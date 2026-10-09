// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"testing"
	"time"
)

func dropFirstContactSub(t *testing.T) {
	t.Helper()
	nostrMu.Lock()
	if cancel, ok := nostrSubs["firstcontact"]; ok {
		cancel()
		delete(nostrSubs, "firstcontact")
	}
	nostrMu.Unlock()
	waitFor(t, "the old listener's loops to end", 10*time.Second, func() bool {
		return fcRelaysLive.Load() == 0
	})
}

// the app reads how many relays the first-contact listener is on, so one
// that started on an empty list is seen and started again
func TestFirstContactRelaysCountsLiveLoops(t *testing.T) {
	socks := newSocksStandIn(t)
	a := newRelayStandIn(t, 0)
	b := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, a, b)
	t.Cleanup(func() { dropFirstContactSub(t) })
	dropFirstContactSub(t)

	if n := firstContactRelays(); n != -1 {
		t.Fatalf("no listener reads %d, not -1", n)
	}
	if err := subscribeFirstContact(0); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "both relays listened on", 10*time.Second, func() bool {
		return firstContactRelays() == 2
	})

	// started again on an empty list: on no relay at all
	setRelays(nil)
	if err := subscribeFirstContact(0); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "the listener on no relay", 10*time.Second, func() bool {
		return firstContactRelays() == 0
	})

	setRelays([]string{a.url()})
	if err := subscribeFirstContact(0); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "one relay listened on", 10*time.Second, func() bool {
		return firstContactRelays() == 1
	})
}
