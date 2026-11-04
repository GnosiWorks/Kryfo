// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// the tests' runners join within a moment of each other: the start's wait
// for the rest would only slow every test that dials a public relay
func init() { liveSettle = 200 * time.Millisecond }

// the cap and the round for one test
func setLiveCap(t *testing.T, cap int, every time.Duration) {
	t.Helper()
	liveMu.Lock()
	oldCap, oldEvery, oldSettle := publicLiveCap, sweepEvery, liveSettle
	// a test's runners join within a moment of each other
	publicLiveCap, sweepEvery, liveSettle = cap, every, 200*time.Millisecond
	liveMu.Unlock()
	t.Cleanup(func() {
		liveMu.Lock()
		publicLiveCap, sweepEvery, liveSettle = oldCap, oldEvery, oldSettle
		liveMu.Unlock()
	})
}

// the run's choice for k, once the joins have settled
func choose(k string) bool {
	for {
		live, wait, _ := livePlace(k)
		if wait <= 0 {
			return live
		}
		time.Sleep(wait)
	}
}

// nothing ranked, nothing heard, nothing pinned, our relay up
func liveReset() {
	liveMu.Lock()
	liveAddrs, liveLast, livePinned = map[string]*liveAddr{}, map[string]int64{}, map[string]bool{}
	livePicks, liveTaken, liveJoinedAt = map[string]livePick{}, 0, time.Time{}
	liveRunAt, liveJoinRun = time.Time{}, map[string]int{}
	ownDown, ownKnown, ownAnsweredAt, ownFailedAt, pubAnsweredAt = false, false, 0, 0, 0
	firstDown, firstKnown, firstAnsweredAt, firstFailedAt = false, false, 0, 0
	liveMu.Unlock()
}

// the round while our relay is down, how long it is quiet and how long its
// failures last before it is
func setDownRound(t *testing.T, every, after, span time.Duration) {
	t.Helper()
	liveMu.Lock()
	oldEvery, oldAfter, oldSpan := sweepEveryDown, ownDownAfter, ownFailSpan
	sweepEveryDown, ownDownAfter, ownFailSpan = every, after, span
	liveMu.Unlock()
	t.Cleanup(func() {
		liveMu.Lock()
		sweepEveryDown, ownDownAfter, ownFailSpan = oldEvery, oldAfter, oldSpan
		liveMu.Unlock()
	})
}

// every socket waits a short turn, the start's free one spent, so all the
// runners of a test have joined the rank before the first dial, as the
// minute's spread gives them on a phone
func shortTurns(t *testing.T) {
	t.Helper()
	old := subSpread
	subSpread = 300 * time.Millisecond
	t.Cleanup(func() {
		runnersGone(t)
		subSpread = old
	})
	spendFirstTurn()
}

// open sockets where a subscription listens on addr
func openOn(r *relayStandIn, addr string) int { return r.listening()[addr] }

// reads of addr on r, each its own window
func everOn(r *relayStandIn, addr string) int { return r.windows(addr) }

func TestLiveRankKeepsTheLatestHeard(t *testing.T) {
	setLiveCap(t, 2, time.Hour)
	liveReset()
	a := liveJoin("a", 30, false)
	defer liveLeave("a", a)
	b := liveJoin("b", 20, false)
	defer liveLeave("b", b)
	if !publicLive("a") || !publicLive("b") {
		t.Fatal("under the cap every address is live")
	}
	c := liveJoin("c", 10, false)
	if !publicLive("a") || !publicLive("b") || publicLive("c") {
		t.Fatal("past the cap the two heard from last are live")
	}
	for _, k := range []string{"a", "b", "c"} {
		choose(k)
	}
	// the run's list holds: c heard from last moves nobody
	liveHeard("c", 40)
	if !publicLive("a") || !publicLive("b") || publicLive("c") {
		t.Fatal("an arrival changed the run's list")
	}
	// the next run ranks by it, a runner started again in place
	liveNewRun()
	for _, k := range []string{"a", "b"} {
		liveJoin(k, 0, false)
	}
	c2 := liveJoin("c", 0, false)
	liveLeave("c", c)
	if !publicLive("c") || publicLive("b") {
		t.Fatal("the next run did not take c heard from last")
	}
	liveLeave("c", c2)
	if !publicLive("b") {
		t.Fatal("b is back in once c is gone")
	}
	if !publicLive("unranked") {
		t.Fatal("an address not ranked is live everywhere")
	}
}

// pinned chats come first, then the latest heard
func TestPinnedChatsRankFirst(t *testing.T) {
	setLiveCap(t, 1, time.Hour)
	liveReset()
	livePin([]string{"b"})
	a := liveJoin("a", 30, false)
	defer liveLeave("a", a)
	b := liveJoin("b", 10, false)
	defer liveLeave("b", b)
	if !choose("b") || choose("a") {
		t.Fatal("the pinned chat is not the one live")
	}
}

