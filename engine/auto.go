// SPDX-License-Identifier: GPL-3.0-or-later
package main

// automatic bridges. tor is tried the usual way first; when tor's own
// signals say the network cuts it off, a disguise is tried, one at a time,
// each with its own time, and the first that carries tor traffic is kept
// and remembered for this type of network. while a pass runs it owns
// every bounce: the gate in reconnectTorBy refuses the rescues, the
// network bounce and manual restarts, for one pass plus two minutes at
// most.
//
// order: what worked here last, direct, the tor project's advice (only
// with consent, only through meek, never plain), built-in obfs4, built-in
// snowflake, webtunnel lines the app keeps. direct is skipped on a network
// type where it was blocked in the last 30 days.

import "C"

import (
	"encoding/json"
	"log"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/cretz/bine/control"
)

// the bridge modes the app picks from. legacy is none picked yet.
const (
	bmLegacy    = ""
	bmAuto      = "auto"
	bmDirect    = "direct"
	bmSnowflake = "snowflake"
	bmWebtunnel = "webtunnel"
	bmMoat      = "moat"
	bmOwn       = "own"
)

// what the app passes with a mode
type modeOpts struct {
	// asking the tor project in automatic: yes, no, or ask, which raises
	// ask_consent the first time tor is found blocked
	Consent string `json:"consent,omitempty"`
	// the person said tor is risky here: automatic never tries direct
	SkipDirect bool `json:"skip_direct,omitempty"`
	// two letters for moat, from the picker
	Country string `json:"country,omitempty"`
	// the lines of a webtunnel, moat or own mode
	Lines []string `json:"lines,omitempty"`
	// webtunnel lines the app keeps, for automatic's last step
	Webtunnel []string `json:"webtunnel,omitempty"`
}

var (
	autoMu   sync.Mutex
	bmMode   = bmLegacy
	bmOpts   modeOpts
	autoGenN int64 // bumped on every mode change: a pass of an older one stops
)

func bridgeMode() (string, modeOpts, int64) {
	autoMu.Lock()
	defer autoMu.Unlock()
	return bmMode, bmOpts, autoGenN
}

func autoGen() int64 {
	autoMu.Lock()
	defer autoMu.Unlock()
	return autoGenN
}

// ---- memory: what worked on which type of network, per day ----

const memDays = 30

type autoUse struct {
	Method string `json:"m"`
	Source string `json:"s,omitempty"`
	Day    int64  `json:"d"`
}

type autoMemory struct {
	V int `json:"v"`
	// network type -> the last method that worked there
	Last map[string]autoUse `json:"last,omitempty"`
	// network type -> method -> when it last worked
	Worked map[string]map[string]autoUse `json:"worked,omitempty"`
	// network type -> the day direct was last found blocked there
	Blocked map[string]int64 `json:"blocked,omitempty"`
}

var (
	memMu   sync.Mutex
	autoMem = autoMemory{V: 1}
)

// today-day would wrap for a day far enough back
func fresh(day, today int64) bool { return day <= today && day > today-memDays }

func memSnapshot() autoMemory {
	memMu.Lock()
	defer memMu.Unlock()
	b, _ := json.Marshal(autoMem)
	var m autoMemory
	_ = json.Unmarshal(b, &m)
	return m
}

func memRemember(kind string, s autoStep, today int64) {
	memMu.Lock()
	defer memMu.Unlock()
	u := autoUse{Method: s.Method, Source: s.Source, Day: today}
	if autoMem.Last == nil {
		autoMem.Last = map[string]autoUse{}
	}
	if autoMem.Worked == nil {
		autoMem.Worked = map[string]map[string]autoUse{}
	}
	if autoMem.Worked[kind] == nil {
		autoMem.Worked[kind] = map[string]autoUse{}
	}
	autoMem.Last[kind] = u
	autoMem.Worked[kind][s.Method] = u
	if s.Method == "direct" {
		delete(autoMem.Blocked, kind)
	}
}

// a method that did not get through here is no longer one that worked
func memForget(kind, method string) {
	memMu.Lock()
	defer memMu.Unlock()
	delete(autoMem.Worked[kind], method)
	if u, ok := autoMem.Last[kind]; ok && u.Method == method {
		delete(autoMem.Last, kind)
	}
}

func memBlocked(kind string, today int64) {
	memMu.Lock()
	defer memMu.Unlock()
	if autoMem.Blocked == nil {
		autoMem.Blocked = map[string]int64{}
	}
	autoMem.Blocked[kind] = today
}

// what the store gets, without anything stale. days only, network types
// only: no names, no times of day, no lines.
func memOut(today int64) autoMemory {
	m := memSnapshot()
	for k, u := range m.Last {
		if !fresh(u.Day, today) {
			delete(m.Last, k)
		}
	}
	for k, w := range m.Worked {
		for meth, u := range w {
			if !fresh(u.Day, today) {
				delete(w, meth)
			}
		}
		if len(w) == 0 {
			delete(m.Worked, k)
		}
	}
	for k, d := range m.Blocked {
		if !fresh(d, today) {
			delete(m.Blocked, k)
		}
	}
	m.V = 1
	return m
}

var autoMethods = map[string]bool{"direct": true, "obfs4": true, "snowflake": true, "webtunnel": true}
var autoSources = map[string]bool{"": true, "builtin": true, "moat": true, "cached": true}

func memIn(s string, today int64) {
	var m autoMemory
	if json.Unmarshal([]byte(s), &m) != nil || m.V != 1 {
		return
	}
	ok := func(u autoUse) bool {
		return autoMethods[u.Method] && autoSources[u.Source] && fresh(u.Day, today)
	}
	clean := autoMemory{V: 1, Last: map[string]autoUse{}, Worked: map[string]map[string]autoUse{}, Blocked: map[string]int64{}}
	for k, u := range m.Last {
		if netKinds[k] && ok(u) {
			clean.Last[k] = u
		}
	}
	for k, w := range m.Worked {
		if !netKinds[k] {
			continue
		}
		for meth, u := range w {
			if meth == u.Method && ok(u) {
				if clean.Worked[k] == nil {
					clean.Worked[k] = map[string]autoUse{}
				}
				clean.Worked[k][meth] = u
			}
		}
	}
	for k, d := range m.Blocked {
		if netKinds[k] && fresh(d, today) {
			clean.Blocked[k] = d
		}
	}
	memMu.Lock()
	autoMem = clean
	memMu.Unlock()
}

