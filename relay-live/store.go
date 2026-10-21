package main

// the store runs in wal mode, so a save never waits for a reader. the wal
// sits next to the database, where free space is read, and is emptied
// every 30 s once no read holds it.
//
// a page of stored wraps is read whole before it goes to the socket, so a
// slow phone holds no store connection and the pool stays small. each
// connection keeps up to 2 MB of page cache outside go's heap, and glibc
// keeps that memory after the connection closes.

import (
	"context"
	"database/sql"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/fiatjaf/eventstore/sqlite3"
	"github.com/nbd-wtf/go-nostr"
)

const (
	// ms a save waits for another writer, the driver's default
	busyTimeout     = 5000
	checkpointEvery = 30 * time.Second
)

// store connections for reads, kept open between uses. a read holds one
// only while its query runs. a catch-up scans every wrap in its window, so
// more than the cpus can run at once only helps while the disk is read
var storeConns = envInt("RELAY_STORE_CONNS", 32)

// saves, deletes and the sweep have connections of their own, so a storm
// of reads does not hold up an ok, and a burst of saves waiting on the
// write lock does not hold up reads. sqlite takes one writer at a time
var storeWriters = envInt("RELAY_STORE_WRITERS", 2)

type store struct {
	*sqlite3.SQLite3Backend
	// the same file, for writes
	w *sqlite3.SQLite3Backend
	// a connection of its own with no busy wait, for checkpoints
	ckpt *sql.DB
}

// the store as the relay runs it, its page size left at the backend's own.
// options already in path win: the driver reads the first of each.
// synchronous full keeps an ok on disk through a power cut, as the
// rollback journal did.
func openStore(path string) (*store, error) {
	sep := "?"
	if strings.Contains(path, "?") {
		sep = "&"
	}
	url := path + sep + "_journal_mode=WAL&_sync=FULL&_busy_timeout=" + strconv.Itoa(busyTimeout)
	db := &sqlite3.SQLite3Backend{DatabaseURL: url}
	if err := db.Init(); err != nil {
		return nil, err
	}
	db.DB.SetMaxOpenConns(storeConns)
	db.DB.SetMaxIdleConns(storeConns)
	w := &sqlite3.SQLite3Backend{DatabaseURL: url}
	if err := w.Init(); err != nil {
		db.Close()
		return nil, err
	}
	w.DB.SetMaxOpenConns(storeWriters)
	w.DB.SetMaxIdleConns(storeWriters)
	ckpt, err := sql.Open("sqlite3", path+sep+"_sync=FULL&_busy_timeout=0")
	if err != nil {
		w.Close()
		db.Close()
		return nil, err
	}
	ckpt.SetMaxOpenConns(1)
	return &store{db, w, ckpt}, nil
}

func (s *store) SaveEvent(ctx context.Context, ev *nostr.Event) error {
	return s.w.SaveEvent(ctx, ev)
}

func (s *store) DeleteEvent(ctx context.Context, ev *nostr.Event) error {
	return s.w.DeleteEvent(ctx, ev)
}

// writes go to the write connections: the sweep deletes through this
func (s *store) ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error) {
	return s.w.ExecContext(ctx, query, args...)
}

// a page is read to its end before the first event goes out, which gives
// its connection back at once. the store caps a page at 100 events
func (s *store) QueryEvents(ctx context.Context, f nostr.Filter) (chan *nostr.Event, error) {
	ch, err := s.SQLite3Backend.QueryEvents(ctx, f)
	if err != nil {
		return nil, err
	}
	var page []*nostr.Event
	for ev := range ch {
		page = append(page, ev)
	}
	out := make(chan *nostr.Event)
	go func() {
		defer close(out)
		for i, ev := range page {
			// sent ones are let go while the rest wait for a slow socket
			page[i] = nil
			select {
			case out <- ev:
			case <-ctx.Done():
				return
			}
		}
	}()
	return out, nil
}

func (s *store) Close() {
	s.ckpt.Close()
	s.w.Close()
	s.SQLite3Backend.Close()
}

// moves the wal into the database and empties the file. it never waits for
// a reader or a writer: it moves what it can and the next run finishes.
// the passive pass copies beside saves. truncate holds saves back while it
// copies, so it runs second, with only what came in since left to copy
func (s *store) checkpoint(ctx context.Context) error {
	var busy, frames, moved int
	for _, mode := range []string{"PASSIVE", "TRUNCATE"} {
		err := s.ckpt.QueryRowContext(ctx, "PRAGMA wal_checkpoint("+mode+")").Scan(&busy, &frames, &moved)
		if err != nil {
			return err
		}
	}
	return nil
}

func startCheckpoints(s *store) {
	go func() {
		for {
			time.Sleep(checkpointEvery)
			if err := s.checkpoint(context.Background()); err != nil {
				log.Printf("checkpoint: %v", err)
			}
		}
	}()
}
