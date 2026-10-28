// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// a stand-in for server/files: the same paths and words, the parts kept in
// memory, and ways to make it fail
type fakeFiles struct {
	mu    sync.Mutex
	files map[string]*fakeFile
	// what it refuses /new with, when set
	refuse string
	// parts to answer 503 before taking one
	failParts atomic.Int32
	// a download cut after this many bytes, once
	cutAfter atomic.Int64
	puts     atomic.Int32
	gets     atomic.Int32
	ranges   []string
	news     []map[string]any
	gots     []string
	drops    []string
}

type fakeFile struct {
	size  int64
	parts map[int][]byte
	ended bool
	own   string
	got   []string
}

func newFakeFiles(t *testing.T) (*fakeFiles, *httptest.Server) {
	f := &fakeFiles{files: map[string]*fakeFile{}}
	mux := http.NewServeMux()
	word := func(w http.ResponseWriter, code int, e string) {
		w.WriteHeader(code)
		fmt.Fprintf(w, `{"e":%q}`, e)
	}
	mux.HandleFunc("POST /files/new", func(w http.ResponseWriter, r *http.Request) {
		var m map[string]any
		_ = json.NewDecoder(r.Body).Decode(&m)
		f.mu.Lock()
		defer f.mu.Unlock()
		f.news = append(f.news, m)
		if f.refuse != "" {
			word(w, 507, f.refuse)
			return
		}
		if !dropPowHolds(m["day"].(string), m["who"].(string), uint64(m["pow"].(float64)), dropPowBits) {
			word(w, 403, "denied")
			return
		}
		id := m["id"].(string)
		ff := f.files[id]
		if ff == nil {
			got := []string{}
			for _, g := range m["got"].([]any) {
				got = append(got, g.(string))
			}
			ff = &fakeFile{size: int64(m["size"].(float64)), parts: map[int][]byte{}, own: m["own"].(string), got: got}
			f.files[id] = ff
		}
		have := []int{}
		for n := range ff.parts {
			have = append(have, n)
		}
		json.NewEncoder(w).Encode(map[string]any{"have": have, "end": ff.ended, "part": dropPart})
	})
	mux.HandleFunc("PUT /files/{id}/{n}", func(w http.ResponseWriter, r *http.Request) {
		f.puts.Add(1)
		if f.failParts.Add(-1) >= 0 {
			io.Copy(io.Discard, r.Body)
			w.WriteHeader(503)
			return
		}
		n, _ := strconv.Atoi(r.PathValue("n"))
		b, _ := io.ReadAll(r.Body)
		f.mu.Lock()
		defer f.mu.Unlock()
		ff := f.files[r.PathValue("id")]
		if ff == nil {
			word(w, 404, "gone")
			return
		}
		ff.parts[n] = b
		w.Write([]byte(`{"ok":true}`))
	})
	mux.HandleFunc("POST /files/{id}/end", func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		ff := f.files[r.PathValue("id")]
		var n int64
		for _, p := range ff.parts {
			n += int64(len(p))
		}
		if n != ff.size {
			word(w, 409, "parts")
			return
		}
		ff.ended = true
		w.Write([]byte(`{"ok":true}`))
	})
	mux.HandleFunc("GET /files/{id}", func(w http.ResponseWriter, r *http.Request) {
		f.gets.Add(1)
		f.mu.Lock()
		ff := f.files[r.PathValue("id")]
		f.ranges = append(f.ranges, r.Header.Get("Range"))
		f.mu.Unlock()
		if ff == nil || !ff.ended {
			word(w, 404, "gone")
			return
		}
		var all []byte
		for n := 0; n < len(ff.parts); n++ {
			all = append(all, ff.parts[n]...)
		}
		if cut := f.cutAfter.Swap(0); cut > 0 {
			// a circuit that dies part way
			from := int64(0)
			if rg := r.Header.Get("Range"); rg != "" {
				fmt.Sscanf(rg, "bytes=%d-", &from)
			}
			w.Header().Set("Content-Length", strconv.FormatInt(int64(len(all))-from, 10))
			if from > 0 {
				w.WriteHeader(206)
			}
			w.Write(all[from : from+cut])
			panic(http.ErrAbortHandler)
		}
		http.ServeContent(w, r, "", time.Time{}, bytes.NewReader(all))
	})
	mux.HandleFunc("POST /files/{id}/got", func(w http.ResponseWriter, r *http.Request) {
		var m map[string]string
		_ = json.NewDecoder(r.Body).Decode(&m)
		f.mu.Lock()
		defer f.mu.Unlock()
		f.gots = append(f.gots, m["t"])
		if f.files[r.PathValue("id")] == nil {
			word(w, 404, "gone")
			return
		}
		w.Write([]byte(`{"left":0}`))
	})
	mux.HandleFunc("POST /files/{id}/drop", func(w http.ResponseWriter, r *http.Request) {
		var m map[string]string
		_ = json.NewDecoder(r.Body).Decode(&m)
		f.mu.Lock()
		defer f.mu.Unlock()
		f.drops = append(f.drops, m["t"])
		ff := f.files[r.PathValue("id")]
		if ff == nil {
			word(w, 404, "gone")
			return
		}
		if sha256Hex(m["t"]) != ff.own {
			word(w, 403, "denied")
			return
		}
		delete(f.files, r.PathValue("id"))
		w.Write([]byte(`{"ok":true}`))
	})
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	return f, srv
}

