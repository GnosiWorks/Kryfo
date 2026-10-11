// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// tor goes on the network only with what the person wants in place: the
// bridges tor really holds, the direct mode, or automatic's own direct
// step. never automatic before any step, never bridges tor refused, never
// a refused or unknown mode. the restore is asked for once

// what was sent after the first n commands
func sentAfter(f *fakeControl, n int) []string { return f.sent()[n:] }

func netOnIn(cmds []string) bool {
	for _, c := range cmds {
		if strings.Contains(c, "DISABLENETWORK=0") {
			return true
		}
	}
	return false
}

// automatic, risky here, asking the tor project first: a wake meanwhile
// stays off the network
func TestAutomaticBeforeAnyStepNeverWakesDirect(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	f := overlapRig(t)
	f.slow.Store(0)
	setNetInfo(wifi())
	block := make(chan struct{})
	t.Cleanup(func() { close(block) })
	w := liveWorld()
	w.moat = func(o moatOpts) ([]moatSetting, error) { <-block; return nil, nil }
	old := autoW
	autoW = w
	t.Cleanup(func() { autoW = old })
	if r := restoreBridgeMode(bmAuto, `{"consent":"yes","skip_direct":true}`); r != "ok" {
		t.Fatal(r)
	}
	time.Sleep(200 * time.Millisecond)
	atomicPaused(t)
	if r := torResume(); r != errAutoWait {
		t.Fatalf("wake: %q", r)
	}
	if sentNetworkOn(f) {
		t.Fatalf("automatic went out with no way in: %v", f.sent())
	}
	if !torIsPaused() {
		t.Fatal("a refused wake left tor marked awake")
	}
}

// the same with no network at start, so no pass: a rescue or network
// bounce stays off too
func TestAutomaticBeforeAnyStepNeverBouncesDirect(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	f := overlapRig(t)
	f.slow.Store(0)
	setNetInfo(netInfo{On: false, Kind: "none"})
	if r := restoreBridgeMode(bmAuto, `{"skip_direct":true}`); r != "ok" {
		t.Fatal(r)
	}
	time.Sleep(100 * time.Millisecond)
	if r := reconnectNow(); r != errAutoWait {
		t.Fatalf("reconnect: %q", r)
	}
	if sentNetworkOn(f) {
		t.Fatalf("a bounce went out with no way in: %v", f.sent())
	}
}

// bridges tor refused stay refused: a later wake does not go out on
// whatever tor held before
func TestRefusedBridgesNeverWake(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t); fakeBridgeFail.Store(false) })
	if r := setBridgeMode(bmOwn, `{"lines":["`+tbObfs4+`"]}`); r != "ok" {
		t.Fatal(r)
	}
	f := overlapRig(t)
	f.slow.Store(0)
	fakeBridgeFail.Store(true)
	if r := reconnectNow(); r != errNoConf {
		t.Fatalf("reconnect: %q", r)
	}
	if v := bridgeStatus(); v.ErrorCode != codeNoConf {
		t.Fatalf("status: %+v", v)
	}
	n := len(f.sent())
	atomicPaused(t)
	if r := torResume(); r != errNoConf {
		t.Fatalf("wake: %q", r)
	}
	if netOnIn(sentAfter(f, n)) {
		t.Fatalf("a wake went out without the bridges: %v", sentAfter(f, n))
	}
	if !torIsPaused() {
		t.Fatal("a refused wake left tor marked awake")
	}
	// tor takes them again: the wake tells it first and goes out
	fakeBridgeFail.Store(false)
	if r := torResume(); r != "ok" {
		t.Fatalf("wake: %q", r)
	}
	endsOnTheNetwork(t, f)
}

// lines that change between tor's start args and its first network on:
// held, and a bounce of its own puts them in place
func TestLinesChangedDuringStartAreBouncedIn(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	if r := setBridgeMode(bmOwn, `{"lines":["`+tbObfs4+`"]}`); r != "ok" {
		t.Fatal(r)
	}
	torArgs()
	if why := networkHold(); why != "" {
		t.Fatalf("start args in place, still held: %q", why)
	}
	other := strings.Replace(tbObfs4, "37.218.245.14:38224", "192.0.2.9:443", 1)
	if r := setBridgeMode(bmOwn, `{"lines":["`+other+`"]}`); r != "ok" {
		t.Fatal(r)
	}
	if why := networkHold(); why != errNoConf {
		t.Fatalf("hold: %q", why)
	}
	f := newFakeControl(t, 100)
	tn := fakeTor(t, f.port())
	resetRoute(t, "publishing", 100)
	networkOnAtStart(tn)
	deadline := time.Now().Add(5 * time.Second)
	for !sentNetworkOn(f) && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	var bridgesAt, onAt = -1, -1
	for i, c := range f.sent() {
		if strings.Contains(c, "USEBRIDGES=1") && bridgesAt < 0 {
			bridgesAt = i
		}
		if strings.Contains(c, "DISABLENETWORK=0") && onAt < 0 {
			onAt = i
		}
	}
	if onAt < 0 || bridgesAt < 0 || bridgesAt > onAt {
		t.Fatalf("network on before the bridges: %v", f.sent())
	}
}

