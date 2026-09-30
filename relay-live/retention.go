package main

// the relay is a post box, not an archive. wraps go at fourteen days.
// dmrelay/ is not a drop-in: it gates reads with nip-42, which the app does
// not speak yet. no delivery tracking either, wrapping the store's channel
// leaves its iterator open when khatru stops draining early.

import (
	"context"
	"database/sql"
	"log"
	"time"
)

const (
	wrapTTL    = 14 * 24 * time.Hour
	sweepEvery = 30 * time.Minute
	// rows per delete. each delete is one write, so one wait for the lock
	// and one sync, whatever it holds
	sweepBatch = 500
	// between deletes, so saves and reads get the lock: sqlite's busy wait
	// takes no turns, and deletes back to back would keep it for the whole
	// sweep
	sweepPause = time.Second
)

type execer interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// oldest first, a batch at a time, until a batch comes back short. a failed
// delete ends it and the next sweep carries on.
func sweep(ctx context.Context, db execer, pause time.Duration) int {
	total := 0
	for {
		cut := time.Now().Add(-wrapTTL).Unix()
		res, err := db.ExecContext(ctx, `DELETE FROM event WHERE rowid IN (
			SELECT rowid FROM event WHERE created_at <= ? ORDER BY created_at LIMIT ?)`,
			cut, sweepBatch)
		if err != nil {
			log.Printf("sweep: %v", err)
			return total
		}
		n, err := res.RowsAffected()
		if err != nil {
			log.Printf("sweep: %v", err)
			return total
		}
		total += int(n)
		if n < sweepBatch {
			return total
		}
		select {
		case <-ctx.Done():
			return total
		case <-time.After(pause):
		}
	}
}

func startSweeper(db execer) {
	go func() {
		// wait out the reconnect burst after a restart
		time.Sleep(3 * time.Minute)
		for {
			if n := sweep(context.Background(), db, sweepPause); n > 0 {
				log.Printf("sweep: dropped %d wraps older than 14 days", n)
			}
			time.Sleep(sweepEvery)
		}
	}()
}
