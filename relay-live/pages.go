package main

// pages of stored wraps wait in memory until their socket takes them (see
// store.go), so what they hold is bounded: each connection keeps one page
// at a time, the pages read and waiting for their sockets are counted
// against one budget, and the reads under way against another, at what
// their pages could hold at most. a page waits for all three before its
// query, so a waiting page holds no store connection, and gives its bytes
// back as its events go out. a read starts while the pages are under
// their budget, so they pass it by at most what the reads bring: pages in
// memory stay under the two budgets together.

import (
	"context"
	"sync"

	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

// bytes of pages read and waiting for their sockets, and of pages being
// read counted at their most. a read for 100 events counts 12 MB, so the
// read budget lets 31 such reads run at once, about as many as the store has
// connections for
var (
	maxPagesBytes = int64(envInt("RELAY_MAX_PAGES_MB", 128)) << 20
	maxReadsBytes = int64(envInt("RELAY_MAX_READS_MB", 384)) << 20
)

const (
	// the store's own cap on a page
	storeLimit = 100
	// what one event can hold at most, counted as pageSize counts it
	maxEventHeld = 512 + maxMessage + maxMessage/4 + maxTags*(128+maxTagLen*(32+64))
)

// what an event holds in memory, counted high like a queued live wrap
func pageSize(ev *nostr.Event) int64 {
	n := int64(512 + len(ev.Content) + len(ev.Content)/4)
	for _, tag := range ev.Tags {
		n += 128
		for _, s := range tag {
			n += int64(32 + len(s))
		}
	}
	return n
}

// the most a page for f can hold
func pageReserve(f nostr.Filter) int64 {
	n := f.Limit
	if n < 1 || n > storeLimit {
		n = storeLimit
	}
	if len(f.IDs) > 0 && len(f.IDs) < n {
		n = len(f.IDs)
	}
	return int64(n) * maxEventHeld
}

// a byte budget taken in turn: a big page is not passed over by small ones
type pageBudget struct {
	mu      sync.Mutex
	max     int64
	held    int64
	waiting []*pageWaiter
}

type pageWaiter struct {
	n     int64
	ready chan struct{}
}

func newPageBudget(max int64) *pageBudget { return &pageBudget{max: max} }

// with mu held. what is larger than the whole budget goes when nothing
// else is held, and a take of 0 waits while the budget is passed
func (b *pageBudget) fits(n int64) bool { return b.held+n <= b.max || b.held == 0 }

// waits for n bytes, false when ctx ended first
func (b *pageBudget) take(ctx context.Context, n int64) bool {
	b.mu.Lock()
	if len(b.waiting) == 0 && b.fits(n) {
		b.held += n
		b.mu.Unlock()
		return true
	}
	w := &pageWaiter{n, make(chan struct{})}
	b.waiting = append(b.waiting, w)
	b.mu.Unlock()
	select {
	case <-w.ready:
		return true
	case <-ctx.Done():
		b.mu.Lock()
		select {
		case <-w.ready:
			// taken just as ctx ended: give it back
			b.held -= n
		default:
			for i, o := range b.waiting {
				if o == w {
					b.waiting = append(b.waiting[:i], b.waiting[i+1:]...)
					break
				}
			}
		}
		b.wakeLocked()
		b.mu.Unlock()
		return false
	}
}

// takes n at once, past the budget if need be: a page just read
func (b *pageBudget) force(n int64) {
	b.mu.Lock()
	b.held += n
	b.mu.Unlock()
}

func (b *pageBudget) give(n int64) {
	if n <= 0 {
		return
	}
	b.mu.Lock()
	b.held -= n
	b.wakeLocked()
	b.mu.Unlock()
}

func (b *pageBudget) wakeLocked() {
	for len(b.waiting) > 0 && b.fits(b.waiting[0].n) {
		w := b.waiting[0]
		b.waiting = b.waiting[1:]
		b.held += w.n
		close(w.ready)
	}
}

// bytes held now, for the tests
func (b *pageBudget) inUse() int64 {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.held
}

// the connection's page slot, nil for one not seen open
func (l *limits) pageSlot(ws *khatru.WebSocket) chan struct{} {
	l.mu.Lock()
	defer l.mu.Unlock()
	if b := l.conns[ws]; b != nil {
		return b.page
	}
	return nil
}

// a query whose page waits for its connection's slot and the budget, and
// gives both back as it goes out. the relay's own calls (expiry) pass
func (l *limits) paged(q queryFunc) queryFunc {
	return func(ctx context.Context, f nostr.Filter) (chan *nostr.Event, error) {
		ws := khatru.GetConnection(ctx)
		if ws == nil || khatru.IsInternalCall(ctx) {
			return q(ctx, f)
		}
		slot := l.pageSlot(ws)
		if slot == nil {
			return nil, errNotOpen
		}
		select {
		case slot <- struct{}{}:
		case <-ctx.Done():
			return nil, ctx.Err()
		}
		reserved := pageReserve(f)
		if !l.reads.take(ctx, reserved) {
			<-slot
			return nil, ctx.Err()
		}
		if !l.pages.take(ctx, 0) {
			l.reads.give(reserved)
			<-slot
			return nil, ctx.Err()
		}
		ch, err := q(ctx, f)
		if err != nil || ch == nil {
			l.reads.give(reserved)
			<-slot
			return ch, err
		}
		var page []*nostr.Event
		var held int64
		for ev := range ch {
			page = append(page, ev)
			held += pageSize(ev)
		}
		l.pages.force(held)
		l.reads.give(reserved)
		out := make(chan *nostr.Event)
		go func() {
			defer func() {
				l.pages.give(held)
				<-slot
				close(out)
			}()
			for i, ev := range page {
				page[i] = nil
				select {
				case out <- ev:
					n := pageSize(ev)
					held -= n
					l.pages.give(n)
				case <-ctx.Done():
					return
				}
			}
		}()
		return out, nil
	}
}
