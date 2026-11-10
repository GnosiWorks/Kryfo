// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/halo/engine/voice"
)

// a small model on a tls host of its own, the pins pointing at it, and the
// socks names the downloads dialled under
type voiceRig struct {
	data  []byte
	srv   *httptest.Server
	hits  atomic.Int32
	mu    sync.Mutex
	names []string
}

func newVoiceRig(t *testing.T, h http.Handler) *voiceRig {
	r := &voiceRig{data: bytes.Repeat([]byte("kryfo voice "), 200000)}
	if h == nil {
		h = http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			r.hits.Add(1)
			http.ServeContent(w, req, "m.bin", time.Time{}, bytes.NewReader(r.data))
		})
	}
	r.srv = httptest.NewTLSServer(h)
	sum := sha256.Sum256(r.data)
	man, err := voice.Parse([]byte(fmt.Sprintf(
		`{"base":%q,"source":"https://source.example/m/","models":[{"id":"base","file":"m.bin","size":%d,"sha256":%q}]}`,
		r.srv.URL+"/v/", len(r.data), hex.EncodeToString(sum[:]))))
	if err != nil {
		t.Fatal(err)
	}
	pool := x509.NewCertPool()
	pool.AddCert(r.srv.Certificate())
	oldPinned, oldDial, oldTLS := voicePinned, voiceDial, voiceTLS
	oldWait, oldGive, oldReady := voiceWait, voiceGiveUp, voiceNetReady
	voiceWait = func(int) time.Duration { return 5 * time.Millisecond }
	voiceGiveUp = 300 * time.Millisecond
	voiceNetReady = func() bool { return true }
	oldDecoy := decoyState.Load()
	decoyState.Store(decoyOff)
	voicePinned = func() (*voice.Manifest, error) { return man, nil }
	voiceTLS = &tls.Config{RootCAs: pool}
	voiceDial = func(name string) (dialFn, error) {
		r.mu.Lock()
		r.names = append(r.names, name)
		r.mu.Unlock()
		var d net.Dialer
		return d.DialContext, nil
	}
	t.Cleanup(func() {
		voiceJobs.Cancel("base")
		voiceJobs.Forget("base")
		r.srv.Close()
		voicePinned, voiceDial, voiceTLS = oldPinned, oldDial, oldTLS
		voiceWait, voiceGiveUp, voiceNetReady = oldWait, oldGive, oldReady
		decoyState.Store(oldDecoy)
	})
	return r
}

