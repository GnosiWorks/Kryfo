// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"net/http"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func failedCount() int {
	routeMu.Lock()
	defer routeMu.Unlock()
	return len(failedSinceOK)
}

// relays that turn a wrap away answered through tor: the route carried the
// question and the answer, so it is not marked down, nor rebuilt for it
func TestRefusedPublishIsNotADeadRoute(t *testing.T) {
	socks := newSocksStandIn(t)
	a, b, c := newRelayStandIn(t, 0), newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	for _, r := range []*relayStandIn{a, b, c} {
		r.refuse = "rate-limited: slow down"
	}
	useStandIns(t, modePrivate, socks, a, b, c)
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	me, err := myXid()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if n := nostrPublishMulti(ctx, laneEveryday, wrapTo(t, me, newXid(t).pub, "hi")); n != 0 {
		t.Fatalf("%d relays took it, the stand-ins refuse", n)
	}
	if n := failedCount(); n != 0 {
		t.Fatalf("%d relays that answered no were counted against the route", n)
	}
	if why := routeNeedsRescue(time.Now().Add(5 * time.Minute)); why != "" {
		t.Fatalf("a rescue for relays that answered: %s", why)
	}
	if !routeOK() {
		t.Fatal("the route reads down after relays answered through it")
	}
	// they are still benched as before: they did not take it
	relayHealthMu.Lock()
	n := relayFails[a.url()]
	relayHealthMu.Unlock()
	if n == 0 {
		t.Fatal("a refusing relay was not counted at all")
	}
}

// a relay that says it has the event already holds it: sent, no bench
func TestDuplicateAnswerIsNoFailure(t *testing.T) {
	socks := newSocksStandIn(t)
	a := newRelayStandIn(t, 0)
	a.refuse = "duplicate: already have this event"
	useStandIns(t, modePrivate, socks, a)
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	me, _ := myXid()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if got := nostrPublishMulti(ctx, laneEveryday, wrapTo(t, me, newXid(t).pub, "hi")); got != 1 {
		t.Fatalf("a relay that holds the event counted %d, want it as sent", got)
	}
	relayHealthMu.Lock()
	n := relayFails[a.url()]
	relayHealthMu.Unlock()
	if n != 0 {
		t.Fatalf("a relay that holds the event was counted as failing %d times", n)
	}
}

// a sign of life from a connection made before the latest bounce says
// nothing about the tor after it
func TestOldConnectionProvesNothing(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	resetRoute(t, "publishing", 100)
	old := routeBump()
	routeBump()
	routeAliveOn(old, "wss://a.example")
	if routeOK() {
		t.Fatal("a connection from before the bounce proved the new route")
	}
	routeAliveOn(routeGeneration(), "wss://a.example")
	if !routeOK() {
		t.Fatal("a connection on the route now did not prove it")
	}
}

// relays fail while a live socket on our relay still answers its probes:
// tor carries, the failures are those relays' own, and nothing is rebuilt
func TestLiveSocketAnswerClearsFailures(t *testing.T) {
	socks := newSocksStandIn(t)
	ours := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, ours)
	resetRoute(t, "publishing", 100)
	oldSpread := kickSpread
	kickSpread = 0
	defer func() { kickSpread = oldSpread }()
	peer := newXid(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, mustRcv(t, peer))
	waitFor(t, "the subscription", 10*time.Second, func() bool {
		cs := ours.snapshot()
		return len(cs) == 1 && len(cs[0].reqs) > 0
	})
	failAll(time.Now().Add(-2*time.Minute), "wss://down.example", "wss://gone.example")
	// a kick makes the live socket ask its probe
	kickUntil(t, "the probe answered", func() bool { return failedCount() == 0 })
	if why := routeNeedsRescue(time.Now()); why != "" {
		t.Fatalf("a rescue with a socket answering: %s", why)
	}
	if n := len(ours.snapshot()); n != 1 {
		t.Fatalf("the live socket was replaced: %d connections", n)
	}
}

