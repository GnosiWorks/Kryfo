// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"testing"
	"time"
)

// a cold start straight into a decoy keeps the bridges the person picked,
// and until the app has said how tor connects, tor stays off the network.
// the restore is taken once; a pick in a decoy is still refused

// a process that has heard no mode yet
func unknownMode(t *testing.T) {
	t.Helper()
	modeSet.Store(false)
	restoreUsed.Store(false)
	t.Cleanup(func() {
		modeSet.Store(true)
		restoreUsed.Store(false)
		decoyState.Store(decoyOff)
	})
}

func TestDecoyColdStartKeepsBridges(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	setDecoy(true)
	if bridgeModeKnown() {
		t.Fatal("a fresh process knows a mode")
	}
	if r := restoreBridgeMode(bmOwn, `{"lines":["`+tbObfs4+`"]}`); r != "ok" {
		t.Fatalf("restore: %q", r)
	}
	if !bridgeModeKnown() || !bridgesEnabled() {
		t.Fatal("the bridges were not taken")
	}
	if l := bridgeLines(); len(l) != 1 || !strings.HasPrefix(l[0], "obfs4 ") {
		t.Fatalf("lines: %v", l)
	}
	// the decoy still changes nothing, and the restore is done
	if r := setBridgeMode(bmDirect, ""); r != "error: decoy" {
		t.Fatalf("a pick in a decoy: %q", r)
	}
	if r := restoreBridgeMode(bmDirect, ""); r != "error: restore used" {
		t.Fatalf("a second restore: %q", r)
	}
	if !bridgesEnabled() {
		t.Fatal("the decoy turned the bridges off")
	}
}

func TestDecoyColdStartKeepsAutomatic(t *testing.T) {
	useFakeAuto(t, wifi())
	unknownMode(t)
	setDecoy(true)
	if r := restoreBridgeMode(bmAuto, `{"consent":"ask","skip_direct":true}`); r != "ok" {
		t.Fatalf("restore: %q", r)
	}
	mode, opts, _ := bridgeMode()
	if mode != bmAuto || !opts.SkipDirect {
		t.Fatalf("mode %q %+v", mode, opts)
	}
	// what the decoy sees is automatic and nothing of how
	if v := bridgeStatus(); v.Mode != bmAuto || v.Method != "" {
		t.Fatalf("status: %+v", v)
	}
}

// with no mode, neither a reconnect nor a wake puts tor on the network.
// the mode, once there, does
func TestNoModeNoNetwork(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	unknownMode(t)
	f := overlapRig(t)
	f.slow.Store(0)
	on := func() bool {
		for _, c := range f.sent() {
			if strings.Contains(c, "DISABLENETWORK=0") {
				return true
			}
		}
		return false
	}
	if r := reconnectNow(); r != errNoMode {
		t.Fatalf("reconnect: %q", r)
	}
	if r := torResume(); r != errNoMode {
		t.Fatalf("wake: %q", r)
	}
	if on() {
		t.Fatalf("tor went on the network with no mode: %v", f.sent())
	}
	if r := restoreBridgeMode(bmDirect, ""); r != "ok" {
		t.Fatalf("restore: %q", r)
	}
	deadline := time.Now().Add(5 * time.Second)
	for !on() && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	endsOnTheNetwork(t, f)
}
