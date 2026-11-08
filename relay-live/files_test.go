package main

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/fiatjaf/eventstore/slicestore"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

type filesBox struct {
	root, blobName, voiceName string
	blob, sums, voice         []byte
}

// a files dir like the box's: models/<sum>.bin and SHA256SUMS, a secret
// beside models/, one outside the root, symlinks in and out, a sub dir
func makeFiles(t *testing.T) filesBox {
	t.Helper()
	base := t.TempDir()
	root := filepath.Join(base, "kryfo-models")
	for _, d := range []string{"models/sub", "voice"} {
		if err := os.MkdirAll(filepath.Join(root, d), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	blob := make([]byte, 1<<20+123)
	rand.Read(blob)
	s := sha256.Sum256(blob)
	name := hex.EncodeToString(s[:]) + ".bin"
	sums := []byte(hex.EncodeToString(s[:]) + "  " + name + "\n")
	voice := []byte("a voice transcript")
	v := sha256.Sum256(voice)
	vname := hex.EncodeToString(v[:])
	write := func(p string, b []byte) {
		if err := os.WriteFile(p, b, 0o444); err != nil {
			t.Fatal(err)
		}
	}
	write(filepath.Join(root, "models", name), blob)
	write(filepath.Join(root, "models", "SHA256SUMS"), sums)
	write(filepath.Join(root, "models", "sub", "inner"), []byte("inner"))
	write(filepath.Join(root, "voice", vname), voice)
	write(filepath.Join(root, "secret"), []byte("beside models"))
	write(filepath.Join(base, "outside"), []byte("outside the root"))
	write(filepath.Join(base, vname), []byte("outside the root"))
	links := map[string]string{
		filepath.Join(root, "models", "in.bin"):  filepath.Join(root, "models", name),
		filepath.Join(root, "models", "out.bin"): filepath.Join(base, "outside"),
		filepath.Join(root, "models", "rel.bin"): "../secret",
		filepath.Join(root, "models", "etc"):     "/etc/hostname",
		filepath.Join(root, "models", "up"):      "..",
	}
	for l, to := range links {
		if err := os.Symlink(to, l); err != nil {
			t.Fatal(err)
		}
	}
	return filesBox{root: root, blobName: name, voiceName: vname, blob: blob, sums: sums, voice: voice}
}

// one relay behind both listeners, as on the box: clearnet the relay as
// is, the onion one from the env like main does
func filesRelay(t *testing.T, env map[string]string) (clear, onion string) {
	t.Helper()
	for k, v := range env {
		t.Setenv(k, v)
	}
	relay := khatru.NewRelay()
	db := &slicestore.SliceStore{}
	if err := db.Init(); err != nil {
		t.Fatal(err)
	}
	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	relay.DeleteEvent = append(relay.DeleteEvent, db.DeleteEvent)
	applyLimits(relay, "")
	// each listener with the server main builds for it
	c := httptest.NewUnstartedServer(relay)
	c.Config = relayServer("", relay)
	c.Start()
	t.Cleanup(c.Close)
	o, _, err := onionServer(relay)
	if err != nil {
		t.Fatal(err)
	}
	if o == nil {
		t.Fatal("no onion server")
	}
	s := httptest.NewUnstartedServer(o.Handler)
	s.Config = o
	s.Start()
	t.Cleanup(s.Close)
	return c.URL, s.URL
}

func onEnv(fb filesBox) map[string]string {
	return map[string]string{"RELAY_ONION_ADDR": "127.0.0.1:3339", "RELAY_MODELS_DIR": fb.root}
}

func get(t *testing.T, c *http.Client, url string, hdr ...string) (*http.Response, []byte) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i+1 < len(hdr); i += 2 {
		req.Header.Set(hdr[i], hdr[i+1])
	}
	if c == nil {
		c = &http.Client{Timeout: 10 * time.Second}
	}
	resp, err := c.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return resp, b
}

// a request line sent as is, for paths a client would clean
func rawGet(t *testing.T, base, path string) (int, []byte) {
	t.Helper()
	c, err := net.Dial("tcp", strings.TrimPrefix(base, "http://"))
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	c.SetDeadline(time.Now().Add(10 * time.Second))
	fmt.Fprintf(c, "GET %s HTTP/1.1\r\nHost: x.onion\r\nConnection: close\r\n\r\n", path)
	b, _ := io.ReadAll(c)
	var code int
	fmt.Sscanf(string(b), "HTTP/1.1 %d", &code)
	return code, b
}

func TestModelsServedOverTheOnion(t *testing.T) {
	fb := makeFiles(t)
	_, on := filesRelay(t, onEnv(fb))
	resp, b := get(t, nil, on+"/models/"+fb.blobName)
	if resp.StatusCode != 200 || !bytes.Equal(b, fb.blob) {
		t.Fatalf("blob: %d, %d bytes", resp.StatusCode, len(b))
	}
	h := resp.Header
	if h.Get("Content-Type") != "application/octet-stream" || h.Get("X-Content-Type-Options") != "nosniff" ||
		!strings.Contains(h.Get("Cache-Control"), "immutable") || h.Get("ETag") != `"`+fb.blobName+`"` ||
		h.Get("Accept-Ranges") != "bytes" || h.Get("Last-Modified") != "" {
		t.Fatalf("headers %v", h)
	}
	resp, b = get(t, nil, on+"/models/SHA256SUMS")
	if resp.StatusCode != 200 || !bytes.Equal(b, fb.sums) || resp.Header.Get("Cache-Control") != "no-cache" ||
		resp.Header.Get("ETag") != "" {
		t.Fatalf("sums: %d %q %v", resp.StatusCode, b, resp.Header)
	}
}

func TestModelsRanges(t *testing.T) {
	fb := makeFiles(t)
	_, on := filesRelay(t, onEnv(fb))
	u := on + "/models/" + fb.blobName
	n := len(fb.blob)
	resp, b := get(t, nil, u, "Range", "bytes=0-1048575")
	if resp.StatusCode != 206 || !bytes.Equal(b, fb.blob[:1<<20]) ||
		resp.Header.Get("Content-Range") != fmt.Sprintf("bytes 0-1048575/%d", n) {
		t.Fatalf("first mib: %d %v", resp.StatusCode, resp.Header)
	}
	resp, b = get(t, nil, u, "Range", "bytes=-100")
	if resp.StatusCode != 206 || !bytes.Equal(b, fb.blob[n-100:]) {
		t.Fatalf("suffix: %d", resp.StatusCode)
	}
	resp, b = get(t, nil, u, "Range", fmt.Sprintf("bytes=%d-", n-5))
	if resp.StatusCode != 206 || !bytes.Equal(b, fb.blob[n-5:]) {
		t.Fatalf("open end: %d", resp.StatusCode)
	}
	if resp, _ = get(t, nil, u, "Range", "bytes=0-1,5-9"); resp.StatusCode != 416 {
		t.Fatalf("two ranges: %d", resp.StatusCode)
	}
	if resp, _ = get(t, nil, u, "Range", fmt.Sprintf("bytes=%d-", n+10)); resp.StatusCode != 416 {
		t.Fatalf("past the end: %d", resp.StatusCode)
	}
	// the etag is the name: a resume with if-range gets the range
	resp, b = get(t, nil, u, "Range", "bytes=10-19", "If-Range", `"`+fb.blobName+`"`)
	if resp.StatusCode != 206 || !bytes.Equal(b, fb.blob[10:20]) {
		t.Fatalf("if-range: %d", resp.StatusCode)
	}
}

func TestModelsTraversalAndUnknownNames(t *testing.T) {
	fb := makeFiles(t)
	_, on := filesRelay(t, onEnv(fb))
	for _, p := range []string{
		"/models/", "/models", "/models/nothing.bin", "/models/sub", "/models/sub/inner",
		"/models/../secret", "/models/..%2fsecret", "/models/%2e%2e/secret", "/models/%2e%2e%2fsecret",
		"/models/..", "/models/.", "/models/.hidden", "/models//etc/hostname",
		"/models/in.bin", "/models/out.bin", "/models/rel.bin", "/models/etc", "/models/up",
		"/models/up/secret", "/models/" + fb.blobName + "/", "/models/" + fb.blobName + "%00",
		"/models/%2Fetc%2Fhostname", "/models/" + strings.Repeat("a", 129),
		"/voice/" + fb.voiceName, "/secret",
	} {
		code, b := rawGet(t, on, p)
		if code == 200 && (bytes.Contains(b, []byte("beside models")) || bytes.Contains(b, []byte("outside")) ||
			bytes.Contains(b, []byte("inner")) || bytes.Contains(b, fb.blob[:64])) {
			t.Fatalf("%s served a file", p)
		}
		if strings.HasPrefix(p, "/models/") && code != 404 {
			t.Fatalf("%s: %d, want 404", p, code)
		}
	}
	// not get
	for _, m := range []string{http.MethodHead, http.MethodPost, http.MethodPut, http.MethodDelete} {
		req, _ := http.NewRequest(m, on+"/models/SHA256SUMS", nil)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		if resp.StatusCode != 405 || resp.Header.Get("Allow") != "GET" {
			t.Fatalf("%s: %d", m, resp.StatusCode)
		}
	}
}

func TestFilesOnlyOnTheOnionListener(t *testing.T) {
	fb := makeFiles(t)
	cl, on := filesRelay(t, onEnv(fb))
	for _, p := range []string{"/models/SHA256SUMS", "/models/" + fb.blobName, "/voice/" + fb.voiceName} {
		resp, b := get(t, nil, cl+p)
		if resp.StatusCode == 200 && (bytes.Equal(b, fb.sums) || bytes.Equal(b, fb.blob) || bytes.Equal(b, fb.voice)) {
			t.Fatalf("clearnet served %s", p)
		}
	}
	if resp, _ := get(t, nil, on+"/models/SHA256SUMS"); resp.StatusCode != 200 {
		t.Fatalf("onion: %d", resp.StatusCode)
	}
}

func TestOnionListenerConfig(t *testing.T) {
	relay := khatru.NewRelay()
	t.Setenv("RELAY_ONION_ADDR", "")
	t.Setenv("RELAY_MODELS_DIR", t.TempDir())
	if s, _, err := onionServer(relay); s != nil || err != nil {
		t.Fatalf("unset addr: %v %v", s, err)
	}
	for _, a := range []string{"0.0.0.0:3339", ":3339", "192.0.2.10:3339", "localhost:3339", "127.0.0.1", "[::]:3339"} {
		t.Setenv("RELAY_ONION_ADDR", a)
		if s, _, err := onionServer(relay); s != nil || err == nil {
			t.Fatalf("%s taken", a)
		}
	}
	t.Setenv("RELAY_ONION_ADDR", "[::1]:3339")
	t.Setenv("RELAY_MODELS_DIR", filepath.Join(t.TempDir(), "none"))
	if _, _, err := onionServer(relay); err == nil {
		t.Fatal("a missing dir taken")
	}
	// no dir: the onion listener is the relay alone
	t.Setenv("RELAY_MODELS_DIR", "")
	s, what, err := onionServer(relay)
	if err != nil || s == nil || what != "no files" {
		t.Fatalf("%v %q %v", s, what, err)
	}
	if _, ok := s.Handler.(*khatru.Relay); !ok {
		t.Fatalf("handler %T, want the relay", s.Handler)
	}
}

func TestVoiceOffUnlessSwitchedOn(t *testing.T) {
	fb := makeFiles(t)
	_, on := filesRelay(t, onEnv(fb))
	resp, b := get(t, nil, on+"/voice/"+fb.voiceName)
	if resp.StatusCode == 200 && bytes.Equal(b, fb.voice) {
		t.Fatal("voice served while off")
	}
	env := onEnv(fb)
	env["RELAY_VOICE"] = "on"
	_, on = filesRelay(t, env)
	resp, b = get(t, nil, on+"/voice/"+fb.voiceName)
	if resp.StatusCode != 200 || !bytes.Equal(b, fb.voice) || !strings.Contains(resp.Header.Get("Cache-Control"), "immutable") {
		t.Fatalf("voice on: %d", resp.StatusCode)
	}
	for _, p := range []string{"/voice/" + strings.ToUpper(fb.voiceName), "/voice/" + fb.voiceName[:63], "/voice/x.bin", "/voice/"} {
		if code, _ := rawGet(t, on, p); code != 404 {
			t.Fatalf("%s: %d", p, code)
		}
	}
	// a voice dir that is a symlink out of the root
	os.RemoveAll(filepath.Join(fb.root, "voice"))
	if err := os.Symlink(filepath.Dir(fb.root), filepath.Join(fb.root, "voice")); err != nil {
		t.Fatal(err)
	}
	if code, b := rawGet(t, on, "/voice/"+fb.voiceName); code != 404 || bytes.Contains(b, []byte("outside")) {
		t.Fatalf("voice dir out of the root: %d", code)
	}
}

func TestFilesRateLimitedPerConnection(t *testing.T) {
	fb := makeFiles(t)
	_, on := filesRelay(t, onEnv(fb))
	one := &http.Client{Timeout: 10 * time.Second, Transport: &http.Transport{MaxConnsPerHost: 1}}
	limited := 0
	for i := 0; i < filesBurst+10; i++ {
		resp, _ := get(t, one, on+"/models/SHA256SUMS")
		if i < filesBurst && resp.StatusCode != 200 {
			t.Fatalf("request %d: %d", i, resp.StatusCode)
		}
		if resp.StatusCode == 429 {
			limited++
		}
	}
	if limited == 0 {
		t.Fatal("never limited")
	}
	other := &http.Client{Timeout: 10 * time.Second, Transport: &http.Transport{}}
	if resp, _ := get(t, other, on+"/models/SHA256SUMS"); resp.StatusCode != 200 {
		t.Fatalf("another connection: %d", resp.StatusCode)
	}
}

func TestFilesBusyWhenEverySlotIsTaken(t *testing.T) {
	fb := makeFiles(t)
	fs, err := openFiles(fb.root, false)
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < fileSlots; i++ {
		fs.slots <- struct{}{}
	}
	s := httptest.NewUnstartedServer(onionHandler(khatru.NewRelay(), fs))
	s.Config.ConnContext = withConnFiles
	s.Start()
	defer s.Close()
	if resp, _ := get(t, nil, s.URL+"/models/SHA256SUMS"); resp.StatusCode != 503 {
		t.Fatalf("%d, want 503", resp.StatusCode)
	}
	<-fs.slots
	if resp, _ := get(t, nil, s.URL+"/models/SHA256SUMS"); resp.StatusCode != 200 {
		t.Fatalf("%d after a slot came free", resp.StatusCode)
	}
}

// nothing about a file request reaches the log, stdout or stderr
func TestFilesLogNothing(t *testing.T) {
	fb := makeFiles(t)
	_, on := filesRelay(t, onEnv(fb))
	var buf bytes.Buffer
	log.SetOutput(&buf)
	defer log.SetOutput(os.Stderr)
	r, w, _ := os.Pipe()
	oldOut, oldErr := os.Stdout, os.Stderr
	os.Stdout, os.Stderr = w, w
	for _, p := range []string{"/models/SHA256SUMS", "/models/" + fb.blobName, "/models/nothing", "/models/../secret", "/models/out.bin"} {
		rawGet(t, on, p)
	}
	get(t, nil, on+"/models/"+fb.blobName, "Range", "bytes=0-1,4-5")
	c, err := net.Dial("tcp", strings.TrimPrefix(on, "http://"))
	if err == nil {
		fmt.Fprintf(c, "GET /models/%s HTTP/1.1\r\nHost: x\r\n\r\n", fb.blobName)
		c.Close() // gone half way through the answer
	}
	time.Sleep(200 * time.Millisecond)
	os.Stdout, os.Stderr = oldOut, oldErr
	w.Close()
	out, _ := io.ReadAll(r)
	if buf.Len() != 0 || len(out) != 0 {
		t.Fatalf("logged %q, printed %q", buf.String(), out)
	}
}

// the websocket and the relay's info answer over the onion listener as on
// the clearnet one
func TestRelayUnchangedOnTheOnionListener(t *testing.T) {
	fb := makeFiles(t)
	cl, on := filesRelay(t, onEnv(fb))
	for _, base := range []string{cl, on} {
		resp, b := get(t, nil, base+"/", "Accept", "application/nostr+json")
		if resp.StatusCode != 200 || !bytes.Contains(b, []byte(`"software"`)) {
			t.Fatalf("%s info: %d %s", base, resp.StatusCode, b)
		}
		r := connect(t, "ws"+strings.TrimPrefix(base, "http"))
		to := addr()
		if err := publish(t, r, wrap(t, to, nil)); err != nil {
			t.Fatal(err)
		}
		got, why := ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Limit: 10})
		if why != "" || len(got) != 1 {
			t.Fatalf("%s: got %d, closed %q", base, len(got), why)
		}
		// the address check holds on both
		_, why = ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Limit: 10})
		if why == "" {
			t.Fatalf("%s: an addressless req was answered", base)
		}
	}
}

