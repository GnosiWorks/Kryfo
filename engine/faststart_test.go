// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"net"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
)

// the start's gate, first batch and turns as a fresh process has them
func freshStart(t *testing.T) {
	t.Helper()
	startGate.Lock()
	oldC, oldArmed := startGate.c, startGate.armed
	startGate.c, startGate.armed = nil, false
	startGate.Unlock()
	startFirst.Lock()
	oldLane, oldKick := startFirst.lane, startFirst.kick
	startFirst.lane, startFirst.kick = "", nil
	startFirst.Unlock()
	batchTurns.Lock()
	oldTurns := batchTurns.m
	batchTurns.m = map[hubKey]batchTurn{}
	batchTurns.Unlock()
	statusMu.RLock()
	oldStatus := torStatus
	statusMu.RUnlock()
	// a kick of its own, so no turn of a test before is taken for this one's
	kickRelays()
	t.Cleanup(func() {
		openStartGate()
		startGate.Lock()
		startGate.c, startGate.armed = oldC, oldArmed
		startGate.Unlock()
		startFirst.Lock()
		startFirst.lane, startFirst.kick = oldLane, oldKick
		startFirst.Unlock()
		batchTurns.Lock()
		batchTurns.m = oldTurns
		batchTurns.Unlock()
		setStatus(oldStatus)
	})
}

func listensOn(r *relayStandIn, addrs []string) int {
	l, n := r.listening(), 0
	for _, a := range addrs {
		if l[a] > 0 {
			n++
		}
	}
	return n
}

// dialled while tor is still on its way, tor would hold every socket and
// let them all go at 100%, in one instant: the start's sockets wait for tor
// and take their turns from there
func TestTheStartWaitsForTorBeforeItsTurns(t *testing.T) {
	socks := newSocksStandIn(t)
	r := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, r)
	freshInbox(t)
	freshBatches(t)
	freshStart(t)
	setStatus("starting")
	armStartGate()
	var rcvs []string
	for i := 0; i < 3; i++ {
		p := newXid(t)
		rcvs = append(rcvs, mustRcv(t, p))
		if res := nostrSubscribeAs(mainIdent, hex.EncodeToString(p.pub[:]), false, false); res != "ok" {
			t.Fatal(res)
		}
	}
	time.Sleep(1500 * time.Millisecond)
	if n := len(r.snapshot()); n != 0 {
		t.Fatalf("%d sockets dialled before tor was up", n)
	}
	setStatus("publishing")
	waitFor(t, "every address listening once tor is up", 15*time.Second, func() bool {
		return listensOn(r, rcvs) == len(rcvs)
	})
}

// the batch of the chats on top of the list takes the start's free turn,
// on every relay; every other socket, a hidden chat's too, waits its own
func TestTheFirstChatsBatchGoesFirst(t *testing.T) {
	own, pub := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	freshInbox(t)
	freshBatches(t)
	freshStart(t)
	old := subSpread
	subSpread = time.Hour
	t.Cleanup(func() {
		runnersGone(t)
		subSpread = old
	})

	// seats as a start before this one gave them: batch 0 full, batch 1 two
	var peers []xid
	byBatch := map[string][]string{}
	for i := 0; i < batchMax+2; i++ {
		p := newXid(t)
		peers = append(peers, p)
		rcv := mustRcv(t, p)
		l := receiveLane(mainIdent, rcv)
		byBatch[l] = append(byBatch[l], rcv)
	}
	first := batchLane(contactSet(mainIdent), 1)
	if len(byBatch[first]) != 2 {
		t.Fatalf("batch 1 has %d", len(byBatch[first]))
	}
	// the two latest chats are in batch 1, the third in batch 0: the batch
	// with most of them goes first
	noteFirstChats([]identPeer{
		{I: mainIdent, X: hex.EncodeToString(peers[batchMax].pub[:])},
		{I: mainIdent, X: hex.EncodeToString(peers[0].pub[:])},
		{I: mainIdent, X: hex.EncodeToString(peers[batchMax+1].pub[:])},
	})
	if got := startFirstLane(); got != first {
		t.Fatalf("first batch %q, want %q", got, first)
	}
	hid := newXid(t)
	hidRcv := mustRcv(t, hid)
	for _, p := range append(peers, hid) {
		if res := nostrSubscribeAs(mainIdent, hex.EncodeToString(p.pub[:]), false, p == hid); res != "ok" {
			t.Fatal(res)
		}
	}
	waitFor(t, "the first batch on both relays", 10*time.Second, func() bool {
		return listensOn(own, byBatch[first]) == 2 && listensOn(pub, byBatch[first]) == 2
	})
	time.Sleep(time.Second)
	rest := append(append([]string(nil), byBatch[batchLane(contactSet(mainIdent), 0)]...), hidRcv)
	if n := listensOn(own, rest) + listensOn(pub, rest); n != 0 {
		t.Fatalf("%d addresses of other sockets went at once beside the first batch", n)
	}
	// told once the turns began, a new list waits for the next start
	noteFirstChats([]identPeer{{I: mainIdent, X: hex.EncodeToString(peers[0].pub[:])}})
	if got := startFirstLane(); got != first {
		t.Fatalf("first batch moved to %q mid start", got)
	}
}

