// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the fast route: our two stores read and written together, the quicker one
// answering first, a second anchor for the second store, the public relays
// only while neither of ours answers, and the top-up of a wrap one store
// missed.

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// two stores, a and b, b on the second store's name
func useTwoStores(t *testing.T, a, b *relayStandIn, more ...*relayStandIn) {
	t.Helper()
	useStandIns(t, modeBalanced, nil, append([]*relayStandIn{a, b}, more...)...)
	old, oldSpread := secondRelayHost.get(), secondFirstSpread
	secondRelayHost.put(strings.TrimPrefix(b.url(), "ws://"))
	secondFirstSpread = 0
	t.Cleanup(func() {
		secondRelayHost.put(old)
		secondFirstSpread = oldSpread
	})
	freshInbox(t)
}

func standInDown(r *relayStandIn, down bool) {
	r.mu.Lock()
	r.down = down
	r.mu.Unlock()
	if down {
		r.dropAll()
	}
}

// the anchor file of store st for rcv
func anchorFile(rcv, st string) string {
	_, last := addressFiles(rcv)
	return storeLastPath(last, st)
}

func readAnchor(t *testing.T, path string) int64 {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		return -1
	}
	v, _ := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64)
	return v
}

func TestTheFastRouteIsOneRoute(t *testing.T) {
	old := currentMode()
	t.Cleanup(func() { transportMode.Store(old) })
	transportMode.Store(modePrivate)
	if got := setTransportMode(modeFast); got != modeBalanced {
		t.Fatalf("the old fast mode routes as %q, want balanced", got)
	}
	if got := setTransportMode(modeBalanced); got != modeBalanced {
		t.Fatalf("balanced routes as %q", got)
	}
	setTransportMode(modePrivate)

	nostrMu.Lock()
	oldRelays, oldBackups := nostrRelays, nostrBackups
	nostrMu.Unlock()
	t.Cleanup(func() {
		setRelays(oldRelays)
		setBackups(oldBackups)
	})
	if r := nostrInit("wss://relay.kryfo.app, wss://relay2.kryfo.app|wss://nos.lol,wss://nostr.mom"); r != "ok" {
		t.Fatal(r)
	}
	nostrMu.Lock()
	relays, backups := strings.Join(nostrRelays, " "), strings.Join(nostrBackups, " ")
	nostrMu.Unlock()
	if relays != "wss://relay.kryfo.app wss://relay2.kryfo.app" || backups != "wss://nos.lol wss://nostr.mom" {
		t.Fatalf("relays %q, backups %q", relays, backups)
	}
	urls := []string{"wss://relay.kryfo.app", "wss://relay2.kryfo.app"}
	if storeOf(urls, urls[0]) != storeFirst || storeOf(urls, urls[1]) != storeSecond || !storeLead(urls, urls[1]) {
		t.Fatal("the two names are not two stores, each its own lead")
	}
	// private mode: our onion and its clearnet name are one store
	onion := []string{"ws://" + ownOnionHost, "wss://relay.kryfo.app", "wss://nos.lol"}
	if storeOf(onion, onion[0]) != storeFirst || storeOf(onion, onion[1]) != storeFirst ||
		storeLead(onion, onion[1]) || storeOf(onion, onion[2]) != "" {
		t.Fatal("private mode's entries are not where they were")
	}
	// ours by name alone: a public relay put first is still not ours
	first := []string{"wss://nos.lol", "wss://relay.kryfo.app"}
	if storeOf(first, first[0]) != "" {
		t.Fatal("the first entry of a list counts as ours whatever its name")
	}
	if storeOf(onion, "ws://"+secondOnionHost) != storeSecond {
		t.Fatal("the second store's onion is not the second store")
	}
	// a list with no backups clears the last one's
	if r := nostrInit("wss://relay.kryfo.app"); r != "ok" || len(backupsNow()) != 0 {
		t.Fatalf("%s, backups %v", r, backupsNow())
	}
}

