// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the fast route's second round: the public relays while our first store is
// down, a send it missed reaching private readers, late top-ups as fresh
// wraps, nothing of it on the private route, the sealed queue file, and no
// public relay ever dialled in the clear.

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"os"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
)

// a wrap from one identity to another, stamped at, its seal kept as the
// send path keeps it
func wrapKeptAt(t *testing.T, from xid, to [32]byte, body string, at time.Time) nostr.Event {
	t.Helper()
	sndSk, sndPk, err := nip17DeriveRoleAs(from, to, nip17SndInfo, hex.EncodeToString(from.pub[:]))
	if err != nil {
		t.Fatal(err)
	}
	_, rcvPk, err := nip17DeriveRoleAs(from, to, nip17RcvInfo, hex.EncodeToString(to[:]))
	if err != nil {
		t.Fatal(err)
	}
	ck, err := nip44.GenerateConversationKey(rcvPk, sndSk)
	if err != nil {
		t.Fatal(err)
	}
	rumor := nostr2.Event{Kind: 14, CreatedAt: nostr2.Now(), PubKey: sndPk, Content: body,
		Tags: nostr2.Tags{{"p", rcvPk}}}
	exp := wrapExpiry(time.Now())
	gw, err := giftWrapKept(rumor, rcvPk,
		func(pt string) (string, error) { return nip44.Encrypt(pt, ck) },
		func(e *nostr2.Event) error { return e.Sign(sndSk) },
		func(e *nostr2.Event) {
			e.CreatedAt = nostr2.Timestamp(at.Unix())
			e.Tags = append(e.Tags, nostr2.Tag{"expiration", exp})
		})
	if err != nil {
		t.Fatal(err)
	}
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		t.Fatal(err)
	}
	return ev
}

// tor carries for the test, and the fast route's times are short
func fastTorUp(t *testing.T) {
	t.Helper()
	statusMu.RLock()
	oldStatus := torStatus
	statusMu.RUnlock()
	setStatus("bootstrapped")
	liveMu.Lock()
	oldAfter, oldSpan := fastDownAfter, fastFailSpan
	fastDownAfter, fastFailSpan = 2*time.Second, time.Second
	liveMu.Unlock()
	t.Cleanup(func() {
		setStatus(oldStatus)
		liveMu.Lock()
		fastDownAfter, fastFailSpan = oldAfter, oldSpan
		liveMu.Unlock()
	})
}

// two stores and a public backup reached through the socks stand-in
func useTwoStoresAndBackup(t *testing.T) (a, b, p *relayStandIn, socks *socksStandIn) {
	t.Helper()
	a, b, p = newRelayStandIn(t, 0), newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	socks = newSocksStandIn(t)
	useStandIns(t, modeBalanced, socks, a, b)
	old, oldSpread := secondRelayHost, secondFirstSpread
	secondRelayHost = strings.TrimPrefix(b.url(), "ws://")
	secondFirstSpread = 0
	t.Cleanup(func() { secondRelayHost, secondFirstSpread = old, oldSpread })
	freshInbox(t)
	setBackups([]string{p.url()})
	p.mu.Lock()
	p.keep = true
	p.mu.Unlock()
	return a, b, p, socks
}

// every connection the relay saw came through tor's socks port
func allThroughSocks(t *testing.T, r *relayStandIn, socks *socksStandIn) {
	t.Helper()
	for _, c := range r.snapshot() {
		if _, ok := socks.nameOf(c.remote); !ok {
			t.Fatalf("a public relay was reached in the clear from %s", c.remote)
		}
	}
}

func acceptedOf(r *relayStandIn) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.accepted
}

func gotID(r *relayStandIn, id nostr.ID) bool {
	for _, c := range r.snapshot() {
		for _, e := range c.got {
			if e.ID == id {
				return true
			}
		}
	}
	return false
}