// a chat with no seat is passed over and given none: a hidden chat's
// address must never be batched by being told
func TestFirstChatsGiveNoSeat(t *testing.T) {
	r := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, r)
	freshBatches(t)
	freshStart(t)
	p := newXid(t)
	noteFirstChats([]identPeer{{I: mainIdent, X: hex.EncodeToString(p.pub[:])}})
	if got := startFirstLane(); got != "" {
		t.Fatalf("first batch %q from a chat with no seat", got)
	}
	if _, ok := batchFind(contactSet(mainIdent), mustRcv(t, p)); ok {
		t.Fatal("telling the first chats gave a seat")
	}
}

// the trace's steps and the home's getting new messages, counts and times
// only
func TestStartStepsAndCaughtUp(t *testing.T) {
	freshStart(t)
	t.Cleanup(func() { startSteps.reset(time.Time{}) })
	a, b, c := strings.Repeat("a", 64), strings.Repeat("b", 64), strings.Repeat("c", 64)
	startSteps.reset(time.Now())
	startSteps.torPct(10)
	startSteps.torPct(5)
	startSteps.torPct(100)
	startSteps.torReady()
	startSteps.member("everyday:0:0", a)
	startSteps.member("everyday:0:0", b)
	startSteps.member("everyday:0:1", c)
	if startSteps.caughtNow() {
		t.Fatal("caught up before anything came")
	}
	startSteps.routeProven()
	startSteps.relayUp()
	startSteps.caughtUp(a)
	if startSteps.caughtNow() {
		t.Fatal("caught up with half a batch in")
	}
	startSteps.caughtUp(c)
	if !startSteps.caughtNow() {
		t.Fatal("no first chats told: the first batch in is enough")
	}
	startSteps.caughtUp(b)
	lines := startSteps.take()
	for _, want := range []string{"tor 10% +", "tor 100% +", "tor ready +", "route proven +", "first relay connected +",
		"first batch caught up (1 of 3 addresses) +", "all batches caught up (2 batches, 3 addresses) +"} {
		if !strings.Contains(lines, want) {
			t.Fatalf("no %q in\n%s", want, lines)
		}
	}
	if strings.Contains(lines, "tor 5%") || strings.Contains(lines, "aaaa") || strings.Contains(lines, "everyday") {
		t.Fatalf("a step back, an address or a lane in\n%s", lines)
	}
	if startSteps.take() != "" {
		t.Fatal("lines given twice")
	}

	// with first chats told, only their batch counts
	startFirst.Lock()
	startFirst.lane = "everyday:0:0"
	startFirst.Unlock()
	startSteps.reset(time.Now())
	startSteps.member("everyday:0:0", a)
	startSteps.member("everyday:0:0", b)
	startSteps.member("everyday:0:1", c)
	startSteps.routeProven()
	startSteps.caughtUp(c)
	if startSteps.caughtNow() {
		t.Fatal("another batch in stood for the first chats'")
	}
	startSteps.caughtUp(a)
	startSteps.caughtUp(b)
	if !startSteps.caughtNow() {
		t.Fatal("the first chats' batch in, still not caught up")
	}

	// nobody to catch up on: in once the route is proven
	startSteps.reset(time.Now())
	if startSteps.caughtNow() {
		t.Fatal("caught up before the route")
	}
	startSteps.routeProven()
	if !startSteps.caughtNow() {
		t.Fatal("no batch, and still waiting")
	}

	// a relay that never finishes does not hold the line for good
	old := startCaughtMost
	startCaughtMost = 50 * time.Millisecond
	t.Cleanup(func() { startCaughtMost = old })
	startSteps.reset(time.Now())
	startSteps.member("everyday:0:0", a)
	startSteps.routeProven()
	time.Sleep(80 * time.Millisecond)
	if !startSteps.caughtNow() {
		t.Fatal("still getting new messages past the cap")
	}
}