// ---- the plan for one pass ----

type autoStep struct {
	Method string // direct, obfs4, snowflake, webtunnel, or moat for the ask
	Source string // builtin, moat, cached; empty for direct
	Lines  []string
	Limit  time.Duration
}

// per transport, from the first dial
var methodLimit = map[string]time.Duration{
	"obfs4":     45 * time.Second,
	"webtunnel": 90 * time.Second,
	"snowflake": 150 * time.Second,
}

// what worked here before gets less time, but snowflake needs its own
var lastLimit = 60 * time.Second

func stepLimit(method string, last bool) time.Duration {
	if method == "direct" {
		return directLimit
	}
	if last && method != "snowflake" {
		return lastLimit
	}
	return methodLimit[method]
}

// the lines for a remembered method, or none when they are gone
func linesFor(u autoUse, opts modeOpts) []string {
	switch {
	case u.Method == "direct":
		return nil
	case u.Source == "builtin":
		return builtinLines(u.Method)
	case u.Source == "moat":
		for _, s := range moatSettingsCached() {
			if s.Type == u.Method && s.Source == "bridgedb" {
				return s.Lines
			}
		}
	case u.Source == "cached" && u.Method == "webtunnel":
		good, _, _ := sortBridgeLines(strings.Join(opts.Webtunnel, "\n"))
		return good
	}
	return nil
}

func sameStep(a, b autoStep) bool { return a.Method == b.Method && a.Source == b.Source }

func planPass(kind string, mem autoMemory, opts modeOpts, today int64) []autoStep {
	var steps []autoStep
	add := func(s autoStep) {
		for _, o := range steps {
			if sameStep(o, s) {
				return
			}
		}
		steps = append(steps, s)
	}
	directBlocked := false
	if d, ok := mem.Blocked[kind]; ok && fresh(d, today) {
		directBlocked = true
	}
	skipDirect := directBlocked || opts.SkipDirect
	if u, ok := mem.Last[kind]; ok && fresh(u.Day, today) {
		lines := linesFor(u, opts)
		switch {
		case u.Method == "direct" && !skipDirect:
			add(autoStep{Method: "direct", Limit: directLimit})
		case u.Method != "direct" && len(lines) > 0:
			add(autoStep{Method: u.Method, Source: u.Source, Lines: lines, Limit: stepLimit(u.Method, true)})
		}
	}
	if !skipDirect {
		add(autoStep{Method: "direct", Limit: directLimit})
	}
	add(autoStep{Method: "moat"})
	for _, t := range []string{"obfs4", "snowflake"} {
		if lines := builtinLines(t); len(lines) > 0 {
			add(autoStep{Method: t, Source: "builtin", Lines: lines, Limit: stepLimit(t, false)})
		}
	}
	if lines := linesFor(autoUse{Method: "webtunnel", Source: "cached"}, opts); len(lines) > 0 {
		add(autoStep{Method: "webtunnel", Source: "cached", Lines: lines, Limit: stepLimit("webtunnel", false)})
	}
	return steps
}

// the steps moat's settings give, in its order
func moatSteps(settings []moatSetting) []autoStep {
	var out []autoStep
	for _, s := range settings {
		src := "moat"
		if s.Source == "builtin" {
			src = "builtin"
		}
		if len(s.Lines) == 0 || methodLimit[s.Type] == 0 {
			continue
		}
		out = append(out, autoStep{Method: s.Type, Source: src, Lines: s.Lines, Limit: stepLimit(s.Type, false)})
	}
	return out
}

// how many attempts a plan holds; the ask of moat is none
func attemptCount(steps []autoStep) int {
	n := 0
	for _, s := range steps {
		if s.Method != "moat" {
			n++
		}
	}
	return n
}

// the longest one step can take
func stepBudget(s autoStep) time.Duration {
	switch s.Method {
	case "moat":
		return moatTimeout + 15*time.Second
	case "direct":
		return attemptCap + autoSetconfWait
	}
	return firstDialWait + attemptCap + autoSetconfWait
}

func passBudget(steps []autoStep) time.Duration {
	var d time.Duration
	for _, s := range steps {
		d += stepBudget(s)
	}
	return d
}

// ---- the gate ----

// a pass may hold every other bounce off for this long past its budget
var autoGateSlack = 2 * time.Minute

var autoGate struct {
	sync.Mutex
	held  bool
	until time.Time
	id    int64 // the pass that holds it
	next  int64
}

// takes the gate for a pass of this mode, unless a newer mode took over.
// the pass's id, 0 when refused.
func gateHold(gen int64, budget time.Duration) int64 {
	autoMu.Lock()
	defer autoMu.Unlock()
	if autoGenN != gen {
		return 0
	}
	autoGate.Lock()
	defer autoGate.Unlock()
	autoGate.next++
	autoGate.held, autoGate.until, autoGate.id = true, autoNow().Add(budget+autoGateSlack), autoGate.next
	return autoGate.id
}

func gateExtend(id int64, d time.Duration) {
	autoGate.Lock()
	if autoGate.held && autoGate.id == id {
		autoGate.until = autoGate.until.Add(d)
	}
	autoGate.Unlock()
}

// a pass gives the gate back, unless a newer one holds it by now
func gateRelease(id int64) {
	autoGate.Lock()
	if autoGate.id == id {
		autoGate.held = false
	}
	autoGate.Unlock()
}

// a mode change takes the gate from whichever pass has it
func gateDrop() {
	autoGate.Lock()
	autoGate.held = false
	autoGate.Unlock()
}

// whether this pass still holds the gate and is inside its cap
func gateOwned(id int64) bool {
	autoGate.Lock()
	defer autoGate.Unlock()
	return autoGate.held && autoGate.id == id && !autoNow().After(autoGate.until)
}

// true while a pass owns the bounces. a pass past its cap owns nothing,
// so a stuck one cannot keep every rescue away.
func autoGateHeld() bool {
	autoGate.Lock()
	defer autoGate.Unlock()
	if !autoGate.held {
		return false
	}
	if autoNow().After(autoGate.until) {
		log.Println("auto: past its cap, the rescues may bounce again")
		autoGate.held = false
		return false
	}
	return true
}

// ---- what the status line reads ----

var autoSt struct {
	sync.Mutex
	phase      string
	method     string
	source     string
	since      time.Time
	blocked    bool
	limited    bool
	errCode    string
	askConsent bool
	// which attempt of the pass this is, from 1, and how many it plans
	attempt  int
	attempts int
}

