// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"strconv"
	"testing"
	"time"
)

// the addresses of open connections, one set per connection
func connAddrs(r *relayStandIn) []map[string]bool {
	var out []map[string]bool
	for _, c := range r.snapshot() {
		if c.closed.IsZero() && len(c.addrs) > 0 {
			out = append(out, c.addrs)
		}
	}
	return out
}

// every live req names at most hubMaxAddrs addresses
func checkLiveReqs(t *testing.T, r *relayStandIn) {
	t.Helper()
	for _, c := range r.snapshot() {
		for _, q := range c.reqs {
			if n := len(q.filter.Tags["p"]); n > hubMaxAddrs {
				t.Fatalf("a req named %d addresses, the most is %d", n, hubMaxAddrs)
			}
			if len(q.filter.Tags["p"]) > 1 && !q.filter.LimitZero {
				t.Fatalf("a req for stored wraps named %d addresses", len(q.filter.Tags["p"]))
			}
		}
	}
}

// an empty batch book for the test, the one before after it
func freshBatches(t *testing.T) {
	t.Helper()
	batchMu.Lock()
	old := batches
	batches = &batchBook{dir: savedDataDir(), every: map[string]batchPlace{}, top: map[string]batchTop{}, hide: map[string]bool{}}
	batches.key, batches.idKey = bookKeys()
	batchMu.Unlock()
	t.Cleanup(func() {
		batchMu.Lock()
		batches = old
		batchMu.Unlock()
	})
}

func TestABatchsAddressesShareOneSocket(t *testing.T) {
	own, pub := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	freshInbox(t)
	freshBatches(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer func() {
		cancel()
		runnersGone(t)
	}()
	const n = 30
	var peers []xid
	var rcvs []string
	lanes := map[string]bool{}
	for i := 0; i < n; i++ {
		p := newXid(t)
		rcv := mustRcv(t, p)
		peers = append(peers, p)
		rcvs = append(rcvs, rcv)
		lanes[receiveLane(mainIdent, rcv)] = true
		// one of them has a window full enough to page
		k := 1
		if i == 0 {
			k = 130
		}
		for j := 0; j < k; j++ {
			ev := wrapToAt(t, p, myXPub, "stored "+strconv.Itoa(j), time.Now().Add(-time.Duration(j)*time.Second))
			own.store(ev)
			pub.store(ev)
		}
	}
	for i, p := range peers {
		go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), mainPair(p.pub), rcvs[i])
	}
	all := func() bool {
		l := own.listening()
		for _, a := range rcvs {
			if l[a] == 0 {
				return false
			}
		}
		return true
	}
	waitFor(t, "every address listening on our relay", 30*time.Second, all)
	waitFor(t, "every stored wrap in", 30*time.Second, func() bool {
		got := fsInbox()
		if len(got[hex.EncodeToString(peers[0].pub[:])]) < 130 {
			return false
		}
		for _, p := range peers {
			if len(got[hex.EncodeToString(p.pub[:])]) == 0 {
				return false
			}
		}
		return true
	})
	// 30 addresses: batches of 8, 8, 8 and 6
	if len(lanes) != 4 {
		t.Fatalf("%d batches for %d addresses, want 4", len(lanes), n)
	}
	for _, r := range []*relayStandIn{own, pub} {
		if got := len(connAddrs(r)); got > len(lanes) {
			t.Fatalf("%d sockets open on one relay for %d batches", got, len(lanes))
		}
		checkLiveReqs(t, r)
	}
	// no socket carries two batches or more than one batch holds
	for _, set := range connAddrs(own) {
		if len(set) > batchMax {
			t.Fatalf("one socket carries %d addresses", len(set))
		}
		var lane string
		for a := range set {
			if l := receiveLane(mainIdent, a); lane == "" {
				lane = l
			} else if l != lane {
				t.Fatalf("one socket carries %s and %s", lane, l)
			}
		}
	}

	// a wrap sent now reaches each address on the shared req
	for _, p := range peers {
		own.pushLive(wrapToAt(t, p, myXPub, "live", time.Now().Add(-3*time.Hour)))
	}
	waitFor(t, "every live wrap in", 15*time.Second, func() bool {
		got := fsInbox()
		for _, p := range peers {
			if !got[hex.EncodeToString(p.pub[:])]["live"] {
				return false
			}
		}
		return true
	})

	// the relay drops everyone: each batch comes back on one socket, and
	// what came meanwhile is fetched by each address's own window
	own.dropAll()
	for _, p := range peers[:5] {
		own.store(wrapToAt(t, p, myXPub, "meanwhile", time.Now().Add(-5*time.Hour)))
	}
	waitFor(t, "every address listening again", 30*time.Second, all)
	waitFor(t, "what came meanwhile in", 30*time.Second, func() bool {
		got := fsInbox()
		for _, p := range peers[:5] {
			if !got[hex.EncodeToString(p.pub[:])]["meanwhile"] {
				return false
			}
		}
		return true
	})
	if got := len(connAddrs(own)); got > len(lanes) {
		t.Fatalf("%d sockets open after the drop for %d batches", got, len(lanes))
	}
	checkLiveReqs(t, own)
}