// the gate stays open for a process that never started tor, and opens by
// itself if tor never says it is up
func TestTheStartGateOpens(t *testing.T) {
	freshStart(t)
	if startGateChan() != nil {
		t.Fatal("a gate with no start")
	}
	old := startGateMost
	startGateMost = 50 * time.Millisecond
	t.Cleanup(func() { startGateMost = old })
	armStartGate()
	g := startGateChan()
	if g == nil {
		t.Fatal("no gate once armed")
	}
	select {
	case <-g:
	case <-time.After(2 * time.Second):
		t.Fatal("the gate never opened by itself")
	}
	// armed once per process
	armStartGate()
	if startGateChan() != nil {
		t.Fatal("armed twice")
	}
}

// a card on screen opens a socket to each relay on the hello lane and lets
// it go: nothing asked, nothing sent, and not again within the while
func TestWarmHelloOpensAndAsksNothing(t *testing.T) {
	own, pub := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	warmHelloAt.Store(0)
	t.Cleanup(func() { warmHelloAt.Store(0) })
	warmHello()
	waitFor(t, "a socket to each relay, let go", 10*time.Second, func() bool {
		for _, r := range []*relayStandIn{own, pub} {
			c := r.snapshot()
			if len(c) != 1 || c[0].closed.IsZero() {
				return false
			}
		}
		return true
	})
	for _, r := range []*relayStandIn{own, pub} {
		c := r.snapshot()[0]
		if len(c.reqs) != 0 || len(c.got) != 0 {
			t.Fatalf("the warm asked %d and sent %d", len(c.reqs), len(c.got))
		}
	}
	warmHello()
	time.Sleep(500 * time.Millisecond)
	if n := len(own.snapshot()) + len(pub.snapshot()); n != 2 {
		t.Fatalf("warmed again at once: %d sockets", n)
	}
}

// a relay that takes the connection and never says a word, or shuts it at
// once: a dead circuit or a door that turns tor away. counts the dials
type blackHole struct {
	ln    net.Listener
	dials atomic.Int32
}

func newBlackHole(t *testing.T, shut bool) *blackHole {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	b := &blackHole{ln: ln}
	var held []net.Conn
	var mu sync.Mutex
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			b.dials.Add(1)
			if shut {
				c.Close()
				continue
			}
			mu.Lock()
			held = append(held, c)
			mu.Unlock()
		}
	}()
	t.Cleanup(func() {
		ln.Close()
		mu.Lock()
		for _, c := range held {
			c.Close()
		}
		mu.Unlock()
	})
	return b
}

func (b *blackHole) url() string { return "ws://" + b.ln.Addr().String() }

// a send is sent once our relay takes it: a second store that never
// answers and a public relay that never answers hold nothing up
func TestASendDoesNotWaitOnDeadRelays(t *testing.T) {
	own := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own)
	second, public := newBlackHole(t, false), newBlackHole(t, false)
	old := secondRelayHost.get()
	secondRelayHost.put(strings.TrimPrefix(second.url(), "ws://"))
	t.Cleanup(func() { secondRelayHost.put(old) })
	setRelays([]string{own.url(), second.url(), public.url()})
	peer := newXid(t)
	began := time.Now()
	if r := nostrSend(mainIdent, hex.EncodeToString(peer.pub[:]), "hi"); r != "ok" {
		t.Fatal(r)
	}
	if d := time.Since(began); d > 3*time.Second {
		t.Fatalf("the send waited %s on relays that never answer", d)
	}
}

// a public relay on the bench is not dialled again at every kick, and is
// as soon as the benches are let go of
func TestABenchedPublicRelayWaitsOutKicks(t *testing.T) {
	own := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own)
	dead := newBlackHole(t, true)
	setRelays([]string{own.url(), dead.url()})
	relayHealthMu.Lock()
	relayFails[dead.url()] = relayFailGrace + 2
	relayCoolTill[dead.url()] = time.Now().Add(time.Minute)
	relayHealthMu.Unlock()
	peer := newXid(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(alone(ctx), hex.EncodeToString(peer.pub[:]), mainPair(peer.pub), mustRcv(t, peer))
	waitFor(t, "our relay listening", 10*time.Second, func() bool { return len(own.listening()) == 1 })
	for i := 0; i < 5; i++ {
		kickRelays()
		time.Sleep(300 * time.Millisecond)
	}
	if n := dead.dials.Load(); n != 0 {
		t.Fatalf("a benched relay dialled %d times over five kicks", n)
	}
	relayClearBenches()
	waitFor(t, "the dead relay tried once the benches went", 10*time.Second, func() bool { return dead.dials.Load() > 0 })
}

