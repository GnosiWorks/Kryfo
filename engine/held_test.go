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
	if !s.hold(id, nostr.Timestamp(now.Unix()), "", now) {
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
	s.hold(id, nostr.Timestamp(now.Unix()), "", now)
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
		if s.hold(id, nostr.Timestamp(now.Unix()), "", now) {
			held++
		}
	}
	if held != seenHeldKeep {
		t.Fatalf("held %d, want %d", held, seenHeldKeep)
	}
	old := randomID(t)
	if s.hold(old, nostr.Timestamp(now.Add(-seenHeldFor-time.Hour).Unix()), "", now) {
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
	s.hold(free, nostr.Timestamp(now.Unix()), "", now)
	markHeldFile(path, seenFreeMark)
	s.hold(still, nostr.Timestamp(now.Unix()), "", now)
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
			h, g := []int{}, []string{}
			for i, e := range b.M {
				if e.T == tag {
					got[e.C] = true
					// "hold", or "hold:group" for one held in a group
					if w, group, _ := strings.Cut(how(e.C), ":"); w == "hold" {
						h = append(h, i)
						g = append(g, group)
					}
				}
			}
			hj, _ := json.Marshal(h)
			gj, _ := json.Marshal(g)
			nostrAck(b.K, fmt.Sprintf(`{"f":[],"h":%s,"g":%s}`, hj, gj))
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

func TestAFileIsOneGroupOfHeldIDs(t *testing.T) {
	path := filepath.Join(t.TempDir(), "seen")
	now := time.Now()
	stamp := nostr.Timestamp(now.Unix())
	s := loadSeen(path)
	hold := func(group string) bool {
		id := randomID(t)
		s.claim(id)
		return s.hold(id, stamp, group, now)
	}
	// a file already held takes its slices with no group to spare
	if !hold("file-a") {
		t.Fatal("the first slice")
	}
	for i := 1; i < seenHeldKeep; i++ {
		if !hold("") {
			t.Fatalf("text %d", i)
		}
	}
	if hold("") || hold("file-b") {
		t.Fatal("a new group past the bound was held")
	}
	n := 1
	for hold("file-a") {
		n++
	}
	if n != seenHeldPerGroup {
		t.Fatalf("the file held %d slices, want %d", n, seenHeldPerGroup)
	}
	if c := loadSeen(path).heldCount(); c != seenHeldKeep-1+seenHeldPerGroup {
		t.Fatalf("a restart holds %d", c)
	}
}

func TestHeldIDsHaveAHardMost(t *testing.T) {
	now := time.Now()
	s := loadSeen("")
	held := 0
	for f := 0; f < 10; f++ {
		for i := 0; i < seenHeldPerGroup; i++ {
			id := randomID(t)
			s.claim(id)
			if s.hold(id, nostr.Timestamp(now.Unix()), fmt.Sprintf("file-%d", f), now) {
				held++
			}
		}
	}
	if held != seenHeldMost {
		t.Fatalf("held %d ids, want %d", held, seenHeldMost)
	}
}

// let go of after the poll handed it over: a hold from that batch would
// pass the mark and wait two weeks. it goes to the app again instead
func TestAHoldPastAFreeComesAgain(t *testing.T) {
	pollAckReset(t)
	set := loadSeen(filepath.Join(t.TempDir(), "seen"))
	ids := pollAckPut(t, set, "a")
	nostrMu.Lock()
	nostrInboxDone[0].at = nostr.Timestamp(time.Now().Unix())
	nostrMu.Unlock()
	b := pollRaw(t)
	markHeldFile(set.path, seenFreeMark)
	if r := nostrAck(b.K, `{"f":[],"h":[0],"g":[""]}`); r != "ok" {
		t.Fatal(r)
	}
	if set.heldCount() != 0 {
		t.Fatal("held past the mark")
	}
	if got := pollRaw(t); bodies(got) != "a" {
		t.Fatalf("not offered again: %q", bodies(got))
	}
	nostrAck(pollRaw(t).K, "")
	_ = ids
}

func TestFreeAndMarkLeaveAnAddressWithNothingHeldAlone(t *testing.T) {
	_, peer, tag, rcv, _ := heldSetUp(t)
	_ = peer
	seenPath, _ := addressFiles(rcv)
	loadSeen(seenPath).handedOver([]nostr.ID{randomID(t)})
	before, _ := os.ReadFile(seenPath)
	for _, how := range []string{"mark", "free"} {
		if err := nostrLetHeld(tag, how); err != nil {
			t.Fatal(err)
		}
	}
	after, _ := os.ReadFile(seenPath)
	if string(before) != string(after) {
		t.Fatalf("nothing held and the file changed: %q", after)
	}
	// with one held, a mark alone lets it go for the next start
	s := loadSeen(seenPath)
	id := randomID(t)
	s.claim(id)
	s.hold(id, nostr.Timestamp(time.Now().Unix()), "", time.Now())
	if err := nostrLetHeld(tag, "mark"); err != nil {
		t.Fatal(err)
	}
	if w := loadSeen(seenPath).wanted(time.Now()); len(w) != 1 || w[0] != id {
		t.Fatalf("marked and not wanted: %v", w)
	}
}

// a file of more slices than there are groups, then a text, both past the
// shelf: let go, all of it comes
func TestABigFileAndATextHeldBothComeBack(t *testing.T) {
	relay, peer, tag, rcv, ck := heldSetUp(t)
	now := time.Now()
	n := 300
	for i := 0; i < n; i++ {
		relay.store(wrapToAt(t, peer, myXPub, fmt.Sprintf("s%d", i), now.Add(-2*time.Hour+time.Duration(i)*time.Second)))
	}
	relay.store(wrapToAt(t, peer, myXPub, "text", now.Add(-time.Hour)))
	hold := func(c string) string {
		if strings.HasPrefix(c, "s") {
			return "hold:file-1"
		}
		return "hold"
	}
	keep := func(string) string { return "keep" }
	if got := heldRun(t, tag, peer, rcv, ck, hold); len(got) != n+1 {
		t.Fatalf("the first start offered %d", len(got))
	}
	if err := nostrLetHeld(tag, "free"); err != nil {
		t.Fatal(err)
	}
	got := heldRun(t, tag, peer, rcv, ck, keep)
	if len(got) != n+1 || !got["text"] || !got["s299"] {
		t.Fatalf("let go and %d came back", len(got))
	}
}

// a freed id the relay no longer has is asked for once
func TestAFreedIDTheRelayLostIsForgotten(t *testing.T) {
	relay, peer, tag, rcv, ck := heldSetUp(t)
	now := time.Now()
	gone := wrapToAt(t, peer, myXPub, "gone", now.Add(-30*time.Hour))
	relay.store(gone, wrapToAt(t, peer, myXPub, "kept", now.Add(-29*time.Hour)),
		wrapToAt(t, peer, myXPub, "new", now.Add(-time.Minute)))
	how := func(c string) string {
		if c == "new" {
			return "keep"
		}
		return "hold"
	}
	heldRun(t, tag, peer, rcv, ck, how)
	relay.mu.Lock()
	var left []nostr.Event
	for _, ev := range relay.events {
		if ev.ID != gone.ID {
			left = append(left, ev)
		}
	}
	relay.events = left
	relay.mu.Unlock()
	if err := nostrLetHeld(tag, "free"); err != nil {
		t.Fatal(err)
	}
	if got := heldRun(t, tag, peer, rcv, ck, how); !got["kept"] || len(got) != 1 {
		t.Fatalf("let go, got %v", got)
	}
	seenPath, _ := addressFiles(rcv)
	// one answer without it is not enough
	if w := loadSeen(seenPath).wanted(time.Now()); len(w) != 1 {
		t.Fatalf("%d asked for after one answer, want 1", len(w))
	}
	heldRun(t, tag, peer, rcv, ck, how)
	if w := loadSeen(seenPath).wanted(time.Now()); len(w) != 0 {
		t.Fatalf("%d still asked for", len(w))
	}
}

// two relays, the held text on one of them only: the one without it answers
// first, and the text still comes
func TestAFreedIDOneRelayLacksStillComes(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, a, b)
	pollHoldReset(t)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	cks := []string{catchupKey(a.url(), rcv), catchupKey(b.url(), rcv)}
	forget := func() {
		for _, ck := range cks {
			forgetCatchup(ck)
		}
	}
	forget()
	t.Cleanup(forget)
	now := time.Now()
	x := wrapToAt(t, peer, myXPub, "x", now.Add(-30*time.Hour))
	n := wrapToAt(t, peer, myXPub, "new", now.Add(-time.Minute))
	a.store(x, n)
	b.store(x, n)
	how := func(c string) string {
		if c == "x" {
			return "hold"
		}
		return "keep"
	}
	if got := heldRun(t, tag, peer, rcv, cks[1], how); !got["x"] {
		t.Fatalf("the first start got %v", got)
	}
	forget()
	a.mu.Lock()
	a.events = []nostr.Event{n}
	a.mu.Unlock()
	b.mu.Lock()
	b.reqDelay = 300 * time.Millisecond
	b.mu.Unlock()
	if err := nostrLetHeld(tag, "free"); err != nil {
		t.Fatal(err)
	}
	keep := func(string) string { return "keep" }
	if got := heldRun(t, tag, peer, rcv, cks[1], keep); !got["x"] {
		t.Fatalf("let go, the relay that has it was not heard: %v", got)
	}
}

