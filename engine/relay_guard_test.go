// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what the relay runners guarantee: the poll is one entry per event under
// that event's own tag, an event is remembered once the app has taken it,
// the since anchor stays near now, and a connection stays up whatever
// frames arrive on it.

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	ws "github.com/coder/websocket"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
	"github.com/nbd-wtf/go-nostr/nip59"
)

// a relay on the host: each req gets the stored events that match, newest
// first, then eose. publishes get an ok.
type localRelay struct {
	srv *httptest.Server

	mu     sync.Mutex
	events []nostr.Event
	conns  int
	reqs   []nostr.Filter
}

func newLocalRelay(t *testing.T) *localRelay {
	t.Helper()
	s := &localRelay{}
	s.srv = httptest.NewServer(http.HandlerFunc(s.handle))
	t.Cleanup(s.srv.Close)
	return s
}

func (s *localRelay) url() string { return "ws" + strings.TrimPrefix(s.srv.URL, "http") }

func (s *localRelay) store(evs ...nostr.Event) {
	s.mu.Lock()
	s.events = append(s.events, evs...)
	s.mu.Unlock()
}

func (s *localRelay) connCount() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.conns
}

func (s *localRelay) filters() []nostr.Filter {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]nostr.Filter(nil), s.reqs...)
}

func (s *localRelay) handle(w http.ResponseWriter, r *http.Request) {
	c, err := ws.Accept(w, r, nil)
	if err != nil {
		return
	}
	defer c.CloseNow()
	s.mu.Lock()
	s.conns++
	s.mu.Unlock()
	ctx := r.Context()
	for {
		_, data, err := c.Read(ctx)
		if err != nil {
			return
		}
		env, err := nostr.ParseMessage(string(data))
		if err != nil {
			continue
		}
		switch e := env.(type) {
		case *nostr.ReqEnvelope:
			f := e.Filters[0]
			s.mu.Lock()
			s.reqs = append(s.reqs, f)
			var match []nostr.Event
			for _, ev := range s.events {
				if f.Matches(ev) && !f.LimitZero {
					match = append(match, ev)
				}
			}
			s.mu.Unlock()
			sort.Slice(match, func(i, j int) bool { return match[i].CreatedAt > match[j].CreatedAt })
			if f.Limit > 0 && len(match) > f.Limit {
				match = match[:f.Limit]
			}
			id := e.SubscriptionID
			for _, ev := range match {
				b, _ := nostr.EventEnvelope{SubscriptionID: &id, Event: ev}.MarshalJSON()
				if c.Write(ctx, ws.MessageText, b) != nil {
					return
				}
			}
			b, _ := nostr.EOSEEnvelope(id).MarshalJSON()
			if c.Write(ctx, ws.MessageText, b) != nil {
				return
			}
		case *nostr.EventEnvelope:
			b, _ := nostr.OKEnvelope{EventID: e.Event.ID, OK: true}.MarshalJSON()
			if c.Write(ctx, ws.MessageText, b) != nil {
				return
			}
		}
	}
}

// the runners pointed at local relays, straight rather than over tor, with
// a data dir and an identity of the test's own. all put back afterwards.
func onLocalRelays(t *testing.T, urls ...string) {
	t.Helper()
	oldMode := currentMode()
	oldDir := savedDataDir
	oldPriv, oldPub := myXPriv, myXPub
	nostrMu.Lock()
	oldRelays := nostrRelays
	nostrMu.Unlock()
	t.Cleanup(func() {
		transportMode.Store(oldMode)
		savedDataDir = oldDir
		myXPriv, myXPub = oldPriv, oldPub
		nostrMu.Lock()
		nostrRelays = oldRelays
		nostrMu.Unlock()
		nostrResetClient()
		relayClearBenches()
	})
	transportMode.Store(modeFast)
	nostrResetClient()
	relayClearBenches()
	savedDataDir = t.TempDir()
	useRelays(urls...)
	myXPriv, myXPub = newIdentity(t)
}

// other relays for the runners started from here on, same data dir
func useRelays(urls ...string) {
	nostrMu.Lock()
	nostrRelays = urls
	nostrMu.Unlock()
}

func newTestXid(t *testing.T) xid {
	t.Helper()
	priv, pub := newIdentity(t)
	return xid{priv: priv, pub: pub}
}

