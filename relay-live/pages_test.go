package main

import (
	"context"
	"strings"
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

func waiters(l *limits) int {
	l.pages.mu.Lock()
	defer l.pages.mu.Unlock()
	return len(l.pages.waiting)
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

// pages of all sockets together stay under one budget. a page past it
// waits before its query, and goes once another page is let go
func TestPagesShareOneBudget(t *testing.T) {
	db, _ := testStore(t)
	url, l := slowRelay(t, db, func(r *khatru.Relay) { r.WriteWait = time.Minute })
	const wraps, size = 40, 60 << 10
	one := wraps * pageSize(&nostr.Event{Content: strings.Repeat("s", size), Tags: nostr.Tags{{"p", addr()}}})
	l.pages.max = pageReserve(pageFilter(addr())) + 2*one + one/4

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
	waitFor(t, "three pages waiting", 5*time.Second, func() bool { return waiters(l) == 3 })
	if held := l.pages.inUse(); held > l.pages.max {
		t.Fatalf("%d bytes of pages held, the budget is %d", held, l.pages.max)
	}
	if n := db.Stats().InUse; n != 0 {
		t.Fatalf("%d store connections held by waiting pages", n)
	}
	cs[0].Close()
	waitFor(t, "a waiting page going", 5*time.Second, func() bool { return waiters(l) == 2 })
	if held := l.pages.inUse(); held > l.pages.max {
		t.Fatalf("%d bytes of pages held, the budget is %d", held, l.pages.max)
	}
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