func stSet(f func()) {
	autoSt.Lock()
	f()
	autoSt.Unlock()
}

// ---- the world a pass acts on, swapped out by the tests ----

var (
	autoNow   = time.Now
	autoSleep = time.Sleep
	// how often an attempt looks at tor
	autoPoll = time.Second
	// how long tor may take to answer the SETCONF of a switch before the
	// attempt counts as failed
	autoSetconfWait = 20 * time.Second
)

type autoWorld struct {
	started func() bool
	// tor holds a built circuit since its last bounce, on this network
	settled func() bool
	apply   func(s autoStep) string
	open    func() *attemptSeen
	poll    func(a *attemptSeen, s autoStep)
	close   func()
	proven  func(gen int64) bool
	moat    func(o moatOpts) ([]moatSetting, error)
	// tor itself can build a circuit, whatever the relays do
	torUp func() bool
}

var autoW = liveWorld()

// sets the lines a step needs, unless a newer mode took over: whether
// they are in place, and whether they changed
func autoUseLines(gen int64, lines []string) (bool, bool) {
	autoMu.Lock()
	defer autoMu.Unlock()
	if autoGenN != gen {
		return false, false
	}
	return true, useLines(lines)
}

// a step's lines, and whether it is automatic's own direct step, in one
// go under the mode's lock: a new mode can never land between the two
func autoUseStep(gen int64, s autoStep) (bool, bool) {
	autoMu.Lock()
	defer autoMu.Unlock()
	if autoGenN != gen {
		return false, false
	}
	changed := useLines(s.Lines)
	if h := autoStepHook; h != nil {
		h()
	}
	autoDirectOK.Store(s.Method == "direct")
	return true, changed
}

// called between a step's lines and its direct mark, for the tests
var autoStepHook func()

// puts a set of lines in place, or none for direct. the same set again
// changes nothing. true when something changed.
func useLines(lines []string) bool {
	if h := useLinesHook; h != nil {
		h()
	}
	good, _, _ := sortBridgeLines(strings.Join(lines, "\n"))
	on := len(good) > 0
	bridgeMu.Lock()
	same := on == bridgeOn && strings.Join(good, "\n") == strings.Join(bridgeList, "\n")
	if !same {
		bridgeList, bridgeOn = good, on
		bridgeFails = map[string]bridgeFail{}
	}
	bridgeMu.Unlock()
	if same {
		return false
	}
	noteLinesChanged()
	noteBridgeSecrets(good)
	dropSnowflakeClients()
	if on {
		_ = startPTListeners()
	}
	return true
}

func torStarted() bool {
	mu.Lock()
	defer mu.Unlock()
	return torNode != nil && torNode.Control != nil
}

// what the last bounce's bridge SETCONF said, "" when it took
var bridgeConfErr atomic.Value

// the network change the last bounce happened on
var bounceEpoch atomic.Int64

// tor's own word on whether it has built a circuit. DisableNetwork clears
// it, so after a bounce it speaks of the network that came back.
func circuitEstablished() bool {
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil || t.Control == nil {
		return false
	}
	var kv []*control.KeyVal
	err := ctrlDo(t, "GETINFO circuit-established", func(c *control.Conn) error {
		var gerr error
		kv, gerr = c.GetInfo("status/circuit-established")
		return gerr
	})
	return err == nil && len(kv) > 0 && strings.TrimSpace(kv[0].Val) == "1"
}

// the steps of a reconnect after tor has its config
var bounceTookConfig = map[string]bool{"network on": true, "watchers": true}

func liveWorld() autoWorld {
	return autoWorld{
		started: torStarted,
		settled: func() bool {
			return bounceEpoch.Load() == netEpoch.Load() && circuitEstablished()
		},
		apply: func(s autoStep) string {
			done := make(chan string, 1)
			go func() { done <- reconnectAuto() }()
			conf := func() string {
				if e, _ := bridgeConfErr.Load().(string); e != "" {
					return "error: " + e
				}
				return "ok"
			}
			select {
			case r := <-done:
				if r != "ok" {
					return r
				}
				return conf()
			case <-time.After(autoSetconfWait):
				// tor took the config and the rest is slow: not a failure
				if bounceTookConfig[lastReconnectStep()] {
					return conf()
				}
				return "error: tor did not take the change in time"
			}
		},
		open: func() *attemptSeen {
			mu.Lock()
			t := torNode
			mu.Unlock()
			return obsOpen(t, autoNow())
		},
		poll:   livePoll,
		close:  obsClose,
		proven: func(gen int64) bool { return routeProven() && routeGeneration() == gen },
		moat: func(o moatOpts) ([]moatSetting, error) {
			out, err := moatSettingsCall(o)
			if err == nil && len(out.Settings) == 0 {
				d, derr := moatDefaultsCall(o)
				out, err = d, derr
			}
			return out.Settings, err
		},
		torUp: circuitEstablished,
	}
}

func livePoll(a *attemptSeen, s autoStep) {
	mu.Lock()
	t := torNode
	mu.Unlock()
	p, ok := readBootPhase(t)
	obsMu.Lock()
	armed := a.armed
	obsMu.Unlock()
	// a circuit event can be missed; tor's own flag cannot
	circ := armed && circuitEstablished()
	now := autoNow()
	obsMu.Lock()
	defer obsMu.Unlock()
	if ok {
		a.bootstrap(p, !torWasUp(t), now)
	}
	if circ {
		a.circ("BUILT", nil, now)
	}
	if s.Method == "direct" {
		return
	}
	if r := ptReg(s.Method); r != nil && a.firstDial.IsZero() {
		if last := r.lastReq.Load(); last > a.since.UnixNano() {
			a.firstDial = time.Unix(0, last)
		}
	}
	dead := len(s.Lines) > 0
	for _, ln := range s.Lines {
		b, err := parseBridgeLine(ln)
		if err != nil || !bridgeIsDead(b.transport+" "+bridgeAddrKey(b.addr)) {
			dead = false
			break
		}
	}
	a.allDead = dead
	if s.Method == "snowflake" {
		noteSnowflake(a)
	}
}

// snowflake getting further than before counts as progress, and nothing else
func noteSnowflake(a *attemptSeen) {
	if _, at := snowflakeForward(); at.After(a.since) {
		a.sfMoved = at
	}
}

