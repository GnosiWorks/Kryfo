// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"encoding/json"
	"net/http"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// automatic against a scripted tor and a clock of its own: what each
// method does is a script, time moves only when the pass sleeps, and the
// network, the pause and the mode change at set moments.

type fakeAuto struct {
	now     time.Time
	applied []string
	// per method: what tor shows, given the time since the switch
	script   map[string]func(a *attemptSeen, el time.Duration)
	applyErr map[string]string
	started  bool
	events   []fakeEvent
	moatOpts []moatOpts
	moatOut  []moatSetting
	moatErr  error
	proven   bool
	settled  bool
	up       func() bool
}

type fakeEvent struct {
	at time.Duration
	f  func()
}

func (f *fakeAuto) sleep(d time.Duration) {
	// a moment of real time, so a call on its own goroutine can answer
	// before the clock runs away from it
	time.Sleep(20 * time.Microsecond)
	f.now = f.now.Add(d)
	var left []fakeEvent
	for _, e := range f.events {
		if !f.now.Before(t0Auto.Add(e.at)) {
			e.f()
		} else {
			left = append(left, e)
		}
	}
	f.events = left
}

var t0Auto = time.Unix(20000*86400, 0)

func (f *fakeAuto) at(d time.Duration, fn func()) { f.events = append(f.events, fakeEvent{d, fn}) }

// a method that never gets through, and one that does after a while
func never(a *attemptSeen, el time.Duration) {
	if a.firstDial.IsZero() {
		a.firstDial = a.since
	}
}

func worksAfter(d time.Duration) func(a *attemptSeen, el time.Duration) {
	return func(a *attemptSeen, el time.Duration) {
		if a.firstDial.IsZero() {
			a.firstDial = a.since
		}
		if el >= d {
			a.circ("BUILT", nil, a.since.Add(el))
		}
	}
}

// direct cut off the way a censor resets it
func resetByCensor(a *attemptSeen, el time.Duration) {
	if el >= time.Second && len(a.fails) == 0 {
		for _, r := range []string{"$A", "$B", "$C"} {
			a.orconn(r, "FAILED", "CONNECTRESET", a.since.Add(el))
		}
	}
}

func useFakeAuto(t *testing.T, n netInfo) *fakeAuto {
	t.Helper()
	f := &fakeAuto{now: t0Auto, started: true, script: map[string]func(*attemptSeen, time.Duration){}, applyErr: map[string]string{}}
	oldNow, oldSleep, oldW := autoNow, autoSleep, autoW
	autoNow = func() time.Time { return f.now }
	autoSleep = f.sleep
	autoW = autoWorld{
		started: func() bool { return f.started },
		apply: func(s autoStep) string {
			f.applied = append(f.applied, s.Method+"/"+s.Source)
			if e := f.applyErr[s.Method]; e != "" {
				return e
			}
			return "ok"
		},
		open: func() *attemptSeen { return newSeen(f.now) },
		poll: func(a *attemptSeen, s autoStep) {
			if sc := f.script[s.Method]; sc != nil {
				sc(a, f.now.Sub(a.since))
			}
		},
		close:   func() {},
		settled: func() bool { return f.settled },
		torUp: func() bool {
			if f.up != nil {
				return f.up()
			}
			return true
		},
		proven: func(int64) bool { return f.proven },
		moat: func(o moatOpts) ([]moatSetting, error) {
			f.moatOpts = append(f.moatOpts, o)
			return f.moatOut, f.moatErr
		},
	}
	resetAuto(t)
	resetRoute(t, "publishing", 100)
	setNetInfo(n)
	t.Cleanup(func() {
		autoNow, autoSleep, autoW, autoRunPass = oldNow, oldSleep, oldW, runPass
		resetAuto(t)
	})
	return f
}

