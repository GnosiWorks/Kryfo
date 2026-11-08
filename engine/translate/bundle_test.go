// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"math/rand/v2"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// two languages of different sizes in one small class, published under
// /src/ and filled into a mirror under /m/ by FillMirror
type bundleFix struct {
	m      *Manifest
	gz     map[string][]byte // by published path
	mirror string
	srv    *httptest.Server
	hits   atomic.Int64
	stall  chan struct{}

	mu sync.Mutex
	// what the mirror was asked, path and range, in order
	asked []string
	// a request at this offset fails once
	failAt map[int64]bool
	// the mirror answers with the whole file
	whole bool
}

const testClass = 4 << 20

// small classes for the tests: whole chunks, as the real ones are
func smallClasses(t *testing.T) {
	old := PadClasses
	PadClasses = []int64{testClass, 2 * testClass}
	t.Cleanup(func() { PadClasses = old })
}

func newBundleFix(t *testing.T) *bundleFix {
	t.Helper()
	smallClasses(t)
	bf := &bundleFix{gz: map[string][]byte{}, failAt: map[int64]bool{}}
	rng := rand.New(rand.NewPCG(3, 4))
	mk := func(dir, kind, name string, n int, noisy bool) File {
		raw := make([]byte, n)
		for i := range raw {
			if noisy {
				raw[i] = byte(rng.IntN(256))
			} else {
				raw[i] = byte(i % 7)
			}
		}
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
	pairs := []Pair{
		{From: "zh", To: "en", Arch: "tiny", Files: []File{
			mk("zh-en", KindModel, "model.zhen.bin", 5000, false),
			mk("zh-en", KindVocab, "vocab.zhen.spm", 300, false),
		}},
		{From: "en", To: "zh", Arch: "tiny", Files: []File{
			mk("en-zh", KindModel, "model.enzh.bin", 4000, false),
			mk("en-zh", KindSrcVocab, "srcvocab.enzh.spm", 200, false),
			mk("en-zh", KindTrgVocab, "trgvocab.enzh.spm", 200, false),
		}},
		// german spans whole chunks and ends inside one
		{From: "de", To: "en", Arch: "tiny", Files: []File{
			mk("de-en", KindModel, "model.deen.bin", Chunk*3/2, true),
			mk("de-en", KindVocab, "vocab.deen.spm", 700, true),
		}},
		{From: "en", To: "de", Arch: "tiny", Files: []File{
			mk("en-de", KindModel, "model.ende.bin", Chunk/2, true),
			mk("en-de", KindVocab, "vocab.ende.spm", 900, true),
		}},
	}
	bf.mirror = t.TempDir()
	bf.srv = httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bf.hits.Add(1)
		if bf.stall != nil {
			select {
			case <-bf.stall:
			case <-r.Context().Done():
				return
			}
		}
		if p, ok := strings.CutPrefix(r.URL.Path, "/src/"); ok {
			body, ok := bf.gz[p]
			if !ok {
				http.NotFound(w, r)
				return
			}
			http.ServeContent(w, r, "", time.Time{}, bytes.NewReader(body))
			return
		}
		name, ok := strings.CutPrefix(r.URL.Path, "/m/")
		if !ok {
			http.NotFound(w, r)
			return
		}
		rg := r.Header.Get("Range")
		bf.mu.Lock()
		bf.asked = append(bf.asked, name+" "+rg)
		var off int64
		fmt.Sscanf(rg, "bytes=%d-", &off)
		fail := bf.failAt[off]
		delete(bf.failAt, off)
		whole := bf.whole
		bf.mu.Unlock()
		if fail {
			http.Error(w, "cut", http.StatusBadGateway)
			return
		}
		fh, err := os.Open(filepath.Join(bf.mirror, filepath.Base(name)))
		if err != nil {
			http.NotFound(w, r)
			return
		}
		defer fh.Close()
		if whole {
			r.Header.Del("Range")
		}
		http.ServeContent(w, r, "", time.Time{}, fh)
	}))
	t.Cleanup(bf.srv.Close)
	bf.m = &Manifest{Version: 1, Source: bf.srv.URL + "/src/", Base: bf.srv.URL + "/m/", Pairs: pairs}
	if err := bf.m.check(); err != nil {
		t.Fatal(err)
	}
	if err := FillMirror(context.Background(), HTTPGetter(bf.srv.Client()), bf.m, bf.mirror, nil); err != nil {
		t.Fatal(err)
	}
	// and each language's older bundle of both directions, as the mirror
	// keeps the one older builds fetch
	for _, l := range bf.m.Langs() {
		if err := fillBundle(context.Background(), HTTPGetter(bf.srv.Client()), bf.m, l, filepath.Join(bf.mirror, bf.m.BundleName(l))); err != nil {
			t.Fatal(err)
		}
	}
	bf.hits.Store(0)
	return bf
}

