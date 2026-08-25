package main

// the relay is a post box, not an archive. wraps go at fourteen days.
//
// there is a more capable relay in dmrelay/ - badger, nip-42 gated reads,
// expiration validation - but it is not a drop-in: it only serves kind 1059
// to a client that has proved it owns the address, and the app does not
// speak nip-42 yet. deploying it over this one silently breaks every
// subscription. so retention lands here, on the relay that is actually
// running, and dmrelay waits for the engine to catch up.
//
// no query wrapping, no delivery tracking. an earlier attempt noticed
// deliveries by wrapping the store's channel, and when khatru stopped
// draining early the store never closed its iterator. time alone is enough
// to stop being an archive, and it cannot deadlock.

import (
	"context"
	"log"
	"time"

	"github.com/nbd-wtf/go-nostr"
)

const (
	wrapTTL    = 14 * 24 * time.Hour
	sweepEvery = 30 * time.Minute
	sweepBatch = 2000
)

type eventStore interface {
	QueryEvents(context.Context, nostr.Filter) (chan *nostr.Event, error)
	DeleteEvent(context.Context, *nostr.Event) error
}

func sweep(ctx context.Context, db eventStore) int {
	cut := nostr.Timestamp(time.Now().Add(-wrapTTL).Unix())
	ch, err := db.QueryEvents(ctx, nostr.Filter{
		Until: &cut,
		Limit: sweepBatch,
	})
	if err != nil {
		log.Printf("sweep: %v", err)
		return 0
	}

	// drain the whole channel before deleting anything: the store keeps a
	// cursor open until it is closed, and deleting mid-read is how you end
	// up holding two locks on the same table.
	var dead []*nostr.Event
	for ev := range ch {
		dead = append(dead, ev)
	}
	for _, ev := range dead {
		if err := db.DeleteEvent(ctx, ev); err != nil {
			log.Printf("sweep: delete %s: %v", ev.ID[:8], err)
		}
	}
	return len(dead)
}

func startSweeper(db eventStore) {
	go func() {
		// a few minutes after boot, so a restart clears the backlog without
		// competing with clients reconnecting all at once.
		time.Sleep(3 * time.Minute)
		for {
			if n := sweep(context.Background(), db); n > 0 {
				log.Printf("sweep: dropped %d wraps older than 14 days", n)
			}
			time.Sleep(sweepEvery)
		}
	}()
}
