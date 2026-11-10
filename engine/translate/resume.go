// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"context"
	"errors"
	"fmt"
	"io"
	"math/rand/v2"
	"net"
	"os"
	"slices"
	"strconv"
	"sync"
	"syscall"
	"time"
)

var (
	// no byte came for Fetcher.Stall
	ErrStall = errors.New("stalled")
	// one chunk took longer than Fetcher.ChunkMax
	ErrSlow = errors.New("too slow")
	// the mirror sent another part than the one asked for
	errNoRange = errors.New("range not honoured")
)

// StatusError is an answer other than 206 or 200.
type StatusError struct{ Code int }

func (e StatusError) Error() string        { return fmt.Sprintf("%v: %d", ErrStatus, e.Code) }
func (e StatusError) Is(target error) bool { return target == ErrStatus }

// Fetcher is how a bundle comes over the wire. the zero value but Lane is
// FetchBundle: one request at a time, the first stop ends it.
type Fetcher struct {
	// Lane gives a getter on a circuit of its own, and what lets it go
	// (nil: nothing). called once per lane, and again for a fresh circuit
	// when a lane missed twice in a row.
	Lane func() (Getter, func())
	// how many chunks are asked for at once, each lane on its own circuit.
	// 0 is one. the chunks stay whole and each is asked for once, as with
	// one lane; only their order on the wire interleaves.
	Lanes int
	// a stop is waited out and the same chunk asked again, from the byte
	// the part file holds, instead of ending the download
	Retry bool
	// the pause before a lane's n-th try in a row (n from 1). nil: Backoff
	Wait func(n int) time.Duration
	// whether the network is there. after a stop a lane waits for it
	// instead of using up tries. nil: always
	Ready func() bool
	// a retrying download ends when no chunk came for this long. 0: never
	GiveUp time.Duration
	// one request ends when no byte came for this long, from its start
	Stall time.Duration
	// one request ends when its chunk took this long in all
	ChunkMax time.Duration
	// told of every stop
	Log func(Stop)
}

// Stop is one request that did not bring its chunk. Why is an error class
// only, never a url or a host.
type Stop struct {
	Why  string
	At   int64 // the chunk's first byte in the bundle
	Lane int
	Try  int           // misses in a row on this chunk
	Wait time.Duration // before the next try; 0 when the download ends
}

// Backoff is 2 s doubling to 60 s, give or take a quarter.
func Backoff(n int) time.Duration {
	d := 2 * time.Second
	for i := 1; i < n && d < time.Minute; i++ {
		d *= 2
	}
	d = min(d, time.Minute)
	return d*3/4 + rand.N(d/2)
}

// Why sorts a stop for the log.
func Why(err error) string {
	var se StatusError
	var ne net.Error
	var oe *net.OpError
	switch {
	case errors.Is(err, ErrStall):
		return "stall"
	case errors.Is(err, ErrSlow):
		return "slow"
	case errors.As(err, &se):
		return "status " + strconv.Itoa(se.Code)
	case errors.Is(err, errNoRange), errors.Is(err, ErrStatus):
		return "range"
	case errors.Is(err, syscall.ECONNRESET):
		return "reset"
	case errors.Is(err, syscall.ECONNREFUSED):
		return "refused"
	case errors.As(err, &oe) && oe.Op == "dial":
		return "dial"
	case errors.As(err, &ne) && ne.Timeout(), errors.Is(err, context.DeadlineExceeded):
		return "timeout"
	case errors.Is(err, io.ErrUnexpectedEOF), errors.Is(err, io.EOF):
		return "eof"
	case errors.Is(err, ErrShort):
		return "short"
	}
	return "other"
}

// a stop no retry gets past: the mirror is wrong, not the way to it
func permanent(err error) bool {
	var se StatusError
	if errors.As(err, &se) {
		return se.Code >= 400 && se.Code < 500 && se.Code != 408 && se.Code != 425 && se.Code != 429
	}
	return errors.Is(err, errNoRange) || errors.Is(err, ErrStatus) ||
		errors.Is(err, ErrHash) || errors.Is(err, ErrSize)
}

// what the lanes share while a bundle comes
type filling struct {
	mu      sync.Mutex
	next    int64          // the next chunk no lane has taken
	prefix  int64          // every chunk below it is in
	in      map[int64]bool // chunks in above prefix
	count   int64          // bytes in, padding counted
	lastNew time.Time
	err     error
}

// what a .bundle.got file says: the whole chunks below a prefix, and on a
// second line the chunks in above it, which other lanes brought
func gotText(prefix int64, in map[int64]bool) []byte {
	b := strconv.AppendInt(nil, prefix, 10)
	if len(in) == 0 {
		return b
	}
	offs := make([]int64, 0, len(in))
	for off := range in {
		offs = append(offs, off)
	}
	slices.Sort(offs)
	b = append(b, '\n')
	for i, off := range offs {
		if i > 0 {
			b = append(b, ',')
		}
		b = strconv.AppendInt(b, off, 10)
	}
	return b
}