// ---- one pass ----

const passInterrupted = "interrupted"

// a check-in window: tor is up for a minute in the background, and no pass
// starts in it. it ends on its own if the app never says.
var (
	checkInMu    sync.Mutex
	checkInUntil time.Time
)

var checkInMax = 10 * time.Minute

func inCheckIn() bool {
	checkInMu.Lock()
	defer checkInMu.Unlock()
	return !checkInUntil.IsZero() && autoNow().Before(checkInUntil)
}

// why a pass cannot run now, or "". behind a captive portal nothing gets
// out until someone signs in, so nothing is tried and nothing is learned.
func autoIdleWhy() string {
	switch {
	case !modeNeedsTor():
		return "not_tor_mode"
	case torIsPaused(), inCheckIn():
		return "paused"
	case !currentNet().On:
		return "no_internet"
	case currentNet().Limited:
		return "captive"
	}
	return ""
}

// behind a portal no pass runs, but tor keeps the way that worked on this
// type of network, so a sign-in, or a portal android only thinks is there,
// finds it in place. nothing known here: tor waits for the sign-in
func captiveWay(gen int64) {
	if networkHold() != errAutoWait {
		return
	}
	_, opts, _ := bridgeMode()
	s, ok := checkInStep(currentNet().Kind, memSnapshot(), opts, dayOf(autoNow()))
	if !ok {
		return
	}
	if ok, _ := autoUseStep(gen, s); !ok {
		return
	}
	stSet(func() { autoSt.method, autoSt.source = s.Method, s.Source })
	log.Printf("auto: behind a portal, keeping %s in place", s.Method)
	if torStarted() && !torIsPaused() {
		go captiveBounce()
	}
}

// vars for the tests
var (
	captiveBounce = func() { _ = reconnectAuto() }
	holdBounce    = func() { _ = reconnectNowFor(whyAuto) }
)

// one pass and what it began with
type passCtx struct {
	gen   int64
	epoch int64
	id    int64 // its hold on the gate
	valid int64 // the validation flips it began with
}

func autoInterrupted(p passCtx) string {
	if autoGen() != p.gen {
		return "stopped"
	}
	if why := autoIdleWhy(); why != "" {
		return why
	}
	if netEpoch.Load() != p.epoch {
		return "network"
	}
	if autoValidFlips.Load() != p.valid {
		return "validated"
	}
	if p.id != 0 && !gateOwned(p.id) {
		return "capped"
	}
	return ""
}

func consentNow() string {
	_, o, _ := bridgeMode()
	return o.Consent
}

func runPass(gen, epoch int64, why string) string {
	n := currentNet()
	kind := n.Kind
	_, opts, _ := bridgeMode()
	today := dayOf(autoNow())
	steps := planPass(kind, memSnapshot(), opts, today)
	// counted as the status line counts them: the ask of moat is no way in
	log.Printf("auto: pass (%s) on %s, %d ways to try", why, kind, attemptCount(steps))
	p := passCtx{gen: gen, epoch: epoch, valid: autoValidFlips.Load()}
	if p.id = gateHold(gen, passBudget(steps)); p.id == 0 {
		return passInterrupted
	}
	defer gateRelease(p.id)
	r := runSteps(p, kind, n.Validated, opts, steps, today)
	if r == passInterrupted && !gateOwned(p.id) && autoGen() == gen {
		log.Println("auto: the pass ran past its cap")
		stSet(func() {
			autoSt.phase, autoSt.method, autoSt.source = "exhausted", "", ""
			autoSt.errCode = "exhausted"
		})
		return "exhausted"
	}
	return r
}

func runSteps(p passCtx, kind string, validated bool, opts modeOpts, steps []autoStep, today int64) string {
	stSet(func() {
		autoSt.blocked, autoSt.limited, autoSt.errCode, autoSt.askConsent = false, false, "", false
		autoSt.attempt, autoSt.attempts = 0, attemptCount(steps)
	})
	moatDone, moatAt := false, -1
	// direct was found blocked here lately, or ran out on a network
	// android could not check: either way tor did not get through as is
	blocked := false
	if d, ok := memSnapshot().Blocked[kind]; ok && fresh(d, today) {
		blocked = true
		stSet(func() { autoSt.blocked = true })
	}
	for i := 0; i < len(steps); i++ {
		s := steps[i]
		if s.Method == "moat" {
			moatAt = i
			if !moatDone && consentNow() == "yes" {
				moatDone = true
				// tor still out on its own while direct is not welcome, failed
				// or never in this pass: off the network before the tor
				// project is asked
				if torStarted() && !torIsPaused() && !bridgesEnabled() && !autoDirectOK.Load() {
					autoDirectOK.Store(false)
					_ = reconnectAuto()
				}
				extra, r := autoAskMoat(p, opts)
				if r != "" {
					return r
				}
				steps = spliceMoat(steps, i, extra)
				gateExtend(p.id, passBudget(extra))
				stSet(func() { autoSt.attempts = autoSt.attempt + attemptCount(steps[i+1:]) })
			} else if consentNow() == "ask" && blocked && !netValveOpen.Load() {
				stSet(func() { autoSt.askConsent = true })
			}
			continue
		}
		stSet(func() { autoSt.attempt++ })
		v := runAttempt(p, s, validated)
		// direct that did not get through is no longer welcome out
		if s.Method == "direct" && v != seenOK {
			autoDirectOK.Store(false)
		}
		switch v {
		case seenOK:
			memRemember(kind, s, dayOf(autoNow()))
			// through: there is nothing left to ask the tor project for
			stSet(func() {
				autoSt.phase, autoSt.method, autoSt.source = "connected", s.Method, s.Source
				autoSt.errCode, autoSt.askConsent = "", false
			})
			log.Printf("auto: %s gets through", s.Method)
			return seenOK
		case seenBlocked:
			// with no network said to be there, nothing is learned of it
			if s.Method == "direct" && !netValveOpen.Load() {
				blocked = true
				memBlocked(kind, dayOf(autoNow()))
				stSet(func() { autoSt.blocked, autoSt.errCode = true, "blocked" })
				if consentNow() == "ask" {
					stSet(func() { autoSt.askConsent = true })
				}
			}
		case seenLimited:
			blocked = true
			stSet(func() { autoSt.limited, autoSt.errCode = true, "limited" })
			if consentNow() == "ask" && !netValveOpen.Load() {
				stSet(func() { autoSt.askConsent = true })
			}
		case passInterrupted:
			return passInterrupted
		}
		// a bridge that did not get through here is not one to check in by
		if v == seenFailed && s.Method != "direct" && !netValveOpen.Load() {
			memForget(kind, s.Method)
		}
		// consent came while this pass was past the ask: ask now
		if !moatDone && moatAt >= 0 && moatAt < i && consentNow() == "yes" {
			steps = append(steps[:i+1], append([]autoStep{{Method: "moat"}}, steps[i+1:]...)...)
			gateExtend(p.id, stepBudget(autoStep{Method: "moat"}))
		}
	}
	stSet(func() {
		autoSt.phase, autoSt.method, autoSt.source = "exhausted", "", ""
		autoSt.errCode = "exhausted"
	})
	log.Println("auto: nothing got through")
	return "exhausted"
}