// the engine pointed at the stand-in, dialing straight to it, with a
// secret of the test's own
func dropRig(t *testing.T) (*fakeFiles, *[]string) {
	t.Helper()
	f, srv := newFakeFiles(t)
	oldHosts, oldDial, oldSecret, oldBits, oldPause := dropHosts, dropDial, dropSecret, dropPowBits, dropPause
	lanes := &[]string{}
	var lanesMu sync.Mutex
	dropHosts = map[string]string{"f1": srv.URL}
	dropDial = func(lane string) (dialFn, error) {
		lanesMu.Lock()
		*lanes = append(*lanes, lane)
		lanesMu.Unlock()
		return (&net.Dialer{}).DialContext, nil
	}
	secret := make([]byte, 32)
	rand.Read(secret)
	dropSecret = func() ([]byte, error) { return secret, nil }
	dropPowBits = 6
	dropPause = 10 * time.Millisecond
	t.Cleanup(func() {
		dropHosts, dropDial, dropSecret, dropPowBits, dropPause = oldHosts, oldDial, oldSecret, oldBits, oldPause
	})
	return f, lanes
}

func writeRandom(t *testing.T, n int) (string, []byte) {
	t.Helper()
	b := make([]byte, n)
	rand.Read(b)
	p := filepath.Join(t.TempDir(), "file.bin")
	if err := os.WriteFile(p, b, 0o600); err != nil {
		t.Fatal(err)
	}
	return p, b
}

func sendJob(path, uid string, members ...string) string {
	b, _ := json.Marshal(dropSendJob{Path: path, UID: uid, Members: members, Host: "f1", Lane: "everyday"})
	return string(b)
}

func mustSend(t *testing.T, job string) dropSent {
	t.Helper()
	out := dropSend(job)
	var s dropSent
	if err := json.Unmarshal([]byte(out), &s); err != nil {
		t.Fatalf("send: %s", out)
	}
	return s
}

func fetchJob(s dropSent, path string) string {
	b, _ := json.Marshal(dropFetchJob{Host: "f1", ID: s.ID, Key: s.Key, Size: s.Size, Chunks: s.Chunks, Path: path})
	return string(b)
}

// a file of a little over two parts goes up sealed and comes down whole,
// each on a lane of its own file
func TestDropSendAndFetch(t *testing.T) {
	f, lanes := dropRig(t)
	path, plain := writeRandom(t, 2*80*dropChunk+12345)
	s := mustSend(t, sendJob(path, "uid1", "alice"))
	if s.Size != int64(len(plain)) || s.Chunks != dropPadChunks(161) || len(s.Tokens) != 1 {
		t.Fatalf("sent %+v", s)
	}
	stored := f.files[s.ID]
	var all []byte
	for n := 0; n < len(stored.parts); n++ {
		all = append(all, stored.parts[n]...)
	}
	if int64(len(all)) != int64(s.Chunks)*dropSealed {
		t.Fatalf("stored %d bytes", len(all))
	}
	if bytes.Contains(all, plain[:64]) {
		t.Fatal("the service holds plain bytes")
	}
	if got := stored.got[0]; got != sha256Hex(s.Tokens["alice"]) {
		t.Fatal("the service was not given the hash of the token")
	}
	out := filepath.Join(t.TempDir(), "got.bin")
	if r := dropFetch(fetchJob(s, out)); r != "ok" {
		t.Fatalf("fetch: %s", r)
	}
	back, _ := os.ReadFile(out)
	if !bytes.Equal(back, plain) {
		t.Fatal("the file came back different")
	}
	if _, err := os.Stat(out + ".part"); !os.IsNotExist(err) {
		t.Fatal("the sealed bytes stayed")
	}
	for _, l := range *lanes {
		if l != "files:"+s.ID {
			t.Fatalf("a transfer on lane %q", l)
		}
	}
}

