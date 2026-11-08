// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/halo/engine/devices"
)

// a relay that is not there yet, as for a computer whose tor still starts:
// nothing fetched or posted until up
type slowRelay struct {
	*fakeRelay
	up        atomic.Bool
	postFails atomic.Int32
}

func (s *slowRelay) post(ctx context.Context, seed [32]byte, msg []byte) error {
	if !s.up.Load() || s.postFails.Add(-1) >= 0 {
		return errLinkUnreached
	}
	return s.fakeRelay.post(ctx, seed, msg)
}

func (s *slowRelay) fetch(ctx context.Context, seed [32]byte) ([][]byte, error) {
	if !s.up.Load() {
		return nil, errLinkUnreached
	}
	return s.fakeRelay.fetch(ctx, seed)
}

func quickBackoffs(t *testing.T) {
	old := linkBackoffs
	linkBackoffs = []time.Duration{time.Millisecond, 2 * time.Millisecond}
	t.Cleanup(func() { linkBackoffs = old })
}

// a fresh computer's code shows only once its rendezvous answers: before
// that a phone that scans it waits for nothing and gives up
func TestAJoinerIsReadyOnlyOnceItsRelaysAnswer(t *testing.T) {
	w := newLinkWorld(t)
	slow := &slowRelay{fakeRelay: w.relay}
	linkWireNow = slow
	j := link(t, "join_start", map[string]any{"key": hexKey(w.devKey.pub), "reg": 4321})
	if j.Err != "" {
		t.Fatalf("join_start: %+v", j)
	}
	time.Sleep(60 * time.Millisecond)
	if s := link(t, "state", map[string]any{"link": j.Link}); s.Ready || s.St != lsOffer {
		t.Fatalf("ready with no relay: %+v", s)
	}
	slow.up.Store(true)
	end := time.Now().Add(5 * time.Second)
	for !link(t, "state", map[string]any{"link": j.Link}).Ready {
		if time.Now().After(end) {
			t.Fatal("never ready once the relays answered")
		}
		time.Sleep(2 * time.Millisecond)
	}
}

// posts that fail for a while are tried again: the link goes on, never
// ends at the first relay that blinks
func TestPostsThatFailAreTriedAgain(t *testing.T) {
	quickBackoffs(t)
	w := newLinkWorld(t)
	slow := &slowRelay{fakeRelay: w.relay}
	slow.up.Store(true)
	slow.postFails.Store(3)
	linkWireNow = slow
	jid, pid, _ := w.toDigits(t)
	if s := waitState(t, jid, lsDigits, lsFailed); s.St != lsDigits {
		t.Fatalf("the joiner: %+v", s)
	}
	if s := waitState(t, pid, lsDigits, lsFailed); s.St != lsDigits {
		t.Fatalf("the phone: %+v", s)
	}
	slow.postFails.Store(2)
	w.toBundles(t, jid, pid)
}

// a fake clock for the link runs, stepped by the tests
func linkTestClock(t *testing.T) func(time.Duration) {
	old := linkClock
	t.Cleanup(func() { linkClock = old })
	var cmu sync.Mutex
	at := time.Now()
	linkClock = func() time.Time { cmu.Lock(); defer cmu.Unlock(); return at }
	return func(d time.Duration) { cmu.Lock(); at = at.Add(d); cmu.Unlock() }
}

// both sides confirmed and the joiner placed, its bundles to make: many,
// so they take several lines
func (w *linkWorld) toPlaced(t *testing.T, jid, pid string, many int) (devEntry, map[string]any) {
	t.Helper()
	w.phoneConfirms(t, pid)
	link(t, "confirm", map[string]any{"link": jid})
	placed := waitState(t, jid, lsPlaced)
	dev := *placed.Device
	jState := w.load(t, w.phone.id.pub, w.devKey.pub)
	w.as(jState)
	if own := link(t, "own", map[string]any{"link": jid, "ident": 0}); own.Err != "" {
		t.Fatalf("own: %s", own.Err)
	}
	var once [][]byte
	for k := 0; k < many; k++ {
		once = append(once, linkKDB1(t, dev, uint32(10+k)))
	}
	return dev, map[string]any{"link": jid, "first": linkKDB1(t, dev, 1), "last": linkKDB1(t, dev, 2),
		"once": once, "made": time.Now().UnixMilli()}
}

