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
// socket dials anyway. while the process lives nobody moves in or out, not
// on a runner started again either, and a place a delete frees stays empty:
// a socket opening on one address as another closes would show a public
// relay that the two are one phone. someone just added is live until the
// next start.

import (
	"log"
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

// the round while our relay is down: what reaches only the public relays
// then comes within minutes. each address still keeps its own times
var sweepEveryDown = 10 * time.Minute

// our relay counts as down once none of its entries has answered for this
// long, sleep included, and its attempts have failed for ownFailSpan while
// the public relays answer. faster public reads only help when those do,
// and a wake whose circuits come back slowly fails everywhere at once
var ownDownAfter = 10 * time.Minute

// how long ours fails while a public relay answers. an onion circuit can
// take a minute longer than an exit one at a wake
var ownFailSpan = 2 * time.Minute

// a public relay answering this lately says the route works
var pubAnswerRecent = 2 * time.Minute

// the list waits until no address new to the run has joined for this long:
// at a start the app listens on everyone in one go, and the turns may come
// at once. never longer than liveSettleMax from the run's start
var liveSettle = 3 * time.Second

var liveSettleMax = 30 * time.Second

func sweepRound() time.Duration {
	liveMu.Lock()
	defer liveMu.Unlock()
	if ownDown {
		return sweepEveryDown
	}
	return sweepEvery
}

type liveAddr struct {
	// when it last brought something, unix seconds, 0 for never
	heard int64
}

// an address's place in a run: 1 live on the public relays, -1 not
type livePick struct {
	run    int
	chosen int8
}

var (
	liveMu    sync.Mutex
	liveAddrs = map[string]*liveAddr{}
	// the latest arrival or add per address, kept while its runner is
	// started again, as every one is on a mode switch. in memory only: on
	// disk it would say when each contact last wrote
	liveLast = map[string]int64{}
	// the run's choice per address, kept while its runner is started again
	livePicks = map[string]livePick{}
	// places the rank gave in this run. a delete gives none back
	liveTaken int
	// the last join of an address new to this run, when the run began, and
	// the run each address last joined in
	liveJoinedAt time.Time
	liveRunAt    time.Time
	liveJoinRun  = map[string]int{}
	// the app's pinned chats, by address. in memory only, as the app tells
	// it before it listens
	livePinned = map[string]bool{}
	// a mode switch starts a new run
	liveRun int
	// closed when the round changes, so a wait for a read looks again
	liveWakeC = make(chan struct{})
	// our relay: down as above. its last answer, the first failure since that
	// came while the public relays answered, and their last answer, by
	// ownClock, which counts sleep
	ownDown       bool
	ownKnown      bool
	ownAnsweredAt time.Duration
	ownFailedAt   time.Duration
	pubAnsweredAt time.Duration
)

// only a contact's address is ranked: first-contact, room and pair
// addresses stay live everywhere
func rankedLane(lane string) bool { return strings.HasPrefix(lane, laneEveryday+":") }

// a runner listens on rcvPk. fresh: someone just added, live until the
// next start, unless the address has a place in this run already. returns
// the handle it leaves with
func liveJoin(rcvPk string, heard int64, fresh bool) *liveAddr {
	liveMu.Lock()
	defer liveMu.Unlock()
	a := &liveAddr{heard: max(heard, liveLast[rcvPk])}
	if old := liveAddrs[rcvPk]; old != nil && old.heard > a.heard {
		a.heard = old.heard
	}
	liveAddrs[rcvPk] = a
	liveLast[rcvPk] = a.heard
	if liveRunAt.IsZero() {
		liveRunAt = time.Now()
	}
	// a runner started again holds no one up: a stranger's openers restart
	// one over and over
	first := liveJoinRun[rcvPk] != liveRun+1
	liveJoinRun[rcvPk] = liveRun + 1
	if p := livePicks[rcvPk]; p.run != liveRun || p.chosen == 0 {
		if fresh {
			livePicks[rcvPk] = livePick{run: liveRun, chosen: 1}
		} else if first {
			liveJoinedAt = time.Now()
		}
	}
	return a
}

// the address was let go of: nothing of when it was heard stays, and a
// take still under way on its runner writes nothing back. its place in the
// run stays given
func liveForget(rcvPk string) {
	liveMu.Lock()
	delete(liveLast, rcvPk)
	delete(liveAddrs, rcvPk)
	delete(livePicks, rcvPk)
	delete(liveJoinRun, rcvPk)
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

// the pinned chats' addresses. they rank the addresses not chosen yet, so
// from the next start or mode switch on
func livePin(rcvPks []string) {
	liveMu.Lock()
	livePinned = map[string]bool{}
	for _, k := range rcvPks {
		livePinned[k] = true
	}
	liveMu.Unlock()
}

// a mode switch: every runner starts again, and the list is chosen anew
// once they have joined, with the pins the app tells first. what failed the
// old way says nothing of our relay the new way
func liveNewRun() {
	liveMu.Lock()
	defer liveMu.Unlock()
	liveRun++
	liveTaken = 0
	liveJoinedAt, liveRunAt = time.Time{}, time.Now()
	ownKnown, ownAnsweredAt, ownFailedAt = true, ownClock(), 0
	if ownDown {
		ownDown = false
		liveWakeLocked()
	}
}

func liveWakeLocked() {
	close(liveWakeC)
	liveWakeC = make(chan struct{})
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

// whether rcvPk holds live sockets on the public relays: the run's choice
// once made, else where the rank puts it now
func publicLive(rcvPk string) bool {
	liveMu.Lock()
	defer liveMu.Unlock()
	if p := livePicks[rcvPk]; p.run == liveRun && p.chosen != 0 {
		return p.chosen > 0
	}
	return liveRankedLocked(rcvPk)
}

// rcvPk's place on the public relays in this run, chosen here the first time
// it is asked once the run's addresses have joined. wait: how long until it
// can be. live only while the run has places left, so the list never grows
// past the cap however the turns fall. the channel closes when the round
// changes, taken under the same lock so a change in between is not missed
func livePlace(rcvPk string) (live bool, wait time.Duration, wake <-chan struct{}) {
	liveMu.Lock()
	defer liveMu.Unlock()
	wake = liveWakeC
	if liveAddrs[rcvPk] == nil {
		// let go of: its runner is on the way out
		return false, 0, wake
	}
	if p := livePicks[rcvPk]; p.run == liveRun && p.chosen != 0 {
		return p.chosen > 0, 0, wake
	}
	if w := liveSettleLocked(); w > 0 {
		return false, w, wake
	}
	p := livePick{run: liveRun, chosen: -1}
	if liveRankedLocked(rcvPk) && liveTaken < publicLiveCap {
		p.chosen = 1
		liveTaken++
	}
	livePicks[rcvPk] = p
	return p.chosen > 0, 0, wake
}

// under liveMu. how long the run's list still waits: until no address new
// to the run joined for liveSettle, one at least, so the pins the app tells
// before it listens are in. liveSettleMax from the run's start at most
func liveSettleLocked() time.Duration {
	most := liveSettleMax - time.Since(liveRunAt)
	if most <= 0 {
		return 0
	}
	if liveJoinedAt.IsZero() {
		return min(liveSettle, most)
	}
	return min(liveSettle-time.Since(liveJoinedAt), most)
}

// rcvPk brought something at at. it ranks by it from the next run on, and
// any address not chosen yet in this one
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

// a public relay answered: the route works
func pubRelayAnswered() {
	wakeRouteProven()
	liveMu.Lock()
	pubAnsweredAt = ownClock()
	liveMu.Unlock()
}

// an entry of our relay answered: an eose, an event or a probe's reply
func ownRelayAnswered() {
	wakeRouteProven()
	liveMu.Lock()
	defer liveMu.Unlock()
	ownKnown, ownAnsweredAt, ownFailedAt = true, ownClock(), 0
	if ownDown {
		ownDown = false
		log.Println("nostr: our relay answers again, public relays read at the usual round")
		liveWakeLocked()
	}
}

// an attempt on an entry of our relay failed
func ownRelayFailed() {
	wakeCheck()
	liveMu.Lock()
	defer liveMu.Unlock()
	now := ownClock()
	if !ownKnown {
		ownKnown, ownAnsweredAt = true, now
	}
	// with no public relay answering either, it is the route or a wake, not
	// ours: the span starts again once one does
	if pubAnsweredAt == 0 || now-pubAnsweredAt > pubAnswerRecent {
		ownFailedAt = 0
		return
	}
	if ownFailedAt == 0 {
		ownFailedAt = now
	}
	if !ownDown && now-ownAnsweredAt >= ownDownAfter && now-ownFailedAt >= ownFailSpan {
		ownDown = true
		log.Println("nostr: our relay is down, public relays read more often")
		liveWakeLocked()
	}
}

// the phone slept: a span of failures begun before it ends there, so a
// public relay answering before ours at the wake finds no span to finish
func liveSlept() {
	liveMu.Lock()
	ownFailedAt = 0
	liveMu.Unlock()
}

// whether the round now is the one for our relay down
func ownRelayDown() bool {
	liveMu.Lock()
	defer liveMu.Unlock()
	return ownDown
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
// start does not dial every address on every public relay at once. the
// same as the round turns short: each address its own time in it
func firstSweepDelay() time.Duration {
	return time.Duration(mrand.Int64N(int64(sweepRound()) + 1))
}
