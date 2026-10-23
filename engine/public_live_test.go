// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"slices"
	"strings"
	"testing"
	"time"
)

// the cap and the round for one test
func setLiveCap(t *testing.T, cap int, every time.Duration) {
	t.Helper()
	liveMu.Lock()
	oldCap, oldEvery := publicLiveCap, sweepEvery
	publicLiveCap, sweepEvery = cap, every
	liveMu.Unlock()
	t.Cleanup(func() {
		liveMu.Lock()
		publicLiveCap, sweepEvery = oldCap, oldEvery
		liveMu.Unlock()
	})
}

// nothing ranked, nothing heard
func liveReset() {
	liveMu.Lock()
	liveAddrs = map[string]*liveAddr{}
	liveMu.Unlock()
}

// every socket waits a short turn, the start's free one spent, so all the
// runners of a test have joined the rank before the first dial, as the
// minute's spread gives them on a phone
func shortTurns(t *testing.T) {
	t.Helper()
	old := subSpread
	subSpread = 300 * time.Millisecond
	t.Cleanup(func() { subSpread = old })
	spendFirstTurn()
}

// open sockets that listen on addr
func openOn(r *relayStandIn, addr string) int {
	n := 0
	for _, c := range connsOn(r.snapshot(), []string{addr}) {
		if c.closed.IsZero() && len(c.reqs) > 0 {
			n++
		}
	}
	return n
}

// sockets that ever listened on addr
func everOn(r *relayStandIn, addr string) int {
	return len(connsOn(r.snapshot(), []string{addr}))
}

func TestLiveRankKeepsTheLatestHeard(t *testing.T) {
	setLiveCap(t, 2, time.Hour)
	liveReset()
	a := liveJoin("a", 30)
	defer liveLeave("a", a)
	b := liveJoin("b", 20)
	defer liveLeave("b", b)
	if !publicLive("a") || !publicLive("b") {
		t.Fatal("under the cap every address is live")
	}
	c := liveJoin("c", 10)
	defer liveLeave("c", c)
	if !publicLive("a") || !publicLive("b") || publicLive("c") {
		t.Fatal("past the cap the two heard from last are live")
	}
	wake := liveWake("c")
	liveHeard("c", 40)
	select {
	case <-wake:
	default:
		t.Fatal("an address that moved into the cap was not woken")
	}
	if !publicLive("c") || publicLive("b") {
		t.Fatal("c heard from last is live, b fell out")
	}
	// a runner started again in place keeps its address when the old one leaves
	c2 := liveJoin("c", 0)
	liveLeave("c", c)
	if !publicLive("c") {
		t.Fatal("the new runner's address lost its rank")
	}
	liveLeave("c", c2)
	if !publicLive("b") {
		t.Fatal("b is back in once c is gone")
	}
	if !publicLive("unranked") {
		t.Fatal("an address not ranked is live everywhere")
	}
}

// a big inbox held one socket per address on every public relay: 271
// addresses were 1084 sockets on four relays that turn piles of sockets
// from one exit away. past the cap only the latest stay live there, and
// every address stays live on our relay.
func TestBigInboxKeepsFewPublicSockets(t *testing.T) {
	// a round long enough that no read of the public relay falls in the test
	setLiveCap(t, 4, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	l := startLanes(t, ctx, 10, 2)
	// first-contact and room addresses are never capped
	uncapped := []string{l.fc}
	for _, r := range l.rooms {
		uncapped = append(uncapped, r...)
	}
	all := append(slices.Clone(uncapped), l.contacts...)
	waitFor(t, "every address listening on our relay", 15*time.Second, func() bool {
		for _, a := range all {
			if openOn(own, a) != 1 {
				return false
			}
		}
		return true
	})
	waitFor(t, "first-contact and room addresses listening on the public relay", 15*time.Second, func() bool {
		for _, a := range uncapped {
			if openOn(pub, a) != 1 {
				return false
			}
		}
		return true
	})
	// time for any runner that would dial the public relay to have done so
	time.Sleep(2 * time.Second)
	sorted := slices.Clone(l.contacts)
	slices.Sort(sorted)
	live := 0
	for i, a := range sorted {
		n := openOn(pub, a)
		live += n
		// nothing heard yet: the address breaks the tie
		want := 0
		if i < 4 {
			want = 1
		}
		if n != want {
			t.Errorf("address %d of 10 has %d sockets on the public relay", i, n)
		}
	}
	if live != 4 {
		t.Fatalf("%d contact addresses live on the public relay, want 4", live)
	}
}

// an address past the cap still reads the public relay now and then, so a
// wrap that only reached a public relay comes in. one that brings something
// is live there from then on.
func TestQuietAddressReadsThePublicRelay(t *testing.T) {
	setLiveCap(t, 1, 2*time.Second)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	peers := []xid{newXid(t), newXid(t), newXid(t)}
	rcvs := make([]string, len(peers))
	for i, p := range peers {
		rcvs[i] = mustRcv(t, p)
	}
	// the last by address is past the cap while nothing is heard
	order := []int{0, 1, 2}
	slices.SortFunc(order, func(a, b int) int { return strings.Compare(rcvs[a], rcvs[b]) })
	first, mid, last := order[0], order[1], order[2]
	pub.store(wrapTo(t, peers[last], myXPub, "only on a public relay"))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	for i, p := range peers {
		go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), p.pub, rcvs[i])
	}
	lastHex := hex.EncodeToString(peers[last].pub[:])
	waitFor(t, "the wrap from the public relay", 15*time.Second, func() bool {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		return slices.Contains(nostrInbox, lastHex+"|only on a public relay")
	})
	waitFor(t, "the address that brought it live on the public relay", 10*time.Second, func() bool {
		return openOn(pub, rcvs[last]) == 1
	})
	// the quiet one reads and lets go, round after round
	waitFor(t, "two reads of the quiet address", 15*time.Second, func() bool {
		return everOn(pub, rcvs[mid]) >= 2
	})
	if n := openOn(pub, rcvs[mid]); n > 1 {
		t.Fatalf("the quiet address holds %d sockets on the public relay", n)
	}
	if openOn(pub, rcvs[first]) > 1 {
		t.Fatal("the address pushed out holds more than one socket on the public relay")
	}
	for _, a := range rcvs {
		if openOn(own, a) != 1 {
			t.Fatal("every address stays live on our relay")
		}
	}
}

