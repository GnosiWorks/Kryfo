package main

// what the relay keeps, and for how long.
//
// a gift wrap is mail in transit. once it is in the recipient's hands the
// copy here is not a backup, it is a liability - something to seize, and
// something that makes "we hold nothing useful" untrue. so:
//
//	delivered  swept an hour after it was served
//	undelivered  swept at 14 days
//
// the hour is deliberate. deleting the moment a wrap is handed over would
// lose it if the client dropped before writing to disk, so there is a window
// to ask again. the mark lives in memory: a restart forgets it and those
// wraps then wait out the 14 days instead. that fails toward keeping a
// message slightly too long rather than losing one, which is the right way
// round.

import (
	"context"
	"log"
	"strconv"
	"sync"
	"time"

	"github.com/nbd-wtf/go-nostr"
)

const (
	// how long a wrap that nobody has collected is held
	undeliveredTTL = 14 * 24 * time.Hour
	// grace between handing a wrap over and dropping our copy
	deliveredGrace = time.Hour
	sweepEvery     = 30 * time.Minute
	sweepBatch     = 5000
)

var (
	servedMu sync.Mutex
	served   = map[string]time.Time{}
)

func markServed(id string) {
	servedMu.Lock()
	if _, seen := served[id]; !seen {
		served[id] = time.Now()
	}
	servedMu.Unlock()
}

// ids handed over long enough ago to be safe to drop
func servedRipe() []string {
	cut := time.Now().Add(-deliveredGrace)
	out := []string{}
	servedMu.Lock()
	for id, at := range served {
		if at.Before(cut) {
			out = append(out, id)
		}
	}
	servedMu.Unlock()
	return out
}

func forgetServed(ids []string) {
	servedMu.Lock()
	for _, id := range ids {
		delete(served, id)
	}
	servedMu.Unlock()
}

// wrap the query so anything actually served to its owner is noted. khatru
// hands back a channel; we pass every event straight through and only
// remember that it went out.
func trackingQuery(
	inner func(context.Context, nostr.Filter) (chan *nostr.Event, error),
) func(context.Context, nostr.Filter) (chan *nostr.Event, error) {
	return func(ctx context.Context, f nostr.Filter) (chan *nostr.Event, error) {
		src, err := inner(ctx, f)
		if err != nil {
			return nil, err
		}
		out := make(chan *nostr.Event)
		go func() {
			defer close(out)
			for ev := range src {
				if ev.Kind == 1059 {
					markServed(ev.ID)
				}
				select {
				case out <- ev:
				case <-ctx.Done():
					return
				}
			}
		}()
		return out, nil
	}
}

func expiredAt(ev *nostr.Event) (time.Time, bool) {
	t := ev.Tags.Find("expiration")
	if t == nil || len(t) < 2 {
		return time.Time{}, false
	}
	sec, err := strconv.ParseInt(t[1], 10, 64)
	if err != nil {
		return time.Time{}, false
	}
	return time.Unix(sec, 0), true
}

type store interface {
	QueryEvents(context.Context, nostr.Filter) (chan *nostr.Event, error)
	DeleteEvent(context.Context, *nostr.Event) error
}

// one pass: drop what has been collected, and what nobody came for.
func sweep(ctx context.Context, db store) (int, int) {
	ripe := servedRipe()
	ripeSet := make(map[string]bool, len(ripe))
	for _, id := range ripe {
		ripeSet[id] = true
	}

	ch, err := db.QueryEvents(ctx, nostr.Filter{
		Kinds: []int{1059},
		Limit: sweepBatch,
	})
	if err != nil {
		log.Printf("sweep: query: %v", err)
		return 0, 0
	}

	now := time.Now()
	oldest := now.Add(-undeliveredTTL)
	var delivered, stale int
	var done []string

	for ev := range ch {
		drop := false
		if ripeSet[ev.ID] {
			drop = true
			delivered++
			done = append(done, ev.ID)
		} else if exp, ok := expiredAt(ev); ok && exp.Before(now) {
			drop = true
			stale++
		} else if ev.CreatedAt.Time().Before(oldest) {
			// belt and braces: a wrap with a far-off expiration still goes
			// at fourteen days. the sender does not get to decide how long
			// we carry something.
			drop = true
			stale++
		}
		if drop {
			if err := db.DeleteEvent(ctx, ev); err != nil {
				log.Printf("sweep: delete %s: %v", ev.ID[:8], err)
			}
		}
	}
	forgetServed(done)
	return delivered, stale
}

func startSweeper(db store) {
	go func() {
		// first pass shortly after boot clears whatever a restart left
		time.Sleep(2 * time.Minute)
		for {
			d, s := sweep(context.Background(), db)
			if d+s > 0 {
				log.Printf("sweep: dropped %d delivered, %d expired", d, s)
			}
			time.Sleep(sweepEvery)
		}
	}()
}