// a caller that sends its headers slowly, or keeps a connection idle, is
// closed on both listeners; a websocket lives on past both waits
func TestSlowAndIdleConnectionsClosed(t *testing.T) {
	oh, oi := headerWait, idleWait
	headerWait, idleWait = 300*time.Millisecond, 600*time.Millisecond
	t.Cleanup(func() { headerWait, idleWait = oh, oi })
	fb := makeFiles(t)
	cl, on := filesRelay(t, onEnv(fb))
	closed := func(c net.Conn) bool {
		c.SetReadDeadline(time.Now().Add(5 * time.Second))
		_, err := io.ReadAll(c)
		return err == nil
	}
	for _, base := range []string{cl, on} {
		hostport := strings.TrimPrefix(base, "http://")
		c, err := net.Dial("tcp", hostport)
		if err != nil {
			t.Fatal(err)
		}
		fmt.Fprintf(c, "GET /models/SHA256SUMS HTTP/1.1\r\nHost: x\r\n")
		start := time.Now()
		if !closed(c) || time.Since(start) > 3*time.Second {
			t.Fatalf("%s: half a header kept open", base)
		}
		c.Close()
		// a whole request, then nothing: closed once idle
		c, err = net.Dial("tcp", hostport)
		if err != nil {
			t.Fatal(err)
		}
		fmt.Fprintf(c, "GET / HTTP/1.1\r\nHost: x\r\nAccept: application/nostr+json\r\n\r\n")
		start = time.Now()
		if !closed(c) || time.Since(start) > 3*time.Second {
			t.Fatalf("%s: an idle connection kept open", base)
		}
		c.Close()
		r := connect(t, "ws"+strings.TrimPrefix(base, "http"))
		time.Sleep(time.Second)
		to := addr()
		if err := publish(t, r, wrap(t, to, nil)); err != nil {
			t.Fatalf("%s: websocket after the waits: %v", base, err)
		}
		got, why := ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Limit: 10})
		if why != "" || len(got) != 1 {
			t.Fatalf("%s: got %d, closed %q", base, len(got), why)
		}
	}
}
