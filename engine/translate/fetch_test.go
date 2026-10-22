// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"errors"
	"io"
	"math/rand/v2"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// a pair of two made-up files, one bigger than a chunk once gzipped
type fixture struct {
	m     *Manifest
	p     Pair
	raw   map[string][]byte // by name
	gz    map[string][]byte // by path and by mirror name
	mu    sync.Mutex
	reqs  []*http.Request
	serve func(w http.ResponseWriter, r *http.Request, body []byte)
	srv   *httptest.Server
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	fx := &fixture{raw: map[string][]byte{}, gz: map[string][]byte{}}
	rng := rand.New(rand.NewPCG(1, 2))
	mk := func(kind, name string, n int) File {
		raw := make([]byte, n)
		for i := range raw {
			// noisy enough that gzip barely shrinks it
			raw[i] = byte(rng.IntN(200))
		}
		var b bytes.Buffer
		zw := gzip.NewWriter(&b)
		zw.Write(raw)
		zw.Close()
		p := "zh-en/run/exported/" + name + ".gz"
		s1, s2 := sha256.Sum256(raw), sha256.Sum256(b.Bytes())
		fx.raw[name], fx.gz[p] = raw, b.Bytes()
		fx.gz[hexSum(s2[:])+".gz"] = b.Bytes()
		return File{Kind: kind, Name: name, Path: p, Size: int64(n), SHA256: hexSum(s1[:]),
			GzSize: int64(b.Len()), GzSHA256: hexSum(s2[:])}
	}
	fx.p = Pair{From: "zh", To: "en", Arch: "tiny", Files: []File{
		mk(KindModel, "model.zhen.intgemm.alphas.bin", Chunk*5/2),
		mk(KindVocab, "vocab.zhen.spm", 1000),
	}}
	fx.serve = func(w http.ResponseWriter, r *http.Request, body []byte) {
		http.ServeContent(w, r, "", time.Time{}, bytes.NewReader(body))
	}
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fx.mu.Lock()
		fx.reqs = append(fx.reqs, r)
		serve := fx.serve
		fx.mu.Unlock()
		body, ok := fx.gz[strings.TrimPrefix(r.URL.Path, "/m/")]
		if !ok {
			http.NotFound(w, r)
			return
		}
		serve(w, r, body)
	}))
	t.Cleanup(srv.Close)
	fx.srv = srv
	fx.m = &Manifest{Version: 1, Source: "https://source.invalid/", Base: srv.URL + "/m/", Pairs: []Pair{fx.p}}
	if err := fx.m.check(); err != nil {
		t.Fatal(err)
	}
	return fx
}

// the test server's own client, which trusts its certificate
func (fx *fixture) getter(t *testing.T) Getter { return HTTPGetter(fx.srv.Client()) }

func (fx *fixture) requests() []*http.Request {
	fx.mu.Lock()
	defer fx.mu.Unlock()
	return append([]*http.Request(nil), fx.reqs...)
}

func checkInstalled(t *testing.T, fx *fixture, dir string) {
	t.Helper()
	if !Installed(fx.p, dir) {
		t.Fatal("not installed")
	}
	for name, raw := range fx.raw {
		got, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil || !bytes.Equal(got, raw) {
			t.Fatalf("%s: %v", name, err)
		}
	}
	left, _ := filepath.Glob(filepath.Join(dir, "*.part"))
	tmp, _ := filepath.Glob(filepath.Join(dir, ".unpack-*"))
	if len(left)+len(tmp) != 0 {
		t.Fatalf("left behind %v %v", left, tmp)
	}
}

func TestFetchWhole(t *testing.T) {
	fx := newFixture(t)
	dir := t.TempDir()
	var last, total int64
	err := FetchPair(context.Background(), fx.getter(t), fx.m, fx.p, dir, func(d, n int64) { last, total = d, n })
	if err != nil {
		t.Fatal(err)
	}
	checkInstalled(t, fx, dir)
	if last != fx.p.GzBytes() || total != fx.p.GzBytes() {
		t.Fatalf("progress %d of %d, want %d", last, total, fx.p.GzBytes())
	}
	reqs := fx.requests()
	model := fx.p.Files[0]
	want := int((model.GzSize+Chunk-1)/Chunk) + 1
	if len(reqs) != want {
		t.Fatalf("%d requests, want %d", len(reqs), want)
	}
	for _, r := range reqs {
		// nothing in a request but the file and the range
		if r.Header.Get("User-Agent") != "" || r.Header.Get("Range") == "" || r.URL.RawQuery != "" ||
			r.Header.Get("Cookie") != "" || r.Header.Get("Accept-Encoding") != "identity" {
			t.Fatalf("request says more than it needs to: %v %v", r.URL, r.Header)
		}
	}
	// a second call finds it all in place and asks for nothing
	if err := FetchPair(context.Background(), fx.getter(t), fx.m, fx.p, dir, nil); err != nil {
		t.Fatal(err)
	}
	if n := len(fx.requests()); n != want {
		t.Fatalf("refetched: %d requests", n)
	}
}