// the cheap rescue renames every lane so new streams take new circuits. it
// sends tor nothing (NEWNYM would drop the vanguards and onion descriptors),
// keeps the route and the kept sockets, and kicks every runner
func TestNewCircuitsKeepTheRoute(t *testing.T) {
	fc := newFakeControl(t, 100)
	fakeTor(t, fc.port())
	oldMode := currentMode()
	transportMode.Store(modePrivate)
	t.Cleanup(func() { transportMode.Store(oldMode) })
	resetRoute(t, "publishing", 100)
	gen := routeGeneration()
	kick := kickChan()
	name := laneName(laneEveryday)
	cachedNostrClientMu.Lock()
	cachedNostrClients[laneEveryday] = &http.Client{}
	cachedNostrClientMu.Unlock()
	key := pubKey{lane: laneEveryday, url: "wss://kept.example", addr: "kept"}
	sock := &pubSock{}
	pubMu.Lock()
	pubSocks[key] = sock
	pubMu.Unlock()
	t.Cleanup(func() {
		pubMu.Lock()
		delete(pubSocks, key)
		pubMu.Unlock()
	})
	before, _ := bounceSnapshot()
	rescueCircuits()
	if sent := fc.sent(); len(sent) != 0 {
		t.Fatalf("new circuits sent tor %q", sent)
	}
	if laneName(laneEveryday) == name {
		t.Fatal("the lane kept its socks name, its next stream rides the old circuit")
	}
	cachedNostrClientMu.Lock()
	c := cachedNostrClients[laneEveryday]
	cachedNostrClientMu.Unlock()
	if c != nil {
		t.Fatal("a client with the old socks name was kept")
	}
	pubMu.Lock()
	still := pubSocks[key] == sock
	pubMu.Unlock()
	if !still {
		t.Fatal("a kept publish socket was cut")
	}
	if routeGeneration() != gen {
		t.Fatal("new circuits started a new route")
	}
	select {
	case <-kick:
	default:
		t.Fatal("the runners were not kicked")
	}
	after, _ := bounceSnapshot()
	if len(after) != len(before)+1 && len(after) != bounceKeep || after[0].Why != whyCircuits {
		t.Fatalf("not on the transport screen: %+v", after)
	}
}

// a relay that never answered on a route that carries is down for its own
// reasons: its failures do not count against tor. our relay's always do, and
// while nothing has answered on the route every relay's does
func TestOnlyRelaysThatAnsweredSpeakForTor(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	setRelays([]string{"ws://ours.onion", "wss://relay.kryfo.app", "wss://down1.example", "wss://down2.example"})
	resetRoute(t, "publishing", 100)
	routeNoteFail("wss://down1.example")
	if n := failedCount(); n != 1 {
		t.Fatalf("nothing answered yet and a failure counted %d, want 1", n)
	}
	routeNoteOK()
	routeNoteFail("wss://down1.example")
	routeNoteFail("wss://down2.example")
	if n := failedCount(); n != 0 {
		t.Fatalf("%d relays that never answered counted against the route", n)
	}
	routeAnswered("wss://down1.example", -1)
	routeNoteFail("wss://down1.example")
	if n := failedCount(); n != 1 {
		t.Fatalf("a relay that answered on this route and then failed: %d counted", n)
	}
	routeNoteFail("ws://ours.onion")
	routeNoteFail("wss://relay.kryfo.app")
	if n := failedCount(); n != 3 {
		t.Fatalf("our relay's failures: %d counted, want 3", n)
	}
	// a bounce starts a new route: once it carries, answers from before it no longer count
	routeBump()
	routeNoteOK()
	routeNoteFail("wss://down1.example")
	if n := failedCount(); n != 0 {
		t.Fatalf("an answer from before the bounce still counted: %d", n)
	}
}

