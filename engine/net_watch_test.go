// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"context"
	"encoding/hex"
	"fmt"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// android's default-network watch and the plain online call, the park and
// the way back. no tor here: a fake control port that records what tor was
// told.

// android's word not had yet, and put back as it was after
func keepNetDetail(t *testing.T) {
	t.Helper()
	netInfoMu.Lock()
	saved := netInfoNow
	netInfoNow = netInfo{On: true, Validated: true, Kind: "unknown"}
	netDisproved = nil
	netInfoMu.Unlock()
	connSaid.Store(connUnsaid)
	t.Cleanup(func() {
		netInfoMu.Lock()
		netInfoNow = saved
		netDisproved = nil
		netInfoMu.Unlock()
		connSaid.Store(connUnsaid)
		setOffline(false)
	})
}

// a none from the plain call while android's watch says a network is there
// is not taken: tor stays on the network
func TestNetWatchOutranksANone(t *testing.T) {
	f := offlineRig(t)
	keepNetDetail(t)
	quietBounce(t)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi"}`)
	networkChangedTo(false)
	time.Sleep(100 * time.Millisecond)
	if netOffline.Load() || torParked.Load() || countSent(f.sent(), netOff) != 0 {
		t.Fatalf("parked on a none the watch did not say: offline %v parked %v %v",
			netOffline.Load(), torParked.Load(), f.sent())
	}
	// and the watch saying none is taken whatever the plain call says
	networkDetail(`{"on":false,"kind":"other"}`)
	networkChangedTo(true)
	if !netOffline.Load() {
		t.Fatal("online by the plain call while the watch says none")
	}
}

// the watch alone says none, then a network: tor leaves the network and
// is bounced back on, with no word from the plain call
func TestADetailOnlyOutageBouncesBack(t *testing.T) {
	f := offlineRig(t)
	keepNetDetail(t)
	networkDetail(`{"on":true,"validated":true,"kind":"wifi"}`)
	networkDetail(`{"on":false,"kind":"other"}`)
	if !waitUntil(2*time.Second, func() bool { return torParked.Load() && countSent(f.sent(), netOff) > 0 }) {
		t.Fatalf("not parked on the watch's none: %v", f.sent())
	}
	networkDetail(`{"on":true,"validated":true,"kind":"cellular"}`)
	if !waitUntil(3*time.Second, func() bool { return countSent(f.sent(), netOn) > 0 && !torParked.Load() }) {
		t.Fatalf("not back on the network after the watch's return: %v", f.sent())
	}
}

// a park with no network said to be there for long: the valve takes the
// network as there, the bounce puts tor on, and a relay through it ends
// the outage
func TestTheValveTakesARelayAsANetwork(t *testing.T) {
	f := offlineRig(t)
	keepNetDetail(t)
	oa := netValveAfter
	netValveAfter = time.Minute
	t.Cleanup(func() { netValveAfter = oa })
	networkChangedTo(false)
	if !waitUntil(2*time.Second, func() bool { return torParked.Load() }) {
		t.Fatal("not parked")
	}
	if netValveDue(time.Now()) {
		t.Fatal("the valve opened at once")
	}
	if !netValveDue(time.Now().Add(2 * time.Minute)) {
		t.Fatal("the valve did not open")
	}
	done := make(chan struct{})
	go func() { netValveTry(); close(done) }()
	if !waitUntil(3*time.Second, func() bool { return countSent(f.sent(), netOn) > 0 }) {
		t.Fatalf("the valve did not put tor on: %v", f.sent())
	}
	// a relay through the tor that came back
	for end := time.Now().Add(5 * time.Second); time.Now().Before(end); {
		routeNoteOK()
		select {
		case <-done:
			end = time.Now()
		case <-time.After(20 * time.Millisecond):
		}
	}
	<-done
	if netOffline.Load() || torParked.Load() {
		t.Fatalf("a relay got through and still offline %v parked %v", netOffline.Load(), torParked.Load())
	}
}

