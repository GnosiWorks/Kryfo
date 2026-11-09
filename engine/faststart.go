// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a start's first turns. a socket that dials through tor waits until this
// process's tor is up before it takes its turn, so the turns spread from
// the moment tor can carry them: dialled earlier, tor held them all and let
// them go together at 100%, every batch in the same instant. and the batch
// that holds the most recent chats takes the start's free turn on every
// relay, so the chats on top of the list are caught up first. every other
// socket draws its turn over the whole spread, as before: per relay there
// is still one socket at once and the rest at their own times.

import (
	"context"
	"encoding/json"
	"log"
	"sync"
	"sync/atomic"
	"time"

	"fiatjaf.com/nostr"
)

import "C"

// the longest a start waits for tor before its sockets dial anyway, unless
// tor still says it is climbing: then it looks again every startGateLook,
// up to startGateLongest. a dial before 100% gains nothing, tor holds it
// and lets the start's sockets go together once it is up
var (
	startGateMost    = 90 * time.Second
	startGateLook    = 15 * time.Second
	startGateLongest = 10 * time.Minute
)

var startGate struct {
	sync.Mutex
	// nil once open
	c     chan struct{}
	armed bool
	at    time.Time
}

// at the first start of tor in this process
func armStartGate() {
	startGate.Lock()
	defer startGate.Unlock()
	if startGate.armed {
		return
	}
	startGate.armed = true
	c := make(chan struct{})
	startGate.c = c
	startGate.at = time.Now()
	time.AfterFunc(startGateMost, func() { capStartGate(c) })
}

// the cap of gate c: open, unless tor's own watcher says it is still on
// its way
func capStartGate(c chan struct{}) {
	startGate.Lock()
	at, gone := startGate.at, startGate.c != c
	startGate.Unlock()
	if gone {
		return
	}
	if torStillClimbing() && time.Since(at) < startGateLongest {
		time.AfterFunc(startGateLook, func() { capStartGate(c) })
		return
	}
	startGate.Lock()
	defer startGate.Unlock()
	if startGate.c == c {
		close(c)
		startGate.c = nil
	}
}

// tor's bootstrap watcher runs, its control port answers and it is under
// 100%: its percent is current, and no circuit is there to dial on
var torStillClimbing = func() bool {
	if atomic.LoadInt32(&bootstrapWatching) == 0 || ctrlSilentCount() > 0 || torIsPaused() {
		return false
	}
	statusMu.RLock()
	defer statusMu.RUnlock()
	return bootstrapPct < 100
}

// tor is up, or waited for long enough
func openStartGate() {
	startGate.Lock()
	defer startGate.Unlock()
	if startGate.c != nil {
		close(startGate.c)
		startGate.c = nil
	}
}

// closed once the start's sockets may dial, nil when they may now
func startGateChan() <-chan struct{} {
	startGate.Lock()
	defer startGate.Unlock()
	if startGate.c == nil {
		return nil
	}
	return startGate.c
}

// whether relayClientFor(lane, u) dials through tor
func relayOverTor(lane, u string) bool {
	if isBackup(u) || (laneKeepsTor(lane) && !clearForTests(u)) {
		return true
	}
	if currentMode() != modePrivate {
		nostrMu.Lock()
		urls := nostrRelays
		nostrMu.Unlock()
		return isOnion(u) || (storeOf(urls, u) == "" && !clearForTests(u))
	}
	return modeNeedsTor()
}

// the batch that goes first at the start, and the kick it goes in
var startFirst struct {
	sync.Mutex
	lane string
	kick chan struct{}
}

// under startFirst: the start's kick, the one the process's first turn is
// drawn under
func startKickLocked(kc chan struct{}) chan struct{} {
	if startFirst.kick == nil {
		startFirst.kick = kc
	}
	return startFirst.kick
}

// lane's turn under kick kc is at once: it is the start's first batch and
// kc the start's kick
func startFirstFor(lane string, kc chan struct{}) bool {
	startFirst.Lock()
	defer startFirst.Unlock()
	k := startKickLocked(kc)
	return startFirst.lane != "" && lane == startFirst.lane && k == kc
}

