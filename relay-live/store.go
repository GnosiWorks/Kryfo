package main

// the store runs in wal mode, so a save never waits for a reader: a page
// streaming to a slow phone holds up no one. the wal sits next to the
// database, where free space is read, and is emptied every 30 s once no
// read holds it.

import (
	"context"
	"database/sql"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/fiatjaf/eventstore/sqlite3"
)

const (
	// ms a save waits for another writer, the driver's default
	busyTimeout     = 5000
	checkpointEvery = 30 * time.Second
)

type store struct {
	*sqlite3.SQLite3Backend
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
	db := &sqlite3.SQLite3Backend{DatabaseURL: path + sep +
		"_journal_mode=WAL&_sync=FULL&_busy_timeout=" + strconv.Itoa(busyTimeout)}
	if err := db.Init(); err != nil {
		return nil, err
	}
	ckpt, err := sql.Open("sqlite3", path+sep+"_sync=FULL&_busy_timeout=0")
	if err != nil {
		db.Close()
		return nil, err
	}
	ckpt.SetMaxOpenConns(1)
	return &store{db, ckpt}, nil
}

func (s *store) Close() {
	s.ckpt.Close()
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
