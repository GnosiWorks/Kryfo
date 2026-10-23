// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"strconv"
	"strings"
	"testing"
	"time"
)

// a bump that tore nothing down: the live socket's next probe answer
// proves the route again, with no redial
func TestProbeAfterABumpProvesTheRoute(t *testing.T) {
	socks := newSocksStandIn(t)
	ours := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, ours)
	resetRoute(t, "reachable", 100)
	oldSpread := kickSpread
	kickSpread = 0
	defer func() { kickSpread = oldSpread }()
	peer := newXid(t)
	ctx, cancel := context.WithCancel(context.Background())
	// the runner ends before the stand-ins' cleanups put things back
	done := make(chan struct{})
	t.Cleanup(func() {
		cancel()
		<-done
	})
	go func() {
		defer close(done)
		nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, mustRcv(t, peer))
	}()
	waitFor(t, "the subscription", 10*time.Second, func() bool {
		cs := ours.snapshot()
		return len(cs) == 1 && len(cs[0].reqs) > 0
	})
	waitFor(t, "the route proven", 10*time.Second, routeOK)
	routeBump()
	if routeOK() {
		t.Fatal("the bump left the route proven")
	}
	kickUntil(t, "the probe proved the route", routeOK)
	if n := len(ours.snapshot()); n != 1 {
		t.Fatalf("proved by a redial, not the live socket: %d connections", n)
	}
}

// relays slow to fail after the route answered: those attempts began while
// the route carried, so they are the relays' own and the route stays up.
// one begun after the answer still counts
func TestFailureBegunBeforeAnAnswerIsTheRelaysOwn(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	resetRoute(t, "reachable", 100)
	a, b := "wss://slow-a.example", "wss://slow-b.example"
	t.Cleanup(func() {
		relayHealthMu.Lock()
		for _, u := range []string{a, b} {
			delete(relayFails, u)
			delete(relayFailAt, u)
			delete(relayCoolTill, u)
		}
		relayHealthMu.Unlock()
	})
	routeNoteOK()
	routeAnswered(a, -1)
	routeAnswered(b, -1)
	began := time.Now()
	time.Sleep(2 * time.Millisecond)
	// our relay took a publish begun at the same moment
	routeNoteOK()
	relayFailed(a, began)
	relayFailed(b, began)
	if n := failedCount(); n != 0 {
		t.Fatalf("%d failures of attempts begun before the answer counted against the route", n)
	}
	routeMu.Lock()
	firstFailAt = time.Now().Add(-time.Minute)
	routeMu.Unlock()
	if !routeOK() {
		t.Fatal("the route reads down while it answered after those attempts began")
	}
	time.Sleep(2 * time.Millisecond)
	relayFailed(a, time.Now())
	if n := failedCount(); n != 1 {
		t.Fatalf("a failure begun after the answer: %d counted, want 1", n)
	}
}

// the line the app reads: tor's status and the route's verdict from one
// reading, so a view never pairs a status with another moment's verdict
func TestStatusLineIsOneReading(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	resetRoute(t, "publishing", 100)
	if got := statusLine(); !strings.HasPrefix(got, "publishing|100|") || !strings.HasSuffix(got, "|0|0") {
		t.Fatalf("nothing answered yet: %q", got)
	}
	routeNoteOK()
	if got := statusLine(); !strings.HasSuffix(got, "|1|0") {
		t.Fatalf("answered: %q", got)
	}
	// tor torn down: its status says starting and the verdict follows it
	setTestStatus("starting", 10)
	if got := statusLine(); !strings.HasPrefix(got, "starting|10|") || !strings.HasSuffix(got, "|0|0") {
		t.Fatalf("starting: %q", got)
	}
	g := routeBump()
	if got := statusLine(); !strings.HasSuffix(got, "|0|"+strconv.FormatInt(g, 10)) {
		t.Fatalf("after a bump: %q", got)
	}
}

// the other direction: the route dies right after an answer. attempts that
// were already under way are those relays' own, the next round speaks for
// the route: it reads down 20 s after its first failure and the rescue
// still comes, its first step at deadFor
func TestARouteThatDiesAfterAnAnswerStillReadsDown(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	resetRoute(t, "reachable", 100)
	a, b := "wss://gone-a.example", "wss://gone-b.example"
	t.Cleanup(func() {
		relayHealthMu.Lock()
		for _, u := range []string{a, b} {
			delete(relayFails, u)
			delete(relayFailAt, u)
			delete(relayCoolTill, u)
		}
		relayHealthMu.Unlock()
	})
	routeNoteOK()
	routeAnswered(a, -1)
	routeAnswered(b, -1)
	inFlight := time.Now()
	time.Sleep(2 * time.Millisecond)
	// one last answer, then the guard goes
	routeNoteOK()
	relayFailed(a, inFlight)
	relayFailed(b, inFlight)
	if n := failedCount(); n != 0 {
		t.Fatalf("%d in-flight failures counted, want none", n)
	}
	// the next round of dials, begun after the answer, all fail
	time.Sleep(2 * time.Millisecond)
	next := time.Now()
	routeNoteFailFrom(a, next)
	routeNoteFailFrom(b, next)
	if n := failedCount(); n != 2 {
		t.Fatalf("the next round: %d counted, want 2", n)
	}
	routeMu.Lock()
	first := firstFailAt
	routeMu.Unlock()
	if !routeOK() {
		t.Fatal("down before its 20 s")
	}
	routeMu.Lock()
	firstFailAt = first.Add(-21 * time.Second)
	routeMu.Unlock()
	if routeOK() {
		t.Fatal("still up 21 s after the next round failed")
	}
	if why := routeNeedsRescue(first.Add(deadFor - time.Second)); why != "" {
		t.Fatalf("a rescue before deadFor: %q", why)
	}
	if why := routeNeedsRescue(first.Add(deadFor + time.Second)); why == "" {
		t.Fatal("no rescue for a route that died after an answer")
	}
}
