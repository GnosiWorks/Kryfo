// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
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
	// a second download dials under a name of its own
	voiceRemove("base", dir)
	voiceFetch("base", dir)
	waitVoice(t, "base")
	if len(r.names) != 2 || r.names[0] == r.names[1] {
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
	voiceJobs.Cancel("base")
	if st := voiceJobs.Status("base"); st.State != voice.StateCancelled || st.Done != voice.Chunk {
		t.Fatalf("status %+v", st)
	}
	st, err := os.Stat(filepath.Join(dir, "m.bin.part"))
	if err != nil || st.Size() != voice.Chunk {
		t.Fatalf("part %v %v", st, err)
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
	hits := r.hits.Load()
	time.Sleep(100 * time.Millisecond)
	if r.hits.Load() != hits {
		t.Fatal("asked the host again with a decoy open")
	}
	if _, err := os.Stat(filepath.Join(dir, "m.bin")); err == nil {
		t.Fatal("a model landed in the decoy")
	}
}
