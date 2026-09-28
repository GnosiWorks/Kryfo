// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what a receive address keeps on disk goes with the room or the peer it
// belonged to, and nothing still finishing on it writes it again, until a
// subscription on the address starts anew

import (
	"context"
	"encoding/hex"
	"os"
	"strings"
	"testing"
	"time"

	"fiatjaf.com/nostr"
)

func put(t *testing.T, paths ...string) {
	t.Helper()
	for _, p := range paths {
		if err := os.WriteFile(p, []byte("x\n"), 0600); err != nil {
			t.Fatal(err)
		}
	}
}

func there(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

func TestRoomForgetTakesEveryAddressFile(t *testing.T) {
	useStandIns(t, modeFast, nil)
	me, a, b := newXid(t), newXid(t), newXid(t)
	var kept []string
	var gone []string
	for _, peer := range []xid{a, b} {
		_, rcv, err := nip17RcvAddressAs(me, peer.pub)
		if err != nil {
			t.Fatal(err)
		}
		s, l := addressFiles(rcv)
		gone = append(gone, s, l)
	}
	_, fcPk, err := fcKeysFrom(me.priv, 0)
	if err != nil {
		t.Fatal(err)
	}
	s, l := addressFiles(fcPk)
	gone = append(gone, s, l)
	// another room's, and a contact's
	other := newXid(t)
	_, rcv, _ := nip17RcvAddressAs(other, a.pub)
	s, l = addressFiles(rcv)
	kept = append(kept, s, l)
	put(t, append(gone, kept...)...)

	peers := []string{
		hex.EncodeToString(me.pub[:]),
		hex.EncodeToString(a.pub[:]),
		hex.EncodeToString(b.pub[:]),
		"not a key",
	}
	if err := roomForget(hex.EncodeToString(me.priv[:]), peers); err != nil {
		t.Fatal(err)
	}
	for _, p := range gone {
		if there(p) {
			t.Errorf("%s left", p)
		}
	}
	for _, p := range kept {
		if !there(p) {
			t.Errorf("%s gone", p)
		}
	}
}

func TestPeerUnsubscribeTakesItsFilesAndNothingWritesThemAgain(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	seenPath, lastPath := addressFiles(rcv)
	ev := wrapTo(t, peer, myXPub, "hi")
	relay.store(ev)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	nostrMu.Lock()
	nostrSubs[tag] = cancel
	nostrMu.Unlock()
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	waitFor(t, "the event opened", 10*time.Second, func() bool { return inboxLen() == 1 })
	waitFor(t, "the anchor written", 10*time.Second, func() bool { return there(lastPath) })

	if err := nostrUnsubscribe(tag); err != nil {
		t.Fatal(err)
	}
	nostrMu.Lock()
	_, still := nostrSubs[tag]
	nostrMu.Unlock()
	if still {
		t.Fatal("the subscription is still there")
	}
	if there(seenPath) || there(lastPath) {
		t.Fatal("files left")
	}
	// the app takes the batch the runner opened: nothing is written back
	pollEntries(t)
	s := loadSeen(seenPath)
	s.handedOver([]nostr.ID{randomID(t)})
	time.Sleep(300 * time.Millisecond)
	if there(seenPath) || there(lastPath) {
		t.Fatal("written again after the address was let go of")
	}

	// a new subscription on the address keeps its files again
	ctx2, cancel2 := context.WithCancel(context.Background())
	defer cancel2()
	go nostrSubscribeRunner(ctx2, tag, peer.pub, rcv)
	waitFor(t, "the event came again", 10*time.Second, func() bool { return inboxLen() == 1 })
	pollEntries(t)
	waitFor(t, "remembered again", 10*time.Second, func() bool {
		b, _ := os.ReadFile(seenPath)
		return strings.Contains(string(b), ev.ID.Hex())
	})
}
