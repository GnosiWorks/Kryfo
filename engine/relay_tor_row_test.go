// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

// the transport row the app reads for u, as the banner does
func rowOf(t *testing.T, u string) relayView {
	t.Helper()
	for _, r := range transportSnapshot().Relays {
		if r.URL == u {
			return r
		}
	}
	t.Fatalf("no row for %s", u)
	return relayView{}
}

func ownDownNowForTest() bool {
	liveMu.Lock()
	defer liveMu.Unlock()
	return ownDown
}

// a direct runner on own with its socket up, and a hidden one, which keeps
// tor on fast
func fastRunners(t *testing.T, ctx context.Context, own *relayStandIn, socks *socksStandIn) {
	t.Helper()
	freshInbox(t)
	for _, hidden := range []bool{false, true} {
		peer := newXid(t)
		_, rcv, err := nip17RcvAddressAs(testMain(), peer.pub)
		if err != nil {
			t.Fatal(err)
		}
		c := ctx
		if hidden {
			c = asHidden(ctx)
		}
		go nostrSubscribeRunner(c, hex.EncodeToString(peer.pub[:]), mainPair(peer.pub), rcv)
	}
	waitFor(t, "a direct socket", 10*time.Second, func() bool {
		return openSubs(own, socks, false) >= 1
	})
}

// fast, the 2026-11-14 redmi: tor cannot build a circuit while the direct
// sockets carry. the hidden, first-contact and hello lanes fail through tor
// on every try, and our relay's row stays clean: no "not answering", no
// public relays read for an outage that is not there
func TestTorFailingOnFastLeavesOurRowClean(t *testing.T) {
	socks := newSocksStandIn(t)
	own := newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, socks, own)
	setFailBurst(t, 0)
	socks.refuse.Store(true)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	fastRunners(t, ctx, own, socks)
	t.Cleanup(func() { dropFirstContactSub(t) })
	dropFirstContactSub(t)
	if err := subscribeFirstContact(mainIdent, 0); err != nil {
		t.Fatal(err)
	}
	me, err := identityOf(mainIdent)
	if err != nil {
		t.Fatal(err)
	}
	pctx, pcancel := context.WithTimeout(ctx, 5*time.Second)
	defer pcancel()
	if n := nostrPublishMulti(pctx, laneHello, wrapTo(t, me, newXid(t).pub, "hi")); n != 0 {
		t.Fatalf("a hello went out %d times with tor refusing", n)
	}

	u := own.url()
	clean := func(what string) {
		t.Helper()
		if n := failsOf(u); n != 0 {
			t.Fatalf("%s: our row has %d failures from tor", what, n)
		}
		if r := rowOf(t, u); r.Fails != 0 || r.Benched || !r.Up {
			t.Fatalf("%s: row %+v", what, r)
		}
		if ownDownNowForTest() {
			t.Fatalf("%s: our relay read as down", what)
		}
	}
	waitFor(t, "the tor lanes failing", 15*time.Second, func() bool {
		return socks.refused.Load() >= 4 && failsOf(torRowPrefix+u) > 0
	})
	clean("tor refusing")
	if r := rowOf(t, u); r.TorFails == 0 {
		t.Fatalf("the tor lanes' failures are not shown apart: %+v", r)
	}

	// tor flapping: never once our row
	for i := 0; i < 6; i++ {
		socks.refuse.Store(i%2 == 1)
		socks.cut()
		end := time.Now().Add(700 * time.Millisecond)
		for time.Now().Before(end) {
			clean("tor flapping")
			time.Sleep(50 * time.Millisecond)
		}
	}
	// tor back: its row clears as well
	socks.refuse.Store(false)
	waitFor(t, "the tor row cleared", 25*time.Second, func() bool {
		return failsOf(torRowPrefix+u) == 0
	})
	clean("tor back")
}