// moat's settings, from the week's cache or asked for over meek. the
// plain path is never taken here: moatGate refuses it for automatic.
func autoAskMoat(p passCtx, opts modeOpts) ([]autoStep, string) {
	if s := moatSettingsCached(); len(s) > 0 {
		return moatSteps(s), ""
	}
	stSet(func() { autoSt.phase, autoSt.method, autoSt.source, autoSt.since = "asking", "", "", autoNow() })
	type res struct {
		s   []moatSetting
		err error
	}
	o := moatOpts{Consent: true, Via: viaMeek, Automatic: true, Country: opts.Country}
	done := make(chan res, 1)
	go func() {
		s, err := autoW.moat(o)
		done <- res{s, err}
	}()
	for {
		select {
		case r := <-done:
			if r.err != nil {
				log.Printf("auto: moat: %v", r.err)
				stSet(func() { autoSt.errCode = "moat_unreachable" })
				return nil, ""
			}
			if len(r.s) > 0 && decoyClosed() {
				cacheMoatSettings(r.s)
			}
			return moatSteps(r.s), ""
		default:
		}
		if why := autoInterrupted(p); why != "" {
			log.Printf("auto: moat call stopped: %s", why)
			cancelMoatCalls()
			return nil, passInterrupted
		}
		autoSleep(autoPoll)
	}
}

// puts moat's steps right after it, and drops the built-in steps further
// on for any type moat's steps already cover
func spliceMoat(steps []autoStep, at int, extra []autoStep) []autoStep {
	tried := map[string]bool{}
	for _, e := range extra {
		tried[e.Method] = true
	}
	out := append([]autoStep(nil), steps[:at+1]...)
	for _, e := range extra {
		dup := false
		for _, o := range out {
			dup = dup || (sameStep(o, e) && o.Method != "moat")
		}
		if !dup {
			out = append(out, e)
		}
	}
	for _, s := range steps[at+1:] {
		if s.Source == "builtin" && tried[s.Method] {
			continue
		}
		out = append(out, s)
	}
	return out
}

func runAttempt(p passCtx, s autoStep, validated bool) string {
	stSet(func() {
		autoSt.phase, autoSt.method, autoSt.source, autoSt.since = "trying", s.Method, s.Source, autoNow()
	})
	// automatic's own direct step is the one time it goes out without
	// bridges
	ok, changed := autoUseStep(p.gen, s)
	if !ok {
		return passInterrupted
	}
	// listening before the bounce, so nothing it brings is missed
	a := autoW.open()
	defer autoW.close()
	switch {
	// held off the network all the same: put in place again, which clears
	// the hold or fails on to the next way
	case !changed && autoW.started() && autoW.settled() && networkHold() == "":
		// these lines already carry tor on this network: no bounce
		obsArm()
	case autoW.started():
		r := autoW.apply(s)
		if why := autoInterrupted(p); why != "" {
			return passInterrupted
		}
		if r != "ok" {
			log.Printf("auto: %s not applied: %s", s.Method, r)
			return seenFailed
		}
		obsArm()
	default:
		// no tor yet: the app's start takes these lines, and the clock
		// starts with it
		for !autoW.started() {
			if why := autoInterrupted(p); why != "" {
				return passInterrupted
			}
			autoSleep(autoPoll)
		}
		// tor came up without this way in place, the listeners down or the
		// lines changed while it started: put it in place now
		if networkHold() != "" {
			r := autoW.apply(s)
			if why := autoInterrupted(p); why != "" {
				return passInterrupted
			}
			if r != "ok" {
				log.Printf("auto: %s not applied: %s", s.Method, r)
				return seenFailed
			}
		}
		now := autoNow()
		obsMu.Lock()
		a.since = now
		obsMu.Unlock()
		obsArm()
		stSet(func() { autoSt.since = now })
	}
	gen0 := routeGeneration()
	for {
		if why := autoInterrupted(p); why != "" {
			log.Printf("auto: %s attempt stopped: %s", s.Method, why)
			return passInterrupted
		}
		autoW.poll(a, s)
		now := autoNow()
		obsMu.Lock()
		var v, why string
		if s.Method == "direct" {
			v, why = judgeDirect(a, validated, now)
		} else {
			v, why = judgeBridge(a, s.Limit, now)
		}
		obsMu.Unlock()
		// a relay connected through the route this bounce built
		if v != seenOK && autoW.proven(gen0) {
			v = seenOK
		}
		if v != seenTrying {
			if why != "" {
				log.Printf("auto: %s %s: %s", s.Method, v, why)
			}
			return v
		}
		autoSleep(autoPoll)
	}
}

// ---- the loop that runs passes while the mode is automatic ----

var (
	autoKickCh = make(chan struct{}, 1)
	// how often the loop looks around
	autoTick = 10 * time.Second
	// how long tor may be without a circuit after a pass worked before a
	// new pass begins; it doubles with every such pass, up to an hour, and
	// starts over once tor has kept a circuit for half an hour
	autoLostAfter = 5 * time.Minute
	autoLostMax   = time.Hour
	autoUpFor     = 30 * time.Minute
	// the least time between two passes
	autoPassFloor = 20 * time.Second
	autoRetryBase = 15 * time.Minute
	autoRetryMax  = 2 * time.Hour
	autoRetryNow  atomic.Bool
	autoLoopRuns  atomic.Int32
	// bumped when android validates a network it could not before
	autoValidFlips atomic.Int64
)

func autoKick() {
	select {
	case autoKickCh <- struct{}{}:
	default:
	}
}