// a run's list never grows past the cap, whatever order the turns come in:
// one whose turn came before the others joined keeps the place it took
func TestTheRunsListHoldsTheCap(t *testing.T) {
	setLiveCap(t, 2, time.Hour)
	liveReset()
	liveJoin("d", 10, false)
	if !choose("d") {
		t.Fatal("alone and not live")
	}
	for i, k := range []string{"a", "b", "c"} {
		liveJoin(k, int64(40-i*10), false)
	}
	live := 1
	for _, k := range []string{"a", "b", "c"} {
		if choose(k) {
			live++
		}
	}
	if live != 2 || !publicLive("d") || !publicLive("a") {
		t.Fatalf("%d live, want d and a", live)
	}
	// someone just added is live on top, until the next start
	e := liveJoin("e", 0, true)
	if !choose("e") {
		t.Fatal("someone just added is not live")
	}
	liveLeave("e", e)
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
// still only reads: the run's list holds
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
		go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), mainPair(p.pub), rcvs[i])
	}
	lastHex := hex.EncodeToString(peers[last].pub[:])
	waitFor(t, "the wrap from the public relay", 15*time.Second, func() bool {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		return slices.Contains(nostrInbox, lastHex+"|only on a public relay")
	})
	waitFor(t, "the address that brought it letting go after its read", 10*time.Second, func() bool {
		return openOn(pub, rcvs[last]) == 0
	})
	// the quiet one reads and lets go, round after round
	waitFor(t, "two reads of the quiet address", 15*time.Second, func() bool {
		return everOn(pub, rcvs[mid]) >= 2
	})
	if n := openOn(pub, rcvs[mid]); n > 1 {
		t.Fatalf("the quiet address holds %d sockets on the public relay", n)
	}
	if openOn(pub, rcvs[first]) != 1 {
		t.Fatal("the live address does not hold its one socket on the public relay")
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
	go nostrSubscribeRunner(asFresh(ctx), hex.EncodeToString(p.pub[:]), mainPair(p.pub), rcv)
	waitFor(t, "the new address live on the public relay", 10*time.Second, func() bool {
		return openOn(pub, rcv) == 1
	})
}

// a contact past the cap who writes reaches us on our relay. no socket on
// a public relay opens or closes for it: one opening for the writer as
// another closes would show the relay that the two are one phone
func TestAContactWhoWritesMovesNoPublicSocket(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	oldSpread := kickSpread
	kickSpread = 0
	t.Cleanup(func() { kickSpread = oldSpread })
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	in, out, inRcv, outRcv := livePair(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, in, inRcv)
	runOn(ctx, out, outRcv)
	waitFor(t, "both on our relay and the first on the public one", 15*time.Second, func() bool {
		return openOn(own, inRcv) == 1 && openOn(own, outRcv) == 1 && openOn(pub, inRcv) == 1
	})
	own.pushLive(wrapTo(t, out, myXPub, "hello"))
	outHex := hex.EncodeToString(out.pub[:])
	waitFor(t, "the message on our relay", 10*time.Second, func() bool {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		return slices.Contains(nostrInbox, outHex+"|hello")
	})
	// kicks and their probes, as the job's knocks bring them
	end := time.Now().Add(3 * time.Second)
	for time.Now().Before(end) {
		kickRelays()
		time.Sleep(50 * time.Millisecond)
	}
	if n := everOn(pub, outRcv); n != 0 {
		t.Fatalf("the writer dialled the public relay %d times", n)
	}
	if everOn(pub, inRcv) != 1 || openOn(pub, inRcv) != 1 {
		t.Fatal("the live address's public socket closed or was replaced")
	}
}

// the list is chosen again at a mode switch, when every runner starts
// again anyway: a chat pinned since ranks first then. the pin changes no
// socket before that
func TestTheListIsChosenAgainAtAModeSwitch(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	oldSpread := kickSpread
	kickSpread = 0
	t.Cleanup(func() { kickSpread = oldSpread })
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	in, out, inRcv, outRcv := livePair(t)
	ctx, cancel := context.WithCancel(context.Background())
	runOn(ctx, in, inRcv)
	runOn(ctx, out, outRcv)
	waitFor(t, "the first live on the public relay", 15*time.Second, func() bool {
		return openOn(own, outRcv) == 1 && openOn(pub, inRcv) == 1
	})
	nostrPinned(mainPeers(hex.EncodeToString(out.pub[:])))
	end := time.Now().Add(2 * time.Second)
	for time.Now().Before(end) {
		kickRelays()
		time.Sleep(50 * time.Millisecond)
	}
	if everOn(pub, outRcv) != 0 || everOn(pub, inRcv) != 1 {
		t.Fatal("a pin moved a public socket before the next run")
	}
	// the switch: every runner ends, the list is chosen anew
	cancel()
	waitFor(t, "the old sockets closed", 10*time.Second, func() bool {
		return openOn(pub, inRcv) == 0 && openOn(own, outRcv) == 0
	})
	liveNewRun()
	spendFirstTurn()
	ctx2, cancel2 := context.WithCancel(context.Background())
	defer cancel2()
	runOn(ctx2, in, inRcv)
	runOn(ctx2, out, outRcv)
	waitFor(t, "the pinned chat live on the public relay", 15*time.Second, func() bool {
		return openOn(pub, outRcv) == 1
	})
	time.Sleep(time.Second)
	if openOn(pub, inRcv) != 0 {
		t.Fatal("the one it ranks above is still live")
	}
}

