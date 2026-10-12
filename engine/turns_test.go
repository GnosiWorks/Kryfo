// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"os"
	"sort"
	"sync/atomic"
	"testing"
	"time"
)

// sockets subscribe at once in tests, unless a test asks for turns
func TestMain(m *testing.M) {
	subSpread = 0
	os.Exit(m.Run())
}

// the free turn after the current kick, used up
func spendFirstTurn() { takeFirstTurn(kickChan()) }

// when each address first asked the relay, from start
func firstAsks(r *relayStandIn, start time.Time) []time.Duration {
	var out []time.Duration
	for _, c := range r.snapshot() {
		if len(c.reqs) > 0 {
			out = append(out, c.reqs[0].at.Sub(start))
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i] < out[j] })
	return out
}

// how long from start until the first and until every address asked
func measureStart(t *testing.T, spread time.Duration) (first, all time.Duration) {
	t.Helper()
	old := subSpread
	subSpread = spread
	defer func() { subSpread = old }()
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	// a start as a fresh process has it: no socket has asked since the kick
	kickRelays()
	start := time.Now()
	l := startLanes(t, ctx, 11, 0)
	waitFor(t, "every address asked", spread+15*time.Second, func() bool {
		return len(firstAsks(relay, start)) >= l.subs()
	})
	at := firstAsks(relay, start)
	return at[0], at[len(at)-1]
}

// the window is cut to a few seconds here. the real one, slow:
//
//	HALO_TURN_WINDOW=1m go test -run TestTurnsSpreadTheStart -v .
func TestTurnsSpreadTheStart(t *testing.T) {
	w := 4 * time.Second
	if d, err := time.ParseDuration(os.Getenv("HALO_TURN_WINDOW")); err == nil && d > 0 {
		w = d
	}
	firstBefore, allBefore := measureStart(t, 0)
	firstAfter, allAfter := measureStart(t, w)
	t.Logf("start to first and to all subscribed: %s and %s with no turns, %s and %s with turns over %s",
		firstBefore.Round(time.Millisecond), allBefore.Round(time.Millisecond),
		firstAfter.Round(time.Millisecond), allAfter.Round(time.Millisecond), w)
	apartBefore, apartAfter := allBefore-firstBefore, allAfter-firstAfter
	if apartBefore > w/4 {
		t.Fatalf("with no turns the asks were %s apart", apartBefore)
	}
	// twelve draws over the window all within a quarter of it: about 1e-6
	if apartAfter < w/4 {
		t.Fatalf("turns over %s left the asks only %s apart", w, apartAfter)
	}
	if allAfter > w+5*time.Second {
		t.Fatalf("every address asked only %s after the start", allAfter)
	}
	// the first goes at once, so the route is up as soon as before
	if firstAfter > firstBefore+time.Second {
		t.Fatalf("the first address asked %s after the start", firstAfter)
	}
}

// a socket waiting its turn is a catch-up under way: a check-in that saw
// nothing counted would stop tor before it had asked
func TestATurnCountsAsACatchup(t *testing.T) {
	old := subSpread
	subSpread = time.Hour
	defer func() { subSpread = old }()
	spendFirstTurn()
	active, begun := atomic.LoadInt32(&catchupActive), atomic.LoadInt64(&catchupStarted)
	ctx, cancel := context.WithCancel(context.Background())
	var tn subTurn
	done := make(chan bool)
	go func() { done <- tn.take(ctx) }()
	waitFor(t, "the turn counted", 5*time.Second, func() bool {
		return atomic.LoadInt32(&catchupActive) == active+1
	})
	if atomic.LoadInt64(&catchupStarted) != begun {
		t.Fatal("a turn counted as a catch-up begun")
	}
	cancel()
	if <-done {
		t.Fatal("a turn ended by its context said go")
	}
	tn.done()
	tn.done()
	if got := atomic.LoadInt32(&catchupActive); got != active {
		t.Fatalf("%d catch-ups left counted, want %d", got, active)
	}
}