// the start's free turn is the first batch's: under the start's kick no
// other socket goes at once
func startFirstHolds(kc chan struct{}) bool {
	startFirst.Lock()
	defer startFirst.Unlock()
	k := startKickLocked(kc)
	return startFirst.lane != "" && k == kc
}

// kc is the start's kick: the one the process's first turn is drawn under
func isStartKick(kc chan struct{}) bool {
	startFirst.Lock()
	defer startFirst.Unlock()
	return startKickLocked(kc) == kc
}

// when the process began, by the wall clock so a sleep counts
var procStart = time.Now().Round(0)

// how long after the process began a runner's first ask is the start's:
// past tor's longest climb and the start's turns. one made hours later in a
// process never kicked since is no start
var startMadeFor = startGateLongest + 5*time.Minute

// kc is the start's kick, or would be: no turn was drawn yet, and the
// process began lately. sets nothing
func startKickPeek(kc chan struct{}) bool {
	if time.Now().Round(0).Sub(procStart) > startMadeFor {
		return false
	}
	startFirst.Lock()
	defer startFirst.Unlock()
	return startFirst.kick == nil || startFirst.kick == kc
}

// the start's first batch, "" for none
func startFirstLane() string {
	startFirst.Lock()
	defer startFirst.Unlock()
	return startFirst.lane
}

// the chats on top of the list, the most recent first, everyday chats
// only, as HaloNostrPinned takes them: the batch that holds most of them
// goes first at the start. a chat with no batch yet is passed over, none
// is given one here
//
//export HaloNostrFirstChats
func HaloNostrFirstChats(cPeersJSON *C.char) *C.char {
	var peers []identPeer
	if err := json.Unmarshal([]byte(goStr(cPeersJSON)), &peers); err != nil {
		return C.CString("error: bad list")
	}
	noteFirstChats(peers)
	return C.CString("ok")
}

func noteFirstChats(peers []identPeer) {
	count := map[string]int{}
	rank := map[string]int{}
	for i, h := range peers {
		c, _, err := pairArg(h.I, h.arg())
		if err != nil || c.dev != nil {
			continue
		}
		_, rcvPk, err := c.rcvAddress()
		if err != nil {
			continue
		}
		set := contactSet(c.ident)
		n, ok := batchFind(set, rcvPk)
		if !ok {
			continue
		}
		lane := batchLane(set, n)
		count[lane]++
		if _, seen := rank[lane]; !seen {
			rank[lane] = i
		}
	}
	best := ""
	for lane, k := range count {
		if best == "" || k > count[best] || (k == count[best] && rank[lane] < rank[best]) {
			best = lane
		}
	}
	startFirst.Lock()
	defer startFirst.Unlock()
	// told once the start's turns began, it waits for the next start
	if startFirst.kick != nil {
		return
	}
	startFirst.lane = best
}

// the hello lane's circuits built ahead while a card is on screen, to be
// scanned or shown: the first hello and the answer to it then go on
// circuits tor already has, our onion relay's rendezvous one included,
// instead of building them after the scan. a socket to each relay, let go
// of once it is open: nothing is asked or sent on it. at most once in
// warmHelloEvery
var (
	warmHelloEvery = 2 * time.Minute
	warmHelloAt    atomic.Int64
)

func warmHello() {
	now := time.Now()
	if last := warmHelloAt.Load(); last != 0 && now.Sub(time.Unix(0, last)) < warmHelloEvery {
		return
	}
	warmHelloAt.Store(now.UnixNano())
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		urls := relaysInUse(ctx)
		cancel()
		for _, u := range urls {
			go func(u string) {
				client, err := relayClientFor(laneHello, u)
				if err != nil {
					return
				}
				dctx, dcancel := relayDialCtx(context.Background(), u)
				defer dcancel()
				r := nostr.NewRelay(dctx, u, relayOptionsFor(u))
				if err := r.ConnectWithClient(dctx, client); err != nil {
					log.Printf("nostr: hello lane not warmed on %s: %v", u, err)
					return
				}
				r.Close()
			}(u)
		}
	}()
}

// a card is on screen, to scan or to show: the hello lane is warmed
//
//export HaloNostrWarmHello
func HaloNostrWarmHello() *C.char {
	warmHello()
	return C.CString("ok")
}
