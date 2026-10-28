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
	"strings"
	"sync"
	"testing"
	"time"
)

const testBits = 6

func testConfig() config {
	return config{
		maxPlain:       50 << 20,
		floor:          5 << 30,
		senderDayBytes: 1 << 30,
		senderDayFiles: 300,
		dayBytes:       100 << 30,
		keep:           7 * 24 * time.Hour,
		unfinished:     24 * time.Hour,
		powBits:        testBits,
		streams:        4,
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

func grind(day, who string, bits int) uint64 {
	for n := uint64(0); ; n++ {
		if powOK(day, who, n, bits) {
			return n
		}
	}
}

type upload struct {
	id, own, who string
	tokens       []string
	size         int64
	body         []byte
}

func newUpload(chunks, recipients int) *upload {
	u := &upload{id: randHex(16), own: randHex(32), who: randHex(32), size: int64(chunks) * chunkSealed}
	for i := 0; i < recipients; i++ {
		u.tokens = append(u.tokens, randHex(32))
	}
	u.body = make([]byte, u.size)
	_, _ = rand.Read(u.body)
	return u
}

func (u *upload) req(day string) newReq {
	got := []string{}
	for _, t := range u.tokens {
		got = append(got, sha(t))
	}
	return newReq{ID: u.id, Size: u.size, Got: got, Own: sha(u.own), Day: day, Who: u.who, Pow: grind(day, u.who, testBits)}
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
	return r.postJSON("/files/new", u.req("2026-10-28"))
}

func (r *rig) put(u *upload, n int) int {
	end := min(int64(n+1)*partSize, u.size)
	code, _ := r.do("PUT", fmt.Sprintf("/files/%s/%d", u.id, n), u.body[int64(n)*partSize:end], nil)
	return code
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
	if code, m := r.postJSON("/files/"+u.id+"/end", nil); code != 200 {
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
	who := randHex(32)
	n := grind("2026-10-28", who, 10)
	if !powOK("2026-10-28", who, n, 10) {
		t.Fatal("ground nonce does not hold")
	}
	if powOK("2026-10-29", who, n, 10) && powOK("2026-10-29", who, n+1, 10) {
		t.Fatal("work for one day holds for another")
	}
	now := time.Date(2026, 10, 28, 23, 59, 0, 0, time.UTC)
	if !dayOK("2026-10-29", now) || !dayOK("2026-10-27", now) || dayOK("2026-10-30", now) {
		t.Fatal("days around now")
	}
}

// a file in two parts goes up, comes down by range, and goes once its one
// recipient says it has it
func TestUploadDownloadGot(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(padChunks(100), 1)
	r.sendAll(u)
	code, body := r.do("GET", "/files/"+u.id, nil, nil)
	if code != 200 || !bytes.Equal(body, u.body) {
		t.Fatalf("get: %d, %d bytes", code, len(body))
	}
	code, body = r.do("GET", "/files/"+u.id, nil, map[string]string{"Range": fmt.Sprintf("bytes=%d-", partSize+7)})
	if code != 206 || !bytes.Equal(body, u.body[partSize+7:]) {
		t.Fatalf("range: %d, %d bytes", code, len(body))
	}
	if code, m := r.postJSON("/files/"+u.id+"/got", tokenReq{T: randHex(32)}); code != 403 {
		t.Fatalf("a token nobody was given: %d %v", code, m)
	}
	if code, m := r.postJSON("/files/"+u.id+"/got", tokenReq{T: u.tokens[0]}); code != 200 || m["left"].(float64) != 0 {
		t.Fatalf("got: %d %v", code, m)
	}
	if code, _ := r.do("GET", "/files/"+u.id, nil, nil); code != 404 {
		t.Fatalf("a taken file still answers %d", code)
	}
	if _, err := os.Stat(filepath.Join(r.dir, "blobs", u.id)); !os.IsNotExist(err) {
		t.Fatalf("a taken file is still on disk: %v", err)
	}
	if _, err := os.Stat(filepath.Join(r.dir, "index", u.id+".json")); !os.IsNotExist(err) {
		t.Fatalf("a taken file's record is still on disk: %v", err)
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
		if code, _ := r.do("GET", "/files/"+u.id, nil, nil); code != 200 {
			t.Fatalf("the file went with a member still to take it (%d)", i)
		}
	}
	r.postJSON("/files/"+u.id+"/got", tokenReq{T: u.tokens[2]})
	if code, _ := r.do("GET", "/files/"+u.id, nil, nil); code != 404 {
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
	if code, m := r.postJSON("/files/"+u.id+"/end", nil); code != 409 || m["e"] != "parts" {
		t.Fatalf("end with parts missing: %d %v", code, m)
	}
	if code, _ := r.do("GET", "/files/"+u.id, nil, nil); code != 404 {
		t.Fatalf("an unfinished file answers %d", code)
	}
	other := *u
	other.own = randHex(32)
	if code, _ := r.begin(&other); code != 409 {
		t.Fatalf("another sender's file under the same id: %d", code)
	}
	code, m = r.do2(t, "GET", "/files/"+u.id+"/have")
	if code != 200 || fmt.Sprint(m["have"]) != "[1]" {
		t.Fatalf("have: %d %v", code, m)
	}
}

func (r *rig) do2(t *testing.T, method, path string) (int, map[string]any) {
	code, b := r.do(method, path, nil, nil)
	var m map[string]any
	_ = json.Unmarshal(b, &m)
	return code, m
}

func TestPartShape(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(3, 1)
	r.begin(u)
	if code, _ := r.do("PUT", "/files/"+u.id+"/0", u.body[:100], nil); code != 400 {
		t.Fatalf("a short part: %d", code)
	}
	if code, _ := r.do("PUT", "/files/"+u.id+"/1", u.body, nil); code != 400 {
		t.Fatalf("a part past the end: %d", code)
	}
	if code, _ := r.do("PUT", "/files/"+randHex(16)+"/0", u.body, nil); code != 404 {
		t.Fatalf("a part of no file: %d", code)
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
		func(q *newReq) { q.Day = "2026-10-01" },
		func(q *newReq) {
			for powOK(q.Day, q.Who, q.Pow, testBits) {
				q.Pow++
			}
		},
	}
	for i, f := range bad {
		u := newUpload(3, 1)
		q := u.req("2026-10-28")
		f(&q)
		if code, m := r.postJSON("/files/new", q); code == 200 {
			t.Fatalf("case %d taken: %v", i, m)
		}
	}
	u := newUpload(int(maxSealed(50<<20)/chunkSealed)+64, 1)
	q := u.req("2026-10-28")
	if code, m := r.postJSON("/files/new", q); code != 413 || m["e"] != "big" {
		t.Fatalf("over the limit: %d %v", code, m)
	}
	u = newUpload(int(maxSealed(50<<20)/chunkSealed), 1)
	if code, m := r.begin(u); code != 200 {
		t.Fatalf("at the limit: %d %v", code, m)
	}
}

// one key a day sends this much, and the next day starts again
func TestSenderDayLimit(t *testing.T) {
	cfg := testConfig()
	cfg.senderDayFiles = 2
	r := newRig(t, cfg)
	who := randHex(32)
	for i := 0; i < 3; i++ {
		u := newUpload(2, 1)
		u.who = who
		code, m := r.begin(u)
		if i < 2 && code != 200 {
			t.Fatalf("file %d: %d %v", i, code, m)
		}
		if i == 2 && (code != 429 || m["e"] != "limit") {
			t.Fatalf("past the day's files: %d %v", code, m)
		}
	}
	other := newUpload(2, 1)
	if code, _ := r.begin(other); code != 200 {
		t.Fatalf("another key: %d", code)
	}
	r.clock = r.clock.Add(24 * time.Hour)
	u := newUpload(2, 1)
	u.who = who
	if code, m := r.postJSON("/files/new", u.req("2026-10-29")); code != 200 {
		t.Fatalf("the next day: %d %v", code, m)
	}
	cfg = testConfig()
	cfg.senderDayBytes = 5 * chunkSealed
	r = newRig(t, cfg)
	a, b := newUpload(3, 1), newUpload(3, 1)
	b.who = a.who
	r.begin(a)
	if code, _ := r.begin(b); code != 429 {
		t.Fatalf("past the day's bytes: %d", code)
	}
}

func TestEveryoneDayLimit(t *testing.T) {
	cfg := testConfig()
	cfg.dayBytes = 5 * chunkSealed
	r := newRig(t, cfg)
	r.begin(newUpload(3, 1))
	if code, m := r.begin(newUpload(3, 1)); code != 503 || m["e"] != "busy" {
		t.Fatalf("past everyone's day: %d %v", code, m)
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
	if code, _ := r.do("GET", "/files/"+u.id, nil, nil); code != 404 {
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
	if code, _ := r.do("GET", "/files/"+whole.id, nil, nil); code != 200 {
		t.Fatal("a whole file went after a day")
	}
	if _, err := os.Stat(filepath.Join(r.dir, "blobs", half.id)); !os.IsNotExist(err) {
		t.Fatal("an unfinished file's bytes stayed")
	}
	r.clock = r.clock.Add(6 * 24 * time.Hour)
	if n := r.s.sweep(); n != 1 {
		t.Fatalf("swept %d after a week", n)
	}
	if code, _ := r.do("GET", "/files/"+whole.id, nil, nil); code != 404 {
		t.Fatal("a file stayed past its week")
	}
}

// a restart keeps every file, drops a record cut short and bytes no
// record names
func TestRestart(t *testing.T) {
	r := newRig(t, testConfig())
	u := newUpload(3, 1)
	r.sendAll(u)
	broken := randHex(16)
	_ = os.WriteFile(filepath.Join(r.dir, "index", broken+".json"), []byte("{"), 0o600)
	_ = os.WriteFile(filepath.Join(r.dir, "blobs", broken), []byte("x"), 0o600)
	orphan := randHex(16)
	_ = os.WriteFile(filepath.Join(r.dir, "blobs", orphan), []byte("x"), 0o600)
	s, err := newService(testConfig(), r.store, r.dir)
	if err != nil {
		t.Fatal(err)
	}
	s.sweepOrphans(filepath.Join(r.dir, "blobs"))
	if d := s.drops[u.id]; d == nil || !d.Ended {
		t.Fatal("a whole file was lost in the restart")
	}
	for _, id := range []string{broken, orphan} {
		if _, err := os.Stat(filepath.Join(r.dir, "blobs", id)); !os.IsNotExist(err) {
			t.Fatalf("bytes with no record stayed: %s", id)
		}
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
	r.do("GET", "/files/"+u.id, nil, nil)
	rec, _ := os.ReadFile(filepath.Join(r.dir, "index", u.id+".json"))
	if strings.Contains(string(rec), u.who) {
		t.Fatal("the sender's key is on disk")
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
