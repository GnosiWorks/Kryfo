// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a walk's pages are random slices of the conversation. the poll keeps them
// until the walk is out, so the app puts the whole catch-up in order, and
// never keeps them past the hold's limits. other addresses are not kept.

import (
	"strings"
	"testing"
	"time"
)

func pollHoldReset(t *testing.T) {
	t.Helper()
	reset := func() {
		nostrMu.Lock()
		nostrInbox, nostrInboxDone = nil, nil
		pollHeldSince = time.Time{}
		walkingTags = map[string]int{}
		nostrMu.Unlock()
	}
	reset()
	t.Cleanup(reset)
}

func pollHoldPut(lines ...string) {
	nostrMu.Lock()
	for _, l := range lines {
		nostrInbox = append(nostrInbox, l)
		nostrInboxDone = append(nostrInboxDone, inboxDone{})
	}
	nostrMu.Unlock()
}

func TestPollHoldsAWalkUntilItIsOut(t *testing.T) {
	pollHoldReset(t)
	now := time.Unix(1_800_000_000, 0)
	walkBegins("x-alice")
	pollHoldPut("x-alice|c2")
	if got := nostrPollAt(now); got != "" {
		t.Fatalf("handed over while the walk was going: %s", got)
	}
	// the next page
	pollHoldPut("x-alice|c0", "x-alice|c1")
	if got := nostrPollAt(now.Add(5 * time.Second)); got != "" {
		t.Fatalf("handed over while the walk was going: %s", got)
	}
	walkEnds("x-alice")
	got := nostrPollAt(now.Add(6 * time.Second))
	for _, c := range []string{"c2", "c0", "c1"} {
		if !strings.Contains(got, `"c":"`+c+`"`) {
			t.Fatalf("%s missing from the batch: %s", c, got)
		}
	}
	if again := nostrPollAt(now.Add(7 * time.Second)); again != "" {
		t.Fatalf("handed over twice: %s", again)
	}
}

func TestPollWithNoWalkHandsOverAtOnce(t *testing.T) {
	pollHoldReset(t)
	pollHoldPut("x-alice|live")
	if got := nostrPollAt(time.Unix(1_800_000_000, 0)); !strings.Contains(got, "live") {
		t.Fatalf("a live wrap waited: %q", got)
	}
}

func TestPollHoldEndsAfterItsTime(t *testing.T) {
	pollHoldReset(t)
	now := time.Unix(1_800_000_000, 0)
	walkBegins("x-alice")
	pollHoldPut("x-alice|c0")
	if got := nostrPollAt(now); got != "" {
		t.Fatalf("handed over at once: %s", got)
	}
	if got := nostrPollAt(now.Add(pollHoldMax)); !strings.Contains(got, "c0") {
		t.Fatalf("a walk that never ends kept the wraps: %q", got)
	}
	// a new hold starts from the next line, not the old one
	pollHoldPut("x-alice|c1")
	if got := nostrPollAt(now.Add(pollHoldMax + time.Second)); got != "" {
		t.Fatalf("the next line was not held: %s", got)
	}
}

func TestPollHoldEndsPastItsSize(t *testing.T) {
	pollHoldReset(t)
	walkBegins("x-alice")
	big := strings.Repeat("a", pollHoldBytes/2+1)
	pollHoldPut("x-alice|"+big, "x-alice|"+big)
	if got := nostrPollAt(time.Unix(1_800_000_000, 0)); got == "" {
		t.Fatal("held past the size limit")
	}
}

// a reconnect walking one contact's address holds nobody else's messages,
// receipts or room chat
func TestPollHoldsOnlyTheAddressWalked(t *testing.T) {
	pollHoldReset(t)
	now := time.Unix(1_800_000_000, 0)
	walkBegins("x-alice")
	pollHoldPut("x-alice|a1", "x-bob|b1", "room:r1:x-carol|r1", "firstcontact|f1")
	got := nostrPollAt(now)
	for _, c := range []string{"b1", "r1", "f1"} {
		if !strings.Contains(got, `"c":"`+c+`"`) {
			t.Fatalf("%s waited on another address's walk: %s", c, got)
		}
	}
	if strings.Contains(got, "a1") {
		t.Fatalf("the walked address went over: %s", got)
	}
	pollHoldPut("x-bob|b2", "x-alice|a0")
	got = nostrPollAt(now.Add(time.Second))
	if !strings.Contains(got, "b2") || strings.Contains(got, "a0") {
		t.Fatalf("the second poll: %s", got)
	}
	walkEnds("x-alice")
	got = nostrPollAt(now.Add(2 * time.Second))
	if !strings.Contains(got, "a1") || !strings.Contains(got, "a0") ||
		strings.Index(got, "a1") > strings.Index(got, "a0") {
		t.Fatalf("the walk did not go over whole and in arrival order: %s", got)
	}
}

// one address walked on two relays is held until both are out
func TestPollHoldsUntilEveryRelaysWalkIsOut(t *testing.T) {
	pollHoldReset(t)
	now := time.Unix(1_800_000_000, 0)
	walkBegins("x-alice")
	walkBegins("x-alice")
	pollHoldPut("x-alice|a1")
	walkEnds("x-alice")
	if got := nostrPollAt(now); got != "" {
		t.Fatalf("went over with a relay still walking: %s", got)
	}
	walkEnds("x-alice")
	if got := nostrPollAt(now.Add(time.Second)); !strings.Contains(got, "a1") {
		t.Fatalf("kept after both walks were out: %q", got)
	}
	nostrMu.Lock()
	left := len(walkingTags)
	nostrMu.Unlock()
	if left != 0 {
		t.Fatalf("%d walks left counted", left)
	}
}