// the first rescue and the new circuits are spread too, not only the gaps
func TestFirstRescueIsSpread(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	setRelays([]string{"ws://ours.onion", "wss://relay.kryfo.app"})
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	rescueJitter = func(d time.Duration) time.Duration { return d + 7*time.Second }
	routeNoteFail("ws://ours.onion")
	routeNoteFail("wss://relay.kryfo.app")
	routeMu.Lock()
	t0 := firstFailAt
	routeMu.Unlock()
	if why := routeNeedsRescue(t0.Add(deadFor + time.Second)); why != "" {
		t.Fatalf("rescued inside the spread window: %s", why)
	}
	at := t0.Add(deadFor + 7*time.Second)
	if why := routeNeedsRescue(at); !strings.HasPrefix(why, circuitsWhy) {
		t.Fatalf("no new circuits after the spread window: %q", why)
	}
	if why := routeNeedsRescue(at.Add(circuitsFor + time.Second)); why != "" {
		t.Fatalf("bounced inside the spread hold: %s", why)
	}
	if why := routeNeedsRescue(at.Add(circuitsFor + 7*time.Second)); why == "" {
		t.Fatal("no bounce after the spread hold")
	}
}

// new circuits at most once in their gap: a dead spell soon after gets a probe, then the bounce
func TestNewCircuitsHaveAGap(t *testing.T) {
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	t0 := time.Unix(1_700_000_000, 0)
	failAll(t0, "wss://a", "wss://b")
	if why := routeNeedsRescue(t0.Add(61 * time.Second)); !strings.HasPrefix(why, circuitsWhy) {
		t.Fatalf("first spell: %q", why)
	}
	routeNoteOK()
	t1 := t0.Add(3 * time.Minute)
	failAll(t1, "wss://a", "wss://b")
	if why := routeNeedsRescue(t1.Add(61 * time.Second)); !strings.HasPrefix(why, probeWhy) {
		t.Fatalf("a spell soon after new circuits: %q, want a probe", why)
	}
	why := routeNeedsRescue(t1.Add(61*time.Second + circuitsFor))
	if why == "" || strings.HasPrefix(why, circuitsWhy) || strings.HasPrefix(why, probeWhy) {
		t.Fatalf("nothing answered the probe: %q, want the bounce", why)
	}
	routeNoteOK()
	t2 := t0.Add(61*time.Second + circuitsGap)
	failAll(t2, "wss://a", "wss://b")
	if why := routeNeedsRescue(t2.Add(61 * time.Second)); !strings.HasPrefix(why, circuitsWhy) {
		t.Fatalf("a spell past the gap: %q, want new circuits", why)
	}
}

// what the transport screen reads: the newest first, a dozen at most
func TestBounceNotesKeepTheLatest(t *testing.T) {
	bounceMu.Lock()
	oldNotes, oldTotal := bounceNotes, bounceTotal
	bounceNotes, bounceTotal = nil, map[string]int{}
	bounceMu.Unlock()
	t.Cleanup(func() {
		bounceMu.Lock()
		bounceNotes, bounceTotal = oldNotes, oldTotal
		bounceMu.Unlock()
	})
	for i := 0; i < bounceKeep+3; i++ {
		noteBounce(whyNetwork)
	}
	noteBounce(whyRelays)
	notes, total := bounceSnapshot()
	if len(notes) != bounceKeep {
		t.Fatalf("%d kept, want %d", len(notes), bounceKeep)
	}
	if notes[0].Why != whyRelays {
		t.Fatalf("newest first: %+v", notes[0])
	}
	if total[whyNetwork] != bounceKeep+3 || total[whyRelays] != 1 {
		t.Fatalf("counts %v", total)
	}
	v := transportSnapshot()
	if len(v.Bounces) != bounceKeep || v.BounceCounts[whyRelays] != 1 {
		t.Fatalf("transport state: %d bounces, counts %v", len(v.Bounces), v.BounceCounts)
	}
}

// the gap between rescues is spread a tenth either way, so phones that lost
// a relay together do not bounce tor together
func TestRescueGapIsSpread(t *testing.T) {
	seen := map[time.Duration]bool{}
	for i := 0; i < 50; i++ {
		d := rescueJitter(2 * time.Minute)
		if d < 108*time.Second || d > 132*time.Second {
			t.Fatalf("gap %s outside a tenth of two minutes", d)
		}
		seen[d] = true
	}
	if len(seen) < 10 {
		t.Fatalf("only %d different gaps in 50", len(seen))
	}
}

