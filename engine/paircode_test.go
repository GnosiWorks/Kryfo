// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
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
// the same invite put there again in an event of its own is a second event.
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
	if got := pairCodeFetch(code); got != "twice" {
		t.Fatalf("the same invite in two events gave %q", got)
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

// a share is one event: the same one on every relay is taken, and every relay
// is asked for as many events as a full answer holds
func TestPairCodeOneEventOnManyRelays(t *testing.T) {
	relays := make([]*relayStandIn, 4)
	for i := range relays {
		relays[i] = newRelayStandIn(t, 0)
		relays[i].keep = true
	}
	useStandIns(t, modeBalanced, nil, relays...)

	const code = "482913"
	const invite = "kryfo://share?id=the-sharer"
	if r := pairCodePublish(code, invite); r != "ok" {
		t.Fatalf("share: %s", r)
	}
	waitFor(t, "the invite on every relay", 10*time.Second, func() bool {
		for _, r := range relays {
			if keptEvents(r) != 1 {
				return false
			}
		}
		return true
	})
	// one relay sends it twice over: still the one event
	relays[1].mu.Lock()
	relays[1].events = append(relays[1].events, relays[1].events[0])
	relays[1].mu.Unlock()

	if got := pairCodeFetch(code); got != invite {
		t.Fatalf("the joiner got %q", got)
	}
	for i, r := range relays {
		asked := false
		for _, c := range r.snapshot() {
			for _, q := range c.reqs {
				if q.filter.Tags["p"] != nil {
					asked = true
					if q.filter.Limit != pairQueryLimit {
						t.Errorf("relay %d was asked for %d events", i, q.filter.Limit)
					}
				}
			}
		}
		if !asked {
			t.Errorf("relay %d was not asked", i)
		}
	}
}

// newer events at the code's address do not stand in for the sharer's: the
// code is refused however many there are, on one relay or on all of them
func TestPairCodeRefusesNewerEvents(t *testing.T) {
	const code = "482913"
	sharer := "kryfo://share?id=the-sharer"
	other := "kryfo://share?id=the-sharer&onion=elsewhere"
	at := time.Now().Add(-2 * time.Minute)

	for _, n := range []int{1, 20, pairQueryLimit - 1, pairQueryLimit + 5} {
		t.Run(fmt.Sprintf("%d newer on every relay", n), func(t *testing.T) {
			a := newRelayStandIn(t, 0)
			b := newRelayStandIn(t, 0)
			useStandIns(t, modeBalanced, nil, a, b)
			first := pairEventAt(t, code, sharer, at)
			a.store(first)
			b.store(first)
			for i := 0; i < n; i++ {
				ev := pairEventAt(t, code, other, at.Add(time.Duration(i+1)*time.Second))
				a.store(ev)
				b.store(ev)
			}
			if got := pairCodeFetch(code); got != "twice" {
				t.Fatalf("the joiner got %q", got)
			}
		})
	}
}

// an answer as long as the limit is refused even when every event in it is
// the same one: what the relay left out is not known
func TestPairCodeRefusesAFullAnswer(t *testing.T) {
	const code = "482913"
	r := newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, nil, r)
	ev := pairEventAt(t, code, "kryfo://share?id=the-sharer", time.Now())
	for i := 0; i < pairQueryLimit; i++ {
		r.store(ev)
	}
	if got := pairCodeFetch(code); got != "twice" {
		t.Fatalf("a full answer gave %q", got)
	}

	r.mu.Lock()
	r.events = r.events[:pairQueryLimit-1]
	r.mu.Unlock()
	if got := pairCodeFetch(code); got != "kryfo://share?id=the-sharer" {
		t.Fatalf("an answer one short of full gave %q", got)
	}
}

// each event at a code is signed by a key of its own, never the code's
func TestPairCodeEventHasItsOwnAuthor(t *testing.T) {
	const code = "482913"
	now := time.Now()
	a, pk, err := pairCodeEvent(code, "x", now)
	if err != nil {
		t.Fatal(err)
	}
	b, _, err := pairCodeEvent(code, "x", now)
	if err != nil {
		t.Fatal(err)
	}
	if a.PubKey.Hex() == pk || b.PubKey.Hex() == pk {
		t.Fatal("an event is signed with the code's key")
	}
	if a.PubKey == b.PubKey {
		t.Fatal("two events share an author")
	}
	if !a.VerifySignature() || !b.VerifySignature() {
		t.Fatal("an event does not verify")
	}
	if tg := a.Tags.Find("p"); len(tg) < 2 || tg[1] != pk {
		t.Fatalf("the event is not at the code's address: %v", tg)
	}
}

