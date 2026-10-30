// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	"github.com/halo/engine/devices"
	"github.com/halo/engine/kshim"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
)

// a relay in memory: every event, by the address its p tag names. the
// link's own reader decides what counts, as it does on the real relays
type fakeRelay struct {
	mu  sync.Mutex
	evs map[string][]nostr.Event
}

func (f *fakeRelay) put(ev nostr.Event) {
	f.mu.Lock()
	defer f.mu.Unlock()
	pk := ev.Tags.Find("p")[1]
	f.evs[pk] = append(f.evs[pk], ev)
}

func (f *fakeRelay) post(_ context.Context, seed [32]byte, msg []byte) error {
	ev, _, err := linkEvent(seed, msg, time.Now())
	if err != nil {
		return err
	}
	f.put(ev)
	return nil
}

func (f *fakeRelay) fetch(_ context.Context, seed [32]byte) ([][]byte, error) {
	_, pk, err := linkKeys(seed)
	if err != nil {
		return nil, err
	}
	f.mu.Lock()
	evs := append([]nostr.Event(nil), f.evs[pk]...)
	f.mu.Unlock()
	return linkMessages(seed, evs), nil
}

// the magics now at an address, as the link reads them
func (f *fakeRelay) kinds(t *testing.T, seed [32]byte) string {
	t.Helper()
	ms, _ := f.fetch(context.Background(), seed)
	var k []string
	for _, m := range ms {
		k = append(k, string(m[:4]))
	}
	return strings.Join(k, ",")
}

// the door in this process: each line on a stream of its own, through the
// onion door's own handler
func pipeDoor(lines *atomic.Int32) linkDialer {
	return func(ctx context.Context, onion, line string) error {
		c, s := net.Pipe()
		go handleConn(s)
		defer c.Close()
		c.SetDeadline(time.Now().Add(5 * time.Second))
		if _, err := io.WriteString(c, line+"\n"); err != nil {
			return err
		}
		ack := make([]byte, len(doorAck))
		if _, err := io.ReadFull(c, ack); err != nil || string(ack) != doorAck {
			return fmt.Errorf("no ack: %v", err)
		}
		if lines != nil {
			lines.Add(1)
		}
		return nil
	}
}

type linkWorld struct {
	l      *kshim.Lib
	relay  *fakeRelay
	phone  *devAcct
	pState *devState
	devKey *devSigner
	lines  atomic.Int32
}

const testPhoneOnion = "abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwd"

func newLinkWorld(t *testing.T) *linkWorld {
	t.Helper()
	w := &linkWorld{l: devTestShim(t), relay: &fakeRelay{evs: map[string][]nostr.Event{}}}
	w.phone = newDevAcct(t, w.l)
	w.devKey = newDevSigner(t, w.l)
	oldWire, oldDial, oldPoll, oldOnion, oldCur := linkWireNow, linkDialNow, linkPoll, linkOnionOf, devCur
	linkWireNow, linkDialNow, linkPoll = w.relay, pipeDoor(&w.lines), 5*time.Millisecond
	linkOnionOf = func() string { return testPhoneOnion }
	t.Cleanup(func() {
		linkWireNow, linkDialNow, linkPoll, linkOnionOf = oldWire, oldDial, oldPoll, oldOnion
		devMu.Lock()
		devCur = oldCur
		devMu.Unlock()
		linkMu.Lock()
		for k, r := range linkRuns {
			r.cancel()
			delete(linkRuns, k)
		}
		linkMu.Unlock()
	})
	w.pState = w.load(t, w.phone.id.pub, w.phone.id.pub)
	// the phone's own list as it signs it: the phone alone
	w.as(w.pState)
	var o devOut
	call(t, devSessionJSON("own_mine", jsonOf(t, map[string]any{"ident": 0, "list": w.phone.wire})), &o)
	if o.Err != "" {
		t.Fatalf("own_mine: %s", o.Err)
	}
	return w
}