// waits for cond, polling, and fails the test when it does not come
func eventually(t *testing.T, what string, limit time.Duration, cond func() bool) {
	t.Helper()
	end := time.Now().Add(limit)
	for time.Now().Before(end) {
		if cond() {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("%s: not within %s", what, limit)
}

// the poll as the app reads it
func pollEntries(t *testing.T) []pollEntry {
	t.Helper()
	raw := nostrPoll()
	if raw == "" {
		return nil
	}
	if strings.ContainsRune(raw, 0) {
		t.Fatal("the poll holds a nul")
	}
	var out []pollEntry
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		t.Fatalf("the poll is not a json array: %v", err)
	}
	return out
}

func inboxLen() int {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	return len(nostrInbox)
}

func inboxHas(line string) bool {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	for _, l := range nostrInbox {
		if l == line {
			return true
		}
	}
	return false
}

// an empty inbox for the test, and again after it
func freshInbox(t *testing.T) {
	t.Helper()
	clear := func() {
		nostrMu.Lock()
		nostrInbox, nostrInboxDone = nil, nil
		nostrMu.Unlock()
	}
	clear()
	t.Cleanup(clear)
}

func toEvent(t *testing.T, gw nostr2.Event) nostr.Event {
	t.Helper()
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		t.Fatal(err)
	}
	return ev
}

// an opener to our first-contact address, as a stranger's phone builds it
func openerTo(t *testing.T, from xid, fcPk, body string) nostr.Event {
	t.Helper()
	gw, err := nip17WrapFirstContactAs(from, myXPub, fcPk, body)
	if err != nil {
		t.Fatal(err)
	}
	return toEvent(t, gw)
}

// a wrap from peer to me, as the peer's phone builds it
func wrapTo(t *testing.T, peer xid, me [32]byte, body string) nostr.Event {
	t.Helper()
	gw, err := nip17WrapAs(peer, me, body)
	if err != nil {
		t.Fatal(err)
	}
	return toEvent(t, gw)
}

// a wrap from peer to me stamped at a time of the sender's choosing
func wrapToAt(t *testing.T, peer xid, me [32]byte, body string, at time.Time) nostr.Event {
	t.Helper()
	sndSk, sndPk, err := nip17DeriveRoleAs(peer, me, nip17SndInfo, hex.EncodeToString(peer.pub[:]))
	if err != nil {
		t.Fatal(err)
	}
	_, rcvPk, err := nip17DeriveRoleAs(peer, me, nip17RcvInfo, hex.EncodeToString(me[:]))
	if err != nil {
		t.Fatal(err)
	}
	ck, err := nip44.GenerateConversationKey(rcvPk, sndSk)
	if err != nil {
		t.Fatal(err)
	}
	rumor := nostr2.Event{Kind: 14, CreatedAt: nostr2.Now(), PubKey: sndPk, Content: body,
		Tags: nostr2.Tags{{"p", rcvPk}}}
	gw, err := nip59.GiftWrap(rumor, rcvPk,
		func(pt string) (string, error) { return nip44.Encrypt(pt, ck) },
		func(e *nostr2.Event) error { return e.Sign(sndSk) },
		func(e *nostr2.Event) { e.CreatedAt = nostr2.Timestamp(at.Unix()) })
	if err != nil {
		t.Fatal(err)
	}
	return toEvent(t, gw)
}

// a validly signed wrap to an address that opens for nobody
func unopenedTo(t *testing.T, rcv string, at time.Time, content string) nostr.Event {
	t.Helper()
	ev := nostr.Event{Kind: 1059, CreatedAt: nostr.Timestamp(at.Unix()),
		Tags: nostr.Tags{{"p", rcv}}, Content: content}
	if err := ev.Sign(nostr.Generate()); err != nil {
		t.Fatal(err)
	}
	return ev
}

func TestPollIsOneEntryPerEvent(t *testing.T) {
	lines := []string{
		"firstcontact|AAAA",
		"firstcontact|two\nlines",
		`room:ab:cd|{"t":"x"}`,
		"abc|with\rreturn",
		"abc|with\x00nul",
		"abc|a|b",
		"no tag at all",
		"abc|",
	}
	raw := pollJSON(lines)
	if strings.ContainsAny(raw, "\n\r\x00") {
		t.Fatalf("the poll itself holds a line break or a nul: %q", raw)
	}
	var got []pollEntry
	if err := json.Unmarshal([]byte(raw), &got); err != nil {
		t.Fatal(err)
	}
	want := []pollEntry{{"firstcontact", "AAAA"}, {"room:ab:cd", `{"t":"x"}`}, {"abc", "a|b"}, {"abc", ""}}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("poll entries %q, want %q", got, want)
	}
	if pollJSON(nil) != "" || pollJSON([]string{"x|a\nb"}) != "" {
		t.Fatal("a poll with nothing to hand over is empty")
	}
}