func waitVoice(t *testing.T, id string) voice.Status {
	t.Helper()
	for i := 0; i < 1000; i++ {
		st := voiceJobs.Status(id)
		if st.State != voice.StateRunning {
			return st
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("download never ended")
	return voice.Status{}
}

func TestVoiceModelsListsPins(t *testing.T) {
	var out struct {
		Base   string           `json:"base"`
		Models []voiceModelInfo `json:"models"`
	}
	if err := json.Unmarshal([]byte(voiceModels()), &out); err != nil {
		t.Fatal(err)
	}
	if len(out.Models) != 1 || out.Models[0].ID != "base" || out.Models[0].Size != 59707625 {
		t.Fatalf("models %+v", out.Models)
	}
	if !regexp.MustCompile(`^http://[a-z2-7]{56}\.onion/voice/$`).MatchString(out.Base) {
		t.Fatalf("base %q is not our mirror", out.Base)
	}
}

func TestVoiceFetchOverItsOwnCircuit(t *testing.T) {
	r := newVoiceRig(t, nil)
	dir := t.TempDir()
	if got := voiceCheck("base", dir); got != "no" {
		t.Fatalf("check before %q", got)
	}
	if got := voiceFetch("base", dir); got != "ok" {
		t.Fatal(got)
	}
	st := waitVoice(t, "base")
	if st.State != voice.StateDone || st.Done != int64(len(r.data)) {
		t.Fatalf("status %+v", st)
	}
	var polled voice.Status
	json.Unmarshal([]byte(voiceJSON(voiceJobs.Status("base"))), &polled)
	if polled.State != voice.StateDone {
		t.Fatalf("polled %+v", polled)
	}
	got, _ := os.ReadFile(filepath.Join(dir, "m.bin"))
	if !bytes.Equal(got, r.data) {
		t.Fatal("bytes differ")
	}
	if voiceCheck("base", dir) != "yes" {
		t.Fatal("fetched model fails its check")
	}
	// every lane of it, and a second download, dial under names of their own
	voiceRemove("base", dir)
	voiceFetch("base", dir)
	waitVoice(t, "base")
	seen := map[string]bool{}
	for _, n := range r.names {
		seen[n] = true
	}
	if len(r.names) != 2*voiceLanes || len(seen) != len(r.names) {
		t.Fatalf("socks names %q", r.names)
	}
	hex32 := regexp.MustCompile(`^[0-9a-f]{32}$`)
	for _, n := range r.names {
		if !hex32.MatchString(n) {
			t.Fatalf("socks name %q says more than a random tag", n)
		}
		for _, other := range []string{"", laneName(laneUpdate), laneName(laneServices), laneName(laneGifs), laneName(laneEveryday)} {
			if n == other {
				t.Fatalf("a model download shares an isolation key: %q", n)
			}
		}
	}
}

func TestVoiceFetchNeedsTor(t *testing.T) {
	r := newVoiceRig(t, nil)
	voiceDial = func(string) (dialFn, error) { return nil, fmt.Errorf("not started") }
	dir := t.TempDir()
	if got := voiceFetch("base", dir); !strings.HasPrefix(got, "error: tor") {
		t.Fatalf("got %q", got)
	}
	if r.hits.Load() != 0 {
		t.Fatal("the host was reached without tor")
	}
	if entries, _ := os.ReadDir(dir); len(entries) != 0 {
		t.Fatalf("left %v", entries)
	}
}

func TestVoiceFetchRefuses(t *testing.T) {
	r := newVoiceRig(t, nil)
	for _, c := range []struct{ id, dir string }{
		{"base", "/sdcard/Download"},
		{"base", "/storage/emulated/0/kryfo"},
		{"base", "relative"},
		{"small", t.TempDir()},
		{"large", t.TempDir()},
	} {
		if got := voiceFetch(c.id, c.dir); !strings.HasPrefix(got, "error: ") {
			t.Errorf("%+v: %q", c, got)
		}
	}
	if len(r.names) != 0 || r.hits.Load() != 0 {
		t.Fatal("a refused download dialled")
	}
	if got := voiceCheck("base", "/sdcard/x"); !strings.HasPrefix(got, "error: ") {
		t.Fatalf("check in shared storage %q", got)
	}
}

// the mirror serves the files itself: a redirect is not followed, to any
// host, so the download never leaves the pinned one
func TestVoiceNoRedirect(t *testing.T) {
	target := newVoiceRig(t, nil)
	hop := http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		http.Redirect(w, req, target.srv.URL+req.URL.Path, http.StatusFound)
	})
	newVoiceRig(t, hop)
	// the rig above replaced the pins; the target's own tls is trusted too
	voiceTLS.RootCAs.AddCert(target.srv.Certificate())
	dir := t.TempDir()
	voiceFetch("base", dir)
	if st := waitVoice(t, "base"); st.State != voice.StateFailed {
		t.Fatalf("followed a redirect: %+v", st)
	}
	if target.hits.Load() != 0 {
		t.Fatal("reached the redirect's target")
	}
}

// the request names the model by its hash and nothing else
func TestVoiceAsksForTheHash(t *testing.T) {
	var paths []string
	var mu sync.Mutex
	var r *voiceRig
	r = newVoiceRig(t, http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		mu.Lock()
		paths = append(paths, req.URL.Path)
		mu.Unlock()
		http.ServeContent(w, req, "m.bin", time.Time{}, bytes.NewReader(r.data))
	}))
	dir := t.TempDir()
	voiceFetch("base", dir)
	if st := waitVoice(t, "base"); st.State != voice.StateDone {
		t.Fatalf("status %+v", st)
	}
	sum := sha256.Sum256(r.data)
	want := "/v/" + hex.EncodeToString(sum[:])
	// the handler wrote paths over loopback, which the race detector
	// cannot see as an ordering
	mu.Lock()
	defer mu.Unlock()
	for _, p := range paths {
		if p != want {
			t.Fatalf("asked for %q, want %q", p, want)
		}
	}
	if _, err := os.Stat(filepath.Join(dir, "m.bin")); err != nil {
		t.Fatal("the model is not under its own name on the phone")
	}
}

func TestVoiceRemove(t *testing.T) {
	gate := make(chan struct{})
	var r *voiceRig
	r = newVoiceRig(t, http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		<-gate
		http.ServeContent(w, req, "m.bin", time.Time{}, bytes.NewReader(r.data))
	}))
	dir := t.TempDir()
	voiceFetch("base", dir)
	for !voiceJobs.Running("base") {
		time.Sleep(time.Millisecond)
	}
	if got := voiceRemove("base", dir); got != "error: downloading" {
		t.Fatalf("remove while downloading %q", got)
	}
	if got := voiceCheck("base", dir); got != "no" {
		t.Fatalf("check while downloading %q", got)
	}
	close(gate)
	waitVoice(t, "base")
	if got := voiceRemove("base", dir); got != "ok" {
		t.Fatal(got)
	}
	if entries, _ := os.ReadDir(dir); len(entries) != 0 {
		t.Fatalf("left %v", entries)
	}
	if voiceJobs.Status("base").State != voice.StateIdle {
		t.Fatal("removed model still has a status")
	}
	if got := voiceRemove("nope", dir); !strings.HasPrefix(got, "error: ") {
		t.Fatalf("unknown model %q", got)
	}
}

