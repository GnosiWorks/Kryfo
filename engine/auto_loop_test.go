// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// the loop that starts passes, the gate's owner, and what a network change,
// a portal, a decoy and slow relays do to automatic

type loopCall struct {
	at  time.Duration
	why string
}

// runs the loop with passes that answer from a script, until the script
// stops it
func runLoop(t *testing.T, f *fakeAuto, script func(n int, why string) string) []loopCall {
	t.Helper()
	oldTick := autoTick
	autoTick = time.Millisecond
	defer func() { autoTick = oldTick }()
	var calls []loopCall
	autoMu.Lock()
	autoGenN++
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	gen := autoGenN
	autoMu.Unlock()
	autoRunPass = func(g, epoch int64, why string) string {
		calls = append(calls, loopCall{f.now.Sub(t0Auto), why})
		return script(len(calls), why)
	}
	done := make(chan struct{})
	go func() { autoLoop(gen); close(done) }()
	select {
	case <-done:
	case <-time.After(10 * time.Second):
		autoMu.Lock()
		autoGenN++
		autoMu.Unlock()
		<-done
		t.Fatalf("the loop never stopped: %v", calls)
	}
	return calls
}

func stopLoop() {
	autoMu.Lock()
	autoGenN++
	autoMu.Unlock()
}

// a pass cut short by a flapping network starts again only once the
// network is quiet, and never closer to the last than the floor
func TestLoopWaitsOutAFlappingNetwork(t *testing.T) {
	f := useFakeAuto(t, wifi())
	calls := runLoop(t, f, func(n int, why string) string {
		if n == 1 {
			for i := 0; i < 3; i++ {
				f.sleep(time.Second)
				netEpoch.Add(1)
			}
			return passInterrupted
		}
		stopLoop()
		return seenOK
	})
	if len(calls) != 2 || calls[1].why != "network" {
		t.Fatalf("passes %v", calls)
	}
	if gap := calls[1].at - calls[0].at; gap < autoPassFloor || gap < 3*time.Second+netQuiet {
		t.Fatalf("the next pass came %s after the last", gap)
	}
}

// the proof of the old network is no proof of the new one
func TestNetworkChangeDropsTheProof(t *testing.T) {
	quietBounce(t)
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	if !routeProven() {
		t.Fatal("no proof to begin with")
	}
	networkChanged()
	if routeProven() {
		t.Fatal("a new network kept the old network's proof")
	}
}

// a new pass after tor lost its circuits backs off, and a relay outage
// with tor still up is no reason for one
func TestLostPassesBackOff(t *testing.T) {
	f := useFakeAuto(t, wifi())
	// the way the first pass found, in place and held by tor: no hold, so
	// what follows is tor losing its circuits on it
	useLines([]string{tbObfs4})
	noteLinesApplied(linesGen.Load())
	if why := networkHold(); why != "" {
		t.Fatalf("hold: %q", why)
	}
	up := false
	f.up = func() bool {
		f.sleep(time.Minute)
		return up
	}
	calls := runLoop(t, f, func(n int, why string) string {
		if n == 3 {
			stopLoop()
		}
		return seenOK
	})
	if len(calls) != 3 || calls[1].why != "lost" || calls[2].why != "lost" {
		t.Fatalf("passes %v", calls)
	}
	first, second := calls[1].at-calls[0].at, calls[2].at-calls[1].at
	if first < autoLostAfter || second < 2*autoLostAfter {
		t.Fatalf("lost passes after %s and %s, want a back-off", first, second)
	}

	// relays dead, tor up: no pass
	resetRoute(t, "publishing", 100)
	up = true
	minutes := 0
	f.up = func() bool {
		f.sleep(time.Minute)
		if minutes++; minutes > 60 {
			stopLoop()
		}
		return true
	}
	calls = runLoop(t, f, func(n int, why string) string { return seenOK })
	if len(calls) != 1 || routeOK() {
		t.Fatalf("passes %v with tor up and the relays down", calls)
	}
}

// a pass gives back only its own hold on the gate
func TestGateReleaseOnlyByItsPass(t *testing.T) {
	useFakeAuto(t, wifi())
	one := gateHold(autoGen(), time.Minute)
	gateDrop()
	two := gateHold(autoGen(), time.Minute)
	gateRelease(one)
	if !autoGateHeld() || !gateOwned(two) {
		t.Fatal("an old pass released a newer one's gate")
	}
	gateRelease(two)
	if autoGateHeld() {
		t.Fatal("the gate outlived its pass")
	}
}

