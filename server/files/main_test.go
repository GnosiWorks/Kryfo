// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"
)

const testBits = 6

func testConfig() config {
	return config{
		maxPlain:   50 << 20,
		floor:      5 << 30,
		dayBytes:   100 << 30,
		dayFiles:   20000,
		keep:       7 * 24 * time.Hour,
		unfinished: 24 * time.Hour,
		idle:       15 * time.Minute,
		maxFiles:   50000,
		maxComing:  20 << 30,
		idleSmall:  2 * time.Minute,
		powCap:     20,
		powBase:    testBits,
	}
}

// the disk store with a free space the test sets
type roomyStore struct {
	*diskStore
	mu   sync.Mutex
	room uint64
	err  error
}

func (r *roomyStore) free() (uint64, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.room, r.err
}

type rig struct {
	t     *testing.T
	s     *service
	store *roomyStore
	srv   *httptest.Server
	dir   string
	clock time.Time
}

func newRig(t *testing.T, cfg config) *rig {
	t.Helper()
	dir := t.TempDir()
	ds, err := newDiskStore(filepath.Join(dir, "blobs"))
	if err != nil {
		t.Fatal(err)
	}
	st := &roomyStore{diskStore: ds, room: 100 << 30}
	s, err := newService(cfg, st, dir)
	if err != nil {
		t.Fatal(err)
	}
	r := &rig{t: t, s: s, store: st, dir: dir, clock: time.Date(2026, 10, 28, 12, 0, 0, 0, time.UTC)}
	s.now = func() time.Time { return r.clock }
	r.srv = httptest.NewServer(s.routes())
	t.Cleanup(r.srv.Close)
	return r
}

func randHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func sha(s string) string {
	b, _ := hex.DecodeString(s)
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

func grind(id string, size int64, bits int) uint64 {
	for n := uint64(0); ; n++ {
		if powOK(id, size, n, bits) {
			return n
		}
	}
}

type upload struct {
	id, own string
	tokens  []string
	size    int64
	body    []byte
}

func newUpload(chunks, recipients int) *upload {
	u := &upload{id: randHex(16), own: randHex(32), size: int64(chunks) * chunkSealed}
	for i := 0; i < recipients; i++ {
		u.tokens = append(u.tokens, randHex(32))
	}
	u.body = make([]byte, u.size)
	_, _ = rand.Read(u.body)
	return u
}

// one that only ever begins: no bytes behind it
func newBare(chunks int) *upload {
	return &upload{id: randHex(16), own: randHex(32), size: int64(chunks) * chunkSealed, tokens: []string{randHex(32)}}
}

func (u *upload) req() newReq {
	got := []string{}
	for _, t := range u.tokens {
		got = append(got, sha(t))
	}
	return newReq{ID: u.id, Size: u.size, Got: got, Own: sha(u.own), Pow: grind(u.id, u.size, powBits(testBits, u.size))}
}

func (r *rig) do(method, path string, body []byte, hdr map[string]string) (int, []byte) {
	r.t.Helper()
	req, err := http.NewRequest(method, r.srv.URL+path, bytes.NewReader(body))
	if err != nil {
		r.t.Fatal(err)
	}
	for k, v := range hdr {
		req.Header.Set(k, v)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		r.t.Fatal(err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, b
}

func (r *rig) postJSON(path string, v any) (int, map[string]any) {
	r.t.Helper()
	b, _ := json.Marshal(v)
	code, out := r.do("POST", path, b, nil)
	var m map[string]any
	_ = json.Unmarshal(out, &m)
	return code, m
}

func (r *rig) begin(u *upload) (int, map[string]any) {
	return r.postJSON("/files/new", u.req())
}

func (r *rig) put(u *upload, n int) int {
	end := min(int64(n+1)*partSize, u.size)
	code, _ := r.do("PUT", fmt.Sprintf("/files/%s/%d", u.id, n), u.body[int64(n)*partSize:end], map[string]string{ownHeader: u.own})
	return code
}

func (r *rig) end(u *upload) (int, map[string]any) {
	code, b := r.do("POST", "/files/"+u.id+"/end", nil, map[string]string{ownHeader: u.own})
	var m map[string]any
	_ = json.Unmarshal(b, &m)
	return code, m
}

// a recipient's download, by its token
func (r *rig) get(u *upload, i int, hdr map[string]string) (int, []byte) {
	h := map[string]string{tokenHeader: u.tokens[i]}
	for k, v := range hdr {
		h[k] = v
	}
	return r.do("GET", "/files/"+u.id, nil, h)
}

func (r *rig) sendAll(u *upload) {
	r.t.Helper()
	if code, m := r.begin(u); code != 200 {
		r.t.Fatalf("new: %d %v", code, m)
	}
	parts := int((u.size + partSize - 1) / partSize)
	for n := 0; n < parts; n++ {
		if code := r.put(u, n); code != 200 {
			r.t.Fatalf("part %d: %d", n, code)
		}
	}
	if code, m := r.end(u); code != 200 {
		r.t.Fatalf("end: %d %v", code, m)
	}
}

func TestPadChunks(t *testing.T) {
	for n := 1; n <= 2000; n++ {
		p := padChunks(n)
		if p < n || (n > 16 && p*8 > n*9) {
			t.Fatalf("padChunks(%d) = %d", n, p)
		}
		if padChunks(p) != p {
			t.Fatalf("padChunks(%d) = %d is not its own pad", n, p)
		}
	}
	// 50 MB: 800 chunks, stored as 832
	if got := maxSealed(50 << 20); got != 832*chunkSealed {
		t.Fatalf("maxSealed(50 MB) = %d", got)
	}
	if partSize < 5<<20 {
		t.Fatalf("a part of %d bytes is under the s3 floor", partSize)
	}
}

func TestPow(t *testing.T) {
	id := randHex(16)
	n := grind(id, 3*chunkSealed, 10)
	if !powOK(id, 3*chunkSealed, n, 10) {
		t.Fatal("ground nonce does not hold")
	}
	other := randHex(16)
	held := 0
	for k := uint64(0); k < 64; k++ {
		if powOK(other, 3*chunkSealed, n+k, 10) && powOK(id, 4*chunkSealed, n+k, 10) {
			held++
		}
	}
	if held > 1 {
		t.Fatal("work for one file holds for another")
	}
	// a bigger file costs more
	if powBits(18, 100<<10) != 18 || powBits(18, 50<<20) != 24 {
		t.Fatalf("bits: %d %d", powBits(18, 100<<10), powBits(18, 50<<20))
	}
}

// what the service is told of an upload: nothing two uploads of one
// sender have in common, and nothing it keeps names a sender
func TestTwoUploadsShareNothing(t *testing.T) {
	a, b := newUpload(3, 1), newUpload(3, 1)
	ja, _ := json.Marshal(a.req())
	jb, _ := json.Marshal(b.req())
	var ma, mb map[string]any
	_ = json.Unmarshal(ja, &ma)
	_ = json.Unmarshal(jb, &mb)
	for k := range ma {
		if k == "size" {
			continue
		}
		if fmt.Sprint(ma[k]) == fmt.Sprint(mb[k]) {
			t.Fatalf("both uploads carry the same %s", k)
		}
	}
	keys := []string{}
	for k := range ma {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	if fmt.Sprint(keys) != "[got id own pow size]" {
		t.Fatalf("an upload says %v", keys)
	}
}

// a file in two parts goes up, comes down by range, and goes once its one
// recipient says it has it
func TestUploadDownloadGot(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(padChunks(100), 1)
	r.sendAll(u)
	if code, _ := r.do("GET", "/files/"+u.id, nil, nil); code != 403 {
		t.Fatalf("a download with no token: %d", code)
	}
	code, body := r.get(u, 0, nil)
	if code != 200 || !bytes.Equal(body, u.body) {
		t.Fatalf("get: %d, %d bytes", code, len(body))
	}
	code, body = r.get(u, 0, map[string]string{"Range": fmt.Sprintf("bytes=%d-", partSize+7)})
	if code != 206 || !bytes.Equal(body, u.body[partSize+7:]) {
		t.Fatalf("range: %d, %d bytes", code, len(body))
	}
	if code, m := r.postJSON("/files/"+u.id+"/got", tokenReq{T: randHex(32)}); code != 403 {
		t.Fatalf("a token nobody was given: %d %v", code, m)
	}
	if code, m := r.postJSON("/files/"+u.id+"/got", tokenReq{T: u.tokens[0]}); code != 200 || m["left"] != nil {
		t.Fatalf("got: %d %v", code, m)
	}
	if code, _ := r.get(u, 0, nil); code != 404 {
		t.Fatalf("a taken file still answers %d", code)
	}
	if _, err := os.Stat(filepath.Join(r.dir, "blobs", u.id)); !os.IsNotExist(err) {
		t.Fatalf("a taken file is still on disk: %v", err)
	}
	// its record stays its week: its id and its day, nothing more
	rec, _ := os.ReadFile(filepath.Join(r.dir, "index", u.id+".json"))
	var kept map[string]any
	_ = json.Unmarshal(rec, &kept)
	keys := []string{}
	for k := range kept {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	if fmt.Sprint(keys) != "[at gone id]" || int64(kept["at"].(float64))%86400 != 0 {
		t.Fatalf("a taken file's record: %s", rec)
	}
}

// a group file goes once every member has it, each token counted once
func TestEveryRecipientBeforeItGoes(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(3, 3)
	r.sendAll(u)
	for i, tok := range []string{u.tokens[0], u.tokens[0], u.tokens[1]} {
		if code, m := r.postJSON("/files/"+u.id+"/got", tokenReq{T: tok}); code != 200 {
			t.Fatalf("got %d: %d %v", i, code, m)
		}
		if code, _ := r.get(u, 2, nil); code != 200 {
			t.Fatalf("the file went with a member still to take it (%d)", i)
		}
	}
	r.postJSON("/files/"+u.id+"/got", tokenReq{T: u.tokens[2]})
	if code, _ := r.get(u, 2, nil); code != 404 {
		t.Fatal("the file stayed after every member took it")
	}
}

// a send cut off asks again under the same id and is told what is in
func TestResumeAndClash(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(padChunks(200), 1)
	r.begin(u)
	if code := r.put(u, 1); code != 200 {
		t.Fatalf("part 1: %d", code)
	}
	code, m := r.begin(u)
	if code != 200 || fmt.Sprint(m["have"]) != "[1]" {
		t.Fatalf("again: %d %v", code, m)
	}
	if code, m := r.end(u); code != 409 || m["e"] != "clash" || fmt.Sprint(m["have"]) != "[1]" {
		t.Fatalf("end with parts missing: %d %v", code, m)
	}
	if code, _ := r.get(u, 0, nil); code != 404 {
		t.Fatalf("an unfinished file answers %d", code)
	}
	other := *u
	other.own = randHex(32)
	if code, _ := r.begin(&other); code != 409 {
		t.Fatalf("another sender's file under the same id: %d", code)
	}
	code, m = r.do2(t, "GET", "/files/"+u.id+"/have", nil)
	if code != 403 {
		t.Fatalf("have with no token: %d %v", code, m)
	}
	code, m = r.do2(t, "GET", "/files/"+u.id+"/have", map[string]string{ownHeader: u.own})
	if code != 200 || fmt.Sprint(m["have"]) != "[1]" {
		t.Fatalf("have: %d %v", code, m)
	}
}

func (r *rig) do2(t *testing.T, method, path string, hdr map[string]string) (int, map[string]any) {
	code, b := r.do(method, path, nil, hdr)
	var m map[string]any
	_ = json.Unmarshal(b, &m)
	return code, m
}

func TestPartShape(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(3, 1)
	r.begin(u)
	own := map[string]string{ownHeader: u.own}
	if code, _ := r.do("PUT", "/files/"+u.id+"/0", u.body, nil); code != 403 {
		t.Fatalf("a part with no token: %d", code)
	}
	if code, _ := r.do("PUT", "/files/"+u.id+"/0", u.body, map[string]string{ownHeader: u.tokens[0]}); code != 403 {
		t.Fatalf("a part with a recipient's token: %d", code)
	}
	if code, _ := r.do("PUT", "/files/"+u.id+"/0", u.body[:100], own); code != 400 {
		t.Fatalf("a short part: %d", code)
	}
	if code, _ := r.do("PUT", "/files/"+u.id+"/1", u.body, own); code != 400 {
		t.Fatalf("a part past the end: %d", code)
	}
	if code, _ := r.do("PUT", "/files/"+randHex(16)+"/0", u.body, own); code != 404 {
		t.Fatalf("a part of no file: %d", code)
	}
	if code, _ := r.end(&upload{id: u.id, own: randHex(32)}); code != 403 {
		t.Fatalf("an end by someone else: %d", code)
	}
	// the writer a refused part took is free again
	if code := r.put(u, 0); code != 200 {
		t.Fatalf("the part after the refusals: %d", code)
	}
}

// a body that stops part way marks nothing and leaves the slot free
func TestPartCutShort(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(padChunks(100), 1)
	r.begin(u)
	want, w, err := r.s.partSlot(u.id, 0, u.own, func() {})
	if err != nil {
		t.Fatal(err)
	}
	if err := r.s.putPart(u.id, 0, bytes.NewReader(u.body[:1000]), want, w); err != errShape {
		t.Fatalf("a short body: %v", err)
	}
	if b, _, _ := r.s.have(u.id, u.own); len(b.have) != 0 {
		t.Fatal("a part cut short was marked")
	}
	if code := r.put(u, 0); code != 200 {
		t.Fatalf("the part again: %d", code)
	}
}

// one writer a file. a writer still on it is a PUT whose circuit died: the
// owner's next PUT stops it and takes over, and the stopped one marks nothing
func TestOwnerTakesOverAStalledPart(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(padChunks(200), 1)
	r.begin(u)
	// a PUT that sends a few bytes and then nothing, as over a dead circuit
	pr, pw := io.Pipe()
	stalled := make(chan int, 1)
	go func() {
		req, _ := http.NewRequest("PUT", fmt.Sprintf("%s/files/%s/0", r.srv.URL, u.id), pr)
		req.ContentLength = partSize
		req.Header.Set(ownHeader, u.own)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			stalled <- -1
			return
		}
		resp.Body.Close()
		stalled <- resp.StatusCode
	}()
	pw.Write(u.body[:1000])
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		r.s.mu.Lock()
		w := r.s.drops[u.id].w
		r.s.mu.Unlock()
		if w != nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	start := time.Now()
	if code := r.put(u, 0); code != 200 {
		t.Fatalf("the owner's next PUT: %d", code)
	}
	if time.Since(start) > 4*time.Second {
		t.Fatal("the next PUT waited out the stalled one")
	}
	pw.CloseWithError(io.ErrClosedPipe)
	if code := <-stalled; code == 200 {
		t.Fatal("the stalled PUT was taken")
	}
	if b, _, _ := r.s.have(u.id, u.own); fmt.Sprint(b.have) != "[0]" {
		t.Fatalf("parts in: %v", b.have)
	}
	// and someone else's PUT takes nothing over
	if _, _, err := r.s.partSlot(u.id, 1, randHex(32), func() {}); err != errWork {
		t.Fatalf("a stranger's PUT: %v", err)
	}
}

// a part that lands after its file went takes its bytes with it
func TestPartAfterTheFileWent(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(3, 1)
	r.begin(u)
	want, w, _ := r.s.partSlot(u.id, 0, u.own, func() {})
	r.s.mu.Lock()
	r.s.forget(u.id)
	r.s.mu.Unlock()
	if err := r.s.putPart(u.id, 0, bytes.NewReader(u.body), want, w); err != errGone {
		t.Fatalf("a part of a file gone: %v", err)
	}
	if _, err := os.Stat(filepath.Join(r.dir, "blobs", u.id)); !os.IsNotExist(err) {
		t.Fatal("the late part stayed on disk")
	}
	// and bytes no record names go on the next sweep, not at a restart
	stray := filepath.Join(r.dir, "blobs", randHex(16))
	_ = os.WriteFile(stray, []byte("x"), 0o600)
	r.s.sweepOrphans(filepath.Join(r.dir, "blobs"))
	if _, err := os.Stat(stray); !os.IsNotExist(err) {
		t.Fatal("an orphan stayed")
	}
}

func TestNewShape(t *testing.T) {
	r := newRig(t, testConfig())
	bad := []func(*newReq){
		func(q *newReq) { q.ID = "nothex" },
		func(q *newReq) { q.Size = chunkSealed + 1 },
		func(q *newReq) { q.Size = 17 * chunkSealed },
		func(q *newReq) { q.Got = nil },
		func(q *newReq) { q.Got = make([]string, maxGot+1) },
		func(q *newReq) {
			for powOK(q.ID, q.Size, q.Pow, powBits(testBits, q.Size)) {
				q.Pow++
			}
		},
		// work for another file
		func(q *newReq) { q.ID = randHex(16) },
	}
	for i, f := range bad {
		u := newUpload(3, 1)
		q := u.req()
		f(&q)
		if code, m := r.postJSON("/files/new", q); code == 200 {
			t.Fatalf("case %d taken: %v", i, m)
		}
	}
	u := newUpload(int(maxSealed(50<<20)/chunkSealed)+64, 1)
	q := u.req()
	if code, m := r.postJSON("/files/new", q); code != 413 || m["e"] != "big" {
		t.Fatalf("over the limit: %d %v", code, m)
	}
	u = newUpload(int(maxSealed(50<<20)/chunkSealed), 1)
	if code, m := r.begin(u); code != 200 {
		t.Fatalf("at the limit: %d %v", code, m)
	}
}

// the day's count of files raises the work, and the next day starts again
func TestEveryoneDayFiles(t *testing.T) {
	cfg := testConfig()
	cfg.dayFiles = 2
	r := newRig(t, cfg)
	r.begin(newUpload(2, 1))
	r.begin(newUpload(2, 1))
	// past the day's count of files it costs more work, not a refusal
	if code, m := r.begin(newUpload(2, 1)); code != 429 || m["e"] != "work" {
		t.Fatalf("past the day's files: %d %v", code, m)
	}
	r.clock = r.clock.Add(24 * time.Hour)
	if code, _ := r.begin(newUpload(2, 1)); code != 200 {
		t.Fatalf("the next day: %d", code)
	}
}

func TestEveryoneDayLimit(t *testing.T) {
	cfg := testConfig()
	cfg.dayBytes = 5 * chunkSealed
	r := newRig(t, cfg)
	a := newUpload(3, 1)
	r.begin(a)
	if code, _ := r.begin(newUpload(3, 1)); code != 200 {
		t.Fatal("declared bytes used everyone's day")
	}
	r.put(a, 0)
	if code, m := r.begin(newUpload(3, 1)); code != 503 || m["e"] != "busy" {
		t.Fatalf("past everyone's day: %d %v", code, m)
	}
}

// begins with nothing behind them hold their room for minutes: an honest
// file gets in once they stop, and they never touch the day's bytes
func TestFloodOfBeginsLeavesRoom(t *testing.T) {
	cfg := testConfig()
	cfg.dayBytes = 1 << 30
	r := newRig(t, cfg)
	r.store.room = (5 << 30) + 40*int64ToU(maxSealed(50<<20))
	big := int(maxSealed(50<<20) / chunkSealed)
	for i := 0; i < 40; i++ {
		if code, m := r.begin(newBare(big)); code != 200 {
			t.Fatalf("begin %d: %d %v", i, code, m)
		}
	}
	honest := newUpload(big, 1)
	if code, _ := r.begin(honest); code != 507 {
		t.Fatalf("the flood holds the room for now: %d", code)
	}
	r.clock = r.clock.Add(16 * time.Minute)
	r.s.sweep()
	if code, m := r.begin(honest); code != 200 {
		t.Fatalf("after the flood stopped: %d %v", code, m)
	}
	if r.s.today != 0 || r.s.open != 1 || r.s.coming != honest.size {
		t.Fatalf("today %d, open %d, coming %d", r.s.today, r.s.open, r.s.coming)
	}
	// a file that keeps sending keeps its room past the idle time
	r.put(honest, 0)
	r.clock = r.clock.Add(10 * time.Minute)
	r.put(honest, 1)
	r.clock = r.clock.Add(10 * time.Minute)
	if r.s.sweep() != 0 {
		t.Fatal("a file still sending was swept")
	}
}

func int64ToU(n int64) uint64 { return uint64(n) }

// the records have a hard cap: each is memory
func TestRecordCap(t *testing.T) {
	cfg := testConfig()
	cfg.maxFiles = 2
	r := newRig(t, cfg)
	r.sendAll(newUpload(3, 1))
	r.sendAll(newUpload(3, 1))
	if code, _ := r.begin(newUpload(3, 1)); code != 503 {
		t.Fatalf("past the records: %d", code)
	}
}

// past half of a cap a new file costs more work, one bit each tenth over:
// the service says how much and the sender works again. nothing is refused
// for the count of files alone
func TestWorkRisesWithLoad(t *testing.T) {
	cfg := testConfig()
	cfg.dayFiles = 10
	r := newRig(t, cfg)
	for i := 0; i < 6; i++ {
		if code, _ := r.begin(newBare(3)); code != 200 {
			t.Fatalf("begin %d: %d", i, code)
		}
	}
	u := newBare(3)
	base := powBits(testBits, u.size)
	code, m := r.begin(u)
	if code != 429 || m["e"] != "work" || int(m["bits"].(float64)) != base+1 {
		t.Fatalf("at 60%%: %d %v", code, m)
	}
	q := u.req()
	q.Pow = grind(u.id, u.size, base+1)
	if code, m := r.postJSON("/files/new", q); code != 200 {
		t.Fatalf("with the work asked: %d %v", code, m)
	}
	for i := 0; i < 8; i++ {
		v := newBare(3)
		q := v.req()
		q.Pow = grind(v.id, v.size, r.s.bitsNow(v.size))
		r.postJSON("/files/new", q)
	}
	// past the day's count the bits keep rising instead of a refusal
	if need := r.s.bitsNow(3 * chunkSealed); need < base+7 {
		t.Fatalf("at 150%%: %d bits", need)
	}
	// coming bytes weigh by what was declared, not by the count
	cfg = testConfig()
	cfg.maxComing = 10 * chunkSealed
	r = newRig(t, cfg)
	r.begin(newBare(8))
	if need := r.s.bitsNow(3 * chunkSealed); need != powBits(testBits, 3*chunkSealed)+3 {
		t.Fatalf("80%% of the coming bytes: %d bits", need)
	}
}

// the work has a cap, whatever the size
func TestWorkCap(t *testing.T) {
	r := newRig(t, testConfig())
	r.s.cfg.powBase = 18
	if b := r.s.bitsNow(50 << 20); b != 20 {
		t.Fatalf("50 MB asks %d bits", b)
	}
}

// a begin of a file the service holds needs no work: a resume, a resend,
// a group's owed members
func TestNoWorkToGoOn(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(padChunks(100), 1)
	r.begin(u)
	q := u.req()
	for powOK(q.ID, q.Size, q.Pow, powBits(testBits, q.Size)) {
		q.Pow++
	}
	if code, m := r.postJSON("/files/new", q); code != 200 {
		t.Fatalf("again with no work: %d %v", code, m)
	}
	other := newUpload(3, 1)
	q = other.req()
	for powOK(q.ID, q.Size, q.Pow, powBits(testBits, q.Size)) {
		q.Pow++
	}
	if code, _ := r.postJSON("/files/new", q); code != 429 {
		t.Fatalf("a new file with no work: %d", code)
	}
}

// a file of one part sends it at once or lets its room go in minutes
func TestSmallFileIdlesFast(t *testing.T) {
	r := newRig(t, testConfig())
	small, big := newBare(3), newBare(padChunks(200))
	r.begin(small)
	r.begin(big)
	r.clock = r.clock.Add(3 * time.Minute)
	if n := r.s.sweep(); n != 1 {
		t.Fatalf("swept %d", n)
	}
	if r.s.drops[small.id] != nil || r.s.drops[big.id] == nil {
		t.Fatal("the wrong one went")
	}
}

// every recipient said got: the bytes go, the record says so, and a send of
// the same message again is told it went instead of sending it again
func TestGotThenSentAgain(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(3, 1)
	r.sendAll(u)
	r.postJSON("/files/"+u.id+"/got", tokenReq{T: u.tokens[0]})
	code, m := r.begin(u)
	if code != 200 || m["gone"] != true {
		t.Fatalf("sent again: %d %v", code, m)
	}
	if code := r.put(u, 0); code != 404 {
		t.Fatalf("a part of a file every recipient has: %d", code)
	}
	if r.s.held != 0 {
		t.Fatalf("held %d after the got", r.s.held)
	}
}

// each token is served three times the file at most, ranges and all, and
// one member's downloads cost the others nothing
func TestDownloadsHaveAnEnd(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(3, 2)
	r.sendAll(u)
	// attempts that die early cost only what they were served
	for i := 0; i < 5; i++ {
		if code, _ := r.get(u, 0, map[string]string{"Range": "bytes=0-99"}); code != 206 {
			t.Fatalf("a short try %d: %d", i, code)
		}
	}
	for i := 0; i < 2; i++ {
		if code, _ := r.get(u, 0, nil); code != 200 {
			t.Fatalf("download %d: %d", i, code)
		}
	}
	if code, _ := r.get(u, 0, map[string]string{"Range": "bytes=1-"}); code != 206 {
		t.Fatalf("a resume: %d", code)
	}
	if code, _ := r.get(u, 0, map[string]string{"Range": "bytes=1-"}); code != 404 {
		t.Fatalf("past three times the file by range: %d", code)
	}
	if code, _ := r.get(u, 1, nil); code != 200 {
		t.Fatalf("the other member: %d", code)
	}
}

// under the floor no new file is taken, counting what is still coming in;
// the files already there go on
func TestDiskGuard(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(padChunks(200), 1)
	r.store.room = (5 << 30) + uint64(u.size) + 100
	if code, _ := r.begin(u); code != 200 {
		t.Fatalf("over the floor: %d", code)
	}
	v := newUpload(3, 1)
	if code, m := r.begin(v); code != 507 || m["e"] != "full" {
		t.Fatalf("an upload still coming counts: %d %v", code, m)
	}
	if code := r.put(u, 0); code != 200 {
		t.Fatalf("the file already begun goes on: %d", code)
	}
	r.store.err = os.ErrPermission
	r.store.room = 100 << 30
	if code, _ := r.begin(v); code != 507 {
		t.Fatalf("free space not read: %d", code)
	}
	cfg := testConfig()
	cfg.quota = 5 * chunkSealed
	r = newRig(t, cfg)
	r.begin(newUpload(3, 1))
	if code, _ := r.begin(newUpload(3, 1)); code != 507 {
		t.Fatalf("past the quota: %d", code)
	}
}

func TestSenderTakesItBack(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(3, 1)
	r.sendAll(u)
	if code, _ := r.postJSON("/files/"+u.id+"/drop", tokenReq{T: u.tokens[0]}); code != 403 {
		t.Fatalf("a recipient's token drops it: %d", code)
	}
	if code, _ := r.postJSON("/files/"+u.id+"/drop", tokenReq{T: u.own}); code != 200 {
		t.Fatalf("drop: %d", code)
	}
	if code, _ := r.get(u, 0, nil); code != 404 {
		t.Fatal("a dropped file still answers")
	}
}

// a week for a whole file, a day for one that never finished
func TestSweep(t *testing.T) {
	r := newRig(t, testConfig())
	whole, half := newUpload(3, 1), newUpload(padChunks(100), 1)
	r.sendAll(whole)
	r.begin(half)
	r.put(half, 0)
	r.clock = r.clock.Add(25 * time.Hour)
	if n := r.s.sweep(); n != 1 {
		t.Fatalf("swept %d after a day", n)
	}
	if code, _ := r.get(whole, 0, nil); code != 200 {
		t.Fatal("a whole file went after a day")
	}
	if _, err := os.Stat(filepath.Join(r.dir, "blobs", half.id)); !os.IsNotExist(err) {
		t.Fatal("an unfinished file's bytes stayed")
	}
	r.clock = r.clock.Add(6 * 24 * time.Hour)
	if n := r.s.sweep(); n != 1 {
		t.Fatalf("swept %d after a week", n)
	}
	if code, _ := r.get(whole, 0, nil); code != 404 {
		t.Fatal("a file stayed past its week")
	}
}

// a restart keeps every file, drops a record cut short, one too large and
// bytes no record names, and never holds more records than it may
func TestRestart(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(3, 1)
	r.sendAll(u)
	broken := randHex(16)
	_ = os.WriteFile(filepath.Join(r.dir, "index", broken+".json"), []byte("{"), 0o600)
	_ = os.WriteFile(filepath.Join(r.dir, "blobs", broken), []byte("x"), 0o600)
	huge := randHex(16)
	_ = os.WriteFile(filepath.Join(r.dir, "index", huge+".json"), bytes.Repeat([]byte(" "), maxRecord+10), 0o600)
	orphan := randHex(16)
	_ = os.WriteFile(filepath.Join(r.dir, "blobs", orphan), []byte("x"), 0o600)
	s, err := newService(testConfig(), r.store, r.dir)
	if err != nil {
		t.Fatal(err)
	}
	s.sweepOrphans(filepath.Join(r.dir, "blobs"))
	if d := s.drops[u.id]; d == nil || !d.ended {
		t.Fatal("a whole file was lost in the restart")
	}
	if s.held != u.size || s.open != 0 {
		t.Fatalf("held %d open %d after the restart", s.held, s.open)
	}
	for _, id := range []string{broken, orphan} {
		if _, err := os.Stat(filepath.Join(r.dir, "blobs", id)); !os.IsNotExist(err) {
			t.Fatalf("bytes with no record stayed: %s", id)
		}
	}
	if _, err := os.Stat(filepath.Join(r.dir, "index", huge+".json")); !os.IsNotExist(err) {
		t.Fatal("a record too large stayed")
	}
	for i := 0; i < 5; i++ {
		r.sendAll(newUpload(3, 1))
	}
	cfg := testConfig()
	cfg.maxFiles = 3
	s, err = newService(cfg, r.store, r.dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(s.drops) != 3 {
		t.Fatalf("a start held %d records, the cap is 3", len(s.drops))
	}
	// a file that stopped sending while the service was down goes at start
	cfg = testConfig()
	half := newUpload(padChunks(100), 1)
	r.begin(half)
	r.clock = r.clock.Add(time.Hour)
	s, _ = newService(cfg, r.store, r.dir)
	s.now = func() time.Time { return r.clock }
	if s.drops[half.id] != nil && !s.expired(s.drops[half.id], r.clock) {
		t.Fatal("an idle upload outlived the restart")
	}
}

func TestErrorsNameNoPath(t *testing.T) {
	_, err := os.Open(filepath.Join(t.TempDir(), "blobs", strings.Repeat("ab", 16)))
	if k := errKind(err); strings.Contains(k, "ab") || !strings.Contains(k, "open") {
		t.Fatalf("errKind: %q", k)
	}
}

// what a sender and a recipient do leaves no line in the log, and what is
// on disk holds no sender key
func TestNothingPerFile(t *testing.T) {
	var buf bytes.Buffer
	log.SetOutput(&buf)
	defer log.SetOutput(os.Stderr)
	r := newRig(t, testConfig())
	u := newUpload(3, 1)
	r.sendAll(u)
	r.get(u, 0, nil)
	rec, _ := os.ReadFile(filepath.Join(r.dir, "index", u.id+".json"))
	var keys map[string]any
	_ = json.Unmarshal(rec, &keys)
	for k := range keys {
		if !strings.Contains(" id size parts ended gone got taken own at last ", " "+k+" ") {
			t.Fatalf("a record keeps %s", k)
		}
	}
	r.postJSON("/files/"+u.id+"/got", tokenReq{T: u.tokens[0]})
	if buf.Len() != 0 {
		t.Fatalf("logged: %q", buf.String())
	}
	r.s.report()
	if strings.Contains(buf.String(), u.id) || !strings.Contains(buf.String(), "1 new") {
		t.Fatalf("report: %q", buf.String())
	}
}