func TestVoiceCancelKeepsPart(t *testing.T) {
	var r *voiceRig
	started := make(chan struct{}, 1)
	r = newVoiceRig(t, http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		// the first chunk, then a host that stalls until the client goes
		if req.Header.Get("Range") != "bytes=0-1048575" {
			select {
			case started <- struct{}{}:
			default:
			}
			<-req.Context().Done()
			return
		}
		http.ServeContent(w, req, "m.bin", time.Time{}, bytes.NewReader(r.data))
	}))
	dir := t.TempDir()
	voiceFetch("base", dir)
	<-started
	// the other lanes stall; the first chunk lands and is written down
	got := filepath.Join(dir, "m.bin.got")
	for i := 0; i < 400; i++ {
		if b, _ := os.ReadFile(got); string(b) == fmt.Sprint(voice.Chunk) {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}
	voiceJobs.Cancel("base")
	if st := voiceJobs.Status("base"); st.State != voice.StateCancelled || st.Done != voice.Chunk {
		t.Fatalf("status %+v", st)
	}
	st, err := os.Stat(filepath.Join(dir, "m.bin.part"))
	if err != nil || st.Size() < voice.Chunk {
		t.Fatalf("part %v %v", st, err)
	}
	if b, _ := os.ReadFile(got); string(b) != fmt.Sprint(voice.Chunk) {
		t.Fatalf("got file %q", b)
	}
}

// the decoy downloads nothing: not while one is open, not before the app
// has said, and a decoy opening stops a download the real session started
func TestVoiceFetchRefusedInDecoy(t *testing.T) {
	r := newVoiceRig(t, nil)
	for _, st := range []int32{decoyOn, decoyUnknown} {
		decoyState.Store(st)
		dir := t.TempDir()
		if got := voiceFetch("base", dir); got != "error: decoy" {
			t.Errorf("decoy state %d: %q", st, got)
		}
		if entries, _ := os.ReadDir(dir); len(entries) != 0 {
			t.Errorf("decoy state %d left %v", st, entries)
		}
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(r.names) != 0 || r.hits.Load() != 0 {
		t.Fatal("a decoy session dialled")
	}
}

func TestVoiceDecoyStopsADownload(t *testing.T) {
	var r *voiceRig
	started := make(chan struct{}, 1)
	r = newVoiceRig(t, http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		r.hits.Add(1)
		if req.Header.Get("Range") != "bytes=0-1048575" {
			select {
			case started <- struct{}{}:
			default:
			}
			<-req.Context().Done()
			return
		}
		http.ServeContent(w, req, "m.bin", time.Time{}, bytes.NewReader(r.data))
	}))
	dir := t.TempDir()
	if got := voiceFetch("base", dir); got != "ok" {
		t.Fatal(got)
	}
	<-started
	setDecoy(true)
	if st := waitVoice(t, "base"); st.State != voice.StateCancelled {
		t.Fatalf("download ran on in the decoy: %+v", st)
	}
	// its lanes let go of what they were asking for
	voiceJobs.Wait("base")
	hits := r.hits.Load()
	time.Sleep(100 * time.Millisecond)
	if r.hits.Load() != hits {
		t.Fatal("asked the host again with a decoy open")
	}
	if _, err := os.Stat(filepath.Join(dir, "m.bin")); err == nil {
		t.Fatal("a model landed in the decoy")
	}
}

// a conn whose Close waits for hold, so a stopped download cannot let go
// of its file until the test says
type heldConn struct {
	net.Conn
	hold <-chan struct{}
}

func (c heldConn) Close() error {
	<-c.hold
	return c.Conn.Close()
}