// a start with nothing held goes straight on the network
func TestStartWithNothingHeldGoesOn(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	if r := setBridgeMode(bmDirect, ""); r != "ok" {
		t.Fatal(r)
	}
	f := newFakeControl(t, 100)
	tn := fakeTor(t, f.port())
	networkOnAtStart(tn)
	if !sentNetworkOn(f) {
		t.Fatalf("direct held: %v", f.sent())
	}
}

// a kept mode the engine refuses becomes automatic without tor alone, the
// status never says direct, and the restore is not asked for twice
func TestRefusedRestoreFallsBackNeverDirect(t *testing.T) {
	useFakeAuto(t, wifi())
	unknownMode(t)
	if v := bridgeStatus(); v.Method == "direct" || v.ErrorCode != codeNoMode {
		t.Fatalf("no mode yet: %+v", v)
	}
	if r := restoreBridgeMode(bmWebtunnel, `{"consent":"yes","country":"ir","lines":["`+tbObfs4+`"]}`); r != "error: lines_bad" {
		t.Fatalf("restore: %q", r)
	}
	mode, opts, _ := bridgeMode()
	if mode != bmAuto || !opts.SkipDirect || !bridgeModeKnown() {
		t.Fatalf("fallback: %q %+v", mode, opts)
	}
	// the yes and the country go with it
	if opts.Consent != "yes" || opts.Country != "ir" {
		t.Fatalf("fallback lost the person's choices: %+v", opts)
	}
	if v := bridgeStatus(); v.Method == "direct" {
		t.Fatalf("status says direct: %+v", v)
	}
	if r := restoreBridgeMode(bmDirect, ""); r != "error: restore used" {
		t.Fatalf("second restore: %q", r)
	}
}

// a restore and a pick never interleave: the restore waits its turn
func TestRestoreWaitsForAPick(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	modeMu.Lock()
	done := make(chan string, 1)
	go func() { done <- restoreBridgeMode(bmDirect, "") }()
	select {
	case r := <-done:
		modeMu.Unlock()
		t.Fatalf("the restore ran during a pick: %q", r)
	case <-time.After(100 * time.Millisecond):
	}
	// the pick lands first
	if r := applyBridgeMode(bmOwn, `{"lines":["`+tbObfs4+`"]}`); r != "ok" {
		modeMu.Unlock()
		t.Fatal(r)
	}
	modeMu.Unlock()
	if r := <-done; r != "error: mode already set" {
		t.Fatalf("restore over a pick: %q", r)
	}
	if mode, _, _ := bridgeMode(); mode != bmOwn {
		t.Fatalf("mode: %q", mode)
	}
}

// a check-in never goes direct where tor is risky or was blocked lately
func TestCheckInRespectsRiskyAndBlocked(t *testing.T) {
	today := int64(20000)
	mem := autoMemory{V: 1, Last: map[string]autoUse{"wifi": {Method: "direct", Day: today}}}
	if s, ok := checkInStep("wifi", mem, modeOpts{}, today); !ok || s.Method != "direct" {
		t.Fatalf("plain: %+v %v", s, ok)
	}
	if _, ok := checkInStep("wifi", mem, modeOpts{SkipDirect: true}, today); ok {
		t.Fatal("direct while risky")
	}
	mem.Blocked = map[string]int64{"wifi": today}
	if _, ok := checkInStep("wifi", mem, modeOpts{}, today); ok {
		t.Fatal("direct where it was blocked")
	}
}

// the old call says nothing before the decoy is known closed, and lines
// it cannot read set no mode
func TestLegacyCallNeedsAClosedDecoyAndALine(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	decoyState.Store(decoyUnknown)
	if r := setBridges(tbObfs4, true); r != "error: decoy" {
		t.Fatalf("decoy unknown: %q", r)
	}
	decoyState.Store(decoyOff)
	setBridges("obfs4 mangled", true)
	if bridgeModeKnown() {
		t.Fatal("unreadable lines set a mode")
	}
	setBridges("", false)
	if !bridgeModeKnown() {
		t.Fatal("bridges off is a mode")
	}
}

// a decoy reads no line checks
func TestDecoyReadsNoLineChecks(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	setDecoy(true)
	restoreBridgeMode(bmOwn, `{"lines":["`+tbObfs4+`","obfs4 bad"]}`)
	if c := bridgeLineChecks(); c != "[]" {
		t.Fatalf("a decoy read %s", c)
	}
	setDecoy(false)
	if c := bridgeLineChecks(); c == "[]" {
		t.Fatal("the checks are gone")
	}
}

// automatic with the listeners down says so too
func TestAutomaticWithListenersDownHasACode(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	ptListenersFail(t)
	autoMu.Lock()
	bmMode = bmAuto
	autoMu.Unlock()
	useLines([]string{tbObfs4})
	if v := bridgeStatus(); v.ErrorCode != codePTDown {
		t.Fatalf("status: %+v", v)
	}
}

// a refused wake leaves tor marked asleep; the tests mark it asleep first
func atomicPaused(t *testing.T) {
	t.Helper()
	atomic.StoreInt32(&torPaused, 1)
	t.Cleanup(func() { atomic.StoreInt32(&torPaused, 0) })
}