// the same message and file give the same values; another message or a
// changed file gives others
func TestDropValuesStable(t *testing.T) {
	dropRig(t)
	path, _ := writeRandom(t, 1000)
	a, _, _ := dropValuesFor(path, "u")
	b, _, _ := dropValuesFor(path, "u")
	c, _, _ := dropValuesFor(path, "v")
	if a.id != b.id || string(a.key) != string(b.key) || a.token("m") != b.token("m") {
		t.Fatal("the values moved between sends")
	}
	if a.id == c.id || a.token("m") == a.token("n") {
		t.Fatal("two messages or two members share values")
	}
	os.WriteFile(path, []byte("other bytes"), 0o600)
	d, _, _ := dropValuesFor(path, "u")
	if d.id == a.id || string(d.key) == string(a.key) {
		t.Fatal("other bytes under the old key")
	}
}

// a send cut off asks again and sends only the parts still missing
func TestDropSendResumes(t *testing.T) {
	f, _ := dropRig(t)
	path, _ := writeRandom(t, 3*80*dropChunk)
	v, _, _ := dropValuesFor(path, "uid2")
	// the first go dies on its second part with every try used
	f.failParts.Store(1 + int32(dropTries))
	if r := dropSend(sendJob(path, "uid2", "bob")); r != "error: net" {
		t.Fatalf("first go: %s", r)
	}
	before := len(f.files[v.id].parts)
	if before != 0 && before != 1 {
		t.Fatalf("%d parts in after the first go", before)
	}
	f.puts.Store(0)
	f.failParts.Store(0)
	s := mustSend(t, sendJob(path, "uid2", "bob"))
	if int(f.puts.Load()) != 3-before {
		t.Fatalf("%d parts sent again, want %d", f.puts.Load(), 3-before)
	}
	if s.ID != v.id {
		t.Fatal("the second go is another file")
	}
	// one part refused once is tried again inside the same go
	path2, _ := writeRandom(t, 1000)
	f.failParts.Store(1)
	mustSend(t, sendJob(path2, "uid3", "bob"))
}

// a download cut off goes on from the chunks it has, by range
func TestDropFetchResumes(t *testing.T) {
	f, _ := dropRig(t)
	path, plain := writeRandom(t, 200*dropChunk+77)
	s := mustSend(t, sendJob(path, "uid4", "carol"))
	f.cutAfter.Store(50*dropSealed + 1000)
	oldTries := dropTries
	dropTries = 1
	out := filepath.Join(t.TempDir(), "got.bin")
	if r := dropFetch(fetchJob(s, out)); r != "error: net" {
		t.Fatalf("cut: %s", r)
	}
	dropTries = oldTries
	if st, err := os.Stat(out + ".part"); err != nil || st.Size() < 50*dropSealed {
		t.Fatalf("the sealed bytes did not stay: %v", err)
	}
	if _, err := os.Stat(out); !os.IsNotExist(err) {
		t.Fatal("a half file is in place")
	}
	if r := dropFetch(fetchJob(s, out)); r != "ok" {
		t.Fatalf("again: %s", r)
	}
	last := f.ranges[len(f.ranges)-1]
	if last != fmt.Sprintf("bytes=%d-", 50*dropSealed) {
		t.Fatalf("went on with %q", last)
	}
	back, _ := os.ReadFile(out)
	if !bytes.Equal(back, plain) {
		t.Fatal("the resumed file is different")
	}
}

