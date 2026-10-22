// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func planNames(steps []autoStep) string {
	var out []string
	for _, s := range steps {
		out = append(out, s.Method+"/"+s.Source)
	}
	return strings.Join(out, " ")
}

// where tor looks blocked the public obfs4 bridges go last; elsewhere the
// order is as it was
func TestBlockedPlanPutsObfs4Last(t *testing.T) {
	useFakeAuto(t, wifi())
	today := dayOf(t0Auto)
	wt := modeOpts{Webtunnel: []string{webtunnelLine(t)}}
	cases := []struct {
		name string
		mem  autoMemory
		opts modeOpts
		want string
	}{
		{"nothing known", autoMemory{}, wt,
			"direct/ moat/ obfs4/builtin snowflake/builtin webtunnel/cached"},
		{"blocked here", autoMemory{Blocked: map[string]int64{"wifi": today}}, wt,
			"moat/ snowflake/builtin webtunnel/cached obfs4/builtin"},
		{"blocked on the other network", autoMemory{Blocked: map[string]int64{"cellular": today - 2}}, wt,
			"direct/ moat/ snowflake/builtin webtunnel/cached obfs4/builtin"},
		{"blocked long ago", autoMemory{Blocked: map[string]int64{"cellular": today - 40}}, modeOpts{},
			"direct/ moat/ obfs4/builtin snowflake/builtin"},
		{"blocked or watched, said by the person", autoMemory{}, modeOpts{SkipDirect: true},
			"moat/ snowflake/builtin obfs4/builtin"},
		{"obfs4 worked here before: still first", autoMemory{
			Last:    map[string]autoUse{"wifi": {Method: "obfs4", Source: "builtin", Day: today}},
			Blocked: map[string]int64{"wifi": today},
		}, modeOpts{}, "obfs4/builtin moat/ snowflake/builtin"},
	}
	for _, c := range cases {
		if got := planNames(planPass("wifi", c.mem, c.opts, today)); got != c.want {
			t.Errorf("%s: %s, want %s", c.name, got, c.want)
		}
	}
}

// direct blocked in the pass: snowflake and the kept webtunnel lines are
// tried before the public obfs4, which still gets its turn
func TestBlockedPassTriesObfs4Last(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.script["direct"] = resetByCensor
	f.script["snowflake"] = never
	f.script["webtunnel"] = never
	f.script["obfs4"] = worksAfter(5 * time.Second)
	if r := pass(t, modeOpts{Webtunnel: []string{webtunnelLine(t)}}); r != seenOK {
		t.Fatalf("pass %s, tried %v", r, f.applied)
	}
	if got := strings.Join(f.applied, " "); got != "direct/ snowflake/builtin webtunnel/cached obfs4/builtin" {
		t.Fatalf("tried %s", got)
	}
	// the way that got through is the one remembered
	if m := memSnapshot(); m.Last["wifi"].Method != "obfs4" {
		t.Fatalf("remembered %+v", m)
	}
}

// the tor project's advice keeps its own order, obfs4 first included
func TestMoatOrderIsKept(t *testing.T) {
	f := useFakeAuto(t, wifi())
	f.script["direct"] = resetByCensor
	f.script["obfs4"] = never
	f.script["snowflake"] = worksAfter(5 * time.Second)
	f.moatOut = []moatSetting{
		{Type: "obfs4", Source: "builtin", Lines: builtinLines("obfs4")},
		{Type: "snowflake", Source: "builtin", Lines: builtinLines("snowflake")},
	}
	if r := pass(t, modeOpts{Consent: "yes"}); r != seenOK {
		t.Fatalf("pass %s, tried %v", r, f.applied)
	}
	if got := strings.Join(f.applied, " "); got != "direct/ obfs4/builtin snowflake/builtin" {
		t.Fatalf("tried %s", got)
	}
}

// tor bounced after automatic got through, as on the way back to onion:
// the line says connecting again, with its own clock, not almost there
func TestBounceAfterPassIsNotAlmostThere(t *testing.T) {
	f := useFakeAuto(t, wifi())
	memBlocked("wifi", dayOf(f.now))
	f.script["snowflake"] = worksAfter(5 * time.Second)
	if r := pass(t, modeOpts{}); r != seenOK {
		t.Fatalf("pass %s, tried %v", r, f.applied)
	}
	if st := bridgeStatus(); st.Phase != "connected" || st.CanSend {
		t.Fatalf("after the pass %+v", st)
	}
	// the bounce of a switch back to onion
	atomic.StoreInt64(&lastTorRestart, 0)
	reconnectTorFor(whyMode)
	f.now = f.now.Add(30 * time.Second)
	st := bridgeStatus()
	if st.Phase != "trying" || st.Method != "snowflake" || st.SinceMs != 30000 {
		t.Fatalf("after the bounce %+v", st)
	}
	// no "tor seems blocked, trying another way": the way is known
	if st.Blocked || st.Limited || st.Attempt != 0 || st.Attempts != 0 {
		t.Fatalf("after the bounce %+v", st)
	}
	// tor carries again: connected, as before
	noteAutoUp()
	if st := bridgeStatus(); st.Phase != "connected" {
		t.Fatalf("tor up again %+v", st)
	}
}

// relay and fast mode use no bridge: nothing is in use, whatever tor keeps
func TestNotTorModeHasNothingInUse(t *testing.T) {
	f := useFakeAuto(t, wifi())
	memBlocked("wifi", dayOf(f.now))
	f.script["snowflake"] = worksAfter(5 * time.Second)
	if r := pass(t, modeOpts{}); r != seenOK {
		t.Fatalf("pass %s", r)
	}
	for _, m := range []string{modeBalanced, modeFast} {
		transportMode.Store(m)
		if st := bridgeStatus(); st.Phase != "not_tor_mode" || st.Method != "" || st.Source != "" || st.Snowflake != "" {
			t.Fatalf("%s: %+v", m, st)
		}
	}
	// a picked bridge too
	autoMu.Lock()
	bmMode = bmSnowflake
	autoMu.Unlock()
	bridgeMu.Lock()
	bridgeList, bridgeOn = builtinLines("snowflake"), true
	bridgeMu.Unlock()
	if st := bridgeStatus(); st.Method != "" {
		t.Fatalf("picked snowflake in relay mode: %+v", st)
	}
	transportMode.Store(modePrivate)
	if st := bridgeStatus(); st.Method != "snowflake" {
		t.Fatalf("back on onion: %+v", st)
	}
}
