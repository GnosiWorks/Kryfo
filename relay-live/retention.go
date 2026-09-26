package main

// the relay is a post box, not an archive. wraps go at fourteen days.
// dmrelay/ is not a drop-in: it gates reads with nip-42, which the app does
// not speak yet. no delivery tracking either, wrapping the store's channel
// leaves its iterator open when khatru stops draining early.

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

	// drain the channel before deleting: the store keeps a cursor open until
	// then, and deleting mid-read holds two locks on the same table.
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
		// wait out the reconnect burst after a restart
		time.Sleep(3 * time.Minute)
		for {
			if n := sweep(context.Background(), db); n > 0 {
				log.Printf("sweep: dropped %d wraps older than 14 days", n)
			}
			time.Sleep(sweepEvery)
		}
	}()
}