func jsonOf(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func call(t *testing.T, raw string, into any) {
	t.Helper()
	if err := json.Unmarshal([]byte(raw), into); err != nil {
		t.Fatalf("%s: %v", raw, err)
	}
}

// a container's state as dart loads it: identity, and this device's key
func (w *linkWorld) load(t *testing.T, identity, key devices.Key) *devState {
	t.Helper()
	var in devLoad
	call(t, jsonOf(t, map[string]any{"mine": []map[string]any{{"ident": 0, "identity": hexKey(identity), "key": hexKey(key)}}}), &in)
	d, _, _, err := loadDevState(&in, devVerifier{w.l})
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func (w *linkWorld) as(d *devState) {
	devMu.Lock()
	devCur = d
	devMu.Unlock()
}

func link(t *testing.T, op string, args map[string]any) linkOut {
	t.Helper()
	var o linkOut
	call(t, devLinkJSON(op, jsonOf(t, args)), &o)
	return o
}

func waitState(t *testing.T, id string, want ...string) linkOut {
	t.Helper()
	end := time.Now().Add(10 * time.Second)
	for {
		o := link(t, "state", map[string]any{"link": id})
		for _, s := range want {
			if o.St == s {
				return o
			}
		}
		if time.Now().After(end) {
			t.Fatalf("link %s at %q (%s), wanted %v", id[:6], o.St, o.Why, want)
		}
		time.Sleep(2 * time.Millisecond)
	}
}

// a KDB1 of the device on its entry, as dart's makeBundle would give one
func linkKDB1(t *testing.T, e devEntry, kyber uint32) []byte {
	t.Helper()
	k, err := parseHexKey(e.Key)
	if err != nil {
		t.Fatal(err)
	}
	spk := newDevSigner(t, devTestShim(t)).pub
	b := &devices.Block{
		Reg: e.Reg, Device: uint8(e.ID), HasKey: true, Key: k,
		SpkID: 7, Spk: spk, SpkSig: bytes.Repeat([]byte{0x5a}, devices.SigSize),
		KyberID: kyber, Kyber: append([]byte{0x08}, bytes.Repeat([]byte{0x33}, devices.KyberSize-1)...),
		KyberSig: bytes.Repeat([]byte{0x6b}, devices.SigSize),
	}
	w, err := devices.EncodeBundle(b)
	if err != nil {
		t.Fatal(err)
	}
	return w
}

// both sides up to the digits
func (w *linkWorld) toDigits(t *testing.T) (jid, pid, offer string) {
	t.Helper()
	j := link(t, "join_start", map[string]any{"key": hexKey(w.devKey.pub), "reg": 4321})
	if j.Err != "" || !strings.HasPrefix(j.Offer, devices.OfferPrefix) {
		t.Fatalf("join_start: %+v", j)
	}
	waitState(t, j.Link, lsOffer)
	p := link(t, "link_start", map[string]any{"offer": j.Offer, "key": hexKey(w.phone.id.pub)})
	if p.Err != "" {
		t.Fatalf("link_start: %+v", p)
	}
	return j.Link, p.Link, j.Offer
}

// the phone signs its next list and confirms
func (w *linkWorld) phoneConfirms(t *testing.T, pid string) {
	t.Helper()
	w.as(w.pState)
	o := link(t, "list", map[string]any{"link": pid, "ident": 0, "reg": 4321})
	if o.Err != "" || len(o.Body) == 0 {
		t.Fatalf("list: %+v", o)
	}
	sig, err := w.phone.id.Sign(devices.ContextList, o.Body)
	if err != nil {
		t.Fatal(err)
	}
	if s := link(t, "sign", map[string]any{"link": pid, "sig": sig}); s.Err != "" {
		t.Fatalf("sign: %s", s.Err)
	}
	if c := link(t, "confirm", map[string]any{"link": pid}); c.Err != "" {
		t.Fatalf("confirm: %s", c.Err)
	}
}

func TestALinkEndToEndInOneProcess(t *testing.T) {
	w := newLinkWorld(t)
	jid, pid, offer := w.toDigits(t)
	js := waitState(t, jid, lsDigits)
	ps := waitState(t, pid, lsDigits)
	if js.SAS == "" || js.SAS != ps.SAS || len(js.SAS) != 6 {
		t.Fatalf("digits %q and %q", js.SAS, ps.SAS)
	}
	// the phone is quicker: its welcome and place are out while the
	// joiner's person still compares. held, never failed
	w.phoneConfirms(t, pid)
	raw, _ := devices.ParseOfferText(offer)
	toJ, _, _ := devices.Rendezvous(raw)
	end := time.Now().Add(5 * time.Second)
	for w.relay.kinds(t, toJ) != "KLA2,KLW2,KLP1" {
		if time.Now().After(end) {
			t.Fatalf("at the joiner's address: %s", w.relay.kinds(t, toJ))
		}
		time.Sleep(2 * time.Millisecond)
	}
	time.Sleep(50 * time.Millisecond)
	if s := waitState(t, jid, lsDigits, lsFailed); s.St != lsDigits {
		t.Fatalf("an early welcome ended the link: %+v", s)
	}
	if c := link(t, "confirm", map[string]any{"link": jid}); c.Err != "" {
		t.Fatalf("joiner confirm: %s", c.Err)
	}
	placed := waitState(t, jid, lsPlaced)
	if placed.Identity != hexKey(w.phone.id.pub) || placed.KeyNumber != devices.KeyNumber(w.phone.id.pub) {
		t.Fatalf("joined %s", placed.Identity)
	}
	// no contacts yet: the pool's usual eight
	if placed.Want != 8 {
		t.Fatalf("the phone wants %d bundles", placed.Want)
	}
	if placed.Device == nil || placed.Device.Key != hexKey(w.devKey.pub) || placed.Device.Reg != 4321 || placed.Device.ID < 2 {
		t.Fatalf("its place: %+v", placed.Device)
	}
	// bundles before the own list is taken: refused
	dev := *placed.Device
	bundles := map[string]any{"link": jid, "first": linkKDB1(t, dev, 1), "last": linkKDB1(t, dev, 2),
		"once": [][]byte{linkKDB1(t, dev, 10), linkKDB1(t, dev, 11)}, "made": time.Now().UnixMilli()}
	if o := link(t, "bundles", bundles); o.Err == "" {
		t.Fatal("bundles went before the own list")
	}
	// the new container, loaded as dart loads it: the identity, and its
	// device key for it
	jState := w.load(t, w.phone.id.pub, w.devKey.pub)
	w.as(jState)
	own := link(t, "own", map[string]any{"link": jid, "ident": 0})
	if own.Err != "" || len(own.Rows) == 0 {
		t.Fatalf("own: %+v", own)
	}
	if l := jState.own.Current(w.phone.id.pub); l == nil {
		t.Fatal("no own list on the device")
	} else if e, ok := l.FindKey(w.devKey.pub); !ok || e.ID != uint8(dev.ID) {
		t.Fatal("the own list does not name the device")
	}
	if again := link(t, "own", map[string]any{"link": jid, "ident": 0}); again.Err == "" {
		t.Fatal("the link's list taken twice")
	}
	if o := link(t, "bundles", bundles); o.Err != "" {
		t.Fatalf("bundles: %s", o.Err)
	}
	waitState(t, jid, lsDone)
	got := waitState(t, pid, lsBundles)
	if got.Device == nil || got.Device.Key != dev.Key || got.Device.ID != dev.ID {
		t.Fatalf("the phone got %+v", got.Device)
	}
	if w.lines.Load() < 1 {
		t.Fatal("nothing went through the door")
	}
	pt := link(t, "take", map[string]any{"link": pid})
	jt := link(t, "take", map[string]any{"link": jid})
	if pt.Err != "" || jt.Err != "" {
		t.Fatalf("take: %s %s", pt.Err, jt.Err)
	}
	if len(pt.Stream) != devices.StreamKeySize || !bytes.Equal(pt.Stream, jt.Stream) {
		t.Fatal("the stream keys differ")
	}
	if !bytes.Equal(pt.First, bundles["first"].([]byte)) || len(pt.Once) != 2 || pt.Made == 0 {
		t.Fatal("the bundles are not the device's")
	}
	// the list the phone keeps is the one the device took
	l, err := devices.ReadList(pt.List, devVerifier{w.l})
	if err != nil || !devices.SameBody(l, jState.own.Current(w.phone.id.pub)) {
		t.Fatalf("the phone's list: %v", err)
	}
	// what the phone keeps goes to its own state as it does today
	w.as(w.pState)
	var o devOut
	call(t, devSessionJSON("own_mine", jsonOf(t, map[string]any{"ident": 0, "list": pt.List})), &o)
	if o.Err != "" {
		t.Fatalf("the phone's own list: %s", o.Err)
	}
	// both runs are gone
	if s := link(t, "state", map[string]any{"link": pid}); s.Err == "" {
		t.Fatal("the phone's run outlived its take")
	}
}

// a stranger who saw the address on a relay, but not the qr, cannot reach
// the link: its events are not the link's own
func TestAStrangersAcceptNeverReachesTheRendezvous(t *testing.T) {
	w := newLinkWorld(t)
	j := link(t, "join_start", map[string]any{"key": hexKey(w.devKey.pub), "reg": 4321})
	raw, _ := devices.ParseOfferText(j.Offer)
	toJ, _, _ := devices.Rendezvous(raw)
	_, pk, _ := linkKeys(toJ)
	// a real accept, even: what decides is who sealed it
	_, accept, err := devices.AcceptOffer(raw, newDevAcct(t, w.l).id.pub, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	stranger := nostr2.GeneratePrivateKey()
	ck, _ := nip44.GenerateConversationKey(pk, stranger)
	ct, _ := nip44.Encrypt(base64.StdEncoding.EncodeToString(accept), ck)
	ev := nostr2.Event{Kind: 1059, CreatedAt: nostr2.Now(), Content: ct, Tags: nostr2.Tags{{"p", pk}}}
	ev.Sign(stranger)
	var out nostr.Event
	if err := easyjson.Unmarshal([]byte(ev.String()), &out); err != nil {
		t.Fatal(err)
	}
	w.relay.put(out)
	// and one that claims the address's own key, with no signature by it
	forged := out
	forged.PubKey, _ = nostr.PubKeyFromHex(pk)
	w.relay.put(forged)
	// sealed to the address's key by the address's key, but signed by
	// someone else: still not the link's
	sk, _, _ := linkKeys(toJ)
	own, _ := nip44.GenerateConversationKey(pk, sk)
	ct2, _ := nip44.Encrypt(base64.StdEncoding.EncodeToString(accept), own)
	ev2 := nostr2.Event{Kind: 1059, CreatedAt: nostr2.Now(), Content: ct2, Tags: nostr2.Tags{{"p", pk}}}
	ev2.Sign(stranger)
	var out2 nostr.Event
	easyjson.Unmarshal([]byte(ev2.String()), &out2)
	w.relay.put(out2)
	time.Sleep(60 * time.Millisecond)
	if s := waitState(t, j.Link, lsOffer, lsDigits, lsFailed); s.St != lsOffer {
		t.Fatalf("a stranger's accept reached the joiner: %+v", s)
	}
	if got, _ := w.relay.fetch(context.Background(), toJ); len(got) != 0 {
		t.Fatalf("the reader took %d of the stranger's events", len(got))
	}
	// the phone that scanned the code still links
	p := link(t, "link_start", map[string]any{"offer": j.Offer, "key": hexKey(w.phone.id.pub)})
	js := waitState(t, j.Link, lsDigits)
	ps := waitState(t, p.Link, lsDigits)
	if js.SAS != ps.SAS {
		t.Fatal("the real phone's digits differ")
	}
}

func TestDigitsThatDoNotMatchEndBothSides(t *testing.T) {
	w := newLinkWorld(t)
	jid, pid, offer := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	// the phone's person says no: nothing more goes out
	link(t, "end", map[string]any{"link": pid})
	raw, _ := devices.ParseOfferText(offer)
	toJ, _, _ := devices.Rendezvous(raw)
	time.Sleep(30 * time.Millisecond)
	if k := w.relay.kinds(t, toJ); k != "KLA2" {
		t.Fatalf("after a no the joiner's address holds %s", k)
	}
	// the phone cannot be confirmed past it
	if c := link(t, "confirm", map[string]any{"link": pid}); c.Err == "" {
		t.Fatal("a confirm after the end")
	}
	link(t, "end", map[string]any{"link": jid})
	if c := link(t, "confirm", map[string]any{"link": jid}); c.Err == "" {
		t.Fatal("the joiner confirmed after the end")
	}
}

func TestThePhoneConfirmsOnlyWithItsSignedList(t *testing.T) {
	w := newLinkWorld(t)
	_, pid, _ := w.toDigits(t)
	waitState(t, pid, lsDigits)
	if c := link(t, "confirm", map[string]any{"link": pid}); c.Err == "" {
		t.Fatal("confirmed with no list")
	}
	w.as(w.pState)
	o := link(t, "list", map[string]any{"link": pid, "ident": 0, "reg": 4321})
	if o.Err != "" {
		t.Fatal(o.Err)
	}
	// a signature by anyone else
	other := newDevSigner(t, w.l)
	bad, _ := other.Sign(devices.ContextList, o.Body)
	if s := link(t, "sign", map[string]any{"link": pid, "sig": bad}); s.Err != "signature" {
		t.Fatalf("another key's signature: %q", s.Err)
	}
	if c := link(t, "confirm", map[string]any{"link": pid}); c.Err == "" {
		t.Fatal("confirmed with a bad list")
	}
	// another identity of the phone cannot be linked from this run
	if o := link(t, "list", map[string]any{"link": pid, "ident": 7, "reg": 4321}); o.Err != "unknown" {
		t.Fatalf("an unknown ident: %q", o.Err)
	}
}

func TestTheDoorTakesOnlyTheWaitingLinksLines(t *testing.T) {
	w := newLinkWorld(t)
	dial := pipeDoor(nil)
	tok := strings.Repeat("ab", devices.TokenSize)
	ctx := context.Background()
	// no link waiting: a link line is junk, shut unread as today
	if err := dial(ctx, testPhoneOnion, linkLinePrefix+tok+" 0/1 AAAA"); err == nil {
		t.Fatal("a link line acked with no link waiting")
	}
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	w.phoneConfirms(t, pid)
	link(t, "confirm", map[string]any{"link": jid})
	waitState(t, jid, lsPlaced)
	r, _ := runOf(pid)
	r.mu.Lock()
	good := hex.EncodeToString(r.token[:])
	r.mu.Unlock()
	for name, line := range map[string]string{
		"another token": linkLinePrefix + tok + " 0/2 AAAA",
		"no index":      linkLinePrefix + good + " AAAA",
		"index past n":  linkLinePrefix + good + " 2/2 AAAA",
		"zero lines":    linkLinePrefix + good + " 0/0 AAAA",
		"padded index":  linkLinePrefix + good + " 00/2 AAAA",
		"too many":      linkLinePrefix + good + fmt.Sprintf(" 0/%d AAAA", linkChunksMost+1),
		"short token":   linkLinePrefix + good[:10] + " 0/2 AAAA",
		"a message":     base64.StdEncoding.EncodeToString([]byte{2, 1, 2, 3, 4, 5, 6, 7}),
	} {
		if name == "a message" {
			// a message still goes to the inbox as before
			if err := dial(ctx, testPhoneOnion, line); err != nil {
				t.Errorf("%s: %v", name, err)
			}
			continue
		}
		if err := dial(ctx, testPhoneOnion, line); err == nil {
			t.Errorf("%s acked", name)
		}
	}
	// a KLB1 that does not open ends the phone's side, and the token is
	// spent
	if err := dial(ctx, testPhoneOnion, linkLinePrefix+good+" 0/1 "+base64.StdEncoding.EncodeToString([]byte("KLB1junk"))); err != nil {
		t.Fatalf("the last line of a whole KLB1: %v", err)
	}
	if s := waitState(t, pid, lsFailed); s.Why != lsWhyBad {
		t.Fatalf("a junk KLB1: %+v", s)
	}
	if err := dial(ctx, testPhoneOnion, linkLinePrefix+good+" 0/1 AAAA"); err == nil {
		t.Fatal("a spent token acked")
	}
	mu.Lock()
	inbox = inbox[:0]
	inboxDrained()
	mu.Unlock()
}

func TestALateAcceptEndsTheJoiner(t *testing.T) {
	w := newLinkWorld(t)
	start := time.Now()
	old := linkClock
	t.Cleanup(func() { linkClock = old })
	var mu2 sync.Mutex
	at := start
	linkClock = func() time.Time { mu2.Lock(); defer mu2.Unlock(); return at }
	j := link(t, "join_start", map[string]any{"key": hexKey(w.devKey.pub), "reg": 4321})
	waitState(t, j.Link, lsOffer)
	raw, _ := devices.ParseOfferText(j.Offer)
	toJ, _, _ := devices.Rendezvous(raw)
	_, accept, err := devices.AcceptOffer(raw, w.phone.id.pub, start)
	if err != nil {
		t.Fatal(err)
	}
	mu2.Lock()
	at = start.Add(devices.LinkLife + time.Second)
	mu2.Unlock()
	w.relay.post(context.Background(), toJ, accept)
	if s := waitState(t, j.Link, lsFailed, lsDigits); s.St != lsFailed || s.Why != lsWhyTime {
		t.Fatalf("a late accept: %+v", s)
	}
}