// every runner is started again on a mode switch, the old one gone before
// the new one starts. what was heard on the address is kept for it, and
// nothing of it once the address is let go of
func TestTheRankOutlivesARestart(t *testing.T) {
	setLiveCap(t, 1, time.Hour)
	liveReset()
	a := liveJoin("a", 10, false)
	b := liveJoin("b", 20, false)
	defer liveLeave("b", b)
	liveHeard("a", 30)
	liveLeave("a", a)
	a = liveJoin("a", 10, false)
	if !publicLive("a") || publicLive("b") {
		t.Fatal("a runner started again lost what its address heard")
	}
	liveLeave("a", a)
	dropAddressFiles("a")
	a = liveJoin("a", 10, false)
	defer liveLeave("a", a)
	if publicLive("a") {
		t.Fatal("an address let go of kept when it was heard")
	}
	// someone just added is live until the next start, over a restart in
	// the run too, even with another heard from since
	c := liveJoin("c", 40, true)
	liveHeard("b", 100)
	liveLeave("c", c)
	c = liveJoin("c", 0, false)
	defer liveLeave("c", c)
	if !choose("c") {
		t.Fatal("someone just added fell out on a restart")
	}
	// the next run ranks by what was heard
	liveNewRun()
	b = liveJoin("b", 0, false)
	c = liveJoin("c", 0, false)
	if choose("c") || !choose("b") {
		t.Fatal("the next run did not rank b heard from last first")
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

// two contacts with nothing heard: the first by address holds the one place
// on the public relay, the other is past the cap
func livePair(t *testing.T) (in, out xid, inRcv, outRcv string) {
	t.Helper()
	a, b := newXid(t), newXid(t)
	ra, rb := mustRcv(t, a), mustRcv(t, b)
	if ra < rb {
		return a, b, ra, rb
	}
	return b, a, rb, ra
}

func runOn(ctx context.Context, p xid, rcv string) {
	go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), mainPair(p.pub), rcv)
}

// the anchor file an earlier run left, at unix seconds at
func plantAnchor(t *testing.T, rcv string, at int64) {
	t.Helper()
	_, lastPath := addressFiles(rcv)
	if err := os.WriteFile(lastPath, []byte(strconv.FormatInt(at, 10)), 0600); err != nil {
		t.Fatal(err)
	}
}

// relay to ms, as the heard file holds them
func readHeard(t *testing.T, rcv string) map[string]int64 {
	t.Helper()
	b, err := os.ReadFile(heardFile(rcv))
	if err != nil {
		return nil
	}
	out := map[string]int64{}
	for _, line := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		i := strings.LastIndexByte(line, ' ')
		if i <= 0 {
			continue
		}
		v, _ := strconv.ParseInt(line[i+1:], 10, 64)
		out[line[:i]] = v
	}
	return out
}

// the relay closes every socket that asked for addr, at once
func cutOn(r *relayStandIn, addr string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, c := range r.conns {
		if c.closed.IsZero() && c.addrs[addr] {
			c.kill()
			if c.ws != nil {
				c.ws.CloseNow()
			}
		}
	}
}

// past the cap an address reads the public relays now and then, while the
// ones heard from last hold sockets there. what the heard file says of the
// public relays would sort the contacts into the two, so a seized phone's
// files must not tell a live address from one past the cap
func TestTheHeardFileHidesWhoIsLive(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	in, out, inRcv, outRcv := livePair(t)
	// files an earlier version left, a line for every relay
	old := time.Now().Add(-48 * time.Hour).UnixMilli()
	for _, r := range []string{inRcv, outRcv} {
		body := fmt.Sprintf("%s %d\n%s %d\n", own.url(), old, pub.url(), old)
		if err := os.WriteFile(heardFile(r), []byte(body), 0600); err != nil {
			t.Fatal(err)
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, in, inRcv)
	runOn(ctx, out, outRcv)
	waitFor(t, "one address live on the public relay, both on ours", 15*time.Second, func() bool {
		return openOn(pub, inRcv) == 1 && openOn(own, inRcv) == 1 && openOn(own, outRcv) == 1
	})
	waitFor(t, "both heard files written after our relay's catch-up", 10*time.Second, func() bool {
		return readHeard(t, inRcv)[own.url()] > old && readHeard(t, outRcv)[own.url()] > old
	})
	// the live one's catch-up on the public relay is in too
	time.Sleep(500 * time.Millisecond)
	a, b := readHeard(t, inRcv), readHeard(t, outRcv)
	for name, h := range map[string]map[string]int64{"live": a, "capped": b} {
		if _, ok := h[pub.url()]; ok {
			t.Errorf("the %s address's heard file names the public relay: %v", name, h)
		}
	}
	if len(a) != len(b) {
		t.Fatalf("the files differ: %v and %v", a, b)
	}
	step := heardSaveStep.Milliseconds()
	for relay, v := range a {
		w, ok := b[relay]
		if !ok || v-w > step || w-v > step {
			t.Fatalf("the files differ on %s: %v and %v", relay, a, b)
		}
	}
}

// a held id let go of is asked for by id on the next read. a read used to
// close at the main answer's end, before the ask was answered, so what only
// a public relay had never came while the address was past the cap
func TestAReadWaitsForTheHeldItAsked(t *testing.T) {
	setLiveCap(t, 1, 2*time.Second)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	pollHoldReset(t)
	a, b := newXid(t), newXid(t)
	ra, rb := mustRcv(t, a), mustRcv(t, b)
	now := time.Now()
	// b was heard from last, so a is past the cap. a's window starts a
	// minute ago, well past the held one
	plantAnchor(t, rb, now.Unix())
	plantAnchor(t, ra, now.Unix()-60)
	held := wrapToAt(t, a, myXPub, "held", now.Add(-30*time.Hour))
	pub.store(held)
	pub.mu.Lock()
	pub.idsDelay = time.Second
	pub.mu.Unlock()
	seenPath, _ := addressFiles(ra)
	s := loadSeen(seenPath)
	if !s.claim(held.ID) || !s.hold(held.ID, held.CreatedAt, "", now, 0, 0) {
		t.Fatal("not held")
	}
	markHeldFile(seenPath, seenFreeMark)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, b, rb)
	runOn(ctx, a, ra)
	aHex := hex.EncodeToString(a.pub[:])
	waitFor(t, "the held text from the public relay", 12*time.Second, func() bool {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		return slices.Contains(nostrInbox, aHex+"|held")
	})
	if everOn(pub, ra) == 0 {
		t.Fatal("it came without a read of the public relay")
	}
}

