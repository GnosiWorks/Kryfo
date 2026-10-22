// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
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
	// padding bytes served, its requests, and whether the mirror has it
	pad     atomic.Int64
	padReqs atomic.Int64
	noPad   bool
}

// PadSize bytes of zeros, without holding them
type zeros struct{}

func (zeros) ReadAt(p []byte, off int64) (int, error) {
	clear(p)
	return len(p), nil
}

type counted struct {
	http.ResponseWriter
	n *atomic.Int64
}

func (c counted) Write(b []byte) (int, error) {
	n, err := c.ResponseWriter.Write(b)
	c.n.Add(int64(n))
	return n, err
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
		s1, s2 := sha256.Sum256(raw), sha256.Sum256(b.Bytes())
		// at its published path and at its name on the mirror
		bf.gz[p], bf.gz[hexSum(s2[:])+".gz"] = b.Bytes(), b.Bytes()
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
		if r.URL.Path == "/m/"+PadName && !bf.noPad {
			bf.padReqs.Add(1)
			pad := io.NewSectionReader(zeros{}, 0, PadSize)
			http.ServeContent(counted{w, &bf.pad}, r, "", time.Time{}, pad)
			return
		}
		body, ok := bf.gz[strings.TrimPrefix(r.URL.Path, "/m/")]
		if !ok {
			http.NotFound(w, r)
			return
		}
		http.ServeContent(w, r, "", time.Time{}, bytes.NewReader(body))
	}))
	t.Cleanup(bf.srv.Close)
	bf.m = &Manifest{Version: 1, Source: "https://source.invalid/", Base: "https://models.invalid/m/", Pairs: []Pair{zhen, enzh}}
	if err := bf.m.check(); err != nil {
		t.Fatal(err)
	}
	return bf
}

func (bf *bundleFix) local(t *testing.T) *Manifest {
	t.Helper()
	m, err := bf.m.withBase(bf.srv.URL + "/m")
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
	wire := PadTo(gz)
	if last != wire || total != wire {
		t.Fatalf("progress %d of %d, want %d", last, total, wire)
	}
	if got := bf.pad.Load(); got != wire-gz {
		t.Fatalf("padding %d bytes, want %d", got, wire-gz)
	}
	if n := bf.padReqs.Load(); n != (wire-gz+Chunk-1)/Chunk {
		t.Fatalf("padding in %d requests", n)
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
	if wire := PadTo(gz); st.Done != wire || st.Total != wire {
		t.Fatalf("done %+v, want %d", st, wire)
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
	k := MirrorName(m.Pairs[0].Files[0])
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

func TestPadClasses(t *testing.T) {
	for _, c := range []struct{ gz, want int64 }{
		{0, 0},
		{1, 48 << 20},
		{48 << 20, 48 << 20},
		{48<<20 + 1, 96 << 20},
		// the chinese bundle
		{75033319, 96 << 20},
		{96<<20 + 1, 192 << 20},
		{300 << 20, 384 << 20},
	} {
		if got := PadTo(c.gz); got != c.want {
			t.Errorf("PadTo(%d) = %d, want %d", c.gz, got, c.want)
		}
		if got := PadTo(c.gz) - c.gz; c.gz > 0 && (got < 0 || got >= PadSize) {
			t.Errorf("PadTo(%d) pads %d, more than the pad file", c.gz, got)
		}
	}
	m, _ := Pinned()
	if got := m.WireBytes("zh"); got != 96<<20 {
		t.Fatalf("zh on the wire %d", got)
	}
}

// the files are what count: a mirror without padding still installs them
func TestFetchBundleWithoutPad(t *testing.T) {
	bf := newBundleFix(t)
	bf.noPad = true
	dir := t.TempDir()
	m := bf.local(t)
	if err := FetchBundle(context.Background(), HTTPGetter(bf.srv.Client()), m, "zh", dir, nil); err != nil {
		t.Fatal(err)
	}
	if !BundleInstalled(m, "zh", dir) {
		t.Fatal("not installed")
	}
}

// filling a mirror reads the published paths and fetches no padding
func TestFetchFromSource(t *testing.T) {
	bf := newBundleFix(t)
	local := bf.local(t)
	src := local.FromSource()
	src.Source = local.Base
	f := src.Pairs[0].Files[0]
	if got := src.URL(f); got != local.Base+f.Path {
		t.Fatalf("source url %q", got)
	}
	if got := local.URL(f); got != local.Base+f.GzSHA256+".gz" {
		t.Fatalf("mirror url %q", got)
	}
	dir := t.TempDir()
	if err := FetchBundle(context.Background(), HTTPGetter(bf.srv.Client()), src, "zh", dir, nil); err != nil {
		t.Fatal(err)
	}
	if !BundleInstalled(src, "zh", dir) || bf.padReqs.Load() != 0 {
		t.Fatalf("installed %v, pad requests %d", BundleInstalled(src, "zh", dir), bf.padReqs.Load())
	}
}

func TestMirrorBases(t *testing.T) {
	onion := "http://" + strings.Repeat("a", 56) + ".onion/models/"
	if !baseOK(onion) {
		t.Fatal("onion over http refused")
	}
	for _, bad := range []string{
		"http://" + strings.Repeat("a", 55) + ".onion/",
		"http://" + strings.Repeat("a", 56) + ".onion.example/",
		"http://" + strings.Repeat("1", 56) + ".onion/",
		"ftp://" + strings.Repeat("a", 56) + ".onion/",
		"http://mirror.example/",
		"https://u:p@mirror.example/",
		"https://mirror.example/?a=b",
	} {
		if baseOK(bad) {
			t.Errorf("%q taken", bad)
		}
	}
	p, err := Pinned()
	if err != nil {
		t.Fatal(err)
	}
	if !onionRe.MatchString(strings.TrimSuffix(strings.TrimPrefix(p.Base, "http://"), "/models/")) {
		t.Fatalf("pinned base %q is not the onion mirror", p.Base)
	}
	if !strings.HasPrefix(p.Source, "https://") {
		t.Fatalf("source %q", p.Source)
	}
}

// the manifest with its files fetched from a local test server
func (m *Manifest) withBase(base string) (*Manifest, error) {
	if !strings.HasSuffix(base, "/") {
		base += "/"
	}
	if !baseOK(base) {
		return nil, fmt.Errorf("%w: base %q", ErrManifest, base)
	}
	c := *m
	c.Base = base
	c.bySource = false
	return &c, nil
}