// our relay down, really: the direct way fails, the row says so as soon as
// it did before, and its coming back clears it
func TestOurRelayDownStillShowsAndClears(t *testing.T) {
	socks := newSocksStandIn(t)
	own := newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, socks, own)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	fastRunners(t, ctx, own, socks)
	u := own.url()
	waitFor(t, "the row up", 10*time.Second, func() bool { return rowOf(t, u).Up })

	own.mu.Lock()
	own.down = true
	conns := own.conns
	own.mu.Unlock()
	for _, c := range conns {
		c.kill()
	}
	// the app shows the banner 20 s after every row failed: the first
	// failed redial is within the own ceiling
	waitFor(t, "the row failing", ownRelayCeiling*6/5+3*time.Second, func() bool {
		return rowOf(t, u).Fails > 0
	})

	own.mu.Lock()
	own.down = false
	own.mu.Unlock()
	waitFor(t, "the row clean again", ownRelayCeiling*6/5+5*time.Second, func() bool {
		r := rowOf(t, u)
		return r.Fails == 0 && !r.Benched
	})
}

// one failure, then the relay answers on a socket that stayed up: the
// streak is over. before, only a new subscription or a send ended it, so a
// quiet phone held "not answering" over sockets that carried
func TestAnAnswerEndsAFailingStreak(t *testing.T) {
	useStandIns(t, modeBalanced, nil)
	setFailBurst(t, 0)
	u := "wss://relay.kryfo.app"
	setRelays([]string{u, "wss://relay2.kryfo.app"})
	for i := 0; i < 8; i++ {
		relayFailed(u, time.Now())
	}
	if failsOf(u) == 0 {
		t.Fatal("no failure counted")
	}
	relayUp(u)
	if n := failsOf(u); n != 0 || benchLeft(u) != 0 {
		t.Fatalf("an answer left %d failures, %s on the bench", n, benchLeft(u))
	}
	if r := rowOf(t, u); r.Fails != 0 || r.Benched || !r.Up {
		t.Fatalf("row %+v", r)
	}

	// an attempt begun before the relay answered on another socket went
	// down on its own: not counted
	began := time.Now().Add(-time.Second)
	relayUp(u)
	relayFailed(u, began)
	if n := failsOf(u); n != 0 {
		t.Fatalf("a failure older than an answer counted: %d", n)
	}
	// one begun after is
	relayFailed(u, time.Now())
	if n := failsOf(u); n != 1 {
		t.Fatalf("a fresh failure: %d, want 1", n)
	}
}

// our relay turning a wrap away is benched as before, so the next send
// spares it, and its next answer on a socket that stayed up ends that
func TestOurRelayTurningAWrapAwayEndsWithItsNextAnswer(t *testing.T) {
	useStandIns(t, modeBalanced, nil)
	setFailBurst(t, 0)
	own := "wss://relay.kryfo.app"
	setRelays([]string{own, "wss://relay2.kryfo.app"})
	for i := 0; i < 8; i++ {
		relayRefused(own, time.Now(), errors.New("msg: rate-limited: the relay is busy"))
	}
	if failsOf(own) == 0 {
		t.Fatal("a refusal no longer counts")
	}
	relayUp(own)
	if n := failsOf(own); n != 0 || benchLeft(own) != 0 {
		t.Fatalf("after an answer: %d failures, %s on the bench", n, benchLeft(own))
	}
}

// the tor rows never reach the banner's fields, on fast only: on private
// tor is the way, and its failures are our relay's row as before
func TestHealthKeyByRoute(t *testing.T) {
	useStandIns(t, modeBalanced, nil)
	own := "wss://relay.kryfo.app"
	setRelays([]string{own, "wss://relay2.kryfo.app"})
	// with no tor stand-in pinned the hook takes these as clear; the app
	// has none
	clearTestHosts.Clear()
	for _, lane := range []string{laneFirstContact, laneHello, "room:x", "pair:x", laneHidden + ":x"} {
		if k := healthKey(lane, own); k != torRowPrefix+own {
			t.Fatalf("fast %s: row %q", lane, k)
		}
	}
	if k := healthKey(laneEveryday, own); k != own {
		t.Fatalf("fast everyday: row %q", k)
	}
	if k := healthKey(laneFirstContact, "wss://public.example"); k != "wss://public.example" {
		t.Fatalf("a public relay: row %q", k)
	}
	transportMode.Store(modePrivate)
	if k := healthKey(laneFirstContact, own); k != own {
		t.Fatalf("private first contact: row %q", k)
	}
}

