// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// the same shape as the settle/cap pair in the relay runner: whichever fires
// first wins the Once, so a relay is either finished or dropped, and
// catchupActive is decremented exactly once either way. getting that wrong
// leaks the counter and a check-in waits for a relay that is already gone.
func settlePair(u string, cap time.Duration) (done func(), cancelled *int32) {
	var once sync.Once
	var capT *time.Timer
	var cancels int32
	noteCatchupStart(u)
	settled := func() {
		once.Do(func() {
			if capT != nil {
				capT.Stop()
			}
			atomic.AddInt32(&catchupActive, -1)
			noteCatchupDone(u, false)
		})
	}
	capT = time.AfterFunc(cap, func() {
		once.Do(func() {
			atomic.AddInt32(&catchupActive, -1)
			noteCatchupDone(u, true)
			atomic.AddInt32(&cancels, 1)
		})
	})
	atomic.AddInt32(&catchupActive, 1)
	return settled, &cancels
}

func TestCatchupCapDropsASlowRelay(t *testing.T) {
	atomic.StoreInt32(&catchupActive, 0)
	settled, cancels := settlePair("wss://slow.example", 120*time.Millisecond)

	if got := atomic.LoadInt32(&catchupActive); got != 1 {
		t.Fatalf("active should be 1 while it runs, got %d", got)
	}
	// never finishes on its own
	time.Sleep(400 * time.Millisecond)

	if got := atomic.LoadInt32(&catchupActive); got != 0 {
		t.Fatalf("the cap must release the relay; active is still %d", got)
	}
	ms, dropped, seen := catchupOf("wss://slow.example")
	if !seen || !dropped {
		t.Fatalf("want a recorded drop, got seen=%v dropped=%v", seen, dropped)
	}
	if ms < 100 || ms > 350 {
		t.Fatalf("recorded %dms, expected about the cap", ms)
	}
	if atomic.LoadInt32(cancels) != 1 {
		t.Fatal("the backfill should have been cancelled exactly once")
	}

	// a late finish must not decrement a second time
	settled()
	if got := atomic.LoadInt32(&catchupActive); got != 0 {
		t.Fatalf("a settle after the cap double-counted: active %d", got)
	}
}

func TestCatchupCapLeavesAQuickRelayAlone(t *testing.T) {
	atomic.StoreInt32(&catchupActive, 0)
	settled, cancels := settlePair("wss://quick.example", 2*time.Second)

	time.Sleep(60 * time.Millisecond)
	settled()

	if got := atomic.LoadInt32(&catchupActive); got != 0 {
		t.Fatalf("a finished relay should leave active at 0, got %d", got)
	}
	ms, dropped, seen := catchupOf("wss://quick.example")
	if !seen || dropped {
		t.Fatalf("a relay that finished must not be marked dropped: %v %v", seen, dropped)
	}
	if ms > 500 {
		t.Fatalf("recorded %dms for a relay that took 60ms", ms)
	}
	// and the cap must not fire afterwards
	time.Sleep(2200 * time.Millisecond)
	if got := atomic.LoadInt32(&catchupActive); got != 0 {
		t.Fatalf("the cap fired after a normal finish: active %d", got)
	}
	if atomic.LoadInt32(cancels) != 0 {
		t.Fatal("a finished relay's backfill must not be cancelled")
	}
}

// several relays at once: the slow ones are dropped, the quick ones are not,
// and the counter lands back on zero so a check-in can end.
func TestCatchupCapWithSeveralRelays(t *testing.T) {
	atomic.StoreInt32(&catchupActive, 0)
	quick, _ := settlePair("wss://a.example", time.Second)
	_, _ = settlePair("wss://b.example", 100*time.Millisecond)
	alsoQuick, _ := settlePair("wss://c.example", time.Second)

	if got := atomic.LoadInt32(&catchupActive); got != 3 {
		t.Fatalf("want 3 active, got %d", got)
	}
	quick()
	alsoQuick()
	time.Sleep(300 * time.Millisecond)

	if got := atomic.LoadInt32(&catchupActive); got != 0 {
		t.Fatalf("one slow relay held the check-in open: active %d", got)
	}
	if _, dropped, _ := catchupOf("wss://b.example"); !dropped {
		t.Fatal("the slow relay should be marked dropped")
	}
	for _, u := range []string{"wss://a.example", "wss://c.example"} {
		if _, dropped, _ := catchupOf(u); dropped {
			t.Fatalf("%s finished and must not be marked dropped", u)
		}
	}
}

// the cap is the whole point: it has to be well under the job's window.
func TestCatchupCapIsWellUnderTheJobWindow(t *testing.T) {
	if catchupCap > 45*time.Second {
		t.Fatalf("catchupCap is %s; the job has under three minutes and the "+
			"check-in waits for every relay in turn", catchupCap)
	}
}