// content with a line break or a nul is dropped, each event is one entry
// under its own tag, and every event behind a dropped one still arrives
func TestPollCarriesEachEventUnderItsOwnTag(t *testing.T) {
	relay := newLocalRelay(t)
	onLocalRelays(t, relay.url())
	freshInbox(t)
	_, fcPk, err := nip17FirstContactKeys(0)
	if err != nil {
		t.Fatal(err)
	}
	stranger := newTestXid(t)
	friend := newTestXid(t)
	friendTag := hex.EncodeToString(friend.pub[:])
	for _, body := range []string{
		"one\ntwo",
		"three\x00four",
		"five\rsix",
		"hello",
	} {
		relay.store(openerTo(t, stranger, fcPk, body))
	}
	_, rcv, err := nip17RcvAddress(friend.pub)
	if err != nil {
		t.Fatal(err)
	}
	relay.store(wrapTo(t, friend, myXPub, "from a friend"))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunnerMode(ctx, "firstcontact", [32]byte{}, fcPk, true, 0)
	go nostrSubscribeRunner(ctx, friendTag, friend.pub, rcv)
	eventually(t, "every event opened", 10*time.Second, func() bool { return inboxLen() == 5 })
	got := pollEntries(t)
	sort.Slice(got, func(i, j int) bool { return got[i].T < got[j].T })
	want := []pollEntry{{friendTag, "from a friend"}, {"firstcontact", "hello"}}
	sort.Slice(want, func(i, j int) bool { return want[i].T < want[j].T })
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("the app got %q, want %q", got, want)
	}
}

// an event that opened is remembered only once the app has taken it, so a
// restart before then fetches it again, and one after does not
func TestEventsAreRememberedOnceHandedOver(t *testing.T) {
	relay := newLocalRelay(t)
	onLocalRelays(t, relay.url())
	freshInbox(t)
	peer := newTestXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	ev := wrapTo(t, peer, myXPub, "hi")
	relay.store(ev)
	seenPath := savedDataDir + "/nostr_seen_" + rcv[:16]
	holds := func() bool {
		b, _ := os.ReadFile(seenPath)
		return strings.Contains(string(b), ev.ID.Hex())
	}

	ctx1, cancel1 := context.WithCancel(context.Background())
	go nostrSubscribeRunner(ctx1, tag, peer.pub, rcv)
	eventually(t, "the event opened", 10*time.Second, func() bool { return inboxLen() == 1 })
	if holds() {
		t.Fatal("remembered before the app took it")
	}
	// a restart: the process and its inbox are gone
	cancel1()
	nostrMu.Lock()
	nostrInbox, nostrInboxDone = nil, nil
	nostrMu.Unlock()

	ctx2, cancel2 := context.WithCancel(context.Background())
	go nostrSubscribeRunner(ctx2, tag, peer.pub, rcv)
	eventually(t, "the event came again", 10*time.Second, func() bool { return inboxLen() == 1 })
	if got := pollEntries(t); len(got) != 1 || got[0].C != "hi" {
		t.Fatalf("the app got %q", got)
	}
	if !holds() {
		t.Fatal("not remembered after the app took it")
	}
	cancel2()

	ctx3, cancel3 := context.WithCancel(context.Background())
	defer cancel3()
	go nostrSubscribeRunner(ctx3, tag, peer.pub, rcv)
	eventually(t, "the relay was asked again", 10*time.Second, func() bool { return len(relay.filters()) >= 3 })
	time.Sleep(time.Second)
	if n := inboxLen(); n != 0 {
		t.Fatalf("%d events handed over twice", n)
	}
}

// the anchor never moves past now and a few minutes: an event stamped far
// ahead, opened or not, leaves the next window over what relays hold today
func TestAnchorStaysNearNow(t *testing.T) {
	first := newLocalRelay(t)
	onLocalRelays(t, first.url())
	freshInbox(t)
	peer := newTestXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	ahead := time.Now().Add(47 * time.Hour)
	first.store(unopenedTo(t, rcv, ahead, "x"))
	first.store(wrapToAt(t, peer, myXPub, "stamped ahead", ahead))
	lastPath := savedDataDir + "/nostr_last_" + rcv[:16]
	anchor := func() int64 {
		b, _ := os.ReadFile(lastPath)
		v, _ := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64)
		return v
	}

	ctx1, cancel1 := context.WithCancel(context.Background())
	go nostrSubscribeRunner(ctx1, tag, peer.pub, rcv)
	eventually(t, "the anchor moved", 10*time.Second, func() bool { return anchor() > 0 })
	cancel1()
	if lim := time.Now().Add(anchorSlack + 5*time.Second).Unix(); anchor() > lim {
		t.Fatalf("the anchor went %ds past now", anchor()-time.Now().Unix())
	}
	pollEntries(t)

	second := newLocalRelay(t)
	second.store(wrapTo(t, peer, myXPub, "sent today"))
	useRelays(second.url())
	ctx2, cancel2 := context.WithCancel(context.Background())
	defer cancel2()
	go nostrSubscribeRunner(ctx2, tag, peer.pub, rcv)
	eventually(t, "today's wrap", 8*time.Second, func() bool { return inboxHas(tag + "|sent today") })
}

