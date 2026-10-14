// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"testing"
	"time"
)

// the verdict on one attempt, from what tor said and a clock. no tor here.

func TestBootPhaseParse(t *testing.T) {
	p := parseBootPhase(`WARN BOOTSTRAP PROGRESS=5 TAG=conn SUMMARY="Connecting to a relay" WARNING="Connection reset by peer" REASON=CONNECTRESET COUNT=4 RECOMMENDATION=warn HOSTADDR=192.0.2.9:443`)
	if p.Progress != 5 || p.Tag != "conn" || p.Reason != "CONNECTRESET" || p.Count != 4 || !p.Warn ||
		p.Warning != "Connection reset by peer" {
		t.Fatalf("parsed %+v", p)
	}
	p = parseBootPhase(`NOTICE BOOTSTRAP PROGRESS=100 TAG=done SUMMARY="Done"`)
	if p.Progress != 100 || p.Tag != "done" || p.Warn {
		t.Fatalf("parsed %+v", p)
	}
}

func TestDirectBlockedByResets(t *testing.T) {
	t0 := time.Unix(1000, 0)
	a := newSeen(t0)
	for i, r := range []string{"$A~a", "$B~b", "$C~c"} {
		a.orconn(r, "FAILED", "CONNECTRESET", t0.Add(time.Duration(i)*time.Second))
	}
	// the same relay twice is one relay
	a.orconn("$C~c", "FAILED", "CONNECTRESET", t0.Add(5*time.Second))
	if v, _ := judgeDirect(a, true, t0.Add(20*time.Second)); v != seenTrying {
		t.Fatalf("judged %s before the window was over", v)
	}
	if v, why := judgeDirect(a, true, t0.Add(directOrWindow)); v != seenBlocked {
		t.Fatalf("three relays reset and none answered: %s %s", v, why)
	}
	// one that answered means the network lets tor through
	a.orconn("$D~d", "CONNECTED", "", t0.Add(30*time.Second))
	if v, _ := judgeDirect(a, true, t0.Add(directOrWindow)); v == seenBlocked {
		t.Fatal("blocked although a relay answered")
	}
	// a normal close is not a censor
	b := newSeen(t0)
	for _, r := range []string{"$A", "$B", "$C", "$D"} {
		b.orconn(r, "CLOSED", "DONE", t0)
	}
	if v, _ := judgeDirect(b, true, t0.Add(directOrWindow)); v != seenTrying {
		t.Fatalf("closed connections judged %s", v)
	}
}

func TestDirectBlockedByStuckTag(t *testing.T) {
	t0 := time.Unix(1000, 0)
	a := newSeen(t0)
	for s := 0; s <= 60; s += 2 {
		a.bootstrap(bootPhase{Progress: 5, Tag: "conn"}, true, t0.Add(time.Duration(s)*time.Second))
	}
	if v, why := judgeDirect(a, true, t0.Add(60*time.Second)); v != seenBlocked || why != "stuck connecting" {
		t.Fatalf("a minute at conn: %s %s", v, why)
	}
	// a tor that has been up says nothing with its phase
	b := newSeen(t0)
	b.bootstrap(bootPhase{Progress: 5, Tag: "conn"}, false, t0)
	if v, _ := judgeDirect(b, true, t0.Add(80*time.Second)); v != seenTrying {
		t.Fatalf("a stale phase judged %s", v)
	}
	// warnings that keep coming
	c := newSeen(t0)
	for i := 1; i <= 3; i++ {
		c.bootstrap(bootPhase{Progress: 10, Tag: "conn_done", Count: i, Warn: true, Reason: "CONNECTRESET"}, true, t0.Add(time.Duration(i)*time.Second))
	}
	if v, why := judgeDirect(c, true, t0.Add(5*time.Second)); v != seenBlocked || why != "tor warns" {
		t.Fatalf("rising warnings: %s %s", v, why)
	}
	// a skewed clock warns as loudly, and is no censor
	for _, r := range []string{"MISC", "CLOCK_SKEW", ""} {
		e := newSeen(t0)
		for i := 1; i <= 4; i++ {
			e.bootstrap(bootPhase{Progress: 80, Tag: "ap_handshake_done", Count: i, Warn: true, Reason: r}, true, t0.Add(time.Duration(i)*time.Second))
		}
		if v, why := judgeDirect(e, true, t0.Add(10*time.Second)); v == seenBlocked {
			t.Fatalf("warnings with reason %q judged blocked: %s", r, why)
		}
	}
	// a handshake with no circuit after it
	d := newSeen(t0)
	d.bootstrap(bootPhase{Progress: 15, Tag: "handshake_done"}, true, t0.Add(time.Second))
	d.bootstrap(bootPhase{Progress: 20, Tag: "onehop_create"}, true, t0.Add(3*time.Second))
	if v, _ := judgeDirect(d, true, t0.Add(time.Second+directNoCircuit)); v == seenBlocked {
		t.Fatal("the clock ran from the handshake, not from the last step")
	}
	if v, why := judgeDirect(d, true, t0.Add(3*time.Second+directNoCircuit)); v != seenBlocked || why != "no circuit" {
		t.Fatalf("no circuit after the handshake: %s %s", v, why)
	}
}