// while the first store is down the backups are read and written through
// tor, the second store answering or not, and let go once the first is back
func TestPublicRelaysWhileOurFirstIsDown(t *testing.T) {
	a, b, p, socks := useTwoStoresAndBackup(t)
	fastTorUp(t)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	waitFor(t, "both of ours listen", 10*time.Second, func() bool {
		return len(a.snapshot()) > 0 && len(b.snapshot()) > 0
	})
	if ok := nostrPublishMulti(context.Background(), laneEveryday, wrapToAt(t, peer, myXPub, "one", time.Now())); ok < 1 {
		t.Fatal("not sent")
	}
	time.Sleep(3 * time.Second)
	if n := len(p.snapshot()); n != 0 {
		t.Fatalf("with both of ours up the public relay saw %d sockets", n)
	}

	// the first goes, the second carries on and keeps answering
	standInDown(a, true)
	busy, stopBusy := context.WithCancel(context.Background())
	defer stopBusy()
	go func() {
		for i := 0; busy.Err() == nil; i++ {
			b.pushLive(wrapToAt(t, peer, myXPub, "b "+strconv.Itoa(i), time.Now()))
			time.Sleep(300 * time.Millisecond)
		}
	}()
	p.store(wrapToAt(t, peer, myXPub, "a private contact wrote", time.Now().Add(-time.Minute)))
	waitFor(t, "the backup read", 30*time.Second, func() bool { return inboxHas(tag + "|a private contact wrote") })
	if ownRelayDown() {
		t.Fatal("ours counted as down while the second store answered")
	}
	if ok := nostrPublishMulti(context.Background(), laneEveryday, wrapToAt(t, peer, myXPub, "two", time.Now())); ok < 1 {
		t.Fatal("not sent while the first is down")
	}
	waitFor(t, "the public relay took the send", 10*time.Second, func() bool { return acceptedOf(p) >= 1 })
	allThroughSocks(t, p, socks)
	stopBusy()

	// the first is back: every socket on the backup goes, the kept publish
	// socket too, long before its idle time
	standInDown(a, false)
	kickRelays()
	waitFor(t, "the backup let go", 20*time.Second, func() bool {
		for _, c := range p.snapshot() {
			if c.closed.IsZero() {
				return false
			}
		}
		return !firstStoreDown()
	})
}

// a send the first store missed, with tor up, also reaches the public
// relays through tor at once: private readers and versions before the
// second store read only the first store and those
func TestASendOurFirstMissedGoesToThePublicRelays(t *testing.T) {
	a, _, p, socks := useTwoStoresAndBackup(t)
	fastTorUp(t)
	standInDown(a, true)
	peer := newXid(t)
	ev := wrapToAt(t, peer, myXPub, "missed by the first", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
		t.Fatal("not sent")
	}
	waitFor(t, "the public copy", 15*time.Second, func() bool { return gotID(p, ev.ID) })
	allThroughSocks(t, p, socks)
	// a send the first store took goes nowhere else
	standInDown(a, false)
	ev2 := wrapToAt(t, peer, myXPub, "taken by the first", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev2); ok < 1 {
		t.Fatal("not sent")
	}
	waitFor(t, "the first took it", 10*time.Second, func() bool { return gotID(a, ev2.ID) })
	time.Sleep(time.Second)
	if gotID(p, ev2.ID) {
		t.Fatal("a send the first store took went to a public relay")
	}
}

