package main

import (
	"context"
	"path/filepath"
	"strings"
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

func sliceWrap(t *testing.T, to string) nostr.Event {
	return wrap(t, to, func(e *nostr.Event) { e.Content = strings.Repeat("s", bigContent+1) })
}

func marks(t *testing.T, db *store) int {
	t.Helper()
	var n int
	if err := db.DB.QueryRow(`SELECT count(*) FROM big_wrap`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

// a file slice is marked as it is saved and goes a week after it came;
// a text of the same age stays for its fourteen days
func TestFileSlicesGoAfterAWeek(t *testing.T) {
	db, err := openStore(filepath.Join(t.TempDir(), "relay.sqlite") + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(db.Close)
	ctx := context.Background()
	to := addr()
	small := wrap(t, to, nil)
	old, fresh := sliceWrap(t, to), sliceWrap(t, to)
	for _, ev := range []*nostr.Event{&small, &old, &fresh} {
		if err := db.SaveEvent(ctx, ev); err != nil {
			t.Fatal(err)
		}
	}
	if n := marks(t, db); n != 2 {
		t.Fatalf("%d marks, want the two slices", n)
	}
	eight := time.Now().Add(-8 * 24 * time.Hour).Unix()
	if _, err := db.DB.Exec(`UPDATE big_wrap SET at = ? WHERE id = ?`, eight, old.ID); err != nil {
		t.Fatal(err)
	}
	if n := sweepBig(ctx, db, 0); n != 1 {
		t.Fatalf("swept %d, want the old slice", n)
	}
	left, err := db.CountEvents(ctx, nostr.Filter{IDs: []string{small.ID, old.ID, fresh.ID}})
	if err != nil {
		t.Fatal(err)
	}
	if left != 2 || marks(t, db) != 1 {
		t.Fatalf("%d wraps and %d marks left, want 2 and 1", left, marks(t, db))
	}
	gone, _ := db.CountEvents(ctx, nostr.Filter{IDs: []string{old.ID}})
	if gone != 0 {
		t.Fatal("the old slice is still there")
	}
}

// more marks than a batch go in one sweep
func TestFileSliceSweepBatches(t *testing.T) {
	db, err := openStore(filepath.Join(t.TempDir(), "relay.sqlite") + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(db.Close)
	ctx := context.Background()
	to := addr()
	want := sweepBatch + 3
	for i := 0; i < want; i++ {
		ev := sliceWrap(t, to)
		if err := db.SaveEvent(ctx, &ev); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := db.DB.Exec(`UPDATE big_wrap SET at = ?`, time.Now().Add(-8*24*time.Hour).Unix()); err != nil {
		t.Fatal(err)
	}
	if n := sweepBig(ctx, db, 0); n != want {
		t.Fatalf("swept %d of %d", n, want)
	}
	if marks(t, db) != 0 {
		t.Fatal("marks left")
	}
}
