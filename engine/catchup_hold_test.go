// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	ws "github.com/coder/websocket"
	"github.com/halo/engine/catchup"
)

// a walk began three hours ago and has stepped over a stretch it walked
// then. a wrap sent since is stamped inside that stretch, below what the
// newest wraps would move the anchor to. the connection that finishes the
// walk steps over it; the next one asks from before the walk began and gets
// it, and the anchor file never passes it.
func TestWrapStampedIntoAWalkedStretchArrives(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	oldSpread := kickSpread
	kickSpread = 0
	defer func() { kickSpread = oldSpread }()
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	ck := catchupKey(relay.url(), rcv)
	clear := func() { forgetCatchup(ck) }
	clear()
	t.Cleanup(clear)

	now := time.Now()
	ts := func(d time.Duration) nostr.Timestamp { return nostr.Timestamp(now.Add(d).Unix()) }
	began := ts(-3 * time.Hour)
	lastPath := savedDataDir + "/nostr_last_" + rcv[:16]
	anchor := func() int64 {
		b, _ := os.ReadFile(lastPath)
		v, _ := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64)
		return v
	}
	if err := os.WriteFile(lastPath, []byte(strconv.FormatInt(int64(ts(-4*time.Hour)), 10)), 0600); err != nil {
		t.Fatal(err)
	}
	catchupMu.Lock()
	catchupMarks[ck] = catchup.Mark{Top: ts(-time.Hour), Cursor: ts(-15 * time.Hour)}
	catchupHolds[ck] = catchup.Hold{Floor: ts(-4 * time.Hour), Began: began}
	catchupMu.Unlock()

	for i := 1; i <= 6; i++ {
		relay.store(wrapToAt(t, peer, myXPub, "new "+strconv.Itoa(i), now.Add(-time.Duration(i)*10*time.Minute)))
	}
	relay.store(wrapToAt(t, peer, myXPub, "stamped back", now.Add(-12*time.Hour-30*time.Minute)))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	waitFor(t, "the walk finished", 10*time.Second, func() bool {
		return inboxLen() == 6 && !catchupMarkOf(ck).Started()
	})
	if inboxHas(tag + "|stamped back") {
		t.Fatal("the walk that stepped over the stretch got it after all, so this proves nothing")
	}
	if h := catchupHoldOf(ck); h.Floor != began {
		t.Fatalf("after the walk the relay holds %+v, want the walk's start %d", h, began)
	}
	if a := anchor(); a > int64(began) {
		t.Fatalf("the anchor file went to %d, past the walk's start %d", a, began)
	}

	relay.dropAll()
	kickUntil(t, "the next connection", func() bool {
		conns := relay.snapshot()
		return len(conns) >= 2 && len(conns[1].reqs) > 0
	})
	waitFor(t, "the wrap stamped back", 10*time.Second, func() bool { return inboxHas(tag + "|stamped back") })
	if since := relay.snapshot()[1].reqs[0].filter.Since; since > began-12*3600 {
		t.Fatalf("the next connection asked from %d, after %d", since, began-12*3600)
	}
	waitFor(t, "the hold let go", 5*time.Second, func() bool { return !catchupHoldOf(ck).Held() })
	// the file stays at or below what the app has not kept yet
	if a := anchor(); a > int64(ts(-12*time.Hour-30*time.Minute)) {
		t.Fatalf("the anchor file went to %d, past a wrap the app has not kept", a)
	}
	waitFor(t, "the app kept everything", 5*time.Second, func() bool {
		pollAcked(time.Now())
		return inboxLen() == 0
	})
	if a := anchor(); a < int64(ts(-11*time.Minute)) {
		t.Fatalf("with nothing owed the anchor file stayed at %d", a)
	}
}

// our relay holds a backlog only it has: slices stamped nine to nineteen
// hours back, below an anchor file eight hours back. a text an hour old is
// on both relays.
type halfWay struct {
	t           *testing.T
	ours, other *relayStandIn
	peer        xid
	tag, rcv    string
	began       int64
	text        nostr.Event
	// what the app has taken from the poll so far
	got map[string]bool
}

const halfWaySlices = 150

