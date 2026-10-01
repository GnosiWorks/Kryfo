// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	"github.com/halo/engine/catchup"
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

func TestCatchupCapDropsSlowRelay(t *testing.T) {
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
	ms, dropped, _, seen := catchupOf("wss://slow.example")
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

func TestCatchupCapLeavesQuickRelay(t *testing.T) {
	atomic.StoreInt32(&catchupActive, 0)
	settled, cancels := settlePair("wss://quick.example", 2*time.Second)

	time.Sleep(60 * time.Millisecond)
	settled()

	if got := atomic.LoadInt32(&catchupActive); got != 0 {
		t.Fatalf("a finished relay should leave active at 0, got %d", got)
	}
	ms, dropped, _, seen := catchupOf("wss://quick.example")
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
	if _, dropped, _, _ := catchupOf("wss://b.example"); !dropped {
		t.Fatal("the slow relay should be marked dropped")
	}
	for _, u := range []string{"wss://a.example", "wss://c.example"} {
		if _, dropped, _, _ := catchupOf(u); dropped {
			t.Fatalf("%s finished and must not be marked dropped", u)
		}
	}
}

// the cap is the whole point: it has to be well under the job's window.
func TestCatchupCapUnderJobWindow(t *testing.T) {
	if catchupCap > 45*time.Second {
		t.Fatalf("catchupCap is %s; the job has under three minutes and the "+
			"check-in waits for every relay in turn", catchupCap)
	}
}

// three drops in a row buy one longer window, then it goes back to normal.
func TestThreeDropsBuyLongWindow(t *testing.T) {
	u := "wss://stubborn.example"
	catchupMu.Lock()
	delete(catchupDrops, u)
	delete(catchupLast, u)
	delete(catchupLong, u)
	catchupMu.Unlock()

	for i := 1; i <= 3; i++ {
		d, long := catchupCapFor(u)
		if long {
			t.Fatalf("drop %d should still be the normal window", i)
		}
		if d != catchupCap {
			t.Fatalf("drop %d got %s, want %s", i, d, catchupCap)
		}
		noteCatchupStart(u)
		noteCatchupDone(u, true)
	}

	d, long := catchupCapFor(u)
	if !long || d != catchupLongCap {
		t.Fatalf("after three drops want one %s window, got %s long=%v",
			catchupLongCap, d, long)
	}
	noteCatchupStart(u)
	noteCatchupDone(u, true)
	if _, _, wasLong, _ := catchupOf(u); !wasLong {
		t.Fatal("the long turn should be recorded so the screen can show it")
	}

	// and it is one turn, not a new normal
	if d, long := catchupCapFor(u); long || d != catchupCap {
		t.Fatalf("the window after the long one should be normal, got %s long=%v", d, long)
	}
}

// a relay that finishes clears its record, so an old bad patch does not earn
// it a long window later.
func TestFinishClearsDropCount(t *testing.T) {
	u := "wss://recovers.example"
	catchupMu.Lock()
	delete(catchupDrops, u)
	catchupMu.Unlock()

	for i := 0; i < 2; i++ {
		catchupCapFor(u)
		noteCatchupStart(u)
		noteCatchupDone(u, true)
	}
	catchupCapFor(u)
	noteCatchupStart(u)
	noteCatchupDone(u, false)

	catchupMu.Lock()
	n := catchupDrops[u]
	catchupMu.Unlock()
	if n != 0 {
		t.Fatalf("a finished catch-up should clear the count, got %d", n)
	}
	if d, long := catchupCapFor(u); long || d != catchupCap {
		t.Fatalf("want the normal window after a success, got %s long=%v", d, long)
	}
}

// a relay carries one subscription per contact, and each catches up on its
// own: its own start time, drop count and place in the backlog.
func TestCatchupIsPerContact(t *testing.T) {
	u := "wss://shared.example"
	a, b := catchupKey(u, "aaaa"), catchupKey(u, "bbbb")

	noteCatchupStart(a)
	noteCatchupStart(b)
	time.Sleep(40 * time.Millisecond)
	noteCatchupDone(a, false) // quick
	time.Sleep(120 * time.Millisecond)
	noteCatchupDone(b, true) // held up until the cap

	ms, dropped, _, seen := catchupOf(u)
	if !seen || !dropped {
		t.Fatalf("the relay should show its slowest subscription, the dropped one: seen=%v dropped=%v", seen, dropped)
	}
	if ms < 140 {
		t.Fatalf("the drop was recorded after %dms; it ran for about 160", ms)
	}
	if _, _, _, subs, drops := catchupDetailOf(u); subs != 2 || drops != 1 {
		t.Fatalf("want 2 subscriptions with 1 dropped, got %d and %d", subs, drops)
	}

	// each keeps its own place in the backlog
	setCatchupMark(a, catchup.Mark{Top: 100, Cursor: 50})
	if catchupMarkOf(b).Started() {
		t.Fatal("one contact's backlog mark leaked into another's")
	}
	setCatchupMark(a, catchup.Mark{})

	// and its own drop count: b's drops buy b a long turn, not a
	for i := 0; i < catchupDropsBeforeLong; i++ {
		noteCatchupStart(b)
		noteCatchupDone(b, true)
	}
	if _, long := catchupCapFor(a); long {
		t.Fatal("a got the long turn for b's drops")
	}
	if _, long := catchupCapFor(b); !long {
		t.Fatal("b did not get its long turn")
	}
}

// a first answer cut by the cap keeps its place: the next walk steps over
// what came, and a place from before is joined, not thrown away. only our
// relay holds anything for it.
func TestCutFirstAnswerKeepsItsPlace(t *testing.T) {
	now := time.Unix(2_000_000, 0)
	top := nostr.Timestamp(now.Add(anchorSlack).Unix())
	k := "wss://cut.example addr"
	pub := "wss://public.example addr"
	clear := func() {
		catchupMu.Lock()
		for _, key := range []string{k, pub} {
			delete(catchupMarks, key)
			delete(catchupHolds, key)
			delete(catchupFreed, key)
		}
		catchupMu.Unlock()
	}
	clear()
	defer clear()
	owed := catchup.Hold{Floor: 1_400_000, Began: 1_999_000}
	c := catchup.Conn{Key: k, Own: true, Owed: owed}

	keepFirstAnswer(c, 0, now)
	if catchupMarkOf(k).Started() || catchupHoldOf(k).Held() {
		t.Fatal("an answer with nothing in it kept a place")
	}
	keepFirstAnswer(c, 1_500_000, now)
	if m := catchupMarkOf(k); m.Top != top || m.Cursor != 1_500_000 {
		t.Fatalf("first cut: %+v", m)
	}
	if h := catchupHoldOf(k); h != owed {
		t.Fatalf("the cut keeps %+v, want what the walk owes, %+v", h, owed)
	}
	// the next one got less far: the place stays as deep as it was
	keepFirstAnswer(c, 1_800_000, now)
	if m := catchupMarkOf(k); m.Cursor != 1_500_000 {
		t.Fatalf("a shallower cut moved the place up: %+v", m)
	}
	// one that got deeper moves it down
	keepFirstAnswer(c, 1_200_000, now)
	if m := catchupMarkOf(k); m.Cursor != 1_200_000 {
		t.Fatalf("a deeper cut did not move the place: %+v", m)
	}
	// a walk's place with a gap above it is left alone
	setCatchupMark(k, catchup.Mark{Top: 1_000_000, Cursor: 900_000})
	keepFirstAnswer(c, 1_100_000, now)
	if m := catchupMarkOf(k); m.Top != 1_000_000 || m.Cursor != 900_000 {
		t.Fatalf("a cut with a gap replaced the walk's place: %+v", m)
	}
	// a public relay keeps its place and holds nothing
	keepFirstAnswer(catchup.Conn{Key: pub}, 1_500_000, now)
	if !catchupMarkOf(pub).Started() || catchupHoldOf(pub).Held() {
		t.Fatalf("a public relay's cut: place %+v, hold %+v", catchupMarkOf(pub), catchupHoldOf(pub))
	}
}
