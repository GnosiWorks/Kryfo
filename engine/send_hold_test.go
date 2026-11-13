// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a held engine sends nothing: no wrap, no wrap a store missed sent again
// on its own, no line to a door. let go, the waiting wrap goes

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestASendHoldStopsEveryWayOut(t *testing.T) {
	t.Cleanup(func() { sendHeld.Store(false) })
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	standInDown(a, true)
	peer := newXid(t)
	ev := wrapToAt(t, peer, myXPub, "before the hold", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
		t.Fatal("not sent")
	}
	waitFor(t, "it waits for a", 10*time.Second, func() bool { return len(topupFor(storeFirst)) == 1 })

	tookIt := func(r *relayStandIn, id string) bool {
		for _, c := range r.snapshot() {
			for _, e := range c.got {
				if e.ID.Hex() == id {
					return true
				}
			}
		}
		return false
	}

	sendHeld.Store(true)
	// a fresh wrap goes nowhere
	held := wrapToAt(t, peer, myXPub, "while held", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, held); ok != 0 {
		t.Fatalf("%d relays took a held wrap", ok)
	}
	// a's answer would send what it missed: not while held, and it waits on
	standInDown(a, false)
	relayOK(a.url())
	topupKick(a.url())
	if topupFlush(storeFirst, a.url()) {
		t.Fatal("a held flush says it is done")
	}
	time.Sleep(500 * time.Millisecond)
	if tookIt(a, ev.ID.Hex()) || tookIt(b, held.ID.Hex()) || tookIt(a, held.ID.Hex()) {
		t.Fatal("sent while held")
	}
	if n := len(topupFor(storeFirst)); n != 1 {
		t.Fatalf("the hold dropped what waits: %d", n)
	}
	// a door gets no line either
	if err := sendToAs(nil, "x.onion", "line", doorMessage); !errors.Is(err, errSendHeld) {
		t.Fatalf("a door line: %v", err)
	}
	if err := sendTyping(nil, "x.onion", "line"); !errors.Is(err, errSendHeld) {
		t.Fatalf("a typing line: %v", err)
	}
	if r := handlePost("/handle/claim", nil); r != "error: "+errSendHeld.Error() {
		t.Fatalf("a handle claim: %s", r)
	}

	// let go: what waited goes
	sendHeld.Store(false)
	topupMu.Lock()
	topupAfter = map[string]time.Time{}
	topupMu.Unlock()
	relayOK(a.url())
	waitFor(t, "a took it once let go", 10*time.Second, func() bool { return tookIt(a, ev.ID.Hex()) })
}