// the cap holds for a whole pass, waiting for tor to start included
func TestPassCapWhileTorNeverStarts(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.started = false
	f.at(3*time.Hour, stopLoop)
	r := pass(t, modeOpts{})
	steps := planPass("wifi", autoMemory{}, modeOpts{}, dayOf(t0Auto))
	if r != "exhausted" || f.now.Sub(t0Auto) > passBudget(steps)+autoGateSlack+time.Minute {
		t.Fatalf("pass %s after %s", r, f.now.Sub(t0Auto))
	}
	if autoGateHeld() {
		t.Fatal("the gate held past the pass")
	}
}

// behind a captive portal nothing is tried and nothing asked; once
// android validates the network a pass starts at once
func TestCaptivePortalIdlesThenRetries(t *testing.T) {
	f := useFakeAuto(t, netInfo{On: true, Limited: true, Kind: "wifi"})
	if why := autoIdleWhy(); why != "captive" {
		t.Fatalf("idle %q", why)
	}
	st := bridgeStatus()
	if st.Phase != "captive" || st.AskConsent || st.Attempts != 0 {
		t.Fatalf("status %+v", st)
	}
	var signedIn atomic.Bool
	go func() {
		time.Sleep(50 * time.Millisecond)
		signedIn.Store(true)
		setNetInfo(wifi())
	}()
	early := false
	calls := runLoop(t, f, func(n int, why string) string {
		early = early || !signedIn.Load()
		stopLoop()
		return seenOK
	})
	if len(calls) != 1 || early {
		t.Fatalf("passes %v, one before the sign-in: %v", calls, early)
	}
	if len(f.applied) != 0 {
		t.Fatalf("tried %v behind the portal", f.applied)
	}
	// an unvalidated network that android then validates retries at once
	setNetInfo(netInfo{On: true, Validated: false, Kind: "wifi"})
	n := autoValidFlips.Load()
	setNetInfo(wifi())
	if autoValidFlips.Load() != n+1 {
		t.Fatal("validation not noticed")
	}
}

// wifi back behind a portal while direct was what worked here: the pass on
// it is cut short by the portal, and tor must not be left with no way in.
// the way that worked is put back without a pass, and nothing unknown is
func TestCaptiveKeepsTheKnownWay(t *testing.T) {
	f := useFakeAuto(t, wifi())
	memRemember("wifi", autoStep{Method: "direct"}, dayOf(f.now))
	bounces := 0
	old := captiveBounce
	captiveBounce = func() { bounces++ }
	defer func() { captiveBounce = old }()
	portal := netInfo{On: true, Limited: true, Kind: "wifi"}
	f.script["direct"] = func(a *attemptSeen, el time.Duration) {
		if el >= 4*time.Second {
			setNetInfo(portal)
		}
	}
	if r := pass(t, modeOpts{}); r != passInterrupted {
		t.Fatalf("pass %s", r)
	}
	if why := networkHold(); why != errAutoWait {
		t.Fatalf("hold after the cut pass: %q", why)
	}
	go func() {
		time.Sleep(50 * time.Millisecond)
		stopLoop()
	}()
	if calls := runLoop(t, f, func(int, string) string { return seenOK }); len(calls) != 0 {
		t.Fatalf("passes behind the portal: %v", calls)
	}
	if why := networkHold(); why != "" {
		t.Fatalf("tor left off behind the portal: %q", why)
	}
	if st := bridgeStatus(); st.Phase != "captive" || st.Method != "direct" {
		t.Fatalf("status %+v", st)
	}
	// nothing remembered for this type of network: it waits for the sign-in
	resetAuto(t)
	autoDirectOK.Store(false)
	setNetInfo(portal)
	go func() {
		time.Sleep(50 * time.Millisecond)
		stopLoop()
	}()
	runLoop(t, f, func(int, string) string { return seenOK })
	if why := networkHold(); why != errAutoWait {
		t.Fatalf("an unknown way put in place behind a portal: %q", why)
	}
}

