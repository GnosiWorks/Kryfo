package main

// the knock table: a hash of the address, the endpoint, the signed time and
// the expiry. a forget is a row with no endpoint, kept for the skew window.
// registrations go through one goroutine in batches, never waited on under
// the knocker's lock, so a slow disk never holds up a wrap. half that queue
// is kept for them: the sweep's deletes may be skipped, a start deletes
// what expired anyway. a registration is answered first: one lost in a
// crash is sent again by the phone within days. a forget is written on its
// own connection, synced, before the relay answers it. every write keeps
// the newer of two for one address, so the two paths cannot undo each
// other. the files are the relay user's alone.

import (
	"database/sql"
	"log"
	"os"
	"sync/atomic"
	"time"
)

type knockOp struct {
	key           [32]byte
	ep            string
	made, expires int64
	// a flush marker: closed once everything before it is written
	done chan struct{}
}

type knockStore struct {
	db *sql.DB
	// forgets, written on their own connection and synced before the relay
	// answers them
	fdb     *sql.DB
	path    string
	ch      chan knockOp
	dropped atomic.Int64
}

func openKnockStore(path string) (*knockStore, error) {
	// made here first, so sqlite's -wal and -shm take its mode
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE, 0o600)
	if err != nil {
		return nil, err
	}
	f.Close()
	db, err := sql.Open("sqlite3", path+"?_journal_mode=WAL&_sync=NORMAL&_busy_timeout=5000")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	fdb, err := sql.Open("sqlite3", path+"?_journal_mode=WAL&_sync=FULL&_busy_timeout=2000")
	if err != nil {
		db.Close()
		return nil, err
	}
	fdb.SetMaxOpenConns(1)
	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS knock (
		addr BLOB PRIMARY KEY, endpoint TEXT NOT NULL,
		made INTEGER NOT NULL, expires INTEGER NOT NULL)`); err != nil {
		db.Close()
		return nil, err
	}
	for _, p := range []string{path, path + "-wal", path + "-shm"} {
		if _, err := os.Stat(p); err == nil {
			if err := os.Chmod(p, 0o600); err != nil {
				db.Close()
				return nil, err
			}
		}
	}
	return &knockStore{db: db, fdb: fdb, path: path, ch: make(chan knockOp, 1<<16)}, nil
}

// a row to write, or with made 0 to delete. never blocks: a write that
// does not fit is dropped, counted and logged, the registration stays in
// memory
func (s *knockStore) put(key [32]byte, ep string, made, expires int64) {
	if s == nil {
		return
	}
	select {
	case s.ch <- knockOp{key: key, ep: ep, made: made, expires: expires}:
	default:
		s.drop()
	}
}

// a delete for something expired: only into the lower half of the queue
func (s *knockStore) putSweep(key [32]byte) {
	if s == nil || len(s.ch) >= cap(s.ch)/2 {
		return
	}
	select {
	case s.ch <- knockOp{key: key}:
	default:
	}
}

var lastDropLog atomic.Int64

func (s *knockStore) drop() {
	n := s.dropped.Add(1)
	now := time.Now().Unix()
	if last := lastDropLog.Load(); now-last >= 60 && lastDropLog.CompareAndSwap(last, now) {
		log.Printf("knock: the table writer is behind, %d writes dropped", n)
	}
}

func (s *knockStore) droppedSwap() int64 {
	if s == nil {
		return 0
	}
	return s.dropped.Swap(0)
}

func (s *knockStore) start() {
	go func() {
		for op := range s.ch {
			batch := []knockOp{op}
		more:
			for len(batch) < 512 {
				select {
				case o, ok := <-s.ch:
					if !ok {
						break more
					}
					batch = append(batch, o)
				default:
					break more
				}
			}
			s.write(batch)
		}
	}()
}

func (s *knockStore) write(batch []knockOp) {
	tx, err := s.db.Begin()
	if err == nil {
		for _, op := range batch {
			if op.done != nil && op.made == 0 && op.ep == "" && op.key == ([32]byte{}) {
				continue
			}
			if op.made == 0 {
				_, err = tx.Exec(`DELETE FROM knock WHERE addr = ?`, op.key[:])
			} else {
				_, err = tx.Exec(`INSERT INTO knock (addr, endpoint, made, expires) VALUES (?, ?, ?, ?)
					ON CONFLICT(addr) DO UPDATE SET endpoint = excluded.endpoint, made = excluded.made, expires = excluded.expires
					WHERE excluded.made > knock.made`,
					op.key[:], op.ep, op.made, op.expires)
			}
			if err != nil {
				break
			}
		}
		if err == nil {
			err = tx.Commit()
		} else {
			tx.Rollback()
		}
	}
	if err != nil {
		// counted, never the row: the registrations stay in memory
		log.Printf("knock: table write of %d rows: %v", len(batch), err)
	}
	for _, op := range batch {
		if op.done != nil {
			close(op.done)
		}
	}
}

// waits until everything put before it is written
func (s *knockStore) flush(wait time.Duration) bool {
	if s == nil {
		return true
	}
	done := make(chan struct{})
	select {
	case s.ch <- knockOp{done: done}:
	case <-time.After(wait):
		return false
	}
	select {
	case <-done:
		return true
	case <-time.After(wait):
		return false
	}
}

// a forget, on disk before this returns; it wins a tie with a
// registration of the same second
func (s *knockStore) writeForget(key [32]byte, made, expires int64) error {
	if s == nil {
		return nil
	}
	_, err := s.fdb.Exec(`INSERT INTO knock (addr, endpoint, made, expires) VALUES (?, '', ?, ?)
		ON CONFLICT(addr) DO UPDATE SET endpoint = '', made = excluded.made, expires = excluded.expires
		WHERE excluded.made >= knock.made`, key[:], made, expires)
	if err != nil {
		log.Printf("knock: a forget not written: %v", err)
	}
	return err
}

func (s *knockStore) close() {
	if s == nil {
		return
	}
	s.fdb.Close()
	s.db.Close()
}

// what was registered before a restart, the expired left out and deleted.
// runs before the writer starts
func (k *knocker) load() error {
	if k.store == nil {
		return nil
	}
	db := k.store.db
	now := k.now().Unix()
	if _, err := db.Exec(`DELETE FROM knock WHERE expires <= ?`, now); err != nil {
		return err
	}
	rows, err := db.Query(`SELECT addr, endpoint, made, expires FROM knock`)
	if err != nil {
		return err
	}
	defer rows.Close()
	k.mu.Lock()
	defer k.mu.Unlock()
	for rows.Next() {
		var a []byte
		var ep string
		var made, exp int64
		if err := rows.Scan(&a, &ep, &made, &exp); err != nil {
			return err
		}
		if len(a) != 32 {
			continue
		}
		var key [32]byte
		copy(key[:], a)
		if ep == "" {
			k.forgets[key] = made
			continue
		}
		if !k.endpointOK(ep) {
			continue
		}
		k.setLocked(key, ep, made, exp)
		// across a restart, an endpoint a day old counts as proven
		if e := k.eps[ep]; e != nil && k.now().Sub(e.born) >= knockTrustAfter {
			e.delivered = true
			k.settledLocked(e)
		}
	}
	return rows.Err()
}
