// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"fmt"
	"os"
	"slices"
	"strconv"
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

// nothing ranked, nothing heard, nothing pinned
func liveReset() {
	liveMu.Lock()
	liveAddrs, liveLast, livePinned = map[string]*liveAddr{}, map[string]int64{}, map[string]bool{}
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
		liveChoose(k)
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
	if !liveChoose("b") || liveChoose("a") {
		t.Fatal("the pinned chat is not the one live")
	}
}

// a run's list never grows past the cap, whatever order the turns come in:
// one whose turn came before the others joined keeps the place it took
func TestTheRunsListHoldsTheCap(t *testing.T) {
	setLiveCap(t, 2, time.Hour)
	liveReset()
	liveJoin("d", 10, false)
	if !liveChoose("d") {
		t.Fatal("alone and not live")
	}
	for i, k := range []string{"a", "b", "c"} {
		liveJoin(k, int64(40-i*10), false)
	}
	live := 1
	for _, k := range []string{"a", "b", "c"} {
		if liveChoose(k) {
			live++
		}
	}
	if live != 2 || !publicLive("d") || !publicLive("a") {
		t.Fatalf("%d live, want d and a", live)
	}
	// someone just added is live on top, until the next start
	e := liveJoin("e", 0, true)
	if !liveChoose("e") {
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
		go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), p.pub, rcvs[i])
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
	go nostrSubscribeRunner(asFresh(ctx), hex.EncodeToString(p.pub[:]), p.pub, rcv)
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
	nostrPinned([]string{hex.EncodeToString(out.pub[:])})
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
	// someone just added keeps their place over a restart too
	c := liveJoin("c", 40, false)
	liveLeave("c", c)
	c = liveJoin("c", 0, false)
	defer liveLeave("c", c)
	if !publicLive("c") {
		t.Fatal("someone just added fell out on a restart")
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
	go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), p.pub, rcv)
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
