// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// both directions of zh, served by a local server that can be made to stall
type bundleFix struct {
	m     *Manifest
	gz    map[string][]byte
	hits  atomic.Int64
	stall chan struct{}
	srv   *httptest.Server
}

func newBundleFix(t *testing.T) *bundleFix {
	t.Helper()
	bf := &bundleFix{gz: map[string][]byte{}}
	mk := func(dir, kind, name string, n int, seed byte) File {
		raw := bytes.Repeat([]byte{seed, seed + 1, seed + 7}, n/3+1)[:n]
		var b bytes.Buffer
		zw := gzip.NewWriter(&b)
		zw.Write(raw)
		zw.Close()
		p := dir + "/" + name + ".gz"
		bf.gz[p] = b.Bytes()
		s1, s2 := sha256.Sum256(raw), sha256.Sum256(b.Bytes())
		return File{Kind: kind, Name: name, Path: p, Size: int64(n), SHA256: hexSum(s1[:]),
			GzSize: int64(b.Len()), GzSHA256: hexSum(s2[:])}
	}
	zhen := Pair{From: "zh", To: "en", Arch: "tiny", Files: []File{
		mk("zh-en", KindModel, "model.zhen.bin", 5000, 1),
		mk("zh-en", KindVocab, "vocab.zhen.spm", 300, 2),
	}}
	enzh := Pair{From: "en", To: "zh", Arch: "tiny", Files: []File{
		mk("en-zh", KindModel, "model.enzh.bin", 4000, 3),
		mk("en-zh", KindSrcVocab, "srcvocab.enzh.spm", 200, 4),
		mk("en-zh", KindTrgVocab, "trgvocab.enzh.spm", 200, 5),
	}}
	bf.srv = httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bf.hits.Add(1)
		if bf.stall != nil {
			select {
			case <-bf.stall:
			case <-r.Context().Done():
				return
			}
		}
		body, ok := bf.gz[strings.TrimPrefix(r.URL.Path, "/m/")]
		if !ok {
			http.NotFound(w, r)
			return
		}
		http.ServeContent(w, r, "", time.Time{}, bytes.NewReader(body))
	}))
	t.Cleanup(bf.srv.Close)
	bf.m = &Manifest{Version: 1, Base: "https://models.invalid/m/", Pairs: []Pair{zhen, enzh}}
	if err := bf.m.check(); err != nil {
		t.Fatal(err)
	}
	return bf
}

func (bf *bundleFix) local(t *testing.T) *Manifest {
	t.Helper()
	m, err := bf.m.WithBase(bf.srv.URL + "/m")
	if err != nil {
		t.Fatal(err)
	}
	return m
}

func TestFetchBundleBothWays(t *testing.T) {
	bf := newBundleFix(t)
	dir := t.TempDir()
	m := bf.local(t)
	var last, total int64
	err := FetchBundle(context.Background(), HTTPGetter(bf.srv.Client()), m, "zh", dir, func(d, n int64) {
		if d < last {
			t.Errorf("progress went back from %d to %d", last, d)
		}
		last, total = d, n
	})
	if err != nil {
		t.Fatal(err)
	}
	gz, disk := m.BundleBytes("zh")
	if last != gz || total != gz {
		t.Fatalf("progress %d of %d, want %d", last, total, gz)
	}
	if !BundleInstalled(m, "zh", dir) {
		t.Fatal("not installed")
	}
	if disk != 5000+300+4000+200+200 {
		t.Fatalf("disk %d", disk)
	}
	for _, d := range []string{"zhen-tiny", "enzh-tiny"} {
		if _, err := os.Stat(filepath.Join(dir, d)); err != nil {
			t.Fatal(err)
		}
	}
	if err := RemoveBundle(m, "zh", dir); err != nil {
		t.Fatal(err)
	}
	if BundleInstalled(m, "zh", dir) {
		t.Fatal("still installed after removal")
	}
}

func TestFetchBundleUnknownLanguage(t *testing.T) {
	bf := newBundleFix(t)
	err := FetchBundle(context.Background(), HTTPGetter(bf.srv.Client()), bf.local(t), "fr", t.TempDir(), nil)
	if !errors.Is(err, ErrNoBundle) {
		t.Fatalf("got %v", err)
	}
	if bf.hits.Load() != 0 {
		t.Fatal("asked the server for a language it has nothing for")
	}
}

