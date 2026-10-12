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

// how long from start until every address asked, and how far apart the
// first and last were
func measureStart(t *testing.T, spread time.Duration) (all, apart time.Duration) {
	t.Helper()
	old := subSpread
	subSpread = spread
	defer func() { subSpread = old }()
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	start := time.Now()
	l := startLanes(t, ctx, 11, 0)
	waitFor(t, "every address asked", spread+15*time.Second, func() bool {
		return len(firstAsks(relay, start)) >= l.subs()
	})
	at := firstAsks(relay, start)
	return at[len(at)-1], at[len(at)-1] - at[0]
}

// the window is cut to a few seconds here. the real one, slow:
//
//	HALO_TURN_WINDOW=1m go test -run TestTurnsSpreadTheStart -v .
func TestTurnsSpreadTheStart(t *testing.T) {
	w := 4 * time.Second
	if d, err := time.ParseDuration(os.Getenv("HALO_TURN_WINDOW")); err == nil && d > 0 {
		w = d
	}
	allBefore, apartBefore := measureStart(t, 0)
	allAfter, apartAfter := measureStart(t, w)
	t.Logf("start to all subscribed: %s with no turns (%s apart), %s with turns over %s (%s apart)",
		allBefore.Round(time.Millisecond), apartBefore.Round(time.Millisecond),
		allAfter.Round(time.Millisecond), w, apartAfter.Round(time.Millisecond))
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
}

// a socket waiting its turn is a catch-up under way: a check-in that saw
// nothing counted would stop tor before it had asked
func TestATurnCountsAsACatchup(t *testing.T) {
	old := subSpread
	subSpread = time.Hour
	defer func() { subSpread = old }()
	active, begun := atomic.LoadInt32(&catchupActive), atomic.LoadInt64(&catchupStarted)
	ctx, cancel := context.WithCancel(context.Background())
	var tn subTurn
	done := make(chan bool)
	go func() { done <- tn.take(ctx) }()
	waitFor(t, "the turn counted", 5*time.Second, func() bool {
		return atomic.LoadInt32(&catchupActive) == active+1 &&
			atomic.LoadInt64(&catchupStarted) > begun
	})
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
// between goes at once, and a kick it answered on its live socket gives it
// no second turn
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
	var tn subTurn
	if quick(&tn) {
		t.Fatal("the first subscribe went without a turn")
	}
	tn.kick = kickChan()
	if !quick(&tn) {
		t.Fatal("a redial with no wake waited a turn")
	}
	kickRelays()
	if quick(&tn) {
		t.Fatal("a wake went without a turn")
	}
	kickRelays()
	tn.skip()
	if !quick(&tn) {
		t.Fatal("a kick answered on the live socket gave a second turn")
	}
}

// turns cover the whole minute, and inside a check-in end in time for the
// dials and catch-ups behind them
func TestTurnsFitACheckIn(t *testing.T) {
	old := subSpread
	subSpread = time.Minute
	defer func() { subSpread = old }()
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
	}()
	spread := func() (lo, hi time.Duration) {
		lo = time.Hour
		for i := 0; i < 2000; i++ {
			d := turnDelay(now)
			lo, hi = min(lo, d), max(hi, d)
		}
		return
	}
	checkInMu.Lock()
	checkInUntil = time.Time{}
	checkInMu.Unlock()
	if lo, hi := spread(); lo > 3*time.Second || hi < 57*time.Second || hi >= time.Minute {
		t.Fatalf("turns out of a check-in from %s to %s", lo, hi)
	}
	for _, ago := range []time.Duration{0, 30 * time.Second, 70 * time.Second, 2 * time.Minute} {
		checkInMu.Lock()
		checkInUntil = now.Add(-ago).Add(checkInMax)
		checkInMu.Unlock()
		left := max(0, min(time.Minute, checkInTurnsBy-ago))
		_, hi := spread()
		if hi > left {
			t.Fatalf("%s into a check-in a turn of %s, past the %s left", ago, hi, left)
		}
	}
	// the dial and the catch-up after the last turn, inside the app's 160 s
	// from the check-in's start
	if checkInTurnsBy+onionDialWait+catchupCap > 160*time.Second {
		t.Fatal("the last catch-up of a check-in could end past 160 s")
	}
}