// someone just added is live everywhere at once, whatever the cap
func TestJustAddedIsLiveOnThePublicRelays(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	l := startLanes(t, ctx, 3, 0)
	waitFor(t, "the old addresses on our relay", 15*time.Second, func() bool {
		for _, a := range l.contacts {
			if openOn(own, a) != 1 {
				return false
			}
		}
		return true
	})
	p := newXid(t)
	rcv := mustRcv(t, p)
	go nostrSubscribeRunner(asFresh(ctx), hex.EncodeToString(p.pub[:]), p.pub, rcv)
	waitFor(t, "the new address live on the public relay", 10*time.Second, func() bool {
		return openOn(pub, rcv) == 1
	})
}

// a contact past the cap who writes reaches us on our relay. its address
// goes live on the public relays at once, not at its next read, and the
// one it pushed out of the cap lets go of its socket at its next probe
func TestAContactWhoWritesGoesLiveOnThePublicRelays(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	oldSpread := kickSpread
	kickSpread = 0
	t.Cleanup(func() { kickSpread = oldSpread })
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	peers := []xid{newXid(t), newXid(t), newXid(t)}
	rcvs := make([]string, len(peers))
	for i, p := range peers {
		rcvs[i] = mustRcv(t, p)
	}
	// nothing heard yet: the first by address holds the one place
	order := []int{0, 1, 2}
	slices.SortFunc(order, func(a, b int) int { return strings.Compare(rcvs[a], rcvs[b]) })
	first, last := order[0], order[2]
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	for i, p := range peers {
		go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), p.pub, rcvs[i])
	}
	waitFor(t, "every address on our relay and the first on the public one", 15*time.Second, func() bool {
		for _, a := range rcvs {
			if openOn(own, a) != 1 {
				return false
			}
		}
		return openOn(pub, rcvs[first]) == 1
	})
	if everOn(pub, rcvs[last]) != 0 {
		t.Fatal("an address past the cap dialled the public relay")
	}
	own.pushLive(wrapTo(t, peers[last], myXPub, "hello"))
	lastHex := hex.EncodeToString(peers[last].pub[:])
	waitFor(t, "the message on our relay", 10*time.Second, func() bool {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		return slices.Contains(nostrInbox, lastHex+"|hello")
	})
	waitFor(t, "the writer live on the public relay", 5*time.Second, func() bool {
		return openOn(pub, rcvs[last]) == 1
	})
	kickUntil(t, "the address pushed out closing its public socket", func() bool {
		return openOn(pub, rcvs[first]) == 0
	})
	if openOn(pub, rcvs[last]) != 1 {
		t.Fatal("the writer lost its public socket on the kick")
	}
	for _, a := range rcvs {
		if openOn(own, a) != 1 {
			t.Fatal("every address stays live on our relay")
		}
	}
}

// only the contacts' receive lanes are ranked
func TestOnlyContactAddressesAreCapped(t *testing.T) {
	for i := 0; i < receiveLaneCount; i++ {
		if !rankedLane(receiveLaneAt(i)) {
			t.Fatalf("contact lane %d is not ranked", i)
		}
	}
	for _, l := range []string{laneEveryday, laneFirstContact, roomLane("ab"), pairLane("ab"), laneServices} {
		if rankedLane(l) {
			t.Fatalf("%s is ranked", l)
		}
	}
}