func TestAHiddenChatKeepsASocketOfItsOwn(t *testing.T) {
	own := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own)
	freshInbox(t)
	// everyone in one batch, so only the hidden mark keeps it apart
	freshBatches(t)
	t.Cleanup(func() { runnersGone(t) })
	var rcvs []string
	var hidden, hiddenKey string
	for i := 0; i < 4; i++ {
		p := newXid(t)
		rcv := mustRcv(t, p)
		rcvs = append(rcvs, rcv)
		if r := nostrSubscribeAs(mainIdent, hex.EncodeToString(p.pub[:]), false, i == 0); r != "ok" {
			t.Fatal(r)
		}
		if i == 0 {
			hidden, hiddenKey = rcv, subKey(mainIdent, hex.EncodeToString(p.pub[:]))
		}
	}
	waitFor(t, "every address listening", 30*time.Second, func() bool {
		l := own.listening()
		for _, a := range rcvs {
			if l[a] == 0 {
				return false
			}
		}
		return true
	})
	shared := 0
	for _, set := range connAddrs(own) {
		if set[hidden] && len(set) > 1 {
			t.Fatalf("the hidden chat's address shares a socket with %d others", len(set)-1)
		}
		if !set[hidden] {
			shared++
		}
	}
	if shared != 1 {
		t.Fatalf("the everyday addresses are on %d sockets, want one", shared)
	}
	// a lane of its own, over tor on every route, and in no batch
	lane := mainPair([32]byte{}).listenLaneAs(hidden, true)
	if laneKind(lane) != laneHidden || !laneKeepsTor(lane) {
		t.Fatalf("the hidden chat listens on %q", lane)
	}
	if lane == hiddenLane(rcvs[1]) {
		t.Fatal("two hidden chats on one lane")
	}
	batchMu.Lock()
	_, inBatch := batches.every[batches.id(hidden)]
	batchMu.Unlock()
	if inBatch {
		t.Fatal("the hidden chat's address took a place in a batch")
	}
	// started again for a held wrap, it stays apart
	nostrMu.Lock()
	marked := nostrHiddenSubs[hiddenKey]
	nostrMu.Unlock()
	if !marked {
		t.Fatal("the hidden chat's subscription is not kept as hidden")
	}
}

func TestIdentitiesDoNotShareASocket(t *testing.T) {
	own := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own)
	freshInbox(t)
	freshBatches(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer func() {
		cancel()
		runnersGone(t)
	}()
	byIdent := map[string]int{}
	for i := 0; i < 6; i++ {
		p := newXid(t)
		rcv := mustRcv(t, p)
		c := mainPair(p.pub)
		// the grouping is all that is looked at here
		c.ident = i % 2
		byIdent[rcv] = c.ident
		go nostrSubscribeRunner(ctx, "t"+strconv.Itoa(i), c, rcv)
	}
	waitFor(t, "every address listening", 30*time.Second, func() bool {
		l := own.listening()
		for a := range byIdent {
			if l[a] == 0 {
				return false
			}
		}
		return true
	})
	for _, set := range connAddrs(own) {
		id := -1
		for a := range set {
			if id == -1 {
				id = byIdent[a]
			} else if byIdent[a] != id {
				t.Fatal("one socket carries the addresses of two identities")
			}
		}
	}
	if got := len(connAddrs(own)); got != 2 {
		t.Fatalf("%d sockets for two identities, want 2", got)
	}
	// and their batches have lanes of their own, so circuits of their own
	if receiveLane(0, "aa") == receiveLane(1, "bb") {
		t.Fatal("two identities' first batches on one lane")
	}
}

