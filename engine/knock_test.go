// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	nostr2 "github.com/nbd-wtf/go-nostr"
)

// subscriptions as the app starts them, without their runners: contacts,
// the first-contact address and one room's member. taken down afterwards
func knockSubs(t *testing.T, contacts int) (peers []string, room xid, roomPk string) {
	t.Helper()
	idle := func(ctx context.Context) { <-ctx.Done() }
	var keys []string
	for i := 0; i < contacts; i++ {
		p := newXid(t)
		h := hex.EncodeToString(p.pub[:])
		startSub(h, idle)
		keys = append(keys, h)
		peers = append(peers, h)
	}
	startSub("firstcontact", idle)
	keys = append(keys, "firstcontact")
	nostrMu.Lock()
	oldFc := fcCounterNow
	fcCounterNow = 0
	nostrMu.Unlock()
	room = newXid(t)
	member := newXid(t)
	sk, pk, err := nip17RcvAddressAs(room, member.pub)
	if err != nil {
		t.Fatal(err)
	}
	key := roomSubKey(room, hex.EncodeToString(member.pub[:]))
	lane := roomLane(hex.EncodeToString(room.pub[:]))
	noteKnockTarget(key, knockTarget{pk, sk, lane, lane})
	startSub(key, idle)
	keys = append(keys, key)
	t.Cleanup(func() {
		nostrMu.Lock()
		fcCounterNow = oldFc
		for _, k := range keys {
			if c, ok := nostrSubs[k]; ok {
				c()
				delete(nostrSubs, k)
			}
		}
		nostrMu.Unlock()
	})
	return peers, room, pk
}

func TestKnockAddressesCarryTheirGroup(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	peers, room, roomPk := knockSubs(t, 6)
	var rows []struct{ A, G string }
	if err := json.Unmarshal([]byte(knockAddresses()), &rows); err != nil {
		t.Fatal(err)
	}
	if len(rows) < 8 {
		t.Fatalf("%d addresses, want at least the 8 started here", len(rows))
	}
	got := map[string]string{}
	for _, r := range rows {
		got[r.A] = r.G
	}
	for _, h := range peers {
		p, _ := peerArr(h)
		_, pk, _ := nip17RcvAddress(p)
		if got[pk] != receiveLane(pk) {
			t.Fatalf("a contact's address is in group %q, its lane is %q", got[pk], receiveLane(pk))
		}
	}
	_, fc, _ := nip17FirstContactKeys(0)
	if got[fc] != "firstcontact:"+fc {
		t.Fatalf("the first-contact address is in group %q", got[fc])
	}
	if got[roomPk] != roomLane(hex.EncodeToString(room.pub[:])) {
		t.Fatalf("the room's address is in group %q", got[roomPk])
	}
	if strings.Contains(knockAddresses(), "sk") {
		t.Fatal("the list carries more than addresses and groups")
	}
}

func TestKnockRegisterGoesOnEachLaneToOurRelayOnly(t *testing.T) {
	own := newRelayStandIn(t, 0)
	other := newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, own, other)
	peers, room, roomPk := knockSubs(t, 5)
	_, fc, _ := nip17FirstContactKeys(0)
	var contacts []string
	for _, h := range peers {
		p, _ := peerArr(h)
		_, pk, _ := nip17RcvAddress(p)
		contacts = append(contacts, pk)
	}
	dummy := nostr2.GeneratePrivateKey()
	dummyPk, _ := nostr2.GetPublicKey(dummy)
	stranger := strings.Repeat("ab", 32)

	ep := func(i int) string { return "https://push.example.org/up" + string(rune('a'+i)) }
	items := []knockItem{{A: fc, E: ep(0)}, {A: roomPk, E: ep(1)}, {K: dummy, S: 9, E: ep(2)}, {A: stranger, E: ep(3)}}
	for i, pk := range contacts {
		items = append(items, knockItem{A: pk, E: ep(4 + i%2)})
	}
	raw, _ := json.Marshal(items)
	var out struct{ Done []string }
	if err := json.Unmarshal([]byte(knockRegister(string(raw))), &out); err != nil {
		t.Fatal(err)
	}
	if len(out.Done) != len(items)-1 {
		t.Fatalf("done %v: want every item but the stranger's", out.Done)
	}
	for _, d := range out.Done {
		if d == stranger {
			t.Fatal("an address the engine does not listen on was registered")
		}
	}

	lanes := map[string]string{fc: laneFirstContact, roomPk: roomLane(hex.EncodeToString(room.pub[:])), dummyPk: knockSlotLane(9)}
	for _, pk := range contacts {
		lanes[pk] = receiveLane(pk)
	}
	seen := map[string]string{}
	for _, c := range own.snapshot() {
		for _, ev := range c.got {
			if ev.Kind != knockKind {
				continue
			}
			pk := ev.PubKey.Hex()
			if len(ev.Tags) != 0 || !strings.HasPrefix(ev.Content, "https://push.example.org/up") {
				t.Fatalf("registration %+v", ev)
			}
			if !ev.VerifySignature() {
				t.Fatal("a registration is not signed by its address")
			}
			name, viaTor := socks.nameOf(c.remote)
			if !viaTor {
				t.Fatal("a registration went outside tor")
			}
			seen[pk] = name
		}
	}
	if len(seen) != len(items)-1 {
		t.Fatalf("our relay saw %d registrations, want %d", len(seen), len(items)-1)
	}
	for pk, name := range seen {
		if name != laneName(lanes[pk]) {
			t.Fatalf("a registration for %s... came in on another lane than its address's", pk[:8])
		}
	}
	// the slot without an address shares a circuit with no address
	for pk, name := range seen {
		if pk != dummyPk && name == seen[dummyPk] {
			t.Fatal("a stand-in registration shared a lane with an address")
		}
	}
	for _, c := range other.snapshot() {
		for _, ev := range c.got {
			if ev.Kind == knockKind {
				t.Fatal("a registration went to a relay that is not ours")
			}
		}
	}
}