func newHalfWay(t *testing.T) *halfWay {
	h := &halfWay{t: t, ours: newRelayStandIn(t, 0), other: newRelayStandIn(t, 0), got: map[string]bool{}}
	useStandIns(t, modeFast, nil, h.ours, h.other)
	freshInbox(t)
	oldSpread := kickSpread
	kickSpread = 0
	t.Cleanup(func() { kickSpread = oldSpread })
	h.peer = newXid(t)
	h.tag = hex.EncodeToString(h.peer.pub[:])
	h.rcv = mustRcv(t, h.peer)
	h.clean()
	t.Cleanup(h.clean)
	now := time.Now()
	h.began = now.Add(-8 * time.Hour).Unix()
	if err := os.WriteFile(h.lastPath(), []byte(strconv.FormatInt(h.began, 10)), 0600); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < halfWaySlices; i++ {
		h.ours.store(wrapToAt(t, h.peer, myXPub, "slice "+strconv.Itoa(i),
			now.Add(-9*time.Hour-time.Duration(i)*4*time.Minute)))
	}
	h.text = wrapToAt(t, h.peer, myXPub, "text", now.Add(-time.Hour))
	h.ours.store(h.text)
	h.other.store(h.text)
	return h
}

func (h *halfWay) lastPath() string { return savedDataDir + "/nostr_last_" + h.rcv[:16] }

func (h *halfWay) anchor() int64 {
	b, _ := os.ReadFile(h.lastPath())
	v, _ := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64)
	return v
}

func (h *halfWay) key(r *relayStandIn) string { return catchupKey(r.url(), h.rcv) }

// what a process keeps in memory, gone
func (h *halfWay) clean() { forgetCatchup(h.key(h.ours), h.key(h.other)) }

// what the process keeps in memory for these catch-up keys, gone
func forgetCatchup(keys ...string) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	for _, k := range keys {
		delete(catchupMarks, k)
		delete(catchupHolds, k)
		delete(catchupFreed, k)
	}
}

// the poll, as the app takes it
func (h *halfWay) poll() {
	for _, e := range pollEntries(h.t) {
		h.got[e.C] = true
	}
}

func (h *halfWay) waitAll(what string, bodies ...string) {
	h.t.Helper()
	for i := 0; i < halfWaySlices; i++ {
		bodies = append(bodies, "slice "+strconv.Itoa(i))
	}
	waitFor(h.t, what, 20*time.Second, func() bool {
		h.poll()
		for _, b := range bodies {
			if !h.got[b] {
				return false
			}
		}
		return true
	})
}

func (h *halfWay) delays(oursUp, oursAnswer, otherUp time.Duration) {
	h.ours.mu.Lock()
	h.ours.upgradeDelay, h.ours.reqDelay = oursUp, oursAnswer
	h.ours.mu.Unlock()
	h.other.mu.Lock()
	h.other.upgradeDelay = otherUp
	h.other.mu.Unlock()
}

// otherFirst: our relay connects only once the other relay has answered, as
// an onion does next to an exit. else ours reads the anchor first and the
// other relay answers before ours does. slow holds back every answer of ours.
func (h *halfWay) pace(otherFirst bool, slow time.Duration) {
	if otherFirst {
		h.delays(1500*time.Millisecond, slow, 0)
	} else {
		h.delays(0, slow, 300*time.Millisecond)
	}
}

// the since of the first request on our relay's connection number conn
func (h *halfWay) firstSince(conn int) int64 {
	h.t.Helper()
	var since int64
	waitFor(h.t, "our relay asked", 10*time.Second, func() bool {
		c := h.ours.snapshot()
		if len(c) <= conn || len(c[conn].reqs) == 0 {
			return false
		}
		since = int64(c[conn].reqs[0].filter.Since)
		return true
	})
	return since
}

