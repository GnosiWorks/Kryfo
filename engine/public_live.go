// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a big inbox keeps live sockets on the public relays only for the contact
// addresses heard from most lately. every other one listens live on our
// relay and reads each public relay now and then. a public relay turns
// away a pile of sockets from one exit, and every socket costs pings,
// probes and memory on the phone and a stream on tor.

import (
	mrand "math/rand/v2"
	"strings"
	"sync"
	"time"
)

// how many contact addresses keep a live socket on each public relay.
// under liveMu, a var for the tests
var publicLiveCap = 24

// how often an address past the cap reads each public relay. our relay
// carries it live meanwhile, so this only matters while ours is down.
// under liveMu
var sweepEvery = time.Hour

func sweepRound() time.Duration {
	liveMu.Lock()
	defer liveMu.Unlock()
	return sweepEvery
}

type liveAddr struct {
	// when it last brought something, unix seconds, 0 for never
	heard int64
}

var (
	liveMu    sync.Mutex
	liveAddrs = map[string]*liveAddr{}
)

// only a contact's address is ranked: first-contact, room and pair
// addresses stay live everywhere
func rankedLane(lane string) bool { return strings.HasPrefix(lane, laneEveryday+":") }

// a runner listens on rcvPk. returns the handle it leaves with
func liveJoin(rcvPk string, heard int64) *liveAddr {
	liveMu.Lock()
	defer liveMu.Unlock()
	a := &liveAddr{heard: heard}
	if old := liveAddrs[rcvPk]; old != nil && old.heard > heard {
		a.heard = old.heard
	}
	liveAddrs[rcvPk] = a
	return a
}

// a runner started again in its place keeps the address
func liveLeave(rcvPk string, a *liveAddr) {
	liveMu.Lock()
	if liveAddrs[rcvPk] == a {
		delete(liveAddrs, rcvPk)
	}
	liveMu.Unlock()
}

// under liveMu. the latest heard first, the address breaking ties, so
// every runner of an address gets the same answer
func liveRankedLocked(rcvPk string) bool {
	a := liveAddrs[rcvPk]
	if a == nil || len(liveAddrs) <= publicLiveCap {
		return true
	}
	ahead := 0
	for k, o := range liveAddrs {
		if o.heard > a.heard || (o.heard == a.heard && k < rcvPk) {
			ahead++
			if ahead >= publicLiveCap {
				return false
			}
		}
	}
	return true
}

// whether rcvPk keeps live sockets on the public relays
func publicLive(rcvPk string) bool {
	liveMu.Lock()
	defer liveMu.Unlock()
	return liveRankedLocked(rcvPk)
}

// rcvPk brought something at at
func liveHeard(rcvPk string, at int64) {
	liveMu.Lock()
	defer liveMu.Unlock()
	if a := liveAddrs[rcvPk]; a != nil && at > a.heard {
		a.heard = at
	}
}

// the next read of a public relay, a fourth either way so they spread out
func sweepDelay() time.Duration {
	every := sweepRound()
	return every*3/4 + time.Duration(mrand.Int64N(int64(every/2)+1))
}

// the first read after a start lands anywhere in the first round, so a
// start does not dial every address on every public relay at once
func firstSweepDelay() time.Duration {
	return time.Duration(mrand.Int64N(int64(sweepRound()) + 1))
}