// one turn per start and per wake: a socket that redials without a kick in
// between goes at once, one that has not got through since its last turn
// takes no new one, and a kick it answered on its live socket gives it no
// second turn. the open chat's address asks with no turn at all
func TestOneTurnPerWake(t *testing.T) {
	old := subSpread
	subSpread = time.Hour
	defer func() { subSpread = old }()
	quick := func(tn *subTurn) bool {
		ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
		defer cancel()
		ok := tn.take(ctx)
		tn.done()
		return ok
	}
	spendFirstTurn()
	var tn subTurn
	if quick(&tn) {
		t.Fatal("the first subscribe went without a turn")
	}
	tn.dialed(true)
	if !quick(&tn) {
		t.Fatal("a redial with no wake waited a turn")
	}
	kickRelays()
	spendFirstTurn()
	if quick(&tn) {
		t.Fatal("a wake went without a turn")
	}
	// no dial got through since that turn: the next kick is no new one
	kickRelays()
	spendFirstTurn()
	if !quick(&tn) {
		t.Fatal("a kick before the socket got through cost it a second turn")
	}
	tn.dialed(true)
	kickRelays()
	tn.skip()
	if !quick(&tn) {
		t.Fatal("a kick answered on the live socket gave a second turn")
	}
	// the first to ask after a wake goes at once, the next waits
	kickRelays()
	var a, b subTurn
	if !quick(&a) {
		t.Fatal("the first socket after a wake went with a turn")
	}
	if quick(&b) {
		t.Fatal("a second socket after a wake went at once too")
	}
	// the open chat's address goes at once
	firstTag.Store("peer-on-screen")
	defer firstTag.Store("")
	kickRelays()
	spendFirstTurn()
	open := subTurn{tag: "peer-on-screen"}
	if !quick(&open) {
		t.Fatal("the open chat's address waited a turn")
	}
	other := subTurn{tag: "someone-else"}
	if quick(&other) {
		t.Fatal("another address went at once with the open chat's")
	}
}

// a socket that goes with no turn, as the open chat's or one that has not
// got through since its last, is counted until its dial is over too
func TestNoTurnStillCounts(t *testing.T) {
	old := subSpread
	subSpread = time.Hour
	defer func() { subSpread = old }()
	ctx := context.Background()
	base := settledActive(t)
	firstTag.Store("peer-on-screen")
	defer firstTag.Store("")
	open := subTurn{tag: "peer-on-screen"}
	kickRelays()
	spendFirstTurn()
	if !open.take(ctx) {
		t.Fatal("the open chat's address waited")
	}
	if atomic.LoadInt32(&catchupActive) != base+1 {
		t.Fatal("the open chat's dial was not counted")
	}
	open.dialed(true)
	// one that took a turn and never got through goes again at once on the
	// next kick, counted
	var tn subTurn
	tn.kick = kickChan()
	kickRelays()
	if !tn.take(ctx) {
		t.Fatal("a socket that never got through waited a second turn")
	}
	if atomic.LoadInt32(&catchupActive) != base+1 {
		t.Fatal("a redial with no turn was not counted")
	}
	tn.dialed(false)
	if atomic.LoadInt32(&catchupActive) != base {
		t.Fatal("a dial over left a count behind")
	}
}

// the app's check-in budget from its job's start (main.dart, kCheck*): tor
// carries by 90, the listeners by 95, the kick by 105 or never, the answers
// are waited for until 120. then the tail: a wait for the drain, the
// missing-slice asks and the outbox, and tor's sleep
const (
	checkInKickBy    = 105 * time.Second
	checkInLoopBy    = 120 * time.Second
	checkInDrainWait = 2 * time.Second
	checkInAskWait   = 3 * time.Second
	checkInOutbox    = 5 * time.Second
	checkInSleep     = 6 * time.Second
	// all of it done by about here, well inside the job's hard stop at 170
	// (HaloPeriodicJobService)
	checkInAllDone = 137 * time.Second
)

