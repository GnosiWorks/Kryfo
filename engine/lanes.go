// SPDX-License-Identifier: GPL-3.0-or-later
package main

// relay traffic comes in lanes that must never be linked to each other: the
// everyday identity, each burner room, each pair code. tor keeps streams with
// different socks credentials on different circuits, so every lane dials
// under its own name and gets its own exit and its own way to an onion.
// outside private mode there is no circuit to keep apart and nothing changes.

import (
	"crypto/rand"
	"encoding/hex"
	"strings"
	"sync"
	"time"

	"fiatjaf.com/nostr"
)

// everything that speaks for the main identity: its contacts, hidden chats
// included, its first-contact address, its sends, handles and badges.
const laneEveryday = "everyday"

// a room is a name that exists only inside the room.
func roomLane(pubHex string) string { return "room:" + pubHex }

// a pair code's key comes from the code alone and belongs to nobody, so
// looking one up says nothing about who looked.
func pairLane(pk string) string { return "pair:" + pk }

// only the kind goes in a log line, never the key behind it
func laneKind(lane string) string {
	if i := strings.IndexByte(lane, ':'); i >= 0 {
		return lane[:i]
	}
	return lane
}

// the socks name for each lane: random and new with every process, so no key
// ever reaches tor, its logs or its control events.
var (
	laneMu    sync.Mutex
	laneNames = map[string]string{}
)

func laneName(lane string) string {
	laneMu.Lock()
	defer laneMu.Unlock()
	if n, ok := laneNames[lane]; ok {
		return n
	}
	b := make([]byte, 16)
	rand.Read(b)
	n := hex.EncodeToString(b)
	laneNames[lane] = n
	return n
}

// a room that is gone takes its lane with it
func dropLane(lane string) {
	laneMu.Lock()
	delete(laneNames, lane)
	laneMu.Unlock()
	cachedNostrClientMu.Lock()
	delete(cachedNostrClients, lane)
	cachedNostrClientMu.Unlock()
}

// over tor a pong often takes longer than the library's 800ms, and three late
// ones in a row close the socket, which then fetches its window again. its
// 19s ping on every socket is also most of what an idle phone sends. 90s
// stays under the 100s some proxies give an idle websocket. the direct
// modes keep the library's defaults.
var (
	torPingInterval = 90 * time.Second
	torPongTimeout  = 20 * time.Second
)

// for the long-lived subscription sockets. one-shot sockets close long before
// a ping would matter.
func subscribeRelayOptions() nostr.RelayOptions {
	if !modeNeedsTor() {
		return nostr.RelayOptions{}
	}
	return nostr.RelayOptions{PingInterval: torPingInterval, PongTimeout: torPongTimeout}
}