// a slow network that lets tor through is never called blocked: a relay
// answers, and the tag keeps moving
func TestSlowOpenNetworkIsNotBlocked(t *testing.T) {
	t0 := time.Unix(1000, 0)
	a := newSeen(t0)
	a.orconn("$A", "FAILED", "TIMEOUT", t0.Add(10*time.Second))
	a.orconn("$B", "FAILED", "TIMEOUT", t0.Add(20*time.Second))
	a.orconn("$C", "FAILED", "TIMEOUT", t0.Add(30*time.Second))
	a.orconn("$D", "CONNECTED", "", t0.Add(40*time.Second))
	tags := []string{"conn", "conn_done", "handshake", "handshake_done", "onehop_create", "requesting_status", "loading_status"}
	for i, tag := range tags {
		a.bootstrap(bootPhase{Progress: 5 + 5*i, Tag: tag}, true, t0.Add(time.Duration(15*i)*time.Second))
	}
	for s := 0; s < 90; s += 5 {
		if v, why := judgeDirect(a, true, t0.Add(time.Duration(s)*time.Second)); v != seenTrying {
			t.Fatalf("at %ds: %s %s", s, v, why)
		}
	}
	// the tag last moved at 90 s, so it runs until 90 s after that
	if v, _ := judgeDirect(a, true, t0.Add(170*time.Second)); v != seenTrying {
		t.Fatalf("a moving bootstrap was cut short: %s", v)
	}
	if v, _ := judgeDirect(a, true, t0.Add(90*time.Second+directLimit)); v != seenFailed {
		t.Fatalf("after the stall: %s, want failed and not blocked", v)
	}
	a.circ("BUILT", nil, t0.Add(70*time.Second))
	if v, _ := judgeDirect(a, true, t0.Add(70*time.Second)); v != seenOK {
		t.Fatalf("a built circuit: %s", v)
	}
}

// tor's own one-hop directory circuits and onion circuits say less than an
// ordinary circuit, so they prove nothing
func TestOnlyOrdinaryCircuitsCount(t *testing.T) {
	t0 := time.Unix(1000, 0)
	a := newSeen(t0)
	a.circ("BUILT", []string{"ONEHOP_TUNNEL", "IS_INTERNAL", "NEED_CAPACITY"}, t0)
	a.circ("BUILT", []string{"IS_INTERNAL", "NEED_CAPACITY"}, t0)
	a.circ("LAUNCHED", nil, t0)
	if a.circuit {
		t.Fatal("a one-hop or internal circuit counted")
	}
	a.circ("BUILT", []string{"NEED_CAPACITY"}, t0)
	if !a.circuit {
		t.Fatal("an ordinary circuit did not count")
	}
}

// android could not check the network: direct gets its whole time and
// ends limited, whatever the evidence
func TestUnvalidatedEndsLimited(t *testing.T) {
	t0 := time.Unix(1000, 0)
	a := newSeen(t0)
	for _, r := range []string{"$A", "$B", "$C", "$D"} {
		a.orconn(r, "FAILED", "CONNECTRESET", t0.Add(time.Second))
	}
	if v, _ := judgeDirect(a, false, t0.Add(60*time.Second)); v != seenTrying {
		t.Fatalf("cut short on an unvalidated network: %s", v)
	}
	if v, _ := judgeDirect(a, false, t0.Add(directLimit)); v != seenLimited {
		t.Fatalf("at the end: %s, want limited", v)
	}
	// validated and silent: a censor that drops
	b := newSeen(t0)
	if v, why := judgeDirect(b, true, t0.Add(directLimit)); v != seenBlocked || why != "nothing answered" {
		t.Fatalf("nothing answered on a validated network: %s %s", v, why)
	}
}