func TestWithBase(t *testing.T) {
	m, _ := Pinned()
	if got, _ := m.WithBase(""); got != m {
		t.Fatal("empty base changed the manifest")
	}
	c, err := m.WithBase("https://mirror.example/models")
	if err != nil {
		t.Fatal(err)
	}
	if c.Base != "https://mirror.example/models/" || m.Base == c.Base {
		t.Fatalf("base %q, pinned %q", c.Base, m.Base)
	}
	// the pins go with it
	p, _ := c.Pair("zh", "en")
	q, _ := m.Pair("zh", "en")
	if p.Files[0].SHA256 != q.Files[0].SHA256 {
		t.Fatal("pins changed")
	}
	for _, bad := range []string{"http://mirror.example/", "mirror.example/", "https://u:p@mirror.example/",
		"https://mirror.example/?a=b", "https:///x/", "file:///tmp/"} {
		if _, err := m.WithBase(bad); err == nil {
			t.Errorf("%q taken", bad)
		}
	}
}

func TestPinnedLangsAndSizes(t *testing.T) {
	m, _ := Pinned()
	if l := m.Langs(); len(l) != 1 || l[0] != "zh" {
		t.Fatalf("langs %v", l)
	}
	gz, disk := m.BundleBytes("zh")
	// the size the app shows before a download: both directions
	if gz < 60<<20 || gz > 90<<20 || disk <= gz {
		t.Fatalf("zh bundle %d on the wire, %d on disk", gz, disk)
	}
}

func waitState(t *testing.T, j *Jobs, key, want string) Status {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for {
		st := j.Status(key)
		if st.State == want {
			return st
		}
		if time.Now().After(deadline) {
			t.Fatalf("state %+v, want %s", st, want)
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func TestJobsRunCancelResume(t *testing.T) {
	bf := newBundleFix(t)
	bf.stall = make(chan struct{})
	dir := t.TempDir()
	m := bf.local(t)
	var j Jobs
	run := func(ctx context.Context, prog Progress) error {
		return FetchBundle(ctx, HTTPGetter(bf.srv.Client()), m, "zh", dir, prog)
	}
	if st := j.Status("zh"); st.State != StateIdle {
		t.Fatalf("fresh %+v", st)
	}
	if !j.Start("zh", run) {
		t.Fatal("did not start")
	}
	if j.Start("zh", run) {
		t.Fatal("a second download of the same language started")
	}
	for bf.hits.Load() == 0 {
		time.Sleep(time.Millisecond)
	}
	j.Cancel("zh")
	waitState(t, &j, "zh", StateCancelled)

	close(bf.stall)
	if !j.Start("zh", run) {
		t.Fatal("did not resume")
	}
	st := waitState(t, &j, "zh", StateDone)
	gz, _ := m.BundleBytes("zh")
	if st.Done != gz || st.Total != gz {
		t.Fatalf("done %+v, want %d", st, gz)
	}
	if !BundleInstalled(m, "zh", dir) {
		t.Fatal("not installed")
	}
	j.Forget("zh")
	if st := j.Status("zh"); st.State != StateIdle {
		t.Fatalf("after forget %+v", st)
	}
}

func TestJobsSortFailures(t *testing.T) {
	var j Jobs
	j.Start("a", func(context.Context, Progress) error { return ErrHash })
	if st := waitState(t, &j, "a", StateFailed); st.Kind != "hash" {
		t.Fatalf("%+v", st)
	}
	j.Start("b", func(context.Context, Progress) error { return errors.New("dial tcp: refused") })
	if st := waitState(t, &j, "b", StateFailed); st.Kind != "net" || st.Err == "" {
		t.Fatalf("%+v", st)
	}
}

func TestJobsBadHashLeavesNothing(t *testing.T) {
	bf := newBundleFix(t)
	m := bf.local(t)
	// one byte of the model's gzip changed on the server
	k := "zh-en/model.zhen.bin.gz"
	bad := append([]byte(nil), bf.gz[k]...)
	bad[len(bad)/2] ^= 0xff
	bf.gz[k] = bad
	dir := t.TempDir()
	var j Jobs
	j.Start("zh", func(ctx context.Context, prog Progress) error {
		return FetchBundle(ctx, HTTPGetter(bf.srv.Client()), m, "zh", dir, prog)
	})
	if st := waitState(t, &j, "zh", StateFailed); st.Kind != "hash" {
		t.Fatalf("%+v", st)
	}
	left, _ := filepath.Glob(filepath.Join(dir, "*", "*"))
	if len(left) != 0 {
		t.Fatalf("left %v", left)
	}
}