// a process whose walk on our relay stops half way. the other relay's pass
// ends first and does not move the file. returns how many connections our
// relay saw.
func (h *halfWay) leave(otherFirst bool) int {
	t := h.t
	h.pace(otherFirst, 1500*time.Millisecond)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, h.tag, h.peer.pub, h.rcv)
	waitFor(t, "the other relay's pass", 10*time.Second, func() bool {
		catchupMu.Lock()
		_, done := catchupLast[h.key(h.other)]
		catchupMu.Unlock()
		return inboxHas(h.tag+"|text") && done
	})
	if a := h.anchor(); a != h.began {
		t.Fatalf("the other relay moved the anchor file to %d while ours owes from %d", a, h.began)
	}
	if since := h.firstSince(0); since != h.began-12*3600 {
		t.Fatalf("our relay asked from %d, not from the anchor the process began with", since)
	}
	waitFor(t, "a page of the walk", 10*time.Second, func() bool {
		c := h.ours.snapshot()
		return len(c) > 0 && len(c[0].reqs) >= 2
	})
	cancel()
	waitFor(t, "the walk stopped", 5*time.Second, func() bool { return catchupMarkOf(h.key(h.ours)).Started() })
	time.Sleep(300 * time.Millisecond)
	if a := h.anchor(); a > h.began {
		t.Fatalf("the walk stopped owing from %d, and the anchor file is at %d", h.began, a)
	}
	h.poll()
	return len(h.ours.snapshot())
}

// the next process: no mark, no hold, the anchor from the file
func (h *halfWay) restart(otherFirst bool) {
	h.clean()
	h.pace(otherFirst, 0)
	ctx, cancel := context.WithCancel(context.Background())
	h.t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, h.tag, h.peer.pub, h.rcv)
}

var relayOrders = []struct {
	name       string
	otherFirst bool
}{
	{"ours reads the anchor first", false},
	{"the other relay first", true},
}

// the walk on our relay stops half way, and the process with it. the file
// stays where the walk began. a new text reaches both relays, and in the
// next process the other relay may hand it over before ours has connected.
// ours still asks from where its walk began, and every slice comes.
func TestAWalkLeftHalfWayKeepsTheAnchorFileBelowIt(t *testing.T) {
	for _, o := range relayOrders {
		t.Run(o.name, func(t *testing.T) {
			h := newHalfWay(t)
			n := h.leave(o.otherFirst)
			text2 := wrapToAt(t, h.peer, myXPub, "text 2", time.Now().Add(-5*time.Minute))
			h.ours.store(text2)
			h.other.store(text2)
			h.restart(o.otherFirst)
			if since := h.firstSince(n); since != h.began-12*3600 {
				t.Fatalf("after the restart our relay asked from %d, not from %d", since, h.began-12*3600)
			}
			h.waitAll("every slice", "text 2")
		})
	}
}

// the same restart with nothing new since. once both relays are through, the
// anchor is back at the text the process before had, and later connections
// ask from there, not from where the walk began.
func TestTheAnchorComesBackAfterARestart(t *testing.T) {
	for _, o := range relayOrders {
		t.Run(o.name, func(t *testing.T) {
			h := newHalfWay(t)
			n := h.leave(o.otherFirst)
			h.restart(o.otherFirst)
			if since := h.firstSince(n); since != h.began-12*3600 {
				t.Fatalf("after the restart our relay asked from %d, not from %d", since, h.began-12*3600)
			}
			h.waitAll("every slice")
			text := int64(h.text.CreatedAt)
			waitFor(t, "the anchor file back at the text", 10*time.Second, func() bool { return h.anchor() == text })
			h.delays(0, 0, 0)
			for i := 1; i <= 3; i++ {
				ours, other := len(h.ours.snapshot()), len(h.other.snapshot())
				h.ours.dropAll()
				h.other.dropAll()
				kickUntil(t, "both relays again", func() bool {
					a, b := h.ours.snapshot(), h.other.snapshot()
					return len(a) > ours && len(a[len(a)-1].reqs) > 0 && len(b) > other && len(b[len(b)-1].reqs) > 0
				})
				for _, r := range []*relayStandIn{h.ours, h.other} {
					c := r.snapshot()
					if since := int64(c[len(c)-1].reqs[0].filter.Since); since != text-12*3600 {
						t.Fatalf("reconnect %d asked from %d, not from the text's %d", i, since, text-12*3600)
					}
				}
				// a first answer of twenty is full here, so ours walks
				waitFor(t, "the pass after the reconnect", 10*time.Second, func() bool {
					c := h.ours.snapshot()
					return len(c[len(c)-1].reqs) >= 2 && !catchupHoldOf(h.key(h.ours)).Held()
				})
			}
			if a := h.anchor(); a != text {
				t.Fatalf("after the reconnects the anchor file is at %d, not at the text's %d", a, text)
			}
		})
	}
}

