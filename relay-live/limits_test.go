package main

import (
	"context"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/fiatjaf/eventstore/slicestore"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

// a real relay with the limits on, over a real websocket
func testRelay(t *testing.T) (string, *limits) {
	t.Helper()
	url, l, _ := testRelayCounted(t)
	return url, l
}

// the same, and a count of the queries that reached the store
func testRelayCounted(t *testing.T) (string, *limits, *atomic.Int64) {
	t.Helper()
	relay := khatru.NewRelay()
	db := &slicestore.SliceStore{}
	if err := db.Init(); err != nil {
		t.Fatal(err)
	}
	var queries atomic.Int64
	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, func(ctx context.Context, f nostr.Filter) (chan *nostr.Event, error) {
		queries.Add(1)
		return db.QueryEvents(ctx, f)
	})
	relay.DeleteEvent = append(relay.DeleteEvent, db.DeleteEvent)
	l := applyLimits(relay, "")
	srv := httptest.NewServer(relay)
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http"), l, &queries
}

// every open connection's event budget, with no refill
func setEventBudget(l *limits, n float64) {
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, b := range l.conns {
		b.events = newBucket(0, n)
	}
}

// sets the refill of every open connection's events, keeping what is left
func setEventRefill(l *limits, perSec float64) {
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, b := range l.conns {
		b.events.perSec = perSec
	}
}

func connect(t *testing.T, url string) *nostr.Relay {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	// left open: go-nostr's Close races with its own write loop
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
	// the app's liveness probe: its own address, nothing stored, nothing
	// older than now
	now := nostr.Now()
	got, why = ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}},
		Since: &now, LimitZero: true})
	if why != "" || len(got) != 0 {
		t.Fatalf("probe: got %d, closed %q", len(got), why)
	}
	// older builds probe with an id that matches nothing
	got, why = ask(t, r, nostr.Filter{IDs: []string{strings.Repeat("0", 64)}, Limit: 1})
	if why != "" || len(got) != 0 {
		t.Fatalf("older probe: got %d, closed %q", len(got), why)
	}
	// the pair code's wrap carries an expiration beside its address
	exp := wrap(t, to, func(e *nostr.Event) {
		e.Tags = append(e.Tags, nostr.Tag{"expiration", "9999999999"})
	})
	if err := publish(t, r, exp); err != nil {
		t.Fatal(err)
	}
	// as many tags as a wrap may carry, each as long as it may be
	full := wrap(t, to, func(e *nostr.Event) {
		e.Tags = nostr.Tags{{"p", to, "wss://relay.example", "x"}}
		for len(e.Tags) < maxTags {
			e.Tags = append(e.Tags, nostr.Tag{"x", "a", "b", "c"})
		}
	})
	if err := publish(t, r, full); err != nil {
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
		"too many tags": func(e *nostr.Event) {
			for len(e.Tags) <= maxTags {
				e.Tags = append(e.Tags, nostr.Tag{})
			}
		},
		"a long tag": func(e *nostr.Event) { e.Tags = append(e.Tags, make(nostr.Tag, maxTagLen+1)) },
	} {
		if err := publish(t, r, wrap(t, to, mod)); err == nil {
			t.Errorf("%s was taken", name)
		}
	}
}

// a phone whose clock runs fast still delivers, up to the slack and no
// further
func TestClockSlack(t *testing.T) {
	url, _ := testRelay(t)
	r := connect(t, url)
	to := addr()
	slack := nostr.Timestamp(futureSlack / time.Second)
	if err := publish(t, r, wrap(t, to, func(e *nostr.Event) { e.CreatedAt = nostr.Now() + slack - 60 })); err != nil {
		t.Fatalf("a wrap inside the slack was refused: %v", err)
	}
	if err := publish(t, r, wrap(t, to, func(e *nostr.Event) { e.CreatedAt = nostr.Now() + slack + 60 })); err == nil {
		t.Fatal("a wrap past the slack was taken")
	}
	if futureSlack > 2*time.Hour {
		t.Fatalf("the slack is %s, a wrap should not sit further ahead than 2h", futureSlack)
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
		// limit 0 asks only for what comes next, and is checked the same way
		"everything, limit 0":         {LimitZero: true},
		"every wrap, limit 0":         {Kinds: []int{wrapKind}, LimitZero: true},
		"by author, limit 0":          {Kinds: []int{wrapKind}, Authors: []string{to}, LimitZero: true},
		"too many addresses, limit 0": {Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": many}, LimitZero: true},
	} {
		got, why := ask(t, r, f)
		if why == "" || len(got) != 0 {
			t.Errorf("%s: got %d, closed %q", name, len(got), why)
		}
	}
}

func TestEventsArePacedPerConnection(t *testing.T) {
	url, l := testRelay(t)
	r := connect(t, url)
	to := addr()
	if err := publish(t, r, wrap(t, to, nil)); err != nil {
		t.Fatal(err)
	}
	// no refill while the loop runs, however long it takes
	setEventRefill(l, 0)
	taken := 1
	for i := 0; i < eventBurst+50; i++ {
		if publish(t, r, wrap(t, to, nil)) == nil {
			taken++
		}
	}
	if taken != eventBurst {
		t.Fatalf("took %d of %d, burst is %d", taken, eventBurst+51, eventBurst)
	}
	// and the refill brings it back
	setEventRefill(l, eventsPerSec)
	time.Sleep(300 * time.Millisecond)
	if err := publish(t, r, wrap(t, to, nil)); err != nil {
		t.Fatalf("after the refill: %v", err)
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
	// the app's limit 0 probe spends from the same budget
	r = connect(t, url)
	now := nostr.Now()
	probe := nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {addr()}}, Since: &now, LimitZero: true}
	refused = 0
	for i := 0; i < reqBurst+10; i++ {
		if _, why := ask(t, r, probe); why != "" {
			refused++
		}
	}
	if refused == 0 {
		t.Fatal("no limit 0 req was refused past the burst")
	}
}