// the round counts from a read that caught up: one cut before its answer
// is tried again within the round, not a whole round after the connect
func TestACutReadIsTriedAgainWithinTheRound(t *testing.T) {
	setLiveCap(t, 1, 8*time.Second)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	pub.mu.Lock()
	pub.reqDelay = 2 * time.Second
	pub.mu.Unlock()
	in, out, inRcv, outRcv := livePair(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, in, inRcv)
	runOn(ctx, out, outRcv)
	waitFor(t, "the first read", 12*time.Second, func() bool { return everOn(pub, outRcv) >= 1 })
	cutOn(pub, outRcv)
	// an eighth to a quarter of the round, and the turn
	waitFor(t, "the read tried again", 4*time.Second, func() bool { return everOn(pub, outRcv) >= 2 })
}

// our relay going down right as an address starts waiting for its next
// read wakes the wait, not the end of the usual round
func TestARoundChangeAsTheWaitBeginsIsNotMissed(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	setDownRound(t, time.Second, 10*time.Minute, 30*time.Second)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	// ours turns every dial away, so nothing says it is back
	own.mu.Lock()
	own.down = true
	own.mu.Unlock()
	in, out, inRcv, outRcv := livePair(t)
	var once sync.Once
	sweepWaitHook = func() {
		once.Do(func() {
			liveMu.Lock()
			now := ownClock()
			ownKnown, ownAnsweredAt, ownFailedAt, pubAnsweredAt = true, now-time.Hour, now-time.Hour, now
			liveMu.Unlock()
			ownRelayFailed()
		})
	}
	t.Cleanup(func() {
		runnersGone(t)
		sweepWaitHook = nil
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, in, inRcv)
	runOn(ctx, out, outRcv)
	waitFor(t, "a read in the short round", 6*time.Second, func() bool {
		return everOn(pub, outRcv) >= 1
	})
}

// with our relay down the addresses past the cap read the public relays
// every few minutes, each at its own times, and go back to the usual round
// once ours answers again
func TestOurRelayDownReadsThePublicRelaysMoreOften(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	setDownRound(t, 4*time.Second, 300*time.Millisecond, 300*time.Millisecond)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	own.mu.Lock()
	own.down = true
	own.mu.Unlock()
	peers := make([]xid, 9)
	rcvs := make([]string, 9)
	for i := range peers {
		peers[i] = newXid(t)
		rcvs[i] = mustRcv(t, peers[i])
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	for i := range peers {
		runOn(ctx, peers[i], rcvs[i])
	}
	sorted := slices.Clone(rcvs)
	slices.Sort(sorted)
	capped := sorted[1:]
	waitFor(t, "every address past the cap read the public relay twice", 40*time.Second, func() bool {
		for _, a := range capped {
			if everOn(pub, a) < 2 {
				return false
			}
		}
		return true
	})
	// each its own times: the eight first reads spread over the 4 s round,
	// not in one batch or two. at least four of its sixteen quarter
	// seconds, which uniform times miss about once in a thousand runs
	slots := map[int64]bool{}
	var firsts []time.Time
	for _, a := range capped {
		at := connsOn(pub.snapshot(), []string{a})[0].opened
		firsts = append(firsts, at)
		slots[at.UnixMilli()/250] = true
	}
	if len(slots) < 4 {
		t.Fatalf("the reads came in batches: %v", firsts)
	}
	// ours answers again: the usual round from here
	own.mu.Lock()
	own.down = false
	own.mu.Unlock()
	// a kick ends our relay's backoff, as the network coming back does
	waitFor(t, "every address back on our relay", 20*time.Second, func() bool {
		kickRelays()
		for _, a := range rcvs {
			if openOn(own, a) != 1 {
				return false
			}
		}
		return !ownRelayDown()
	})
	// the short round's reads are dropped with it: none left to go out
	// together at the next wake
	time.Sleep(time.Second)
	before := map[string]int{}
	for _, a := range capped {
		before[a] = everOn(pub, a)
	}
	time.Sleep(6 * time.Second)
	for _, a := range capped {
		if n := everOn(pub, a) - before[a]; n > 0 {
			t.Fatalf("an address read the public relay %d more times with ours back", n)
		}
	}
}

// a delete lets go of the address while a take on its runner may still be
// under way. that take writes no rank back
func TestADeletedContactLeavesNoRank(t *testing.T) {
	setLiveCap(t, 1, time.Hour)
	liveReset()
	a := liveJoin("a", 10, false)
	dropAddressFiles("a")
	liveHeard("a", 50)
	liveLeave("a", a)
	liveMu.Lock()
	_, kept := liveLast["a"]
	liveMu.Unlock()
	if kept {
		t.Fatal("when the deleted contact last wrote stayed in memory")
	}
	b := liveJoin("b", 20, false)
	defer liveLeave("b", b)
	a = liveJoin("a", 0, false)
	defer liveLeave("a", a)
	if publicLive("a") {
		t.Fatal("the contact added again started with the old rank")
	}
}

// a public relay that turns the dial away has had this round's read. every
// address past the cap redialling at the backoff's pace is the pile of
// sockets the relay turns away
func TestARefusedReadCountsAsTheRound(t *testing.T) {
	setLiveCap(t, 0, 4*time.Second)
	own := newRelayStandIn(t, 0)
	u, dials := refusingRelay(t)
	useStandIns(t, modeFast, nil, own)
	useRelays(own.url(), u)
	shortTurns(t)
	freshInbox(t)
	p := newXid(t)
	rcv := mustRcv(t, p)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, p, rcv)
	waitFor(t, "the first read", 6*time.Second, func() bool { return dials.Load() >= 1 })
	time.Sleep(300 * time.Millisecond)
	// a kick ends the backoff's wait, not the round's
	end := time.Now().Add(2 * time.Second)
	for time.Now().Before(end) {
		kickRelays()
		time.Sleep(30 * time.Millisecond)
	}
	if n := dials.Load(); n != 1 {
		t.Fatalf("the refusing relay was dialled %d times in one round", n)
	}
}

// a read whose relay never says that was all ends at the catch-up cap. it
// used to stay open as a live socket for as long as the relay answered probes
func TestAReadWithNoEndCloses(t *testing.T) {
	setLiveCap(t, 0, 4*time.Second)
	oldCap := catchupCap
	catchupCap = 500 * time.Millisecond
	t.Cleanup(func() { catchupCap = oldCap })
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	pub.mu.Lock()
	pub.stallAt, pub.stallAll = 1, true
	pub.mu.Unlock()
	p := newXid(t)
	rcv := mustRcv(t, p)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, p, rcv)
	waitFor(t, "the first read", 6*time.Second, func() bool { return everOn(pub, rcv) >= 1 })
	waitFor(t, "the read closed at the cap", 3*time.Second, func() bool {
		cs := connsOn(pub.snapshot(), []string{rcv})
		return len(cs) > 0 && !cs[0].closed.IsZero()
	})
}

