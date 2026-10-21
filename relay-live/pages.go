package main

// pages of stored wraps wait in memory until their socket takes them (see
// store.go), so what they hold is bounded twice: each connection keeps one
// page at a time, and all pages together stay under one budget. a page
// waits for both before its query, so a waiting page holds no store
// connection. a page reserves what it could hold at most and gives back
// the rest once it is read, then each event as it goes out.

import (
	"context"
	"sync"

	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

// bytes of pages in memory for all connections together
var maxPagesBytes = int64(envInt("RELAY_MAX_PAGES_MB", 128)) << 20

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

// with mu held. a page larger than the whole budget goes when nothing else
// is held
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

// takes n past the budget at once: a page that came out bigger than it
// reserved, which only stored events from before a lower bound can do
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
		if !l.pages.take(ctx, reserved) {
			<-slot
			return nil, ctx.Err()
		}
		ch, err := q(ctx, f)
		if err != nil || ch == nil {
			l.pages.give(reserved)
			<-slot
			return ch, err
		}
		var page []*nostr.Event
		var held int64
		for ev := range ch {
			page = append(page, ev)
			held += pageSize(ev)
		}
		if held < reserved {
			l.pages.give(reserved - held)
		} else {
			l.pages.force(held - reserved)
		}
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
