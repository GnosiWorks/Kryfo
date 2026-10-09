// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what the app leaves on the relay until a full shelf has room: passed over
// without being opened on every fetch after, at most seenHeldKeep of them
// an address, and fetched again by id once let go, wherever the anchor is.

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"fiatjaf.com/nostr"
)

func TestAHeldIDIsPassedOverUntilLetGo(t *testing.T) {
	path := filepath.Join(t.TempDir(), "seen")
	now := time.Now()
	s := loadSeen(path)
	id := randomID(t)
	if !s.claim(id) {
		t.Fatal("claim")
	}
	if !s.hold(id, nostr.Timestamp(now.Unix()), now) {
		t.Fatal("not held")
	}
	if s.claim(id) || s.handed(id) {
		t.Fatal("a held id is taken again or counted as kept")
	}
	// a restart remembers it
	again := loadSeen(path)
	if again.claim(id) || again.heldCount() != 1 || len(again.wanted(now)) != 0 {
		t.Fatal("a restart forgot the held id")
	}
	markHeldFile(path, seenFreeMark)
	freed := loadSeen(path)
	if w := freed.wanted(now); len(w) != 1 || w[0] != id {
		t.Fatalf("let go and not wanted: %v", w)
	}
	if !freed.claim(id) {
		t.Fatal("let go and still passed over")
	}
	freed.handedOver([]nostr.ID{id})
	after := loadSeen(path)
	if after.heldCount() != 0 || !after.handed(id) {
		t.Fatal("kept after it came back and still held")
	}
}

func TestADropTakesTheHeldAsKept(t *testing.T) {
	path := filepath.Join(t.TempDir(), "seen")
	now := time.Now()
	s := loadSeen(path)
	id := randomID(t)
	s.claim(id)
	s.hold(id, nostr.Timestamp(now.Unix()), now)
	markHeldFile(path, seenDropMark)
	d := loadSeen(path)
	if d.heldCount() != 0 || !d.handed(id) || d.claim(id) {
		t.Fatal("a dropped id is still held or taken again")
	}
}

func TestHeldIDsAreBoundedAndExpire(t *testing.T) {
	path := filepath.Join(t.TempDir(), "seen")
	now := time.Now()
	s := loadSeen(path)
	held := 0
	for i := 0; i < seenHeldKeep+50; i++ {
		id := randomID(t)
		s.claim(id)
		if s.hold(id, nostr.Timestamp(now.Unix()), now) {
			held++
		}
	}
	if held != seenHeldKeep {
		t.Fatalf("held %d, want %d", held, seenHeldKeep)
	}
	old := randomID(t)
	if s.hold(old, nostr.Timestamp(now.Add(-seenHeldFor-time.Hour).Unix()), now) {
		t.Fatal("held one the relay no longer keeps")
	}
	if n := loadSeen(path).heldCount(); n != seenHeldKeep {
		t.Fatalf("a restart holds %d", n)
	}
	// two weeks on, the relay has none of them and nothing waits
	if n := len(loadSeen(path).wanted(now.Add(seenHeldFor + time.Hour))); n != 0 {
		t.Fatalf("%d wanted past the relay's retention", n)
	}
}

func TestCompactionKeepsWhatIsHeld(t *testing.T) {
	path := filepath.Join(t.TempDir(), "seen")
	now := time.Now()
	s := loadSeen(path)
	free, still := randomID(t), randomID(t)
	for _, id := range []nostr.ID{free, still} {
		s.claim(id)
	}
	s.hold(free, nostr.Timestamp(now.Unix()), now)
	markHeldFile(path, seenFreeMark)
	s.hold(still, nostr.Timestamp(now.Unix()), now)
	// enough kept ids to rewrite the file
	for i := 0; i < seenFileMax; i++ {
		id := randomID(t)
		s.claim(id)
		s.handedOver([]nostr.ID{id})
	}
	b, _ := os.ReadFile(path)
	if n := strings.Count(string(b), "\n"); n > seenFileMax {
		t.Fatalf("not compacted: %d lines", n)
	}
	c := loadSeen(path)
	if c.heldCount() != 2 {
		t.Fatalf("compaction left %d held", c.heldCount())
	}
	if w := c.wanted(now); len(w) != 1 || w[0] != free {
		t.Fatalf("compaction lost which was let go: %v", w)
	}
	if c.claim(still) {
		t.Fatal("compaction let the held one go")
	}
}