// a place in the run belongs to the address: a runner started again keeps
// it, whatever was heard since, and a place a delete frees stays empty
// until the next run
func TestARunsPlaceOutlivesARunnerRestart(t *testing.T) {
	setLiveCap(t, 1, time.Hour)
	liveReset()
	a := liveJoin("a", 10, false)
	b := liveJoin("b", 5, false)
	if !choose("a") || choose("b") {
		t.Fatal("a heard from last is not the one live")
	}
	liveHeard("b", 100)
	liveLeave("a", a)
	a = liveJoin("a", 0, false)
	if !choose("a") {
		t.Fatal("a runner started again in the run lost its place")
	}
	// an accept starts its runner fresh: it keeps the place it has
	liveLeave("b", b)
	b = liveJoin("b", 0, true)
	if choose("b") {
		t.Fatal("a fresh start moved an address into the run's list")
	}
	// a deleted live address frees no place for anyone in this run
	liveLeave("a", a)
	dropAddressFiles("a")
	c := liveJoin("c", 200, false)
	if choose("c") || choose("b") {
		t.Fatal("the place a delete freed was given again in the run")
	}
	liveNewRun()
	liveJoin("b", 0, false)
	liveJoin("c", 0, false)
	if !choose("c") || choose("b") {
		t.Fatal("the next run did not choose again")
	}
	liveLeave("c", c)
}

// the app starts a runner again in the run on a second intro card, an
// unblock, a stranger's opener, the listen again after a start and a
// resubscribe on the same mode, and fresh on an accept. each is a
// subscribe of a key already listened on, which moves no public socket
func TestARestartedRunnerKeepsItsPublicPlace(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	in, out, inRcv, outRcv := livePair(t)
	inHex, outHex := hex.EncodeToString(in.pub[:]), hex.EncodeToString(out.pub[:])
	t.Cleanup(func() {
		nostrMu.Lock()
		for _, h := range []string{inHex, outHex} {
			if c := nostrSubs[h]; c != nil {
				c()
				delete(nostrSubs, h)
			}
		}
		nostrMu.Unlock()
	})
	nostrSubscribe(mainIdent, inHex, false)
	nostrSubscribe(mainIdent, outHex, false)
	waitFor(t, "the first live on the public relay", 15*time.Second, func() bool {
		return openOn(own, outRcv) == 1 && openOn(pub, inRcv) == 1
	})
	// the one past the cap writes: it ranks first from now on
	own.pushLive(wrapTo(t, out, myXPub, "hello"))
	waitFor(t, "the message on our relay", 10*time.Second, func() bool {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		return slices.Contains(nostrInbox, outHex+"|hello")
	})
	for _, path := range []struct {
		name  string
		fresh bool
	}{
		{"a second intro card", false},
		{"an unblock", false},
		{"a stranger's opener", false},
		{"the listen again", false},
		{"a resubscribe", false},
		{"an accept", true},
	} {
		ins := everOn(pub, inRcv)
		nostrSubscribe(mainIdent, inHex, path.fresh)
		nostrSubscribe(mainIdent, outHex, path.fresh)
		waitFor(t, path.name+": the live address back on the public relay", 10*time.Second, func() bool {
			return everOn(pub, inRcv) > ins && openOn(pub, inRcv) == 1
		})
		if n := everOn(pub, outRcv); n != 0 {
			t.Fatalf("%s: the address past the cap dialled the public relay %d times", path.name, n)
		}
	}
}

