// SPDX-License-Identifier: GPL-3.0-or-later
package main

// how tor connects is known only once the app has said. until then tor
// stays off the network: an unknown mode never means direct, as someone
// who picked a bridge because tor is risky where they are would otherwise
// reach tor directly on a cold start.

import "C"

import (
	"encoding/json"
	"log"
	"sync"
	"sync/atomic"
)

var (
	// set by the boot restore or a pick
	modeSet atomic.Bool
	// one mode change at a time, so a restore never lands over a pick
	modeMu sync.Mutex
	// the boot restore was asked for, taken or not
	restoreUsed atomic.Bool
	// bumped whenever the wanted bridge lines change; tor holds the lines
	// of linesApplied, by its start args or a bridge SETCONF that took
	linesGen     atomic.Int64
	linesApplied atomic.Int64
	// automatic's own direct step is in place: the one time automatic goes
	// out without bridges
	autoDirectOK atomic.Bool
)

const (
	errNoMode   = "error: no bridge mode yet"
	errPTDown   = "error: bridges could not start"
	errNoConf   = "error: bridges not applied"
	errAutoWait = "error: automatic has no way in yet"
	errOffline  = "error: no network"
	codePTDown  = "pt_failed"
	codeNoMode  = "no_mode"
	codeNoConf  = "not_applied"
	codeWait    = "auto_wait"
)

func bridgeModeKnown() bool { return modeSet.Load() }

// the wanted lines changed: tor holds them only once told
func noteLinesChanged() {
	linesGen.Add(1)
	autoDirectOK.Store(false)
}

func bridgesApplied() bool { return linesApplied.Load() == linesGen.Load() }

// tor holds the lines of gen now. a late answer for older lines never
// takes the place of a newer one
func noteLinesApplied(gen int64) {
	for {
		cur := linesApplied.Load()
		if gen <= cur || linesApplied.CompareAndSwap(cur, gen) {
			return
		}
	}
}

// a check that useLines is never seen with the mode already known, for the
// tests
var useLinesHook func()

// why tor may not go on the network now, "" when it may. without bridges
// only when the mode is direct, or automatic's own direct step runs, and
// with bridges only once tor really holds them
func networkHold() string {
	if !bridgeModeKnown() {
		return errNoMode
	}
	if bridgesEnabled() {
		if ptDown.Load() {
			return errPTDown
		}
		if !bridgesApplied() {
			return errNoConf
		}
		return ""
	}
	if mode, _, _ := bridgeMode(); mode == bmAuto && !autoDirectOK.Load() {
		return errAutoWait
	}
	return ""
}

// the code the status line shows for a hold, "" for none
func holdCode() string {
	switch networkHold() {
	case errNoMode:
		return codeNoMode
	case errPTDown:
		return codePTDown
	case errNoConf:
		return codeNoConf
	case errAutoWait:
		return codeWait
	}
	return ""
}

// the mode as the app kept it, handed over at start before tor runs, as
// for HaloSetBridgeMode. it is taken with a decoy open too: a decoy shows
// automatic, and tor underneath keeps what the person picked. asked for
// once, and never over a mode already set. one the engine cannot take
// becomes automatic without tor alone, never direct. "ok" or "error: <why>".
//
//export HaloRestoreBridgeMode
func HaloRestoreBridgeMode(cMode, cJSON *C.char) *C.char {
	return C.CString(restoreBridgeMode(goStr(cMode), goStr(cJSON)))
}

func restoreBridgeMode(mode, raw string) string {
	modeMu.Lock()
	defer modeMu.Unlock()
	if restoreUsed.Swap(true) {
		return "error: restore used"
	}
	if bridgeModeKnown() {
		return "error: mode already set"
	}
	r := applyBridgeMode(mode, raw)
	if r != "ok" {
		log.Printf("bridges: the kept mode was refused (%s), automatic without tor alone", r)
		if fb := applyBridgeMode(bmAuto, fallbackOpts(raw)); fb != "ok" {
			log.Printf("bridges: fallback refused: %s", fb)
		}
	}
	return r
}

// automatic without tor alone, keeping the person's yes or no to the tor
// project and their country from what was kept, when that can be read
func fallbackOpts(raw string) string {
	var o modeOpts
	_ = json.Unmarshal([]byte(raw), &o)
	f := modeOpts{SkipDirect: true, Country: o.Country, Webtunnel: o.Webtunnel}
	switch o.Consent {
	case "yes", "ask":
		f.Consent = o.Consent
	}
	b, _ := json.Marshal(f)
	return string(b)
}