func TestFetchResumes(t *testing.T) {
	fx := newFixture(t)
	dir := t.TempDir()
	get := fx.getter(t)
	var offs []int64
	calls := 0
	cut := func(ctx context.Context, url string, off, n int64) (io.ReadCloser, int64, error) {
		calls++
		offs = append(offs, off)
		if calls == 2 {
			return nil, 0, errors.New("circuit closed")
		}
		return get(ctx, url, off, n)
	}
	if err := FetchPair(context.Background(), cut, fx.m, fx.p, dir, nil); err == nil {
		t.Fatal("no error from a cut")
	}
	model := fx.p.Files[0]
	part := filepath.Join(dir, model.Name+".gz.part")
	if st, err := os.Stat(part); err != nil || st.Size() != Chunk {
		t.Fatalf("part after a cut: %v %v", st, err)
	}
	if err := FetchPair(context.Background(), cut, fx.m, fx.p, dir, nil); err != nil {
		t.Fatal(err)
	}
	checkInstalled(t, fx, dir)
	// the second call went on from the first chunk, it did not start over
	if offs[2] != Chunk {
		t.Fatalf("resumed at %d, want %d (offsets %v)", offs[2], Chunk, offs)
	}
}

func TestFetchServerIgnoresRange(t *testing.T) {
	fx := newFixture(t)
	dir := t.TempDir()
	model := fx.p.Files[0]
	// half a chunk of the right bytes from an earlier try
	part := filepath.Join(dir, model.Name+".gz.part")
	if err := os.WriteFile(part, fx.gz[model.Path][:Chunk/2], 0o600); err != nil {
		t.Fatal(err)
	}
	fx.serve = func(w http.ResponseWriter, r *http.Request, body []byte) {
		w.Write(body)
	}
	if err := FetchPair(context.Background(), fx.getter(t), fx.m, fx.p, dir, nil); err != nil {
		t.Fatal(err)
	}
	checkInstalled(t, fx, dir)
}

func TestFetchRefusesTampered(t *testing.T) {
	fx := newFixture(t)
	dir := t.TempDir()
	fx.serve = func(w http.ResponseWriter, r *http.Request, body []byte) {
		bad := append([]byte(nil), body...)
		bad[len(bad)/2] ^= 1
		http.ServeContent(w, r, "", time.Time{}, bytes.NewReader(bad))
	}
	err := FetchPair(context.Background(), fx.getter(t), fx.m, fx.p, dir, nil)
	if !errors.Is(err, ErrHash) {
		t.Fatalf("took a changed file: %v", err)
	}
	model := fx.p.Files[0]
	for _, p := range []string{model.Name, model.Name + ".gz.part"} {
		if _, err := os.Stat(filepath.Join(dir, p)); !os.IsNotExist(err) {
			t.Fatalf("%s left: %v", p, err)
		}
	}
}

func TestFetchRefusesLonger(t *testing.T) {
	fx := newFixture(t)
	dir := t.TempDir()
	fx.serve = func(w http.ResponseWriter, r *http.Request, body []byte) {
		// a whole answer that is longer than the manifest says
		w.Write(append(append([]byte(nil), body...), "more"...))
	}
	err := FetchPair(context.Background(), fx.getter(t), fx.m, fx.p, dir, nil)
	if !errors.Is(err, ErrSize) {
		t.Fatalf("took a longer file: %v", err)
	}
}

func TestFetchUnpackedHashChecked(t *testing.T) {
	fx := newFixture(t)
	dir := t.TempDir()
	fx.p.Files[1].SHA256 = strings.Repeat("0", 64)
	err := FetchFile(context.Background(), fx.getter(t), fx.m.URL(fx.p.Files[1]), fx.p.Files[1], dir, nil)
	if !errors.Is(err, ErrHash) {
		t.Fatalf("unpacked file not checked: %v", err)
	}
	if left, _ := os.ReadDir(dir); len(left) != 0 {
		t.Fatalf("left %v", left)
	}
}

func TestFetchWrongContentRange(t *testing.T) {
	fx := newFixture(t)
	fx.serve = func(w http.ResponseWriter, r *http.Request, body []byte) {
		w.Header().Set("Content-Range", "bytes 7-9/100")
		w.WriteHeader(http.StatusPartialContent)
		w.Write(body[:3])
	}
	err := FetchPair(context.Background(), fx.getter(t), fx.m, fx.p, t.TempDir(), nil)
	if !errors.Is(err, ErrStatus) {
		t.Fatalf("took bytes from the wrong place: %v", err)
	}
}

func TestFetchStatus(t *testing.T) {
	fx := newFixture(t)
	fx.serve = func(w http.ResponseWriter, r *http.Request, body []byte) {
		http.Error(w, "gone", http.StatusForbidden)
	}
	err := FetchPair(context.Background(), fx.getter(t), fx.m, fx.p, t.TempDir(), nil)
	if !errors.Is(err, ErrStatus) {
		t.Fatalf("%v", err)
	}
}

func TestFetchCancelled(t *testing.T) {
	fx := newFixture(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err := FetchPair(ctx, fx.getter(t), fx.m, fx.p, t.TempDir(), nil)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("%v", err)
	}
	if len(fx.requests()) != 0 {
		t.Fatal("asked after a cancel")
	}
}

func TestRangeStart(t *testing.T) {
	for h, want := range map[string]int64{"bytes 0-9/10": 0, "bytes 1048576-2097151/3000000": 1 << 20} {
		if n, ok := rangeStart(h); !ok || n != want {
			t.Errorf("%q: %d %v", h, n, ok)
		}
	}
	for _, h := range []string{"", "bytes */10", "items 0-1/2", "bytes -5-9/10"} {
		if _, ok := rangeStart(h); ok {
			t.Errorf("took %q", h)
		}
	}
}
