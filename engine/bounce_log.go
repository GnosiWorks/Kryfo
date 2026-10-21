// SPDX-License-Identifier: GPL-3.0-or-later
package main

// why tor was bounced lately, for the transport screen: a kind and a time, in memory only

import (
	"sync"
	"time"
)

// what made a reconnect. codes: the app words them in the person's language
const (
	whyNetwork  = "network"
	whyByHand   = "hand"
	whyRelays   = "relays"
	whyStall    = "stall"
	whyTorOff   = "tor_off"
	whyDialer   = "dialer"
	whyMode     = "onion"
	whyBridges  = "bridges"
	whyAuto     = "auto"
	whyNoNet    = "offline"
	whyCircuits = "circuits"
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