// the valve proves nothing: tor is parked again, and the next try waits
// twice as long
func TestTheValveParksAgainAndBacksOff(t *testing.T) {
	f := offlineRig(t)
	keepNetDetail(t)
	oa, of := netValveAfter, netValveFor
	netValveAfter, netValveFor = time.Minute, 1500*time.Millisecond
	t.Cleanup(func() { netValveAfter, netValveFor = oa, of })
	networkChangedTo(false)
	if !waitUntil(2*time.Second, func() bool { return torParked.Load() }) {
		t.Fatal("not parked")
	}
	now := time.Now()
	if !netValveDue(now.Add(61 * time.Second)) {
		t.Fatal("the valve did not open")
	}
	netValveTry()
	if !waitUntil(3*time.Second, func() bool {
		var last string
		for _, c := range f.sent() {
			if strings.Contains(c, "DISABLENETWORK") {
				last = c
			}
		}
		return strings.Contains(last, netOff) && torParked.Load() && countSent(f.sent(), netOn) > 0
	}) {
		t.Fatalf("not tried and parked again: offline %v parked %v %v", netOffline.Load(), torParked.Load(), f.sent())
	}
	if !netOffline.Load() {
		t.Fatal("taken as online with nothing through")
	}
	if netValveDue(now.Add(61*time.Second + 90*time.Second)) {
		t.Fatal("the valve opened again before its back-off")
	}
	if !netValveDue(now.Add(61*time.Second + 121*time.Second)) {
		t.Fatal("the valve did not open after its back-off")
	}
}

// a start that saw a network, then a park before its DisableNetwork 0
// reached tor: tor is not put on the network with none
func TestAStartAfterAParkStaysOff(t *testing.T) {
	f := offlineRig(t)
	keepNetDetail(t)
	op := netPark
	netPark = func() {}
	t.Cleanup(func() { netPark = op })
	mu.Lock()
	tn := torNode
	mu.Unlock()
	ctrlMu.Lock()
	done := make(chan struct{})
	go func() { networkOnAtStart(tn); close(done) }()
	time.Sleep(50 * time.Millisecond)
	setOffline(true)
	ctrlMu.Unlock()
	<-done
	if n := countSent(f.sent(), netOn); n != 0 {
		t.Fatalf("a start put tor on the network with none: %v", f.sent())
	}
	if !torParked.Load() {
		t.Fatal("not marked off the network")
	}
}

// a start with no network parks tor at once
func TestAStartWithNoNetworkParks(t *testing.T) {
	f := offlineRig(t)
	keepNetDetail(t)
	setOffline(true)
	mu.Lock()
	tn := torNode
	mu.Unlock()
	networkOnAtStart(tn)
	if countSent(f.sent(), netOn) != 0 || !torParked.Load() {
		t.Fatalf("parked %v: %v", torParked.Load(), f.sent())
	}
}

// the network goes while tor takes a wake's DisableNetwork 0, and the
// park finds tor parked still: tor ends off the network all the same
func TestAWakeRacingAParkEndsOff(t *testing.T) {
	f := offlineRig(t)
	keepNetDetail(t)
	if r := torStop(); r != "ok" {
		t.Fatalf("stop: %s", r)
	}
	torParked.Store(true)
	f.slowNet.Store(int64(300 * time.Millisecond))
	t.Cleanup(func() { f.slowNet.Store(0) })
	done := make(chan string, 1)
	go func() { done <- torResume() }()
	if !waitUntil(time.Second, func() bool { return countSent(f.sent(), netOn) > 0 }) {
		t.Fatalf("no wake sent: %v", f.sent())
	}
	setOffline(true)
	go netPark()
	if r := <-done; r != "ok" {
		t.Fatalf("wake: %s", r)
	}
	f.slowNet.Store(0)
	if !waitUntil(3*time.Second, func() bool {
		var last string
		for _, c := range f.sent() {
			if strings.Contains(c, "DISABLENETWORK") {
				last = c
			}
		}
		return strings.Contains(last, netOff) && torParked.Load()
	}) {
		t.Fatalf("left on the network with none: %v", f.sent())
	}
}

// no network: a park when the network is back already does nothing
func TestAParkAfterTheNetworkCameDoesNothing(t *testing.T) {
	f := offlineRig(t)
	netPark()
	time.Sleep(100 * time.Millisecond)
	if n := countSent(f.sent(), netOff); n != 0 {
		t.Fatalf("parked with a network there: %v", f.sent())
	}
}

