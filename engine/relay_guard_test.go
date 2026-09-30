// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what the relay runners guarantee: the poll is one entry per event under
// that event's own tag, an event counts under its own id, the since anchor
// stays near now, what a runner remembers stays bounded, a relay that keeps
// dropping is redialled slower, and a connection stays up whatever frames
// arrive on it.

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"sort"
	"strconv"
	"strings"
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

// other relays for the runners started from here on, same data dir
func useRelays(urls ...string) {
	nostrMu.Lock()
	nostrRelays = urls
	nostrMu.Unlock()
}

// an opener to our first-contact address, as a stranger's phone builds it
func openerTo(t *testing.T, from xid, fcPk, body string) nostr.Event {
	t.Helper()
	gw, err := nip17WrapFirstContactAs(from, myXPub, fcPk, body)
	if err != nil {
		t.Fatal(err)
	}
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		t.Fatal(err)
	}
	return ev
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
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		t.Fatal(err)
	}
	return ev
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

func randomID(t *testing.T) nostr.ID {
	var id nostr.ID
	if _, err := rand.Read(id[:]); err != nil {
		t.Fatal(err)
	}
	return id
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
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	_, fcPk, err := nip17FirstContactKeys(0)
	if err != nil {
		t.Fatal(err)
	}
	stranger := newXid(t)
	friend := newXid(t)
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
	waitFor(t, "every event opened", 10*time.Second, func() bool { return inboxLen() == 5 })
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
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	peer := newXid(t)
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
	waitFor(t, "the event opened", 10*time.Second, func() bool { return inboxLen() == 1 })
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
	waitFor(t, "the event came again", 10*time.Second, func() bool { return inboxLen() == 1 })
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
	waitFor(t, "the relay was asked again", 10*time.Second, func() bool { return len(relay.snapshot()) >= 3 })
	time.Sleep(time.Second)
	if n := inboxLen(); n != 0 {
		t.Fatalf("%d events handed over twice", n)
	}
}

// an event counts under its own id, the one its body hashes to, and every
// event arrives from whichever relay holds it
func TestEventsCountUnderTheirOwnID(t *testing.T) {
	quick := newRelayStandIn(t, 0)
	slow := newRelayStandIn(t, 0)
	slow.reqDelay = 500 * time.Millisecond
	useStandIns(t, modeFast, nil, slow, quick)
	freshInbox(t)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	real := wrapTo(t, peer, myXPub, "the real one")
	other := unopenedTo(t, rcv, real.CreatedAt.Time(), "other")
	if !other.VerifySignature() {
		t.Fatal("a signed event should verify")
	}
	other.ID = real.ID
	if other.VerifySignature() {
		t.Fatal("an event whose id field is not its own id verified")
	}
	quick.store(other)
	slow.store(real)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	waitFor(t, "the real event", 8*time.Second, func() bool { return inboxHas(tag + "|the real one") })
}

// the anchor never moves past now and a few minutes: an event stamped far
// ahead, opened or not, leaves the next window over what relays hold today
func TestAnchorStaysNearNow(t *testing.T) {
	first := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, first)
	freshInbox(t)
	peer := newXid(t)
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
	waitFor(t, "the anchor moved", 10*time.Second, func() bool { return anchor() > 0 })
	cancel1()
	if lim := time.Now().Add(anchorSlack + 5*time.Second).Unix(); anchor() > lim {
		t.Fatalf("the anchor went %ds past now", anchor()-time.Now().Unix())
	}
	pollEntries(t)

	second := newRelayStandIn(t, 0)
	second.store(wrapTo(t, peer, myXPub, "sent today"))
	useRelays(second.url())
	ctx2, cancel2 := context.WithCancel(context.Background())
	defer cancel2()
	go nostrSubscribeRunner(ctx2, tag, peer.pub, rcv)
	waitFor(t, "today's wrap", 8*time.Second, func() bool { return inboxHas(tag + "|sent today") })
}

// only events that opened move the anchor
func TestAnchorMovesOnlyOnEventsThatOpen(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	peer := newXid(t)
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	relay.store(unopenedTo(t, rcv, time.Now(), "x"))
	lastPath := savedDataDir + "/nostr_last_" + rcv[:16]
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, rcv)
	waitFor(t, "the catch-up ended", 10*time.Second, func() bool {
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
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	peer := newXid(t)
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
	waitFor(t, "the anchor put back", 10*time.Second, func() bool {
		b, _ := os.ReadFile(lastPath)
		v, _ := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64)
		return v <= time.Now().Unix()
	})
	conns := relay.snapshot()
	if len(conns) == 0 || len(conns[0].reqs) == 0 {
		t.Fatal("the relay was never asked")
	}
	if since := int64(conns[0].reqs[0].filter.Since); since > time.Now().Unix()-12*3600+60 {
		t.Fatalf("asked from %ds ahead of the usual window", since-(time.Now().Unix()-12*3600))
	}
}

