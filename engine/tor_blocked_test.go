// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf && torblocked

// a real tor behind the test build's censor: direct is judged blocked from
// tor's own signals, and automatic moves on to a bridge.
//
//	./torconf-tests.sh TestBlockedDirectIsJudged
package main

import (
	"strings"
	"testing"
	"time"
)

func TestBlockedDirectIsJudged(t *testing.T) {
	setDecoy(false)
	setNetInfo(netInfo{On: true, Validated: true, Kind: "wifi"})
	transportMode.Store(modePrivate)
	if addr := startListener(t.TempDir()); strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	a := obsOpen(node(t), time.Now())
	defer obsClose()
	var v, why string
	for t0 := time.Now(); time.Since(t0) < 3*time.Minute; time.Sleep(time.Second) {
		livePoll(a, autoStep{Method: "direct"})
		obsMu.Lock()
		v, why = judgeDirect(a, true, time.Now())
		fails, ok, tag := len(a.fails), a.orOK, a.phase.Tag
		obsMu.Unlock()
		if v != seenTrying {
			t.Logf("after %s: %s (%s), %d relays cut off, answered %v, tag %s, censor saw %d",
				time.Since(t0).Round(time.Second), v, why, fails, ok, tag, censorSeen.Load())
			break
		}
	}
	if v != seenBlocked {
		torState(t)
		t.Fatalf("direct behind the censor judged %q", v)
	}
	if bootPct() >= 100 {
		t.Fatal("tor got through the censor")
	}
}

// the whole of automatic on a first start behind the censor: direct is
// judged blocked and remembered, and a bridge is tried. whether a bridge
// gets through depends on the network the test runs on, so that is logged.
func TestBlockedAutomaticMovesOn(t *testing.T) {
	setDecoy(false)
	setNetInfo(netInfo{On: true, Validated: true, Kind: "wifi"})
	transportMode.Store(modePrivate)
	if r := setBridgeMode(bmAuto, `{"consent":"no"}`); r != "ok" {
		t.Fatalf("mode: %s", r)
	}
	defer setBridgeMode(bmDirect, "")
	if addr := startListener(t.TempDir()); strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	t0 := time.Now()
	var st bridgeStatusView
	moved := false
	for time.Since(t0) < 12*time.Minute {
		st = bridgeStatus()
		if st.Method != "direct" && st.Method != "" {
			moved = true
		}
		if st.Phase == "connected" || st.Phase == "exhausted" {
			break
		}
		time.Sleep(2 * time.Second)
	}
	t.Logf("after %s: phase %s, method %s, blocked %v", time.Since(t0).Round(time.Second), st.Phase, st.Method, st.Blocked)
	if m := memSnapshot(); m.Blocked["wifi"] == 0 {
		t.Fatalf("direct not remembered as blocked: %+v", m)
	}
	if !moved {
		t.Fatal("automatic never tried a bridge")
	}
	if st.Phase == "connected" && st.Method == "direct" {
		t.Fatal("connected direct through the censor")
	}
}
