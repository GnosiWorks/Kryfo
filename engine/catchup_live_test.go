// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a wrap a contact sends while a catch-up is under way goes out live, and
// like every wrap it is stamped up to hours back. taken for a stored one it
// would set where the walk carries on, below stored wraps the relay never
// got to, and a fresh walk would finish without them.

import (
	"context"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"slices"
	"sort"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	ws "github.com/coder/websocket"
	"github.com/halo/engine/catchup"
)

// a relay that answers every request from its store, newest first, up to
// the limit, and passes one new wrap on live while answering the first:
// right after its eose, or, as khatru can when a live push races a stored
// answer, right before it
type liveRelay struct {
	mu     sync.Mutex
	store  []nostr.Event
	live   nostr.Event
	before bool
	sent   bool
}

func (l *liveRelay) serve(t *testing.T) string {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := ws.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer c.CloseNow()
		c.SetReadLimit(1 << 20)
		ctx := r.Context()
		send := func(b []byte) bool { return c.Write(ctx, ws.MessageText, b) == nil }
		for {
			_, data, err := c.Read(ctx)
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
			f := e.Filters[0]
			l.mu.Lock()
			var match []nostr.Event
			for _, ev := range l.store {
				if f.Matches(ev) && !f.LimitZero {
					match = append(match, ev)
				}
			}
			push := !l.sent && !f.LimitZero
			if push {
				l.sent = true
				l.store = append(l.store, l.live)
			}
			l.mu.Unlock()
			sort.Slice(match, func(i, j int) bool { return match[i].CreatedAt > match[j].CreatedAt })
			if f.Limit > 0 && len(match) > f.Limit {
				match = match[:f.Limit]
			}
			sid := e.SubscriptionID
			for _, ev := range match {
				b, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: ev}.MarshalJSON()
				if !send(b) {
					return
				}
			}
			livePush, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: l.live}.MarshalJSON()
			if push && l.before && !send(livePush) {
				return
			}
			b, _ := nostr.EOSEEnvelope(sid).MarshalJSON()
			if !send(b) {
				return
			}
			if push && !l.before && !send(livePush) {
				return
			}
		}
	}))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http")
}

// whether a catch-up on key has begun and not ended
func catchupRunning(key string) bool {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	_, ok := catchupFrom[key]
	return ok
}

// 130 stored wraps, an hour back and older, and one sent live while the
// first answer comes, stamped nine hours back, below all of them. every one
// arrives before the walk ends.
func TestALiveWrapDoesNotMoveTheFirstAnswersOldest(t *testing.T) {
	for _, before := range []bool{false, true} {
		name := "after the eose"
		if before {
			name = "before the eose"
		}
		t.Run(name, func(t *testing.T) {
			useStandIns(t, modeFast, nil, newRelayStandIn(t, 0))
			const stored = 130
			for round := 0; round < 6; round++ {
				freshInbox(t)
				peer := newXid(t)
				tag := hex.EncodeToString(peer.pub[:])
				rcv := mustRcv(t, peer)
				now := time.Now()
				l := &liveRelay{before: before}
				for i := 0; i < stored; i++ {
					l.store = append(l.store, wrapToAt(t, peer, myXPub, "old "+strconv.Itoa(i),
						now.Add(-time.Hour-time.Duration(i)*2*time.Minute)))
				}
				l.live = wrapToAt(t, peer, myXPub, "live", now.Add(-9*time.Hour))
				u := l.serve(t)
				useRelays(u)
				ck := catchupKey(u, rcv)
				forgetCatchup(ck)
				ctx, cancel := context.WithCancel(context.Background())
				go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
				waitFor(t, "the walk to end", 15*time.Second, func() bool {
					return inboxHas(tag+"|live") && !catchupRunning(ck)
				})
				missing := 0
				for i := 0; i < stored; i++ {
					if !inboxHas(tag + "|old " + strconv.Itoa(i)) {
						missing++
					}
				}
				cancel()
				forgetCatchup(ck)
				if missing > 0 {
					t.Fatalf("round %d: the walk ended without %d of %d stored wraps", round, missing, stored)
				}
			}
		})
	}
}

// our relay as khatru can behave: a request's stored events go out from one
// goroutine and a live push from another, so wraps that arrive while a page
// is written go out among its stored events. a photo is a hundred wraps.
// here they come after the 40th of the first page, stamped below everything
// stored.
func TestLiveWrapsInsideAPageSkipNothing(t *testing.T) {
	for _, burst := range []int{1, 11, 100, 250} {
		complete, missing := walkWithBurst(t, burst)
		if !complete || missing > 0 {
			t.Fatalf("%d live inside a page: complete %v without %d of 300 stored events",
				burst, complete, missing)
		}
	}
}

func walkWithBurst(t *testing.T, burst int) (bool, int) {
	now := nostr.Now()
	var store []nostr.Event
	for i := 0; i < 300; i++ {
		ev := nostr.Event{Kind: 1059, CreatedAt: now - 3600 - nostr.Timestamp(i*60), Tags: nostr.Tags{{"p", "aa"}}}
		ev.ID[0], ev.ID[1] = byte(i>>8), byte(i)
		store = append(store, ev)
	}
	before := slices.Clone(store)
	var lives []nostr.Event
	for j := 0; j < burst; j++ {
		ev := nostr.Event{Kind: 1059, CreatedAt: now - 9*3600 - nostr.Timestamp(j), Tags: nostr.Tags{{"p", "aa"}}}
		ev.ID[0], ev.ID[1], ev.ID[2] = 0xff, byte(j>>8), byte(j)
		lives = append(lives, ev)
	}
	var mu sync.Mutex
	pushed := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := ws.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer c.CloseNow()
		ctx := r.Context()
		send := func(b []byte) bool { return c.Write(ctx, ws.MessageText, b) == nil }
		for {
			_, data, err := c.Read(ctx)
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
			f := e.Filters[0]
			mu.Lock()
			var match []nostr.Event
			for _, ev := range store {
				if f.Matches(ev) {
					match = append(match, ev)
				}
			}
			mu.Unlock()
			sort.Slice(match, func(i, j int) bool { return match[i].CreatedAt > match[j].CreatedAt })
			if f.Limit > 0 && len(match) > f.Limit {
				match = match[:f.Limit]
			}
			sid := e.SubscriptionID
			for i, ev := range match {
				b, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: ev}.MarshalJSON()
				if !send(b) {
					return
				}
				mu.Lock()
				push := !pushed && i == 40 && f.Matches(lives[0])
				if push {
					pushed = true
					store = append(store, lives...)
				}
				mu.Unlock()
				for _, lv := range lives {
					if !push {
						break
					}
					b, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: lv}.MarshalJSON()
					if !send(b) {
						return
					}
				}
			}
			b, _ := nostr.EOSEEnvelope(sid).MarshalJSON()
			if !send(b) {
				return
			}
		}
	}))
	defer srv.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	rl, err := nostr.RelayConnect(ctx, "ws"+strings.TrimPrefix(srv.URL, "http"), nostr.RelayOptions{AssumeValid: true})
	if err != nil {
		t.Fatal(err)
	}
	defer rl.Close()
	got := map[nostr.ID]bool{}
	res := catchup.Back(ctx, func(pc context.Context, s, u nostr.Timestamp, n int) ([]nostr.Event, error) {
		return relayPage(pc, rl, "aa", s, u, n)
	}, now-48*3600, now, catchupPage, 50, func(ev nostr.Event) bool { got[ev.ID] = true; return true })
	missing := 0
	for _, ev := range before {
		if !got[ev.ID] {
			missing++
		}
	}
	return res.Complete, missing
}