func TestSeenStaysBounded(t *testing.T) {
	path := t.TempDir() + "/nostr_seen_x"
	s := loadSeen(path)
	var ids []nostr.ID
	for i := 0; i < seenKeep+700; i++ {
		id := randomID(t)
		ids = append(ids, id)
		if !s.claim(id) {
			t.Fatal("a new id was taken for a repeat")
		}
		if s.claim(id) {
			t.Fatal("an id being opened was not a repeat")
		}
		s.handedOver([]nostr.ID{id})
	}
	if n := s.opened.len(); n > seenKeep {
		t.Fatalf("%d ids held, the cap is %d", n, seenKeep)
	}
	if s.opened.has(ids[0]) || !s.opened.has(ids[len(ids)-1]) {
		t.Fatal("the oldest ids go first")
	}
	newest := ids[len(ids)-1]
	for i := 0; i < 5*seenUnopenedKeep; i++ {
		id := randomID(t)
		s.claim(id)
		s.notOpened(id)
	}
	if !s.opened.has(newest) {
		t.Fatal("an id of an event that opened was not kept")
	}
	if n := s.unopened.len(); n > seenUnopenedKeep {
		t.Fatalf("%d ids that did not open held, the cap is %d", n, seenUnopenedKeep)
	}
	b, _ := os.ReadFile(path)
	if n := strings.Count(string(b), "\n"); n > seenFileMax {
		t.Fatalf("the file holds %d lines, the cap is %d", n, seenFileMax)
	}
	r := loadSeen(path)
	if r.claim(newest) {
		t.Fatal("a restart forgot an id it kept")
	}
	if r.opened.len() > seenKeep || r.unopened.len() > seenUnopenedKeep {
		t.Fatal("a restart read back more than the caps")
	}
}

// a file from before the cap is cut down on the next start
func TestSeenFileIsCutOnLoad(t *testing.T) {
	path := t.TempDir() + "/nostr_seen_x"
	var sb strings.Builder
	for i := 0; i < 2*seenFileMax; i++ {
		id := randomID(t)
		sb.WriteString(id.Hex() + "\n")
	}
	if err := os.WriteFile(path, []byte(sb.String()), 0600); err != nil {
		t.Fatal(err)
	}
	loadSeen(path)
	b, _ := os.ReadFile(path)
	if n := strings.Count(string(b), "\n"); n > seenKeep {
		t.Fatalf("%d lines kept, the cap is %d", n, seenKeep)
	}
}

// one connection that brings more events than the cap leaves a bounded file
func TestSeenFileBoundedWithinOneConnection(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	peer := newXid(t)
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	sk := nostr.Generate()
	n := seenFileMax + 1000
	for i := 0; i < n; i++ {
		ev := nostr.Event{Kind: 1059, CreatedAt: nostr.Timestamp(now.Unix() - int64(i)),
			Tags: nostr.Tags{{"p", rcv}}, Content: strconv.Itoa(i)}
		if err := ev.Sign(sk); err != nil {
			t.Fatal(err)
		}
		relay.store(ev)
	}
	seenPath := savedDataDir + "/nostr_seen_" + rcv[:16]
	var most int
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, rcv)
	end := time.Now().Add(30 * time.Second)
	for time.Now().Before(end) {
		b, _ := os.ReadFile(seenPath)
		l := strings.Count(string(b), "\n")
		if l > most {
			most = l
		}
		relay.mu.Lock()
		sent := relay.resent
		relay.mu.Unlock()
		if sent >= n && l > 0 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if most == 0 {
		t.Fatal("nothing was remembered")
	}
	if most > seenFileMax {
		t.Fatalf("the file reached %d lines, the cap is %d", most, seenFileMax)
	}
}

func TestKickAnswersSpreadPerSocket(t *testing.T) {
	var lo, hi time.Duration = kickSpread, 0
	for i := 0; i < 500; i++ {
		d := kickDelay()
		if d < 0 || d >= kickSpread {
			t.Fatalf("a delay of %s is outside the spread", d)
		}
		lo, hi = min(lo, d), max(hi, d)
	}
	if lo > kickSpread/10 || hi < kickSpread*9/10 {
		t.Fatalf("delays from %s to %s do not cover the spread", lo, hi)
	}
	deaf := 4 * time.Minute
	lo, hi = deaf*2, 0
	for i := 0; i < 500; i++ {
		d := quietFor(deaf)
		if d < deaf*3/4 || d > deaf*5/4 {
			t.Fatalf("a quiet timer of %s is outside a quarter either way", d)
		}
		lo, hi = min(lo, d), max(hi, d)
	}
	if hi-lo < deaf/3 {
		t.Fatalf("quiet timers only spread from %s to %s", lo, hi)
	}
}

