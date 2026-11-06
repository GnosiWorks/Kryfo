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
	"sync"
	"sync/atomic"
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
// only while its query runs. a catch-up the recipient index cannot answer
// scans every wrap in its window, so more than the cpus can run at once
// only helps while the disk is read
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
	// the recipient index's fill (recipients.go): wraps stamped at or
	// after below are listed, and all of them once filled
	below  atomic.Int64
	filled atomic.Bool
	stop   context.Context
	halt   context.CancelFunc
	fillWG sync.WaitGroup
	// catch-ups answered by the index and by the backend's query
	byIndex, byScan atomic.Int64
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
	if _, err := w.DB.Exec(bigWrapTable); err != nil {
		ckpt.Close()
		w.Close()
		db.Close()
		return nil, err
	}
	if _, err := w.DB.Exec(bigWrapIndex); err != nil {
		ckpt.Close()
		w.Close()
		db.Close()
		return nil, err
	}
	s := &store{SQLite3Backend: db, w: w, ckpt: ckpt}
	s.stop, s.halt = context.WithCancel(context.Background())
	if err := s.initRecipients(); err != nil {
		s.Close()
		return nil, err
	}
	return s, nil
}

// its recipient rows go with it, by the wrap_to_gone trigger
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
	page, err := s.page(ctx, f)
	if err != nil {
		return nil, err
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

// a catch-up through the recipient index when it can be sure of it, else
// the backend's query
func (s *store) page(ctx context.Context, f nostr.Filter) ([]*nostr.Event, error) {
	if s.listable(f) {
		page, err := s.pageByRecipient(ctx, f)
		if err == nil {
			s.byIndex.Add(1)
			return page, nil
		}
		if err != errUnlisted {
			return nil, err
		}
	}
	s.byScan.Add(1)
	ch, err := s.SQLite3Backend.QueryEvents(ctx, f)
	if err != nil {
		return nil, err
	}
	var page []*nostr.Event
	for ev := range ch {
		page = append(page, ev)
	}
	return page, nil
}

// a file slice's id and the day it came, for its shorter week (sweepBig).
// the day it came, not its stamp: a wrap's stamp is set back on purpose.
// the day, not the second: a copy of the disk must not tell when each
// slice came, and with that whose burst it was
const (
	bigWrapTable = `CREATE TABLE IF NOT EXISTS big_wrap (
		id TEXT PRIMARY KEY, at INTEGER NOT NULL)`
	bigWrapIndex = `CREATE INDEX IF NOT EXISTS big_wrap_at ON big_wrap(at, id)`
)

// a wrap this size is a slice of a file. the app fills a text to at most
// 27841 bytes of wrap and a slice to 55149 (mobile/lib/wire_pad.dart): the
// line sits between, so only the rare text longer than about 20000
// characters is taken for one
const bigContent = 40000

func isBig(ev *nostr.Event) bool { return len(ev.Content) > bigContent }

// the start of the utc day of t, in unix seconds
func dayOf(t time.Time) int64 { return t.Unix() / 86400 * 86400 }

// saved as the backend saves it, with its recipient rows in the same
// write, and marked when it is a file slice. a mark that fails leaves it
// the fourteen days of any wrap
func (s *store) SaveEvent(ctx context.Context, ev *nostr.Event) error {
	if err := s.saveListed(ctx, ev); err != nil {
		return err
	}
	if isBig(ev) {
		if _, err := s.w.DB.ExecContext(ctx, `INSERT OR IGNORE INTO big_wrap (id, at) VALUES (?, ?)`,
			ev.ID, dayOf(time.Now())); err != nil {
			log.Printf("store: a slice not marked: %v", err)
		}
	}
	return nil
}

func (s *store) Close() {
	s.halt()
	s.fillWG.Wait()
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
