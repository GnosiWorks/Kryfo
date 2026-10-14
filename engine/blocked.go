// SPDX-License-Identifier: GPL-3.0-or-later
package main

// whether tor gets through on this network, judged from tor's own words:
// the bootstrap phase while tor has never been up in this process, its
// ORCONN events for every guard, fallback and bridge it tries, its CIRC
// events, and the local transport listeners tor dials. never from the
// nostr relays: a slow relay must not make a working bridge look dead.
//
// tor reports bootstrap problems only until it first reaches 100%, and the
// phase stays at 100 after that, bounces included. so the phase counts on
// a first start only, and the events carry everything after.

import (
	"hash/fnv"
	"log"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// one GETINFO status/bootstrap-phase reply taken apart. HOSTADDR is never
// kept: it is a relay or bridge address.
type bootPhase struct {
	Progress int
	Tag      string
	Warning  string
	Reason   string
	Count    int
	Warn     bool // RECOMMENDATION=warn
}

func parseBootPhase(v string) bootPhase {
	p := bootPhase{Progress: parseBootstrapPct(v)}
	for _, f := range splitPhase(v) {
		k, val, ok := strings.Cut(f, "=")
		if !ok {
			continue
		}
		val = strings.Trim(val, `"`)
		switch k {
		case "TAG":
			p.Tag = val
		case "WARNING":
			p.Warning = val
		case "REASON":
			p.Reason = val
		case "COUNT":
			p.Count, _ = strconv.Atoi(val)
		case "RECOMMENDATION":
			p.Warn = val == "warn"
		}
	}
	return p
}

// the fields of a phase line, quoted values kept whole
func splitPhase(v string) []string {
	var out []string
	var b strings.Builder
	quoted := false
	for _, c := range v {
		switch {
		case c == '"':
			quoted = !quoted
			b.WriteRune(c)
		case c == ' ' && !quoted:
			if b.Len() > 0 {
				out = append(out, b.String())
				b.Reset()
			}
		default:
			b.WriteRune(c)
		}
	}
	if b.Len() > 0 {
		out = append(out, b.String())
	}
	return out
}

// tags where tor is still trying to reach its first hop
var connTags = map[string]bool{
	"conn_pt": true, "conn_done_pt": true, "conn_proxy": true, "conn_done_proxy": true,
	"conn": true, "conn_done": true, "handshake": true,
	"ap_conn_pt": true, "ap_conn_done_pt": true, "ap_conn_proxy": true, "ap_conn_done_proxy": true,
	"ap_conn": true, "ap_conn_done": true, "ap_handshake": true,
}

// tags past the handshake with the first hop
var handshakeDoneTags = map[string]bool{"handshake_done": true, "ap_handshake_done": true}

// a stall at these after a handshake is a censor letting the handshake
// through and cutting what follows. requesting_status is one of them: a
// consensus request that never gets a byte back is cut, not slow
var noCircuitTags = map[string]bool{
	"handshake_done": true, "onehop_create": true, "requesting_status": true,
}

// the same for the path with a cached consensus, which goes straight from
// its handshake to the first circuit. after a directory download they are
// only a slow first circuit
var cachedNoCircuitTags = map[string]bool{"ap_handshake_done": true, "circuit_create": true}

// tags of a directory download under way
var dirTags = map[string]bool{
	"loading_status": true, "loading_keys": true, "requesting_descriptors": true, "loading_descriptors": true,
}

// past the consensus: what is left is the descriptor download
var descTags = map[string]bool{"requesting_descriptors": true, "loading_descriptors": true}

// the ways a censor ends a connection to a relay
var censorReasons = map[string]bool{
	"CONNECTRESET": true, "TIMEOUT": true, "NOROUTE": true, "CONNECTREFUSED": true, "IOERROR": true,
}

// what one attempt has seen since tor went back on the network. targets
// are kept as hashes only.
type attemptSeen struct {
	since time.Time
	// events count once tor is back on the network after the switch; the
	// listener is on before it, so none are missed
	armed    bool
	orOK     bool
	fails    map[uint64]bool
	failAt   time.Time
	circuit  bool
	circAt   time.Time
	phase    bootPhase
	phaseOK  bool // the phase is fresh: tor has not reached 100% yet
	tagSince time.Time
	tagMoved time.Time
	countAt  time.Time // when COUNT last rose
	countUp  int       // how many times it rose
	hsDoneAt time.Time
	// tor got bytes of the directory in this attempt
	dirSeen bool
	// this attempt's way carried tor on to the descriptor download
	pastConsensus bool
	// a transport listener's first request after the switch, and the last
	// time its snowflake reported progress
	firstDial time.Time
	sfMoved   time.Time
	allDead   bool
}

func newSeen(now time.Time) *attemptSeen {
	return &attemptSeen{since: now, fails: map[uint64]bool{}}
}

func targetHash(s string) uint64 {
	h := fnv.New64a()
	h.Write([]byte(s))
	return h.Sum64()
}

func (a *attemptSeen) orconn(target, status, reason string, now time.Time) {
	switch status {
	case "CONNECTED":
		a.orOK = true
	case "FAILED", "CLOSED":
		if !censorReasons[reason] {
			return
		}
		if len(a.fails) == 0 {
			a.failAt = now
		}
		a.fails[targetHash(target)] = true
	}
}

// a circuit tor built for its own directory fetches or an onion service
// says less than one of its ordinary three-hop circuits, so only those count
func (a *attemptSeen) circ(status string, flags []string, now time.Time) {
	if status != "BUILT" || a.circuit {
		return
	}
	for _, f := range flags {
		if f == "ONEHOP_TUNNEL" || f == "IS_INTERNAL" {
			return
		}
	}
	a.circuit, a.circAt = true, now
}

func (a *attemptSeen) bootstrap(p bootPhase, fresh bool, now time.Time) {
	if !fresh || p.Progress >= 100 {
		// getting to the end is progress too
		if fresh && a.phaseOK && p.Progress > a.phase.Progress {
			a.tagMoved = now
		}
		a.phaseOK = false
		return
	}
	if dirTags[p.Tag] || (p.Progress >= 30 && p.Progress < 75) {
		a.dirSeen = true
	}
	if !a.phaseOK || p.Tag != a.phase.Tag {
		a.tagSince = now
	}
	// a new phase or a higher percent is progress
	if a.phaseOK && (p.Tag != a.phase.Tag || p.Progress > a.phase.Progress) {
		a.tagMoved = now
		if descTags[p.Tag] {
			a.pastConsensus = true
		}
	}
	if a.phaseOK && p.Count > a.phase.Count {
		a.countAt = now
		a.countUp++
	}
	if handshakeDoneTags[p.Tag] && a.hsDoneAt.IsZero() {
		a.hsDoneAt = now
	}
	a.phase, a.phaseOK = p, true
}

// the verdicts an attempt can come to
const (
	seenTrying  = "trying"
	seenOK      = "ok"
	seenBlocked = "blocked" // tor's first hop is cut off: a censor
	seenFailed  = "failed"  // ran out of time, or every line is dead
	seenLimited = "limited" // direct ran out on a network android could not check
)

// how a direct attempt is judged. vars so the tests can read them.
var (
	directOrWindow  = 45 * time.Second
	directTagStuck  = 60 * time.Second
	directNoCircuit = 90 * time.Second
	directLimit     = 90 * time.Second
	// an attempt that keeps moving forward runs on, up to this from its
	// start, and ends only once it has stalled for its own limit
	attemptCap = 4 * time.Minute
	// a bridge that brought the consensus may sit this long on one percent
	// of the descriptor download: tor fetches them all through the bridges,
	// and a set with dead lines in it waits out each one
	descStall = 150 * time.Second
	// tor at times waits over two minutes before the first dial to a line
	// it was just given. the clock of a bridge starts at that dial.
	firstDialWait = 160 * time.Second
)

// the evidence that a direct attempt is blocked, or ""
func (a *attemptSeen) blockedWhy(now time.Time) string {
	if len(a.fails) >= 3 && !a.orOK && now.Sub(a.since) >= directOrWindow {
		return "relays cut off"
	}
	if a.phaseOK {
		if connTags[a.phase.Tag] && now.Sub(a.tagSince) >= directTagStuck {
			return "stuck connecting"
		}
		// only a censor's reason: a skewed clock or the like warns too
		if a.phase.Warn && a.countUp >= 2 && censorReasons[a.phase.Reason] {
			return "tor warns"
		}
		// past the handshake and no further: a censor that lets the
		// handshake through and cuts what follows. a bootstrap that got
		// on to the consensus is no such thing
		stuck := noCircuitTags[a.phase.Tag] || (cachedNoCircuitTags[a.phase.Tag] && !a.dirSeen)
		if from := a.hsDoneAt; !from.IsZero() && stuck {
			if a.tagMoved.After(from) {
				from = a.tagMoved
			}
			if now.Sub(from) >= directNoCircuit {
				return "no circuit"
			}
		}
	}
	return ""
}

// whether an attempt that began at start is over: nothing moved forward
// for its limit, a new phase, a higher percent or a snowflake step, or it
// reached the cap however it moves
func (a *attemptSeen) ranOut(start time.Time, limit time.Duration, now time.Time) bool {
	if now.Sub(start) >= attemptCap {
		return true
	}
	from := start
	for _, m := range []time.Time{a.tagMoved, a.sfMoved} {
		if m.After(from) {
			from = m
		}
	}
	return now.Sub(from) >= limit
}

// the verdict on a direct attempt. on a network android could not check,
// direct gets its whole time and ends limited, never blocked.
func judgeDirect(a *attemptSeen, validated bool, now time.Time) (string, string) {
	if a.circuit {
		return seenOK, ""
	}
	limit := directLimit
	if validated {
		if why := a.blockedWhy(now); why != "" {
			return seenBlocked, why
		}
	}
	if !a.ranOut(a.since, limit, now) {
		return seenTrying, ""
	}
	if !validated {
		return seenLimited, "ran out"
	}
	// a validated network where no relay ever answered: a censor that
	// drops rather than resets looks like this
	if !a.orOK {
		return seenBlocked, "nothing answered"
	}
	return seenFailed, "ran out"
}

// the verdict on a bridge attempt. its time runs from tor's first dial on
// the transport, not from the switch.
func judgeBridge(a *attemptSeen, limit time.Duration, now time.Time) (string, string) {
	if a.circuit {
		return seenOK, ""
	}
	if a.allDead {
		return seenFailed, "every line failed"
	}
	if a.firstDial.IsZero() {
		if now.Sub(a.since) >= firstDialWait {
			return seenFailed, "tor never dialled"
		}
		return seenTrying, ""
	}
	if a.pastConsensus && limit < descStall {
		limit = descStall
	}
	if !a.ranOut(a.firstDial, limit, now) {
		return seenTrying, ""
	}
	return seenFailed, "ran out"
}

// ---- the live side: tor's events into the attempt that is open ----

var (
	obsMu  sync.Mutex
	obsCur *attemptSeen
	// the event connection the listener is on, and whether it is
	obsGen   int
	obsOn    bool
	obsCh    = make(chan control.Event, 64)
	obsStart sync.Once
)

// the one reader of obsCh. bine's pump blocks on a full channel, so it is
// drained for the life of the process, subscribed or not.
func obsReader() {
	for ev := range obsCh {
		now := time.Now()
		obsMu.Lock()
		a := obsCur
		if a != nil && a.armed {
			switch e := ev.(type) {
			case *control.ORConnEvent:
				a.orconn(e.Target, e.Status, e.Reason, now)
			case *control.CircuitEvent:
				a.circ(e.Status, e.BuildFlags, now)
			}
		}
		obsMu.Unlock()
	}
}

func eventConnGen() int {
	evMu.Lock()
	defer evMu.Unlock()
	return evGen
}

// opens an attempt: events from now on count for it
func obsOpen(t *tor.Tor, now time.Time) *attemptSeen {
	obsStart.Do(func() { go obsReader() })
	a := newSeen(now)
	obsMu.Lock()
	obsCur = a
	obsMu.Unlock()
	obsSubscribe(t)
	return a
}

func obsSubscribe(t *tor.Tor) {
	if t == nil || t.ControlPort == 0 {
		return
	}
	c, err := eventConn(t)
	if err != nil {
		log.Printf("auto: event subscribe: %v", err)
		return
	}
	gen := eventConnGen()
	obsMu.Lock()
	if obsOn && obsGen == gen {
		obsMu.Unlock()
		return
	}
	obsMu.Unlock()
	if err := c.AddEventListener(obsCh, control.EventCodeORConn, control.EventCodeCircuit); err != nil {
		log.Printf("auto: event subscribe: %v", err)
		return
	}
	obsMu.Lock()
	obsOn, obsGen = true, gen
	obsMu.Unlock()
}

// tor is back on the network for the attempt that is open: its events
// count from here
func obsArm() {
	obsMu.Lock()
	if obsCur != nil {
		obsCur.armed = true
	}
	obsMu.Unlock()
}

// closes the attempt and stops the events, which come by the hundred
func obsClose() {
	obsMu.Lock()
	obsCur = nil
	on, gen := obsOn, obsGen
	obsOn = false
	obsMu.Unlock()
	if !on {
		return
	}
	evMu.Lock()
	c, g := evConn, evGen
	evMu.Unlock()
	if c != nil && g == gen {
		_ = c.RemoveEventListener(obsCh, control.EventCodeORConn, control.EventCodeCircuit)
	}
}

// the bootstrap phase, asked of tor. ok false when tor did not answer.
func readBootPhase(t *tor.Tor) (bootPhase, bool) {
	if t == nil || t.Control == nil {
		return bootPhase{}, false
	}
	var kv []*control.KeyVal
	err := ctrlDo(t, "GETINFO bootstrap-phase", func(c *control.Conn) error {
		var gerr error
		kv, gerr = c.GetInfo("status/bootstrap-phase")
		return gerr
	})
	if err != nil || len(kv) == 0 {
		return bootPhase{}, false
	}
	return parseBootPhase(kv[0].Val), true
}

// whether tor has been at 100% in this process. its phase says nothing
// after that.
var torEverUp sync.Map // *tor.Tor -> true

func noteTorUp(t *tor.Tor) {
	if t != nil {
		torEverUp.Store(t, true)
	}
}

func torWasUp(t *tor.Tor) bool {
	_, ok := torEverUp.Load(t)
	return ok
}