// the first store is down six hours. a send it missed, stamped back as
// every wrap is, waits; when the store is back the queue sends a fresh wrap
// around the same seal, and a reader of that store alone whose window moved
// on with the hours reads it there
func TestALateTopUpIsAFreshWrap(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	a.mu.Lock()
	a.keep = true
	a.mu.Unlock()
	standInDown(a, true)
	sender, reader := newXid(t), newXid(t)
	mu.Lock()
	myXPriv, myXPub = sender.priv, sender.pub
	mu.Unlock()
	now := time.Now()
	// sent six hours ago, stamped up to ten hours before that
	ev := wrapKeptAt(t, sender, reader.pub, "sent while the first was down", now.Add(-15*time.Hour))
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
		t.Fatal("not sent")
	}
	waitFor(t, "it waits for the first store", 10*time.Second, func() bool { return len(topupFor(storeFirst)) == 1 })
	topupMu.Lock()
	topupQueue[0].At = now.Add(-6 * time.Hour).Unix()
	topupMu.Unlock()

	standInDown(a, false)
	relayOK(a.url())
	var fresh nostr.Event
	waitFor(t, "the first store took a wrap", 10*time.Second, func() bool {
		for _, c := range a.snapshot() {
			if len(c.got) > 0 {
				fresh = c.got[0]
				return true
			}
		}
		return false
	})
	if fresh.ID == ev.ID {
		t.Fatal("six hours late, the old wrap went as it was")
	}
	if fresh.CreatedAt < nostr.Timestamp(now.Add(-10*time.Hour-time.Minute).Unix()) {
		t.Fatalf("the fresh wrap is stamped %s back", now.Sub(time.Unix(int64(fresh.CreatedAt), 0)))
	}

	// the reader: a version that reads the first store alone, its anchor
	// moved up to now by the hours of traffic since
	cancelReader := readFirstStoreAs(t, reader, sender, a, now.Add(-time.Minute))
	defer cancelReader()
	tag := hex.EncodeToString(sender.pub[:])
	waitFor(t, "the reader has it", 10*time.Second, func() bool { return inboxHas(tag + "|sent while the first was down") })
}

// runs a reader of store a alone as identity me, listening for from, its
// anchor at anchor
func readFirstStoreAs(t *testing.T, me, from xid, a *relayStandIn, anchor time.Time) func() {
	t.Helper()
	transportMode.Store(modeFast)
	setBackups(nil)
	// the sender's own ids, which a reader in the same process would skip
	nostrMu.Lock()
	nostrSentIDs = map[string]bool{}
	nostrMu.Unlock()
	setRelays([]string{a.url()})
	mu.Lock()
	myXPriv, myXPub = me.priv, me.pub
	mu.Unlock()
	rcv := mustRcv(t, from)
	if err := os.WriteFile(anchorFile(rcv, storeFirst), []byte(strconv.FormatInt(anchor.Unix(), 10)), 0600); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	go nostrSubscribeRunner(ctx, hex.EncodeToString(from.pub[:]), from.pub, rcv)
	return cancel
}

// private stays as it was: a send our relay missed queues nothing, and a
// switch to fast afterwards sends it nowhere
func TestPrivateQueuesNothingForASwitchToFast(t *testing.T) {
	a, p := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	b := newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, a, p)
	statusMu.RLock()
	oldStatus := torStatus
	statusMu.RUnlock()
	setStatus("bootstrapped")
	t.Cleanup(func() { setStatus(oldStatus) })
	standInDown(a, true)
	peer := newXid(t)
	evs := []nostr.Event{
		wrapToAt(t, peer, myXPub, "one", time.Now()),
		wrapToAt(t, peer, myXPub, "two", time.Now()),
	}
	for _, ev := range evs {
		if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
			t.Fatal("not sent on private")
		}
	}
	time.Sleep(time.Second)
	if n := len(topupFor(storeFirst)); n != 0 {
		t.Fatalf("private queued %d wraps", n)
	}
	// to fast, the first store back
	old := secondRelayHost
	secondRelayHost = strings.TrimPrefix(b.url(), "ws://")
	t.Cleanup(func() { secondRelayHost = old })
	switchMode(modeBalanced)
	setRelays([]string{a.url(), b.url()})
	standInDown(a, false)
	relayOK(a.url())
	time.Sleep(2 * time.Second)
	for _, ev := range evs {
		if gotID(a, ev.ID) {
			t.Fatal("a send made on private was flushed after the switch")
		}
	}
}

