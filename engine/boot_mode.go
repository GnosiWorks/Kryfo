// SPDX-License-Identifier: GPL-3.0-or-later
package main

// how tor connects is known only once the app has said. until then tor
// stays off the network: an unknown mode never means direct, as someone
// who picked a bridge because tor is risky where they are would otherwise
// reach tor directly on a cold start.

import "C"

import (
	"sync"
	"sync/atomic"
)

var (
	// set by the boot restore, a pick, or the old HaloSetBridges
	modeSet atomic.Bool
	// one mode change at a time, so a restore never lands over a pick
	modeMu sync.Mutex
)

const errNoMode = "error: no bridge mode yet"

func bridgeModeKnown() bool { return modeSet.Load() }

// the mode as the app kept it, handed over at start before tor runs, as
// for HaloSetBridgeMode. it is taken with a decoy open too: a decoy shows
// automatic, and tor underneath keeps what the person picked. once, and
// never over a mode already set. "ok" or "error: <why>".
//
//export HaloRestoreBridgeMode
func HaloRestoreBridgeMode(cMode, cJSON *C.char) *C.char {
	return C.CString(restoreBridgeMode(goStr(cMode), goStr(cJSON)))
}

func restoreBridgeMode(mode, raw string) string {
	modeMu.Lock()
	defer modeMu.Unlock()
	if bridgeModeKnown() {
		return "error: mode already set"
	}
	return applyBridgeMode(mode, raw)
}