// what a socket asks when it checks it is alive looks like what it asks
// anyway: its own address and kind, nothing stored, nothing older than now
func TestProbeLooksLikeTheSocketsOwnRequest(t *testing.T) {
	now := time.Now()
	f := probeFilter("ab", now)
	b, err := easyjson.Marshal(f)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"kinds":[1059],"since":` + strconv.FormatInt(now.Unix(), 10) + `,"limit":0,"#p":["ab"]}`
	if string(b) != want {
		t.Fatalf("probe %s, want %s", b, want)
	}

	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	old := kickSpread
	kickSpread = 3 * time.Second
	defer func() { kickSpread = old }()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	l := startLanes(t, ctx, 3, 1)
	subs := l.subs()
	waitFor(t, "every subscription connected", 15*time.Second, func() bool {
		n := 0
		for _, c := range relay.snapshot() {
			if c.closed.IsZero() && len(c.reqs) > 0 {
				n++
			}
		}
		return n == subs
	})
	kicked := time.Now()
	kickRelays()
	waitFor(t, "every socket asked", 15*time.Second, func() bool {
		for _, c := range relay.snapshot() {
			if c.closed.IsZero() && len(c.reqs) < 2 {
				return false
			}
		}
		return true
	})
	var first, last time.Time
	for _, c := range relay.snapshot() {
		if len(c.reqs) < 2 {
			continue
		}
		own := c.reqs[0].filter.Tags["p"]
		p := c.reqs[1]
		if !p.filter.LimitZero || len(p.filter.IDs) > 0 || !reflect.DeepEqual(p.filter.Tags["p"], own) {
			t.Errorf("a probe asked %v on a socket that listens for %v", p.filter, own)
		}
		if p.at.Before(kicked) {
			continue
		}
		if first.IsZero() || p.at.Before(first) {
			first = p.at
		}
		if p.at.After(last) {
			last = p.at
		}
	}
	if spread := last.Sub(first); spread < 500*time.Millisecond {
		t.Fatalf("%d sockets answered a kick within %s", subs, spread)
	}
}

func TestYoungDropWaitGrows(t *testing.T) {
	got := []time.Duration{}
	for n := 1; n <= 8; n++ {
		got = append(got, youngDropWait(5*time.Second, n, false))
	}
	want := []time.Duration{5 * time.Second, 10 * time.Second, 20 * time.Second, 40 * time.Second,
		80 * time.Second, 160 * time.Second, 5 * time.Minute, 5 * time.Minute}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("waits %v, want %v", got, want)
	}
	if d := youngDropWait(2*time.Second, 10, true); d != ownRelayCeiling {
		t.Fatalf("our own relay waits %s at most, got %s", ownRelayCeiling, d)
	}
}

// a relay that closes every connection right after answering is redialled
// at a growing interval, not at the usual pace for ever
func TestRelayThatDropsYoungIsRedialledSlower(t *testing.T) {
	var conns atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := ws.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer c.CloseNow()
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
			if e, ok := env.(*nostr.ReqEnvelope); ok {
				b, _ := nostr.EOSEEnvelope(e.SubscriptionID).MarshalJSON()
				c.Write(r.Context(), ws.MessageText, b)
				time.Sleep(50 * time.Millisecond)
				c.Close(ws.StatusNormalClosure, "")
				return
			}
		}
	}))
	defer srv.Close()
	useStandIns(t, modeFast, nil)
	useRelays("ws" + strings.TrimPrefix(srv.URL, "http"))
	freshInbox(t)
	peer := newXid(t)
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	// index 0, our own relay: the shortest pause and the lowest ceiling
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, rcv)
	time.Sleep(15 * time.Second)
	// 2s, 4s, 8s between them: four in fifteen seconds, where a fixed pace
	// would have made seven
	if n := conns.Load(); n > 5 {
		t.Fatalf("%d connections in 15s to a relay that drops each one", n)
	}
}

// every prefix of a valid frame and ids of every length are passed over, and
// the event behind them arrives on the same connection
func TestConnectionStaysUpWhateverTheFrames(t *testing.T) {
	freshInbox(t)
	useStandIns(t, modeFast, nil)
	peer := newXid(t)
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
	waitFor(t, "the valid event", 20*time.Second, func() bool { return inboxHas(tag + "|still here") })
	if n := conns.Load(); n != 1 {
		t.Fatalf("%d connections, want 1", n)
	}
}

// the exports that derive from the identity refuse while none is loaded
func TestNothingDerivesWithoutAnIdentity(t *testing.T) {
	mu.Lock()
	oldPriv, oldPub := myXPriv, myXPub
	myXPriv, myXPub = [32]byte{}, [32]byte{}
	mu.Unlock()
	defer func() {
		mu.Lock()
		myXPriv, myXPub = oldPriv, oldPub
		mu.Unlock()
	}()
	peer := newXid(t)
	checks := map[string]error{}
	_, _, checks["first contact"] = nip17FirstContactKeys(0)
	_, _, checks["receive address"] = nip17RcvAddress(peer.pub)
	_, _, checks["role"] = nip17DeriveRole(peer.pub, nip17RcvInfo, "x")
	_, checks["wrap"] = nip17Wrap(peer.pub, "x")
	_, checks["first contact wrap"] = nip17WrapFirstContact(peer.pub, strings.Repeat("ab", 32), "x")
	_, checks["unwrap"] = nip17Unwrap(peer.pub, nostr2.Event{})
	for what, err := range checks {
		if err != errNoIdentity {
			t.Errorf("%s: got %v before an identity was loaded", what, err)
		}
	}
}

func TestAckIsExactlyTheDoorsAnswer(t *testing.T) {
	for in, ok := range map[string]bool{
		"ack\n":         true,
		"ack\nand more": true,
		"ack":           false,
		"":              false,
		"nack\n":        false,
		"ACK\n":         false,
		"ok\n":          false,
	} {
		if err := readAck(strings.NewReader(in)); (err == nil) != ok {
			t.Errorf("%q: ack=%v, want %v", in, err == nil, ok)
		}
	}
	// a far end that never stops sending is read no further than an ack
	r := &countingReader{}
	if readAck(r) == nil {
		t.Fatal("an endless stream is not an ack")
	}
	if r.n > len(doorAck) {
		t.Fatalf("read %d bytes looking for an ack", r.n)
	}
}

type countingReader struct{ n int }

func (c *countingReader) Read(p []byte) (int, error) {
	for i := range p {
		p[i] = 'x'
	}
	c.n += len(p)
	return len(p), nil
}

// the relay library's own log lines go through the engine's gate
func TestLibraryLogsFollowTheGate(t *testing.T) {
	var buf bytes.Buffer
	old := log.Writer()
	log.SetOutput(&buf)
	oldOn := atomic.LoadInt32(&debugOn)
	defer func() {
		log.SetOutput(old)
		atomic.StoreInt32(&debugOn, oldOn)
	}()
	atomic.StoreInt32(&debugOn, 0)
	nostr.InfoLogger.Printf("quiet line")
	if buf.Len() != 0 {
		t.Fatalf("logged with the gate shut: %q", buf.String())
	}
	atomic.StoreInt32(&debugOn, 1)
	nostr.InfoLogger.Printf("open line")
	if !strings.Contains(buf.String(), "open line") {
		t.Fatalf("nothing logged with the gate open: %q", buf.String())
	}
}

// once the wipe holds the engine, subscriptions are gone and nothing more is
// written into the data dir
func TestWipeHoldStopsRunnersAndWrites(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	statusMu.RLock()
	oldStatus := torStatus
	statusMu.RUnlock()
	t.Cleanup(func() {
		engineHeld.Store(false)
		atomic.StoreInt32(&torPaused, 0)
		setStatus(oldStatus)
	})
	peer := newXid(t)
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	nostrMu.Lock()
	nostrSubs["hold-test"] = cancel
	nostrMu.Unlock()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, rcv)
	waitFor(t, "the runner listening", 10*time.Second, func() bool { return len(relay.snapshot()) == 1 })

	if r := wipeHold(); r != "ok" {
		t.Fatalf("hold: %s", r)
	}
	nostrMu.Lock()
	left := len(nostrSubs)
	nostrMu.Unlock()
	if left != 0 {
		t.Fatalf("%d subscriptions left running", left)
	}
	waitFor(t, "the connection closed", 5*time.Second, func() bool {
		c := relay.snapshot()[0]
		return !c.closed.IsZero()
	})
	path := savedDataDir + "/nostr_seen_held"
	s := loadSeen(path)
	id := randomID(t)
	s.claim(id)
	s.notOpened(id)
	s.handedOver([]nostr.ID{randomID(t)})
	if _, err := os.Stat(path); err == nil {
		t.Fatal("written after the hold")
	}
	entries, _ := os.ReadDir(savedDataDir)
	before := len(entries)
	time.Sleep(time.Second)
	entries, _ = os.ReadDir(savedDataDir)
	if len(entries) != before {
		t.Fatal("files appeared after the hold")
	}
}
