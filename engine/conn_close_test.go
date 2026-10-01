// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what a relay connection leaves once it is over: nothing. a failed dial, a
// reconnect, a failed publish dial and a subscription the relay closes all
// end every goroutine they started, and a catch-up page keeps no more than
// it asked for, in the order sent, and no more of each event than a wrap
// can hold.

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"math"
	"net/http"
	"net/http/httptest"
	"runtime"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	ws "github.com/coder/websocket"
	"github.com/halo/engine/catchup"
)

// waits for the goroutines that are ending to end, and fails when more than
// want are left
func goroutinesBackTo(t *testing.T, what string, want int) {
	t.Helper()
	end := time.Now().Add(5 * time.Second)
	n := runtime.NumGoroutine()
	for n > want && time.Now().Before(end) {
		time.Sleep(50 * time.Millisecond)
		runtime.GC()
		n = runtime.NumGoroutine()
	}
	if n > want {
		t.Fatalf("%s: %d goroutines, want at most %d", what, n, want)
	}
}

// a relay that answers every websocket upgrade with a 503, counting them
func refusingRelay(t *testing.T) (string, *atomic.Int32) {
	t.Helper()
	var dials atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		dials.Add(1)
		http.Error(w, "busy", http.StatusServiceUnavailable)
	}))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http"), &dials
}

// kicks the runners until cond holds, so a runner waiting out a pause
// dials again at once
func kickUntil(t *testing.T, what string, cond func() bool) {
	t.Helper()
	end := time.Now().Add(10 * time.Second)
	for !cond() {
		if time.Now().After(end) {
			t.Fatalf("%s: not within 10s", what)
		}
		kickRelays()
		time.Sleep(30 * time.Millisecond)
	}
}

func TestFailedDialsLeaveNothingBehind(t *testing.T) {
	u, dials := refusingRelay(t)
	useStandIns(t, modeFast, nil)
	useRelays(u)
	freshInbox(t)
	peer := newXid(t)
	rcv := mustRcv(t, peer)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, rcv)
	waitFor(t, "the first dial", 5*time.Second, func() bool { return dials.Load() >= 1 })
	time.Sleep(200 * time.Millisecond)
	before := runtime.NumGoroutine()

	const rounds = 40
	for i := int32(2); i <= rounds; i++ {
		kickUntil(t, "the next dial", func() bool { return dials.Load() >= i })
	}
	goroutinesBackTo(t, "after 40 failed dials", before+5)
}

func TestReconnectsLeaveNothingBehind(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	oldSpread := kickSpread
	kickSpread = 0
	defer func() { kickSpread = oldSpread }()
	peer := newXid(t)
	rcv := mustRcv(t, peer)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, rcv)
	listening := func(n int) func() bool {
		return func() bool {
			conns := relay.snapshot()
			return len(conns) >= n && len(conns[n-1].reqs) > 0
		}
	}
	waitFor(t, "the first subscription", 5*time.Second, listening(1))
	time.Sleep(300 * time.Millisecond)
	before := runtime.NumGoroutine()

	const rounds = 30
	for i := 2; i <= rounds; i++ {
		relay.dropAll()
		kickUntil(t, "the next subscription", listening(i))
	}
	time.Sleep(300 * time.Millisecond)
	goroutinesBackTo(t, "after 30 reconnects", before+5)
}

func TestFailedPublishDialsLeaveNothingBehind(t *testing.T) {
	u, dials := refusingRelay(t)
	useStandIns(t, modeFast, nil)
	useRelays(u)
	evs, _ := wrapsTo(t, newXid(t), myXPub, 1)
	before := runtime.NumGoroutine()

	const rounds = 30
	for i := 0; i < rounds; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		if nostrPublishMulti(ctx, laneEveryday, evs[0]) != 0 {
			t.Fatal("a relay that answers 503 took a wrap")
		}
		cancel()
	}
	if n := dials.Load(); n < rounds {
		t.Fatalf("%d dials for %d publishes", n, rounds)
	}
	goroutinesBackTo(t, "after 30 failed publish dials", before+5)
}

// a relay that answers each request with a run of CLOSED frames for it
func TestClosedFramesLeaveNothingWaiting(t *testing.T) {
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
			b, _ := nostr.ClosedEnvelope{SubscriptionID: e.SubscriptionID, Reason: "no"}.MarshalJSON()
			for i := 0; i < 200; i++ {
				if c.Write(r.Context(), ws.MessageText, b) != nil {
					return
				}
			}
		}
	}))
	defer srv.Close()
	time.Sleep(100 * time.Millisecond)
	before := runtime.NumGoroutine()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, "ws"+strings.TrimPrefix(srv.URL, "http"), nostr.RelayOptions{})
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 5; i++ {
		sctx, scancel := context.WithCancel(ctx)
		sub, err := r.Subscribe(sctx, nostr.Filter{Kinds: []nostr.Kind{1059}},
			nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
		if err != nil {
			t.Fatal(err)
		}
		select {
		case <-sub.Context.Done():
		case <-ctx.Done():
			t.Fatal("the subscription outlived its CLOSED")
		}
		if reason := <-sub.ClosedReason; reason != "no" {
			t.Fatalf("closed for %q", reason)
		}
		scancel()
	}
	r.Close()
	goroutinesBackTo(t, "after five closed subscriptions", before+2)
}