// in tor mode the network back wakes the runners only once tor is on it
// again: the bounce kicks them
func TestNetworkBackLeavesTheKickToTheBounce(t *testing.T) {
	offlineRig(t)
	keepNetDetail(t)
	quietBounce(t)
	op := netPark
	netPark = func() {}
	t.Cleanup(func() { netPark = op })
	networkChangedTo(false)
	torParked.Store(true)
	var kicked atomic.Bool
	kc := kickChan()
	go func() { kicked.Store(sleepOrKickOn(kc, 200*time.Millisecond)) }()
	networkChangedTo(true)
	time.Sleep(300 * time.Millisecond)
	if kicked.Load() {
		t.Fatal("runners kicked to dial through a tor still off the network")
	}
}

// automatic's direct step on the old network: tor leaves the network at
// once on a change, not after the quiet window
func TestADirectStepLeavesTheNetworkOnAChange(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	f := overlapRig(t)
	keepNetDetail(t)
	// the bounce does nothing here: what leaves the network is the change
	quietBounce(t)
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	autoDirectOK.Store(true)
	setNetInfo(wifi())
	networkChangedTo(true)
	if !waitUntil(time.Second, func() bool { return countSent(f.sent(), netOff) > 0 }) {
		t.Fatalf("direct stayed on the network after the change: %v", f.sent())
	}
	if why := networkHold(); why != errAutoWait {
		t.Fatalf("hold %q", why)
	}
}

// a network change inside a check-in, with tor's control port slow: the
// call returns at once and the step is put behind it
func TestNetworkStateReturnsWhileTheControlPortWaits(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	f := overlapRig(t)
	f.slow.Store(int64(3 * time.Second))
	keepNetDetail(t)
	quietBounce(t)
	atomicPaused(t)
	setNetInfo(wifi())
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no", SkipDirect: true}
	autoMu.Unlock()
	checkInMu.Lock()
	checkInUntil = autoNow().Add(time.Minute)
	checkInMu.Unlock()
	t.Cleanup(func() {
		checkInMu.Lock()
		checkInUntil = time.Time{}
		checkInMu.Unlock()
		waitUntil(10*time.Second, func() bool {
			ciStepMu.Lock()
			defer ciStepMu.Unlock()
			return !ciStepBusy
		})
	})
	t0 := time.Now()
	networkChangedTo(true)
	networkChangedTo(true)
	if d := time.Since(t0); d > 500*time.Millisecond {
		t.Fatalf("the network change took %s", d)
	}
	if !waitUntil(10*time.Second, func() bool {
		l := bridgeLines()
		return bridgesEnabled() && len(l) > 0 && strings.HasPrefix(l[0], "obfs4 ")
	}) {
		t.Fatal("the check-in step was not put")
	}
}

// a check-in, and the plain call says online before android's watch names
// the network: no step for a network nobody has named
func TestACheckInWaitsForTheNetworksKind(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	keepNetDetail(t)
	quietBounce(t)
	op := netPark
	netPark = func() {}
	t.Cleanup(func() { netPark = op })
	today := dayOf(autoNow())
	memMu.Lock()
	autoMem.Last = map[string]autoUse{"wifi": {Method: "direct", Day: today}}
	autoMem.Blocked = map[string]int64{"other": today}
	memMu.Unlock()
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	networkDetail(`{"on":false,"kind":"other"}`)
	checkIn(true)
	t.Cleanup(func() { checkIn(false) })
	networkChangedTo(true)
	time.Sleep(100 * time.Millisecond)
	if bridgesEnabled() || autoDirectOK.Load() {
		t.Fatalf("a step for an unnamed network: bridges %v direct %v", bridgesEnabled(), autoDirectOK.Load())
	}
	networkDetail(`{"on":true,"validated":true,"kind":"wifi"}`)
	if !waitUntil(2*time.Second, func() bool { return autoDirectOK.Load() && !bridgesEnabled() }) {
		t.Fatalf("the wifi step was not put: bridges %v direct %v", bridgesEnabled(), autoDirectOK.Load())
	}
}