// a method that failed in a pass is no longer the one to check in by
func TestCheckInForgetsAFailedMethod(t *testing.T) {
	f := useFakeAuto(t, wifi())
	today := dayOf(f.now)
	memRemember("wifi", autoStep{Method: "obfs4", Source: "builtin"}, today-3)
	memBlocked("wifi", today)
	f.script["obfs4"] = never
	f.script["snowflake"] = worksAfter(10 * time.Second)
	if r := pass(t, modeOpts{}); r != seenOK || memSnapshot().Last["wifi"].Method != "snowflake" {
		t.Fatalf("pass %s, tried %v", r, f.applied)
	}
	if s, ok := checkInStep("wifi", memSnapshot(), modeOpts{}, today); ok && s.Method == "obfs4" {
		t.Fatalf("check-ins still go by obfs4 after it failed: %+v", s)
	}
}

// memory from a decoy is never taken
func TestDecoyMemoryRefused(t *testing.T) {
	useFakeAuto(t, wifi())
	if r := setBridgeMode(bmAuto, ""); r != "ok" {
		t.Fatalf("auto: %s", r)
	}
	decoyState.Store(decoyOn)
	if r := setAutoMemory(`{"v":1,"blocked":{"wifi":1}}`); !strings.Contains(r, "decoy") {
		t.Fatalf("memory taken in a decoy: %s", r)
	}
}

// a decoy's status says connected, trying or offline, and nothing more
func TestDecoyStatusIsBare(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.script["direct"] = never
	var mid bridgeStatusView
	f.at(10*time.Second, func() {
		decoyState.Store(decoyOn)
		mid = bridgeStatus()
		decoyState.Store(decoyOff)
	})
	f.at(20*time.Second, func() { stopLoop() })
	pass(t, modeOpts{})
	if mid.Phase != "trying" || mid.Attempt != 0 || mid.Attempts != 0 || mid.SinceMs != 0 || mid.Method != "" || mid.ErrorCode != "" {
		t.Fatalf("decoy mid-pass %+v", mid)
	}
	stSet(func() { autoSt.phase, autoSt.errCode = "exhausted", "exhausted" })
	decoyState.Store(decoyOn)
	if st := bridgeStatus(); st.Phase != "offline" || st.ErrorCode != "" {
		t.Fatalf("decoy after a pass gave up %+v", st)
	}
}

// relays that hold the client lock for long do not make a switch late,
// and a working direct route is not judged blocked
func TestSlowRelaysDoNotBlockDirect(t *testing.T) {
	oldW, oldS := autoSetconfWait, bounceSettle
	autoSetconfWait, bounceSettle = 300*time.Millisecond, time.Millisecond
	defer func() { autoSetconfWait, bounceSettle = oldW, oldS }()
	fc := newFakeControl(t, 100)
	fc.circ.Store(1)
	fakeTor(t, fc.port())
	f := useFakeAuto(t, wifi())
	_ = f
	autoW = liveWorld()

	cachedNostrClientMu.Lock()
	var held atomic.Bool
	held.Store(true)
	go func() {
		time.Sleep(1500 * time.Millisecond)
		held.Store(false)
		cachedNostrClientMu.Unlock()
	}()
	defer func() {
		for held.Load() {
			time.Sleep(10 * time.Millisecond)
		}
		time.Sleep(100 * time.Millisecond)
	}()
	autoMu.Lock()
	autoGenN++
	bmMode = bmAuto
	gen := autoGenN
	autoMu.Unlock()
	p := passCtx{gen: gen, epoch: netEpoch.Load(), valid: autoValidFlips.Load()}
	p.id = gateHold(gen, time.Hour)
	defer gateRelease(p.id)
	// lines that change, so it bounces
	setTestLines(true, builtinLines("obfs4")...)
	if v := runAttempt(p, autoStep{Method: "direct", Limit: directLimit}, true); v != seenOK {
		t.Fatalf("direct with slow relays: %s", v)
	}
}

func setTestLines(on bool, lines ...string) {
	bridgeMu.Lock()
	bridgeList, bridgeOn = lines, on
	bridgeMu.Unlock()
}

// the old call saying online does not make a network validated
func TestOnlineIsNotValidated(t *testing.T) {
	useFakeAuto(t, netInfo{On: false, Kind: "wifi"})
	netOffline.Store(false)
	if n := currentNet(); !n.On || n.Validated {
		t.Fatalf("network %+v", n)
	}
}