// the second store was benched while the first one carried. the first goes
// down: the second is dialled again at once, not after the long wait it was
// given, and what it holds comes through
func TestFastFailsOverWithoutAGap(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	oldBurst := relayFailBurst
	relayFailBurst = 0
	t.Cleanup(func() { relayFailBurst = oldBurst })
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)

	// b has been failing for a while, with a answering meanwhile
	standInDown(b, true)
	relayOK(a.url())
	for i := 0; i < 7; i++ {
		relayFailed(b.url(), time.Now())
	}
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, tag, mainPair(peer.pub), rcv)
	waitFor(t, "a carries", 10*time.Second, func() bool {
		c := a.snapshot()
		return len(c) > 0 && len(c[0].reqs) > 0
	})
	waitFor(t, "b failed once more", 10*time.Second, func() bool {
		relayHealthMu.Lock()
		defer relayHealthMu.Unlock()
		return relayFails[b.url()] >= 8
	})
	relayHealthMu.Lock()
	long := time.Until(relayCoolTill[b.url()])
	relayHealthMu.Unlock()
	if long < 30*time.Second || long > otherStoreCeiling+time.Second {
		t.Fatalf("with a answering b waits %s, want the other store's ceiling", long)
	}

	// b is back, a goes, and a wrap only b holds is there
	b.store(wrapToAt(t, peer, myXPub, "only b", time.Now().Add(-time.Minute)))
	standInDown(b, false)
	standInDown(a, true)
	at := time.Now()
	waitFor(t, "the wrap through b", 15*time.Second, func() bool { return inboxHas(tag + "|only b") })
	if d := time.Since(at); d > 12*time.Second {
		t.Fatalf("b took %s to carry once a went", d)
	}
}

// a store far away takes a send a second and a half late: the send is done
// at the other's ok, both get it, and the near one is the quicker
func TestFastPrefersTheQuicker(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	a.mu.Lock()
	a.okDelay = 1500 * time.Millisecond
	a.mu.Unlock()
	peer := newXid(t)
	ev := wrapToAt(t, peer, myXPub, "hello", time.Now())
	at := time.Now()
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
		t.Fatal("not sent")
	}
	if d := time.Since(at); d > time.Second {
		t.Fatalf("the send waited %s for the far store", d)
	}
	waitFor(t, "the far store took it too", 5*time.Second, func() bool {
		a.mu.Lock()
		defer a.mu.Unlock()
		return a.accepted == 1
	})
	var tx struct {
		Relays []map[string]any `json:"relays"`
	}
	waitFor(t, "the rows", 5*time.Second, func() bool {
		raw, _ := json.Marshal(transportSnapshot())
		if json.Unmarshal(raw, &tx) != nil {
			return false
		}
		quick := ""
		for _, r := range tx.Relays {
			if r["quicker"] == true {
				quick, _ = r["store"].(string)
			}
		}
		return quick == storeSecond
	})
	for _, r := range tx.Relays {
		if ms, _ := r["ms"].(float64); ms <= 0 || r["up"] != true {
			t.Fatalf("a row without its round trip: %v", r)
		}
		if r["store"] == storeFirst && r["quicker"] == true {
			t.Fatalf("the far store is called the quicker: %v", r)
		}
	}
	if top := topupFor(storeFirst); len(top) != 0 {
		t.Fatalf("a store that took it late still waits for it: %d", len(top))
	}
}