// a check-in kicks and waits for a catch-up to begin. sockets that are up
// answer the kick's probe and keep their subscription: that is a relay
// reached, in every mode, not "no relay reached" over sockets that carry
func TestAKickAnsweredLiveCountsAsReached(t *testing.T) {
	for _, m := range []string{modeBalanced, modePrivate} {
		t.Run(m, func(t *testing.T) {
			socks := newSocksStandIn(t)
			relay := newRelayStandIn(t, 0)
			useStandIns(t, m, socks, relay)
			old := kickSpread
			kickSpread = 500 * time.Millisecond
			t.Cleanup(func() { kickSpread = old })
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			peer := newXid(t)
			rcv := mustRcv(t, peer)
			go nostrSubscribeRunner(alone(ctx), hex.EncodeToString(peer.pub[:]), mainPair(peer.pub), rcv)
			waitFor(t, "the subscription caught up", 20*time.Second, func() bool {
				catchupMu.Lock()
				defer catchupMu.Unlock()
				_, done := catchupLast[catchupKey(relay.url(), rcv)]
				return done && atomic.LoadInt32(&catchupActive) == 0
			})
			conns := len(relay.snapshot())
			begun := atomic.LoadInt64(&catchupStarted)
			nostrKick()
			waitFor(t, "the kick answered", 15*time.Second, func() bool {
				return atomic.LoadInt64(&catchupStarted) > begun && atomic.LoadInt32(&catchupActive) == 0
			})
			if n := len(relay.snapshot()); n != conns {
				t.Fatalf("%d connections after the kick, want the live one kept (%d)", n, conns)
			}
		})
	}
}

// private, a quiet route that carries: two of our relays fail a dial while
// the live socket has nothing to say. the live sockets are asked at once,
// and their answer keeps the pill off. with no live socket to answer, the
// route still reads down, and the next answer clears it
func TestPrivateQuietRouteAnswersBeforeThePill(t *testing.T) {
	socks := newSocksStandIn(t)
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, relay)
	resetRoute(t, "reachable", 100)
	oldWait, oldGap := routeAskWait, routeAskGap
	routeAskWait, routeAskGap = 15*time.Second, time.Minute
	t.Cleanup(func() { routeAskWait, routeAskGap = oldWait, oldGap })
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	peer := newXid(t)
	rcv := mustRcv(t, peer)
	go nostrSubscribeRunner(alone(ctx), hex.EncodeToString(peer.pub[:]), mainPair(peer.pub), rcv)
	waitFor(t, "the route proven by the live socket", 20*time.Second, func() bool {
		catchupMu.Lock()
		_, done := catchupLast[catchupKey(relay.url(), rcv)]
		catchupMu.Unlock()
		return done && routeOK()
	})
	probes := func() int {
		n := 0
		for _, c := range relay.snapshot() {
			n += len(c.reqs)
		}
		return n
	}
	// two relays that answered on this route fail a dial: ours, and
	// another that answered lately
	other := "wss://other.example"
	routeAnswered(other, -1)
	before := probes()
	routeNoteFail(relay.url())
	routeNoteFail(other)
	if n := failedCount(); n != 2 && n != 0 {
		t.Fatalf("%d failures counted", n)
	}
	routeMu.Lock()
	firstFailAt = time.Now().Add(-21 * time.Second)
	routeMu.Unlock()
	end := time.Now().Add(10 * time.Second)
	for !(probes() > before && failedCount() == 0) {
		if time.Now().After(end) {
			t.Fatalf("no answer to the ask: %d reqs before, %d after, %d failures", before, probes(), failedCount())
		}
		time.Sleep(50 * time.Millisecond)
	}
	if !routeOK() {
		t.Fatal("the route reads down while its live socket answers")
	}

	// nothing live: a real outage still shows, once the ask had its time
	cancel()
	runnersGone(t)
	routeMu.Lock()
	routeAskAt = time.Time{}
	routeMu.Unlock()
	routeNoteFail(relay.url())
	routeNoteFail(other)
	routeMu.Lock()
	firstFailAt = time.Now().Add(-21 * time.Second)
	routeAskAt = time.Now().Add(-routeAskWait - time.Second)
	routeMu.Unlock()
	if routeOK() {
		t.Fatal("every relay failing reads up")
	}
	// and the first answer ends it: nothing sticks
	if !probeProves(relay.url(), func() bool { return true }) || !routeOK() {
		t.Fatal("an answer did not clear the route's doubt")
	}
}