// a request is listened on from the moment it comes, so it has its place
// in the run already. the accept starts its runner fresh and it keeps that
// place: no public socket opens on it at the accept, when the ack goes out.
// it counts as heard at the accept and is live from the next start
func TestAnAcceptedRequestIsLiveFromTheNextStart(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	// in breaks the tie of two never heard from
	in, req, inRcv, reqRcv := livePair(t)
	inHex, reqHex := hex.EncodeToString(in.pub[:]), hex.EncodeToString(req.pub[:])
	t.Cleanup(func() {
		nostrMu.Lock()
		for _, h := range []string{inHex, reqHex} {
			if c := nostrSubs[h]; c != nil {
				c()
				delete(nostrSubs, h)
			}
		}
		nostrMu.Unlock()
	})
	nostrSubscribe(mainIdent, inHex, false)
	nostrSubscribe(mainIdent, reqHex, false)
	waitFor(t, "the request on our relay, the other live on the public one", 15*time.Second, func() bool {
		return openOn(own, reqRcv) == 1 && openOn(pub, inRcv) == 1
	})
	// the accept
	nostrSubscribe(mainIdent, reqHex, true)
	waitFor(t, "the accepted request back on our relay", 10*time.Second, func() bool {
		return openOn(own, reqRcv) == 1 && len(connsOn(own.snapshot(), []string{reqRcv})) >= 2
	})
	end := time.Now().Add(2 * time.Second)
	for time.Now().Before(end) {
		kickRelays()
		time.Sleep(50 * time.Millisecond)
	}
	if n := everOn(pub, reqRcv); n != 0 {
		t.Fatalf("the accept opened %d public sockets in the run", n)
	}
	if openOn(pub, inRcv) != 1 {
		t.Fatal("the accept moved the live address off the public relay")
	}
	// the next start: every runner again, the list chosen anew
	liveNewRun()
	spendFirstTurn()
	nostrSubscribe(mainIdent, inHex, false)
	nostrSubscribe(mainIdent, reqHex, false)
	waitFor(t, "the accepted request live on the public relay", 15*time.Second, func() bool {
		return openOn(pub, reqRcv) == 1
	})
	time.Sleep(time.Second)
	if openOn(pub, inRcv) != 0 {
		t.Fatal("the one it ranks above is still live")
	}
}

// at a start the app listens on everyone in one go, and with the turns free
// the first to join dialled before the rest were in: the list went by row
// order. it waits for the joins, so the latest heard are the ones live
func TestTheListWaitsForTheStartsAddresses(t *testing.T) {
	setLiveCap(t, 2, 1000*time.Hour)
	liveMu.Lock()
	liveSettle = time.Second
	liveMu.Unlock()
	oldSpread := subSpread
	subSpread = 0
	t.Cleanup(func() { subSpread = oldSpread })
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	freshInbox(t)
	now := time.Now().Unix()
	peers := make([]xid, 6)
	rcvs := make([]string, 6)
	for i := range peers {
		peers[i] = newXid(t)
		rcvs[i] = mustRcv(t, peers[i])
		// the later in the rows, the later heard from: the last is a hidden
		// chat, listened on after the rest
		plantAnchor(t, rcvs[i], now-int64(6-i)*600)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	for i := range peers {
		runOn(ctx, peers[i], rcvs[i])
		time.Sleep(150 * time.Millisecond)
	}
	waitFor(t, "the two heard from last live on the public relay", 10*time.Second, func() bool {
		return openOn(pub, rcvs[4]) == 1 && openOn(pub, rcvs[5]) == 1
	})
	time.Sleep(500 * time.Millisecond)
	for i := 0; i < 4; i++ {
		if n := everOn(pub, rcvs[i]); n != 0 {
			t.Fatalf("address %d, early in the rows, dialled the public relay %d times", i, n)
		}
	}
}

// a relay that takes the websocket and the req and never answers has
// nothing behind it: that is our relay down, not up
func TestOurRelayTakingReqsWithNoAnswerIsDown(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	setDownRound(t, time.Second, 300*time.Millisecond, 300*time.Millisecond)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	own.mu.Lock()
	own.hangUp = true
	own.mu.Unlock()
	in, out, inRcv, outRcv := livePair(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, in, inRcv)
	runOn(ctx, out, outRcv)
	waitFor(t, "reads in the short round", 30*time.Second, func() bool {
		return ownRelayDown() && everOn(pub, outRcv) >= 2
	})
}

// the time to our relay counting as down runs while the phone sleeps, but
// only failures while the public relays answer count: a wake whose circuits
// come back slowly fails everywhere, over a minute or more, and is not an
// outage of ours
func TestOurRelayDownCountsTheTimeAsleep(t *testing.T) {
	liveReset()
	t.Cleanup(liveReset)
	setDownRound(t, time.Minute, 10*time.Minute, 2*time.Minute)
	// the clock is put back after the test, and that is no wake either
	wakeReset()
	t.Cleanup(wakeReset)
	var mu sync.Mutex
	at := time.Hour
	clock := func(d time.Duration) {
		mu.Lock()
		at += d
		mu.Unlock()
	}
	setOwnClock(t, func() time.Duration {
		mu.Lock()
		defer mu.Unlock()
		return at
	})
	// failures every 5 s from w to w+d; pub: a public relay answers from
	// that far into them on, nil for none
	wake := func(d time.Duration, pub *time.Duration) {
		for gone := time.Duration(0); gone <= d; gone += 5 * time.Second {
			if pub != nil && gone >= *pub {
				pubRelayAnswered()
			}
			ownRelayFailed()
			clock(5 * time.Second)
		}
	}
	ownRelayAnswered()
	// a slow wake: eleven minutes asleep, a minute of failures with nothing
	// answering, then ours does
	clock(11*time.Minute + 30*time.Second)
	wake(time.Minute, nil)
	if ownRelayDown() {
		t.Fatal("a slow wake was taken for our relay down")
	}
	ownRelayAnswered()
	// a wake whose exit circuits come back before the onion one: the public
	// relays answer half a minute before ours does
	clock(11 * time.Minute)
	pubAt := 30 * time.Second
	wake(90*time.Second, &pubAt)
	if ownRelayDown() {
		t.Fatal("ours coming back a minute after the public relays was taken for down")
	}
	ownRelayAnswered()
	// a failure while they answered, then a sleep: the wake's one failure is
	// no span
	pubRelayAnswered()
	ownRelayFailed()
	clock(15 * time.Minute)
	ownRelayFailed()
	if ownRelayDown() {
		t.Fatal("a span carried over a sleep")
	}
	// slept through an outage of ours: on the wake the public relays answer
	// and ours keeps failing
	clock(11 * time.Minute)
	pubAt = 10 * time.Second
	wake(3*time.Minute, &pubAt)
	if !ownRelayDown() {
		t.Fatal("not down after a sleep through the outage and minutes of failures")
	}
	ownRelayAnswered()
	if ownRelayDown() {
		t.Fatal("still down once it answered")
	}
}

// a read's window reaches back to what that relay is known to have handed
// over. our relay moves the anchor with every wrap, and a wrap only a public
// relay has, stamped back the most, fell below a window drawn from it
func TestAReadReachesBackToWhatItLastHandedOver(t *testing.T) {
	setLiveCap(t, 1, 2*time.Second)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	in, out, inRcv, outRcv := livePair(t)
	now := time.Now()
	plantAnchor(t, inRcv, now.Unix())
	plantAnchor(t, outRcv, now.Unix())
	// the last read of the public relay three hours ago, as the run holds it
	heardMu.Lock()
	heardAt[catchupKey(pub.url(), outRcv)] = now.Add(-3 * time.Hour).UnixMilli()
	heardMu.Unlock()
	// sent since, its outer stamp ten hours back
	pub.store(wrapToAt(t, out, myXPub, "only on a public relay", now.Add(-13*time.Hour)))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, in, inRcv)
	runOn(ctx, out, outRcv)
	outHex := hex.EncodeToString(out.pub[:])
	waitFor(t, "the wrap from the public relay", 15*time.Second, func() bool {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		return slices.Contains(nostrInbox, outHex+"|only on a public relay")
	})
	// to the quarter hour: the read's own end would carry this phone's clock
	for _, c := range connsOn(pub.snapshot(), []string{outRcv}) {
		if len(c.reqs) > 0 && c.reqs[0].filter.Since%900 != 0 {
			t.Fatalf("the widened since is not on the quarter hour: %d", c.reqs[0].filter.Since)
		}
	}
}