func (bf *bundleFix) local(t *testing.T) *Manifest { return bf.m }

func (bf *bundleFix) get() Getter { return HTTPGetter(bf.srv.Client()) }

// what the mirror was asked since the last call
func (bf *bundleFix) take() []string {
	bf.mu.Lock()
	defer bf.mu.Unlock()
	out := bf.asked
	bf.asked = nil
	return out
}

func TestFetchBundleBothWays(t *testing.T) {
	bf := newBundleFix(t)
	dir := t.TempDir()
	m := bf.local(t)
	var last, total int64
	err := FetchBundle(context.Background(), bf.get(), m, "zh", dir, func(d, n int64) {
		if d < last {
			t.Errorf("progress went back from %d to %d", last, d)
		}
		last, total = d, n
	})
	if err != nil {
		t.Fatal(err)
	}
	gz, disk := m.BundleBytes("zh")
	if wire := PadTo(gz); last != wire || total != wire || wire != testClass {
		t.Fatalf("progress %d of %d, want %d", last, total, wire)
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
	left, _ := filepath.Glob(filepath.Join(dir, "*", ".bundle*"))
	if len(left) != 0 {
		t.Fatalf("left %v", left)
	}
	if err := RemoveBundle(m, "zh", dir); err != nil {
		t.Fatal(err)
	}
	if BundleInstalled(m, "zh", dir) {
		t.Fatal("still installed after removal")
	}
}

// the language cannot be told from the requests: every one is a whole
// chunk, in order, of a name as long as any other, and two bundles of
// different sizes in one class ask the same things
func TestBundleRequestsLookAlike(t *testing.T) {
	bf := newBundleFix(t)
	m := bf.local(t)
	zgz, _ := m.BundleBytes("zh")
	dgz, _ := m.BundleBytes("de")
	if zgz == dgz || PadTo(zgz) != PadTo(dgz) {
		t.Fatalf("fixture: %d and %d should differ within one class", zgz, dgz)
	}
	pattern := func(lang string) []string {
		bf.take()
		if err := FetchBundle(context.Background(), bf.get(), m, lang, t.TempDir(), nil); err != nil {
			t.Fatal(err)
		}
		var out []string
		for _, a := range bf.take() {
			name, rg, _ := strings.Cut(a, " ")
			if name != m.BundleName(lang) {
				t.Fatalf("%s asked %q", lang, name)
			}
			out = append(out, fmt.Sprintf("%d %s", len(name), rg))
		}
		return out
	}
	zh, de := pattern("zh"), pattern("de")
	want := []string{}
	for k := int64(0); k < testClass/Chunk; k++ {
		want = append(want, fmt.Sprintf("%d bytes=%d-%d", 68, k*Chunk, (k+1)*Chunk-1))
	}
	if strings.Join(zh, ",") != strings.Join(want, ",") {
		t.Fatalf("zh asked %v, want %v", zh, want)
	}
	if strings.Join(de, ",") != strings.Join(zh, ",") {
		t.Fatalf("de asked %v, zh %v", de, zh)
	}
}

// a cut keeps what came, padding counted: the tries together ask for each
// chunk once, and the files are not used before the last one is in
func TestBundleCutAndResume(t *testing.T) {
	for _, c := range []struct {
		lang string
		at   int64
	}{
		{"de", 1 * Chunk}, // inside the files
		{"zh", 3 * Chunk}, // inside the padding
	} {
		t.Run(c.lang, func(t *testing.T) {
			bf := newBundleFix(t)
			m := bf.local(t)
			dir := t.TempDir()
			bf.failAt[c.at] = true
			if err := FetchBundle(context.Background(), bf.get(), m, c.lang, dir, nil); err == nil {
				t.Fatal("a cut download finished")
			}
			if BundleInstalled(m, c.lang, dir) {
				t.Fatal("installed before all of it came")
			}
			first := bf.take()
			if err := FetchBundle(context.Background(), bf.get(), m, c.lang, dir, nil); err != nil {
				t.Fatal(err)
			}
			second := bf.take()
			if !BundleInstalled(m, c.lang, dir) {
				t.Fatal("not installed")
			}
			// the failed request was asked twice, everything else once
			if n := len(first) + len(second); n != int(testClass/Chunk)+1 {
				t.Fatalf("asked %d times: %v then %v", n, first, second)
			}
			if !strings.HasSuffix(second[0], fmt.Sprintf("bytes=%d-%d", c.at, c.at+Chunk-1)) {
				t.Fatalf("resumed at %q", second[0])
			}
		})
	}
}

// a mirror that sends the whole file is not used: it would look unlike
// every other download
func TestBundleRangeIgnored(t *testing.T) {
	bf := newBundleFix(t)
	bf.whole = true
	dir := t.TempDir()
	err := FetchBundle(context.Background(), bf.get(), bf.local(t), "zh", dir, nil)
	if !errors.Is(err, ErrStatus) {
		t.Fatalf("got %v", err)
	}
	if BundleInstalled(bf.local(t), "zh", dir) {
		t.Fatal("installed")
	}
}

// a mirror with other bytes inside a file: nothing is unpacked, and the
// part goes, since a resume would only repeat it
func TestBundleWrongBytes(t *testing.T) {
	bf := newBundleFix(t)
	m := bf.local(t)
	p := filepath.Join(bf.mirror, m.BundleName("zh"))
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	b[100] ^= 0xff
	if err := os.WriteFile(p, b, 0o644); err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	err = FetchBundle(context.Background(), bf.get(), m, "zh", dir, nil)
	if !errors.Is(err, ErrHash) {
		t.Fatalf("got %v", err)
	}
	left, _ := filepath.Glob(filepath.Join(dir, "*", "*"))
	left2, _ := filepath.Glob(filepath.Join(dir, "*", ".bundle*"))
	if len(left)+len(left2) != 0 {
		t.Fatalf("left %v %v", left, left2)
	}
}

func TestFetchBundleUnknownLanguage(t *testing.T) {
	bf := newBundleFix(t)
	err := FetchBundle(context.Background(), bf.get(), bf.local(t), "fr", t.TempDir(), nil)
	if !errors.Is(err, ErrNoBundle) {
		t.Fatalf("got %v", err)
	}
	if bf.hits.Load() != 0 {
		t.Fatal("asked the server for a language it has nothing for")
	}
}

func TestPinnedLangsAndSizes(t *testing.T) {
	m, _ := Pinned()
	want := "ar de es fa fr hi id it pl pt ru tr uk vi zh zh_hant"
	if l := strings.Join(m.Langs(), " "); l != want {
		t.Fatalf("langs %v", l)
	}
	// every language both ways with english, each way a pack of its own in
	// the 48 MiB class, so a download does not say which language by size
	ids := map[string]bool{}
	for _, l := range m.Langs() {
		for _, k := range []string{l + "-en", "en-" + l} {
			gz, disk := m.BundleBytes(k)
			if gz < 10<<20 || gz > 48<<20 || disk <= 0 || m.WireBytes(k) != 48<<20 {
				t.Fatalf("%s: %d on the wire, %d on disk", k, gz, disk)
			}
			id := m.BundleID(k)
			if !hashRe.MatchString(id) || ids[id] {
				t.Fatalf("%s: bundle id %q", k, id)
			}
			ids[id] = true
		}
	}
	// the chinese pack each way, by the pins
	if id := m.BundleID("zh-en"); id == m.BundleID("en-zh") {
		t.Fatalf("bundle id %q", id)
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
			t.Fatalf("%s: %+v, want %s", key, st, want)
		}
		time.Sleep(2 * time.Millisecond)
	}
}

