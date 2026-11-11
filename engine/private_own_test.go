// SPDX-License-Identifier: GPL-3.0-or-later
package main

// private on our two stores alone, the public relays listed as backups:
// read and written only while our first store is down, through tor, on
// private's own times, and let go once it is back. a backup's answer
// proves the route, so our two down is not tor down.

import (
	"context"
	"encoding/hex"
	"strings"
	"testing"
	"time"
)

// tor carries for the test. private's times are short, fast's long, so a
// fallback that comes went by private's
func privateTorUp(t *testing.T) {
	t.Helper()
	statusMu.RLock()
	oldStatus := torStatus
	statusMu.RUnlock()
	setStatus("bootstrapped")
	liveMu.Lock()
	oldAfter, oldSpan := fastDownAfter, fastFailSpan
	oldPAfter, oldPSpan := privateDownAfter, privateFailSpan
	fastDownAfter, fastFailSpan = time.Hour, time.Hour
	privateDownAfter, privateFailSpan = 2*time.Second, time.Second
	liveMu.Unlock()
	t.Cleanup(func() {
		setStatus(oldStatus)
		liveMu.Lock()
		fastDownAfter, fastFailSpan = oldAfter, oldSpan
		privateDownAfter, privateFailSpan = oldPAfter, oldPSpan
		liveMu.Unlock()
	})
}

// two stores on private, a public backup, all through the socks stand-in
func usePrivateOwn(t *testing.T) (a, b, p *relayStandIn, socks *socksStandIn) {
	t.Helper()
	a, b, p = newRelayStandIn(t, 0), newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	socks = newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, a, b)
	old, oldSpread := secondRelayHost.get(), secondFirstSpread
	secondRelayHost.put(strings.TrimPrefix(b.url(), "ws://"))
	secondFirstSpread = 0
	t.Cleanup(func() {
		runnersGone(t)
		secondRelayHost.put(old)
		secondFirstSpread = oldSpread
	})
	freshInbox(t)
	setBackups([]string{p.url()})
	p.mu.Lock()
	p.keep = true
	p.mu.Unlock()
	return a, b, p, socks
}

func TestPrivateFallsBackWhileOurFirstIsDownAndComesBack(t *testing.T) {
	a, b, p, socks := usePrivateOwn(t)
	privateTorUp(t)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, tag, mainPair(peer.pub), rcv)
	waitFor(t, "both of ours listen", 15*time.Second, func() bool {
		return len(a.snapshot()) > 0 && len(b.snapshot()) > 0
	})
	ev := wrapToAt(t, peer, myXPub, "both up", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
		t.Fatal("not sent")
	}
	waitFor(t, "both stores took it", 10*time.Second, func() bool { return gotID(a, ev.ID) && gotID(b, ev.ID) })
	time.Sleep(2 * time.Second)
	if n := len(p.snapshot()); n != 0 {
		t.Fatalf("with both of ours up the backup saw %d sockets", n)
	}

	// the first goes: an older contact's copy sits on the public relay only
	standInDown(a, true)
	p.store(wrapToAt(t, peer, myXPub, "an older contact wrote", time.Now().Add(-time.Minute)))
	waitFor(t, "the backup read", 30*time.Second, func() bool { return inboxHas(tag + "|an older contact wrote") })
	if !firstStoreDown() {
		t.Fatal("the backup was read with the first store up")
	}
	ev2 := wrapToAt(t, peer, myXPub, "while the first is down", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev2); ok < 1 {
		t.Fatal("not sent while the first is down")
	}
	waitFor(t, "the backup and the second took it", 15*time.Second, func() bool {
		return gotID(p, ev2.ID) && gotID(b, ev2.ID)
	})
	// private queues nothing on the phone, backups or not
	if n := len(topupFor(storeFirst)); n != 0 {
		t.Fatalf("private queued %d wraps", n)
	}
	for _, r := range []*relayStandIn{a, b, p} {
		allThroughSocks(t, r, socks)
	}

	// the first is back: every socket on the backup goes
	standInDown(a, false)
	kickRelays()
	waitFor(t, "the backup let go", 30*time.Second, func() bool {
		for _, c := range p.snapshot() {
			if c.closed.IsZero() {
				return false
			}
		}
		return !firstStoreDown()
	})
	a.pushLive(wrapToAt(t, peer, myXPub, "the first is back", time.Now()))
	waitFor(t, "the first carries again", 20*time.Second, func() bool { return inboxHas(tag + "|the first is back") })
}

// a send the first store missed goes to the backups at once on private
// too, before anything counts it as down: versions before the second store
// read the first and the public relays alone
func TestAPrivateSendOurFirstMissedGoesToTheBackups(t *testing.T) {
	a, b, p, socks := usePrivateOwn(t)
	privateTorUp(t)
	standInDown(a, true)
	peer := newXid(t)
	ev := wrapToAt(t, peer, myXPub, "missed by the first", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
		t.Fatal("not sent")
	}
	waitFor(t, "the backup copy", 15*time.Second, func() bool { return gotID(p, ev.ID) && gotID(b, ev.ID) })
	allThroughSocks(t, p, socks)
	standInDown(a, false)
	ev2 := wrapToAt(t, peer, myXPub, "taken by the first", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev2); ok < 1 {
		t.Fatal("not sent")
	}
	waitFor(t, "the first took it", 10*time.Second, func() bool { return gotID(a, ev2.ID) })
	time.Sleep(time.Second)
	if gotID(p, ev2.ID) {
		t.Fatal("a send the first store took went to a backup")
	}
}

// both of ours down and the backups in use: a backup taking a send proves
// the route on private, so the route watch has nothing to rescue
func TestABackupsAnswerProvesThePrivateRoute(t *testing.T) {
	a, b, p, _ := usePrivateOwn(t)
	privateTorUp(t)
	// gone, not refusing: a refusal is an answer through tor and proves
	// the route on its own
	a.srv.Close()
	b.srv.Close()
	liveMu.Lock()
	firstDown, firstKnown = true, true
	liveMu.Unlock()
	t.Cleanup(func() {
		liveMu.Lock()
		firstDown, firstKnown = false, false
		liveMu.Unlock()
	})
	if !backupsOn() {
		t.Fatal("the backups are not on")
	}
	// a bounce: nothing has answered on the new route yet
	routeBump()
	if routeOK() {
		t.Fatal("the route counts as proven before anything answered")
	}
	peer := newXid(t)
	ev := wrapToAt(t, peer, myXPub, "only the backup", time.Now())
	if ok := nostrPublishMulti(context.Background(), laneEveryday, ev); ok < 1 {
		t.Fatal("not sent through the backup")
	}
	waitFor(t, "the backup took it", 10*time.Second, func() bool { return gotID(p, ev.ID) })
	if !routeOK() {
		t.Fatal("a backup's answer through tor did not prove the route")
	}
}