// a held line keeps when its id reached the relay. from a public relay that
// would tell a live socket's moment from a read's span on disk, so it keeps
// no from there
func TestAHeldLineKeepsNoReachFromAPublicRelay(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	pollHoldReset(t)
	in, out, inRcv, outRcv := livePair(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, in, inRcv)
	runOn(ctx, out, outRcv)
	waitFor(t, "the live address caught up on the public relay", 15*time.Second, func() bool {
		return openOn(pub, inRcv) == 1 && openOn(own, inRcv) == 1
	})
	time.Sleep(500 * time.Millisecond)
	pub.pushLive(wrapTo(t, in, myXPub, "held"))
	inHex := hex.EncodeToString(in.pub[:])
	seenPath, _ := addressFiles(inRcv)
	waitFor(t, "the text held", 10*time.Second, func() bool {
		if b := pollRaw(t); b.K != "" {
			var h []int
			var g []string
			for i, e := range b.M {
				if e.T == inHex {
					h = append(h, i)
					g = append(g, "")
				}
			}
			hj, _ := json.Marshal(h)
			gj, _ := json.Marshal(g)
			nostrAck(b.K, fmt.Sprintf(`{"f":[],"h":%s,"g":%s}`, hj, gj))
		}
		return heldOnFile(seenPath) == 1
	})
	b, err := os.ReadFile(seenPath)
	if err != nil {
		t.Fatal(err)
	}
	for _, line := range strings.Split(string(b), "\n") {
		if !strings.HasPrefix(line, seenHeldMark) {
			continue
		}
		f := strings.Fields(line)
		if len(f) > 4 && f[3] != "0" {
			t.Fatalf("the held line keeps when it reached the public relay: %q", line)
		}
	}
}

// how the run's list stands for k within limit: chosen or still waiting
func placeWithin(k string, limit time.Duration) (live, chosen bool) {
	end := time.Now().Add(limit)
	for time.Now().Before(end) {
		l, wait, _ := livePlace(k)
		if wait <= 0 {
			return l, true
		}
		time.Sleep(min(wait, 20*time.Millisecond))
	}
	return false, false
}