func TestKnockRegisterOnlyOverTor(t *testing.T) {
	useStandIns(t, "fast", nil)
	if got := knockRegister(`[]`); !strings.HasPrefix(got, "error") {
		t.Fatalf("a registration outside tor answered %q", got)
	}
}

func TestKnockEventIsSignedByTheAddress(t *testing.T) {
	sk := nostr2.GeneratePrivateKey()
	pk, _ := nostr2.GetPublicKey(sk)
	ev, err := knockEvent(sk, pk, "https://ntfy.sh/upX?up=1", time.Unix(1_800_000_000, 0))
	if err != nil {
		t.Fatal(err)
	}
	if ev.Kind != knockKind || ev.PubKey.Hex() != pk || len(ev.Tags) != 0 || !ev.VerifySignature() {
		t.Fatalf("event %+v", ev)
	}
	if _, err := knockEvent(sk, strings.Repeat("0", 64), "", time.Now()); err == nil {
		t.Fatal("a registration was signed for an address the key is not")
	}
}

func TestKnockInfoURL(t *testing.T) {
	for in, want := range map[string]string{
		"wss://relay.kryfo.app":       "https://relay.kryfo.app/",
		"wss://relay.kryfo.app/x?y=1": "https://relay.kryfo.app/",
		"ws://abcdef.onion":           "http://abcdef.onion/",
		"https://relay.kryfo.app":     "",
		"not a url":                   "",
	} {
		got, ok := knockInfoURL(in)
		if (want == "") == ok || got != want {
			t.Errorf("%q: got %q %v", in, got, ok)
		}
	}
}

func TestKnockCheckReadsTheRelayInfo(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	tags := []string{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") != "application/nostr+json" {
			http.Error(w, "no", 400)
			return
		}
		json.NewEncoder(w).Encode(map[string]any{"name": "relay", "tags": tags})
	}))
	defer srv.Close()
	old := knockInfoClient
	knockInfoClient = func(context.Context) (*http.Client, error) { return srv.Client(), nil }
	t.Cleanup(func() { knockInfoClient = old })
	setRelays([]string{"ws" + strings.TrimPrefix(srv.URL, "http"), "wss://nos.lol"})

	if got := knockCheck(); got != "no" {
		t.Fatalf("a relay that cannot knock: %q", got)
	}
	tags = []string{"sfw-only", knockTag}
	if got := knockCheck(); got != "yes" {
		t.Fatalf("a relay that knocks: %q", got)
	}
	srv.Close()
	if got := knockCheck(); !strings.HasPrefix(got, "error") {
		t.Fatalf("a relay that does not answer: %q", got)
	}
}

func TestKnockItemTime(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	for _, c := range []struct {
		t    int64
		want time.Time
	}{
		{0, now},
		{now.Unix() - 600, now.Add(-10 * time.Minute)},
		{now.Unix() + 5, now},
		{now.Unix() - int64(knockBack/time.Second) - 1, now},
	} {
		if got := (knockItem{T: c.t}).at(now); !got.Equal(c.want) {
			t.Errorf("t=%d: %v, want %v", c.t, got, c.want)
		}
	}
}