// a runner that finds tor off the network hears a kick that comes between
// its look and its sleep
func TestAParkedRunnerHearsAKickBeforeItSleeps(t *testing.T) {
	si := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, nil, si)
	keepNetDetail(t)
	setOffline(true)
	var looks atomic.Int32
	runnerParkHook = func() {
		if looks.Add(1) == 1 {
			kickRelays()
		}
	}
	t.Cleanup(func() { runnerParkHook = nil })
	peer := newXid(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, mustRcv(t, peer))
	if !waitUntil(3*time.Second, func() bool { return looks.Load() >= 2 }) {
		t.Fatalf("the runner slept through a kick, %d looks", looks.Load())
	}
}

// a parked runner ends with its subscription, not fifteen minutes on
func TestAParkedRunnerEndsWithItsContext(t *testing.T) {
	si := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, nil, si)
	keepNetDetail(t)
	setOffline(true)
	var looks atomic.Int32
	runnerParkHook = func() { looks.Add(1) }
	t.Cleanup(func() { runnerParkHook = nil })
	before := fcRelaysLive.Load()
	ctx, cancel := context.WithCancel(context.Background())
	go nostrSubscribeRunnerMode(ctx, "firstcontact", [32]byte{}, strings.Repeat("ab", 32), true, 3)
	if !waitUntil(3*time.Second, func() bool { return looks.Load() > 0 }) {
		t.Fatal("the runner never parked")
	}
	cancel()
	if !waitUntil(2*time.Second, func() bool { return fcRelaysLive.Load() == before }) {
		t.Fatal("a parked runner outlived its subscription")
	}
}

// a mode with no way out lands after a reconnect looked at the hold and
// before its DisableNetwork 0: tor stays off the network
func TestAModeChangeBeforeTheNetworkOnHolds(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	f := overlapRig(t)
	f.slow.Store(0)
	release := make(chan struct{})
	locked := make(chan struct{})
	var once sync.Once
	reconnectStepHook = func(_ int64, name string) {
		if name != "network on" {
			return
		}
		once.Do(func() {
			go func() {
				ctrlMu.Lock()
				close(locked)
				<-release
				ctrlMu.Unlock()
			}()
			<-locked
		})
	}
	t.Cleanup(func() { reconnectStepHook = nil })
	before := len(f.sent())
	done := make(chan string, 1)
	go func() { done <- reconnectNow() }()
	<-locked
	time.Sleep(100 * time.Millisecond)
	autoMu.Lock()
	bmMode = bmAuto
	autoMu.Unlock()
	autoDirectOK.Store(false)
	close(release)
	if r := <-done; r != errAutoWait {
		t.Fatalf("reconnect: %q", r)
	}
	if netOnIn(sentAfter(f, before)) {
		t.Fatalf("tor went on the network after the mode changed: %v", f.sent())
	}
}

// while the valve is open automatic may try too: the network is taken as
// there
func TestTheValveLetsAutomaticTry(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	keepNetDetail(t)
	networkDetail(`{"on":false,"kind":"other"}`)
	if why := autoIdleWhy(); why != "no_internet" {
		t.Fatalf("offline: %q", why)
	}
	netValveOpen.Store(true)
	t.Cleanup(func() { netValveOpen.Store(false) })
	if why := autoIdleWhy(); why != "" {
		t.Fatalf("valve open: %q", why)
	}
}

// parked for want of a network, the status says so, and a decoy says
// offline
func TestAParkedTorSaysNoInternet(t *testing.T) {
	offlineRig(t)
	keepNetDetail(t)
	t.Cleanup(func() { decoyState.Store(decoyOff) })
	networkChangedTo(false)
	if !waitUntil(2*time.Second, func() bool { return torParked.Load() }) {
		t.Fatal("not parked")
	}
	if v := bridgeStatus(); v.Phase != "no_internet" || v.Network != "none" {
		t.Fatalf("parked: %+v", v)
	}
	decoyState.Store(decoyOn)
	if v := bridgeStatus(); v.Phase != "offline" {
		t.Fatalf("decoy parked: %+v", v)
	}
}

