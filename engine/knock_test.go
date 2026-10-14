// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	nostr2 "github.com/nbd-wtf/go-nostr"
)

type knockWorld struct {
	peers    []string // contacts' x keys
	contacts []string // their receive addresses
	fc       string
	room     xid
	roomPk   string
	keys     []string
}

// subscriptions as the app starts them, without their runners: contacts,
// the first-contact address and one room's member. taken down afterwards
func knockSubs(t *testing.T, contacts int) *knockWorld {
	t.Helper()
	w := &knockWorld{}
	idle := func(ctx context.Context) { <-ctx.Done() }
	for i := 0; i < contacts; i++ {
		p := newXid(t)
		h := hex.EncodeToString(p.pub[:])
		startSub(h, idle)
		w.keys = append(w.keys, h)
		w.peers = append(w.peers, h)
		_, pk, _ := nip17RcvAddress(p.pub)
		w.contacts = append(w.contacts, pk)
	}
	startSub("firstcontact", idle)
	w.keys = append(w.keys, "firstcontact")
	nostrMu.Lock()
	oldFc := fcCounterNow
	fcCounterNow = 0
	nostrMu.Unlock()
	_, w.fc, _ = nip17FirstContactKeys(0)
	w.room = newXid(t)
	member := newXid(t)
	sk, pk, err := nip17RcvAddressAs(w.room, member.pub)
	if err != nil {
		t.Fatal(err)
	}
	w.roomPk = pk
	key := roomSubKey(w.room, hex.EncodeToString(member.pub[:]))
	lane := roomLane(hex.EncodeToString(w.room.pub[:]))
	noteKnockTarget(key, knockTarget{pk, sk, lane, lane, ""})
	startSub(key, idle)
	w.keys = append(w.keys, key)
	t.Cleanup(func() {
		nostrMu.Lock()
		fcCounterNow = oldFc
		for _, k := range w.keys {
			if c, ok := nostrSubs[k]; ok {
				c()
				delete(nostrSubs, k)
			}
		}
		nostrMu.Unlock()
	})
	return w
}

func (w *knockWorld) unsubscribe(k string) {
	nostrMu.Lock()
	if c, ok := nostrSubs[k]; ok {
		c()
		delete(nostrSubs, k)
	}
	nostrMu.Unlock()
}

type knockRow struct{ I, G string }

func knockRows(t *testing.T, exclude string) map[string]string {
	t.Helper()
	var rows []knockRow
	if err := json.Unmarshal([]byte(knockAddresses(exclude)), &rows); err != nil {
		t.Fatal(err)
	}
	out := map[string]string{}
	for _, r := range rows {
		out[r.I] = r.G
	}
	return out
}

func TestKnockAddressesNameNoAddress(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	w := knockSubs(t, 6)
	got := knockRows(t, "")
	raw := knockAddresses("")
	for _, pk := range append(append([]string{w.fc, w.roomPk}, w.contacts...), hex.EncodeToString(w.room.pub[:])) {
		if strings.Contains(raw, pk) || strings.Contains(raw, pk[:16]) {
			t.Fatal("the list names an address or a room key")
		}
	}
	for _, pk := range w.contacts {
		if got[knockID(pk)] != receiveLane(pk) {
			t.Fatalf("a contact's address is in group %q, its lane is %q", got[knockID(pk)], receiveLane(pk))
		}
	}
	if g := got[knockID(w.fc)]; !strings.HasPrefix(g, "firstcontact:") {
		t.Fatalf("the first-contact address is in group %q", g)
	}
	if g := got[knockID(w.roomPk)]; !strings.HasPrefix(g, "room:") {
		t.Fatalf("the room's address is in group %q", g)
	}
	// the same every time, under this identity
	if knockAddresses("") != raw {
		t.Fatal("the ids moved between two calls")
	}
}

func TestKnockLeavesHiddenChatsOut(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	w := knockSubs(t, 3)
	hidden, _ := json.Marshal([]string{strings.ToUpper(w.peers[1])})
	got := knockRows(t, string(hidden))
	if _, ok := got[knockID(w.contacts[1])]; ok {
		t.Fatal("a hidden chat's address was listed")
	}
	if _, ok := got[knockID(w.contacts[0])]; !ok {
		t.Fatal("an everyday contact's address was left out")
	}
}

type knockOut struct{ Done, Dup, Unknown, Refused []string }