// every bounce names why, and the reasons the watch gives map to them
func TestRescueKinds(t *testing.T) {
	for why, want := range map[string]string{
		"tor says ready but every relay has failed for 1m1s": whyRelays,
		"bootstrap has not moved from 50% for 3m0s":          whyStall,
		"tor has been off for 15s":                           whyTorOff,
	} {
		if got := rescueKind(why); got != want {
			t.Errorf("%q: %q, want %q", why, got, want)
		}
	}
}

// relays that answer the upgrade with an http status are up behind a route
// that works: busy, or down behind their front. not tor's failure
func TestUpgradeRefusalIsNotADeadRoute(t *testing.T) {
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks)
	u1, d1 := refusingRelay(t)
	u2, d2 := refusingRelay(t)
	useRelays(u1, u2)
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	peer := newXid(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, mustRcv(t, peer))
	kickUntil(t, "both relays refused twice", func() bool {
		relayClearBenches()
		return d1.Load() >= 2 && d2.Load() >= 2
	})
	if n := failedCount(); n != 0 {
		t.Fatalf("%d relays that answered 503 were counted against the route", n)
	}
	if why := routeNeedsRescue(time.Now().Add(5 * time.Minute)); why != "" {
		t.Fatalf("a rescue for relays that answered: %s", why)
	}
}

// a bounce that goes ahead is noted with the reason it was asked for
func TestBounceKeepsItsReason(t *testing.T) {
	fc := newFakeControl(t, 100)
	fakeTor(t, fc.port())
	// no onion: the publish watch would log two minutes on, in another test
	mu.Lock()
	myAddr = ""
	mu.Unlock()
	resetRoute(t, "publishing", 100)
	oldSettle := bounceSettle
	bounceSettle = time.Millisecond
	defer func() { bounceSettle = oldSettle }()
	atomic.StoreInt64(&lastTorRestart, 0)
	if r := reconnectTorFor(whyRelays); r != "ok" {
		t.Fatalf("reconnect: %s", r)
	}
	notes, _ := bounceSnapshot()
	if len(notes) == 0 || notes[0].Why != whyRelays {
		t.Fatalf("noted as %+v, want %q", notes, whyRelays)
	}
}

// a mode switch starts a new route: an answer that came the old way proves
// nothing about the new one
func TestModeSwitchStartsANewRoute(t *testing.T) {
	useStandIns(t, modeFast, nil)
	resetRoute(t, "publishing", 100)
	gen := routeGeneration()
	switchMode(modePrivate)
	if routeGeneration() == gen {
		t.Fatal("the switch kept the route generation")
	}
	routeAliveOn(gen, "wss://direct.example")
	if routeOK() {
		t.Fatal("an answer from before the switch proved the onion route")
	}
}

// probes at most once in their gap too: a spell soon after one waits for the
// live sockets' own probes instead of kicking every runner again
func TestProbesHaveAGap(t *testing.T) {
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	t0 := time.Unix(1_700_000_000, 0)
	spell := func(at time.Time) string {
		routeNoteOK()
		failAll(at, "wss://a", "wss://b")
		return routeNeedsRescue(at.Add(61 * time.Second))
	}
	if why := spell(t0); !strings.HasPrefix(why, circuitsWhy) {
		t.Fatalf("first spell: %q", why)
	}
	t1 := t0.Add(2 * time.Minute)
	if why := spell(t1); !strings.HasPrefix(why, probeWhy) {
		t.Fatalf("second spell: %q, want a probe", why)
	}
	t2 := t1.Add(2 * time.Minute)
	if why := spell(t2); why != "" {
		t.Fatalf("a spell inside the probe gap: %q, want nothing", why)
	}
	t3 := t1.Add(61*time.Second + probeGap)
	if why := spell(t3); !strings.HasPrefix(why, probeWhy) {
		t.Fatalf("a spell past the probe gap: %q, want a probe", why)
	}
}
