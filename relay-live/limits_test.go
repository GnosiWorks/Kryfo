package main

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/fiatjaf/eventstore/slicestore"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

// a real relay with the limits on, over a real websocket
func testRelay(t *testing.T) (string, *limits) {
	t.Helper()
	relay := khatru.NewRelay()
	db := &slicestore.SliceStore{}
	if err := db.Init(); err != nil {
		t.Fatal(err)
	}
	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	l := applyLimits(relay, "")
	srv := httptest.NewServer(relay)
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http"), l
}

func connect(t *testing.T, url string) *nostr.Relay {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r.Close() })
	return r
}

func wrap(t *testing.T, to string, mod func(*nostr.Event)) nostr.Event {
	t.Helper()
	ev := nostr.Event{
		Kind:      wrapKind,
		CreatedAt: nostr.Now() - 3600,
		Content:   "sealed",
		Tags:      nostr.Tags{{"p", to}},
	}
	if mod != nil {
		mod(&ev)
	}
	if err := ev.Sign(nostr.GeneratePrivateKey()); err != nil {
		t.Fatal(err)
	}
	return ev
}

func addr() string {
	pk, _ := nostr.GetPublicKey(nostr.GeneratePrivateKey())
	return pk
}

func publish(t *testing.T, r *nostr.Relay, ev nostr.Event) error {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return r.Publish(ctx, ev)
}

// what a req gets back: the events before eose, or the reason it was closed
func ask(t *testing.T, r *nostr.Relay, f nostr.Filter) ([]*nostr.Event, string) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	sub, err := r.Subscribe(ctx, nostr.Filters{f})
	if err != nil {
		t.Fatal(err)
	}
	defer sub.Unsub()
	var got []*nostr.Event
	for {
		select {
		case ev := <-sub.Events:
			got = append(got, ev)
		case <-sub.EndOfStoredEvents:
			return got, ""
		case why := <-sub.ClosedReason:
			return got, why
		case <-ctx.Done():
			t.Fatal("no eose and no closed")
		}
	}
}

func TestWrapsGoInAndComeBackByAddress(t *testing.T) {
	url, _ := testRelay(t)
	r := connect(t, url)
	to := addr()
	if err := publish(t, r, wrap(t, to, nil)); err != nil {
		t.Fatal(err)
	}
	got, why := ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Limit: 100})
	if why != "" || len(got) != 1 {
		t.Fatalf("got %d, closed %q", len(got), why)
	}
	// the app's liveness probe: an id that matches nothing
	got, why = ask(t, r, nostr.Filter{IDs: []string{strings.Repeat("0", 64)}, Limit: 1})
	if why != "" || len(got) != 0 {
		t.Fatalf("probe: got %d, closed %q", len(got), why)
	}
	// the pair code's wrap carries an expiration beside its address
	exp := wrap(t, to, func(e *nostr.Event) {
		e.Tags = append(e.Tags, nostr.Tag{"expiration", "9999999999"})
	})
	if err := publish(t, r, exp); err != nil {
		t.Fatal(err)
	}
}

func TestOnlyWrapsToOneAddress(t *testing.T) {
	url, _ := testRelay(t)
	r := connect(t, url)
	to := addr()
	for name, mod := range map[string]func(*nostr.Event){
		"a note":          func(e *nostr.Event) { e.Kind = 1 },
		"no address":      func(e *nostr.Event) { e.Tags = nil },
		"two addresses":   func(e *nostr.Event) { e.Tags = append(e.Tags, nostr.Tag{"p", addr()}) },
		"a bad address":   func(e *nostr.Event) { e.Tags = nostr.Tags{{"p", "zz"}} },
		"from the future": func(e *nostr.Event) { e.CreatedAt = nostr.Now() + nostr.Timestamp(futureSlack/time.Second) + 60 },
		"too old":         func(e *nostr.Event) { e.CreatedAt = nostr.Now() - nostr.Timestamp(wrapTTL/time.Second) - 60 },
	} {
		if err := publish(t, r, wrap(t, to, mod)); err == nil {
			t.Errorf("%s was taken", name)
		}
	}
}

func TestScrapesAreRefused(t *testing.T) {
	url, _ := testRelay(t)
	r := connect(t, url)
	to := addr()
	if err := publish(t, r, wrap(t, to, nil)); err != nil {
		t.Fatal(err)
	}
	many := make([]string, maxAddrs+1)
	for i := range many {
		many[i] = addr()
	}
	for name, f := range map[string]nostr.Filter{
		"everything":         {},
		"every wrap":         {Kinds: []int{wrapKind}},
		"every wrap, recent": {Kinds: []int{wrapKind}, Since: func() *nostr.Timestamp { s := nostr.Now() - 86400; return &s }()},
		"by author":          {Kinds: []int{wrapKind}, Authors: []string{to}},
		"another kind":       {Kinds: []int{1}, Tags: nostr.TagMap{"p": {to}}},
		"another tag":        {Kinds: []int{wrapKind}, Tags: nostr.TagMap{"e": {to}}},
		"too many addresses": {Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": many}},
		"search":             {Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Search: "x"},
	} {
		got, why := ask(t, r, f)
		if why == "" || len(got) != 0 {
			t.Errorf("%s: got %d, closed %q", name, len(got), why)
		}
	}
}

func TestEventsArePacedPerConnection(t *testing.T) {
	url, _ := testRelay(t)
	r := connect(t, url)
	to := addr()
	taken := 0
	for i := 0; i < eventBurst+20; i++ {
		if publish(t, r, wrap(t, to, nil)) == nil {
			taken++
		}
	}
	// the refill adds a few while the loop runs
	if taken < eventBurst || taken > eventBurst+15 {
		t.Fatalf("took %d of %d, burst is %d", taken, eventBurst+20, eventBurst)
	}
	// a second connection has its own budget
	if err := publish(t, connect(t, url), wrap(t, to, nil)); err != nil {
		t.Fatalf("second connection: %v", err)
	}
}

func TestReqsArePacedPerConnection(t *testing.T) {
	url, _ := testRelay(t)
	r := connect(t, url)
	f := nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {addr()}}}
	refused := 0
	for i := 0; i < reqBurst+10; i++ {
		if _, why := ask(t, r, f); why != "" {
			refused++
		}
	}
	if refused == 0 {
		t.Fatal("no req was refused past the burst")
	}
	if _, why := ask(t, connect(t, url), f); why != "" {
		t.Fatalf("second connection: %q", why)
	}
}

func TestConnectionCeilingAndDisk(t *testing.T) {
	url, l := testRelay(t)
	l.maxConns = 1
	r := connect(t, url)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := nostr.RelayConnect(ctx, url); err == nil {
		t.Fatal("a connection over the ceiling was let in")
	}
	l.diskLow.Store(true)
	if err := publish(t, r, wrap(t, addr(), nil)); err == nil {
		t.Fatal("a wrap was taken with the disk low")
	}
	l.diskLow.Store(false)
	if err := publish(t, r, wrap(t, addr(), nil)); err != nil {
		t.Fatal(err)
	}
}