func autoRetryGap(n int) time.Duration {
	d := autoRetryBase << uint(n)
	if n > 4 || d > autoRetryMax {
		return autoRetryMax
	}
	return d
}

func autoLostGap(n int) time.Duration {
	d := autoLostAfter << uint(n)
	if n > 6 || d > autoLostMax {
		return autoLostMax
	}
	return d
}

func autoStart(gen int64) {
	autoLoopRuns.Add(1)
	go func() {
		defer autoLoopRuns.Add(-1)
		autoLoop(gen)
	}()
}

// passes are started here and nowhere else
var autoRunPass = runPass

func autoLoop(gen int64) {
	var (
		result    string
		kind      string
		epoch     = netEpoch.Load()
		retryAt   time.Time
		fails     int
		downSince time.Time
		upSince   time.Time
		lost      int
		heldN     int
		heldAt    time.Time
		lastPass  time.Time
		consent   = consentNow()
		valid     = autoValidFlips.Load()
	)
	for autoGen() == gen {
		now := autoNow()
		start := ""
		if why := autoIdleWhy(); why != "" {
			downSince, upSince = time.Time{}, time.Time{}
			if result != seenOK && result != "exhausted" {
				result = passInterrupted
			}
			if why == "captive" {
				captiveWay(gen)
			}
		} else {
			n := currentNet()
			ep := netEpoch.Load()
			c := consentNow()
			v := autoValidFlips.Load()
			switch {
			case result == "":
				start = "start"
			// a new network, or one that left tor held off it, as a change
			// of the same kind can: a pass puts a way back in place
			case ep != epoch && (result != seenOK || n.Kind != kind || networkHold() != ""):
				start = "network"
			case result == passInterrupted:
				start = "again"
			// awake with no way in place, as after a wake: a pass finds one,
			// and one that keeps finding the hold backs off. a retry from the
			// app, as on coming to the front, does not wait the backoff out
			case result == seenOK && networkHold() != "" && (!now.Before(heldAt) || autoRetryNow.Load()):
				start = "held"
				autoRetryNow.Store(false)
				heldAt = now.Add(autoLostGap(heldN))
				heldN++
			case v != valid && result != seenOK:
				start = "validated"
			case result == "exhausted" && (autoRetryNow.Swap(false) || !now.Before(retryAt) || (c == "yes" && consent != "yes")):
				start = "retry"
			case result == seenOK:
				epoch = ep
				if networkHold() == "" {
					heldN, heldAt = 0, time.Time{}
				}
				if autoW.torUp() {
					downSince = time.Time{}
					if upSince.IsZero() {
						upSince = now
					} else if now.Sub(upSince) >= autoUpFor {
						lost = 0
					}
				} else {
					upSince = time.Time{}
					if downSince.IsZero() {
						downSince = now
					} else if now.Sub(downSince) >= autoLostGap(lost) {
						start = "lost"
						lost++
					}
				}
			}
			consent, valid = c, v
		}
		if start != "" {
			if start == "network" {
				// let the network settle, as the bounce on a change does
				for e := netEpoch.Load(); ; e = netEpoch.Load() {
					autoSleep(netQuiet)
					if netEpoch.Load() == e || autoGen() != gen {
						break
					}
				}
			}
			if wait := lastPass.Add(autoPassFloor).Sub(autoNow()); !lastPass.IsZero() && wait > 0 {
				autoSleep(wait)
			}
			if autoGen() != gen {
				return
			}
			epoch = netEpoch.Load()
			kind = currentNet().Kind
			lastPass = autoNow()
			result = autoRunPass(gen, epoch, start)
			downSince, upSince = time.Time{}, time.Time{}
			switch result {
			case "exhausted":
				retryAt = autoNow().Add(autoRetryGap(fails))
				fails++
			case seenOK:
				fails = 0
			}
			continue
		}
		select {
		case <-autoKickCh:
		case <-time.After(autoTick):
		}
	}
}

// ---- modes ----

func setBridgeMode(mode, raw string) string {
	if !decoyClosed() {
		// a decoy shows automatic and changes nothing underneath
		return "error: decoy"
	}
	modeMu.Lock()
	defer modeMu.Unlock()
	return applyBridgeMode(mode, raw)
}

// a mode, whoever hands it over: the app's pick or the boot restore
func applyBridgeMode(mode, raw string) string {
	var o modeOpts
	if strings.TrimSpace(raw) != "" && json.Unmarshal([]byte(raw), &o) != nil {
		return "error: bad json"
	}
	switch o.Consent {
	case "", "no":
		o.Consent = "no"
	case "yes", "ask":
	default:
		return "error: bad consent"
	}
	var lines []string
	switch mode {
	case bmAuto, bmDirect:
	case bmSnowflake:
		lines = builtinLines("snowflake")
		// no lines would be direct
		if len(lines) == 0 {
			return "error: lines_bad"
		}
	case bmWebtunnel, bmMoat, bmOwn:
		good, _, checks := sortBridgeLines(strings.Join(o.Lines, "\n"))
		lineChecksMu.Lock()
		lineChecks = checks
		lineChecksMu.Unlock()
		if mode == bmWebtunnel {
			var wt []string
			for _, ln := range good {
				if strings.HasPrefix(ln, "webtunnel ") {
					wt = append(wt, ln)
				}
			}
			good = wt
		}
		if len(good) == 0 {
			return "error: lines_bad"
		}
		lines = good
	default:
		return "error: unknown mode"
	}

	heldBefore := networkHold()
	autoMu.Lock()
	prevMode, prevOpts := bmMode, bmOpts
	same := prevMode == mode && optsEqual(prevOpts, o)
	// only the consent moved: a running pass keeps its place
	withConsent := prevOpts
	withConsent.Consent = o.Consent
	consentOnly := !same && prevMode == bmAuto && mode == bmAuto && optsEqual(withConsent, o)
	switch {
	case consentOnly:
		bmOpts = o
	case !same:
		autoGenN++
		bmMode, bmOpts = mode, o
	}
	gen := autoGenN
	changed := false
	if mode != bmAuto && !same {
		changed = useLines(lines)
	}
	if !same && !consentOnly {
		// a new mode: whatever direct step automatic had is over
		autoDirectOK.Store(false)
	}
	// known from here on, with its lines in place, before any bounce below
	// wants the network
	modeSet.Store(true)
	autoMu.Unlock()
	if same || consentOnly {
		if mode == bmAuto {
			autoKick()
		}
		return "ok"
	}
	gateDrop()
	if mode == bmAuto {
		stSet(func() { autoSt.phase, autoSt.method, autoSt.source = "trying", "", "" })
		// the direct step tor was on is over: off the network now, not when
		// a pass gets to it, as none may run behind a portal
		if prevMode == bmAuto && heldBefore == "" && networkHold() == errAutoWait && torStarted() && !torIsPaused() {
			go holdBounce()
		}
		autoStart(gen)
		return "ok"
	}
	stSet(func() {
		autoSt.phase, autoSt.method, autoSt.source = "", "", ""
		autoSt.blocked, autoSt.limited, autoSt.errCode, autoSt.askConsent = false, false, "", false
	})
	if (changed || prevMode != mode) && torStarted() && !torIsPaused() {
		go reconnectNowFor(whyBridges)
	}
	return "ok"
}

