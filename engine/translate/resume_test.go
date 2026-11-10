// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// a mirror over a bad circuit: requests come in slowly, some stop half way,
// some stall with the connection open, some get a busy answer. every chunk
// is served from the real mirror file
type badMirror struct {
	dir string
	srv *httptest.Server

	mu   sync.Mutex
	n    int           // requests so far
	by   map[int64]int // requests per chunk
	plan func(n int) string
	// by the chunk asked for, over plan when set
	planAt func(off int64) string
	conns  map[string]bool
}

func newBadMirror(t *testing.T, dir string, plan func(n int) string) *badMirror {
	bm := &badMirror{dir: dir, by: map[int64]int{}, plan: plan, conns: map[string]bool{}}
	bm.srv = httptest.NewServer(http.HandlerFunc(bm.serve))
	t.Cleanup(bm.srv.Close)
	return bm
}

func (bm *badMirror) serve(w http.ResponseWriter, r *http.Request) {
	var a, b int64
	if _, err := fmt.Sscanf(r.Header.Get("Range"), "bytes=%d-%d", &a, &b); err != nil {
		http.Error(w, "no range", http.StatusBadRequest)
		return
	}
	bm.mu.Lock()
	bm.n++
	bm.by[a]++
	bm.conns[r.RemoteAddr] = true
	what := bm.plan(bm.n)
	if bm.planAt != nil {
		what = bm.planAt(a)
	}
	bm.mu.Unlock()
	body, err := os.ReadFile(filepath.Join(bm.dir, filepath.Base(r.URL.Path)))
	if err != nil {
		http.NotFound(w, r)
		return
	}
	switch what {
	case "busy":
		http.Error(w, "busy", http.StatusServiceUnavailable)
		return
	case "gone":
		http.NotFound(w, r)
		return
	}
	part := body[a : b+1]
	w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", a, b, len(body)))
	w.Header().Set("Content-Length", fmt.Sprint(len(part)))
	w.WriteHeader(http.StatusPartialContent)
	fl := w.(http.Flusher)
	switch what {
	case "drop":
		// half the chunk, then the circuit closes
		w.Write(part[:len(part)/2])
		fl.Flush()
		panic(http.ErrAbortHandler)
	case "stall":
		w.Write(part[:1000])
		fl.Flush()
		select {
		case <-r.Context().Done():
		case <-time.After(5 * time.Second):
		}
		return
	}
	// slow: in pieces, each a little late
	for len(part) > 0 {
		k := min(len(part), 128<<10)
		w.Write(part[:k])
		fl.Flush()
		part = part[k:]
		time.Sleep(time.Millisecond)
	}
}

func (bm *badMirror) manifest(m *Manifest) *Manifest {
	c := *m
	c.Base = bm.srv.URL + "/m/"
	return &c
}

// lanes on their own clients, as the engine gives each lane a circuit
func laneFetcher(bm *badMirror, lanes int, stops *[]Stop, smu *sync.Mutex, made *int) Fetcher {
	return Fetcher{
		Lanes:  lanes,
		Retry:  true,
		Wait:   func(int) time.Duration { return time.Millisecond },
		Stall:  200 * time.Millisecond,
		GiveUp: 5 * time.Second,
		Lane: func() (Getter, func()) {
			smu.Lock()
			*made++
			smu.Unlock()
			c := &http.Client{Transport: &http.Transport{}}
			return HTTPGetter(c), c.CloseIdleConnections
		},
		Log: func(s Stop) {
			smu.Lock()
			*stops = append(*stops, s)
			smu.Unlock()
		},
	}
}

