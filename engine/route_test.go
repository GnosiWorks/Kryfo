// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"sync/atomic"
	"testing"
	"time"
)

// route_test: the verdict on whether tor carries anything, and when a dead
// route is rebuilt. no tor here - the decision is a function of what the
// relay runners report, a status, and a clock.

func resetRoute(t *testing.T, status string, pct int) {
	t.Helper()
	routeMu.Lock()
	failedSinceOK = map[string]bool{}
	firstFailAt = time.Time{}
	routeGen, okGen = 0, -1
	rescues, lastRescue = 0, time.Time{}
	stallPct, stallSince = -1, time.Time{}
	routeMu.Unlock()
	setTestStatus(status, pct)
	atomic.StoreInt32(&torPaused, 0)
	atomic.StoreInt32(&reconnectRunning, 0)
	atomic.StoreInt32(&torRestarting, 0)
}

func setTestStatus(status string, pct int) {
	statusMu.Lock()
	torStatus, bootstrapPct = status, pct
	statusMu.Unlock()
}

// fail every relay once, at a given time
func failAll(at time.Time, relays ...string) {
	routeMu.Lock()
	for _, u := range relays {
		if len(failedSinceOK) == 0 {
			firstFailAt = at
		}
		failedSinceOK[u] = true
	}
	routeMu.Unlock()
}

// the flight-mode case: tor says publishing, every relay fails. nothing for
// the first minute, a rebuild at the minute, and then not again until the gap
// has passed - and that gap doubles while nothing comes back.
func TestDeadRouteIsRebuiltAfterAMinute(t *testing.T) {
	resetRoute(t, "publishing", 100)
	routeNoteOK() // it worked once, as it had before the network went
	t0 := time.Unix(1_700_000_000, 0)
	failAll(t0, "wss://a", "wss://b", "wss://c")

	if why := routeNeedsRescue(t0.Add(59 * time.Second)); why != "" {
		t.Fatalf("rescued at 59s: %s", why)
	}
	if why := routeNeedsRescue(t0.Add(61 * time.Second)); why == "" {
		t.Fatal("no rescue at 61s with every relay failing")
	}
	if why := routeNeedsRescue(t0.Add(90 * time.Second)); why != "" {
		t.Fatalf("rescued again 29s after the last: %s", why)
	}
	// the first gap after one rescue is two minutes
	if why := routeNeedsRescue(t0.Add(61*time.Second + 2*time.Minute)); why == "" {
		t.Fatal("no second rescue after the two minute gap")
	}
	// and the one after that is four
	if why := routeNeedsRescue(t0.Add(61*time.Second + 2*time.Minute + 3*time.Minute)); why != "" {
		t.Fatalf("third rescue came before the four minute gap: %s", why)
	}
	if why := routeNeedsRescue(t0.Add(61*time.Second + 2*time.Minute + 4*time.Minute)); why == "" {
		t.Fatal("no third rescue after the four minute gap")
	}
}

// one relay down for its own reasons must never make the route look dead or
// cause a rebuild, however long it stays down.
func TestOneDeadRelayIsNotADeadRoute(t *testing.T) {
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	t0 := time.Unix(1_700_000_000, 0)
	failAll(t0, "wss://nostr.oxtr.dev")
	for m := 1; m <= 60; m++ {
		if why := routeNeedsRescue(t0.Add(time.Duration(m) * time.Minute)); why != "" {
			t.Fatalf("rescued at %dm for one relay: %s", m, why)
		}
	}
	if !routeOK() {
		t.Fatal("route called dead for one relay")
	}
}

// a relay answering clears the whole run of failures and the backoff with it.
func TestARelayAnsweringEndsIt(t *testing.T) {
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	t0 := time.Unix(1_700_000_000, 0)
	failAll(t0, "wss://a", "wss://b")
	if routeNeedsRescue(t0.Add(61*time.Second)) == "" {
		t.Fatal("expected a rescue")
	}
	routeNoteOK()
	routeMu.Lock()
	n := rescues
	routeMu.Unlock()
	if n != 0 {
		t.Fatalf("rescues not reset by a relay answering: %d", n)
	}
	if why := routeNeedsRescue(t0.Add(10 * time.Minute)); why != "" {
		t.Fatalf("rescued with a healthy route: %s", why)
	}
}

// a bootstrap that keeps climbing is never bounced, however slow. this is the
// bridges-on-a-censored-network case: one step every two and a half minutes
// for half an hour is slow, not stuck.
func TestSlowButMovingBootstrapIsLeftAlone(t *testing.T) {
	resetRoute(t, "starting", 0)
	t0 := time.Unix(1_700_000_000, 0)
	pct := 0
	for s := 0; s <= 30*60; s += 10 {
		if s > 0 && s%150 == 0 {
			pct += 5
			setTestStatus("starting", pct)
		}
		if why := routeNeedsRescue(t0.Add(time.Duration(s) * time.Second)); why != "" {
			t.Fatalf("bounced a moving bootstrap at %ds, %d%%: %s", s, pct, why)
		}
	}
}

