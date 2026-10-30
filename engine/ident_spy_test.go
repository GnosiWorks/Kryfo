// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the engine's side of the one door (identity v4 4.2, 16 item 10): what
// it publishes and listens on for a peer reached on an identity of its
// own carries nothing of the main one. every address, seal key and tag is
// that identity's, on a relay stand-in that keeps what it is sent

import (
	"encoding/hex"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
)

func TestAnotherIdentityUsesNothingOfTheMain(t *testing.T) {
	r := newRelayStandIn(t, 0)
	r.mu.Lock()
	r.keep = true
	r.mu.Unlock()
	useStandIns(t, modeFast, nil, r)
	main := testMain()
	ci := newXid(t)
	putIdentity(5, ci)
	defer identDrop(5)
	peer := newXid(t)
	peerHex := hex.EncodeToString(peer.pub[:])

	// what the main identity would have used with them: none of it may
	// show up
	_, mainRcv, _ := nip17RcvAddressAs(main, peer.pub)
	_, mainTheirs, _ := nip17DeriveRoleAs(main, peer.pub, nip17RcvInfo, peerHex)
	_, mainSeal, _ := nip17DeriveRoleAs(main, peer.pub, nip17SndInfo, hex.EncodeToString(main.pub[:]))
	_, mainFc, _ := nip17FirstContactKeysAs(main, 0)
	mainMarks := []string{
		hex.EncodeToString(main.pub[:]), mainRcv, mainTheirs, mainSeal, mainFc,
	}
	clean := func(what, s string) {
		t.Helper()
		for _, m := range mainMarks {
			if strings.Contains(strings.ToLower(s), m) {
				t.Errorf("%s carries %s... of the main identity", what, m[:12])
			}
		}
	}
	c, err := pairOf(5, peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	_, ciRcv, _ := c.rcvAddress()
	ciTheirs, _ := c.theirAddress()

	// a send: on their address for this identity, sealed by its key
	if res := nostrSend(5, peerHex, "hi"); res != "ok" {
		t.Fatalf("send: %s", res)
	}
	waitFor(t, "the send on the relay", 10*time.Second, func() bool {
		return len(connsOn(r.snapshot(), []string{ciTheirs})) > 0
	})
	if len(connsOn(r.snapshot(), []string{mainTheirs})) > 0 {
		t.Fatal("published to the main identity's address")
	}
	var sent []nostr2.Event
	r.mu.Lock()
	for _, e := range r.events {
		b, _ := easyjson.Marshal(e)
		var ev nostr2.Event
		if err := json.Unmarshal(b, &ev); err == nil {
			sent = append(sent, ev)
		}
		clean("a published event", string(b))
	}
	r.mu.Unlock()
	if len(sent) != 1 {
		t.Fatalf("%d events on the relay", len(sent))
	}
	got, _, err := nip17UnwrapAsStamped(peer, ci.pub, sent[0])
	if err != nil || got != "hi" {
		t.Fatalf("their side: %q %v", got, err)
	}
	if _, _, err := nip17UnwrapAsStamped(peer, main.pub, sent[0]); err == nil {
		t.Fatal("opened as from the main identity")
	}

	// a listen: on this identity's address, under its own key, in the
	// knocks too
	if res := nostrSubscribe(5, peerHex, false); res != "ok" {
		t.Fatalf("subscribe: %s", res)
	}
	defer nostrUnsubscribe(5, peerHex)
	waitFor(t, "the listen on the relay", 10*time.Second, func() bool {
		return len(connsOn(r.snapshot(), []string{ciRcv})) > 0
	})
	if len(connsOn(r.snapshot(), []string{mainRcv})) > 0 {
		t.Fatal("listened on the main identity's address")
	}
	nostrMu.Lock()
	_, mine := nostrSubs["i5:"+peerHex]
	_, asMain := nostrSubs[peerHex]
	nostrMu.Unlock()
	if !mine || asMain {
		t.Fatalf("subscription keys: own %v, main's %v", mine, asMain)
	}
	knocks := knockTargets()
	var knocked bool
	for _, k := range knocks {
		if k.pk == ciRcv {
			knocked = true
		}
		clean("a knock target", k.pk+k.sk+k.group)
	}
	if !knocked {
		t.Fatal("the knocks do not have its address")
	}

	// a first contact from it: sealed with its hello seal key
	stranger := newXid(t)
	fcSk, fcPk, _ := fcKeysFrom(stranger.priv, 0)
	if res := nostrSendFirstContact(5, hex.EncodeToString(stranger.pub[:]), fcPk, "hello"); res != "ok" {
		t.Fatalf("first contact: %s", res)
	}
	waitFor(t, "the first contact on the relay", 10*time.Second, func() bool {
		r.mu.Lock()
		defer r.mu.Unlock()
		return len(r.events) == 2
	})
	r.mu.Lock()
	b, _ := easyjson.Marshal(r.events[1])
	r.mu.Unlock()
	clean("a first contact", string(b))
	var fc nostr2.Event
	if err := json.Unmarshal(b, &fc); err != nil {
		t.Fatal(err)
	}
	_, sealPk, err := nip17UnwrapFirstContactWith(fcSk, fc)
	if err != nil {
		t.Fatal(err)
	}
	clean("a first contact's seal", sealPk)
	if want, _ := v4HelloSealPk(stranger, ci.pub); sealPk != want {
		t.Fatalf("sealed by %s, want its hello seal key", sealPk)
	}
}