// tor at times waits over two minutes before its first dial to new lines.
// the bridge's time runs from that dial.
func TestBridgeTimeStartsAtTheFirstDial(t *testing.T) {
	t0 := time.Unix(1000, 0)
	limit := methodLimit["obfs4"]
	a := newSeen(t0)
	if v, _ := judgeBridge(a, limit, t0.Add(140*time.Second)); v != seenTrying {
		t.Fatalf("no dial yet at 140s: %s", v)
	}
	a.firstDial = t0.Add(144 * time.Second)
	if v, _ := judgeBridge(a, limit, t0.Add(144*time.Second+limit-time.Second)); v != seenTrying {
		t.Fatalf("judged inside its time: %s", v)
	}
	if v, _ := judgeBridge(a, limit, t0.Add(144*time.Second+limit)); v != seenFailed {
		t.Fatalf("after its time: %s", v)
	}
	b := newSeen(t0)
	if v, why := judgeBridge(b, limit, t0.Add(firstDialWait)); v != seenFailed || why != "tor never dialled" {
		t.Fatalf("never dialled: %s %s", v, why)
	}
	// snowflake moving runs on, up to the cap
	c := newSeen(t0)
	c.firstDial = t0
	sl := methodLimit["snowflake"]
	c.sfMoved = t0.Add(sl - 10*time.Second)
	if v, _ := judgeBridge(c, sl, t0.Add(sl+10*time.Second)); v != seenTrying {
		t.Fatalf("snowflake still moving: %s", v)
	}
	if v, _ := judgeBridge(c, sl, t0.Add(attemptCap)); v != seenFailed {
		t.Fatalf("past the cap: %s", v)
	}
	d := newSeen(t0)
	d.allDead = true
	if v, _ := judgeBridge(d, limit, t0.Add(time.Second)); v != seenFailed {
		t.Fatalf("every line dead: %s", v)
	}
}

// a cold start through built-in obfs4: the bridges bring the consensus,
// then tor sits on 50% for over a minute while it fetches descriptors
// through them. that bridge is working and is kept; one that never got
// past the consensus in this attempt still ends at its own limit
func TestDescriptorDownloadKeepsABridge(t *testing.T) {
	t0 := time.Unix(1000, 0)
	limit := methodLimit["obfs4"]
	a := newSeen(t0)
	a.firstDial = t0
	steps := []bootPhase{
		{Progress: 2, Tag: "conn_done_pt"}, {Progress: 10, Tag: "conn_done"},
		{Progress: 25, Tag: "requesting_status"}, {Progress: 30, Tag: "loading_status"},
		{Progress: 45, Tag: "requesting_descriptors"}, {Progress: 50, Tag: "loading_descriptors"},
	}
	for i, p := range steps {
		a.bootstrap(p, true, t0.Add(time.Duration(i)*4*time.Second))
	}
	at50 := t0.Add(20 * time.Second)
	// 88s on one percent, as a healthy built-in bridge did
	if v, _ := judgeBridge(a, limit, at50.Add(88*time.Second)); v != seenTrying {
		t.Fatalf("a bridge loading descriptors left at 88s: %s", v)
	}
	a.bootstrap(bootPhase{Progress: 52, Tag: "loading_descriptors"}, true, at50.Add(90*time.Second))
	a.circ("BUILT", nil, at50.Add(150*time.Second))
	if v, _ := judgeBridge(a, limit, at50.Add(150*time.Second)); v != seenOK {
		t.Fatalf("got through: %s", v)
	}
	// stuck there for good: ends after the longer stall, never past the cap
	b := newSeen(t0)
	b.firstDial = t0
	for i, p := range steps {
		b.bootstrap(p, true, t0.Add(time.Duration(i)*4*time.Second))
	}
	if v, _ := judgeBridge(b, limit, at50.Add(descStall)); v != seenFailed {
		t.Fatalf("stuck past the longer stall: %s", v)
	}
	// 50% from an earlier attempt, never moved in this one: its own limit
	c := newSeen(t0)
	c.firstDial = t0
	c.bootstrap(bootPhase{Progress: 50, Tag: "loading_descriptors"}, true, t0)
	if v, _ := judgeBridge(c, limit, t0.Add(limit)); v != seenFailed {
		t.Fatalf("a bridge that brought nothing kept: %s", v)
	}
}