// out of a check-in turns cover the whole minute. in one they are a few
// seconds and over soon after the job began, however late the app opened
// the window, so the dial, the longest catch-up and the tail behind the
// last one end before the job is stopped. a kick's delay follows the same
// bound
func TestTurnsFitACheckIn(t *testing.T) {
	old, oldKick := subSpread, kickSpread
	subSpread, kickSpread = time.Minute, time.Minute
	defer func() { subSpread, kickSpread = old, oldKick }()
	now := time.Date(2026, 10, 12, 12, 0, 0, 0, time.UTC)
	oldNow := autoNow
	autoNow = func() time.Time { return now }
	defer func() { autoNow = oldNow }()
	checkInMu.Lock()
	oldUntil := checkInUntil
	checkInMu.Unlock()
	defer func() {
		checkInMu.Lock()
		checkInUntil = oldUntil
		checkInMu.Unlock()
		noteCheckIn(0)
	}()
	spread := func(draw func() time.Duration) (lo, hi time.Duration) {
		lo = time.Hour
		for i := 0; i < 2000; i++ {
			d := draw()
			lo, hi = min(lo, d), max(hi, d)
		}
		return
	}
	turn := func() time.Duration { return turnDelay(now) }
	checkInMu.Lock()
	checkInUntil = time.Time{}
	checkInMu.Unlock()
	noteCheckIn(0)
	for name, draw := range map[string]func() time.Duration{"turn": turn, "kick": kickDelay} {
		if lo, hi := spread(draw); lo > 3*time.Second || hi < 57*time.Second || hi >= time.Minute {
			t.Fatalf("%s out of a check-in from %s to %s", name, lo, hi)
		}
	}
	// the job began [job] before the app opened the window, which was
	// [open] ago
	for _, job := range []time.Duration{0, 5 * time.Second, 40 * time.Second} {
		for _, open := range []time.Duration{0, 5 * time.Second, 12 * time.Second, time.Minute} {
			checkInMu.Lock()
			checkInUntil = now.Add(-open).Add(checkInMax)
			checkInMu.Unlock()
			autoNow = func() time.Time { return now.Add(-open) }
			noteCheckIn(1 + int(job/time.Second))
			autoNow = func() time.Time { return now }
			since := job + open
			for name, draw := range map[string]func() time.Duration{"turn": turn, "kick": kickDelay} {
				_, hi := spread(draw)
				if hi > checkInSpread {
					t.Fatalf("a %s of %s in a check-in", name, hi)
				}
				if end := since + hi; hi > 0 && end > checkInTurnsBy {
					t.Fatalf("%s %s after the job began, past %s", name, end, checkInTurnsBy)
				}
			}
		}
	}
	// a socket's last turn, its dial and its longest catch-up are in before
	// the app stops waiting
	checkInMu.Lock()
	checkInUntil = now.Add(checkInMax)
	checkInMu.Unlock()
	dial := checkInBound(onionDialWait, checkInDialWait)
	long := checkInBound(catchupLongCap, checkInLongCap)
	if checkInTurnsBy+dial+long > checkInLoopBy {
		t.Fatalf("the last turn, a %s dial and a %s catch-up end past %s", dial, long, checkInLoopBy)
	}
	// a live socket kicked as late as the app kicks: no delay, the probe,
	// the redial and a usual catch-up, or the app's wait ends first
	if checkInKickBy > checkInLoopBy {
		t.Fatal("the kick can come after the wait")
	}
	if checkInLoopBy+checkInDrainWait+checkInAskWait+checkInOutbox+checkInSleep > checkInAllDone {
		t.Fatal("the tail and tor's sleep end past the budget")
	}
}

// the catch-up count once nothing has moved it for half a second
func settledActive(t *testing.T) int32 {
	t.Helper()
	v := atomic.LoadInt32(&catchupActive)
	still := time.Now()
	for end := time.Now().Add(10 * time.Second); time.Now().Before(end); {
		time.Sleep(50 * time.Millisecond)
		if n := atomic.LoadInt32(&catchupActive); n != v {
			v, still = n, time.Now()
		} else if time.Since(still) >= 500*time.Millisecond {
			return v
		}
	}
	t.Fatal("the catch-up count never settled")
	return 0
}