func resetAuto(t *testing.T) {
	t.Helper()
	autoMu.Lock()
	autoGenN++
	bmMode, bmOpts = bmLegacy, modeOpts{}
	autoMu.Unlock()
	memMu.Lock()
	autoMem = autoMemory{V: 1}
	memMu.Unlock()
	stSet(func() {
		autoSt.phase, autoSt.method, autoSt.source, autoSt.since = "", "", "", time.Time{}
		autoSt.blocked, autoSt.limited, autoSt.errCode, autoSt.askConsent = false, false, "", false
	})
	gateDrop()
	checkInMu.Lock()
	checkInUntil = time.Time{}
	checkInMu.Unlock()
	atomic.StoreInt32(&torPaused, 0)
	transportMode.Store(modePrivate)
	decoyState.Store(decoyOff)
	dropMoatSettings()
	netInfoMu.Lock()
	netInfoNow = netInfo{On: true, Validated: true, Kind: "unknown"}
	netInfoMu.Unlock()
	netOffline.Store(false)
	bridgeMu.Lock()
	bridgeList, bridgeOn = nil, false
	bridgeMu.Unlock()
}

func wifi() netInfo { return netInfo{On: true, Validated: true, Kind: "wifi"} }

// a pass under the current mode, as the loop would start it
func pass(t *testing.T, opts modeOpts) string {
	t.Helper()
	autoMu.Lock()
	autoGenN++
	bmMode, bmOpts = bmAuto, opts
	gen := autoGenN
	autoMu.Unlock()
	return runPass(gen, netEpoch.Load(), "test")
}

func TestAutoDirectBlockedObfs4FailsSnowflakeWorks(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.script["direct"] = resetByCensor
	f.script["obfs4"] = never
	f.script["snowflake"] = worksAfter(40 * time.Second)
	var mid bridgeStatusView
	f.at(50*time.Second, func() { mid = bridgeStatus() })
	if r := pass(t, modeOpts{}); r != seenOK {
		t.Fatalf("pass ended %s", r)
	}
	// the line can say "trying another way, 2 of 3" while obfs4 runs
	if mid.Phase != "trying" || mid.Attempt != 2 || mid.Attempts != 3 {
		t.Fatalf("status mid-pass %+v", mid)
	}
	if got := strings.Join(f.applied, " "); got != "direct/ obfs4/builtin snowflake/builtin" {
		t.Fatalf("tried %s", got)
	}
	m := memSnapshot()
	if m.Last["wifi"].Method != "snowflake" || m.Blocked["wifi"] != dayOf(f.now) {
		t.Fatalf("remembered %+v", m)
	}
	st := bridgeStatus()
	if st.Phase != "connected" || st.Method != "snowflake" || !st.Blocked {
		t.Fatalf("status %+v", st)
	}
	// moat was never asked: no consent
	if len(f.moatOpts) != 0 {
		t.Fatal("moat asked without consent")
	}
	// the next pass on this network starts on snowflake, and never direct
	f.applied = nil
	if r := pass(t, modeOpts{}); r != seenOK || f.applied[0] != "snowflake/builtin" {
		t.Fatalf("second pass %s, tried %v", r, f.applied)
	}
	// another type of network has no memory: direct first
	setNetInfo(netInfo{On: true, Validated: true, Kind: "cellular"})
	f.applied = nil
	f.script["direct"] = worksAfter(5 * time.Second)
	if r := pass(t, modeOpts{}); r != seenOK || strings.Join(f.applied, " ") != "direct/" {
		t.Fatalf("cellular pass %s, tried %v", r, f.applied)
	}
}

func TestAutoAllFailThenRetrySkipsDirect(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.script["direct"] = resetByCensor
	f.script["obfs4"] = never
	f.script["snowflake"] = never
	if r := pass(t, modeOpts{}); r != "exhausted" {
		t.Fatalf("pass ended %s", r)
	}
	if st := bridgeStatus(); st.Phase != "exhausted" || st.ErrorCode != "exhausted" {
		t.Fatalf("status %+v", st)
	}
	f.applied = nil
	pass(t, modeOpts{})
	for _, a := range f.applied {
		if strings.HasPrefix(a, "direct") {
			t.Fatalf("a retry tried direct where it was blocked: %v", f.applied)
		}
	}
	// the back-off: 15 minutes doubling to two hours
	if autoRetryGap(0) != 15*time.Minute || autoRetryGap(1) != 30*time.Minute || autoRetryGap(9) != 2*time.Hour {
		t.Fatal("retry gaps")
	}
	// thirty days on, direct gets a try again
	f.now = f.now.Add(31 * 24 * time.Hour)
	f.applied = nil
	pass(t, modeOpts{})
	if f.applied[0] != "direct/" {
		t.Fatalf("after 30 days: %v", f.applied)
	}
}