// a relay that answers every request with CLOSED, the way one that wants
// authentication or has had enough of us does
func closingRelay(t *testing.T, reason string) (string, *atomic.Int32) {
	t.Helper()
	var reqs atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := ws.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer c.CloseNow()
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
			reqs.Add(1)
			b, _ := nostr.ClosedEnvelope{SubscriptionID: e.SubscriptionID, Reason: reason}.MarshalJSON()
			if c.Write(r.Context(), ws.MessageText, b) != nil {
				return
			}
		}
	}))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http"), &reqs
}

// a relay whose first answer on a connection is full, and which never
// answers what is asked after it, so a walk on it never gets anywhere.
// counts the requests it leaves unanswered.
func stallingRelay(t *testing.T, events []nostr.Event) (string, *atomic.Int32) {
	t.Helper()
	var stalled atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := ws.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer c.CloseNow()
		first := true
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
			if !first {
				stalled.Add(1)
				continue
			}
			first = false
			sid := e.SubscriptionID
			n := min(e.Filters[0].Limit, len(events))
			for _, ev := range events[:n] {
				b, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: ev}.MarshalJSON()
				if c.Write(r.Context(), ws.MessageText, b) != nil {
					return
				}
			}
			b, _ := nostr.EOSEEnvelope(sid).MarshalJSON()
			if c.Write(r.Context(), ws.MessageText, b) != nil {
				return
			}
		}
	}))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http"), &stalled
}

// public relays that never get through: one refuses every request with
// CLOSED, one refuses the connection, and one hands over a full first answer
// and never a page after it. none of them holds anything. the address is new,
// so the first process asks for everything; after it the file is at its
// text, and the next process asks from there and moves the file to the next
// text.
func TestPublicRelaysThatNeverGetThroughHoldNothing(t *testing.T) {
	// the stalled walk holds the poll back no longer than this, so the app
	// keeps the text within the wait
	withPageQuiet(t, 500*time.Millisecond)
	ours, other := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, ours, other)
	freshInbox(t)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	now := time.Now()
	var backlog []nostr.Event
	for i := 0; i < 100; i++ {
		backlog = append(backlog, unopenedTo(t, rcv, now.Add(-time.Hour-time.Duration(i)*time.Minute), "x"))
	}
	closing, refused := closingRelay(t, "auth-required: sign in first")
	down, dials := refusingRelay(t)
	stall, stalled := stallingRelay(t, backlog)
	urls := []string{ours.url(), other.url(), closing, down, stall}
	useRelays(urls...)
	var keys []string
	for _, u := range urls {
		keys = append(keys, catchupKey(u, rcv))
	}
	forgetCatchup(keys...)
	t.Cleanup(func() { forgetCatchup(keys...) })
	lastPath := savedDataDir + "/nostr_last_" + rcv[:16]
	anchor := func() int64 {
		b, _ := os.ReadFile(lastPath)
		v, _ := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64)
		return v
	}

	process := func(body string, at time.Time) (since nostr.Timestamp) {
		t.Helper()
		text := wrapToAt(t, peer, myXPub, body, at)
		ours.store(text)
		other.store(text)
		conn := len(ours.snapshot())
		r0, d0, s0 := refused.Load(), dials.Load(), stalled.Load()
		ctx, cancel := context.WithCancel(context.Background())
		defer func() {
			cancel()
			forgetCatchup(keys...)
		}()
		go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
		waitFor(t, "every public relay failing once", 10*time.Second, func() bool {
			return refused.Load() > r0 && dials.Load() > d0 && stalled.Load() > s0
		})
		// the app keeps what came, and the file follows
		waitFor(t, "the anchor file at "+body, 10*time.Second, func() bool {
			pollAcked(time.Now())
			return anchor() == int64(text.CreatedAt)
		})
		c := ours.snapshot()
		return c[conn].reqs[0].filter.Since
	}
	if since := process("text 1", now.Add(-time.Hour)); since != 0 {
		t.Fatalf("a new address asked from %d", since)
	}
	text1 := nostr.Timestamp(now.Add(-time.Hour).Unix())
	if since := process("text 2", now.Add(-5*time.Minute)); since != text1-12*3600 {
		t.Fatalf("the next process asked our relay from %d, not from the first text's %d", since, text1-12*3600)
	}
}

