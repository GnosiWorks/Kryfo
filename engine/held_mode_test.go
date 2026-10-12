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

// automatic, risky here, asleep before any step: a wake leaves it awake
// and its pass runs, while tor stays off the network until a step is in
func TestAutomaticAsleepBeforeAnyStepWakesWithoutDirect(t *testing.T) {
	// let go of the blocked ask last, once the pass is stopped
	block := make(chan struct{})
	t.Cleanup(func() { close(block) })
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	f := overlapRig(t)
	f.slow.Store(0)
	setNetInfo(wifi())
	var asked atomic.Int32
	w := liveWorld()
	w.moat = func(o moatOpts) ([]moatSetting, error) {
		asked.Add(1)
		<-block
		return nil, nil
	}
	old := autoW
	autoW = w
	t.Cleanup(func() { autoW = old })
	atomicPaused(t)
	if r := restoreBridgeMode(bmAuto, `{"consent":"yes","skip_direct":true}`); r != "ok" {
		t.Fatal(r)
	}
	time.Sleep(200 * time.Millisecond)
	if asked.Load() != 0 {
		t.Fatal("a pass ran while asleep")
	}
	if r := torResume(); r != "ok" {
		t.Fatalf("wake: %q", r)
	}
	if torIsPaused() {
		t.Fatal("automatic left asleep")
	}
	deadline := time.Now().Add(5 * time.Second)
	for asked.Load() == 0 && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	if asked.Load() == 0 {
		t.Fatal("no pass after the wake")
	}
	if sentNetworkOn(f) {
		t.Fatalf("automatic went out with no way in: %v", f.sent())
	}
}

// tor out direct, then automatic picked as risky with the yes: tor leaves
// the network before the tor project is asked
func TestRiskyAutomaticTakesDirectOffBeforeAsking(t *testing.T) {
	block := make(chan struct{})
	t.Cleanup(func() { close(block) })
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	f := overlapRig(t)
	f.slow.Store(0)
	setNetInfo(wifi())
	if r := setBridgeMode(bmDirect, ""); r != "ok" {
		t.Fatal(r)
	}
	// the pick bounces tor out direct
	deadline := time.Now().Add(5 * time.Second)
	for !sentNetworkOn(f) && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	if !sentNetworkOn(f) {
		t.Fatalf("direct never went out: %v", f.sent())
	}
	n := len(f.sent())
	var offAtAsk atomic.Bool
	w := liveWorld()
	w.moat = func(o moatOpts) ([]moatSetting, error) {
		last := ""
		for _, c := range f.sent() {
			if strings.Contains(c, "DISABLENETWORK") {
				last = c
			}
		}
		offAtAsk.Store(strings.Contains(last, "DISABLENETWORK=1"))
		<-block
		return nil, nil
	}
	old := autoW
	autoW = w
	t.Cleanup(func() { autoW = old })
	if r := setBridgeMode(bmAuto, `{"consent":"yes","skip_direct":true}`); r != "ok" {
		t.Fatal(r)
	}
	deadline = time.Now().Add(5 * time.Second)
	for !offAtAsk.Load() && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	if !offAtAsk.Load() {
		t.Fatalf("still on the network direct while asking: %v", sentAfter(f, n))
	}
	if netOnIn(sentAfter(f, n)) {
		t.Fatalf("went out direct: %v", sentAfter(f, n))
	}
}