// a stranger's openers restart that runner over and over: a runner started
// again is not a new address, and holds nobody's place open
func TestARejoinDoesNotHoldTheListOpen(t *testing.T) {
	setLiveCap(t, 1, time.Hour)
	liveReset()
	liveJoin("a", 30, false)
	b := liveJoin("b", 10, false)
	stop := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		for {
			select {
			case <-stop:
				return
			case <-time.After(100 * time.Millisecond):
			}
			liveLeave("b", b)
			b = liveJoin("b", 10, false)
		}
	}()
	live, chosen := placeWithin("a", 2*time.Second)
	close(stop)
	<-done
	if !chosen || !live {
		t.Fatal("a runner restarted every 100 ms held the list open")
	}
}

// new addresses joining without a pause hold the list no longer than its
// ceiling
func TestTheListWaitsNoLongerThanItsCeiling(t *testing.T) {
	setLiveCap(t, 1, time.Hour)
	liveReset()
	liveMu.Lock()
	old := liveSettleMax
	liveSettleMax = time.Second
	liveMu.Unlock()
	t.Cleanup(func() {
		liveMu.Lock()
		liveSettleMax = old
		liveMu.Unlock()
	})
	liveJoin("a", 1000, false)
	stop := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		for i := 0; ; i++ {
			select {
			case <-stop:
				return
			case <-time.After(100 * time.Millisecond):
			}
			liveJoin(fmt.Sprintf("n%d", i), 0, false)
		}
	}()
	live, chosen := placeWithin("a", 2500*time.Millisecond)
	close(stop)
	<-done
	if !chosen || !live {
		t.Fatal("a stream of new addresses kept the list from being chosen")
	}
}

// a mode switch chooses the new run's list once the app listens again, with
// the pins it tells before that, not with the last ones
func TestAModeSwitchChoosesWithThePinsToldAfterIt(t *testing.T) {
	setLiveCap(t, 1, time.Hour)
	liveReset()
	liveJoin("a", 30, false)
	liveJoin("b", 10, false)
	if !choose("a") || choose("b") {
		t.Fatal("a heard from last is not the one live")
	}
	liveNewRun()
	// the old runners come back first, before the app listens again
	time.Sleep(400 * time.Millisecond)
	if _, wait, _ := livePlace("b"); wait <= 0 {
		t.Fatal("the new run chose before anyone joined it")
	}
	livePin([]string{"b"})
	liveJoin("a", 0, false)
	liveJoin("b", 0, false)
	if !choose("b") || choose("a") {
		t.Fatal("the new run did not take the pin told before the listen")
	}
}

// an address that joins after the list was chosen, a pinned row whose key
// came late, gets the place its rank gives while the run has one left, and
// reads now and then when the run's places are all given
func TestALateJoinTakesAFreePlaceOnly(t *testing.T) {
	setLiveCap(t, 2, time.Hour)
	liveReset()
	liveJoin("a", 30, false)
	if !choose("a") {
		t.Fatal("alone and not live")
	}
	livePin([]string{"c", "d"})
	liveJoin("c", 0, false)
	if !choose("c") {
		t.Fatal("a pinned late join with a place free is not live")
	}
	liveJoin("d", 0, false)
	if choose("d") || !publicLive("a") {
		t.Fatal("a late join took a place the run had given")
	}
}

// the reads keep their times on the boot clock: a wall clock set back or
// ahead moves none of them, and time asleep counts
func TestReadsKeepTheirTimesOnTheBootClock(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	var ahead atomic.Int64
	setOwnClock(t, func() time.Duration { return bootClock() + time.Duration(ahead.Load()) })
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	in, out, inRcv, outRcv := livePair(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, in, inRcv)
	runOn(ctx, out, outRcv)
	waitFor(t, "the first live on the public relay", 15*time.Second, func() bool {
		return openOn(own, outRcv) == 1 && openOn(pub, inRcv) == 1
	})
	time.Sleep(500 * time.Millisecond)
	if everOn(pub, outRcv) != 0 {
		t.Fatal("read before its time")
	}
	// two rounds asleep, by the boot clock: the wake's kick finds it due
	ahead.Store(int64(2000 * time.Hour))
	kickUntil(t, "the read after the sleep", func() bool { return everOn(pub, outRcv) >= 1 })
}

// after a start nothing is known of what a public relay handed over, and
// our relay moves the anchor with its catch-up before a public read comes:
// the first read reaches back to the anchor the runner started with
func TestTheFirstReadAfterAStartReachesBackToItsAnchor(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	freshInbox(t)
	// the public relay's dial comes after our relay's catch-up
	pub.mu.Lock()
	pub.upgradeDelay = time.Second
	pub.mu.Unlock()
	p := newXid(t)
	rcv := mustRcv(t, p)
	now := time.Now()
	plantAnchor(t, rcv, now.Add(-3*time.Hour).Unix())
	// sent while ours was down the night before, stamped far back
	pub.store(wrapToAt(t, p, myXPub, "only on a public relay", now.Add(-14*time.Hour)))
	// this morning's, on ours: it moves the anchor up at our catch-up
	own.store(wrapToAt(t, p, myXPub, "this morning", now))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runOn(ctx, p, rcv)
	tag := hex.EncodeToString(p.pub[:])
	waitFor(t, "the night's wrap from the public relay", 15*time.Second, func() bool {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		return slices.Contains(nostrInbox, tag+"|only on a public relay")
	})
	for _, c := range connsOn(pub.snapshot(), []string{rcv}) {
		if len(c.reqs) > 0 && c.reqs[0].filter.Since%900 != 0 {
			t.Fatalf("the widened since is not on the quarter hour: %d", c.reqs[0].filter.Since)
		}
	}
}
