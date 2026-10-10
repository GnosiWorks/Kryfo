// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// the weekly refresh of the built-ins, through a real tor to the real moat.
// it asks the tor project, so it is not in the default torconf list.
//
//	./torconf-tests.sh TestBuiltinRefreshOverTor
package main

import (
	"testing"
	"time"
)

func TestBuiltinRefreshOverTor(t *testing.T) {
	bootDirect(t)
	resetBuiltinState(t)
	defer decoyState.Store(decoyUnknown)

	// no consent, or a decoy open: nothing goes out
	setDecoy(false)
	sent := sentCount()
	if r := reply(t, builtinRefreshJSON(`{"force":true}`)); r["error"] != "no_consent" {
		t.Fatalf("without consent: %v", r)
	}
	setDecoy(true)
	if r := reply(t, builtinRefreshJSON(`{"consent":true,"force":true}`)); r["error"] != "decoy" {
		t.Fatalf("in a decoy: %v", r)
	}
	if sentCount() != sent {
		t.Fatal("a refused refresh went out")
	}

	setDecoy(false)
	t0 := time.Now()
	r := reply(t, builtinRefreshJSON(`{"consent":true,"via":"plain"}`))
	if r["ok"] != true {
		t.Fatalf("refresh: %v", r)
	}
	moatSent.Lock()
	tor, plain := moatSent.n[viaTor], moatSent.n[viaPlain]
	moatSent.Unlock()
	if tor == 0 || plain != 0 {
		t.Errorf("refresh went %d times through tor, %d plain", tor, plain)
	}
	want := 0
	for _, l := range builtinBundled {
		want += len(l)
	}
	t.Logf("refresh through tor took %v: kept %v of %d, left out %v", time.Since(t0).Round(time.Millisecond), r["kept"], want, r["ignored"])
	if int(r["kept"].(float64)) != want {
		t.Errorf("moat's built-ins moved since builtin.json was made, run scripts/builtin-bridges.sh")
	}
	if r := reply(t, builtinRefreshJSON(`{"consent":true}`)); r["skipped"] != true {
		t.Errorf("a second refresh within the week: %v", r)
	}
}