// the queue's file holds nothing readable, comes back after a restart, and
// keeps to the wrap's own expiration, the caps, and what is still wanted
func TestTheTopUpFileIsSealed(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	old := topupMaxItems
	topupMaxItems = 3
	t.Cleanup(func() { topupMaxItems = old })
	peer, other := newXid(t), newXid(t)
	var evs []nostr.Event
	for i := 0; i < 5; i++ {
		ev := wrapKeptAt(t, mustXid(), peer.pub, "w"+strconv.Itoa(i), time.Now())
		evs = append(evs, ev)
		topupAdd(storeFirst, laneEveryday, ev)
	}
	// a pair code's never waits
	topupAdd(storeFirst, pairLane("abc"), wrapToAt(t, peer, myXPub, "code", time.Now()))
	// one that expires before fourteen days is out when it does
	short := wrapToAt(t, peer, myXPub, "short", time.Now())
	short.Tags = append(short.Tags, nostr.Tag{"expiration", strconv.FormatInt(time.Now().Add(-time.Second).Unix(), 10)})
	topupAdd(storeFirst, laneEveryday, short)
	got := topupFor(storeFirst)
	if len(got) != 3 || got[0].Ev.ID != evs[2].ID {
		t.Fatalf("%d waiting, want the newest 3", len(got))
	}
	topupSync()
	raw, err := os.ReadFile(topupFile())
	if err != nil {
		t.Fatal(err)
	}
	for _, ev := range evs {
		if strings.Contains(string(raw), ev.ID.Hex()) || strings.Contains(string(raw), ev.Content[:20]) {
			t.Fatal("the file holds a wrap in the clear")
		}
	}
	if strings.Contains(string(raw), `"kind"`) || strings.Contains(string(raw), wrapAddr(evs[0])) {
		t.Fatal("the file holds a wrap's fields in the clear")
	}
	// nor once a line's encoding is undone
	for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
		plain, _ := base64.RawStdEncoding.DecodeString(line)
		if strings.Contains(string(plain), wrapAddr(evs[0])) || strings.Contains(string(plain), evs[0].ID.Hex()) {
			t.Fatal("a line of the file is only encoded, not sealed")
		}
	}
	topupForget()
	if again := topupFor(storeFirst); len(again) != 3 || again[0].Ev.ID != evs[2].ID || again[0].Kept == nil {
		t.Fatalf("after a restart %d waiting", len(again))
	}
	// a contact deleted takes what waits for them, a room ended its lane's
	room := roomLane("feed")
	topupAdd(storeFirst, room, wrapKeptAt(t, mustXid(), other.pub, "room", time.Now()))
	topupPurgeAddr(wrapAddr(evs[2]))
	topupPurgeLane(room)
	if n := len(topupFor(storeFirst)); n != 0 {
		t.Fatalf("%d left after the contact and the room went", n)
	}
	topupSync()
	topupForget()
	if n := len(topupFor(storeFirst)); n != 0 {
		t.Fatalf("%d came back after a restart", n)
	}
	// the wrong key opens nothing
	topupAdd(storeFirst, laneEveryday, wrapKeptAt(t, mustXid(), peer.pub, "x", time.Now()))
	topupSync()
	topupForget()
	mu.Lock()
	myXPriv, myXPub = other.priv, other.pub
	mu.Unlock()
	if n := len(topupFor(storeFirst)); n != 0 {
		t.Fatal("another identity read the queue")
	}
}

func mustXid() xid {
	me, _ := myXid()
	return me
}