// the first store moved on while the second was out of reach: a wrap only
// the second holds, stamped back, is stepped over by the first store's
// anchor, and comes by the second's own
func TestTheSecondStoreHasItsOwnAnchor(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	now := time.Now()
	ts := func(d time.Duration) int64 { return now.Add(d).Unix() }
	if err := os.WriteFile(anchorFile(rcv, storeFirst), []byte(strconv.FormatInt(ts(-time.Hour), 10)), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(anchorFile(rcv, storeSecond), []byte(strconv.FormatInt(ts(-4*time.Hour), 10)), 0600); err != nil {
		t.Fatal(err)
	}
	both := wrapToAt(t, peer, myXPub, "both", now.Add(-30*time.Minute))
	a.store(both)
	b.store(both)
	b.store(wrapToAt(t, peer, myXPub, "only b, stamped back", now.Add(-14*time.Hour)))

	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, tag, mainPair(peer.pub), rcv)
	waitFor(t, "the wrap only b holds", 10*time.Second, func() bool {
		return inboxHas(tag+"|only b, stamped back") && inboxHas(tag+"|both")
	})
	since := func(r *relayStandIn) int64 {
		c := r.snapshot()
		return int64(c[0].reqs[0].filter.Since)
	}
	if s := since(a); s != ts(-time.Hour)-12*3600 {
		t.Fatalf("the first store asked from %d, not from its own anchor", s)
	}
	if s := since(b); s != ts(-4*time.Hour)-12*3600 {
		t.Fatalf("the second store asked from %d, not from its own anchor", s)
	}
	waitFor(t, "the app kept both", 5*time.Second, func() bool {
		pollAcked(time.Now())
		return inboxLen() == 0
	})
	// each file moves with what its own store handed over
	waitFor(t, "both files moved", 5*time.Second, func() bool {
		return readAnchor(t, anchorFile(rcv, storeFirst)) >= ts(-31*time.Minute) &&
			readAnchor(t, anchorFile(rcv, storeSecond)) >= ts(-31*time.Minute)
	})
	cancel()
	runnersGone(t)
	dropAddressFiles(rcv)
	if _, err := os.Stat(anchorFile(rcv, storeSecond)); !os.IsNotExist(err) {
		t.Fatal("the second store's file outlived the address")
	}
}

// an address the second store never had a file for walks all it holds: a
// wrap it alone took before this phone first read it still comes
func TestASecondStoreWithNoFileWalksAllItHolds(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	now := time.Now()
	if err := os.WriteFile(anchorFile(rcv, storeFirst), []byte(strconv.FormatInt(now.Add(-time.Hour).Unix(), 10)), 0600); err != nil {
		t.Fatal(err)
	}
	at := now.Add(-time.Hour)
	if live := time.Unix(secondLiveAt+60, 0); at.Before(live) {
		at = live
	}
	b.store(wrapToAt(t, peer, myXPub, "since it went live, only b", at))
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, tag, mainPair(peer.pub), rcv)
	waitFor(t, "the wrap only b holds", 10*time.Second, func() bool {
		return inboxHas(tag + "|since it went live, only b")
	})
	// all it holds, and nothing from before the day it went live
	if s := b.snapshot()[0].reqs[0].filter.Since; int64(s) != secondLiveAt-12*3600 {
		t.Fatalf("with no file the second store asked from %d, not from the day it went live", s)
	}
}

// a store that was down when a wrap went out gets it once it answers, also
// from a process after the one that sent it, with the same id
func TestATopUpReachesTheStoreThatMissedIt(t *testing.T) {
	for _, restart := range []bool{false, true} {
		t.Run("restart="+strconv.FormatBool(restart), func(t *testing.T) {
			a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
			useTwoStores(t, a, b)
			standInDown(a, true)
			peer := newXid(t)
			ev := wrapToAt(t, peer, myXPub, "while a was down", time.Now())
			if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
				t.Fatal("not sent")
			}
			waitFor(t, "it waits for a", 10*time.Second, func() bool { return len(topupFor(storeFirst)) == 1 })
			if len(topupFor(storeSecond)) != 0 {
				t.Fatal("the store that took it waits for it too")
			}
			if restart {
				topupSync()
				topupForget()
			}
			standInDown(a, false)
			relayOK(a.url())
			var got atomic.Bool
			waitFor(t, "a took it", 10*time.Second, func() bool {
				for _, c := range a.snapshot() {
					for _, e := range c.got {
						if e.ID == ev.ID {
							got.Store(true)
						}
					}
				}
				return got.Load()
			})
			waitFor(t, "nothing waits", 5*time.Second, func() bool { return len(topupFor(storeFirst)) == 0 })
			// nor after a restart: the file says it went
			topupSync()
			topupForget()
			if n := len(topupFor(storeFirst)); n != 0 {
				t.Fatalf("%d came back after a restart", n)
			}
		})
	}
}