func TestAnAckLeavesHeldPlacesOnTheRelay(t *testing.T) {
	set := pollAckReset(t)
	ids := pollAckPut(t, set, "a", "b", "c")
	nostrMu.Lock()
	for i := range nostrInboxDone {
		nostrInboxDone[i].at = nostr.Timestamp(time.Now().Unix())
	}
	nostrMu.Unlock()
	b := pollRaw(t)
	if r := nostrAck(b.K, `{"f":[2],"h":[1]}`); r != "ok" {
		t.Fatal(r)
	}
	if !set.handed(ids["a"].id) {
		t.Fatal("the kept one is not seen")
	}
	if set.handed(ids["b"].id) || set.claim(ids["b"].id) {
		t.Fatal("the held one is seen or taken again")
	}
	if got := pollRaw(t); bodies(got) != "c" {
		t.Fatalf("the next poll brought %q, want the failed one alone", bodies(got))
	}
}

// a process: a runner, polls acked by how, then gone. what was offered
func heldRun(t *testing.T, tag string, peer xid, rcv, ck string, how func(string) string) map[string]bool {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	got := map[string]bool{}
	quiet := time.Now()
	end := time.Now().Add(6 * time.Second)
	for time.Now().Before(end) && time.Since(quiet) < 1500*time.Millisecond {
		if b := pollRaw(t); b.K != "" {
			var h []int
			for i, e := range b.M {
				if e.T == tag {
					got[e.C] = true
					if how(e.C) == "hold" {
						h = append(h, i)
					}
				}
			}
			hj, _ := json.Marshal(h)
			nostrAck(b.K, fmt.Sprintf(`{"f":[],"h":%s}`, hj))
			quiet = time.Now()
		}
		time.Sleep(30 * time.Millisecond)
	}
	cancel()
	time.Sleep(200 * time.Millisecond)
	nostrMu.Lock()
	nostrInbox, nostrInboxDone = nil, nil
	clear(pollInflight)
	nostrMu.Unlock()
	forgetCatchup(ck)
	return got
}

func heldSetUp(t *testing.T) (*relayStandIn, xid, string, string, string) {
	t.Helper()
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	pollHoldReset(t)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	ck := catchupKey(relay.url(), rcv)
	forgetCatchup(ck)
	t.Cleanup(func() { forgetCatchup(ck) })
	return relay, peer, tag, rcv, ck
}

// a stranger past a full shelf sends far more than is held. the next start
// offers none of it again, and letting go brings exactly what was held
func TestAFloodLeftOnTheRelayStaysBoundedAcrossStarts(t *testing.T) {
	relay, peer, tag, rcv, ck := heldSetUp(t)
	now := time.Now()
	n := seenHeldKeep + 50
	for i := 0; i < n; i++ {
		relay.store(wrapToAt(t, peer, myXPub, fmt.Sprintf("f%d", i), now.Add(-2*time.Hour+time.Duration(i)*time.Second)))
	}
	hold := func(string) string { return "hold" }
	keep := func(string) string { return "keep" }
	if got := heldRun(t, tag, peer, rcv, ck, hold); len(got) != n {
		t.Fatalf("the first start offered %d of %d", len(got), n)
	}
	seenPath, _ := addressFiles(rcv)
	if h := loadSeen(seenPath).heldCount(); h != seenHeldKeep {
		t.Fatalf("%d held, want the bound %d", h, seenHeldKeep)
	}
	for i := 0; i < 2; i++ {
		if got := heldRun(t, tag, peer, rcv, ck, hold); len(got) != 0 {
			t.Fatalf("start %d opened %d of the flood again", i+2, len(got))
		}
	}
	if err := nostrLetHeld(tag, "free"); err != nil {
		t.Fatal(err)
	}
	if got := heldRun(t, tag, peer, rcv, ck, keep); len(got) != seenHeldKeep {
		t.Fatalf("let go and %d came back, want %d", len(got), seenHeldKeep)
	}
	if got := heldRun(t, tag, peer, rcv, ck, keep); len(got) != 0 {
		t.Fatalf("kept and %d came again", len(got))
	}
}

// the anchor moves past a held text. let go, it comes by its id
func TestAHeldTextComesBackPastTheWindow(t *testing.T) {
	relay, peer, tag, rcv, ck := heldSetUp(t)
	now := time.Now()
	relay.store(wrapToAt(t, peer, myXPub, "old", now.Add(-30*time.Hour)))
	relay.store(wrapToAt(t, peer, myXPub, "new", now.Add(-time.Minute)))
	how := func(c string) string {
		if c == "old" {
			return "hold"
		}
		return "keep"
	}
	if got := heldRun(t, tag, peer, rcv, ck, how); !got["old"] || !got["new"] {
		t.Fatalf("the first start got %v", got)
	}
	if got := heldRun(t, tag, peer, rcv, ck, how); len(got) != 0 {
		t.Fatalf("the next start offered %v", got)
	}
	if err := nostrLetHeld(tag, "free"); err != nil {
		t.Fatal(err)
	}
	if got := heldRun(t, tag, peer, rcv, ck, how); !got["old"] || got["new"] {
		t.Fatalf("let go, the start after got %v", got)
	}
}