// a relay that brings fewer than a filter asks for: the rest is asked again
func TestACappedRelayBringsEveryFreedID(t *testing.T) {
	relay, peer, tag, rcv, ck := heldSetUp(t)
	now := time.Now()
	n := 150
	for i := 0; i < n; i++ {
		relay.store(wrapToAt(t, peer, myXPub, fmt.Sprintf("f%d", i), now.Add(-30*time.Hour+time.Duration(i)*time.Second)))
	}
	relay.store(wrapToAt(t, peer, myXPub, "new", now.Add(-time.Minute)))
	how := func(c string) string {
		if c == "new" {
			return "keep"
		}
		return "hold"
	}
	if got := heldRun(t, tag, peer, rcv, ck, how); len(got) != n+1 {
		t.Fatalf("the first start offered %d", len(got))
	}
	relay.mu.Lock()
	relay.capAt = 40
	relay.mu.Unlock()
	if err := nostrLetHeld(tag, "free"); err != nil {
		t.Fatal(err)
	}
	keep := func(string) string { return "keep" }
	if got := heldRun(t, tag, peer, rcv, ck, keep); len(got) != n {
		t.Fatalf("let go, %d of %d came", len(got), n)
	}
}

// a start or an unlock marks the addresses that hold something, its own
// files alone: no runner and no first-contact lane starts again
func TestAStartMarkRestartsNothing(t *testing.T) {
	heldSetUp(t)
	now := time.Now()
	holdOn := func(path string) {
		s := loadSeen(path)
		id := randomID(t)
		s.claim(id)
		if !s.hold(id, nostr.Timestamp(now.Unix()), "", now) {
			t.Fatal("not held")
		}
	}
	var peers []string
	var paths []string
	for i := 0; i < 5; i++ {
		p := newXid(t)
		peers = append(peers, hex.EncodeToString(p.pub[:]))
		path, _ := addressFiles(mustRcv(t, p))
		paths = append(paths, path)
	}
	holdOn(paths[0])
	loadSeen(paths[1]).handedOver([]nostr.ID{randomID(t)})
	const fc = 7
	_, fcPk, err := nip17FirstContactKeys(fc)
	if err != nil {
		t.Fatal(err)
	}
	fcPath, _ := addressFiles(fcPk)
	holdOn(fcPath)
	restarts := 0
	nostrMu.Lock()
	for _, p := range append([]string{"firstcontact"}, peers...) {
		nostrSubs[p] = func() { restarts++ }
	}
	fcCounterNow = fc
	nostrMu.Unlock()
	t.Cleanup(func() {
		nostrMu.Lock()
		for _, p := range append([]string{"firstcontact"}, peers...) {
			delete(nostrSubs, p)
		}
		nostrMu.Unlock()
	})
	fcBefore, _ := os.ReadFile(fcPath)
	quietBefore, _ := os.ReadFile(paths[1])
	nostrMarkHeld(peers)
	if restarts != 0 {
		t.Fatalf("%d restarts", restarts)
	}
	if b, _ := os.ReadFile(fcPath); string(b) != string(fcBefore) {
		t.Fatal("the first-contact lane was touched")
	}
	if b, _ := os.ReadFile(paths[1]); string(b) != string(quietBefore) {
		t.Fatal("an address with nothing held was marked")
	}
	if w := loadSeen(paths[0]).wanted(now); len(w) != 1 {
		t.Fatalf("the held one was not let go: %v", w)
	}
}