// a download tapped again right after a decoy closed starts fresh. the
// old one, stopped but not ended, reads as cancelled at once and is
// waited for, instead of an "ok" for nothing and then "cancelled"
func TestVoiceFetchAfterDecoyStartsFresh(t *testing.T) {
	var r *voiceRig
	var stall atomic.Bool
	stall.Store(true)
	started := make(chan struct{}, 1)
	r = newVoiceRig(t, http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if stall.Load() && req.Header.Get("Range") != "bytes=0-1048575" {
			select {
			case started <- struct{}{}:
			default:
			}
			<-req.Context().Done()
			return
		}
		http.ServeContent(w, req, "m.bin", time.Time{}, bytes.NewReader(r.data))
	}))
	hold := make(chan struct{})
	var once sync.Once
	release := func() { once.Do(func() { close(hold) }) }
	// runs before the rig's cleanup, which waits for the download
	t.Cleanup(release)
	voiceDial = func(string) (dialFn, error) {
		var d net.Dialer
		return func(ctx context.Context, network, addr string) (net.Conn, error) {
			c, err := d.DialContext(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			return heldConn{c, hold}, nil
		}, nil
	}
	dir := t.TempDir()
	if got := voiceFetch("base", dir); got != "ok" {
		t.Fatal(got)
	}
	<-started
	setDecoy(true)
	if st := voiceJobs.Status("base"); st.State != voice.StateCancelled {
		t.Fatalf("a stopped download reads %+v", st)
	}
	setDecoy(false)
	stall.Store(false)
	got := make(chan string, 1)
	go func() { got <- voiceFetch("base", dir) }()
	select {
	case g := <-got:
		t.Fatalf("answered %q while the stopped download held its file", g)
	case <-time.After(100 * time.Millisecond):
	}
	release()
	if g := <-got; g != "ok" {
		t.Fatal(g)
	}
	if st := waitVoice(t, "base"); st.State != voice.StateDone {
		t.Fatalf("the new download ended %+v", st)
	}
	b, err := os.ReadFile(filepath.Join(dir, "m.bin"))
	if err != nil || !bytes.Equal(b, r.data) {
		t.Fatalf("model not landed whole: %v", err)
	}
}

// a cut chunk is waited out and asked again from where it stopped, on a
// fresh circuit after two misses, and a slow one is no longer cut by a cap
// on the whole request
func TestVoiceFetchResumesAfterCuts(t *testing.T) {
	var r *voiceRig
	var n atomic.Int32
	r = newVoiceRig(t, http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		r.hits.Add(1)
		k := n.Add(1)
		if k == 2 || k == 3 {
			// half a chunk, then the circuit goes
			hj, _ := w.(http.Hijacker)
			conn, buf, _ := hj.Hijack()
			buf.WriteString("HTTP/1.1 206 Partial Content\r\nContent-Length: 1048576\r\n")
			buf.WriteString("Content-Range: " + strings.Replace(req.Header.Get("Range"), "=", " ", 1) + "/" + fmt.Sprint(len(r.data)) + "\r\n\r\n")
			buf.Write(r.data[:1000])
			buf.Flush()
			conn.Close()
			return
		}
		http.ServeContent(w, req, "m.bin", time.Time{}, bytes.NewReader(r.data))
	}))
	dir := t.TempDir()
	if got := voiceFetch("base", dir); got != "ok" {
		t.Fatal(got)
	}
	st := waitVoice(t, "base")
	if st.State != voice.StateDone || st.Done != int64(len(r.data)) {
		t.Fatalf("status %+v", st)
	}
	if voiceCheck("base", dir) != "yes" {
		t.Fatal("model fails its check after the cuts")
	}
	for _, left := range []string{"m.bin.part", "m.bin.got", "m.bin.got.new"} {
		if _, err := os.Stat(filepath.Join(dir, left)); err == nil {
			t.Fatalf("%s left behind", left)
		}
	}
	if n.Load() < 5 {
		t.Fatalf("only %d requests for 3 chunks and 2 cuts", n.Load())
	}
}

// a stop keeps the chunks in, and the next start asks only for the rest
func TestVoiceFetchGoesOnFromItsChunks(t *testing.T) {
	var r *voiceRig
	var asked sync.Map
	block := make(chan struct{})
	r = newVoiceRig(t, http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		rg := req.Header.Get("Range")
		if strings.HasPrefix(rg, "bytes=2097152-") {
			select {
			case <-block:
			case <-req.Context().Done():
				return
			}
		}
		asked.Store(rg, true)
		http.ServeContent(w, req, "m.bin", time.Time{}, bytes.NewReader(r.data))
	}))
	voiceGiveUp = time.Minute
	dir := t.TempDir()
	voiceFetch("base", dir)
	for i := 0; i < 400; i++ {
		if b, _ := os.ReadFile(filepath.Join(dir, "m.bin.got")); strings.HasPrefix(string(b), "2097152") {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "m.bin.got")); !strings.HasPrefix(string(b), "2097152") {
		t.Fatalf("got file %q", b)
	}
	voiceJobs.Cancel("base")
	asked.Clear()
	close(block)
	voiceFetch("base", dir)
	if st := waitVoice(t, "base"); st.State != voice.StateDone {
		t.Fatalf("status %+v", st)
	}
	asked.Range(func(k, _ any) bool {
		if !strings.HasPrefix(k.(string), "bytes=2097152-") {
			t.Fatalf("asked again for %s", k)
		}
		return true
	})
	if voiceCheck("base", dir) != "yes" {
		t.Fatal("model fails its check")
	}
}