// no relay answering says nothing about the code: the joiner is told it
// was not reached, not that nothing is there. one relay answering is enough
// for an empty code to read as empty
func TestPairCodeRefusedRelaysAreUnreached(t *testing.T) {
	a := newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, nil, a)
	down, _ := refusingRelay(t)
	other, _ := refusingRelay(t)
	nostrMu.Lock()
	nostrRelays = []string{down, other}
	nostrMu.Unlock()
	if got := pairCodeFetch("111111"); got != pairUnreached {
		t.Fatalf("no relay answering gave %q", got)
	}
	nostrMu.Lock()
	nostrRelays = []string{down, a.url()}
	nostrMu.Unlock()
	if got := pairCodeFetch("111111"); got != "empty" {
		t.Fatalf("one relay answering gave %q", got)
	}
}

// a lookup no relay answered says so, rather than that the code holds
// nothing: the code may be right and the relays out of reach
func TestPairCodeUnreachedIsNotEmpty(t *testing.T) {
	const code = "482913"

	t.Run("no relay answers", func(t *testing.T) {
		a := newRelayStandIn(t, 0)
		b := newRelayStandIn(t, 0)
		useStandIns(t, modeBalanced, nil, a, b)
		a.srv.Close()
		b.srv.Close()
		if got := pairCodeFetch(code); got != pairUnreached {
			t.Fatalf("the joiner got %q", got)
		}
		if got := pairCodePublish(code, "kryfo://share?id=the-sharer"); got != pairUnreached {
			t.Fatalf("the sharer got %q", got)
		}
	})

	t.Run("one answers with nothing", func(t *testing.T) {
		a := newRelayStandIn(t, 0)
		b := newRelayStandIn(t, 0)
		useStandIns(t, modeBalanced, nil, a, b)
		b.srv.Close()
		if got := pairCodeFetch(code); got != "empty" {
			t.Fatalf("the joiner got %q", got)
		}
	})

	t.Run("none configured", func(t *testing.T) {
		useStandIns(t, modeBalanced, nil)
		if got := pairCodeFetch(code); got != pairUnreached {
			t.Fatalf("the joiner got %q", got)
		}
	})
}

// a relay slower to open than the deadline is still waited for while no
// other has answered
func TestPairCodeWaitsForTheFirstAnswer(t *testing.T) {
	old := pairQueryDeadline
	pairQueryDeadline = 300 * time.Millisecond
	t.Cleanup(func() { pairQueryDeadline = old })

	const code = "482913"
	const invite = "kryfo://share?id=the-sharer"
	r := newRelayStandIn(t, 0)
	r.upgradeDelay = time.Second
	useStandIns(t, modeBalanced, nil, r)
	r.store(pairEventAt(t, code, invite, time.Now()))
	if got := pairCodeFetch(code); got != invite {
		t.Fatalf("the joiner got %q", got)
	}
}

// past the deadline the first answer ends the lookup, even an empty one: a
// relay that never answers is not waited for to the end
func TestPairCodeLateAnswerEndsTheWait(t *testing.T) {
	old := pairQueryDeadline
	pairQueryDeadline = 300 * time.Millisecond
	t.Cleanup(func() { pairQueryDeadline = old })

	const code = "482913"
	slow := newRelayStandIn(t, 0)
	slow.upgradeDelay = time.Second
	silent := newRelayStandIn(t, 0)
	silent.upgradeDelay = 8 * time.Second
	useStandIns(t, modeBalanced, nil, slow, silent)
	start := time.Now()
	if got := pairCodeFetch(code); got != "empty" {
		t.Fatalf("the joiner got %q", got)
	}
	if took := time.Since(start); took > 4*time.Second {
		t.Fatalf("the lookup took %v", took)
	}
}
