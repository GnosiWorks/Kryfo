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

// in doubt since t: nothing answered after it, and something failed after
// it or the route is not proven
func TestDoubtedSince(t *testing.T) {
	t0 := time.Unix(1_700_000_000, 0)
	before, after := t0.Add(-time.Second), t0.Add(time.Second)
	for _, c := range []struct {
		answered, failed time.Time
		ok, want         bool
	}{
		{before, before, true, false},
		{before, after, true, true},
		{before, before, false, true},
		{after, after, false, false},
		{time.Time{}, time.Time{}, true, false},
		{time.Time{}, after, true, true},
	} {
		if got := doubtedSince(t0, c.answered, c.failed, c.ok); got != c.want {
			t.Errorf("answered %v failed %v ok %v: %v, want %v",
				c.answered.Sub(t0), c.failed.Sub(t0), c.ok, got, c.want)
		}
	}
}

// android stops vouching for the wifi and vouches again, the same wifi: a
// route in doubt gets the reconnect, once, and only on that wifi
func TestValidatedAgainReconnectsARouteInDoubt(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	keepNetDetail(t)
	var n atomic.Int32
	var doubt atomic.Bool
	oldDo, oldGap, oldDoubt := validBackDo, validBackGap, routeDoubted
	validBackDo, validBackGap = func() { n.Add(1) }, 0
	routeDoubted = func(time.Time) bool { return doubt.Load() }
	validBackAt.Store(0)
	t.Cleanup(func() { validBackDo, validBackGap, routeDoubted = oldDo, oldGap, oldDoubt })
	// a change of network bounces through its own path, left out here
	keepBounceKnobs(t)
	underNetMu(func() {
		netQuiet, netGap = time.Millisecond, time.Millisecond
		netBounce = func() {}
	})
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":7}`)
	time.Sleep(50 * time.Millisecond)

	// nothing in doubt: left to the route watch
	networkDetail(`{"on":true,"validated":false,"kind":"wifi","net":7}`)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":7}`)
	time.Sleep(100 * time.Millisecond)
	if got := n.Load(); got != 0 {
		t.Fatalf("reconnected %d times with nothing in doubt", got)
	}

	doubt.Store(true)
	networkDetail(`{"on":true,"validated":false,"kind":"wifi","net":7}`)
	time.Sleep(50 * time.Millisecond)
	if got := n.Load(); got != 0 {
		t.Fatalf("reconnected %d times when android lost the network's validation", got)
	}
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":7}`)
	if !waitUntil(2*time.Second, func() bool { return n.Load() == 1 }) {
		t.Fatalf("validated again with the route in doubt: %d reconnects, want 1", n.Load())
	}
	// validated again and again: once
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":7}`)
	time.Sleep(100 * time.Millisecond)
	if got := n.Load(); got != 1 {
		t.Fatalf("%d reconnects for one return of the network", got)
	}

	// another network in its place is a change of network, not this
	networkDetail(`{"on":true,"validated":false,"kind":"wifi","net":7}`)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":8}`)
	time.Sleep(200 * time.Millisecond)
	if got := n.Load(); got != 1 {
		t.Fatalf("%d reconnects, a validated wifi that is another one counted", got-1)
	}

	// android says the flap again within validBackGap: one reconnect
	validBackGap = time.Hour
	validBackAt.Store(time.Now().UnixNano())
	networkDetail(`{"on":true,"validated":false,"kind":"wifi","net":8}`)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":8}`)
	time.Sleep(100 * time.Millisecond)
	if got := n.Load(); got != 1 {
		t.Fatalf("a flapping wifi reconnected %d more times inside the gap", got-1)
	}
}
