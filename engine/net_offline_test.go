// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// with no network tor stays off it. left on, it marks every guard it tries
// down, works through its whole sample and takes on new guards once the
// network is back. no tor here: a fake control port that records what tor
// was told.

func offlineRig(t *testing.T) *fakeControl {
	t.Helper()
	keepBounceKnobs(t)
	f := newFakeControl(t, 100)
	fakeTor(t, f.port())
	resetRoute(t, "publishing", 100)
	underNetMu(func() {
		netQuiet, netGap = 10*time.Millisecond, 10*time.Millisecond
		netProof, netProofTries, netProofStep = 50*time.Millisecond, 1, time.Millisecond
	})
	netMu.Lock()
	lastNetBounce = time.Time{}
	netMu.Unlock()
	torParked.Store(false)
	setOffline(false)
	// android's watch has said nothing: the plain call decides
	netInfoMu.Lock()
	saved := netInfoNow
	netInfoNow = netInfo{On: true, Validated: true, Kind: "unknown"}
	netInfoMu.Unlock()
	t.Cleanup(func() {
		// a worker still on its way out runs against the fake
		time.Sleep(300 * time.Millisecond)
		netInfoMu.Lock()
		netInfoNow = saved
		netInfoMu.Unlock()
		setOffline(false)
		torParked.Store(false)
	})
	return f
}

// the bounce's settings are changed under netMu, as the worker reads them
func underNetMu(f func()) {
	netMu.Lock()
	defer netMu.Unlock()
	f()
}

// the bounce's settings put back after the test, once a worker it left has
// finished: one asleep on a long gap would hold every later change
func keepBounceKnobs(t *testing.T) {
	t.Helper()
	netMu.Lock()
	oq, og, ob := netQuiet, netGap, netBounce
	or, op, ot, os := netReconnect, netProof, netProofTries, netProofStep
	netMu.Unlock()
	t.Cleanup(func() {
		underNetMu(func() { netQuiet, netGap = time.Millisecond, time.Millisecond })
		waitUntil(5*time.Second, func() bool {
			netMu.Lock()
			defer netMu.Unlock()
			return !netWorker
		})
		underNetMu(func() {
			netQuiet, netGap, netBounce = oq, og, ob
			netReconnect, netProof, netProofTries, netProofStep = or, op, ot, os
		})
	})
}

// the bounce stubbed and the debounce in milliseconds
func quietBounce(t *testing.T) {
	t.Helper()
	keepBounceKnobs(t)
	underNetMu(func() { netBounce, netQuiet, netGap = func() {}, time.Millisecond, time.Millisecond })
}

func countSent(cmds []string, sub string) int {
	n := 0
	for _, c := range cmds {
		if strings.Contains(c, sub) {
			n++
		}
	}
	return n
}

func waitUntil(limit time.Duration, ok func() bool) bool {
	end := time.Now().Add(limit)
	for time.Now().Before(end) {
		if ok() {
			return true
		}
		time.Sleep(5 * time.Millisecond)
	}
	return ok()
}

const (
	netOff = "DISABLENETWORK=1"
	netOn  = "DISABLENETWORK=0"
)

// airplane mode on: tor leaves the network at once, and nothing puts it back
// while there is none, not a rescue, a mode switch or a watchdog
func TestOfflineTakesTorOffTheNetwork(t *testing.T) {
	f := offlineRig(t)
	networkChangedTo(false)
	if !waitUntil(2*time.Second, func() bool { return countSent(f.sent(), netOff) > 0 && torParked.Load() }) {
		t.Fatalf("tor was not taken off the network when it went: %v", f.sent())
	}
	atomic.StoreInt64(&lastTorRestart, 0)
	if r := reconnectTor(); r != errOffline {
		t.Fatalf("a reconnect with no network said %q", r)
	}
	if r := reconnectNow(); r != errOffline {
		t.Fatalf("a reconnect by hand with no network said %q", r)
	}
	time.Sleep(100 * time.Millisecond)
	if n := countSent(f.sent(), netOn); n != 0 {
		t.Fatalf("tor went back on the network %d times with none: %v", n, f.sent())
	}

	networkChangedTo(true)
	if !waitUntil(2*time.Second, func() bool { return countSent(f.sent(), netOn) > 0 }) {
		t.Fatalf("tor not back on the network once it came: %v", f.sent())
	}
	if !waitUntil(time.Second, func() bool { return !torParked.Load() }) {
		t.Fatal("still marked off the network after it came back")
	}
}

