// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"testing"
	"time"
)

// a change asked for while tor was not on the network yet is done by tor
// going on it. a real change after that still bounces. no tor here: tor
// going on the network is the call the control port makes once it did

func keepNetOn(t *testing.T) {
	t.Helper()
	reset := func() {
		netMu.Lock()
		netOnAt, netOnNet = time.Time{}, netInfo{}
		netMu.Unlock()
		// tor not on the network yet, as it starts
		netWentOff()
	}
	reset()
	t.Cleanup(reset)
}

// a cold start on one wifi: a change heard before tor ran, bounced on
// nothing, then the same network said again while tor came up inside the
// gap. tor up on that network is the end of it
func TestAStartOnOneNetworkIsNotBouncedAfterTorIsUp(t *testing.T) {
	r := rigFlips(t, 30*time.Millisecond, 300*time.Millisecond, 100*time.Millisecond)
	r.prove.Store(true)
	keepNetDetail(t)
	keepNetOn(t)
	wifi := `{"on":true,"validated":true,"kind":"wifi","net":100}`

	networkDetail(wifi)
	networkChangedTo(true)
	if got := waitCalls(r, 1, time.Second); got != 1 {
		t.Fatalf("%d reconnects for the change before tor ran, want 1", got)
	}
	// the same network again, inside the gap, then tor goes on it
	networkDetail(wifi)
	networkChangedTo(true)
	time.Sleep(50 * time.Millisecond)
	netWentOn()
	routeNoteOK()
	networkDetail(wifi)
	time.Sleep(600 * time.Millisecond)
	if got := r.n(); got != 1 {
		t.Fatalf("%d reconnects, want none once tor went on the network", got-1)
	}

	// wifi to mobile data with tor up: bounced
	networkDetail(`{"on":true,"validated":true,"kind":"cellular","net":200}`)
	networkChangedTo(true)
	if got := waitCalls(r, 2, 2*time.Second); got != 2 {
		t.Fatalf("wifi to mobile data with tor up: %d reconnects, want 2", got)
	}
}

// tor came up after the change, but the network it came up on went before
// the bounce was due: still bounced
func TestTorUpOnAnotherNetworkIsStillBounced(t *testing.T) {
	r := rigFlips(t, 80*time.Millisecond, 50*time.Millisecond, 100*time.Millisecond)
	r.prove.Store(true)
	keepNetDetail(t)
	keepNetOn(t)

	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":100}`)
	networkChangedTo(true)
	netWentOn()
	// a new wifi, which the watch alone saw
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":101}`)
	if got := waitCalls(r, 1, time.Second); got != 1 {
		t.Fatalf("%d reconnects, want 1 for tor on a network that went", got)
	}
}

// back from no network: tor parked meanwhile, so the bounce puts it back
func TestOfflineToOnlineStillBounces(t *testing.T) {
	r := rigFlips(t, 30*time.Millisecond, 50*time.Millisecond, 100*time.Millisecond)
	r.prove.Store(true)
	keepNetDetail(t)
	keepNetOn(t)
	quiet := netPark
	netPark = func() {}
	t.Cleanup(func() { netPark = quiet; torParked.Store(false) })

	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":100}`)
	netWentOn()
	networkDetail(`{"on":false,"kind":"other"}`)
	torParked.Store(true)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":102}`)
	if got := waitCalls(r, 1, time.Second); got != 1 {
		t.Fatalf("%d reconnects for a network back, want 1", got)
	}
}

func TestSameNetworkByTheWatch(t *testing.T) {
	wifi := netInfo{On: true, Kind: "wifi", Net: 1, known: true}
	for _, c := range []struct {
		a, b netInfo
		want bool
	}{
		{wifi, wifi, true},
		{wifi, netInfo{On: true, Kind: "wifi", Net: 2, known: true}, false},
		{wifi, netInfo{On: true, Kind: "cellular", Net: 1, known: true}, false},
		{wifi, netInfo{Kind: "other", known: true}, false},
		{wifi, netInfo{On: true, Kind: "wifi", known: true}, true},
		{netInfo{On: true, Kind: "unknown"}, wifi, true},
	} {
		if got := sameNetwork(c.a, c.b); got != c.want {
			t.Errorf("sameNetwork(%+v, %+v) = %v, want %v", c.a, c.b, got, c.want)
		}
	}
}

// a 0 to a tor that was on already, a wake that was not one, is not tor
// going on the network: the change before it is still bounced
func TestANoopNetworkOnKeepsTheBounce(t *testing.T) {
	r := rigFlips(t, 80*time.Millisecond, 50*time.Millisecond, 100*time.Millisecond)
	r.prove.Store(true)
	keepNetDetail(t)
	keepNetOn(t)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":100}`)
	netWentOn()
	time.Sleep(20 * time.Millisecond)
	networkDetail(`{"on":true,"validated":true,"kind":"cellular","net":200}`)
	networkChangedTo(true)
	time.Sleep(20 * time.Millisecond)
	netWentOn()
	// a relay through the old connections: the check alone would be content
	routeNoteOK()
	if got := waitCalls(r, 1, time.Second); got != 1 {
		t.Fatalf("%d reconnects after a real change, want 1", got)
	}
}

// a bounce left out still has tor prove itself on the network
func TestADroppedBounceStillChecks(t *testing.T) {
	r := rigFlips(t, 30*time.Millisecond, 50*time.Millisecond, 200*time.Millisecond)
	keepNetDetail(t)
	keepNetOn(t)
	netCheckOutcome.Store("")
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":100}`)
	networkChangedTo(true)
	time.Sleep(10 * time.Millisecond)
	netWentOn()
	waitUntil(time.Second, func() bool {
		netMu.Lock()
		defer netMu.Unlock()
		return !netWorker
	})
	time.Sleep(20 * time.Millisecond)
	routeBump()
	routeNoteOK()
	waitUntil(time.Second, func() bool { return lastNetCheck() != "" })
	if got := lastNetCheck(); len(got) < 2 || got[:2] != "ok" {
		t.Fatalf("check after a dropped bounce: %q", got)
	}
	if got := r.n(); got != 0 {
		t.Fatalf("%d reconnects, want none", got)
	}
}

// the watch names another network and the app says nothing: the engine
// takes it as a change by itself
func TestANewHandleAloneBounces(t *testing.T) {
	r := rigFlips(t, 40*time.Millisecond, 50*time.Millisecond, 100*time.Millisecond)
	r.prove.Store(true)
	keepNetDetail(t)
	keepNetOn(t)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":100}`)
	netWentOn()
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":100}`)
	time.Sleep(200 * time.Millisecond)
	if got := r.n(); got != 0 {
		t.Fatalf("the same handle again: %d reconnects", got)
	}
	networkDetail(`{"on":true,"validated":true,"kind":"wifi","net":101}`)
	if got := waitCalls(r, 1, time.Second); got != 1 {
		t.Fatalf("a new handle alone: %d reconnects, want 1", got)
	}
}