// the download gets past drops, stalls and busy answers by itself, logs
// each stop by its class, asks each stopped chunk again from its first
// byte, and checks the files as strictly as ever
func TestBundleResumesByItself(t *testing.T) {
	for _, lanes := range []int{1, 3} {
		t.Run(fmt.Sprint(lanes, " lanes"), func(t *testing.T) {
			bf := newBundleFix(t)
			// a third of the requests stop: drop, stall, busy, in turn
			bm := newBadMirror(t, bf.mirror, func(n int) string {
				return [...]string{"slow", "drop", "slow", "stall", "slow", "busy"}[n%6]
			})
			m := bm.manifest(bf.m)
			var stops []Stop
			var smu sync.Mutex
			made := 0
			f := laneFetcher(bm, lanes, &stops, &smu, &made)
			dir := t.TempDir()
			var last int64
			err := FetchBundleWith(context.Background(), f, m, "de", dir, func(d, n int64) {
				if d < last {
					t.Errorf("progress went back from %d to %d", last, d)
				}
				last = d
			})
			if err != nil {
				t.Fatal(err)
			}
			if !BundleInstalled(m, "de", dir) {
				t.Fatal("not installed")
			}
			if last != testClass {
				t.Fatalf("progress %d", last)
			}
			smu.Lock()
			defer smu.Unlock()
			why := map[string]int{}
			for _, s := range stops {
				why[s.Why]++
				if s.Wait == 0 || s.At%Chunk != 0 || s.Lane >= lanes {
					t.Fatalf("stop %+v", s)
				}
			}
			if why["eof"] == 0 || why["stall"] == 0 || why["status 503"] == 0 || len(why) != 3 {
				t.Fatalf("stops %v", why)
			}
			bm.mu.Lock()
			defer bm.mu.Unlock()
			// every chunk asked, each stop asked again, nothing else
			if len(bm.by) != int(testClass/Chunk) || bm.n != int(testClass/Chunk)+len(stops) {
				t.Fatalf("asked %d times for %d chunks, %d stops", bm.n, len(bm.by), len(stops))
			}
			for off := range bm.by {
				if off%Chunk != 0 {
					t.Fatalf("asked at %d", off)
				}
			}
			left, _ := filepath.Glob(filepath.Join(dir, "*", ".bundle*"))
			if len(left) != 0 {
				t.Fatalf("left %v", left)
			}
		})
	}
}

// a chunk that misses twice in a row goes on over a fresh circuit
func TestBundleFreshCircuitAfterTwoMisses(t *testing.T) {
	bf := newBundleFix(t)
	bm := newBadMirror(t, bf.mirror, func(n int) string {
		if n <= 4 {
			return "drop"
		}
		return "slow"
	})
	var stops []Stop
	var smu sync.Mutex
	made := 0
	f := laneFetcher(bm, 1, &stops, &smu, &made)
	dir := t.TempDir()
	if err := FetchBundleWith(context.Background(), f, bm.manifest(bf.m), "zh", dir, nil); err != nil {
		t.Fatal(err)
	}
	if len(stops) != 4 || made != 3 {
		t.Fatalf("%d stops, %d circuits", len(stops), made)
	}
	for i, s := range stops {
		if s.Try != i+1 || s.At != 0 {
			t.Fatalf("stop %d %+v", i, s)
		}
	}
	bm.mu.Lock()
	defer bm.mu.Unlock()
	if len(bm.conns) < 3 {
		t.Fatalf("connections %d", len(bm.conns))
	}
}

// what the stops cannot change: a mirror with other bytes still fails the
// pins once all of it is in, the part goes, and the retries do not hide it
func TestBundleResumedStillHashChecked(t *testing.T) {
	bf := newBundleFix(t)
	p := filepath.Join(bf.mirror, bf.m.BundleName("zh"))
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	b[100] ^= 0xff
	if err := os.WriteFile(p, b, 0o644); err != nil {
		t.Fatal(err)
	}
	bm := newBadMirror(t, bf.mirror, func(n int) string {
		return [...]string{"slow", "drop", "stall"}[n%3]
	})
	var stops []Stop
	var smu sync.Mutex
	made := 0
	f := laneFetcher(bm, 3, &stops, &smu, &made)
	m := bm.manifest(bf.m)
	dir := t.TempDir()
	err = FetchBundleWith(context.Background(), f, m, "zh", dir, nil)
	if !errors.Is(err, ErrHash) {
		t.Fatalf("got %v", err)
	}
	if len(stops) == 0 {
		t.Fatal("no stops")
	}
	if BundleInstalled(m, "zh", dir) {
		t.Fatal("installed")
	}
	left, _ := filepath.Glob(filepath.Join(dir, "*", "*"))
	left2, _ := filepath.Glob(filepath.Join(dir, "*", ".bundle*"))
	if len(left)+len(left2) != 0 {
		t.Fatalf("left %v %v", left, left2)
	}
}

