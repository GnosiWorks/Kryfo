// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"net/http"
	"sync/atomic"
	"testing"
	"time"
)

// a tor row on fast backs off no longer than our relay down does: nothing
// wakes the first contacts, rooms and hidden chats napping on it once tor
// carries again, and the other store's two minutes kept them out that long
// (load test: 1m50 to all tor lanes back, 22 s on 0.6.1). the direct row
// keeps its ceiling
func TestATorRowWaitsNoLongerThanOurRelayDown(t *testing.T) {
	useStandIns(t, modeBalanced, nil)
	setFailBurst(t, 0)
	own, second := "wss://relay.kryfo.app", "wss://relay2.kryfo.app"
	setRelays([]string{own, second})
	clearTestHosts.Clear()
	tor := torRowPrefix + own
	if healthKey(laneFirstContact, own) != tor {
		t.Fatal("no tor row on fast")
	}
	// the other store answers: our first store's direct row may wait long
	relayUp(second)
	relayHealthMu.Lock()
	relayFails[tor], relayFails[own] = 9, 9
	relayHealthMu.Unlock()
	t.Cleanup(func() {
		relayHealthMu.Lock()
		for _, k := range []string{tor, own, second} {
			delete(relayFails, k)
			delete(relayCoolTill, k)
			delete(relayFailAt, k)
			delete(relayUpAt, k)
		}
		relayHealthMu.Unlock()
	})
	most := ownRelayCeiling * 6 / 5
	for i := 0; i < 50; i++ {
		if d := relayRetryAfter(tor, 3*time.Second, true); d > most {
			t.Fatalf("a tor row waits %s, more than our relay down's %s", d, most)
		}
	}
	if d := relayRetryAfter(own, 3*time.Second, true); d <= most {
		t.Fatalf("the direct row lost its ceiling: %s", d)
	}
	// its bench too
	relayFailed(tor, time.Now())
	if d := time.Until(relayCoolUntil(tor)); d > ownRelayCeiling {
		t.Fatalf("a tor row benched for %s", d)
	}
}

// a relay that turns new sockets away while it serves the old ones, as one
// at its connection cap does: every answer on the old sockets clears the
// row, so the turned-away runner must back off on its own count, not knock
// every three seconds
func TestARunnerTurnedAwayBacksOffWhileOthersAnswer(t *testing.T) {
	own := newRelayStandIn(t, 0)
	var dials atomic.Int64
	inner := own.srv.Config.Handler
	own.srv.Config.Handler = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		dials.Add(1)
		inner.ServeHTTP(w, r)
	})
	useStandIns(t, modeBalanced, nil, own)
	freshInbox(t)
	// each address a socket of its own
	oldLane := receiveLane
	receiveLane = func(_ int, rcvPk string) string { return laneEveryday + ":" + rcvPk }
	t.Cleanup(func() { receiveLane = oldLane })
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	served := newXid(t)
	go nostrSubscribeRunner(ctx, hex.EncodeToString(served.pub[:]), mainPair(served.pub), mustRcv(t, served))
	waitFor(t, "the served socket", 10*time.Second, func() bool {
		for _, c := range own.snapshot() {
			if c.closed.IsZero() && len(c.reqs) > 0 {
				return true
			}
		}
		return false
	})

	// full from now: old sockets answer, new ones are turned away
	own.mu.Lock()
	own.down = true
	own.mu.Unlock()
	go func() {
		for i := 0; ctx.Err() == nil; i++ {
			own.pushLive(wrapTo(t, served, testMain().pub, "live"))
			time.Sleep(300 * time.Millisecond)
		}
	}()
	before := dials.Load()
	turned := newXid(t)
	go nostrSubscribeRunner(ctx, hex.EncodeToString(turned.pub[:]), mainPair(turned.pub), mustRcv(t, turned))
	time.Sleep(40 * time.Second)
	n := dials.Load() - before
	// 3 s apart for the first three, then 10 s, 20 s (our relay's
	// ceiling): 6 in 40 s. without its own count: one every ~3 s, 13
	t.Logf("the turned-away runner dialled %d times in 40 s", n)
	if n > 8 {
		t.Fatalf("a runner turned away dialled %d times in 40 s while the row was kept clean", n)
	}
	if n < 3 {
		t.Fatalf("it gave up: %d dials", n)
	}
}
