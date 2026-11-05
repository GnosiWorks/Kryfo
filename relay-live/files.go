package main

// read-only files on the onion listener only: /models/<name> (translation
// packs) and, once switched on, /voice/<sha256>. exact names, no listing,
// no symlinks, get only, nothing logged. the clearnet listener never
// serves them. the files sit under one dir:
//   RELAY_ONION_ADDR   loopback host:port tor's HiddenServicePort 80 maps to
//   RELAY_MODELS_DIR   the dir holding models/ (and voice/); off when unset
//   RELAY_VOICE=on     serve voice/ too; off unless exactly "on"

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	filesPerSec   = 2
	filesBurst    = 20
	fileSlots     = 32
	fileWriteWait = 60 * time.Second
	fileMaxTime   = 2 * time.Hour
)

var (
	modelName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`)
	voiceName = regexp.MustCompile(`^[0-9a-f]{64}$`)
	sumName   = regexp.MustCompile(`^[0-9a-f]{64}\.bin$`)
)

type fileServer struct {
	root  *os.Root
	voice bool
	slots chan struct{}
}

func openFiles(dir string, voice bool) (*fileServer, error) {
	r, err := os.OpenRoot(dir)
	if err != nil {
		return nil, err
	}
	return &fileServer{root: r, voice: voice, slots: make(chan struct{}, fileSlots)}, nil
}

// one bucket per connection, set by the onion server's ConnContext
type connFiles struct {
	mu sync.Mutex
	b  *bucket
}

type connFilesKey struct{}

func withConnFiles(ctx context.Context, _ net.Conn) context.Context {
	return context.WithValue(ctx, connFilesKey{}, &connFiles{b: newBucket(filesPerSec, filesBurst)})
}

func takeFile(ctx context.Context) bool {
	c, _ := ctx.Value(connFilesKey{}).(*connFiles)
	if c == nil {
		return false
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.b.take(time.Now())
}

// the onion listener's handler: files by path, everything else to the relay
func onionHandler(relay http.Handler, fs *fileServer) http.Handler {
	if fs == nil {
		return relay
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch p := r.URL.Path; {
		case strings.HasPrefix(p, "/models/"):
			fs.serve(w, r, "models", strings.TrimPrefix(p, "/models/"), modelName)
		case fs.voice && strings.HasPrefix(p, "/voice/"):
			fs.serve(w, r, "voice", strings.TrimPrefix(p, "/voice/"), voiceName)
		default:
			relay.ServeHTTP(w, r)
		}
	})
}

func (fs *fileServer) serve(w http.ResponseWriter, r *http.Request, dir, name string, ok *regexp.Regexp) {
	h := w.Header()
	if r.Method != http.MethodGet {
		h.Set("Allow", http.MethodGet)
		http.Error(w, "get only", http.StatusMethodNotAllowed)
		return
	}
	if !takeFile(r.Context()) {
		http.Error(w, "slow down", http.StatusTooManyRequests)
		return
	}
	if !ok.MatchString(name) {
		http.NotFound(w, r)
		return
	}
	// one range at most: many ranges cost a multipart body and buy nothing
	if strings.Contains(r.Header.Get("Range"), ",") {
		http.Error(w, "one range at most", http.StatusRequestedRangeNotSatisfiable)
		return
	}
	f, err := fs.open(dir + "/" + name)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer f.Close()
	select {
	case fs.slots <- struct{}{}:
		defer func() { <-fs.slots }()
	default:
		http.Error(w, "busy, try later", http.StatusServiceUnavailable)
		return
	}
	h.Set("Content-Type", "application/octet-stream")
	h.Set("X-Content-Type-Options", "nosniff")
	if dir == "voice" || sumName.MatchString(name) {
		// named by their sum: they never change
		h.Set("Cache-Control", "public, max-age=31536000, immutable")
		h.Set("ETag", `"`+name+`"`)
	} else {
		h.Set("Cache-Control", "no-cache")
	}
	http.ServeContent(newSlowWriter(w), r, "", time.Time{}, f)
}

var errNotPlain = errors.New("not a plain file")

// a regular file inside the root, never a symlink, and the same file that
// was looked at
func (fs *fileServer) open(p string) (*os.File, error) {
	st, err := fs.root.Lstat(p)
	if err != nil {
		return nil, err
	}
	if !st.Mode().IsRegular() {
		return nil, errNotPlain
	}
	f, err := fs.root.OpenFile(p, os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return nil, err
	}
	ft, err := f.Stat()
	if err != nil || !ft.Mode().IsRegular() || !os.SameFile(st, ft) {
		f.Close()
		return nil, errNotPlain
	}
	return f, nil
}

// a big file over tor outlasts the server's write timeout: each write gets
// its own deadline, and the whole answer fileMaxTime at most. only Write is
// passed on, so the copy goes through it
type slowWriter struct {
	w   http.ResponseWriter
	rc  *http.ResponseController
	end time.Time
}

func newSlowWriter(w http.ResponseWriter) *slowWriter {
	return &slowWriter{w: w, rc: http.NewResponseController(w), end: time.Now().Add(fileMaxTime)}
}

func (s *slowWriter) Header() http.Header { return s.w.Header() }

func (s *slowWriter) WriteHeader(code int) {
	s.deadline()
	s.w.WriteHeader(code)
}

func (s *slowWriter) Write(b []byte) (int, error) {
	s.deadline()
	return s.w.Write(b)
}

func (s *slowWriter) deadline() {
	d := time.Now().Add(fileWriteWait)
	if d.After(s.end) {
		d = s.end
	}
	s.rc.SetWriteDeadline(d)
}

func loopbackAddr(a string) bool {
	host, port, err := net.SplitHostPort(a)
	if err != nil || port == "" {
		return false
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

// the onion listener from the env. nil when RELAY_ONION_ADDR is unset
func onionServer(relay http.Handler) (*http.Server, string, error) {
	addr := strings.TrimSpace(os.Getenv("RELAY_ONION_ADDR"))
	if addr == "" {
		return nil, "", nil
	}
	if !loopbackAddr(addr) {
		return nil, "", fmt.Errorf("RELAY_ONION_ADDR %q is not a loopback host:port", addr)
	}
	var fs *fileServer
	what := "no files"
	if dir := strings.TrimSpace(os.Getenv("RELAY_MODELS_DIR")); dir != "" {
		var err error
		if fs, err = openFiles(dir, os.Getenv("RELAY_VOICE") == "on"); err != nil {
			return nil, "", fmt.Errorf("RELAY_MODELS_DIR: %w", err)
		}
		what = "files from " + dir
		if fs.voice {
			what += " (models, voice)"
		} else {
			what += " (models)"
		}
	}
	srv := &http.Server{
		Addr:         addr,
		Handler:      onionHandler(relay, fs),
		WriteTimeout: writeWait,
		ConnContext:  withConnFiles,
	}
	return srv, what, nil
}