func TestJobsRunCancelResume(t *testing.T) {
	bf := newBundleFix(t)
	bf.stall = make(chan struct{})
	dir := t.TempDir()
	m := bf.local(t)
	var j Jobs
	run := func(ctx context.Context, prog Progress) error {
		return FetchBundle(ctx, bf.get(), m, "zh", dir, prog)
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
		if got := PadTo(c.gz); got != c.want || got%Chunk != 0 {
			t.Errorf("PadTo(%d) = %d, want %d", c.gz, got, c.want)
		}
	}
	m, _ := Pinned()
	if got := m.WireBytes("zh"); got != 96<<20 {
		t.Fatalf("zh on the wire %d", got)
	}
}

// the desk tool fetches each file from where it was published
func TestFetchPairFromSource(t *testing.T) {
	bf := newBundleFix(t)
	m := bf.local(t)
	f := m.Pairs[0].Files[0]
	if got := m.SourceURL(f); got != m.Source+f.Path {
		t.Fatalf("source url %q", got)
	}
	dir := t.TempDir()
	if err := FetchPair(context.Background(), bf.get(), m, m.Pairs[0], dir, nil); err != nil {
		t.Fatal(err)
	}
	if !Installed(m.Pairs[0], dir) {
		t.Fatal("not installed")
	}
	if a := bf.take(); len(a) != 0 {
		t.Fatalf("asked the mirror %v", a)
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