func TestAutoNetworkChangeMidAttempt(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.script["direct"] = never
	f.at(10*time.Second, func() { netEpoch.Add(1) })
	if r := pass(t, modeOpts{}); r != passInterrupted {
		t.Fatalf("pass ended %s", r)
	}
	if len(f.applied) != 1 || autoGateHeld() {
		t.Fatalf("tried %v, gate held %v", f.applied, autoGateHeld())
	}
	if m := memSnapshot(); len(m.Blocked) != 0 {
		t.Fatalf("an interrupted attempt was remembered: %+v", m)
	}
}

func TestAutoCheckInPauseMidAttempt(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.script["direct"] = never
	f.at(5*time.Second, func() { atomic.StoreInt32(&torPaused, 1) })
	if r := pass(t, modeOpts{}); r != passInterrupted {
		t.Fatalf("paused: %s", r)
	}
	atomic.StoreInt32(&torPaused, 0)
	f.at(20*time.Second, func() { checkIn(true) })
	if r := pass(t, modeOpts{}); r != passInterrupted {
		t.Fatalf("check-in: %s", r)
	}
	if why := autoIdleWhy(); why != "paused" {
		t.Fatalf("no pass may start in a check-in: %q", why)
	}
	if st := bridgeStatus(); st.Phase != "checkin" {
		t.Fatalf("status %+v", st)
	}
}

func TestAutoUnvalidatedEndsLimited(t *testing.T) {
	f := useFakeAuto(t, netInfo{On: true, Validated: false, Kind: "wifi"})
	f.script["direct"] = resetByCensor
	f.script["obfs4"] = worksAfter(20 * time.Second)
	if r := pass(t, modeOpts{Consent: "ask"}); r != seenOK {
		t.Fatalf("pass ended %s", r)
	}
	st := bridgeStatus()
	if !st.Limited || st.Blocked || st.Network != "limited" || st.Phase != "connected" {
		t.Fatalf("status %+v", st)
	}
	if st.ErrorCode == "no_internet" {
		t.Fatal("an unvalidated network said no internet")
	}
	// direct had its whole time before obfs4 was tried
	if f.now.Sub(t0Auto) < directLimit {
		t.Fatalf("direct cut short at %s", f.now.Sub(t0Auto))
	}
	if m := memSnapshot(); len(m.Blocked) != 0 {
		t.Fatal("limited was remembered as blocked")
	}
	if !st.AskConsent {
		t.Fatal("no consent asked for after direct ran out")
	}
}

func TestAutoNoNetworkIsIdle(t *testing.T) {
	f := useFakeAuto(t, netInfo{On: false, Kind: "wifi"})
	old := autoTick
	autoTick = time.Millisecond
	defer func() { autoTick = old }()
	if why := autoIdleWhy(); why != "no_internet" {
		t.Fatalf("idle why %q", why)
	}
	autoMu.Lock()
	autoGenN++
	bmMode = bmAuto
	gen := autoGenN
	autoMu.Unlock()
	done := make(chan struct{})
	go func() { autoLoop(gen); close(done) }()
	time.Sleep(50 * time.Millisecond)
	autoMu.Lock()
	autoGenN++
	autoMu.Unlock()
	<-done
	if len(f.applied) != 0 {
		t.Fatalf("tried %v with no network", f.applied)
	}
	if st := bridgeStatus(); st.Phase != "no_internet" || st.Network != "none" {
		t.Fatalf("status %+v", st)
	}
}

// a bridge that tor gets through is kept, whatever the relays do
func TestAutoKeepsBridgeWithSlowRelays(t *testing.T) {
	f := useFakeAuto(t, wifi())
	memBlocked("wifi", dayOf(f.now))
	f.script["obfs4"] = worksAfter(10 * time.Second)
	f.proven = false
	if r := pass(t, modeOpts{}); r != seenOK || f.applied[0] != "obfs4/builtin" {
		t.Fatalf("pass %s, tried %v", r, f.applied)
	}
	if st := bridgeStatus(); st.Phase != "connected" || st.CanSend {
		t.Fatalf("status %+v", st)
	}
}

