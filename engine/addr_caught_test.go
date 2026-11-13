// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a linked device's phone pair reads as caught up only once a relay
// walked it to the bottom, each address on its own

import (
	"encoding/hex"
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
	addrsCaught.Clear()
	t.Cleanup(addrsCaught.Clear)

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
		return addrCaughtOf(dvA5, seeded) == "1"
	})
	// what the walk brought is in the inbox by then
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
	if got := addrCaughtOf(dvA5, "nothex/1/5"); !strings.HasPrefix(got, "error: ") {
		t.Fatalf("a bad arg: %s", got)
	}
}