// a relay that sends ten times what a page asked for and never says it is
// done, with one event larger than any wrap can be in front. the page reads
// pageReads times its limit, stops, and keeps the newest it asked for. the
// large one counts, as its id and stamp.
func TestPageKeepsNoMoreThanItAskedFor(t *testing.T) {
	var addr [32]byte
	if _, err := rand.Read(addr[:]); err != nil {
		t.Fatal(err)
	}
	rcv := hex.EncodeToString(addr[:])
	now := time.Now()
	big := unopenedTo(t, rcv, now, strings.Repeat("A", wrapContentMax+1))
	var evs []nostr.Event
	for i := 0; i < 200; i++ {
		evs = append(evs, unopenedTo(t, rcv, now.Add(-time.Duration(i)*time.Second), "x"))
	}
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
			sid := e.SubscriptionID
			for _, ev := range append([]nostr.Event{big}, evs...) {
				b, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: ev}.MarshalJSON()
				if c.Write(r.Context(), ws.MessageText, b) != nil {
					return
				}
			}
		}
	}))
	defer srv.Close()
	old := pageQuiet
	pageQuiet = 3 * time.Second
	defer func() { pageQuiet = old }()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, "ws"+strings.TrimPrefix(srv.URL, "http"), nostr.RelayOptions{})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	start := time.Now()
	got, err := relayPage(ctx, r, rcv, nostr.Timestamp(now.Add(-time.Hour).Unix()),
		nostr.Timestamp(now.Unix()), 20)
	if err != nil {
		t.Fatalf("a page that got what it asked for ended with %v", err)
	}
	if took := time.Since(start); took > time.Second {
		t.Fatalf("the page waited %s after it had what it asked for", took)
	}
	if len(got) != 20 {
		t.Fatalf("kept %d events, asked for 20", len(got))
	}
	// the first twenty sent, the newest, in the order sent
	for i, ev := range append([]nostr.Event{big}, evs...)[:20] {
		if got[i].ID != ev.ID {
			t.Fatalf("event %d of the page is not event %d as sent", i, i)
		}
	}
	if got[0].Content != "" || got[0].CreatedAt != big.CreatedAt {
		t.Fatal("an event larger than a wrap can be was not kept as its id and stamp alone")
	}
}

// ten events larger than a wrap can be, newer than five wraps: the page of
// ten still counts, and the walk carries on below it to the five
func TestEventsLargerThanAWrapStillFillTheirPage(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	var addr [32]byte
	if _, err := rand.Read(addr[:]); err != nil {
		t.Fatal(err)
	}
	rcv := hex.EncodeToString(addr[:])
	now := time.Now()
	large := map[nostr.ID]bool{}
	for i := 0; i < 10; i++ {
		ev := unopenedTo(t, rcv, now.Add(-time.Duration(i)*time.Minute), strings.Repeat("A", wrapContentMax+1))
		large[ev.ID] = true
		relay.store(ev)
	}
	wraps := map[nostr.ID]bool{}
	for i := 0; i < 5; i++ {
		ev := unopenedTo(t, rcv, now.Add(-time.Hour-time.Duration(i)*time.Minute), "x")
		wraps[ev.ID] = true
		relay.store(ev)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, relay.url(), nostr.RelayOptions{})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	got := map[nostr.ID]nostr.Event{}
	res := catchup.Back(ctx, func(pc context.Context, s, u nostr.Timestamp, n int) ([]nostr.Event, error) {
		return relayPage(pc, r, rcv, s, u, n)
	}, nostr.Timestamp(now.Add(-2*time.Hour).Unix()), nostr.Timestamp(now.Unix()), 10, 50,
		func(ev nostr.Event) bool {
			got[ev.ID] = ev
			return true
		})
	if !res.Complete {
		t.Fatalf("the walk did not reach the end: %+v", res)
	}
	for id := range wraps {
		if _, ok := got[id]; !ok {
			t.Fatalf("the walk ended above a wrap: %+v", res)
		}
	}
	for id := range large {
		if ev, ok := got[id]; !ok || ev.Content != "" {
			t.Fatal("an event larger than a wrap can be was not handed on as its id and stamp alone")
		}
	}
}

// tags beyond what a wrap carries count toward its size too
func TestPageEntryKeepsWrapsWhole(t *testing.T) {
	ev := unopenedTo(t, strings.Repeat("a", 64), time.Now(), strings.Repeat("A", wrapContentMax))
	ev.Tags = append(ev.Tags, nostr.Tag{"expiration", "1800000000"})
	if got := pageEntry(ev); got.Content != ev.Content || len(got.Tags) != 2 {
		t.Fatal("a wrap of the largest size was not kept whole")
	}
	ev.Tags = append(ev.Tags, nostr.Tag{"x", strings.Repeat("b", wrapTagsMax)})
	got := pageEntry(ev)
	if got.ID != ev.ID || got.CreatedAt != ev.CreatedAt || got.Content != "" || got.Tags != nil {
		t.Fatalf("an event with more tags than a wrap carries kept %d bytes and %d tags",
			len(got.Content), len(got.Tags))
	}
}