// a valve try: the network taken as there until a relay comes through
func valveProves(t *testing.T, f *fakeControl) {
	t.Helper()
	done := make(chan struct{})
	go func() { netValveTry(); close(done) }()
	if !waitUntil(3*time.Second, func() bool { return countSent(f.sent(), netOn) > 0 }) {
		t.Fatalf("the valve did not put tor on: %v", f.sent())
	}
	for end := time.Now().Add(5 * time.Second); time.Now().Before(end); {
		routeNoteOK()
		select {
		case <-done:
			end = time.Now()
		case <-time.After(20 * time.Millisecond):
		}
	}
	<-done
	if netOffline.Load() {
		t.Fatal("a relay got through and still offline")
	}
}

// automatic before any step, and no network: parked like any other mode,
// so the valve can try it later
func TestAutomaticWithNoWayInParksForTheValve(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	offlineRig(t)
	keepNetDetail(t)
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	autoDirectOK.Store(false)
	oa := netValveAfter
	netValveAfter = time.Minute
	t.Cleanup(func() { netValveAfter = oa })
	networkChangedTo(false)
	if !waitUntil(3*time.Second, func() bool { return torParked.Load() }) {
		t.Fatalf("offline %v parked %v", netOffline.Load(), torParked.Load())
	}
	if !netValveDue(time.Now().Add(2 * time.Minute)) {
		t.Fatal("the valve never comes for automatic")
	}
}

// the watch and the plain call both say none: no valve. the plain call
// saying a network is there: the valve may try
func TestTheValveOnlyWhenTheCallsDisagree(t *testing.T) {
	f := offlineRig(t)
	_ = f
	keepNetDetail(t)
	quietBounce(t)
	networkDetail(`{"on":false,"kind":"other"}`)
	networkChangedTo(false)
	if !waitUntil(3*time.Second, func() bool { return torParked.Load() }) {
		t.Fatal("not parked")
	}
	if netValveDue(time.Now().Add(24 * time.Hour)) {
		t.Fatal("the valve opened with none by both")
	}
	networkChangedTo(true)
	if !netOffline.Load() {
		t.Fatal("the plain call outranked the watch")
	}
	if !netValveDue(time.Now().Add(24 * time.Hour)) {
		t.Fatal("no valve while the calls disagree")
	}
}

// a valve proof stands against the same stale none, and falls to a new word
func TestAValveProofOutlivesTheSameNone(t *testing.T) {
	f := offlineRig(t)
	keepNetDetail(t)
	oa := netValveAfter
	netValveAfter = time.Minute
	t.Cleanup(func() { netValveAfter = oa })
	networkDetail(`{"on":false,"kind":"other"}`)
	networkChangedTo(true)
	if !waitUntil(3*time.Second, func() bool { return torParked.Load() }) {
		t.Fatal("not parked")
	}
	if !netValveDue(time.Now().Add(2 * time.Minute)) {
		t.Fatal("the valve did not open")
	}
	valveProves(t, f)
	networkDetail(`{"on":false,"kind":"other"}`)
	if netOffline.Load() {
		t.Fatal("the watch's same none was taken again")
	}
	networkChangedTo(true)
	time.Sleep(100 * time.Millisecond)
	if netOffline.Load() || torParked.Load() {
		t.Fatalf("the same stale none undid the proof: offline %v parked %v", netOffline.Load(), torParked.Load())
	}
	if n := currentNet(); !n.On {
		t.Fatalf("current %+v", n)
	}
	// a new word from the watch is taken
	networkDetail(`{"on":false,"kind":"wifi"}`)
	if !netOffline.Load() {
		t.Fatal("a new none was not taken")
	}
}

// a check-in around a valve proof puts a step for the network that is there
func TestACheckInAfterAValveProofPutsAStep(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	keepNetDetail(t)
	quietBounce(t)
	op := netPark
	netPark = func() {}
	t.Cleanup(func() { netPark = op })
	networkDetail(`{"on":false,"kind":"other"}`)
	netDisprove()
	setOffline(false)
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	checkIn(true)
	t.Cleanup(func() { checkIn(false) })
	if !autoDirectOK.Load() {
		t.Fatalf("no step around the proof: direct %v bridges %v", autoDirectOK.Load(), bridgesEnabled())
	}
}

