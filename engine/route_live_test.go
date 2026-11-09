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

// the route last answered at at. routeMu
func answeredAt(at time.Time) {
	routeMu.Lock()
	lastAnswerAt = at
	routeMu.Unlock()
}

// bridges on or off, put back after
func keepBridges(t *testing.T, on bool) {
	t.Helper()
	bridgeMu.Lock()
	oldOn, oldList := bridgeOn, bridgeList
	bridgeOn = on
	if on {
		bridgeList = []string{"obfs4 192.0.2.1:443 cert=x iat-mode=0"}
	}
	bridgeMu.Unlock()
	t.Cleanup(func() {
		bridgeMu.Lock()
		bridgeOn, bridgeList = oldOn, oldList
		bridgeMu.Unlock()
	})
}

// the bounces of a dead spell, an hour long, on a wifi android validates
// and where the route carried just before: rescueGapLive apart while the
// last answer is under liveProvenFor old, growing again after
func bouncesInAnHour(t *testing.T) []time.Time {
	t.Helper()
	t0 := time.Now()
	answeredAt(t0)
	failAll(t0, "wss://a", "wss://b")
	var at []time.Time
	for now := t0; now.Before(t0.Add(time.Hour)); now = now.Add(10 * time.Second) {
		why := routeNeedsRescue(now)
		if why != "" && !strings.HasPrefix(why, circuitsWhy) {
			at = append(at, now)
		}
	}
	return at
}

func TestAValidatedNetworkKeepsBouncesClose(t *testing.T) {
	keepNetDetail(t)
	keepBridges(t, false)
	setNetDetailForTest(netInfo{On: true, Validated: true, Kind: "wifi", Net: 7, known: true})
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	at := bouncesInAnHour(t)
	t0 := at[0]
	grew := false
	for i := 1; i < len(at); i++ {
		gap := at[i].Sub(at[i-1])
		if gap < time.Minute {
			t.Fatalf("bounce %d came %s after the one before: a loop", i, gap)
		}
		if at[i-1].Sub(t0) < liveProvenFor-5*time.Minute && gap > rescueGapLive+10*time.Second {
			t.Fatalf("bounce %d came %s after the one before, within %s of the last answer", i, gap, liveProvenFor)
		}
		if gap > rescueGapLive+10*time.Second {
			grew = true
		}
	}
	if !grew {
		t.Fatalf("the waits never grew again in an hour: %d bounces", len(at))
	}
}

// the waits grow as before: android could not check the network, it never
// said a word (a computer), bridges are in use, or the route never carried
// on this network (a censored one android validates)
func TestShortWaitsOnlyWhereTheRouteCarried(t *testing.T) {
	for _, c := range []struct {
		name    string
		net     netInfo
		bridges bool
		before  bool
	}{
		{"unchecked", netInfo{On: true, Kind: "wifi", Net: 7, known: true}, false, false},
		{"no word yet", netInfo{On: true, Validated: true, Kind: "unknown"}, false, false},
		{"bridges", netInfo{On: true, Validated: true, Kind: "wifi", Net: 7, known: true}, true, false},
		{"carried only before this network", netInfo{On: true, Validated: true, Kind: "wifi", Net: 7, known: true}, false, true},
	} {
		t.Run(c.name, func(t *testing.T) {
			keepNetDetail(t)
			keepBridges(t, c.bridges)
			setNetDetailForTest(c.net)
			resetRoute(t, "publishing", 100)
			routeNoteOK()
			if c.before {
				netMu.Lock()
				old := netChangedAt
				netChangedAt = time.Now().Add(time.Second)
				netMu.Unlock()
				t.Cleanup(func() {
					netMu.Lock()
					netChangedAt = old
					netMu.Unlock()
				})
			}
			if n := len(bouncesInAnHour(t)); n > 7 {
				t.Fatalf("%d bounces in an hour", n)
			}
		})
	}
}

// a bootstrap stuck at one percentage on a validated network where the
// route carried lately waits at most stallLimitLive before each bounce
func TestAStuckBootstrapOnAValidatedNetwork(t *testing.T) {
	keepNetDetail(t)
	keepBridges(t, false)
	setNetDetailForTest(netInfo{On: true, Validated: true, Kind: "wifi", Net: 7, known: true})
	resetRoute(t, "starting", 5)
	t0 := time.Now()
	answeredAt(t0)
	routeMu.Lock()
	rescues = 4
	routeMu.Unlock()
	routeNeedsRescue(t0)
	if why := routeNeedsRescue(t0.Add(stallLimitLive - 10*time.Second)); why != "" {
		t.Fatalf("bounced before %s: %s", stallLimitLive, why)
	}
	if why := routeNeedsRescue(t0.Add(stallLimitLive + 10*time.Second)); why == "" {
		t.Fatalf("no bounce after %s stuck on a validated network", stallLimitLive)
	}
	// with bridges the limit grows as before
	keepBridges(t, true)
	t1 := t0.Add(stallLimitLive + 20*time.Second)
	routeNeedsRescue(t1)
	if why := routeNeedsRescue(t1.Add(stallLimitLive + 10*time.Second)); why != "" {
		t.Fatalf("a bridge bootstrap bounced after %s: %s", stallLimitLive, why)
	}
}