// a store's no ends a wrap, a slow down keeps it, and a wrap that keeps
// failing is given up on
func TestATopUpGivesUpOnANo(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	oldRetry := topupRetry
	topupRetry = 0
	t.Cleanup(func() { topupRetry = oldRetry })
	peer := newXid(t)
	ev := wrapKeptAt(t, mustXid(), peer.pub, "x", time.Now())
	for _, c := range []struct {
		refuse string
		kept   bool
	}{
		{"rate-limited: slow down", true},
		{"error: the relay is full, try later", false},
		{"blocked: no", false},
	} {
		topupAdd(storeFirst, laneEveryday, ev)
		a.mu.Lock()
		a.refuse = c.refuse
		a.mu.Unlock()
		topupFlush(storeFirst, a.url())
		if kept := len(topupFor(storeFirst)) == 1; kept != c.kept {
			t.Fatalf("%q: kept %v, want %v", c.refuse, kept, c.kept)
		}
	}
	// a wrap that keeps meeting a slow down is let go after its tries
	topupAdd(storeFirst, laneEveryday, ev)
	a.mu.Lock()
	a.refuse = "rate-limited: slow down"
	a.mu.Unlock()
	for i := 0; i < topupMaxTries+1 && len(topupFor(storeFirst)) > 0; i++ {
		topupFlush(storeFirst, a.url())
	}
	if n := len(topupFor(storeFirst)); n != 0 {
		t.Fatalf("still waiting after %d tries", topupMaxTries)
	}
}

// an answer from a relay is never held up by the queue's file
func TestAnAnswerNeverWaitsOnTheQueue(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	topupAdd(storeFirst, laneEveryday, wrapKeptAt(t, mustXid(), newXid(t).pub, "x", time.Now()))
	topupForget()
	topupFileMu.Lock()
	done := make(chan struct{})
	go func() {
		relayOK(a.url())
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(time.Second):
		topupFileMu.Unlock()
		t.Fatal("an answer waited on the queue's file")
	}
	topupFileMu.Unlock()
}

// on fast a relay in the list that is not ours is reached through tor only
func TestAPublicRelayInTheListIsNeverDialledDirectly(t *testing.T) {
	a, b, p := newRelayStandIn(t, 0), newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modeBalanced, socks, a, b, p)
	old := secondRelayHost
	secondRelayHost = strings.TrimPrefix(b.url(), "ws://")
	t.Cleanup(func() { secondRelayHost = old })
	freshInbox(t)
	statusMu.RLock()
	oldStatus := torStatus
	statusMu.RUnlock()
	setStatus("bootstrapped")
	t.Cleanup(func() { setStatus(oldStatus) })
	peer := newXid(t)
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, mustRcv(t, peer))
	if ok := nostrPublishMulti(context.Background(), laneEveryday, wrapToAt(t, peer, myXPub, "x", time.Now())); ok < 1 {
		t.Fatal("not sent")
	}
	waitFor(t, "the public relay was reached", 15*time.Second, func() bool { return len(p.snapshot()) > 0 })
	allThroughSocks(t, p, socks)
	for _, r := range []*relayStandIn{a, b} {
		for _, c := range r.snapshot() {
			if _, ok := socks.nameOf(c.remote); ok {
				t.Fatal("one of ours went through tor on fast")
			}
		}
	}
}

// a backup waiting for tor dials as soon as tor carries, not at its next
// look minutes later
func TestABackupDialsWhenTorComesUp(t *testing.T) {
	a, _, p, socks := useTwoStoresAndBackup(t)
	standInDown(a, true)
	statusMu.RLock()
	oldStatus := torStatus
	statusMu.RUnlock()
	setStatus("starting")
	t.Cleanup(func() { setStatus(oldStatus) })
	liveMu.Lock()
	firstDown = true
	liveMu.Unlock()
	peer := newXid(t)
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, mustRcv(t, peer))
	time.Sleep(time.Second)
	if len(p.snapshot()) != 0 {
		t.Fatal("a backup dialled before tor carried")
	}
	setStatus("bootstrapped")
	waitFor(t, "the backup dialled", 5*time.Second, func() bool { return len(p.snapshot()) > 0 })
	allThroughSocks(t, p, socks)
}