func TestAutoFirstDialLateIsNotAFailure(t *testing.T) {
	f := useFakeAuto(t, wifi())
	memBlocked("wifi", dayOf(f.now))
	f.script["obfs4"] = func(a *attemptSeen, el time.Duration) {
		if el >= 140*time.Second && a.firstDial.IsZero() {
			a.firstDial = a.since.Add(el)
		}
		if el >= 170*time.Second {
			a.circ("BUILT", nil, a.since.Add(el))
		}
	}
	if r := pass(t, modeOpts{}); r != seenOK || len(f.applied) != 1 {
		t.Fatalf("pass %s, tried %v", r, f.applied)
	}
}

func TestAutoMoatConsent(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.script["direct"] = resetByCensor
	f.script["obfs4"] = never
	f.script["snowflake"] = never
	f.script["webtunnel"] = worksAfter(5 * time.Second)
	wt := webtunnelLine(t)
	f.moatOut = []moatSetting{{Type: "webtunnel", Source: "bridgedb", Lines: []string{wt}}}

	// ask: the sheet is raised, moat is not called
	pass(t, modeOpts{Consent: "ask"})
	if len(f.moatOpts) != 0 || !bridgeStatus().AskConsent {
		t.Fatalf("ask: moat calls %d, status %+v", len(f.moatOpts), bridgeStatus())
	}
	// yes: over meek, marked automatic, never plain
	resetAuto(t)
	setNetInfo(wifi())
	f.applied = nil
	if r := pass(t, modeOpts{Consent: "yes", Country: "ir"}); r != seenOK {
		t.Fatalf("pass with moat: %s, tried %v", r, f.applied)
	}
	if len(f.moatOpts) != 1 {
		t.Fatalf("moat calls %d", len(f.moatOpts))
	}
	o := f.moatOpts[0]
	if !o.Consent || !o.Automatic || o.Via != viaMeek || o.Country != "ir" {
		t.Fatalf("moat opts %+v", o)
	}
	if got := strings.Join(f.applied, " "); got != "direct/ webtunnel/moat" {
		t.Fatalf("tried %s", got)
	}
	// the week's settings are used without asking again
	f.applied = nil
	memMu.Lock()
	autoMem = autoMemory{V: 1}
	autoMem.Blocked = map[string]int64{"wifi": dayOf(f.now)}
	memMu.Unlock()
	pass(t, modeOpts{Consent: "yes"})
	if len(f.moatOpts) != 1 || f.applied[0] != "webtunnel/moat" {
		t.Fatalf("asked again: %d, tried %v", len(f.moatOpts), f.applied)
	}
}

// consent given while the pass is past the ask: moat comes next
func TestAutoConsentMidPass(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.script["direct"] = resetByCensor
	f.script["obfs4"] = never
	f.script["snowflake"] = never
	f.script["webtunnel"] = worksAfter(time.Second)
	f.moatOut = []moatSetting{{Type: "webtunnel", Source: "bridgedb", Lines: []string{webtunnelLine(t)}}}
	f.at(70*time.Second, func() {
		autoMu.Lock()
		bmOpts.Consent = "yes"
		autoMu.Unlock()
	})
	if r := pass(t, modeOpts{Consent: "ask"}); r != seenOK {
		t.Fatalf("pass %s, tried %v", r, f.applied)
	}
	if got := strings.Join(f.applied, " "); got != "direct/ obfs4/builtin webtunnel/moat" {
		t.Fatalf("tried %s", got)
	}
}

// with the stand-in moat: consent off sends nothing at all, consent on
// goes over meek and never plain
func TestAutoMoatOverTheWire(t *testing.T) {
	moat, meek := useMoatStandIns(t)
	plain := 0
	moatTransport = func(via string, d *moatDials) (*http.Transport, error) {
		if via == viaPlain {
			plain++
		}
		return moatTransportFor(via, d)
	}
	f := useFakeAuto(t, wifi())
	autoW.moat = liveWorld().moat
	f.script["direct"] = resetByCensor
	pass(t, modeOpts{Consent: "no"})
	pass(t, modeOpts{Consent: "ask"})
	if moat.hits.Load() != 0 || meek.hits.Load() != 0 {
		t.Fatalf("moat reached without consent: %d %d", moat.hits.Load(), meek.hits.Load())
	}
	pass(t, modeOpts{Consent: "yes"})
	if meek.hits.Load() == 0 || plain != 0 {
		t.Fatalf("meek %d plain %d", meek.hits.Load(), plain)
	}
}