// when a reconnect last took the slot, put in place; what was there comes back
func bounceAtForTest(at time.Time) time.Time {
	reconnectMu.Lock()
	defer reconnectMu.Unlock()
	old := lastBounceAt
	lastBounceAt = at
	return old
}

// the strip's reconnect waits out a bounce under a minute old, where the
// slot is taken, whatever the watch did to lastTorRestart meanwhile
func TestTheStripsReconnectWaitsForABounce(t *testing.T) {
	old := bounceAtForTest(time.Time{})
	t.Cleanup(func() {
		bounceAtForTest(old)
		atomic.StoreInt32(&torPaused, 0)
	})
	bounceAtForTest(time.Now().Add(-10 * time.Second))
	atomic.StoreInt64(&lastTorRestart, 0)
	if r := reconnectForWait(); r != "error: too soon" {
		t.Fatalf("10 s after a bounce: %q, want too soon", r)
	}
	if _, _, _, why := reconnectClaim(true, time.Minute); why != "error: too soon" {
		t.Fatalf("the slot taken 10 s after a bounce: %q", why)
	}
	// a minute on it goes the button's way (asleep here, so no tor is touched)
	bounceAtForTest(time.Now().Add(-61 * time.Second))
	atomic.StoreInt32(&torPaused, 1)
	if r := reconnectForWait(); r != "error: tor is asleep" {
		t.Fatalf("61 s after a bounce: %q, want the button's path", r)
	}
}

// a rescue in the outage left tor starting low: not a climb, so the route
// is in doubt and the reconnect comes. one that climbed past where it stood
// when the network lost its validation is left to climb. t lies ahead so no
// answer from whatever else runs can count as after it
func TestDoubtedAfterABounceLeftItStarting(t *testing.T) {
	resetRoute(t, "starting", 5)
	ahead := time.Now().Add(time.Hour)
	if !routeDoubtedSince(ahead, 100) {
		t.Fatal("stuck at 5% after a bounce, lost at 100%: not in doubt")
	}
	if !routeDoubtedSince(ahead, 5) {
		t.Fatal("still at the 5% it was lost at: not in doubt")
	}
	setTestStatus("starting", 40)
	if routeDoubtedSince(ahead, 5) {
		t.Fatal("climbed from 5% to 40% since the loss: in doubt")
	}
}

// in doubt since t: nothing answered after it, no bootstrap climbed since,
// and something failed after it or the route is not proven
func TestDoubtedSince(t *testing.T) {
	t0 := time.Unix(1_700_000_000, 0)
	before, after := t0.Add(-time.Second), t0.Add(time.Second)
	for _, c := range []struct {
		answered, failed  time.Time
		ok, climbed, want bool
	}{
		{before, before, true, false, false},
		{before, after, true, false, true},
		{before, before, false, false, true},
		{after, after, false, false, false},
		{time.Time{}, time.Time{}, true, false, false},
		{time.Time{}, after, true, false, true},
		{before, after, false, true, false},
	} {
		if got := doubtedSince(t0, c.answered, c.failed, c.ok, c.climbed); got != c.want {
			t.Errorf("answered %v failed %v ok %v climbed %v: %v, want %v",
				c.answered.Sub(t0), c.failed.Sub(t0), c.ok, c.climbed, got, c.want)
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
	oldBounce := bounceAtForTest(time.Time{})
	validBackDo, validBackGap = func() { n.Add(1) }, 0
	routeDoubted = func(time.Time, int) bool { return doubt.Load() }
	validBackAt.Store(0)
	t.Cleanup(func() {
		validBackDo, validBackGap, routeDoubted = oldDo, oldGap, oldDoubt
		bounceAtForTest(oldBounce)
	})
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

	// a bounce under a minute old is still bringing the route back
	validBackGap = 0
	bounceAtForTest(time.Now())
	networkDetail(`{"on":true,"validated":false,"kind":"wifi","net":8}`)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":8}`)
	time.Sleep(100 * time.Millisecond)
	if got := n.Load(); got != 1 {
		t.Fatalf("reconnected %d more times right after a bounce", got-1)
	}
}
