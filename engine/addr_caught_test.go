// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a linked device's phone pair reads as caught up only once each of our
// stores walked it to the bottom and the app kept what came, each address
// on its own

import (
	"encoding/hex"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestAddrCaughtAfterTheWalk(t *testing.T) {
	r := newRelayStandIn(t, 0)
	r.mu.Lock()
	r.keep = true
	r.mu.Unlock()
	useStandIns(t, modeFast, nil, r)
	w := newDevWorld(t)
	nostrMu.Lock()
	nostrInbox, nostrInboxDone = nil, nil
	nostrMu.Unlock()
	seed := hex.EncodeToString(fixedSeed(3))
	opener := w.aHex + "/1/5"
	seeded := opener + "." + seed
	addrCaughtClear()
	t.Cleanup(addrCaughtClear)

	if got := addrCaughtOf(dvA5, opener); got != "0" {
		t.Fatalf("before any listen: %s", got)
	}
	// the phone's last word waits on the relay before the device listens
	if res := nostrSend(dvA1, w.aHex+"/5/1."+seed, "last"); res != "ok" {
		t.Fatal(res)
	}
	nostrMu.Lock()
	nostrSentIDs = map[string]bool{}
	nostrMu.Unlock()
	if res := nostrSubscribe(dvA5, opener, false); res != "ok" {
		t.Fatal(res)
	}
	defer nostrUnsubscribe(dvA5, opener)
	waitFor(t, "the opener walked", 10*time.Second, func() bool {
		return addrCaughtOf(dvA5, opener) == "1"
	})
	// the seeded address is another one: not caught by the opener's walk
	if got := addrCaughtOf(dvA5, seeded); got != "0" {
		t.Fatalf("seeded before its listen: %s", got)
	}
	if res := nostrSubscribe(dvA5, seeded, false); res != "ok" {
		t.Fatal(res)
	}
	defer nostrUnsubscribe(dvA5, seeded)
	waitFor(t, "the seeded walked", 10*time.Second, func() bool {
		return addrCaughtOf(dvA5, seeded) != "0"
	})
	// what the walk brought is in the inbox by then, and not kept yet
	if got := addrCaughtOf(dvA5, seeded); got != "p" {
		t.Fatalf("caught with its line still waiting: %s", got)
	}
	nostrMu.Lock()
	in := false
	for _, l := range nostrInbox {
		if strings.HasSuffix(l, "|last") {
			in = true
		}
	}
	nostrMu.Unlock()
	if !in {
		t.Fatal("caught up without the line the relay held")
	}
	// handed over and not kept yet still waits
	raw := nostrPoll()
	if raw == "" {
		t.Fatal("nothing to poll")
	}
	if got := addrCaughtOf(dvA5, seeded); got != "p" {
		t.Fatalf("caught with its line handed over: %s", got)
	}
	var b pollOut
	if err := json.Unmarshal([]byte(raw), &b); err != nil {
		t.Fatal(err)
	}
	if r := nostrAck(b.K, ""); r != "ok" {
		t.Fatal(r)
	}
	if got := addrCaughtOf(dvA5, seeded); got != "1" {
		t.Fatalf("kept: %s", got)
	}
	if got := addrCaughtOf(dvA5, "nothex/1/5"); !strings.HasPrefix(got, "error: ") {
		t.Fatalf("a bad arg: %s", got)
	}
}

// the phone's send ends at the first store that took it: one store walked
// is not enough while the other is in the list, and a public relay never
// counts
func TestAddrCaughtWantsEveryStore(t *testing.T) {
	a, b, pub := newRelayStandIn(t, 0), newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	for _, r := range []*relayStandIn{a, b} {
		r.mu.Lock()
		r.down = true
		r.mu.Unlock()
	}
	useStandIns(t, modeFast, nil, a, b, pub)
	old := secondRelayHost.get()
	secondRelayHost.put(strings.TrimPrefix(b.url(), "ws://"))
	t.Cleanup(func() {
		runnersGone(t)
		secondRelayHost.put(old)
	})
	w := newDevWorld(t)
	freshInbox(t)
	addrCaughtClear()
	t.Cleanup(addrCaughtClear)
	opener := w.aHex + "/1/5"

	// only the public relay answers: nothing
	if res := nostrSubscribe(dvA5, opener, false); res != "ok" {
		t.Fatal(res)
	}
	defer nostrUnsubscribe(dvA5, opener)
	time.Sleep(1500 * time.Millisecond)
	if got := addrCaughtOf(dvA5, opener); got != "0" {
		t.Fatalf("a public relay walked it: %s", got)
	}
	// the first store: one of two
	a.mu.Lock()
	a.down = false
	a.mu.Unlock()
	waitFor(t, "the first store walked", 20*time.Second, func() bool {
		return addrCaughtOf(dvA5, opener) == "p"
	})
	// the second too: caught
	b.mu.Lock()
	b.down = false
	b.mu.Unlock()
	waitFor(t, "the second store walked", 30*time.Second, func() bool {
		return addrCaughtOf(dvA5, opener) == "1"
	})
}