// a public relay that never answered here backs off past five minutes
func TestANeverAnsweringRelayBacksOffFurther(t *testing.T) {
	u := "wss://never.example"
	relayEverOK.Delete(u)
	t.Cleanup(func() { relayEverOK.Delete(u) })
	if d := relayBackoffFor(u, relayFailGrace+6); d != relayMaxBench {
		t.Fatalf("%s at the old ceiling", d)
	}
	if d := relayBackoffFor(u, relayFailGrace+7); d <= relayMaxBench {
		t.Fatalf("%s: no further than the old ceiling", d)
	}
	if d := relayBackoffFor(u, relayFailGrace+20); d != relayDeadBench {
		t.Fatalf("%s past the dead ceiling", d)
	}
	relayEverOK.Store(u, true)
	if d := relayBackoffFor(u, relayFailGrace+20); d != relayMaxBench {
		t.Fatalf("a relay that answered once backs off %s", d)
	}
}

// a first-contact hello to b, from a stranger's identity
func fcHelloTo(t *testing.T, fcPk, body string) nostr.Event {
	t.Helper()
	stranger := newXid(t)
	putIdentity(77, stranger)
	t.Cleanup(func() { identDrop(77) })
	c, err := pairOf(77, myXPub)
	if err != nil {
		t.Fatal(err)
	}
	gw, err := c.wrapFirstContact(fcPk, body)
	if err != nil {
		t.Fatal(err)
	}
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		t.Fatal(err)
	}
	return ev
}

// one working relay is enough to hear a first contact: a relay that shuts
// the door at once, and one that holds the dial as a slow onion descriptor
// fetch does (90 s and more), hold nothing up, whichever of them is ours
func TestAFirstContactArrivesPastADeadAndASlowRelay(t *testing.T) {
	for _, ours := range []string{"good", "slow"} {
		t.Run("ours "+ours, func(t *testing.T) {
			good := newRelayStandIn(t, 0)
			useStandIns(t, modeFast, nil, good)
			freshInbox(t)
			freshStart(t)
			dead, slow := newBlackHole(t, true), newBlackHole(t, false)
			list := []string{good.url(), dead.url(), slow.url()}
			if ours == "slow" {
				ownRelayHost.put(strings.TrimPrefix(slow.url(), "ws://"))
				list = []string{slow.url(), dead.url(), good.url()}
			}
			setRelays(list)
			_, fcPk, err := mainFirstContactKeys(mainIdent, 0)
			if err != nil {
				t.Fatal(err)
			}
			// one waiting there before the listener starts, one live after
			good.store(fcHelloTo(t, fcPk, "stored hello"))
			if err := subscribeFirstContact(mainIdent, 0); err != nil {
				t.Fatal(err)
			}
			began := time.Now()
			waitFor(t, "the stored hello", 10*time.Second, func() bool { return fsInbox()["firstcontact"]["stored hello"] })
			waitFor(t, "listening on the working relay", 5*time.Second, func() bool { return good.listening()[fcPk] > 0 })
			hello := fcHelloTo(t, fcPk, "live hello")
			good.pushLive(hello)
			waitFor(t, "the live hello", 10*time.Second, func() bool { return fsInbox()["firstcontact"]["live hello"] })
			if d := time.Since(began); d > 15*time.Second {
				t.Fatalf("a first contact took %s past a dead and a slow relay", d)
			}
			if slow.dials.Load() == 0 || dead.dials.Load() == 0 {
				t.Fatal("the dead and the slow relay were never tried: the test proves nothing")
			}
		})
	}
}

// many sockets to a relay on a failing streak dial it one at a time: the
// others wait their own backoff instead of each holding a dial of its own
func TestAFailingRelayTakesOneDialAtATime(t *testing.T) {
	own := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own)
	dead := newBlackHole(t, false)
	setRelays([]string{own.url(), dead.url()})
	relayHealthMu.Lock()
	relayFails[dead.url()] = 1
	relayHealthMu.Unlock()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	for i := 0; i < 5; i++ {
		p := newXid(t)
		go nostrSubscribeRunner(alone(ctx), hex.EncodeToString(p.pub[:]), mainPair(p.pub), mustRcv(t, p))
	}
	waitFor(t, "every socket on our relay", 10*time.Second, func() bool { return len(own.listening()) == 5 })
	time.Sleep(time.Second)
	if n := dead.dials.Load(); n != 1 {
		t.Fatalf("%d dials out at once to a failing relay, want 1", n)
	}
}