// a mirror without the file is an answer, not a stop: no retries
func TestBundleMissingFileNotRetried(t *testing.T) {
	bf := newBundleFix(t)
	bm := newBadMirror(t, bf.mirror, func(int) string { return "gone" })
	var stops []Stop
	var smu sync.Mutex
	made := 0
	f := laneFetcher(bm, 1, &stops, &smu, &made)
	err := FetchBundleWith(context.Background(), f, bm.manifest(bf.m), "zh", t.TempDir(), nil)
	if !errors.Is(err, ErrStatus) || len(stops) != 1 || stops[0].Why != "status 404" || stops[0].Wait != 0 {
		t.Fatalf("got %v, stops %+v", err, stops)
	}
}

// no chunk for GiveUp ends it as a net failure the app offers to retry;
// what came stays for the next start
func TestBundleGivesUpWithoutProgress(t *testing.T) {
	bf := newBundleFix(t)
	busy := false
	bm := newBadMirror(t, bf.mirror, func(n int) string {
		if busy {
			return "busy"
		}
		return "slow"
	})
	var stops []Stop
	var smu sync.Mutex
	made := 0
	f := laneFetcher(bm, 1, &stops, &smu, &made)
	f.GiveUp = 150 * time.Millisecond
	f.Wait = func(int) time.Duration { return 20 * time.Millisecond }
	dir := t.TempDir()
	m := bm.manifest(bf.m)
	var once sync.Once
	err := FetchBundleWith(context.Background(), f, m, "zh", dir, func(d, n int64) {
		if d >= 2*Chunk {
			once.Do(func() {
				bm.mu.Lock()
				busy = true
				bm.mu.Unlock()
			})
		}
	})
	if err == nil || errors.Is(err, ErrHash) || !strings.Contains(err.Error(), "no chunk for") {
		t.Fatalf("got %v", err)
	}
	if len(stops) < 2 || stops[len(stops)-1].Wait != 0 {
		t.Fatalf("stops %+v", stops)
	}
	bm.mu.Lock()
	busy = false
	bm.mu.Unlock()
	bm.mu.Lock()
	bm.by = map[int64]int{}
	bm.mu.Unlock()
	if err := FetchBundleWith(context.Background(), f, m, "zh", dir, nil); err != nil {
		t.Fatal(err)
	}
	bm.mu.Lock()
	defer bm.mu.Unlock()
	if bm.by[0] != 0 || bm.by[Chunk] != 0 {
		t.Fatalf("asked again for what came: %v", bm.by)
	}
}

// with lanes, chunks above one that will not come are kept for the next
// try: only what is missing is asked again (translate-all run 2026-11-08,
// three lanes kept 2 of 26 MB)
func TestBundleResumeKeepsOtherLanesChunks(t *testing.T) {
	bf := newBundleFix(t)
	first := true
	bm := newBadMirror(t, bf.mirror, func(int) string { return "slow" })
	bm.planAt = func(off int64) string {
		if first && off == 0 {
			return "busy"
		}
		return "slow"
	}
	var stops []Stop
	var smu sync.Mutex
	made := 0
	f := laneFetcher(bm, 3, &stops, &smu, &made)
	f.GiveUp = 300 * time.Millisecond
	f.Wait = func(int) time.Duration { return 20 * time.Millisecond }
	dir := t.TempDir()
	m := bm.manifest(bf.m)
	err := FetchBundleWith(context.Background(), f, m, "zh", dir, nil)
	if err == nil || !strings.Contains(err.Error(), "no chunk for") {
		t.Fatalf("got %v", err)
	}
	bm.mu.Lock()
	first = false
	asked := len(bm.by)
	bm.by = map[int64]int{}
	bm.mu.Unlock()
	if asked < 3 {
		t.Fatalf("only %d chunks asked before the stop", asked)
	}
	var back int64 = -1
	if err := FetchBundleWith(context.Background(), f, m, "zh", dir, func(d, n int64) {
		if back < 0 {
			back = d
		}
	}); err != nil {
		t.Fatal(err)
	}
	if !BundleInstalled(m, "zh", dir) {
		t.Fatal("not installed")
	}
	bm.mu.Lock()
	defer bm.mu.Unlock()
	if bm.by[0] != 1 {
		t.Fatalf("the missing chunk asked %d times", bm.by[0])
	}
	for off, n := range bm.by {
		if off != 0 && off < int64(asked)*Chunk {
			t.Fatalf("asked again for chunk at %d (%d times): %v", off, n, bm.by)
		}
	}
	// the progress starts from what was kept, not from nothing
	if back < Chunk {
		t.Fatalf("progress started at %d", back)
	}
}