func runRegister(t *testing.T, items []knockItem) knockOut {
	t.Helper()
	raw, _ := json.Marshal(items)
	var out knockOut
	if err := json.Unmarshal([]byte(knockRegister(string(raw))), &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func TestKnockRegisterGoesOnEachLaneToOurRelayOnly(t *testing.T) {
	own := newRelayStandIn(t, 0)
	other := newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, own, other)
	w := knockSubs(t, 5)
	knockAddresses("")
	dummy := nostr2.GeneratePrivateKey()
	dummyPk, _ := nostr2.GetPublicKey(dummy)

	ep := func(i int) string { return "https://push.example.org/up" + string(rune('a'+i)) }
	items := []knockItem{{I: knockID(w.fc), E: ep(0)}, {I: knockID(w.roomPk), E: ep(1)}, {K: dummy, S: 9, E: ep(2)}, {I: strings.Repeat("ab", 16), E: ep(3)}}
	for i, pk := range w.contacts {
		items = append(items, knockItem{I: knockID(pk), E: ep(4 + i%2)})
	}
	out := runRegister(t, items)
	if len(out.Done) != len(items)-1 {
		t.Fatalf("done %v: want every item but the unknown one", out.Done)
	}

	lanes := map[string]string{w.fc: laneFirstContact, w.roomPk: roomLane(hex.EncodeToString(w.room.pub[:])), dummyPk: knockSlotLane(9)}
	for _, pk := range w.contacts {
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

// a route switch in the middle of a batch: nothing goes out direct, and
// what was not sent before the switch stays unsent
func TestKnockRouteSwitchEndsTheBatch(t *testing.T) {
	own := newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, own)
	w := knockSubs(t, 12)
	knockAddresses("")
	var sent atomic.Int32
	old := knockPublish
	knockPublish = func(ctx context.Context, lane string, ev nostr.Event) error {
		err := old(ctx, lane, ev)
		if sent.Add(1) == 2 {
			transportMode.Store("fast")
			nostrResetClient()
		}
		return err
	}
	t.Cleanup(func() { knockPublish = old })
	var items []knockItem
	for _, pk := range w.contacts {
		items = append(items, knockItem{I: knockID(pk), E: "https://push.example.org/up"})
	}
	out := runRegister(t, items)
	if len(out.Done) >= len(items) {
		t.Fatalf("all %d went after the route changed", len(out.Done))
	}
	for _, c := range own.snapshot() {
		if _, viaTor := socks.nameOf(c.remote); !viaTor {
			t.Fatal("a registration went out direct after the switch")
		}
	}
}

func TestKnockRegistersOnlyOnThePrivateRoute(t *testing.T) {
	own := newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, own)
	w := knockSubs(t, 2)
	knockAddresses("")
	transportMode.Store("fast")
	nostrResetClient()
	out := runRegister(t, []knockItem{{I: knockID(w.contacts[0]), E: "https://push.example.org/up"}, {I: knockID(w.contacts[1]), E: ""}})
	if len(out.Done) != 1 || out.Done[0] != knockID(w.contacts[1]) {
		t.Fatalf("off the private route: done %v, want only the forget", out.Done)
	}
	for _, c := range own.snapshot() {
		if _, viaTor := socks.nameOf(c.remote); !viaTor {
			t.Fatal("a forget went outside tor")
		}
	}
}

// an address no longer listened on is never signed for again, not even to
// forget it: a forget for a chat just hidden, or for a first-contact address
// just replaced, would tell the relay what the phone does
func TestKnockNeverSignsForAnAddressGone(t *testing.T) {
	own := newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, own)
	w := knockSubs(t, 2)
	knockAddresses("")
	w.unsubscribe(w.peers[0])
	id := knockID(w.contacts[0])
	for _, e := range []string{"https://push.example.org/up", ""} {
		out := runRegister(t, []knockItem{{I: id, E: e}})
		if len(out.Done) != 0 || len(out.Unknown) != 1 {
			t.Fatalf("an address gone was signed for (%q): %+v", e, out)
		}
	}
}

