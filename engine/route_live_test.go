// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// a wifi that passes no tcp for a while and says nothing (redmi and
// samsung, 2026-11-08). android goes on calling it validated, so the dead
// route is tor's own state and the waits between bounces stop growing.

// what android says, put in place without the actions a change takes
func setNetDetailForTest(n netInfo) {
	netInfoMu.Lock()
	netInfoNow = n
	netInfoMu.Unlock()
}

// the bounces of a dead spell on a validated wifi come no more than
// rescueGapLive apart, however long it lasts
func TestAValidatedNetworkKeepsBouncesClose(t *testing.T) {
	keepNetDetail(t)
	setNetDetailForTest(netInfo{On: true, Validated: true, Kind: "wifi", Net: 7, known: true})
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	t0 := time.Unix(1_700_000_000, 0)
	failAll(t0, "wss://a", "wss://b")
	var at []time.Time
	for now := t0; now.Before(t0.Add(time.Hour)); now = now.Add(10 * time.Second) {
		why := routeNeedsRescue(now)
		if why != "" && !strings.HasPrefix(why, circuitsWhy) {
			at = append(at, now)
		}
	}
	if len(at) < 15 {
		t.Fatalf("%d bounces in an hour on a validated wifi, want one every few minutes", len(at))
	}
	for i := 1; i < len(at); i++ {
		if gap := at[i].Sub(at[i-1]); gap > rescueGapLive+10*time.Second {
			t.Fatalf("bounce %d came %s after the one before, more than %s", i, gap, rescueGapLive)
		}
		if gap := at[i].Sub(at[i-1]); gap < time.Minute {
			t.Fatalf("bounce %d came %s after the one before: a loop", i, gap)
		}
	}
}

// not validated: the waits grow to the quarter hour as before
func TestAnUncheckedNetworkStillBacksOff(t *testing.T) {
	keepNetDetail(t)
	setNetDetailForTest(netInfo{On: true, Kind: "wifi", Net: 7, known: true})
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	t0 := time.Unix(1_700_000_000, 0)
	failAll(t0, "wss://a", "wss://b")
	n := 0
	for now := t0; now.Before(t0.Add(time.Hour)); now = now.Add(10 * time.Second) {
		why := routeNeedsRescue(now)
		if why != "" && !strings.HasPrefix(why, circuitsWhy) {
			n++
		}
	}
	if n > 7 {
		t.Fatalf("%d bounces in an hour on a network android could not check", n)
	}
}

// a bootstrap stuck at one percentage on a validated network waits at most
// stallLimitLive before each bounce
func TestAStuckBootstrapOnAValidatedNetwork(t *testing.T) {
	keepNetDetail(t)
	setNetDetailForTest(netInfo{On: true, Validated: true, Kind: "wifi", Net: 7, known: true})
	resetRoute(t, "starting", 5)
	routeMu.Lock()
	rescues = 4
	routeMu.Unlock()
	t0 := time.Unix(1_700_000_000, 0)
	routeNeedsRescue(t0)
	if why := routeNeedsRescue(t0.Add(stallLimitLive - 10*time.Second)); why != "" {
		t.Fatalf("bounced before %s: %s", stallLimitLive, why)
	}
	if why := routeNeedsRescue(t0.Add(stallLimitLive + 10*time.Second)); why == "" {
		t.Fatalf("no bounce after %s stuck on a validated network", stallLimitLive)
	}
}

// android stops vouching for the wifi and vouches again, the same wifi: a
// route nothing proved meanwhile is taken as on a new network, at once
func TestValidatedAgainBouncesADeadRoute(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	keepNetDetail(t)
	var n atomic.Int32
	oldDo, oldGap := validBackDo, validBackGap
	validBackDo, validBackGap = func() { n.Add(1) }, 0
	validBackAt.Store(0)
	t.Cleanup(func() { validBackDo, validBackGap = oldDo, oldGap })
	// a change of network bounces through its own path, left out here
	keepBounceKnobs(t)
	underNetMu(func() {
		netQuiet, netGap = time.Millisecond, time.Millisecond
		netBounce = func() {}
	})
	resetRoute(t, "reachable", 100)
	routeNoteOK()
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":7}`)
	time.Sleep(100 * time.Millisecond)
	n.Store(0)

	// an idle phone: nothing failed meanwhile and the route stands proven
	networkDetail(`{"on":true,"validated":false,"kind":"wifi","net":7}`)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":7}`)
	time.Sleep(100 * time.Millisecond)
	if got := n.Load(); got != 0 {
		t.Fatalf("reconnected %d times with nothing in doubt", got)
	}

	networkDetail(`{"on":true,"validated":false,"kind":"wifi","net":7}`)
	time.Sleep(100 * time.Millisecond)
	if got := n.Load(); got != 0 {
		t.Fatalf("reconnected %d times when android lost the network's validation", got)
	}
	time.Sleep(10 * time.Millisecond)
	routeNoteFail("wss://relay.kryfo.app")
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":7}`)
	if !waitUntil(2*time.Second, func() bool { return n.Load() == 1 }) {
		t.Fatalf("validated again with nothing through meanwhile: %d reconnects, want 1", n.Load())
	}
	// another network in its place is a change of network, not this
	time.Sleep(100 * time.Millisecond)
	n.Store(0)
	networkDetail(`{"on":true,"validated":false,"kind":"wifi","net":7}`)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":8}`)
	time.Sleep(200 * time.Millisecond)
	if got := n.Load(); got != 0 {
		t.Fatalf("%d reconnects for a validated wifi that is another one", got)
	}

	// a relay answered while it was unvalidated: the route carries, nothing to do
	time.Sleep(100 * time.Millisecond)
	n.Store(0)
	networkDetail(`{"on":true,"validated":false,"kind":"wifi","net":8}`)
	time.Sleep(10 * time.Millisecond)
	routeNoteOK()
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":8}`)
	time.Sleep(200 * time.Millisecond)
	if got := n.Load(); got != 0 {
		t.Fatalf("reconnected %d times a route a relay proved", got)
	}
}