func TestAutoSetconfNeverAnswers(t *testing.T) {
	oldD, oldW := ctrlDeadline, autoSetconfWait
	ctrlDeadline, autoSetconfWait = 5*time.Second, 300*time.Millisecond
	defer func() { ctrlDeadline, autoSetconfWait = oldD, oldW }()
	fc := newFakeControl(t, 100)
	fc.slow.Store(int64(3 * time.Second))
	fakeTor(t, fc.port())
	resetRoute(t, "publishing", 100)
	oldSettle := bounceSettle
	bounceSettle = time.Millisecond
	defer func() { bounceSettle = oldSettle }()

	f := useFakeAuto(t, wifi())
	memBlocked("wifi", dayOf(f.now))
	live := liveWorld()
	tried := []string{}
	autoW.apply = func(s autoStep) string {
		tried = append(tried, s.Method)
		return live.apply(s)
	}
	f.script["snowflake"] = worksAfter(time.Second)
	t0 := time.Now()
	r := pass(t, modeOpts{})
	took := time.Since(t0)
	// wait out the reconnects left behind, so the next test finds the slot free
	time.Sleep(8 * time.Second)
	if took > 3*time.Second {
		t.Fatalf("an attempt waited %s on a SETCONF that never answered", took)
	}
	if len(tried) < 2 || tried[0] != "obfs4" {
		t.Fatalf("tried %v, result %s", tried, r)
	}
}

func TestBounceGate(t *testing.T) {
	f := useFakeAuto(t, wifi())
	fc := newFakeControl(t, 100)
	fakeTor(t, fc.port())
	resetRoute(t, "publishing", 100)
	oldSettle := bounceSettle
	bounceSettle = time.Millisecond
	defer func() { bounceSettle = oldSettle }()

	gateHold(autoGen(), time.Minute)
	for name, bounce := range map[string]func() string{
		"route rescue":   reconnectTor,
		"relay watchdog": reconnectTor,
		"manual":         reconnectNow,
		"net bounce":     netReconnect,
	} {
		if r := bounce(); r != "error: automatic is connecting" {
			t.Errorf("%s during an attempt: %s", name, r)
		}
	}
	// the mode switch back to onion goes through reconnectTor too
	transportMode.Store(modeFast)
	if r := setTransportMode(modePrivate); r != modePrivate {
		t.Fatalf("mode %s", r)
	}
	time.Sleep(50 * time.Millisecond)
	if n := len(fc.sent()); n != 0 {
		t.Fatalf("a bounce got through the gate: %v", fc.sent())
	}
	// a rescue is not even counted
	failAll(time.Now().Add(-time.Hour), "wss://a", "wss://b")
	if why := routeNeedsRescue(time.Now()); why != "" {
		t.Fatalf("rescue during an attempt: %s", why)
	}
	// automatic's own goes through
	if r := reconnectAuto(); r != "ok" {
		t.Fatalf("automatic's bounce: %s", r)
	}
	// the lifetime cap lets the rescues back in
	f.now = f.now.Add(time.Minute + autoGateSlack + time.Second)
	if autoGateHeld() {
		t.Fatal("the gate outlived its cap")
	}
	atomic.StoreInt64(&lastTorRestart, 0)
	if r := reconnectTor(); r != "ok" {
		t.Fatalf("after the cap: %s", r)
	}
}

func TestCheckInPrefersObfs4OverSnowflake(t *testing.T) {
	f := useFakeAuto(t, wifi())
	today := dayOf(f.now)
	memRemember("wifi", autoStep{Method: "obfs4", Source: "builtin"}, today-3)
	memRemember("wifi", autoStep{Method: "snowflake", Source: "builtin"}, today)
	s, ok := checkInStep("wifi", memSnapshot(), modeOpts{}, today)
	if !ok || s.Method != "obfs4" || len(s.Lines) == 0 {
		t.Fatalf("check-in uses %+v", s)
	}
	// snowflake alone: snowflake
	memMu.Lock()
	delete(autoMem.Worked["wifi"], "obfs4")
	memMu.Unlock()
	if s, _ := checkInStep("wifi", memSnapshot(), modeOpts{}, today); s.Method != "snowflake" {
		t.Fatalf("check-in uses %+v", s)
	}
	// the check-in puts its lines in place while tor sleeps
	autoMu.Lock()
	autoGenN++
	bmMode = bmAuto
	autoMu.Unlock()
	checkIn(true)
	if !bridgesEnabled() || linesMethod() != "snowflake" {
		t.Fatalf("lines in place: %v", bridgeLines())
	}
	checkIn(false)
}