// only events that opened move the anchor
func TestAnchorMovesOnlyOnEventsThatOpen(t *testing.T) {
	relay := newLocalRelay(t)
	onLocalRelays(t, relay.url())
	freshInbox(t)
	peer := newTestXid(t)
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	relay.store(unopenedTo(t, rcv, time.Now(), "x"))
	lastPath := savedDataDir + "/nostr_last_" + rcv[:16]
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, rcv)
	eventually(t, "the catch-up ended", 10*time.Second, func() bool {
		_, err := os.Stat(lastPath)
		return err == nil
	})
	b, _ := os.ReadFile(lastPath)
	if v := strings.TrimSpace(string(b)); v != "0" {
		t.Fatalf("the anchor is %s with nothing opened", v)
	}
}

// an anchor is never read back later than now, and the file follows
func TestAnchorIsNeverLaterThanNow(t *testing.T) {
	relay := newLocalRelay(t)
	onLocalRelays(t, relay.url())
	freshInbox(t)
	peer := newTestXid(t)
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	lastPath := savedDataDir + "/nostr_last_" + rcv[:16]
	ahead := time.Now().Add(47 * time.Hour).Unix()
	if err := os.WriteFile(lastPath, []byte(strconv.FormatInt(ahead, 10)), 0600); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, rcv)
	eventually(t, "the anchor put back", 10*time.Second, func() bool {
		b, _ := os.ReadFile(lastPath)
		v, _ := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64)
		return v <= time.Now().Unix()
	})
	reqs := relay.filters()
	if len(reqs) == 0 {
		t.Fatal("the relay was never asked")
	}
	if since := int64(reqs[0].Since); since > time.Now().Unix()-12*3600+60 {
		t.Fatalf("asked from %ds ahead of the usual window", since-(time.Now().Unix()-12*3600))
	}
}

func TestAnchorStampAndNow(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	if got := anchorStamp(nostr.Timestamp(now.Unix()-60), now); int64(got) != now.Unix()-60 {
		t.Fatalf("a past stamp moved to %d", got)
	}
	if got := anchorStamp(nostr.Timestamp(now.Add(47*time.Hour).Unix()), now); int64(got) != now.Add(anchorSlack).Unix() {
		t.Fatalf("a stamp far ahead became %d", got)
	}
	if got := anchorNow(now.Unix()+1, now); got != now.Unix() {
		t.Fatalf("a loaded anchor ahead of now became %d", got)
	}
	if got := anchorNow(now.Unix()-1, now); got != now.Unix()-1 {
		t.Fatalf("a loaded anchor before now became %d", got)
	}
}

// every prefix of a valid frame and ids of every length are passed over, and
// the event behind them arrives on the same connection
func TestConnectionStaysUpWhateverTheFrames(t *testing.T) {
	freshInbox(t)
	onLocalRelays(t)
	peer := newTestXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	real := wrapTo(t, peer, myXPub, "still here")
	var conns atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := ws.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer c.CloseNow()
		c.SetReadLimit(1 << 20)
		conns.Add(1)
		for {
			_, data, err := c.Read(r.Context())
			if err != nil {
				return
			}
			env, err := nostr.ParseMessage(string(data))
			if err != nil {
				continue
			}
			e, ok := env.(*nostr.ReqEnvelope)
			if !ok {
				continue
			}
			sid := e.SubscriptionID
			valid, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: real}.MarshalJSON()
			var frames []string
			for i := 1; i < len(valid); i++ {
				frames = append(frames, string(valid[:i]))
			}
			for n := 0; n <= 130; n++ {
				id := strings.Repeat("0", n)
				frames = append(frames,
					`["OK","`+id+`",true,""]`,
					`["EVENT","`+sid+`",{"id":"`+id+`","pubkey":"`+id+`"}]`,
				)
			}
			for _, lbl := range []string{"EVENT", "OK", "EOSE", "CLOSED", "NOTICE", "AUTH", "COUNT"} {
				frames = append(frames, `["`+lbl+`"]`, `["`+lbl+`",`, `"`+lbl+`"`, `"`+lbl+`""`+sid)
			}
			for _, f := range frames {
				if c.Write(r.Context(), ws.MessageText, []byte(f)) != nil {
					return
				}
			}
			c.Write(r.Context(), ws.MessageText, valid)
			b, _ := nostr.EOSEEnvelope(sid).MarshalJSON()
			c.Write(r.Context(), ws.MessageText, b)
		}
	}))
	defer srv.Close()
	useRelays("ws" + strings.TrimPrefix(srv.URL, "http"))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	eventually(t, "the valid event", 20*time.Second, func() bool { return inboxHas(tag + "|still here") })
	if n := conns.Load(); n != 1 {
		t.Fatalf("%d connections, want 1", n)
	}
}
