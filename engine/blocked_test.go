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
	if v, why := judgeDirect(d, true, t0.Add(time.Second+directNoCircuit)); v != seenBlocked || why != "no circuit" {
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
	// the tag moved in the last 30 s, so it gets its extension
	if v, _ := judgeDirect(a, true, t0.Add(100*time.Second)); v != seenTrying {
		t.Fatalf("no extension for a moving tag: %s", v)
	}
	if v, _ := judgeDirect(a, true, t0.Add(directLimit+attemptExtend)); v != seenFailed {
		t.Fatalf("after the extension: %s, want failed and not blocked", v)
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
	// snowflake moving gets its extension
	c := newSeen(t0)
	c.firstDial = t0
	sl := methodLimit["snowflake"]
	c.sfMoved = t0.Add(sl - 10*time.Second)
	if v, _ := judgeBridge(c, sl, t0.Add(sl+10*time.Second)); v != seenTrying {
		t.Fatalf("snowflake still moving: %s", v)
	}
	if v, _ := judgeBridge(c, sl, t0.Add(sl+attemptExtend)); v != seenFailed {
		t.Fatalf("one extension only: %s", v)
	}
	d := newSeen(t0)
	d.allDead = true
	if v, _ := judgeBridge(d, limit, t0.Add(time.Second)); v != seenFailed {
		t.Fatalf("every line dead: %s", v)
	}
}