func TestAutoMemoryRoundTrip(t *testing.T) {
	f := useFakeAuto(t, wifi())
	today := dayOf(f.now)
	memRemember("wifi", autoStep{Method: "snowflake", Source: "builtin"}, today)
	memRemember("cellular", autoStep{Method: "direct"}, today-40)
	memBlocked("wifi", today-2)
	out := autoMemoryJSON()
	if strings.Contains(out, "cellular") || !strings.Contains(out, `"wifi"`) {
		t.Fatalf("stale kept or fresh lost: %s", out)
	}
	for _, ln := range builtinLines("snowflake") {
		if strings.Contains(out, strings.Fields(ln)[1]) {
			t.Fatal("a line went into the store")
		}
	}
	resetAuto(t)
	memIn(out, today)
	if m := memSnapshot(); m.Last["wifi"].Method != "snowflake" || m.Blocked["wifi"] != today-2 {
		t.Fatalf("back in: %+v", m)
	}
	// junk is dropped on the way in
	memIn(`{"v":1,"last":{"wifi":{"m":"telnet","d":1},"home-ssid":{"m":"direct","d":`+itoa(today)+`}},"blocked":{"moon":`+itoa(today)+`}}`, today)
	if m := memSnapshot(); len(m.Last) != 0 || len(m.Blocked) != 0 {
		t.Fatalf("junk kept: %+v", m)
	}
	decoyState.Store(decoyOn)
	if r := autoMemoryJSON(); !strings.Contains(r, "decoy") {
		t.Fatalf("memory handed out in a decoy: %s", r)
	}
}

func itoa(n int64) string { b, _ := json.Marshal(n); return string(b) }

// a decoy sees automatic, no method and no memory, and changes nothing
func TestDecoyStatus(t *testing.T) {
	f := useFakeAuto(t, wifi())
	memBlocked("wifi", dayOf(f.now))
	f.script["obfs4"] = worksAfter(time.Second)
	pass(t, modeOpts{})
	decoyState.Store(decoyOn)
	st := bridgeStatus()
	if st.Mode != bmAuto || st.Method != "" || st.Source != "" || st.LastOK != "" || st.Phase != "connected" {
		t.Fatalf("decoy status %+v", st)
	}
	if r := setBridgeMode(bmDirect, ""); r != "error: decoy" {
		t.Fatalf("a decoy changed the mode: %s", r)
	}
	if m, _, _ := bridgeMode(); m != bmAuto || !bridgesEnabled() {
		t.Fatal("the real method stopped under a decoy")
	}
}

// the status names a method and nothing of its lines
func TestBridgeStatusIsPlain(t *testing.T) {
	useFakeAuto(t, wifi())
	lines := append(builtinLines("obfs4"), webtunnelLine(t))
	if r := setBridgeMode(bmOwn, `{"lines":`+mustJSON(lines)+`}`); r != "ok" {
		t.Fatalf("own: %s", r)
	}
	b, _ := json.Marshal(bridgeStatus())
	for _, ln := range lines {
		bl, _ := parseBridgeLine(ln)
		host := bl.addr[:strings.LastIndex(bl.addr, ":")]
		if strings.Contains(string(b), host) || strings.Contains(string(b), bl.fp) {
			t.Fatalf("status names a bridge: %s", b)
		}
	}
	if !strings.Contains(string(b), `"method":"obfs4"`) || !strings.Contains(string(b), `"source":"own"`) {
		t.Fatalf("status %s", b)
	}
	if r := setBridgeMode(bmWebtunnel, `{"lines":["obfs4 1.2.3.4:1 x"]}`); r != "error: lines_bad" {
		t.Fatalf("webtunnel with no webtunnel line: %s", r)
	}
}

func mustJSON(v any) string { b, _ := json.Marshal(v); return string(b) }

func webtunnelLine(t *testing.T) string {
	t.Helper()
	ln := "webtunnel [2001:db8::7]:443 " + strings.Repeat("AB", 20) + " url=https://example.com/x7 ver=0.0.1"
	if _, err := checkBridgeLine(ln); err != nil {
		t.Fatalf("webtunnel line: %v", err)
	}
	return ln
}