// a new first-contact address registers on the new address's circuit,
// never on the one the old address used
func TestKnockFirstContactResetTakesANewCircuit(t *testing.T) {
	own := newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, own)
	w := knockSubs(t, 1)
	knockAddresses("")
	if out := runRegister(t, []knockItem{{I: knockID(w.fc), E: "https://push.example.org/a"}}); len(out.Done) != 1 {
		t.Fatalf("old: %+v", out)
	}
	oldName := laneName(laneFirstContact)
	// the invite is reset: a new counter, the lane dropped
	nostrMu.Lock()
	fcCounterNow = 1
	nostrMu.Unlock()
	dropLane(laneFirstContact)
	_, fresh, _ := nip17FirstContactKeys(1)
	out := runRegister(t, []knockItem{{I: knockID(fresh), E: "https://push.example.org/b"}, {I: knockID(w.fc), E: ""}})
	if len(out.Done) != 1 || out.Done[0] != knockID(fresh) {
		t.Fatalf("after the reset: %+v", out)
	}
	newName := laneName(laneFirstContact)
	if newName == oldName {
		t.Fatal("the lane kept its name")
	}
	for _, c := range own.snapshot() {
		for _, ev := range c.got {
			if ev.PubKey.Hex() != fresh {
				continue
			}
			if name, _ := socks.nameOf(c.remote); name != newName {
				t.Fatal("the new first-contact address registered on the old circuit")
			}
		}
	}
}

func TestKnockRegisterReportsDuplicates(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	w := knockSubs(t, 2)
	knockAddresses("")
	old := knockPublish
	knockPublish = func(_ context.Context, _ string, ev nostr.Event) error {
		if ev.PubKey.Hex() == w.contacts[0] {
			return errorString("msg: duplicate: not newer than what is kept")
		}
		return nil
	}
	t.Cleanup(func() { knockPublish = old })
	out := runRegister(t, []knockItem{{I: knockID(w.contacts[0]), E: "https://p/u"}, {I: knockID(w.contacts[1]), E: "https://p/u"}})
	if len(out.Dup) != 1 || out.Dup[0] != knockID(w.contacts[0]) || len(out.Done) != 1 {
		t.Fatalf("got %+v", out)
	}
}

func TestKnockRegisterReportsRefusals(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	w := knockSubs(t, 2)
	knockAddresses("")
	old := knockPublish
	knockPublish = func(_ context.Context, _ string, ev nostr.Event) error {
		if ev.PubKey.Hex() == w.contacts[0] {
			return errorString("msg: invalid: created_at is too far from now")
		}
		return errorString("dial: connection refused")
	}
	t.Cleanup(func() { knockPublish = old })
	out := runRegister(t, []knockItem{{I: knockID(w.contacts[0]), E: ""}, {I: knockID(w.contacts[1]), E: ""}})
	if len(out.Refused) != 1 || out.Refused[0] != knockID(w.contacts[0]) || len(out.Done)+len(out.Dup)+len(out.Unknown) != 0 {
		t.Fatalf("got %+v", out)
	}
}

// the engine keeps the hidden chats out itself, whatever an item asks
func TestKnockNeverSignsForAHiddenChat(t *testing.T) {
	own := newRelayStandIn(t, 0)
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, own)
	w := knockSubs(t, 2)
	hidden, _ := json.Marshal([]string{w.peers[0]})
	knockAddresses(string(hidden))
	t.Cleanup(func() { knockAddresses("") })
	for _, e := range []string{"https://push.example.org/up", ""} {
		out := runRegister(t, []knockItem{{I: knockID(w.contacts[0]), E: e}})
		if len(out.Done) != 0 || len(out.Unknown) != 1 {
			t.Fatalf("a hidden chat's address was signed for (%q): %+v", e, out)
		}
	}
	out := runRegister(t, []knockItem{{I: knockID(w.contacts[1]), E: "https://push.example.org/up"}})
	if len(out.Done) != 1 {
		t.Fatalf("an everyday contact was refused: %+v", out)
	}
}

type errorString string

func (e errorString) Error() string { return string(e) }

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

// the check asks over a lane of its own, through tor
func TestKnockCheckHasItsOwnLane(t *testing.T) {
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{"tags": []string{knockTag}})
	}))
	defer srv.Close()
	setRelays([]string{"ws" + strings.TrimPrefix(srv.URL, "http")})
	if got := knockCheck(); got != "yes" {
		t.Fatalf("check: %q", got)
	}
	if socks.countAs(laneName(laneKnockInfo)) == 0 {
		t.Fatal("the check did not go on its own lane")
	}
	if socks.countAs(laneName(laneServices)) != 0 {
		t.Fatal("the check went on the services lane")
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