// our relay answers the subscription with CLOSED. it hands over nothing, so
// it holds nothing, and the file follows what the other relay hands over.
func TestOurRelayRefusingTheSubscriptionHoldsNothing(t *testing.T) {
	other := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, other)
	freshInbox(t)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	closing, refused := closingRelay(t, "blocked: not today")
	useRelays(closing, other.url())
	keys := []string{catchupKey(closing, rcv), catchupKey(other.url(), rcv)}
	forgetCatchup(keys...)
	t.Cleanup(func() { forgetCatchup(keys...) })
	lastPath := savedDataDir + "/nostr_last_" + rcv[:16]
	began := time.Now().Add(-8 * time.Hour).Unix()
	if err := os.WriteFile(lastPath, []byte(strconv.FormatInt(began, 10)), 0600); err != nil {
		t.Fatal(err)
	}
	text := wrapToAt(t, peer, myXPub, "text", time.Now().Add(-time.Hour))
	other.store(text)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	waitFor(t, "the anchor file at the text", 10*time.Second, func() bool {
		b, _ := os.ReadFile(lastPath)
		return strings.TrimSpace(string(b)) == strconv.FormatInt(int64(text.CreatedAt), 10)
	})
	if refused.Load() == 0 {
		t.Fatal("our relay was never asked")
	}
	if h := catchupHoldOf(keys[0]); h.Held() {
		t.Fatalf("our relay refused and still holds %+v", h)
	}
}

// our relay is two entries, an onion and its clearnet name, and holds a
// backlog below the file. the onion never gets through: it does not connect,
// or it answers the subscription with CLOSED. the clearnet name walks the
// backlog, and its clean pass lets both go, so the file reaches the text.
func TestEitherEntryOfOurRelayLetsGo(t *testing.T) {
	for _, onion := range []struct {
		name string
		url  func(t *testing.T) string
	}{
		{"the onion does not connect", func(t *testing.T) string { u, _ := refusingRelay(t); return u }},
		{"the onion refuses the subscription", func(t *testing.T) string {
			u, _ := closingRelay(t, "auth-required: sign in first")
			return u
		}},
	} {
		t.Run(onion.name, func(t *testing.T) {
			h := newHalfWay(t)
			o := onion.url(t)
			useRelays(o, h.ours.url(), h.other.url())
			oldHost := ownRelayHost
			ownRelayHost = strings.TrimPrefix(h.ours.url(), "ws://")
			t.Cleanup(func() { ownRelayHost = oldHost })
			ok := catchupKey(o, h.rcv)
			forgetCatchup(ok)
			t.Cleanup(func() { forgetCatchup(ok) })
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			go nostrSubscribeRunner(ctx, h.tag, h.peer.pub, h.rcv)
			if since := h.firstSince(0); since != h.began-12*3600 {
				t.Fatalf("our relay's clearnet name asked from %d, not from %d", since, h.began-12*3600)
			}
			h.waitAll("every slice", "text")
			waitFor(t, "the anchor file at the text", 10*time.Second, func() bool {
				return h.anchor() == int64(h.text.CreatedAt)
			})
			if hd := catchupHoldOf(ok); hd.Held() {
				t.Fatalf("the onion still holds %+v", hd)
			}
		})
	}
}

// the lists the app hands over, relaysFor in main.dart: our relay is the
// onion and its clearnet name in private mode, and the clearnet name alone
// in the others. no public relay is ours.
func TestOurRelaysEntriesInTheAppsLists(t *testing.T) {
	onion := "ws://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion"
	clear := "wss://relay.kryfo.app"
	public := []string{"wss://nos.lol", "wss://relay.primal.net", "wss://nostr.mom", "wss://nostr.oxtr.dev"}
	for _, c := range []struct {
		mode       string
		urls, want []string
	}{
		{modePrivate, append([]string{onion, clear}, public...), []string{onion, clear}},
		{modeBalanced, []string{clear}, []string{clear}},
		{modeFast, append([]string{clear}, public...), []string{clear}},
	} {
		if got := ownRelays(c.urls); strings.Join(got, ",") != strings.Join(c.want, ",") {
			t.Errorf("%s: our relay is %v, want %v", c.mode, got, c.want)
		}
	}
}