// a wrong key, a changed byte or a wrong size never makes a file
func TestDropFetchRefusesWhatDoesNotOpen(t *testing.T) {
	f, _ := dropRig(t)
	path, _ := writeRandom(t, 5000)
	s := mustSend(t, sendJob(path, "uid5", "dan"))
	out := filepath.Join(t.TempDir(), "got.bin")
	wrong := s
	wrong.Key = strings.Repeat("ab", 32)
	if r := dropFetch(fetchJob(wrong, out)); r != "error: bad" {
		t.Fatalf("wrong key: %s", r)
	}
	short := s
	short.Size = 100
	if r := dropFetch(fetchJob(short, out)); r != "error: bad" {
		t.Fatalf("a shorter size: %s", r)
	}
	f.mu.Lock()
	f.files[s.ID].parts[0][10] ^= 1
	f.mu.Unlock()
	if r := dropFetch(fetchJob(s, out)); r != "error: bad" {
		t.Fatalf("a changed byte: %s", r)
	}
	for _, p := range []string{out, out + ".part", out + ".open"} {
		if _, err := os.Stat(p); !os.IsNotExist(err) {
			t.Fatalf("%s left behind", p)
		}
	}
	gone := s
	gone.ID = strings.Repeat("0", 32)
	if r := dropFetch(fetchJob(gone, out)); r != "error: gone" {
		t.Fatalf("a file not there: %s", r)
	}
}

// a sealed file past its end holds filler that opens to zeros only
func TestDropFillerMustBeZeros(t *testing.T) {
	v := dropDerive([]byte("k"), "u", []byte("s"))
	a, _ := dropAEAD(v.key)
	chunks := dropPadChunks(17)
	f, err := os.CreateTemp(t.TempDir(), "sealed")
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < chunks; i++ {
		plain := make([]byte, dropChunk)
		if i == chunks-1 {
			plain[0] = 1
		}
		f.Write(a.Seal(nil, dropNonce(i), plain, dropAAD(chunks)))
	}
	job := dropFetchJob{Size: 17 * dropChunk, Chunks: chunks, Path: filepath.Join(t.TempDir(), "x")}
	if w := dropOpenInto(f, a, job); w != "bad" {
		t.Fatalf("filler with a byte in it: %q", w)
	}
}

// the service's words come back as the engine's, and none is tried again
// at once
func TestDropSendWords(t *testing.T) {
	f, _ := dropRig(t)
	path, _ := writeRandom(t, 1000)
	for _, w := range []string{"full", "limit", "busy", "big"} {
		f.refuse = w
		n := len(f.news)
		if r := dropSend(sendJob(path, "uid6", "eve")); r != "error: "+w {
			t.Fatalf("%s: %s", w, r)
		}
		if len(f.news) != n+1 {
			t.Fatalf("%s was asked %d times", w, len(f.news)-n)
		}
	}
	f.refuse = ""
	if r := dropSend(sendJob(path, "uid6")); r != "error: bad" {
		t.Fatalf("no recipients: %s", r)
	}
	bad := strings.Replace(sendJob(path, "uid6", "eve"), `"f1"`, `"evil"`, 1)
	if r := dropSend(bad); r != "error: bad" {
		t.Fatalf("a host the app does not know: %s", r)
	}
	if r := dropFetch(strings.Replace(fetchJob(dropSent{ID: strings.Repeat("a", 32), Key: strings.Repeat("a", 64), Size: 10, Chunks: 1}, "/tmp/x"), `"f1"`, `"https://evil"`, 1)); r != "error: bad" {
		t.Fatalf("a fetch from a url: %s", r)
	}
}

// a group's file names every member's token, and each member says got with
// its own
func TestDropGroupTokensAndGot(t *testing.T) {
	f, _ := dropRig(t)
	path, _ := writeRandom(t, 1000)
	s := mustSend(t, sendJob(path, "uid7", "a", "b", "c"))
	if len(f.files[s.ID].got) != 3 {
		t.Fatal("not every member's token")
	}
	if r := dropGot("f1", s.ID, s.Tokens["b"]); r != "ok" {
		t.Fatalf("got: %s", r)
	}
	if f.gots[0] != s.Tokens["b"] {
		t.Fatal("got sent another token")
	}
	if r := dropGot("f1", strings.Repeat("1", 32), s.Tokens["b"]); r != "ok" {
		t.Fatalf("got for a file already gone: %s", r)
	}
	if r := dropGot("f1", "../x", s.Tokens["b"]); r != "error: bad" {
		t.Fatalf("a bad id: %s", r)
	}
}