// the highest the catch-up count reaches while run runs, sampled tightly
func peakActive(run func()) int32 {
	var peak atomic.Int32
	peak.Store(atomic.LoadInt32(&catchupActive))
	stop := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		for {
			if n := atomic.LoadInt32(&catchupActive); n > peak.Load() {
				peak.Store(n)
			}
			select {
			case <-stop:
				return
			default:
				time.Sleep(100 * time.Microsecond)
			}
		}
	}()
	run()
	close(stop)
	<-done
	return peak.Load()
}

// with real turns, against a relay: the first address asks at once and the
// rest over the window, each counted as a catch-up until it is in. a kick
// then counts every live socket from the moment its delay is drawn until
// its probe is answered
func TestRealTurnsAndKicks(t *testing.T) {
	old, oldKick := subSpread, kickSpread
	subSpread, kickSpread = 2*time.Second, 8*time.Second
	defer func() { subSpread, kickSpread = old, oldKick }()
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	base := settledActive(t)
	kickRelays()
	start := time.Now()
	l := startLanes(t, ctx, 7, 0)
	waitFor(t, "the turns counted", time.Second, func() bool {
		return atomic.LoadInt32(&catchupActive) > base
	})
	waitFor(t, "every address asked", 10*time.Second, func() bool {
		return len(firstAsks(relay, start)) >= l.subs()
	})
	at := firstAsks(relay, start)
	if at[0] > 500*time.Millisecond {
		t.Fatalf("the first address asked %s after the start", at[0])
	}
	if at[len(at)-1]-at[0] < 500*time.Millisecond {
		t.Fatalf("the addresses asked only %s apart", at[len(at)-1]-at[0])
	}
	waitFor(t, "every catch-up in", 10*time.Second, func() bool {
		return atomic.LoadInt32(&catchupActive) == base
	})
	base = settledActive(t)

	// every live socket arms its delay at once; the first probe goes a
	// random part of eight seconds later
	peak := peakActive(func() {
		kickRelays()
		time.Sleep(300 * time.Millisecond)
	})
	if peak < base+int32(l.subs()) {
		t.Fatalf("after the kick the count reached %d, want %d", peak, base+int32(l.subs()))
	}
	waitFor(t, "every probe answered", 15*time.Second, func() bool {
		return atomic.LoadInt32(&catchupActive) == base
	})
	for _, c := range relay.snapshot() {
		if c.closed.IsZero() && len(c.subIDs) < 2 {
			t.Fatal("a live socket was not asked after the kick")
		}
	}
}

// a socket whose probe went unanswered after a kick redials counted, but
// once it finds tor asleep and parks, it counts no more: a check-in would
// otherwise wait out its whole budget on it. slow: the probe waits 30 s
func TestAParkedSocketCountsNothing(t *testing.T) {
	oldKick := kickSpread
	kickSpread = 50 * time.Millisecond
	defer func() { kickSpread = oldKick }()
	socks := newSocksStandIn(t)
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, relay)
	ctx, cancel := context.WithCancel(context.Background())
	defer func() {
		atomic.StoreInt32(&torPaused, 0)
		cancel()
		kickRelays()
	}()
	l := startLanes(t, ctx, 1, 0)
	waitFor(t, "every address asked", 10*time.Second, func() bool {
		n := 0
		for _, c := range relay.snapshot() {
			if len(c.subIDs) > 0 {
				n++
			}
		}
		return n >= l.subs()
	})
	base := settledActive(t)
	relay.mu.Lock()
	relay.probesQuiet = true
	relay.mu.Unlock()
	kickRelays()
	waitFor(t, "the kicked sockets counted", 2*time.Second, func() bool {
		return atomic.LoadInt32(&catchupActive) >= base+int32(l.subs())
	})
	atomic.StoreInt32(&torPaused, 1)
	waitFor(t, "the parked sockets let go", 45*time.Second, func() bool {
		return atomic.LoadInt32(&catchupActive) == base
	})
}