func optsEqual(a, b modeOpts) bool {
	x, _ := json.Marshal(a)
	y, _ := json.Marshal(b)
	return string(x) == string(y)
}

// the method a check-in uses: the one that worked here last. if that is
// snowflake and obfs4 or webtunnel also worked here in the last 30 days,
// that one, so check-ins do not rendezvous with the broker every quarter
// hour.
func checkInStep(kind string, mem autoMemory, opts modeOpts, today int64) (autoStep, bool) {
	u, ok := mem.Last[kind]
	if !ok || !fresh(u.Day, today) {
		return autoStep{}, false
	}
	// direct only where it is still welcome: not risky, not blocked lately
	if u.Method == "direct" {
		if d, blocked := mem.Blocked[kind]; opts.SkipDirect || (blocked && fresh(d, today)) {
			return autoStep{}, false
		}
	}
	if u.Method == "snowflake" {
		for _, m := range []string{"webtunnel", "obfs4"} {
			// one that failed in a pass since was forgotten there
			if w, ok := mem.Worked[kind][m]; ok && fresh(w.Day, today) {
				if lines := linesFor(w, opts); len(lines) > 0 {
					return autoStep{Method: w.Method, Source: w.Source, Lines: lines}, true
				}
			}
		}
	}
	lines := linesFor(u, opts)
	if u.Method != "direct" && len(lines) == 0 {
		return autoStep{}, false
	}
	return autoStep{Method: u.Method, Source: u.Source, Lines: lines}, true
}

// a check-in begins or ends. in automatic the check-in's method is put in
// place while tor still sleeps, so waking it is all the check-in does.
func checkIn(on bool) string {
	checkInMu.Lock()
	if on {
		checkInUntil = autoNow().Add(checkInMax)
	} else {
		checkInUntil = time.Time{}
	}
	checkInMu.Unlock()
	if mode, _, _ := bridgeMode(); !on || mode != bmAuto {
		autoKick()
		return "ok"
	}
	return putCheckInStep()
}

// the check-in's way in for this network, in place while tor sleeps; a
// network change inside the check-in puts the new network's back
func putCheckInStep() string {
	mode, opts, gen := bridgeMode()
	if mode != bmAuto {
		return "ok"
	}
	// no network, or one android has not named yet: its kind is not known,
	// and the detail that names it puts the step
	n := currentNet()
	if d, ok := netDetailTrusted(); !n.On || (ok && !d.On) {
		return "ok"
	}
	kind, mem, today := n.Kind, memSnapshot(), dayOf(autoNow())
	s, ok := checkInStep(kind, mem, opts, today)
	if !ok {
		// nothing remembered here: tor alone where that is welcome, else
		// the built-in bridges, never direct
		s = autoStep{Method: "direct"}
		if d, b := mem.Blocked[kind]; opts.SkipDirect || (b && fresh(d, today)) {
			s = autoStep{Method: "obfs4", Source: "builtin", Lines: builtinLines("obfs4")}
			// no line to use is a hold: no lines and no direct step
			if len(s.Lines) == 0 {
				stSet(func() { autoSt.method, autoSt.source = "", "" })
				autoUseStep(gen, autoStep{})
				return "error: lines_bad"
			}
		}
	}
	// these lines are what tor has from now on, whatever ran before
	stSet(func() { autoSt.method, autoSt.source = s.Method, s.Source })
	if ok, _ := autoUseStep(gen, s); !ok {
		return "ok"
	}
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t != nil && t.Control != nil && torIsPaused() {
		if err := applyBridgeConf(t); err != nil {
			log.Printf("auto: check-in config: %v", err)
		}
	}
	return "ok"
}

// putCheckInStep off the caller's thread, one at a time, the last change
// always looked at
var (
	ciStepMu    sync.Mutex
	ciStepBusy  bool
	ciStepAgain bool
)

func putCheckInStepSoon() {
	ciStepMu.Lock()
	if ciStepBusy {
		ciStepAgain = true
		ciStepMu.Unlock()
		return
	}
	ciStepBusy = true
	ciStepMu.Unlock()
	go func() {
		for {
			if inCheckIn() {
				putCheckInStep()
			}
			ciStepMu.Lock()
			if !ciStepAgain {
				ciStepBusy = false
				ciStepMu.Unlock()
				return
			}
			ciStepAgain = false
			ciStepMu.Unlock()
		}
	}()
}

// ---- the status line ----

type bridgeStatusView struct {
	Mode       string `json:"mode"`
	Phase      string `json:"phase"`
	Method     string `json:"method"`
	Source     string `json:"source,omitempty"`
	Progress   int    `json:"progress"`
	Attempt    int    `json:"attempt,omitempty"`
	Attempts   int    `json:"attempts,omitempty"`
	SinceMs    int64  `json:"since_ms"`
	CanSend    bool   `json:"can_send"`
	Blocked    bool   `json:"blocked"`
	Limited    bool   `json:"limited"`
	Snowflake  string `json:"snowflake,omitempty"`
	LastOK     string `json:"last_ok_method,omitempty"`
	LastOKDay  int64  `json:"last_ok_day,omitempty"`
	ErrorCode  string `json:"error_code,omitempty"`
	AskConsent bool   `json:"ask_consent,omitempty"`
	Network    string `json:"network"`
	VPN        bool   `json:"vpn"`
}

