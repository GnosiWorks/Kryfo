// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a page the relay cuts short keeps the start of what the relay sent, in the
// order it was sent, so the walk carries on from below everything the page
// did not hand over, and whatever shares the lowest stamp is asked for again.

import (
	"bytes"
	"context"
	crand "crypto/rand"
	"encoding/hex"
	"math"
	"math/rand/v2"
	"net/http"
	"net/http/httptest"
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

// a relay that answers a page newest first, ties by id, pausing at random
// between events. most pages it drops the socket part way through, the way
// a circuit dies; the rest, and a page with nothing in it, end with an eose.
type cuttingRelay struct {
	srv    *httptest.Server
	events []nostr.Event

	mu     sync.Mutex
	rng    *rand.Rand
	sent   [][]nostr.Event   // per cut page, what went out before the drop
	untils []nostr.Timestamp // per page asked for
}

func newCuttingRelay(t *testing.T, seed uint64, events []nostr.Event) *cuttingRelay {
	c := &cuttingRelay{events: events, rng: rand.New(rand.NewPCG(seed, 7))}
	c.srv = httptest.NewServer(http.HandlerFunc(c.handle))
	t.Cleanup(c.srv.Close)
	return c
}

func (c *cuttingRelay) url() string { return "ws" + strings.TrimPrefix(c.srv.URL, "http") }

func (c *cuttingRelay) handle(w http.ResponseWriter, r *http.Request) {
	conn, err := ws.Accept(w, r, nil)
	if err != nil {
		return
	}
	defer conn.CloseNow()
	ctx := r.Context()
	for {
		_, data, err := conn.Read(ctx)
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
		var match []nostr.Event
		for _, ev := range c.events {
			if f.Matches(ev) {
				match = append(match, ev)
			}
		}
		sort.Slice(match, func(i, j int) bool {
			if match[i].CreatedAt != match[j].CreatedAt {
				return match[i].CreatedAt > match[j].CreatedAt
			}
			return bytes.Compare(match[i].ID[:], match[j].ID[:]) < 0
		})
		if f.Limit > 0 && len(match) > f.Limit {
			match = match[:f.Limit]
		}
		sid := e.SubscriptionID
		c.mu.Lock()
		c.untils = append(c.untils, f.Until)
		c.mu.Unlock()
		if len(match) == 0 {
			b, _ := nostr.EOSEEnvelope(sid).MarshalJSON()
			if conn.Write(ctx, ws.MessageText, b) != nil {
				return
			}
			continue
		}
		c.mu.Lock()
		whole := c.rng.IntN(4) == 0
		cut := len(match)
		if !whole {
			cut = c.rng.IntN(len(match) + 1)
		}
		pause := make([]time.Duration, cut)
		for i := range pause {
			if c.rng.IntN(3) == 0 {
				pause[i] = time.Duration(c.rng.IntN(300)) * time.Microsecond
			}
		}
		c.mu.Unlock()
		for i, ev := range match[:cut] {
			b, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: ev}.MarshalJSON()
			if conn.Write(ctx, ws.MessageText, b) != nil {
				return
			}
			if pause[i] > 0 {
				time.Sleep(pause[i])
			}
		}
		if whole {
			b, _ := nostr.EOSEEnvelope(sid).MarshalJSON()
			if conn.Write(ctx, ws.MessageText, b) != nil {
				return
			}
			continue
		}
		c.mu.Lock()
		c.sent = append(c.sent, match[:cut])
		c.mu.Unlock()
		return
	}
}

// what the last cut page sent, and how many pages have been asked for
func (c *cuttingRelay) lastPage() ([]nostr.Event, int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	var last []nostr.Event
	if len(c.sent) > 0 {
		last = c.sent[len(c.sent)-1]
	}
	return last, len(c.untils)
}

// the until page number n asked with, and whether it was asked for
func (c *cuttingRelay) untilOf(n int) (nostr.Timestamp, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if n >= len(c.untils) {
		return 0, false
	}
	return c.untils[n], true
}

