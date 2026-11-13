package main

// what the relay keeps: every wrap goes at 14 days, delivered or not.
// dropping on delivery needs a wrapper on the query channel, and that stalls
// badger when khatru stops draining early. time alone cannot deadlock.

import (
	"context"
	"log"
	"strconv"
	"time"

	"github.com/nbd-wtf/go-nostr"
)

const (
	wrapTTL    = 14 * 24 * time.Hour
	sweepEvery = 30 * time.Minute
	sweepBatch = 5000
)

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

// one pass. the channel is drained to the end no matter what, so the store
// always gets to close its iterator.
func sweep(ctx context.Context, db store) int {
	ch, err := db.QueryEvents(ctx, nostr.Filter{
		Kinds: []int{1059},
		Limit: sweepBatch,
	})
	if err != nil {
		log.Printf("sweep: query: %v", err)
		return 0
	}

	now := time.Now()
	oldest := now.Add(-wrapTTL)
	var dead []*nostr.Event

	for ev := range ch {
		exp, ok := expiredAt(ev)
		// the created_at check is the backstop: a sender does not get to
		// decide how long we carry something by writing a distant tag.
		if (ok && exp.Before(now)) || ev.CreatedAt.Time().Before(oldest) {
			dead = append(dead, ev)
		}
	}

	// delete after the read is finished, not during it
	for _, ev := range dead {
		if err := db.DeleteEvent(ctx, ev); err != nil {
			log.Printf("sweep: delete %s: %v", ev.ID[:8], err)
		}
	}
	return len(dead)
}

func startSweeper(db store) {
	go func() {
		time.Sleep(2 * time.Minute)
		for {
			if n := sweep(context.Background(), db); n > 0 {
				log.Printf("sweep: dropped %d expired wraps", n)
			}
			time.Sleep(sweepEvery)
		}
	}()
}