// a live req the relay turns away puts its addresses on a new one
func TestARefusedLiveReqIsAskedAgain(t *testing.T) {
	own := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own)
	freshInbox(t)
	freshBatches(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer func() {
		cancel()
		runnersGone(t)
	}()
	var peers []xid
	var rcvs []string
	for i := 0; i < 3; i++ {
		p := newXid(t)
		peers = append(peers, p)
		rcvs = append(rcvs, mustRcv(t, p))
		go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), mainPair(p.pub), rcvs[i])
	}
	all := func() bool {
		l := own.listening()
		for _, a := range rcvs {
			if l[a] == 0 {
				return false
			}
		}
		return true
	}
	waitFor(t, "every address listening", 30*time.Second, all)
	// the relay closes the live req, as one over its budget would
	waitFor(t, "the live req closed by the relay", 10*time.Second, func() bool {
		return own.closeLive("rate-limited: slow down")
	})
	waitFor(t, "every address listening again", 30*time.Second, all)
	for _, p := range peers {
		own.pushLive(wrapToAt(t, p, myXPub, "after", time.Now().Add(-time.Hour)))
	}
	waitFor(t, "every wrap in", 15*time.Second, func() bool {
		got := fsInbox()
		for _, p := range peers {
			if !got[hex.EncodeToString(p.pub[:])]["after"] {
				return false
			}
		}
		return true
	})
}

// a relay still on the old req budget turns the batch's windows past it
// away: the socket keeps to the old budget from then on, asks those again
// itself, and every address listens with all its wraps in
func TestAnOldRelaysBudgetSlowsTheSocket(t *testing.T) {
	own := newRelayStandIn(t, 0)
	// the old budget, small enough that one batch's windows run past it
	own.reqPerSec, own.reqBurst = 2, 4
	oldPer, oldBurst := hubOldPerSec, hubOldBurst
	hubOldPerSec, hubOldBurst = 2, 3
	t.Cleanup(func() { hubOldPerSec, hubOldBurst = oldPer, oldBurst })
	useStandIns(t, modeFast, nil, own)
	freshInbox(t)
	freshBatches(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer func() {
		cancel()
		runnersGone(t)
	}()
	var peers []xid
	var rcvs []string
	for i := 0; i < batchMax; i++ {
		p := newXid(t)
		peers = append(peers, p)
		rcvs = append(rcvs, mustRcv(t, p))
		own.store(wrapToAt(t, p, myXPub, "stored", time.Now().Add(-time.Hour)))
	}
	for i, p := range peers {
		go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), mainPair(p.pub), rcvs[i])
	}
	waitFor(t, "every address listening", 30*time.Second, func() bool {
		l := own.listening()
		for _, a := range rcvs {
			if l[a] == 0 {
				return false
			}
		}
		return true
	})
	waitFor(t, "every stored wrap in", 15*time.Second, func() bool {
		got := fsInbox()
		for _, p := range peers {
			if !got[hex.EncodeToString(p.pub[:])]["stored"] {
				return false
			}
		}
		return true
	})
	refused := 0
	for _, c := range own.snapshot() {
		refused += c.refused
	}
	if refused == 0 {
		t.Fatal("the relay turned nothing away: the test asks too little")
	}
	if !hubSlowed(own.url()) {
		t.Fatal("the socket did not take the old budget on")
	}
	// one socket all along: nothing went back to the runners' reconnect
	if got := len(own.snapshot()); got != 1 {
		t.Fatalf("%d sockets, want the batch's one", got)
	}
}