// most pages are cut somewhere, often inside a second that holds three
// events. whatever a page sent and did not hand over lies at or below where
// the walk resumes, the next connection asks from there, and in the end
// every event has come.
func TestCutPagesResumeBelowWhatTheyMissed(t *testing.T) {
	seed := uint64(time.Now().UnixNano())
	var addr [32]byte
	if _, err := crand.Read(addr[:]); err != nil {
		t.Fatal(err)
	}
	rcv := hex.EncodeToString(addr[:])
	now := time.Now()
	var evs []nostr.Event
	for i := 0; i < 900; i++ {
		evs = append(evs, unopenedTo(t, rcv, now.Add(-time.Duration(i/3)*time.Second), "x"))
	}
	relay := newCuttingRelay(t, seed, evs)
	since := nostr.Timestamp(now.Add(-2 * time.Hour).Unix())
	top := nostr.Timestamp(now.Unix())
	got := map[nostr.ID]bool{}
	deliver := func(ev nostr.Event) bool {
		fresh := !got[ev.ID]
		got[ev.ID] = true
		return fresh
	}
	var m catchup.Mark
	cuts := 0
	for round := 0; ; round++ {
		if round == 2000 {
			t.Fatalf("seed %d: the walk never reached the end", seed)
		}
		_, asked := relay.lastPage()
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		r, err := nostr.RelayConnect(ctx, relay.url(), nostr.RelayOptions{})
		if err != nil {
			cancel()
			t.Fatal(err)
		}
		res, next := catchup.Continue(ctx, func(pc context.Context, s, u nostr.Timestamp, n int) ([]nostr.Event, error) {
			return relayPage(pc, r, rcv, s, u, n)
		}, since, top, 40, catchupMaxPages, deliver, m)
		r.Close()
		cancel()
		// the first page of a walk that carries on asks from the resume
		// point itself, so the rest of a second the cut went through comes
		// again
		if m.Started() {
			if u, ok := relay.untilOf(asked); !ok || u != m.Cursor {
				t.Fatalf("seed %d, round %d: asked until %d, not from the resume point %d",
					seed, round, u, m.Cursor)
			}
		}
		if res.Complete {
			break
		}
		cuts++
		page, _ := relay.lastPage()
		for _, ev := range page {
			if !got[ev.ID] && ev.CreatedAt > res.Until {
				t.Fatalf("seed %d, round %d: the walk resumes from %d, above an event stamped %d that the page sent and never handed over",
					seed, round, res.Until, ev.CreatedAt)
			}
		}
		for _, ev := range evs {
			if !got[ev.ID] && ev.CreatedAt > res.Until {
				t.Fatalf("seed %d, round %d: the walk resumes from %d, above an event stamped %d still to come",
					seed, round, res.Until, ev.CreatedAt)
			}
		}
		m = next
	}
	missing := 0
	for _, ev := range evs {
		if !got[ev.ID] {
			missing++
		}
	}
	if missing > 0 {
		t.Fatalf("seed %d: %d of %d events never came, over %d cut pages", seed, missing, len(evs), cuts)
	}
}

// a relay that answers each request with stored events, an eose and then as
// many live ones, numbered in the order they go out
func floodRelay(t *testing.T, stored, live int) string {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := ws.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		ctx := r.Context()
		for {
			_, data, err := conn.Read(ctx)
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
			now := nostr.Now()
			for i := 0; i < stored+live; i++ {
				if i == stored {
					b, _ := nostr.EOSEEnvelope(sid).MarshalJSON()
					if conn.Write(ctx, ws.MessageText, b) != nil {
						return
					}
				}
				ev := nostr.Event{Kind: 1059, CreatedAt: now - nostr.Timestamp(i), Content: strconv.Itoa(i)}
				ev.ID[0], ev.ID[1] = byte(i>>8), byte(i)
				b, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: ev}.MarshalJSON()
				if conn.Write(ctx, ws.MessageText, b) != nil {
					return
				}
			}
		}
	}))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http")
}

// a reader that takes its time still gets every event in the order it was
// sent, the stored ones all before the eose is passed on
func TestEventsComeInTheOrderTheyWereSent(t *testing.T) {
	const stored, live = 300, 300
	u := floodRelay(t, stored, live)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, u, nostr.RelayOptions{AssumeValid: true})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	sub, err := r.Subscribe(ctx, nostr.Filter{Kinds: []nostr.Kind{1059}},
		nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
	if err != nil {
		t.Fatal(err)
	}
	defer sub.Unsub()
	rng := rand.New(rand.NewPCG(uint64(time.Now().UnixNano()), 3))
	next := 0
	eose := sub.EndOfStoredEvents
	for next < stored+live {
		select {
		case ev := <-sub.Events:
			if ev.Content != strconv.Itoa(next) {
				t.Fatalf("event %s came where %d was due", ev.Content, next)
			}
			next++
			if rng.IntN(8) == 0 {
				time.Sleep(time.Duration(rng.IntN(200)) * time.Microsecond)
			}
		case <-eose:
			if next < stored {
				t.Fatalf("the eose came after %d of %d stored events", next, stored)
			}
			eose = nil
		case <-ctx.Done():
			t.Fatalf("only %d of %d events came", next, stored+live)
		}
	}
}

// a reader that does some work per event, as take() does, and takes either
// channel gets the eose right after the last stored event: never a live one
// first, which it would count as stored
func TestALiveEventNeverComesBeforeTheEose(t *testing.T) {
	const stored, live = 5, 3
	u := floodRelay(t, stored, live)
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, u, nostr.RelayOptions{AssumeValid: true})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	early := 0
	const rounds = 100
	for round := 0; round < rounds; round++ {
		sub, err := r.Subscribe(ctx, nostr.Filter{Kinds: []nostr.Kind{1059}},
			nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
		if err != nil {
			t.Fatal(err)
		}
		eose := sub.EndOfStoredEvents
		next, counted := 0, 0
		for next < stored+live {
			select {
			case <-sub.Events:
				if eose != nil {
					counted++
				}
				next++
				time.Sleep(time.Millisecond)
			case <-eose:
				eose = nil
			case <-ctx.Done():
				t.Fatalf("round %d: only %d of %d events came", round, next, stored+live)
			}
		}
		if counted != stored {
			early++
		}
		sub.Unsub()
	}
	if early > 0 {
		t.Fatalf("%d of %d rounds counted a live event as stored", early, rounds)
	}
}

