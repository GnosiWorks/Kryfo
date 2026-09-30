// SPDX-License-Identifier: GPL-3.0-or-later
package main

// relay traffic comes in lanes that must never be linked to each other: the
// main identity's sends, its contacts' addresses in a few lanes, its
// first-contact address, each burner room, each pair code, and the calls to
// our own services. tor keeps streams with different socks credentials on
// different circuits, so every lane dials under its own name and gets its own
// exit and its own way to an onion. outside private mode there is no circuit
// to keep apart and nothing changes.

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"strconv"
	"strings"
	"sync"
	"time"

	"fiatjaf.com/nostr"
)

// the main identity's sends, on a circuit none of its receive addresses use
const laneEveryday = "everyday"

// the contacts' receive addresses, hidden chats included, are spread over
// this many lanes by a hash of the address. one circuit carrying them all
// gets rate limited by relays that count sockets per exit, and when it dies
// every address goes deaf and reconnects in the same second.
const receiveLaneCount = 4

func receiveLaneAt(i int) string { return laneEveryday + ":" + strconv.Itoa(i) }

// one of n lanes by the first four bytes of the address's sha256, so an
// address lands on the same lane every time
func hashLane(rcvPk string, n int) string {
	h := sha256.Sum256([]byte(rcvPk))
	return receiveLaneAt(int(binary.BigEndian.Uint32(h[:4]) % uint32(n)))
}

// the lane a contact's receive address listens on. a var so the measurement
// test can map them another way.
var receiveLane = func(rcvPk string) string { return hashLane(rcvPk, receiveLaneCount) }

// the first-contact address is in the invite, so it never shares a circuit
// with a contact's address or a send
const laneFirstContact = "firstcontact"

// the main identity's lanes: its sends, its first-contact address and the
// contacts'
func mainLanes() []string {
	l := []string{laneEveryday, laneFirstContact}
	for i := 0; i < receiveLaneCount; i++ {
		l = append(l, receiveLaneAt(i))
	}
	return l
}

// the handle registry, people search and the badge service: a circuit of
// their own, apart from the ones that carry the contacts' addresses.
const laneServices = "services"

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

// a lane that is done with takes its socks name with it: a room that is
// gone, a first-contact address that was replaced
func dropLane(lane string) {
	laneMu.Lock()
	delete(laneNames, lane)
	laneMu.Unlock()
	cachedNostrClientMu.Lock()
	delete(cachedNostrClients, lane)
	cachedNostrClientMu.Unlock()
	pubCloseAll(lane)
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

// for the long-lived sockets: subscriptions, and the publish sockets a burst
// keeps. one-shot sockets close long before a ping would matter.
func subscribeRelayOptions() nostr.RelayOptions {
	if !modeNeedsTor() {
		return nostr.RelayOptions{}
	}
	return nostr.RelayOptions{PingInterval: torPingInterval, PongTimeout: torPongTimeout}
}