// a limit 0 req for an address hears new wraps to that address and no other
func TestLimitZeroHearsItsOwnAddress(t *testing.T) {
	url, _ := testRelay(t)
	r := connect(t, url)
	to, other := addr(), addr()
	now := nostr.Now()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	sub, err := r.Subscribe(ctx, nostr.Filters{{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Since: &now, LimitZero: true}})
	if err != nil {
		t.Fatal(err)
	}
	defer sub.Unsub()
	select {
	case <-sub.EndOfStoredEvents:
	case why := <-sub.ClosedReason:
		t.Fatalf("closed %q", why)
	case <-ctx.Done():
		t.Fatal("no eose")
	}
	w := connect(t, url)
	if err := publish(t, w, wrap(t, other, func(e *nostr.Event) { e.CreatedAt = nostr.Now() })); err != nil {
		t.Fatal(err)
	}
	mine := wrap(t, to, func(e *nostr.Event) { e.CreatedAt = nostr.Now() })
	if err := publish(t, w, mine); err != nil {
		t.Fatal(err)
	}
	select {
	case ev := <-sub.Events:
		if ev.ID != mine.ID {
			t.Fatalf("heard a wrap to another address")
		}
	case <-ctx.Done():
		t.Fatal("the wrap to its address never came")
	}
}

// a kind 5 is refused before any lookup, costs one from the connection like
// any event, and removes nothing
func TestKindFiveIsPacedAndLooksNothingUp(t *testing.T) {
	url, l, queries := testRelayCounted(t)
	r := connect(t, url)
	sk := nostr.GeneratePrivateKey()
	pk, _ := nostr.GetPublicKey(sk)
	to := addr()
	kept := nostr.Event{Kind: wrapKind, CreatedAt: nostr.Now() - 3600, Content: "sealed", Tags: nostr.Tags{{"p", to}}}
	if err := kept.Sign(sk); err != nil {
		t.Fatal(err)
	}
	if err := publish(t, r, kept); err != nil {
		t.Fatal(err)
	}
	tags := nostr.Tags{{"e", kept.ID}, {"a", "1059:" + pk + ":"}}
	for i := 0; i < 200; i++ {
		tags = append(tags, nostr.Tag{"e", addr()}, nostr.Tag{"a", "1059:" + addr() + ":"})
	}
	del := nostr.Event{Kind: 5, CreatedAt: nostr.Now(), Tags: tags}
	if err := del.Sign(sk); err != nil {
		t.Fatal(err)
	}
	setEventBudget(l, 2)
	queries.Store(0)
	for i, want := range []string{"gift wraps", "gift wraps", "rate-limited"} {
		err := publish(t, r, del)
		if err == nil || !strings.Contains(err.Error(), want) {
			t.Fatalf("kind 5 #%d: %v, want %q", i+1, err, want)
		}
	}
	if n := queries.Load(); n != 0 {
		t.Fatalf("%d store lookups for kind 5", n)
	}
	if err := publish(t, r, wrap(t, to, nil)); err == nil || !strings.Contains(err.Error(), "rate-limited") {
		t.Fatalf("a wrap after the budget ran out: %v", err)
	}
	got, why := ask(t, connect(t, url), nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}})
	if why != "" || len(got) != 1 || got[0].ID != kept.ID {
		t.Fatalf("got %d, closed %q", len(got), why)
	}
}

// stored bytes have one ceiling for everyone, and reads go on under it
func TestStoredBytesHaveOneCeiling(t *testing.T) {
	url, l := testRelay(t)
	r := connect(t, url)
	to := addr()
	first := wrap(t, to, nil)
	size := storedSize(&first)
	l.mu.Lock()
	l.stored = newBucket(0, float64(3*size))
	l.mu.Unlock()
	for i, w := range []nostr.Event{first, wrap(t, to, nil), wrap(t, to, nil)} {
		if err := publish(t, r, w); err != nil {
			t.Fatalf("wrap %d: %v", i+1, err)
		}
	}
	if err := publish(t, r, wrap(t, to, nil)); err == nil || !strings.Contains(err.Error(), "busy") {
		t.Fatalf("a wrap past the ceiling: %v", err)
	}
	if err := publish(t, connect(t, url), wrap(t, to, nil)); err == nil {
		t.Fatal("a second connection stored past the ceiling")
	}
	got, why := ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}})
	if why != "" || len(got) != 3 {
		t.Fatalf("got %d, closed %q", len(got), why)
	}
}

// free space is read again once enough is written, not only on the poll
func TestFreeSpaceIsReadAgainAfterWrites(t *testing.T) {
	l := &limits{dataDir: t.TempDir()}
	if freeBytes(l.dataDir) < minFreeBytes {
		t.Skip("this disk is below the floor itself")
	}
	l.diskLow.Store(true)
	l.noteWritten(diskRecheck - 1)
	if !l.diskLow.Load() {
		t.Fatal("read again before the recheck size")
	}
	l.noteWritten(1)
	if l.diskLow.Load() {
		t.Fatal("not read again after the recheck size")
	}
	if l.written.Load() != 0 {
		t.Fatal("the count did not start over")
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