// a relay that answers each request with stored events, its eose and at
// once a CLOSED, so the subscription ends while most are still on their way
func eoseThenClosedRelay(t *testing.T, stored int) string {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := ws.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		ctx := r.Context()
		for {
			_, data, err := conn.Read(ctx)
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
			now := nostr.Now()
			var frames [][]byte
			for i := 0; i < stored; i++ {
				ev := nostr.Event{Kind: 1059, CreatedAt: now - nostr.Timestamp(i), Content: strconv.Itoa(i)}
				ev.ID[0], ev.ID[1] = byte(i>>8), byte(i)
				b, _ := nostr.EventEnvelope{SubscriptionID: &sid, Event: ev}.MarshalJSON()
				frames = append(frames, b)
			}
			b, _ := nostr.EOSEEnvelope(sid).MarshalJSON()
			frames = append(frames, b)
			b, _ = nostr.ClosedEnvelope{SubscriptionID: sid, Reason: "error: shutting down"}.MarshalJSON()
			frames = append(frames, b)
			for _, b := range frames {
				if conn.Write(ctx, ws.MessageText, b) != nil {
					return
				}
			}
		}
	}))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http")
}

// the eose is handed over only after every stored event: a subscription
// that ends with some still undelivered drops the eose with them, so a page
// never takes what it got for the whole answer
func TestAnEoseNeverFollowsADroppedStoredEvent(t *testing.T) {
	const stored = 30
	u := eoseThenClosedRelay(t, stored)
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, u, nostr.RelayOptions{AssumeValid: true})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	short := 0
	const rounds = 100
	for round := 0; round < rounds; round++ {
		sub, err := r.Subscribe(ctx, nostr.Filter{Kinds: []nostr.Kind{1059}},
			nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
		if err != nil {
			t.Fatal(err)
		}
		got := 0
		for open := true; open; {
			select {
			case _, alive := <-sub.Events:
				if !alive {
					open = false
					break
				}
				got++
				time.Sleep(50 * time.Microsecond)
			case <-sub.EndOfStoredEvents:
				if got != stored {
					short++
				}
				open = false
			case <-ctx.Done():
				t.Fatalf("round %d: the subscription never ended", round)
			}
		}
		sub.Unsub()
	}
	if short > 0 {
		t.Fatalf("%d of %d rounds handed the eose over after fewer than %d stored events", short, rounds, stored)
	}
}

// an eose faked after MaxWaitForEOSE comes behind every stored event that
// came before it, in order, even when the reader is not there as it fires
func TestAFakedEoseDropsNoStoredEvent(t *testing.T) {
	const stored = 40
	u := floodRelay(t, stored, 0)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, u, nostr.RelayOptions{AssumeValid: true})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	for round := 0; round < 3; round++ {
		sub, err := r.Subscribe(ctx, nostr.Filter{Kinds: []nostr.Kind{1059}},
			nostr.SubscriptionOptions{MaxWaitForEOSE: 50 * time.Millisecond})
		if err != nil {
			t.Fatal(err)
		}
		time.Sleep(200 * time.Millisecond)
		next := 0
		for done := false; !done; {
			select {
			case ev := <-sub.Events:
				if ev.Content != strconv.Itoa(next) {
					t.Fatalf("round %d: event %s came where %d was due", round, ev.Content, next)
				}
				next++
			case <-sub.EndOfStoredEvents:
				if next != stored {
					t.Fatalf("round %d: the faked eose came after %d of %d stored events", round, next, stored)
				}
				done = true
			case <-ctx.Done():
				t.Fatalf("round %d: no eose", round)
			}
		}
		sub.Unsub()
	}
}

// subscriptions ended part way through a flood hand over the start of it,
// in order, and close their channel; nothing is sent on it after that
func TestAnEndedSubscriptionKeepsTheStartOfWhatCame(t *testing.T) {
	u := floodRelay(t, 400, 0)
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, u, nostr.RelayOptions{AssumeValid: true})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	rng := rand.New(rand.NewPCG(uint64(time.Now().UnixNano()), 5))
	for round := 0; round < 40; round++ {
		sub, err := r.Subscribe(ctx, nostr.Filter{Kinds: []nostr.Kind{1059}},
			nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
		if err != nil {
			t.Fatal(err)
		}
		stop := 1 + rng.IntN(60)
		next := 0
		for open := true; open; {
			select {
			case ev, alive := <-sub.Events:
				if !alive {
					open = false
					break
				}
				if ev.Content != strconv.Itoa(next) {
					t.Fatalf("round %d: event %s came where %d was due", round, ev.Content, next)
				}
				next++
				if next == stop {
					sub.Unsub()
				}
			case <-sub.EndOfStoredEvents:
				sub.Unsub()
			case <-ctx.Done():
				t.Fatalf("round %d: the channel never closed", round)
			}
		}
	}
}