// once both confirmed a run ends only when nothing moves: a big identity's
// lines over a slow tor may take past the code's own life
func TestALinkThatMovesOutlivesItsTenMinutes(t *testing.T) {
	w := newLinkWorld(t)
	step := linkTestClock(t)
	door := pipeDoor(&w.lines)
	// every line takes a minute and a half to get through
	linkDialNow = func(ctx context.Context, onion, line string) error {
		step(90 * time.Second)
		return door(ctx, onion, line)
	}
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	_, b := w.toPlaced(t, jid, pid, 400)
	// making the bundles takes a while too, within the phone's grace for
	// them: the app says so, past the joiner's own idle wait
	for i := 0; i < 3; i++ {
		step(65 * time.Second)
		if o := link(t, "touch", map[string]any{"link": jid}); o.Err != "" {
			t.Fatalf("touch: %s", o.Err)
		}
		time.Sleep(10 * time.Millisecond)
	}
	if o := link(t, "bundles", b); o.Err != "" {
		t.Fatalf("bundles: %s", o.Err)
	}
	p := waitState(t, pid, lsBundles, lsFailed)
	// past the old fifteen minutes in all
	if p.St != lsBundles || p.Of < 10 {
		t.Fatalf("the phone: %+v", p)
	}
	w.as(w.pState)
	link(t, "take", map[string]any{"link": pid})
	if k := link(t, "kept", map[string]any{"link": pid}); k.Err != "" {
		t.Fatalf("kept: %s", k.Err)
	}
	if s := waitState(t, jid, lsDone, lsFailed); s.St != lsDone {
		t.Fatalf("the joiner after %d slow lines: %+v", p.Of, s)
	}
}

// a phone that stops answering before the last line: the joiner ends once
// nothing moved for linkIdle, the phone too, neither keeps anything
func TestALinkWhereNothingMovesEnds(t *testing.T) {
	quickBackoffs(t)
	w := newLinkWorld(t)
	step := linkTestClock(t)
	linkDialNow = func(ctx context.Context, onion, line string) error {
		return errors.New("the phone is out")
	}
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	_, b := w.toPlaced(t, jid, pid, 80)
	link(t, "bundles", b)
	end := time.Now().Add(5 * time.Second)
	for link(t, "state", map[string]any{"link": jid}).Of == 0 {
		if time.Now().After(end) {
			t.Fatal("never sending")
		}
		time.Sleep(2 * time.Millisecond)
	}
	time.Sleep(20 * time.Millisecond)
	step(linkIdle + time.Second)
	if s := waitState(t, jid, lsFailed); s.Why != lsWhyReach && s.Why != lsWhyGone {
		t.Fatalf("an idle joiner: %+v", s)
	}
	step(linkBundlesLate)
	if s := waitState(t, pid, lsFailed); s.Why != lsWhyReach && s.Why != lsWhyGone {
		t.Fatalf("an idle phone: %+v", s)
	}
}

// the phone hears nothing while the new device makes its bundles: it waits
// the bundles' own grace, longer than linkIdle, before its first line
func TestThePhoneWaitsForBundlesBeingMade(t *testing.T) {
	w := newLinkWorld(t)
	step := linkTestClock(t)
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	w.toPlaced(t, jid, pid, 80)
	// the joiner's app makes bundles and says so; the phone hears nothing
	for i := 0; i < 2; i++ {
		step(2 * time.Minute)
		link(t, "touch", map[string]any{"link": jid})
		time.Sleep(20 * time.Millisecond)
	}
	if s := link(t, "state", map[string]any{"link": pid}); s.St != lsLinking {
		t.Fatalf("the phone gave up on bundles being made: %+v", s)
	}
	step(linkBundlesLate)
	if s := waitState(t, pid, lsFailed); s.Why != lsWhyReach && s.Why != lsWhyGone {
		t.Fatalf("the phone after the grace: %+v", s)
	}
}

// the phone kept the device, the ack of the last line was lost and the
// phone's onion is out past linkIdle: the joiner keeps trying that line and
// links once the phone is back, never a phantom on the phone
func TestALostLastAckNeverLeavesAPhantom(t *testing.T) {
	quickBackoffs(t)
	w := newLinkWorld(t)
	step := linkTestClock(t)
	door := pipeDoor(&w.lines)
	var lost atomic.Int32
	var down atomic.Bool
	linkDialNow = func(ctx context.Context, onion, line string) error {
		if down.Load() {
			return errors.New("phone out")
		}
		err := door(ctx, onion, line)
		if err == nil && lost.Add(1) == 1 {
			down.Store(true)
			return errors.New("ack lost")
		}
		return err
	}
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	w.toBundles(t, jid, pid)
	w.as(w.pState)
	if pt := link(t, "take", map[string]any{"link": pid}); pt.Err != "" {
		t.Fatalf("take: %s", pt.Err)
	}
	if k := link(t, "kept", map[string]any{"link": pid}); k.Err != "" {
		t.Fatalf("kept: %s", k.Err)
	}
	// the phone out for twice linkIdle, a minute at a time while the
	// joiner tries that line
	for i := 0; i < 6; i++ {
		time.Sleep(30 * time.Millisecond)
		step(time.Minute)
	}
	time.Sleep(30 * time.Millisecond)
	if s := link(t, "state", map[string]any{"link": jid}); s.St != lsSending {
		t.Fatalf("the joiner gave up on a phone that kept it: %+v", s)
	}
	down.Store(false)
	if s := waitState(t, jid, lsDone, lsFailed); s.St != lsDone {
		t.Fatalf("the joiner once the phone is back: %+v", s)
	}
}

