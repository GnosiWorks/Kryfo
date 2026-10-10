// SPDX-License-Identifier: GPL-3.0-or-later
package main

// each line says when its event reached the relay, by this clock, as far as
// the way it came tells: a stored one after what the relay was known to
// have handed over and before the subscribe, a live one as it came. a relay
// is known to have handed over everything once its catch-up ran to its end,
// and from then on with each sign of life. that is kept on disk, read back
// by the next runner on the address, and goes with the address. a held id
// keeps when it reached the relay as it first came.

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"fiatjaf.com/nostr"
)

// the done entry of the inbox line that carries body
func doneOf(t *testing.T, tag, body string) inboxDone {
	t.Helper()
	nostrMu.Lock()
	defer nostrMu.Unlock()
	for i, l := range nostrInbox {
		if l == tag+"|"+body {
			return nostrInboxDone[i]
		}
	}
	t.Fatalf("no line for %q", body)
	return inboxDone{}
}

func TestEachLineSaysWhenItReachedTheRelay(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	oldSpread := kickSpread
	kickSpread = 0
	defer func() { kickSpread = oldSpread }()
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	ck := catchupKey(relay.url(), rcv)
	forgetCatchup(ck)
	t.Cleanup(func() { forgetCatchup(ck); dropHeard(rcv) })

	relay.store(wrapTo(t, peer, myXPub, "stored"))
	began := time.Now().UnixMilli()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	waitFor(t, "the stored one", 10*time.Second, func() bool { return inboxHas(tag + "|stored") })
	// nothing was known of the relay before: any time up to the subscribe
	if d := doneOf(t, tag, "stored"); d.from != 0 || d.until < began || d.until > time.Now().UnixMilli() {
		t.Fatalf("stored: from %d until %d, want 0 and the subscribe", d.from, d.until)
	}
	waitFor(t, "the catch-up ran to its end", 10*time.Second, func() bool { return heardOf(ck) > 0 })
	if h := heardOf(ck); h < began {
		t.Fatalf("heard to %d, before the runner began at %d", h, began)
	}
	// on disk for the next runner
	b, err := os.ReadFile(heardFile(rcv))
	if err != nil || !strings.HasPrefix(string(b), relay.url()+" ") {
		t.Fatalf("the heard file holds %q (%v)", b, err)
	}

	before := time.Now().UnixMilli()
	relay.pushLive(wrapTo(t, peer, myXPub, "live"))
	waitFor(t, "the live one", 10*time.Second, func() bool { return inboxHas(tag + "|live") })
	d := doneOf(t, tag, "live")
	if d.from != d.until || d.from < before || d.until > time.Now().UnixMilli() {
		t.Fatalf("live: from %d until %d, want both when it came", d.from, d.until)
	}

	// the socket goes, and what the relay takes meanwhile comes stored on
	// the next connection, after what was heard before it
	heard := heardOf(ck)
	relay.dropAll()
	relay.store(wrapTo(t, peer, myXPub, "gap"))
	kickUntil(t, "the gap", func() bool { return inboxHas(tag + "|gap") })
	g := doneOf(t, tag, "gap")
	if g.from < heard || g.until < g.from {
		t.Fatalf("gap: from %d until %d, want from at least %d", g.from, g.until, heard)
	}

	// a runner of another process reads the file
	cancel()
	heardMu.Lock()
	delete(heardAt, ck)
	heardMu.Unlock()
	loadHeard(rcv)
	if heardOf(ck) <= 0 {
		t.Fatal("a new runner knows nothing of what was heard")
	}

	// let go of, the address takes it with it
	dropAddressFiles(rcv)
	if heardOf(ck) != 0 {
		t.Fatal("still heard after the address went")
	}
	if _, err := os.Stat(heardFile(rcv)); !os.IsNotExist(err) {
		t.Fatalf("the heard file is still there (%v)", err)
	}
	noteHeard(context.Background(), relay.url(), rcv, time.Now().Add(time.Hour))
	if _, err := os.Stat(heardFile(rcv)); !os.IsNotExist(err) {
		t.Fatal("a late note wrote the file of an address let go of")
	}
}

func TestHeardMovesOnlyForwardAndNotForARunnerLetGo(t *testing.T) {
	savedOld := savedDataDir
	savedDataDir = t.TempDir()
	defer func() { savedDataDir = savedOld }()
	rcv := strings.Repeat("ab", 32)
	t.Cleanup(func() { dropHeard(rcv) })
	k := catchupKey("wss://r", rcv)
	now := time.Now()
	noteHeard(context.Background(), "wss://r", rcv, now)
	noteHeard(context.Background(), "wss://r", rcv, now.Add(-time.Minute))
	if heardOf(k) != now.UnixMilli() {
		t.Fatalf("heard %d, want %d", heardOf(k), now.UnixMilli())
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	noteHeard(ctx, "wss://r", rcv, now.Add(time.Hour))
	if heardOf(k) != now.UnixMilli() {
		t.Fatal("a runner let go of moved it")
	}
	// a torn line is passed over
	if err := os.WriteFile(heardFile(rcv), []byte("wss://r x\nwss://s 77\ngarbage\n"), 0600); err != nil {
		t.Fatal(err)
	}
	dropHeard(rcv)
	loadHeard(rcv)
	if heardOf(k) != 0 || heardOf(catchupKey("wss://s", rcv)) != 77 {
		t.Fatal("the file read wrong")
	}
}

func TestThePollSaysWhenEachReachedTheRelay(t *testing.T) {
	set := pollAckReset(t)
	nostrMu.Lock()
	for _, d := range []inboxDone{{set: set, id: randomID(t), from: 5, until: 9}, {set: set, id: randomID(t)}} {
		set.claim(d.id)
		nostrInbox = append(nostrInbox, "x-alice|b")
		nostrInboxDone = append(nostrInboxDone, d)
	}
	nostrMu.Unlock()
	b := pollRaw(t)
	if len(b.M) != 2 || b.M[0].F != 5 || b.M[0].U != 9 || b.M[1].F != 0 || b.M[1].U != 0 {
		t.Fatalf("entries %+v", b.M)
	}
	raw, _ := json.Marshal(b.M[1])
	if strings.Contains(string(raw), `"f"`) || strings.Contains(string(raw), `"u"`) {
		t.Fatalf("an entry that knows nothing says %s", raw)
	}
}

func TestAHeldIDKeepsWhenItReachedTheRelay(t *testing.T) {
	path := filepath.Join(t.TempDir(), "seen")
	now := time.Now()
	s := loadSeen(path)
	id, old := randomID(t), randomID(t)
	for _, x := range []nostr.ID{id, old} {
		s.claim(x)
	}
	s.hold(id, nostr.Timestamp(now.Unix()), "", now, 11, 22)
	s.hold(old, nostr.Timestamp(now.Unix()), "", now, 0, 0)
	if f, u := s.heldReach(id); f != 11 || u != 22 {
		t.Fatalf("held: %d %d", f, u)
	}
	again := loadSeen(path)
	if f, u := again.heldReach(id); f != 11 || u != 22 {
		t.Fatalf("after a restart: %d %d", f, u)
	}
	if f, u := again.heldReach(old); f != 0 || u != 0 {
		t.Fatalf("one that knew nothing: %d %d", f, u)
	}
	// a line written before these were kept
	if _, h, ok := parseHeldLine(seenHeldMark + old.Hex() + " 5 grp"); !ok || h.from != 0 || h.until != 0 || h.group != "grp" {
		t.Fatalf("an old line reads %+v %v", h, ok)
	}
}
