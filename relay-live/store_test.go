package main

import (
	"context"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/fiatjaf/eventstore/sqlite3"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

func walSize(t *testing.T, path string) int64 {
	t.Helper()
	st, err := os.Stat(path + "-wal")
	if os.IsNotExist(err) {
		return 0
	}
	if err != nil {
		t.Fatal(err)
	}
	return st.Size()
}

// checkpoints until the wal is empty, which needs every read of the store
// to have ended
func emptyWAL(t *testing.T, db *store, path string) {
	t.Helper()
	end := time.Now().Add(3 * time.Second)
	for {
		if err := db.checkpoint(context.Background()); err != nil {
			t.Fatal(err)
		}
		if walSize(t, path) == 0 {
			return
		}
		if time.Now().After(end) {
			t.Fatalf("the wal still holds %d bytes", walSize(t, path))
		}
		time.Sleep(20 * time.Millisecond)
	}
}

func pragma(t *testing.T, db *store, name string) string {
	t.Helper()
	var v string
	if err := db.QueryRowContext(context.Background(), "PRAGMA "+name).Scan(&v); err != nil {
		t.Fatal(err)
	}
	return v
}

// the store opens in wal with the driver's busy wait and a synced commit,
// and one left in the rollback journal, as the box has it, comes back in
// wal with its wraps
func TestStoreOpensInWAL(t *testing.T) {
	path := filepath.Join(t.TempDir(), "relay.sqlite")
	old := &sqlite3.SQLite3Backend{DatabaseURL: path + "?_journal_mode=DELETE"}
	if err := old.Init(); err != nil {
		t.Fatal(err)
	}
	kept := wrap(t, addr(), nil)
	if err := old.SaveEvent(context.Background(), &kept); err != nil {
		t.Fatal(err)
	}
	var mode string
	if err := old.QueryRow("PRAGMA journal_mode").Scan(&mode); err != nil || mode != "delete" {
		t.Fatalf("the old store is in %q: %v", mode, err)
	}
	old.Close()

	db, err := openStore(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(db.Close)
	for name, want := range map[string]string{"journal_mode": "wal", "busy_timeout": "5000", "synchronous": "2"} {
		if got := pragma(t, db, name); got != want {
			t.Errorf("%s is %s, want %s", name, got, want)
		}
	}
	n, err := db.CountEvents(context.Background(), nostr.Filter{IDs: []string{kept.ID}})
	if err != nil || n != 1 {
		t.Fatalf("the old wrap: %d, %v", n, err)
	}
}

// a checkpoint never waits for a reader: with a page open it moves what it
// can and returns at once, and saves go on. once the page is done the wal
// is emptied
func TestCheckpointNeverWaits(t *testing.T) {
	db, path := testStore(t)
	to := addr()
	for i := 0; i < 50; i++ {
		ev := wrap(t, to, nil)
		if err := db.SaveEvent(context.Background(), &ev); err != nil {
			t.Fatal(err)
		}
	}
	if walSize(t, path) == 0 {
		t.Fatal("nothing in the wal")
	}

	ctx, cancel := context.WithCancel(context.Background())
	ch, err := db.QueryEvents(ctx, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}})
	if err != nil {
		t.Fatal(err)
	}
	<-ch
	t0 := time.Now()
	if err := db.checkpoint(context.Background()); err != nil {
		t.Fatal(err)
	}
	if d := time.Since(t0); d > 2*time.Second {
		t.Fatalf("a checkpoint waited %v for a reader", d)
	}
	ev := wrap(t, to, nil)
	t0 = time.Now()
	if err := db.SaveEvent(context.Background(), &ev); err != nil {
		t.Fatal(err)
	}
	if d := time.Since(t0); d > 2*time.Second {
		t.Fatalf("a save waited %v", d)
	}
	if walSize(t, path) == 0 {
		t.Fatal("the wal was emptied under an open read")
	}
	cancel()
	for range ch {
	}
	emptyWAL(t, db, path)
}

// the free space recheck counts at least what saves write to the wal, so
// the floor holds while a long read keeps the wal from being emptied
func TestRecheckCountsTheWAL(t *testing.T) {
	db, path := testStore(t)
	relay := khatru.NewRelay()
	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	l := applyLimits(relay, "")
	// counts without the poll, which would start the count over
	l.dataDir = filepath.Dir(path)
	srv := httptest.NewServer(relay)
	t.Cleanup(srv.Close)
	r := connect(t, "ws"+strings.TrimPrefix(srv.URL, "http"))

	emptyWAL(t, db, path)
	for i := 0; i < 50; i++ {
		if err := publish(t, r, wrap(t, addr(), nil)); err != nil {
			t.Fatal(err)
		}
	}
	wal, counted := walSize(t, path), l.written.Load()
	if counted < wal {
		t.Fatalf("50 wraps wrote %d bytes to the wal, the recheck counted %d", wal, counted)
	}
}

// the ceiling counts at least what a wrap takes in the store, tags written
// as json, escapes and all
func TestStoredSizeCoversTheRow(t *testing.T) {
	db, _ := testStore(t)
	to := addr()
	for name, mod := range map[string]func(*nostr.Event){
		"plain":      nil,
		"a slice":    func(e *nostr.Event) { e.Content = strings.Repeat("s", 40<<10) },
		"empty tags": func(e *nostr.Event) { e.Tags = append(e.Tags, nostr.Tags{{}, {}, {}, {}, {}, {}, {}}...) },
		"escapes": func(e *nostr.Event) {
			s := strings.Repeat("<\x01", 1<<10)
			for len(e.Tags) < maxTags {
				e.Tags = append(e.Tags, nostr.Tag{s, s, s, s})
			}
		},
	} {
		ev := wrap(t, to, mod)
		if err := db.SaveEvent(context.Background(), &ev); err != nil {
			t.Fatal(err)
		}
		var row int
		err := db.QueryRowContext(context.Background(), `SELECT length(CAST(id AS BLOB)) + length(CAST(pubkey AS BLOB))
			+ length(CAST(sig AS BLOB)) + length(CAST(tags AS BLOB)) + length(CAST(content AS BLOB)) + 16
			FROM event WHERE id = ?`, ev.ID).Scan(&row)
		if err != nil {
			t.Fatal(err)
		}
		if n := storedSize(&ev); n < row {
			t.Errorf("%s: counted %d, the row holds %d", name, n, row)
		}
	}
}