// out direct on wi-fi; then a mobile network where direct was blocked
// lately: the bounce does not go out direct there
func TestNewNetworkWhereDirectWasBlockedStaysOff(t *testing.T) {
	fa := useFakeAuto(t, wifi())
	f := overlapRig(t)
	f.slow.Store(0)
	today := dayOf(fa.now)
	memMu.Lock()
	autoMem.Blocked = map[string]int64{"cellular": today}
	memMu.Unlock()
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	autoDirectOK.Store(true)
	n := len(f.sent())
	setNetInfo(netInfo{On: true, Validated: true, Kind: "cellular"})
	networkChanged()
	if r := reconnectNow(); r != errAutoWait {
		t.Fatalf("bounce: %q", r)
	}
	for _, c := range sentAfter(f, n) {
		if strings.Contains(c, "USEBRIDGES=0") || strings.Contains(c, "DISABLENETWORK=0") {
			t.Fatalf("out direct on a network that blocked it: %v", sentAfter(f, n))
		}
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

// a check-in with nothing remembered: tor alone where welcome, else the
// built-in bridges, never direct
func TestCheckInWithNoMemory(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	setNetInfo(wifi())
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	checkIn(true)
	t.Cleanup(func() { checkIn(false) })
	if bridgesEnabled() || !autoDirectOK.Load() || networkHold() != "" {
		t.Fatalf("plain: bridges %v direct ok %v hold %q", bridgesEnabled(), autoDirectOK.Load(), networkHold())
	}
	checkIn(false)
	autoMu.Lock()
	bmOpts = modeOpts{Consent: "no", SkipDirect: true}
	autoMu.Unlock()
	checkIn(true)
	if !bridgesEnabled() || autoDirectOK.Load() {
		t.Fatalf("risky: bridges %v direct ok %v", bridgesEnabled(), autoDirectOK.Load())
	}
	if l := bridgeLines(); len(l) == 0 || !strings.HasPrefix(l[0], "obfs4 ") {
		t.Fatalf("lines: %v", l)
	}
}

// a check-in on a remembered direct is automatic's direct step
func TestCheckInOnRememberedDirect(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	setNetInfo(wifi())
	today := dayOf(autoNow())
	memMu.Lock()
	autoMem.Last = map[string]autoUse{"wifi": {Method: "direct", Day: today}}
	memMu.Unlock()
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	checkIn(true)
	t.Cleanup(func() { checkIn(false) })
	if why := networkHold(); why != "" {
		t.Fatalf("hold: %q", why)
	}
}

// a new mode ends whatever direct step automatic had
func TestNewModeEndsAutomaticsDirectStep(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	setNetInfo(netInfo{On: false, Kind: "none"})
	if r := setBridgeMode(bmDirect, ""); r != "ok" {
		t.Fatal(r)
	}
	autoDirectOK.Store(true)
	if r := setBridgeMode(bmAuto, `{"skip_direct":true}`); r != "ok" {
		t.Fatal(r)
	}
	if why := networkHold(); why != errAutoWait {
		t.Fatalf("hold: %q", why)
	}
}

// new lines with no mode: tor does not hold them yet
func TestLegacyNewLinesAreNotApplied(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	setBridgeLines("", false)
	noteLinesApplied(linesGen.Load())
	setBridgeLines(tbObfs4, true)
	if bridgesApplied() {
		t.Fatal("new lines look applied")
	}
}

// the mode is known only once its lines are in place
func TestModeKnownOnlyWithItsLines(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	seen := []bool{}
	useLinesHook = func() { seen = append(seen, bridgeModeKnown()) }
	t.Cleanup(func() { useLinesHook = nil })
	if r := restoreBridgeMode(bmOwn, `{"lines":["`+tbObfs4+`"]}`); r != "ok" {
		t.Fatal(r)
	}
	if len(seen) == 0 || seen[0] {
		t.Fatalf("known before the lines: %v", seen)
	}
}

// a wake waits for a reconnect under way, and is refused past the wait
func TestWakeWaitsForAReconnect(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	if r := setBridgeMode(bmDirect, ""); r != "ok" {
		t.Fatal(r)
	}
	f := overlapRig(t)
	f.slow.Store(0)
	oldWait, oldStep := resumeWait, resumeStep
	resumeWait, resumeStep = 300*time.Millisecond, 10*time.Millisecond
	t.Cleanup(func() { resumeWait, resumeStep = oldWait, oldStep })
	atomic.StoreInt32(&torRestarting, 1)
	t.Cleanup(func() { atomic.StoreInt32(&torRestarting, 0) })
	atomicPaused(t)
	if r := torResume(); r != "error: a reconnect is running" {
		t.Fatalf("wake during a stuck reconnect: %q", r)
	}
	if sentNetworkOn(f) || !torIsPaused() {
		t.Fatalf("woke under a reconnect: %v paused %v", f.sent(), torIsPaused())
	}
	// one that ends within the wait: the wake goes on after it
	go func() {
		time.Sleep(100 * time.Millisecond)
		atomic.StoreInt32(&torRestarting, 0)
	}()
	if r := torResume(); r != "ok" {
		t.Fatalf("wake after the reconnect: %q", r)
	}
}

// a late answer for older lines does not take the place of newer ones
func TestAppliedNeverGoesBack(t *testing.T) {
	old := linesApplied.Load()
	t.Cleanup(func() { linesApplied.Store(old) })
	noteLinesApplied(old + 5)
	noteLinesApplied(old + 3)
	if linesApplied.Load() != old+5 {
		t.Fatalf("applied went back to %d", linesApplied.Load())
	}
}

// on direct, then a network change of the same kind: tor is held off the
// new network, so the loop starts a pass at once instead of waiting for a
// lost pass minutes on
func TestSameKindNetworkChangeStartsAPass(t *testing.T) {
	f := useFakeAuto(t, wifi())
	calls := runLoop(t, f, func(n int, why string) string {
		if n == 1 {
			autoDirectOK.Store(true)
			// the change, as networkChanged makes it
			netEpoch.Add(1)
			autoDirectOK.Store(false)
			return seenOK
		}
		stopLoop()
		return seenOK
	})
	if len(calls) != 2 || calls[1].why != "network" {
		t.Fatalf("passes %v", calls)
	}
}

// awake with no way in place and nothing else changed, as after a wake:
// a pass runs
func TestAWakeWithNoWayInStartsAPass(t *testing.T) {
	f := useFakeAuto(t, wifi())
	calls := runLoop(t, f, func(n int, why string) string {
		if n == 1 {
			autoDirectOK.Store(false)
			return seenOK
		}
		stopLoop()
		return seenOK
	})
	if len(calls) != 2 || calls[1].why != "held" {
		t.Fatalf("passes %v", calls)
	}
}

// a check-in on a remembered direct that sees the network change inside
// its minute puts its step back
func TestCheckInKeepsItsStepAcrossANetworkChange(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	oldB, oldQ := netBounce, netQuiet
	netBounce, netQuiet = func() {}, time.Millisecond
	t.Cleanup(func() {
		time.Sleep(50 * time.Millisecond)
		netBounce, netQuiet = oldB, oldQ
	})
	setNetInfo(wifi())
	today := dayOf(autoNow())
	memMu.Lock()
	autoMem.Last = map[string]autoUse{"wifi": {Method: "direct", Day: today}}
	memMu.Unlock()
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	checkIn(true)
	t.Cleanup(func() { checkIn(false) })
	networkChanged()
	if !waitUntil(2*time.Second, func() bool { return networkHold() == "" }) {
		t.Fatalf("a check-in left held by a network change: %q", networkHold())
	}
}

// direct reset by the censor, then the tor project asked: tor is off the
// network by then
func TestFailedDirectIsOffBeforeAsking(t *testing.T) {
	fa := useFakeAuto(t, wifi())
	f := overlapRig(t)
	f.slow.Store(0)
	fa.script["direct"] = resetByCensor
	var asked, offAtAsk atomic.Bool
	fa.moatOut = nil
	w := autoW
	w.moat = func(o moatOpts) ([]moatSetting, error) {
		last := ""
		for _, c := range f.sent() {
			if strings.Contains(c, "DISABLENETWORK") {
				last = c
			}
		}
		asked.Store(true)
		offAtAsk.Store(strings.Contains(last, "DISABLENETWORK=1") && networkHold() != "")
		return nil, nil
	}
	autoW = w
	autoMu.Lock()
	autoGenN++
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "yes"}
	gen := autoGenN
	autoMu.Unlock()
	runPass(gen, netEpoch.Load(), "start")
	if !asked.Load() {
		t.Fatal("the tor project was never asked")
	}
	if !offAtAsk.Load() {
		t.Fatalf("still out direct when asking: %v", f.sent())
	}
}

// a pass that reports ok while the hold stays backs off as a lost pass
// does: a few over two hours, never one every twenty seconds
func TestHeldPassesBackOff(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.up = func() bool {
		f.sleep(time.Minute)
		return true
	}
	calls := runLoop(t, f, func(n int, why string) string {
		if f.now.Sub(t0Auto) > 2*time.Hour || n > 50 {
			stopLoop()
		}
		// ok, and still no way in place
		autoDirectOK.Store(false)
		return seenOK
	})
	if len(calls) > 8 {
		t.Fatalf("%d passes in two hours: %v", len(calls), calls)
	}
	for i := 2; i < len(calls); i++ {
		if calls[i].why != "held" {
			t.Fatalf("pass %d: %v", i, calls)
		}
		if gap, last := calls[i].at-calls[i-1].at, calls[i-1].at-calls[max(i-2, 0)].at; i > 2 && gap < last {
			t.Fatalf("held passes came closer: %v", calls)
		}
	}
}

// a held pass on lines already in place puts them in again, which brings
// the listeners back and clears the hold
func TestHeldPassReappliesAndClearsTheHold(t *testing.T) {
	fa := useFakeAuto(t, wifi())
	fa.settled = true
	fa.proven = true
	lines := []string{tbObfs4}
	w := autoW
	w.apply = func(s autoStep) string {
		fa.applied = append(fa.applied, s.Method+"/"+s.Source)
		if startPTListeners() != nil {
			return errPTDown
		}
		noteLinesApplied(linesGen.Load())
		return "ok"
	}
	autoW = w
	autoMu.Lock()
	autoGenN++
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	gen := autoGenN
	autoMu.Unlock()
	useLines(lines)
	noteLinesApplied(linesGen.Load())
	ptDown.Store(true)
	t.Cleanup(func() { ptDown.Store(false) })
	if networkHold() != errPTDown {
		t.Fatalf("hold: %q", networkHold())
	}
	p := passCtx{gen: gen, epoch: netEpoch.Load(), valid: autoValidFlips.Load()}
	v := runAttempt(p, autoStep{Method: "obfs4", Source: "builtin", Lines: lines}, true)
	if len(fa.applied) != 1 {
		t.Fatalf("not put in again: %v (%q)", fa.applied, v)
	}
	if ptDown.Load() || networkHold() != "" {
		t.Fatalf("still held: %q", networkHold())
	}
}

// a check-in's step and a new mode never interleave: the new mode's end
// of direct is the last word
func TestCheckInStepAndANewModeDoNotInterleave(t *testing.T) {
	useFakeAuto(t, wifi())
	today := dayOf(autoNow())
	memMu.Lock()
	autoMem.Last = map[string]autoUse{"wifi": {Method: "direct", Day: today}}
	memMu.Unlock()
	autoMu.Lock()
	autoGenN++
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	done := make(chan struct{})
	autoStepHook = func() {
		autoStepHook = nil
		go func() {
			setBridgeMode(bmAuto, `{"skip_direct":true}`)
			close(done)
		}()
		time.Sleep(50 * time.Millisecond)
	}
	t.Cleanup(func() { autoStepHook = nil })
	checkIn(true)
	t.Cleanup(func() { checkIn(false) })
	<-done
	if autoDirectOK.Load() {
		t.Fatal("a check-in's direct mark landed over the new mode")
	}
}

// no built-in line left for a transport, for the tests
func noBuiltin(t *testing.T, tr string) {
	t.Helper()
	old := builtinBundled[tr]
	builtinBundled[tr] = nil
	t.Cleanup(func() { builtinBundled[tr] = old })
}

// snowflake with no line to use is refused, never direct
func TestSnowflakeWithNoLineIsRefused(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	noBuiltin(t, "snowflake")
	if r := setBridgeMode(bmSnowflake, ""); r != "error: lines_bad" {
		t.Fatalf("snowflake with no lines: %q", r)
	}
	if bridgeModeKnown() || networkHold() == "" {
		t.Fatalf("known %v hold %q", bridgeModeKnown(), networkHold())
	}
}

// a check-in where only the built-in bridges may go, and there are none:
// a hold, never direct
func TestCheckInWithNoBuiltinLineHolds(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	setNetInfo(wifi())
	noBuiltin(t, "obfs4")
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no", SkipDirect: true}
	autoMu.Unlock()
	autoDirectOK.Store(true)
	if r := checkIn(true); r != "error: lines_bad" {
		t.Fatalf("check-in: %q", r)
	}
	t.Cleanup(func() { checkIn(false) })
	if autoDirectOK.Load() || bridgesEnabled() || networkHold() != errAutoWait {
		t.Fatalf("direct ok %v bridges %v hold %q", autoDirectOK.Load(), bridgesEnabled(), networkHold())
	}
}
