package main

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"github.com/nbd-wtf/go-nostr"
)

// a store at path holding n wraps past fourteen days, written without fsync
// and closed again
func fillExpired(t *testing.T, path string, n int) {
	t.Helper()
	db, err := openStore(path + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	to := addr()
	old := nostr.Now() - nostr.Timestamp(wrapTTL/time.Second) - 60
	for i := 0; i < n; i++ {
		ev := wrap(t, to, func(e *nostr.Event) { e.CreatedAt = old - nostr.Timestamp(i) })
		if err := db.SaveEvent(context.Background(), &ev); err != nil {
			t.Fatal(err)
		}
	}
}

func countLeft(t *testing.T, db interface {
	CountEvents(context.Context, nostr.Filter) (int64, error)
}) (expired, all int64) {
	t.Helper()
	ctx := context.Background()
	cut := nostr.Timestamp(time.Now().Add(-wrapTTL).Unix())
	expired, err := db.CountEvents(ctx, nostr.Filter{Until: &cut})
	if err != nil {
		t.Fatal(err)
	}
	all, err = db.CountEvents(ctx, nostr.Filter{})
	if err != nil {
		t.Fatal(err)
	}
	return expired, all
}

// on the store the relay runs, one sweep deletes every expired wrap however
// many batches they fill, and keeps the rest
func TestSweepEmptiesEveryBatch(t *testing.T) {
	path := filepath.Join(t.TempDir(), "relay.sqlite")
	expired := sweepBatch*2 + 7
	fillExpired(t, path, expired)
	db, err := openStore(path + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(db.Close)
	ctx := context.Background()
	for i := 0; i < 5; i++ {
		ev := wrap(t, addr(), nil)
		if err := db.SaveEvent(ctx, &ev); err != nil {
			t.Fatal(err)
		}
	}
	if n := sweep(ctx, db, 0); n != expired {
		t.Fatalf("swept %d of %d", n, expired)
	}
	if left, all := countLeft(t, db); left != 0 || all != 5 {
		t.Fatalf("%d expired left, %d in all, want 0 and 5", left, all)
	}
	if n := sweep(ctx, db, 0); n != 0 {
		t.Fatalf("a second sweep found %d", n)
	}
}

// on the store as the relay opens it, synced, saves and reads go on through
// a sweep of several batches: each waits about one batch, never the sweep
func TestSavesAndReadsGoOnDuringASweep(t *testing.T) {
	path := filepath.Join(t.TempDir(), "relay.sqlite")
	expired := sweepBatch*2 + 7
	fillExpired(t, path, expired)
	db, err := openStore(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(db.Close)
	ctx := context.Background()

	start := time.Now()
	done := make(chan int, 1)
	go func() { done <- sweep(ctx, db, sweepPause) }()

	to := addr()
	byAddr := nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}}
	var worst time.Duration
	saves, swept := 0, -1
	for swept < 0 {
		select {
		case swept = <-done:
		case <-time.After(20 * time.Millisecond):
		}
		ev := wrap(t, to, nil)
		t0 := time.Now()
		if err := db.SaveEvent(ctx, &ev); err != nil {
			t.Fatalf("save %d: %v", saves+1, err)
		}
		if _, err := db.CountEvents(ctx, byAddr); err != nil {
			t.Fatalf("read %d: %v", saves+1, err)
		}
		if d := time.Since(t0); d > worst {
			worst = d
		}
		saves++
	}
	took := time.Since(start)

	if swept != expired {
		t.Fatalf("swept %d of %d", swept, expired)
	}
	if took < 2*sweepPause {
		t.Fatalf("three batches in %v, want a pause between each", took)
	}
	if saves < 10 {
		t.Fatalf("only %d saves during the sweep", saves)
	}
	if worst > time.Second {
		t.Fatalf("a save and read took %v during the sweep", worst)
	}
	if left, all := countLeft(t, db); left != 0 || all != int64(saves) {
		t.Fatalf("%d expired left, %d in all, want 0 and %d", left, all, saves)
	}
}