// woken because none of ours answers, our runners redial spread out, not in
// one instant
func TestOursGoneSpreadsTheRedials(t *testing.T) {
	old := goneSpread
	goneSpread = time.Second
	t.Cleanup(func() { goneSpread = old })
	var mu sync.Mutex
	var at []time.Duration
	start := time.Now()
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			napFor(context.Background(), time.Minute, true)
			mu.Lock()
			at = append(at, time.Since(start))
			mu.Unlock()
		}()
	}
	time.Sleep(100 * time.Millisecond)
	oursGoneWake()
	wg.Wait()
	lo, hi := at[0], at[0]
	for _, d := range at {
		lo, hi = min(lo, d), max(hi, d)
	}
	if hi > 2*time.Second {
		t.Fatalf("a runner woke %s after the wake", hi)
	}
	if hi-lo < 300*time.Millisecond {
		t.Fatalf("twenty runners redialled within %s of each other", hi-lo)
	}
}

// private with both onions: store 1, store 2, the public relays, all through
// tor, each lane on its own circuits. a reader keeps receiving while store
// 1's onion is down, a send reaches both onions and the public relays, and
// nothing is dialled in the clear
func TestPrivateReadsAndWritesBothOnions(t *testing.T) {
	a, b, p := newRelayStandIn(t, 0), newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, a, b, p)
	old, oldSpread := secondRelayHost, secondFirstSpread
	secondRelayHost = strings.TrimPrefix(b.url(), "ws://")
	secondFirstSpread = 0
	t.Cleanup(func() { secondRelayHost, secondFirstSpread = old, oldSpread })
	freshInbox(t)
	statusMu.RLock()
	oldStatus := torStatus
	statusMu.RUnlock()
	setStatus("bootstrapped")
	t.Cleanup(func() { setStatus(oldStatus) })
	urls := []string{a.url(), b.url(), p.url()}
	if storeOf(urls, a.url()) != storeFirst || storeOf(urls, b.url()) != storeSecond || !storeLead(urls, b.url()) {
		t.Fatal("the two onions are not two stores")
	}

	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	waitFor(t, "all three listen", 15*time.Second, func() bool {
		return len(a.snapshot()) > 0 && len(b.snapshot()) > 0 && len(p.snapshot()) > 0
	})
	// the second store's first walk starts at the day it went live
	if s := b.snapshot()[0].reqs[0].filter.Since; int64(s) != secondLiveAt-12*3600 {
		t.Fatalf("the second onion's first walk asked from %d", s)
	}

	// a send reaches both onions and the public relay, and queues nothing
	ev := wrapToAt(t, peer, myXPub, "to everyone", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
		t.Fatal("not sent")
	}
	waitFor(t, "every relay took it", 15*time.Second, func() bool {
		return gotID(a, ev.ID) && gotID(b, ev.ID) && gotID(p, ev.ID)
	})

	// store 1's onion goes: the reader keeps receiving through the second
	standInDown(a, true)
	b.pushLive(wrapToAt(t, peer, myXPub, "through the second onion", time.Now()))
	waitFor(t, "the second onion carried", 15*time.Second, func() bool {
		return inboxHas(tag + "|through the second onion")
	})
	// a send while it is down still goes out, and nothing waits for later
	ev2 := wrapToAt(t, peer, myXPub, "while the first is down", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev2); ok < 1 {
		t.Fatal("not sent while the first onion is down")
	}
	waitFor(t, "the second onion took it", 15*time.Second, func() bool { return gotID(b, ev2.ID) })
	time.Sleep(time.Second)
	if n := len(topupFor(storeFirst)); n != 0 {
		t.Fatalf("private queued %d wraps", n)
	}
	for _, r := range []*relayStandIn{a, b, p} {
		allThroughSocks(t, r, socks)
	}
}