// while the network is not there, a stopped lane waits instead of trying
func TestBundleWaitsForTheNetwork(t *testing.T) {
	bf := newBundleFix(t)
	var rmu sync.Mutex
	ready := true
	bm := newBadMirror(t, bf.mirror, func(n int) string {
		if n == 2 {
			rmu.Lock()
			ready = false
			rmu.Unlock()
			go func() {
				time.Sleep(300 * time.Millisecond)
				rmu.Lock()
				ready = true
				rmu.Unlock()
			}()
			return "drop"
		}
		return "slow"
	})
	var stops []Stop
	var smu sync.Mutex
	made := 0
	f := laneFetcher(bm, 1, &stops, &smu, &made)
	f.Ready = func() bool {
		rmu.Lock()
		defer rmu.Unlock()
		return ready
	}
	start := time.Now()
	if err := FetchBundleWith(context.Background(), f, bm.manifest(bf.m), "zh", t.TempDir(), nil); err != nil {
		t.Fatal(err)
	}
	if time.Since(start) < 300*time.Millisecond || len(stops) != 1 {
		t.Fatalf("took %v, stops %+v", time.Since(start), stops)
	}
}

// a cancel ends every lane at once; what came stays
func TestBundleLanesCancel(t *testing.T) {
	bf := newBundleFix(t)
	bm := newBadMirror(t, bf.mirror, func(int) string { return "stall" })
	var stops []Stop
	var smu sync.Mutex
	made := 0
	f := laneFetcher(bm, 3, &stops, &smu, &made)
	f.Stall = time.Hour
	ctx, cancel := context.WithCancel(context.Background())
	time.AfterFunc(100*time.Millisecond, cancel)
	err := FetchBundleWith(ctx, f, bm.manifest(bf.m), "zh", t.TempDir(), nil)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("got %v", err)
	}
}

func TestWhy(t *testing.T) {
	for _, c := range []struct {
		err  error
		want string
	}{
		{fmt.Errorf("%w: x", ErrStall), "stall"},
		{fmt.Errorf("%w: x", ErrSlow), "slow"},
		{fmt.Errorf("x: %w", StatusError{429}), "status 429"},
		{fmt.Errorf("%w: %w", ErrStatus, errNoRange), "range"},
		{fmt.Errorf("%w: content-range", ErrStatus), "range"},
		{context.DeadlineExceeded, "timeout"},
		{fmt.Errorf("%w: 3 bytes", ErrShort), "short"},
		{errors.New("socks: general failure"), "other"},
	} {
		if got := Why(c.err); got != c.want {
			t.Errorf("%v: %q, want %q", c.err, got, c.want)
		}
	}
	for n := 1; n < 10; n++ {
		if d := Backoff(n); d < time.Second || d > 75*time.Second {
			t.Fatalf("backoff %d: %v", n, d)
		}
	}
}

// a .bundle.got that cannot be written whole leaves the one before it
func TestGotFileIsReplacedWhole(t *testing.T) {
	dir := t.TempDir()
	got := filepath.Join(dir, gotName)
	if err := writeGot(got, gotText(2*Chunk, map[int64]bool{4 * Chunk: true})); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(got + ".new"); !os.IsNotExist(err) {
		t.Fatalf("temp left: %v", err)
	}
	// the temp's place is taken: the write fails and the old list stays
	if err := os.Mkdir(got+".new", 0o700); err != nil {
		t.Fatal(err)
	}
	if err := writeGot(got, []byte("9")); err == nil {
		t.Fatal("a write that could not happen said it did")
	}
	b, err := os.ReadFile(got)
	if err != nil || string(b) != fmt.Sprintf("%d\n%d", 2*Chunk, 4*Chunk) {
		t.Fatalf("got %q, %v", b, err)
	}
}
