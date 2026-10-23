// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a big inbox keeps live sockets on the public relays only for a few
// contact addresses: the pinned chats first, then the ones heard from most
// lately. every other one listens live on our relay and reads each public
// relay now and then. a public relay turns away a pile of sockets from one
// exit, and every socket costs pings, probes and memory on the phone and a
// stream on tor.
//
// the list is chosen once a run, at a start or a mode switch, when every
// socket dials anyway. while the process lives nobody moves in or out: a
// socket opening on one address as another closes would show a public
// relay that the two are one phone. someone just added is live until the
// next start.

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
	// the run it joined in
	run int
	// the run's choice: 0 not made yet, 1 live on the public relays, -1 not
	chosen int8
}

var (
	liveMu    sync.Mutex
	liveAddrs = map[string]*liveAddr{}
	// the latest arrival or add per address, kept while its runner is
	// started again, as every one is on a mode switch. in memory only: on
	// disk it would say when each contact last wrote
	liveLast = map[string]int64{}
	// the app's pinned chats, by address. in memory only, as the app tells
	// it before it listens
	livePinned = map[string]bool{}
	// a mode switch starts a new run
	liveRun int
)

// only a contact's address is ranked: first-contact, room and pair
// addresses stay live everywhere
func rankedLane(lane string) bool { return strings.HasPrefix(lane, laneEveryday+":") }

// a runner listens on rcvPk. fresh: someone just added, live until the
// next start. returns the handle it leaves with
func liveJoin(rcvPk string, heard int64, fresh bool) *liveAddr {
	liveMu.Lock()
	defer liveMu.Unlock()
	a := &liveAddr{heard: max(heard, liveLast[rcvPk]), run: liveRun}
	if old := liveAddrs[rcvPk]; old != nil && old.heard > a.heard {
		a.heard = old.heard
	}
	if fresh {
		a.chosen = 1
	}
	liveAddrs[rcvPk] = a
	liveLast[rcvPk] = a.heard
	return a
}

// the address was let go of: nothing of when it was heard stays, and a
// take still under way on its runner writes nothing back
func liveForget(rcvPk string) {
	liveMu.Lock()
	delete(liveLast, rcvPk)
	delete(liveAddrs, rcvPk)
	delete(livePinned, rcvPk)
	liveMu.Unlock()
}

// a runner started again in its place keeps the address
func liveLeave(rcvPk string, a *liveAddr) {
	liveMu.Lock()
	if liveAddrs[rcvPk] == a {
		delete(liveAddrs, rcvPk)
	}
	liveMu.Unlock()
}

// the pinned chats' addresses, for the runs from here on
func livePin(rcvPks []string) {
	liveMu.Lock()
	livePinned = map[string]bool{}
	for _, k := range rcvPks {
		livePinned[k] = true
	}
	liveMu.Unlock()
}

// a mode switch: every runner starts again, and the list is chosen anew
func liveNewRun() {
	liveMu.Lock()
	liveRun++
	liveMu.Unlock()
}

// under liveMu. pinned first, then the latest heard, the address breaking
// ties, so every runner of an address gets the same answer
func liveRankedLocked(rcvPk string) bool {
	a := liveAddrs[rcvPk]
	if a == nil || len(liveAddrs) <= publicLiveCap {
		return true
	}
	if publicLiveCap <= 0 {
		return false
	}
	pin := livePinned[rcvPk]
	ahead := 0
	for k, o := range liveAddrs {
		op := livePinned[k]
		if (op && !pin) || (op == pin && (o.heard > a.heard || (o.heard == a.heard && k < rcvPk))) {
			ahead++
			if ahead >= publicLiveCap {
				return false
			}
		}
	}
	return true
}

// under liveMu. the run's choice once made, else where the rank puts it now
func liveNowLocked(rcvPk string) bool {
	if a := liveAddrs[rcvPk]; a != nil && a.chosen != 0 {
		return a.chosen > 0
	}
	return liveRankedLocked(rcvPk)
}

// whether rcvPk holds live sockets on the public relays
func publicLive(rcvPk string) bool {
	liveMu.Lock()
	defer liveMu.Unlock()
	return liveNowLocked(rcvPk)
}

// as publicLive, with a channel closed when the wait for a read should
// look again: none yet
func livePlace(rcvPk string) (bool, <-chan struct{}) {
	return publicLive(rcvPk), nil
}

// the run's choice for rcvPk, made the first time its turn comes to dial a
// public relay: by then the start's other addresses have joined. live only
// while the run's list has room, so it holds the cap however the turns fall
func liveChoose(rcvPk string) bool {
	liveMu.Lock()
	defer liveMu.Unlock()
	a := liveAddrs[rcvPk]
	if a == nil {
		return true
	}
	if a.chosen == 0 {
		a.chosen = -1
		if liveRankedLocked(rcvPk) {
			n := 0
			for _, o := range liveAddrs {
				if o.run == a.run && o.chosen > 0 {
					n++
				}
			}
			if n < publicLiveCap {
				a.chosen = 1
			}
		}
	}
	return a.chosen > 0
}

// rcvPk brought something at at. it ranks by it from the next run on
func liveHeard(rcvPk string, at int64) {
	liveMu.Lock()
	defer liveMu.Unlock()
	a := liveAddrs[rcvPk]
	if a == nil {
		return
	}
	liveLast[rcvPk] = max(liveLast[rcvPk], at)
	a.heard = max(a.heard, at)
}

// the next read of a public relay, a fourth either way so they spread out
func sweepDelay() time.Duration {
	every := sweepRound()
	return every*3/4 + time.Duration(mrand.Int64N(int64(every/2)+1))
}

// a read that ended before its catch-up did is tried again within the
// round, an eighth to a quarter of it later, this many times in a row
const sweepRetries = 2

func sweepRetryDelay() time.Duration {
	every := sweepRound()
	return every/8 + time.Duration(mrand.Int64N(int64(every/8)+1))
}

// the first read after a start lands anywhere in the first round, so a
// start does not dial every address on every public relay at once
func firstSweepDelay() time.Duration {
	return time.Duration(mrand.Int64N(int64(sweepRound()) + 1))
}