// the sender takes a file back with its own token, made again from the file
func TestDropTakeBack(t *testing.T) {
	f, _ := dropRig(t)
	path, _ := writeRandom(t, 1000)
	s := mustSend(t, sendJob(path, "uid8", "a"))
	if r := dropDrop(sendJob(path, "uid8", "a")); r != "ok" {
		t.Fatalf("drop: %s", r)
	}
	if f.files[s.ID] != nil {
		t.Fatal("the file stayed")
	}
	if r := dropDrop(sendJob(path, "uid8", "a")); r != "ok" {
		t.Fatalf("drop again: %s", r)
	}
}

// a cancel stops a send part way and takes back what went up
func TestDropCancel(t *testing.T) {
	f, _ := dropRig(t)
	path, _ := writeRandom(t, 6*80*dropChunk)
	v, _, _ := dropValuesFor(path, "uid9")
	f.failParts.Store(1000)
	dropPause = 200 * time.Millisecond
	done := make(chan string, 1)
	go func() { done <- dropSend(sendJob(path, "uid9", "a")) }()
	deadline := time.Now().Add(5 * time.Second)
	for dropProgress("s:uid9") == "" && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if p := dropProgress("s:uid9"); !strings.HasSuffix(p, fmt.Sprint(int64(dropPadChunks(480))*dropSealed)) {
		t.Fatalf("progress %q", p)
	}
	dropCancel("s:uid9")
	select {
	case r := <-done:
		if r != "error: cancelled" {
			t.Fatalf("cancelled send: %s", r)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the cancel did not stop the send")
	}
	if len(f.drops) != 1 || f.files[v.id] != nil {
		t.Fatal("what went up was not taken back")
	}
	if dropProgress("s:uid9") != "" {
		t.Fatal("a finished send still shows progress")
	}
}

// the day key is one per container and per day, and its work holds
func TestDropDayKey(t *testing.T) {
	dropRig(t)
	ctx := context.Background()
	d1, w1, p1, _ := dropDayKey(ctx, "everyday")
	_, w2, _, _ := dropDayKey(ctx, "everyday")
	_, w3, _, _ := dropDayKey(ctx, "decoy")
	if w1 != w2 || w1 == w3 {
		t.Fatal("one key a container a day")
	}
	if !dropPowHolds(d1, w1, p1, dropPowBits) {
		t.Fatal("the work does not hold")
	}
	old := dropNow
	dropNow = func() time.Time { return time.Now().Add(24 * time.Hour) }
	defer func() { dropNow = old }()
	if _, w4, _, _ := dropDayKey(ctx, "everyday"); w4 == w1 {
		t.Fatal("the key outlived its day")
	}
}

// against a real kryfo-files: KRYFO_FILES_URL=http://127.0.0.1:3342 with
// FILES_POW_BITS=6 on the service
func TestDropAgainstTheService(t *testing.T) {
	url := os.Getenv("KRYFO_FILES_URL")
	if url == "" {
		t.Skip("KRYFO_FILES_URL not set")
	}
	dropRig(t)
	dropHosts = map[string]string{"f1": url}
	path, plain := writeRandom(t, 3*80*dropChunk+999)
	s := mustSend(t, sendJob(path, "uid-live", "a", "b"))
	out := filepath.Join(t.TempDir(), "got.bin")
	if r := dropFetch(fetchJob(s, out)); r != "ok" {
		t.Fatalf("fetch: %s", r)
	}
	back, _ := os.ReadFile(out)
	if !bytes.Equal(back, plain) {
		t.Fatal("different bytes")
	}
	for _, m := range []string{"a", "b"} {
		if r := dropGot("f1", s.ID, s.Tokens[m]); r != "ok" {
			t.Fatalf("got %s: %s", m, r)
		}
	}
	if r := dropFetch(fetchJob(s, out+"2")); r != "error: gone" {
		t.Fatalf("after every got: %s", r)
	}
}
