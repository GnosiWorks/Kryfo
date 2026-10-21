// SPDX-License-Identifier: GPL-3.0-or-later
package main

// why tor was bounced or given new circuits lately, for the transport
// screen. a release build logs nothing, and "tor drops" is only readable
// from the phone with this. in memory only, a kind and a time: no address,
// no network name, gone with the process

import (
	"sync"
	"time"
)

// what made a reconnect, as the transport screen shows it
const (
	whyNetwork  = "network change"
	whyByHand   = "by hand"
	whyRelays   = "no relay answered"
	whyStall    = "bootstrap stalled"
	whyTorOff   = "tor was off"
	whyDialer   = "no relay in 3 minutes"
	whyMode     = "back on onion"
	whyBridges  = "bridge change"
	whyAuto     = "automatic"
	whyNoNet    = "no network"
	whyCircuits = "new circuits"
	whyOther    = "other"
)

type bounceNote struct {
	At  int64  `json:"at"`
	Why string `json:"why"`
}

// the most kept, newest last
const bounceKeep = 12

var (
	bounceMu    sync.Mutex
	bounceNotes []bounceNote
	bounceTotal = map[string]int{}
)

func noteBounce(why string) {
	if why == "" {
		why = whyOther
	}
	bounceMu.Lock()
	defer bounceMu.Unlock()
	bounceNotes = append(bounceNotes, bounceNote{time.Now().Unix(), why})
	if len(bounceNotes) > bounceKeep {
		bounceNotes = append([]bounceNote(nil), bounceNotes[len(bounceNotes)-bounceKeep:]...)
	}
	bounceTotal[why]++
}

// the newest first, and how many of each kind this process made
func bounceSnapshot() ([]bounceNote, map[string]int) {
	bounceMu.Lock()
	defer bounceMu.Unlock()
	out := make([]bounceNote, 0, len(bounceNotes))
	for i := len(bounceNotes) - 1; i >= 0; i-- {
		out = append(out, bounceNotes[i])
	}
	tot := make(map[string]int, len(bounceTotal))
	for k, v := range bounceTotal {
		tot[k] = v
	}
	return out, tot
}
