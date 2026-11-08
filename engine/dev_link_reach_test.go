// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
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

// once both confirmed only a run where nothing moves ends: a big identity's
// bundles over a slow tor may take past the code's own life
func TestALinkEndsOnlyWhenNothingMoves(t *testing.T) {
	w := newLinkWorld(t)
	old := linkClock
	t.Cleanup(func() { linkClock = old })
	var cmu sync.Mutex
	at := time.Now()
	linkClock = func() time.Time { cmu.Lock(); defer cmu.Unlock(); return at }
	step := func(d time.Duration) { cmu.Lock(); at = at.Add(d); cmu.Unlock() }
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	w.phoneConfirms(t, pid)
	link(t, "confirm", map[string]any{"link": jid})
	waitState(t, jid, lsPlaced)
	r, _ := runOf(jid)
	pr, _ := runOf(pid)
	// twenty minutes of a slow transfer, a line every two, on both sides:
	// the clock moves under both runs at once
	for i := 0; i < 10; i++ {
		step(2 * time.Minute)
		r.touch()
		pr.touch()
		time.Sleep(15 * time.Millisecond)
	}
	if s := link(t, "state", map[string]any{"link": jid}); s.St != lsPlaced {
		t.Fatalf("a moving link ended: %+v", s)
	}
	step(linkIdle + time.Second)
	// whichever side notices first, the other hears it
	if s := waitState(t, jid, lsFailed); s.Why != lsWhyReach && s.Why != lsWhyGone {
		t.Fatalf("an idle link: %+v", s)
	}
	if s := waitState(t, pid, lsFailed); s.Why != lsWhyReach && s.Why != lsWhyGone {
		t.Fatalf("an idle link, the phone: %+v", s)
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