// a flight's worth of offline reports takes tor off once, not once each
func TestOfflineReportedTwiceParksOnce(t *testing.T) {
	f := offlineRig(t)
	networkChangedTo(false)
	waitUntil(2*time.Second, func() bool { return torParked.Load() })
	before := reconnectRuns.Load()
	networkChangedTo(false)
	networkChangedTo(false)
	time.Sleep(100 * time.Millisecond)
	if n := reconnectRuns.Load() - before; n != 0 {
		t.Fatalf("%d more reconnects for an outage already handled: %v", n, f.sent())
	}
}

// relays all failing for minutes in airplane mode: no rescue while offline,
// and the back-off is untouched for the landing
func TestNoRescueWhileOffline(t *testing.T) {
	resetRoute(t, "publishing", 100)
	defer netOffline.Store(false)
	routeNoteOK()
	t0 := time.Now()
	failAll(t0, "wss://a", "wss://b", "wss://c")
	netOffline.Store(true)
	for _, d := range []time.Duration{time.Minute, 3 * time.Minute, 10 * time.Minute} {
		if why := routeNeedsRescue(t0.Add(d)); why != "" {
			t.Fatalf("rescued %s into an outage: %s", d, why)
		}
	}
	// a bootstrap that cannot climb with no network, and a tor left off
	setTestStatus("starting", 10)
	routeNeedsRescue(t0)
	if why := routeNeedsRescue(t0.Add(time.Hour)); why != "" {
		t.Fatalf("a stalled bootstrap was rescued offline: %s", why)
	}
	routeMu.Lock()
	n := rescues
	routeMu.Unlock()
	if n != 0 {
		t.Fatalf("%d rescues counted offline", n)
	}

	netOffline.Store(false)
	setTestStatus("publishing", 100)
	failAll(t0, "wss://a", "wss://b")
	if why := routeNeedsRescue(t0.Add(2 * time.Minute)); why == "" {
		t.Fatal("no rescue for a dead route once online")
	}
}

// a check-in wake with no network: awake, but tor stays off the network
func TestWakeWithNoNetworkStaysOff(t *testing.T) {
	f := offlineRig(t)
	if r := torStop(); r != "ok" {
		t.Fatalf("stop: %s", r)
	}
	netOffline.Store(true)
	if r := torResume(); r != "ok" {
		t.Fatalf("wake: %s", r)
	}
	if torIsPaused() {
		t.Fatal("still asleep after the wake")
	}
	if n := countSent(f.sent(), netOn); n != 0 {
		t.Fatalf("woken onto no network: %v", f.sent())
	}
	if !torParked.Load() {
		t.Fatal("not marked off the network")
	}
	networkChangedTo(true)
	if !waitUntil(2*time.Second, func() bool { return countSent(f.sent(), netOn) > 0 }) {
		t.Fatalf("tor not back on the network once it came: %v", f.sent())
	}
}

// relay runners sleep through an outage and wake when the network is back,
// even when the change lands between their look at it and their sleep
func TestNetworkBackWakesSleepingRunners(t *testing.T) {
	quietBounce(t)
	keepNetDetail(t)
	op := netPark
	netPark = func() {}
	t.Cleanup(func() { netPark = op })

	networkChangedTo(false)
	kc := kickChan()
	woke := make(chan bool, 1)
	go func() { woke <- sleepOrKickOn(kc, 5*time.Second) }()
	networkChangedTo(true)
	select {
	case k := <-woke:
		if !k {
			t.Fatal("the runner slept its full time")
		}
	case <-time.After(time.Second):
		t.Fatal("a runner asleep through the outage was not woken by the network")
	}
	// the detail call can be the first to say the network is back
	networkDetail(`{"on":false,"kind":"wifi"}`)
	kc = kickChan()
	go func() { woke <- sleepOrKickOn(kc, 5*time.Second) }()
	networkDetail(`{"on":true,"validated":true,"kind":"wifi"}`)
	select {
	case <-woke:
	case <-time.After(time.Second):
		t.Fatal("the network detail saying online did not wake the runners")
	}
	// the network was there all along: no kick for a change between two
	var kicked atomic.Bool
	kc = kickChan()
	go func() { kicked.Store(sleepOrKickOn(kc, 200*time.Millisecond)) }()
	networkChangedTo(true)
	time.Sleep(300 * time.Millisecond)
	if kicked.Load() {
		t.Fatal("every runner was kicked for a change between two networks")
	}
}
