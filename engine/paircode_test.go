// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"testing"
	"time"

	"fiatjaf.com/nostr"
)

func keptEvents(r *relayStandIn) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.events)
}

func pairEventAt(t *testing.T, code, payload string, at time.Time) nostr.Event {
	t.Helper()
	ev, _, err := pairCodeEvent(code, payload, at)
	if err != nil {
		t.Fatal(err)
	}
	return ev
}

// one invite at the code, on every relay, is the invite the joiner gets.
// the same invite put there again is still one invite.
func TestPairCodeOneInvite(t *testing.T) {
	a := newRelayStandIn(t, 0)
	b := newRelayStandIn(t, 0)
	a.keep, b.keep = true, true
	useStandIns(t, modeBalanced, nil, a, b)

	const code = "482913"
	const invite = "kryfo://share?id=the-sharer"
	if r := pairCodePublish(code, invite); r != "ok" {
		t.Fatalf("share: %s", r)
	}
	waitFor(t, "the invite on both relays", 10*time.Second, func() bool {
		return keptEvents(a) == 1 && keptEvents(b) == 1
	})
	start := time.Now()
	if got := pairCodeFetch(code); got != invite {
		t.Fatalf("the joiner got %q", got)
	}
	// every relay answered, so nothing waits out the window
	if took := time.Since(start); took > pairCollectWindow {
		t.Errorf("the fetch took %s with every relay answered", took)
	}

	a.store(pairEventAt(t, code, invite, time.Now().Add(time.Second)))
	if got := pairCodeFetch(code); got != invite {
		t.Fatalf("the same invite twice gave %q", got)
	}
	if got := pairCodeFetch("111111"); got != "empty" {
		t.Fatalf("a code nobody shared gave %q", got)
	}
}

// a code whose address holds two different invites gives neither, whether
// both are on one relay or each on its own
func TestPairCodeRefusesTwoInvites(t *testing.T) {
	const code = "482913"
	sharer := "kryfo://share?id=the-sharer"
	other := "kryfo://share?id=someone-else"

	t.Run("one relay", func(t *testing.T) {
		r := newRelayStandIn(t, 0)
		r.keep = true
		useStandIns(t, modeBalanced, nil, r)
		if res := pairCodePublish(code, sharer); res != "ok" {
			t.Fatalf("share: %s", res)
		}
		r.store(pairEventAt(t, code, other, time.Now().Add(time.Second)))
		if got := pairCodeFetch(code); got != "twice" {
			t.Fatalf("the joiner got %q", got)
		}
	})

	t.Run("one on each relay", func(t *testing.T) {
		a := newRelayStandIn(t, 0)
		b := newRelayStandIn(t, 0)
		useStandIns(t, modeBalanced, nil, a, b)
		a.store(pairEventAt(t, code, sharer, time.Now()))
		b.store(pairEventAt(t, code, other, time.Now()))
		if got := pairCodeFetch(code); got != "twice" {
			t.Fatalf("the joiner got %q", got)
		}
	})

	t.Run("the second one on a relay that answers late", func(t *testing.T) {
		a := newRelayStandIn(t, 0)
		b := newRelayStandIn(t, 0)
		b.reqDelay = time.Second
		useStandIns(t, modeBalanced, nil, a, b)
		a.store(pairEventAt(t, code, sharer, time.Now()))
		b.store(pairEventAt(t, code, other, time.Now()))
		if got := pairCodeFetch(code); got != "twice" {
			t.Fatalf("the joiner got %q", got)
		}
	})
}

// an invite from an earlier share of the same six digits does not count
// against the one that is there now
func TestPairCodeCountsOnlyLiveInvites(t *testing.T) {
	now := time.Now()
	const code = "482913"
	if !pairCodeLive(pairEventAt(t, code, "x", now), now) {
		t.Fatal("a fresh invite is not live")
	}
	if pairCodeLive(pairEventAt(t, code, "x", now.Add(-pairCodeLife-time.Second)), now) {
		t.Fatal("an invite past its expiration is live")
	}
	if pairCodeLive(pairEventAt(t, code, "x", now.Add(-time.Hour)), now) {
		t.Fatal("an hour old invite is live")
	}

	r := newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, nil, r)
	r.store(pairEventAt(t, code, "kryfo://share?id=last-week", now.Add(-7*24*time.Hour)))
	r.store(pairEventAt(t, code, "kryfo://share?id=the-sharer", now))
	if got := pairCodeFetch(code); got != "kryfo://share?id=the-sharer" {
		t.Fatalf("the joiner got %q", got)
	}
}
