package main

import (
	"context"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/fasthttp/websocket"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

// n wraps of size bytes to one address, in the store
func fillWraps(t *testing.T, db *store, to string, n, size int) {
	t.Helper()
	for i := 0; i < n; i++ {
		ev := wrap(t, to, func(e *nostr.Event) {
			e.Content = strings.Repeat("s", size)
			e.CreatedAt = nostr.Now() - 3600 - nostr.Timestamp(i)
		})
		if err := db.SaveEvent(context.Background(), &ev); err != nil {
			t.Fatal(err)
		}
	}
}

func pageFilter(to string) nostr.Filter {
	return nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Limit: 100}
}

func waitFor(t *testing.T, what string, within time.Duration, ok func() bool) {
	t.Helper()
	end := time.Now().Add(within)
	for !ok() {
		if time.Now().After(end) {
			t.Fatalf("%s: not after %v", what, within)
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// a socket that asks for many pages and stops reading keeps one page in
// memory, and the rest hold neither memory nor a store connection
func TestOnePageAtATimePerConnection(t *testing.T) {
	db, _ := testStore(t)
	url, l := slowRelay(t, db, func(r *khatru.Relay) { r.WriteWait = time.Minute })
	to := addr()
	fillWraps(t, db, to, 40, 80<<10)
	base := liveHeap()
	c := dialSlow(t, url)
	for i := 0; i < 20; i++ {
		sendReq(t, c, "p"+string(rune('a'+i)), pageFilter(to))
	}
	if _, err := readNext(c, 5*time.Second); err != nil {
		t.Fatal(err)
	}
	time.Sleep(time.Second)
	page := 40 * pageSize(&nostr.Event{Content: strings.Repeat("s", 80<<10), Tags: nostr.Tags{{"p", to}}})
	if held := l.pages.inUse(); held > page {
		t.Fatalf("%d MB of pages held, one page is %d MB", held>>20, page>>20)
	}
	if grew := liveHeap() - base; grew > 3*page {
		t.Fatalf("the heap grew %d MB for one socket, one page is %d MB", grew>>20, page>>20)
	}
	if n := db.Stats().InUse; n != 0 {
		t.Fatalf("%d store connections held by waiting pages", n)
	}
}

// pages of all sockets together stay under one budget, passed by at most
// what the reads under way bring. a page past it waits before its query,
// and goes once another page is let go
func TestPagesShareOneBudget(t *testing.T) {
	db, _ := testStore(t)
	url, l := slowRelay(t, db, func(r *khatru.Relay) { r.WriteWait = time.Minute })
	const wraps, size = 40, 60 << 10
	one := wraps * pageSize(&nostr.Event{Content: strings.Repeat("s", size), Tags: nostr.Tags{{"p", addr()}}})
	l.pages.max = 2*one + one/4
	l.reads.max = 2 * pageReserve(pageFilter(addr()))
	waiting := func(pages, reads int) func() bool {
		return func() bool {
			l.pages.mu.Lock()
			p := len(l.pages.waiting)
			l.pages.mu.Unlock()
			l.reads.mu.Lock()
			r := len(l.reads.waiting)
			l.reads.mu.Unlock()
			return p == pages && r == reads
		}
	}
	bound := func() {
		t.Helper()
		if held := l.pages.inUse(); held > l.pages.max+l.reads.max {
			t.Fatalf("%d MB of pages held, the bound is %d MB", held>>20, (l.pages.max+l.reads.max)>>20)
		}
	}

	var cs []*websocket.Conn
	for i := 0; i < 6; i++ {
		to := addr()
		fillWraps(t, db, to, wraps, size)
		c := dialSlow(t, url)
		cs = append(cs, c)
		if i < 3 {
			startPage(t, c, to)
		} else {
			sendReq(t, c, "page", pageFilter(to))
		}
	}
	// three pages read, two waiting for room, one for a read
	waitFor(t, "two pages waiting for room and one for a read", 5*time.Second, waiting(2, 1))
	bound()
	if n := db.Stats().InUse; n != 0 {
		t.Fatalf("%d store connections held by waiting pages", n)
	}
	cs[0].Close()
	waitFor(t, "the waiting pages going", 5*time.Second, waiting(1, 0))
	bound()
}

// reads under way are counted at what their pages could hold: past the
// read budget a page waits before its query
type heldQuery struct {
	backend
	in      atomic.Int32
	release chan struct{}
}

func (h *heldQuery) QueryEvents(ctx context.Context, f nostr.Filter) (chan *nostr.Event, error) {
	h.in.Add(1)
	<-h.release
	return h.backend.QueryEvents(ctx, f)
}

func TestReadsShareOneBudget(t *testing.T) {
	db := &heldQuery{backend: memStore(t), release: make(chan struct{})}
	url, l := slowRelay(t, db, nil)
	l.reads.max = 2 * pageReserve(pageFilter(addr()))
	for i := 0; i < 3; i++ {
		sendReq(t, dialSlow(t, url), "page", pageFilter(addr()))
	}
	waitFor(t, "two reads under way and one waiting", 5*time.Second, func() bool {
		l.reads.mu.Lock()
		defer l.reads.mu.Unlock()
		return db.in.Load() == 2 && len(l.reads.waiting) == 1
	})
	close(db.release)
	waitFor(t, "the third read", 5*time.Second, func() bool { return db.in.Load() == 3 })
	waitFor(t, "the reads giving their budget back", 5*time.Second, func() bool { return l.reads.inUse() == 0 })
}

// a page larger than the budget still goes, alone
func TestPageLargerThanTheBudgetGoesAlone(t *testing.T) {
	b := newPageBudget(10)
	if !b.take(context.Background(), 100) {
		t.Fatal("a page larger than the budget waited with nothing held")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	if b.take(ctx, 1) {
		t.Fatal("a page went past a full budget")
	}
	b.give(100)
	if !b.take(context.Background(), 5) || b.inUse() != 5 {
		t.Fatalf("held %d after a give and a take of 5", b.inUse())
	}
}

// a big page waiting is not passed over by small ones behind it
func TestPageBudgetTakesTurns(t *testing.T) {
	b := newPageBudget(10)
	b.take(context.Background(), 6)
	got := make(chan int64, 2)
	go func() { b.take(context.Background(), 8); got <- 8 }()
	waitFor(t, "the big page waiting", time.Second, func() bool {
		b.mu.Lock()
		defer b.mu.Unlock()
		return len(b.waiting) == 1
	})
	go func() { b.take(context.Background(), 3); got <- 3 }()
	select {
	case n := <-got:
		t.Fatalf("a page of %d went first", n)
	case <-time.After(200 * time.Millisecond):
	}
	b.give(6)
	if n := <-got; n != 8 {
		t.Fatalf("a page of %d went first", n)
	}
}

// a wrap saved while a page is being read reaches the reader: in the page
// or live, after the eose
type pausedQuery struct {
	backend
	paused          atomic.Bool
	reading, resume chan struct{}
}

func (p *pausedQuery) QueryEvents(ctx context.Context, f nostr.Filter) (chan *nostr.Event, error) {
	ch, err := p.backend.QueryEvents(ctx, f)
	if err != nil {
		return nil, err
	}
	var page []*nostr.Event
	for ev := range ch {
		page = append(page, ev)
	}
	if f.Limit > 0 && p.paused.CompareAndSwap(false, true) {
		close(p.reading)
		<-p.resume
	}
	out := make(chan *nostr.Event, len(page))
	for _, ev := range page {
		out <- ev
	}
	close(out)
	return out, nil
}

func TestWrapSavedDuringAPageReadIsNotMissed(t *testing.T) {
	db := &pausedQuery{backend: memStore(t), reading: make(chan struct{}), resume: make(chan struct{})}
	url, _ := slowRelay(t, db, nil)
	to := addr()
	c := dialSlow(t, url)
	sendReq(t, c, "page", pageFilter(to))
	<-db.reading
	ev := wrap(t, to, nil)
	if err := publish(t, connect(t, url), ev); err != nil {
		t.Fatal(err)
	}
	close(db.resume)
	for {
		env, err := readNext(c, 5*time.Second)
		if err != nil {
			t.Fatalf("the wrap saved during the read never came: %v", err)
		}
		if e, ok := env.(*nostr.EventEnvelope); ok && e.Event.ID == ev.ID {
			return
		}
	}
}

// a request refused for one filter keeps no listener for any of them
func TestRefusedRequestKeepsNoListener(t *testing.T) {
	var relay *khatru.Relay
	url, _ := slowRelay(t, memStore(t), func(r *khatru.Relay) { relay = r })
	c := dialSlow(t, url)
	b, err := nostr.ReqEnvelope{SubscriptionID: "both", Filters: nostr.Filters{
		pageFilter(addr()),
		{Kinds: []int{1}},
	}}.MarshalJSON()
	if err != nil {
		t.Fatal(err)
	}
	if err := c.WriteMessage(websocket.TextMessage, b); err != nil {
		t.Fatal(err)
	}
	for {
		env, err := readNext(c, 5*time.Second)
		if err != nil {
			t.Fatal(err)
		}
		if _, ok := env.(*nostr.ClosedEnvelope); ok {
			break
		}
	}
	if n := len(relay.GetListeningFilters()); n != 0 {
		t.Fatalf("%d listeners left by a refused request", n)
	}
}

// the largest wrap nip-44 makes is taken, a message far past it ends the
// connection
func TestMessageSizeBound(t *testing.T) {
	url, _ := testRelay(t)
	ok := wrap(t, addr(), func(e *nostr.Event) { e.Content = strings.Repeat("s", 87472) })
	if err := publish(t, connect(t, url), ok); err != nil {
		t.Fatalf("the largest wrap the app sends was refused: %v", err)
	}
	big := wrap(t, addr(), func(e *nostr.Event) { e.Content = strings.Repeat("s", 140<<10) })
	b, err := nostr.EventEnvelope{Event: big}.MarshalJSON()
	if err != nil {
		t.Fatal(err)
	}
	c := dialSlow(t, url)
	if err := c.WriteMessage(websocket.TextMessage, b); err != nil {
		return
	}
	if _, err := readNext(c, 5*time.Second); err == nil {
		t.Fatal("a message past the bound was answered")
	}
}

// a save goes through while every read connection is taken
func TestSavesDoNotWaitForReads(t *testing.T) {
	defer func(n int) { storeConns = n }(storeConns)
	storeConns = 1
	db, _ := testStore(t)
	conn, err := db.SQLite3Backend.DB.Conn(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	ev := wrap(t, addr(), nil)
	if err := db.SaveEvent(ctx, &ev); err != nil {
		t.Fatalf("a save waited for the read connections: %v", err)
	}
	if n := sweep(ctx, db, 0); n != 0 {
		t.Fatalf("the sweep dropped %d fresh wraps", n)
	}
	if ctx.Err() != nil {
		t.Fatal("the sweep waited for the read connections")
	}
	// and through the relay, whose lookups before a save need no store read
	url, _ := slowRelay(t, db, nil)
	if d := publishTimed(t, connect(t, url), wrap(t, addr(), nil)); d >= 2*time.Second {
		t.Fatalf("an ok took %v while the reads were taken", d)
	}
}