// a bootstrap stuck at one percentage is bounced - and the second time it
// sticks, it is given longer before the next bounce.
func TestStuckBootstrapIsBouncedWithBackoff(t *testing.T) {
	resetRoute(t, "starting", 0)
	t0 := time.Unix(1_700_000_000, 0)
	routeNeedsRescue(t0) // starts the stall clock at 0%
	if why := routeNeedsRescue(t0.Add(2*time.Minute + 50*time.Second)); why != "" {
		t.Fatalf("bounced before three minutes: %s", why)
	}
	if why := routeNeedsRescue(t0.Add(3*time.Minute + 10*time.Second)); why == "" {
		t.Fatal("no bounce after three minutes at 0%")
	}
	// still stuck after the bounce: the clock restarts, and the limit is now six
	t1 := t0.Add(3*time.Minute + 20*time.Second)
	routeNeedsRescue(t1)
	if why := routeNeedsRescue(t1.Add(5 * time.Minute)); why != "" {
		t.Fatalf("second bounce came before six minutes: %s", why)
	}
	if why := routeNeedsRescue(t1.Add(6*time.Minute + 10*time.Second)); why == "" {
		t.Fatal("no second bounce after six minutes stuck")
	}
}

// asleep on purpose (check-ins) or mid-reconnect: never.
func TestNoRescueWhilePausedOrReconnecting(t *testing.T) {
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	t0 := time.Unix(1_700_000_000, 0)
	failAll(t0, "wss://a", "wss://b")
	atomic.StoreInt32(&torPaused, 1)
	if why := routeNeedsRescue(t0.Add(10 * time.Minute)); why != "" {
		t.Fatalf("rescued a tor that is asleep on purpose: %s", why)
	}
	atomic.StoreInt32(&torPaused, 0)
	atomic.StoreInt32(&reconnectRunning, 1)
	if why := routeNeedsRescue(t0.Add(10 * time.Minute)); why != "" {
		t.Fatalf("rescued during a reconnect: %s", why)
	}
	atomic.StoreInt32(&reconnectRunning, 0)
}

// the verdict the ui reads. not ok until a relay has connected, not ok again
// after a bounce until one connects through the new route, and not ok when
// every relay is failing - whatever tor says.
func TestRouteOKFollowsRelaysNotTor(t *testing.T) {
	resetRoute(t, "publishing", 100)
	if routeOK() {
		t.Fatal("ok before any relay connected")
	}
	routeNoteOK()
	if !routeOK() {
		t.Fatal("not ok after a relay connected")
	}
	g := routeBump()
	if routeOK() {
		t.Fatal("ok straight after a bounce - that is the tor that went")
	}
	if routeGeneration() != g {
		t.Fatal("generation not reported")
	}
	routeNoteOK()
	if !routeOK() {
		t.Fatal("not ok after a relay connected through the new route")
	}
	failAll(time.Now().Add(-30*time.Second), "wss://a", "wss://b")
	if routeOK() {
		t.Fatal("ok while every relay has been failing for 30s")
	}
	setTestStatus("starting", 40)
	routeNoteOK()
	if routeOK() {
		t.Fatal("ok while tor itself is not ready")
	}
}

// a network that flaps five times in a minute gets one bounce once it has
// settled - not five - and the last change always gets one.
func TestFlappingNetworkIsBouncedOnceSettled(t *testing.T) {
	oldQ, oldG, oldB := netQuiet, netGap, netBounce
	defer func() { netQuiet, netGap, netBounce = oldQ, oldG, oldB }()
	netQuiet, netGap = 50*time.Millisecond, 800*time.Millisecond
	var n int32
	netBounce = func() { atomic.AddInt32(&n, 1) }
	atomic.StoreInt32(&torPaused, 0)
	netMu.Lock()
	lastNetBounce = time.Time{}
	netMu.Unlock()

	// five flaps, each well inside the quiet window of the one before
	for i := 0; i < 5; i++ {
		networkChanged()
		time.Sleep(20 * time.Millisecond)
	}
	time.Sleep(150 * time.Millisecond)
	if got := atomic.LoadInt32(&n); got != 1 {
		t.Fatalf("flapping network bounced %d times, want 1", got)
	}

	// a change right after a bounce waits out the gap, and still gets one
	networkChanged()
	time.Sleep(200 * time.Millisecond)
	if got := atomic.LoadInt32(&n); got != 1 {
		t.Fatalf("bounced inside the gap: %d", got)
	}
	time.Sleep(900 * time.Millisecond)
	if got := atomic.LoadInt32(&n); got != 2 {
		t.Fatalf("the change after the gap was dropped: %d bounces", got)
	}
}