// the transport of the lines in use, "direct" without any
func linesMethod() string {
	ls := bridgeLines()
	if !bridgesEnabled() || len(ls) == 0 {
		return "direct"
	}
	if b, err := parseBridgeLine(ls[0]); err == nil {
		return b.transport
	}
	return strings.Fields(ls[0])[0]
}

func bridgeStatus() bridgeStatusView {
	mode, _, _ := bridgeMode()
	n := currentNet()
	v := bridgeStatusView{Mode: mode, VPN: n.VPN, CanSend: routeOK()}
	switch {
	case !n.On:
		v.Network = "none"
	case !n.Validated || n.Limited:
		v.Network = "limited"
	default:
		v.Network = "ok"
	}
	statusMu.RLock()
	v.Progress = bootstrapPct
	statusMu.RUnlock()

	autoSt.Lock()
	phase, method, source, since := autoSt.phase, autoSt.method, autoSt.source, autoSt.since
	v.Blocked, v.Limited, v.ErrorCode, v.AskConsent = autoSt.blocked, autoSt.limited, autoSt.errCode, autoSt.askConsent
	attempt, attempts := autoSt.attempt, autoSt.attempts
	autoSt.Unlock()

	if mode != bmAuto {
		method, source = linesMethod(), ""
		switch mode {
		case bmMoat:
			source = "moat"
		case bmOwn:
			source = "own"
		case bmSnowflake:
			source = "builtin"
		}
		phase = "trying"
		if v.CanSend {
			phase = "connected"
		}
		since = time.Time{}
		// no mode yet is no method yet, never direct
		if !bridgeModeKnown() {
			method = ""
		}
	}
	// tor held off the network: why, in its own code. a bridge whose
	// listeners would not start, one tor refused, no mode yet, or
	// automatic with no way in yet, which a wake can leave under a pass
	// that once connected
	if c := holdCode(); c != "" && v.ErrorCode == "" && (phase != "connected" || (c == codeWait && !v.CanSend)) {
		v.ErrorCode = c
	}
	switch why := autoIdleWhy(); {
	case why == "not_tor_mode", why == "no_internet":
		phase, v.ErrorCode = why, why
	// a portal tor gets through anyway is no portal to sign in to
	case why == "captive" && v.CanSend:
		phase = "connected"
	case why == "captive":
		phase, v.ErrorCode = "captive", "limited"
	case why == "paused" && inCheckIn():
		phase = "checkin"
	case why == "paused":
		phase, v.ErrorCode = "paused", "paused"
	}
	if phase == "" {
		phase = "trying"
	}
	v.Phase = phase
	if phase == "connected" || v.CanSend {
		v.AskConsent = false
	}
	// "trying another way, 2 of 3" needs no method name
	if mode == bmAuto && (phase == "trying" || phase == "asking") {
		v.Attempt, v.Attempts = attempt, attempts
	}
	if !since.IsZero() && (phase == "trying" || phase == "asking") {
		v.SinceMs = autoNow().Sub(since).Milliseconds()
	}
	v.Method, v.Source = method, source
	if method == "snowflake" && phase == "trying" {
		if p, at, _ := snowflakeStatus(); !since.IsZero() && at.After(since) {
			v.Snowflake = p
		}
	}
	if u, ok := memSnapshot().Last[n.Kind]; ok && fresh(u.Day, dayOf(autoNow())) {
		v.LastOK, v.LastOKDay = u.Method, u.Day
	}
	// a decoy sees automatic at work, and nothing of how: connected,
	// trying or offline, and no more
	if !decoyClosed() {
		d := bridgeStatusView{Mode: bmAuto, Progress: v.Progress, CanSend: v.CanSend, Network: v.Network, VPN: v.VPN}
		switch v.Phase {
		case "connected":
			d.Phase = "connected"
		case "trying", "asking":
			d.Phase = "trying"
		default:
			d.Phase = "offline"
		}
		return d
	}
	return v
}

// ---- exports ----

// picks how tor connects: auto, direct, snowflake, webtunnel, moat or own.
// opts as modeOpts json. "ok", or "error: <code>". in a decoy nothing
// changes.
//
//export HaloSetBridgeMode
func HaloSetBridgeMode(cMode, cJSON *C.char) *C.char {
	return C.CString(setBridgeMode(goStr(cMode), goStr(cJSON)))
}

// the status line's facts as json, in plain terms and without any line,
// address or host: mode, phase (trying, asking, connected, exhausted,
// no_internet, paused, checkin, not_tor_mode), method, source, progress,
// attempt and attempts (automatic's plan for this network), since_ms,
// can_send, blocked, limited, snowflake, last_ok_method, last_ok_day,
// error_code, ask_consent, network, vpn
//
//export HaloBridgeStatus
func HaloBridgeStatus() *C.char {
	b, err := json.Marshal(bridgeStatus())
	if err != nil {
		return C.CString("{}")
	}
	return C.CString(string(b))
}

// try again now after automatic gave up, as when the app comes to the
// front or the person taps try again
//
//export HaloBridgeRetry
func HaloBridgeRetry() *C.char {
	bridgeRetry()
	return C.CString("ok")
}

// a picked bridge also gets its listeners tried again
func bridgeRetry() {
	autoRetryNow.Store(true)
	autoKick()
	if mode, _, _ := bridgeMode(); mode != bmAuto && torStarted() && !torIsPaused() {
		go reconnectNowFor(whyBridges)
	}
}

// what automatic remembers, as json for the secure store, or
// {"error":"decoy"}
//
//export HaloAutoMemory
func HaloAutoMemory() *C.char {
	return C.CString(autoMemoryJSON())
}

// the store gives back only what HaloAutoMemory gave, never in a decoy
func setAutoMemory(s string) string {
	if !decoyClosed() {
		return moatReply(nil, errMoatDecoy)
	}
	memIn(s, dayOf(autoNow()))
	return "ok"
}

func autoMemoryJSON() string {
	if !decoyClosed() {
		return moatReply(nil, errMoatDecoy)
	}
	b, _ := json.Marshal(memOut(dayOf(autoNow())))
	return string(b)
}

// hands back what HaloAutoMemory gave, at start
//
//export HaloSetAutoMemory
func HaloSetAutoMemory(cJSON *C.char) *C.char {
	return C.CString(setAutoMemory(goStr(cJSON)))
}

// a check-in begins (1) or ends (0)
//
//export HaloCheckIn
func HaloCheckIn(on C.int) *C.char {
	noteCheckIn(int(on))
	return C.CString(checkIn(on != 0))
}