// the same line again moves nothing on the phone: a joiner that resends it
// never keeps the phone's run open
func TestALineAgainMovesNothing(t *testing.T) {
	w := newLinkWorld(t)
	step := linkTestClock(t)
	var mu2 sync.Mutex
	var first string
	door := pipeDoor(&w.lines)
	linkDialNow = func(ctx context.Context, onion, line string) error {
		mu2.Lock()
		if first == "" {
			first = line
			mu2.Unlock()
			return door(ctx, onion, line)
		}
		mu2.Unlock()
		// the rest never comes
		return errors.New("slow")
	}
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	_, b := w.toPlaced(t, jid, pid, 80)
	link(t, "bundles", b)
	end := time.Now().Add(5 * time.Second)
	for {
		mu2.Lock()
		f := first
		mu2.Unlock()
		if f != "" {
			break
		}
		if time.Now().After(end) {
			t.Fatal("no first line")
		}
		time.Sleep(2 * time.Millisecond)
	}
	pr, _ := runOf(pid)
	end = time.Now().Add(5 * time.Second)
	for {
		pr.mu.Lock()
		at := pr.at
		pr.mu.Unlock()
		if at == 1 {
			break
		}
		if time.Now().After(end) {
			t.Fatal("the phone never took the first line")
		}
		time.Sleep(2 * time.Millisecond)
	}
	pr.mu.Lock()
	was := pr.moved
	pr.mu.Unlock()
	step(time.Minute)
	if err := pipeDoor(nil)(context.Background(), testPhoneOnion, first); err != nil {
		t.Fatalf("the line again: %v", err)
	}
	pr.mu.Lock()
	now := pr.moved
	pr.mu.Unlock()
	if !now.Equal(was) {
		t.Fatal("the same line again moved the phone's run")
	}
}

// before both confirmed the code's life still holds
func TestAnUnansweredCodeStillRunsOut(t *testing.T) {
	w := newLinkWorld(t)
	old := linkClock
	t.Cleanup(func() { linkClock = old })
	var cmu sync.Mutex
	at := time.Now()
	linkClock = func() time.Time { cmu.Lock(); defer cmu.Unlock(); return at }
	j := link(t, "join_start", map[string]any{"key": hexKey(w.devKey.pub), "reg": 4321})
	waitState(t, j.Link, lsOffer)
	cmu.Lock()
	at = at.Add(devices.LinkLife + linkBundlesLate + time.Second)
	cmu.Unlock()
	if s := waitState(t, j.Link, lsFailed); s.Why != lsWhyTime {
		t.Fatalf("an old code: %+v", s)
	}
}

// the door's ack of the last line lost on the way: the new device sends it
// again and is acked once the phone kept it, never refused and never left
// trying for the rest of its time while the phone shows it linked
func TestALastLineAgainIsAckedOnceKept(t *testing.T) {
	w := newLinkWorld(t)
	var mu2 sync.Mutex
	var lines []string
	door := pipeDoor(&w.lines)
	linkDialNow = func(ctx context.Context, onion, line string) error {
		mu2.Lock()
		lines = append(lines, line)
		mu2.Unlock()
		return door(ctx, onion, line)
	}
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	w.toBundles(t, jid, pid)
	p := link(t, "state", map[string]any{"link": pid})
	if p.At != 1 || p.Of != 1 {
		t.Fatalf("the phone's progress: %d of %d", p.At, p.Of)
	}
	if pt := link(t, "take", map[string]any{"link": pid}); pt.Err != "" {
		t.Fatalf("take: %s", pt.Err)
	}
	mu2.Lock()
	last := lines[len(lines)-1]
	mu2.Unlock()
	// the same line again while the phone still keeps: answered as the
	// first is, once kept
	got := make(chan error, 1)
	go func() { got <- pipeDoor(nil)(context.Background(), testPhoneOnion, last) }()
	time.Sleep(30 * time.Millisecond)
	if k := link(t, "kept", map[string]any{"link": pid}); k.Err != "" {
		t.Fatalf("kept: %s", k.Err)
	}
	if err := <-got; err != nil {
		t.Fatalf("the line again while keeping: %v", err)
	}
	if s := waitState(t, jid, lsDone, lsFailed); s.St != lsDone || s.At != 1 || s.Of != 1 {
		t.Fatalf("the joiner: %+v", s)
	}
	// and after: still acked, for a while
	if err := pipeDoor(nil)(context.Background(), testPhoneOnion, last); err != nil {
		t.Fatalf("the line again after the keep: %v", err)
	}
}

// a line again for a link the phone never kept is not acked
func TestALineAgainIsNotAckedWhenThePhoneKeptNothing(t *testing.T) {
	w := newLinkWorld(t)
	linkKeptWait = 150 * time.Millisecond
	var mu2 sync.Mutex
	var lines []string
	door := pipeDoor(&w.lines)
	linkDialNow = func(ctx context.Context, onion, line string) error {
		mu2.Lock()
		lines = append(lines, line)
		mu2.Unlock()
		return door(ctx, onion, line)
	}
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	w.toBundles(t, jid, pid)
	link(t, "take", map[string]any{"link": pid})
	waitState(t, pid, lsFailed)
	mu2.Lock()
	last := lines[len(lines)-1]
	mu2.Unlock()
	if err := pipeDoor(nil)(context.Background(), testPhoneOnion, last); err == nil {
		t.Fatal("a line of a link kept nowhere acked")
	}
}