// a slow bootstrap that keeps moving keeps its method, whatever the method,
// a stalled one fails at its own limit, and none runs past the cap
func TestSteadyProgressKeepsAMethod(t *testing.T) {
	t0 := time.Unix(1000, 0)
	for _, m := range []string{"obfs4", "webtunnel", "snowflake", "direct"} {
		limit := methodLimit[m]
		judge := func(a *attemptSeen, now time.Time) string {
			if m == "direct" {
				v, _ := judgeDirect(a, true, now)
				return v
			}
			v, _ := judgeBridge(a, limit, now)
			return v
		}
		if m == "direct" {
			limit = directLimit
		}
		// a step every two thirds of the limit, a circuit at 3:50
		a := newSeen(t0)
		a.firstDial = t0
		a.orOK = true
		step := limit * 2 / 3
		pct := 10
		for at := time.Duration(0); at < 230*time.Second; at += step {
			a.bootstrap(bootPhase{Progress: pct, Tag: "loading_descriptors"}, true, t0.Add(at))
			pct += 5
			if v := judge(a, t0.Add(at)); v != seenTrying {
				t.Fatalf("%s: steady progress judged %s at %s", m, v, at)
			}
		}
		a.circ("BUILT", nil, t0.Add(230*time.Second))
		if v := judge(a, t0.Add(230*time.Second)); v != seenOK {
			t.Fatalf("%s: %s", m, v)
		}
		// a stall after one step fails at the limit from that step
		b := newSeen(t0)
		b.firstDial = t0
		b.orOK = true
		b.bootstrap(bootPhase{Progress: 10, Tag: "conn_done"}, true, t0)
		b.bootstrap(bootPhase{Progress: 20, Tag: "loading_status"}, true, t0.Add(20*time.Second))
		if v := judge(b, t0.Add(20*time.Second+limit-time.Second)); v != seenTrying {
			t.Fatalf("%s: failed before the stall reached its limit: %s", m, v)
		}
		if v := judge(b, t0.Add(20*time.Second+limit)); v != seenFailed {
			t.Fatalf("%s: a stall judged %s", m, v)
		}
		// moving forever still ends at the cap
		c := newSeen(t0)
		c.firstDial = t0
		c.orOK = true
		for at := time.Duration(0); at <= attemptCap; at += 10 * time.Second {
			c.bootstrap(bootPhase{Progress: 10 + int(at/time.Second)/10, Tag: "loading_descriptors"}, true, t0.Add(at))
		}
		if v := judge(c, t0.Add(attemptCap)); v != seenFailed {
			t.Fatalf("%s: past the cap %s", m, v)
		}
	}
}

// a fresh bootstrap that got the directory and then waits long for its
// first circuit is slow, not blocked. the same wait with a cached
// consensus, or a consensus request that never gets a byte, is a censor
func TestSlowFirstCircuitIsNotBlocked(t *testing.T) {
	t0 := time.Unix(1000, 0)
	fresh := []bootPhase{
		{Progress: 5, Tag: "conn"}, {Progress: 14, Tag: "handshake"}, {Progress: 15, Tag: "handshake_done"},
		{Progress: 20, Tag: "onehop_create"}, {Progress: 25, Tag: "requesting_status"},
		{Progress: 30, Tag: "loading_status"}, {Progress: 45, Tag: "requesting_descriptors"},
		{Progress: 50, Tag: "loading_descriptors"}, {Progress: 75, Tag: "enough_dirinfo"},
		{Progress: 80, Tag: "ap_conn"}, {Progress: 89, Tag: "ap_handshake_done"}, {Progress: 90, Tag: "circuit_create"},
	}
	a := newSeen(t0)
	a.orOK = true
	for i, p := range fresh {
		a.bootstrap(p, true, t0.Add(time.Duration(i)*5*time.Second))
	}
	last := t0.Add(time.Duration(len(fresh)-1) * 5 * time.Second)
	if v, why := judgeDirect(a, true, last.Add(directNoCircuit)); v == seenBlocked {
		t.Fatalf("a slow first circuit after the directory judged blocked: %s", why)
	}
	// the cached path: handshake, then nothing
	b := newSeen(t0)
	b.orOK = true
	b.bootstrap(bootPhase{Progress: 80, Tag: "ap_conn"}, true, t0)
	b.bootstrap(bootPhase{Progress: 89, Tag: "ap_handshake_done"}, true, t0.Add(time.Second))
	if v, why := judgeDirect(b, true, t0.Add(time.Second+directNoCircuit)); v != seenBlocked || why != "no circuit" {
		t.Fatalf("cached path stalled after its handshake: %s %s", v, why)
	}
	// the consensus request after the handshake gets nothing back
	c := newSeen(t0)
	c.orOK = true
	for i, p := range fresh[:5] {
		c.bootstrap(p, true, t0.Add(time.Duration(i)*time.Second))
	}
	if v, why := judgeDirect(c, true, t0.Add(4*time.Second+directNoCircuit)); v != seenBlocked || why != "no circuit" {
		t.Fatalf("consensus request cut after the handshake: %s %s", v, why)
	}
	// reaching 100% is progress
	d := newSeen(t0)
	d.bootstrap(bootPhase{Progress: 90, Tag: "circuit_create"}, true, t0)
	d.bootstrap(bootPhase{Progress: 100, Tag: "done"}, true, t0.Add(10*time.Second))
	if !d.tagMoved.Equal(t0.Add(10 * time.Second)) {
		t.Fatal("reaching 100% was not progress")
	}
}