// a network the watch says went: what proved the old route proves nothing
func TestADetailNoneDropsTheProof(t *testing.T) {
	offlineRig(t)
	keepNetDetail(t)
	op := netPark
	netPark = func() {}
	t.Cleanup(func() { netPark = op })
	networkDetail(`{"on":true,"validated":true,"kind":"wifi"}`)
	routeNoteOK()
	networkDetail(`{"on":false,"kind":"other"}`)
	if routeProven() {
		t.Fatal("the old route still counts as proven")
	}
}

// during a valve try with no real network, automatic learns nothing and
// asks nothing
func TestAValveTrialLearnsNothing(t *testing.T) {
	f := useFakeAuto(t, netInfo{On: true, Validated: false, Kind: "wifi"})
	netValveOpen.Store(true)
	t.Cleanup(func() { netValveOpen.Store(false) })
	today := dayOf(f.now)
	memRemember("wifi", autoStep{Method: "obfs4", Source: "builtin"}, today)
	f.script["direct"] = never
	f.script["obfs4"] = never
	f.script["snowflake"] = never
	pass(t, modeOpts{Consent: "ask"})
	m := memSnapshot()
	if _, b := m.Blocked["wifi"]; b {
		t.Fatalf("direct judged blocked with no network: %+v", m)
	}
	if m.Last["wifi"].Method != "obfs4" {
		t.Fatalf("a bridge forgotten with no network: %+v", m)
	}
	if st := bridgeStatus(); st.AskConsent {
		t.Fatalf("asked with no network: %+v", st)
	}
	// a checked network where the censor resets direct, all in the trial
	setNetInfo(wifi())
	f.applied = nil
	f.script["direct"] = resetByCensor
	pass(t, modeOpts{Consent: "ask"})
	if !strings.Contains(strings.Join(f.applied, " "), "direct/") {
		t.Fatalf("tried %v", f.applied)
	}
	if _, b := memSnapshot().Blocked["wifi"]; b {
		t.Fatal("direct remembered blocked with no network")
	}
}

// tor goes on with a bridge step before the direct step's exit lands: the
// exit is not sent. the exit first, then the bridge step: tor ends on
func TestADirectExitAndABridgeStepInEitherOrder(t *testing.T) {
	for _, exitFirst := range []bool{false, true} {
		t.Run(fmt.Sprint(exitFirst), func(t *testing.T) {
			resetAuto(t)
			t.Cleanup(func() { resetAuto(t) })
			f := overlapRig(t)
			f.slow.Store(0)
			keepNetDetail(t)
			autoMu.Lock()
			bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
			autoMu.Unlock()
			mu.Lock()
			tn := torNode
			mu.Unlock()
			ons := netOns.Load()
			bridgeStep := func() {
				useLines([]string{tbObfs4})
				noteLinesApplied(linesGen.Load())
				if why, err := networkOn(tn, nil); why != "" || err != nil {
					t.Fatalf("bridge step on: %q %v", why, err)
				}
			}
			if exitFirst {
				netLeaveDirect(ons)
				bridgeStep()
			} else {
				bridgeStep()
				netLeaveDirect(ons)
			}
			var last string
			for _, c := range f.sent() {
				if strings.Contains(c, "DISABLENETWORK") {
					last = c
				}
			}
			if !strings.Contains(last, netOn) {
				t.Fatalf("tor left off the network with a bridge step in place: %v", f.sent())
			}
		})
	}
}

// tor never answering the bridge config is a stuck control port, not a
// hold: the app's restart is for that
func TestAStuckBridgeConfigSaysSo(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	if r := setBridgeMode(bmOwn, `{"lines":["`+tbObfs4+`"]}`); r != "ok" {
		t.Fatal(r)
	}
	f := overlapRig(t)
	old := ctrlDeadline
	ctrlDeadline = 300 * time.Millisecond
	t.Cleanup(func() { ctrlDeadline = old })
	f.slow.Store(int64(time.Second))
	r := reconnectNow()
	if !strings.HasPrefix(r, "error: control port timeout") {
		t.Fatalf("reconnect: %q", r)
	}
	if sentNetworkOn(f) {
		t.Fatalf("on the network without its bridges: %v", f.sent())
	}
}