// the .bundle.got file replaced whole: a stop mid-write leaves the old one,
// never half a list
func writeGot(path string, b []byte) error {
	tmp := path + ".new"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// [have]: chunks above got already in the part file, not asked again
func (f Fetcher) fill(ctx context.Context, url string, fh *os.File, gotPath string, got int64, have map[int64]bool, gz, wire int64, prog Progress) error {
	if got >= wire {
		return nil
	}
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	in := make(map[int64]bool, len(have))
	for off := range have {
		in[off] = true
	}
	st := &filling{next: got, prefix: got, in: in, count: got + int64(len(in))*Chunk, lastNew: time.Now()}
	for st.in[st.prefix] {
		delete(st.in, st.prefix)
		st.prefix += Chunk
	}
	st.next = st.prefix
	fail := func(err error) {
		st.mu.Lock()
		if st.err == nil {
			st.err = err
		}
		st.mu.Unlock()
		cancel()
	}
	take := func() (int64, bool) {
		st.mu.Lock()
		defer st.mu.Unlock()
		for st.in[st.next] {
			st.next += Chunk
		}
		if st.next >= wire {
			return 0, false
		}
		off := st.next
		st.next += Chunk
		return off, true
	}
	stale := func() bool {
		st.mu.Lock()
		defer st.mu.Unlock()
		return f.GiveUp > 0 && time.Since(st.lastNew) > f.GiveUp
	}
	// a chunk is in: the mark moves only over chunks with none missing
	// below them, so a resume never skips a hole
	landed := func(off int64) error {
		st.mu.Lock()
		defer st.mu.Unlock()
		st.in[off] = true
		st.count += Chunk
		st.lastNew = time.Now()
		for st.in[st.prefix] {
			delete(st.in, st.prefix)
			st.prefix += Chunk
		}
		// every chunk in is written down, not only the prefix: with lanes
		// a stop leaves chunks above a hole, and a resume keeps them
		if err := writeGot(gotPath, gotText(st.prefix, st.in)); err != nil {
			return err
		}
		if prog != nil {
			prog(st.count, wire)
		}
		return nil
	}
	lanes := max(f.Lanes, 1)
	var wg sync.WaitGroup
	for i := range lanes {
		wg.Add(1)
		go func() {
			defer wg.Done()
			get, rel := f.Lane()
			defer func() {
				if rel != nil {
					rel()
				}
			}()
			buf := make([]byte, Chunk)
			for {
				off, ok := take()
				if !ok {
					return
				}
				for miss := 0; ; {
					err := f.one(ctx, get, url, off, buf)
					if err == nil {
						break
					}
					if ctx.Err() != nil {
						return
					}
					miss++
					s := Stop{Why: Why(err), At: off, Lane: i, Try: miss}
					if !f.Retry || permanent(err) || stale() {
						if f.Retry && !permanent(err) {
							err = fmt.Errorf("no chunk for %v: %w", f.GiveUp, err)
						}
						f.log(s)
						fail(err)
						return
					}
					s.Wait = f.wait(miss)
					f.log(s)
					if miss%2 == 0 {
						// two misses in a row: a fresh circuit
						if rel != nil {
							rel()
						}
						get, rel = f.Lane()
					}
					if !sleepCtx(ctx, s.Wait) {
						return
					}
					for f.Ready != nil && !f.Ready() {
						if stale() {
							f.log(Stop{Why: "offline", At: off, Lane: i, Try: miss})
							fail(fmt.Errorf("no network for %v: %w", f.GiveUp, err))
							return
						}
						if !sleepCtx(ctx, 2*time.Second) {
							return
						}
					}
				}
				if off < gz {
					if _, err := fh.WriteAt(buf[:min(int64(Chunk), gz-off)], off); err != nil {
						fail(err)
						return
					}
				}
				if err := landed(off); err != nil {
					fail(err)
					return
				}
			}
		}()
	}
	wg.Wait()
	st.mu.Lock()
	defer st.mu.Unlock()
	if st.err != nil {
		return st.err
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	return nil
}

// one whole chunk at off into buf
func (f Fetcher) one(ctx context.Context, get Getter, url string, off int64, buf []byte) error {
	rctx, cancel := context.WithCancelCause(ctx)
	defer cancel(nil)
	var stall *time.Timer
	if f.Stall > 0 {
		stall = time.AfterFunc(f.Stall, func() { cancel(ErrStall) })
		defer stall.Stop()
	}
	if f.ChunkMax > 0 {
		t := time.AfterFunc(f.ChunkMax, func() { cancel(ErrSlow) })
		defer t.Stop()
	}
	why := func(err error) error {
		if c := context.Cause(rctx); ctx.Err() == nil && (c == ErrStall || c == ErrSlow) {
			return fmt.Errorf("%w: %w", c, err)
		}
		return err
	}
	body, start, err := get(rctx, url, off, Chunk)
	if err != nil {
		return why(err)
	}
	defer body.Close()
	if start != off {
		// the whole file instead of the range: not taken, it would make
		// this download unlike the others
		return fmt.Errorf("%w: %w", ErrStatus, errNoRange)
	}
	n := 0
	for n < Chunk {
		k, err := body.Read(buf[n:])
		n += k
		if k > 0 && stall != nil {
			stall.Reset(f.Stall)
		}
		if err != nil {
			if n == Chunk {
				break
			}
			if err == io.EOF {
				err = io.ErrUnexpectedEOF
			}
			return why(fmt.Errorf("%w: chunk at %d: %d bytes: %w", ErrShort, off, n, err))
		}
	}
	return nil
}

func (f Fetcher) wait(n int) time.Duration {
	if f.Wait != nil {
		return f.Wait(n)
	}
	return Backoff(n)
}

func (f Fetcher) log(s Stop) {
	if f.Log != nil {
		f.Log(s)
	}
}

func sleepCtx(ctx context.Context, d time.Duration) bool {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
		return true
	case <-ctx.Done():
		return false
	}
}
