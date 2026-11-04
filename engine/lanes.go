// SPDX-License-Identifier: GPL-3.0-or-later
package main

// relay traffic comes in lanes that must never be linked to each other: the
// main identity's sends, its contacts' addresses in batches of up to eight
// (batches.go), each hidden chat, its first-contact address, each burner
// room, each pair code, and the calls to our own services. tor keeps streams with different socks credentials on
// different circuits, so every lane dials under its own name and gets its own
// exit and its own way to an onion. outside private mode there is no circuit
// to keep apart and nothing changes.

import (
	"crypto/rand"
	"encoding/hex"
	"strconv"
	"strings"
	"sync"
	"time"

	"fiatjaf.com/nostr"
)

// the main identity's sends, on a circuit none of its receive addresses use
const laneEveryday = "everyday"

// the contacts' receive addresses go in batches of their identity, each on
// lanes of its own (batches.go). receiveLane is a var so the measurement
// tests can map them another way.
var receiveLane = func(ident int, rcvPk string) string {
	set := contactSet(ident)
	return batchLane(set, batchOf(set, rcvPk))
}

// a hidden chat's address: a lane of its own, over tor on every route
// (laneKeepsTor), so it shares no socket and no circuit with an everyday
// or a decoy address, nor with another hidden chat. the lane is named by a
// number, never by the address
const laneHidden = "hidden"

var (
	hiddenLaneMu sync.Mutex
	hiddenLanes  = map[string]string{}
)

func hiddenLane(rcvPk string) string {
	hiddenLaneMu.Lock()
	defer hiddenLaneMu.Unlock()
	if l, ok := hiddenLanes[rcvPk]; ok {
		return l
	}
	l := laneHidden + ":" + strconv.Itoa(len(hiddenLanes))
	hiddenLanes[rcvPk] = l
	return l
}

// a hidden chat's lane as the top-up's file keeps it: by a keyed hash of
// its address, since a lane's number holds for this process alone
func hiddenLaneTag(lane string) string {
	if laneKind(lane) != laneHidden {
		return lane
	}
	hiddenLaneMu.Lock()
	defer hiddenLaneMu.Unlock()
	for pk, l := range hiddenLanes {
		if l == lane {
			return laneHidden + ":#" + knockID(pk)
		}
	}
	return lane
}

// and back: the address's lane in this process, or a lane of its own for
// one not listened on now. never the everyday sends' lane
func hiddenLaneFromTag(tag string) string {
	id, ok := strings.CutPrefix(tag, laneHidden+":#")
	if !ok {
		return tag
	}
	hiddenLaneMu.Lock()
	defer hiddenLaneMu.Unlock()
	for pk, l := range hiddenLanes {
		if knockID(pk) == id {
			return l
		}
	}
	return laneHidden + ":t" + id
}

// the first-contact address is in the invite, so it never shares a circuit
// with a contact's address or a send
const laneFirstContact = "firstcontact"

// a first contact to someone else's first-contact address: apart from the
// everyday sends, since that address may carry a public handle
const laneHello = "hello"

// the main identity's lanes that are there from the start: its sends, its
// first contacts and its first-contact address. the contacts' batches get
// theirs as they are listened on
func mainLanes() []string {
	return []string{laneEveryday, laneHello, laneFirstContact}
}

// the handle registry, people search and the badge service: a circuit of
// their own, apart from the ones that carry the contacts' addresses.
const laneServices = "services"

// this phone's own handle: its check, claim, release, listing and lookup,
// signed by the identity key or naming it. apart from people search and
// others' handles, so the registry cannot tie a search to the handle
// that made it
const laneOwnHandle = "ownhandle"

// gif search and its pictures: apart from the services lane too, so the gif
// relay cannot tie a search to a handle lookup or a badge receipt
const laneGifs = "gifs"

// the update check: apart from link previews and every other lane, so the
// site sees a check and nothing it could tie to it
const laneUpdate = "update"

// moat, the tor project's bridge service: a socks name of its own like
// every other lane
const laneMoat = "moat"

// a room is a name that exists only inside the room.
func roomLane(pubHex string) string { return "room:" + pubHex }

// the opener addresses of an identity's device pairs (address_device.go):
// apart from its seeded addresses, as its first-contact address is
func opnLane(ident int) string { return "opn:" + strconv.Itoa(ident) }

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

// every lane takes a new socks name, so its next streams take new circuits
func freshLaneNames() {
	laneMu.Lock()
	laneNames = map[string]string{}
	laneMu.Unlock()
}

// a lane that is done with takes its socks name with it: a room that is
// gone, a first-contact address that was replaced
func dropLane(lane string) {
	laneMu.Lock()
	delete(laneNames, lane)
	laneMu.Unlock()
	cachedNostrClientMu.Lock()
	delete(cachedNostrClients, lane)
	// the lane's client from tor's socks port too (knock.go), or the next
	// one on this lane would ride the old circuit
	delete(cachedNostrClients, "tor:"+lane)
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

// the same for relay u: a backup goes through tor on every route
func relayOptionsFor(u string) nostr.RelayOptions {
	if isBackup(u) {
		return nostr.RelayOptions{PingInterval: torPingInterval, PongTimeout: torPongTimeout}
	}
	return subscribeRelayOptions()
}
