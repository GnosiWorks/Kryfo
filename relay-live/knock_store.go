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
	// when the relay first took the endpoint
	born int64
	// marks the endpoint as having delivered, on every row naming it
	proven bool
	// a row whose endpoint delivered already
	delivered bool
	// a flush marker: closed once everything before it is written
	done chan struct{}
}

type knockStore struct {
	db *sql.DB
	// forgets, written on their own connection and synced before the relay
	// answers them: those waiting go in one transaction together
	fdb     *sql.DB
	fch     chan *forgetReq
	waiting atomic.Int64
	quit    chan struct{}
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
		made INTEGER NOT NULL, expires INTEGER NOT NULL,
		born INTEGER NOT NULL DEFAULT 0, proven INTEGER NOT NULL DEFAULT 0)`); err != nil {
		db.Close()
		return nil, err
	}
	// a table from before the two columns: they are added, an error for
	// one already there is the expected one
	for _, col := range []string{"born", "proven"} {
		db.Exec(`ALTER TABLE knock ADD COLUMN ` + col + ` INTEGER NOT NULL DEFAULT 0`)
	}
	for _, p := range []string{path, path + "-wal", path + "-shm"} {
		if _, err := os.Stat(p); err == nil {
			if err := os.Chmod(p, 0o600); err != nil {
				db.Close()
				return nil, err
			}
		}
	}
	s := &knockStore{db: db, fdb: fdb, path: path, ch: make(chan knockOp, 1<<16),
		fch: make(chan *forgetReq, knockForgetWaiters), quit: make(chan struct{})}
	go s.forgetWriter()
	return s, nil
}

// a row to write, or with made 0 to delete. never blocks: a write that
// does not fit is dropped, counted and logged, the registration stays in
// memory
func (s *knockStore) put(key [32]byte, ep string, made, expires, born int64, delivered bool) {
	if s == nil {
		return
	}
	select {
	case s.ch <- knockOp{key: key, ep: ep, made: made, expires: expires, born: born, delivered: delivered}:
	default:
		s.drop()
	}
}

// an endpoint delivered: so it keeps its age across a restart
func (s *knockStore) proven(ep string) {
	if s == nil {
		return
	}
	select {
	case s.ch <- knockOp{ep: ep, proven: true}:
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
			if op.proven {
				_, err = tx.Exec(`UPDATE knock SET proven = 1 WHERE endpoint = ?`, op.ep)
			} else if op.made == 0 {
				_, err = tx.Exec(`DELETE FROM knock WHERE addr = ?`, op.key[:])
			} else {
				_, err = tx.Exec(`INSERT INTO knock (addr, endpoint, made, expires, born, proven) VALUES (?, ?, ?, ?, ?, ?)
					ON CONFLICT(addr) DO UPDATE SET endpoint = excluded.endpoint, made = excluded.made, expires = excluded.expires,
						born = excluded.born, proven = CASE WHEN knock.endpoint = excluded.endpoint
							THEN max(knock.proven, excluded.proven) ELSE excluded.proven END
					WHERE excluded.made > knock.made`,
					op.key[:], op.ep, op.made, op.expires, op.born, op.delivered)
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

// forgets waiting for the disk at once; past it the answer is to try
// later
const knockForgetWaiters = 1000

type forgetReq struct {
	key           [32]byte
	made, expires int64
	done          chan error
}

// a forget, on disk before this returns: "" once it is, or the answer to
// give. it wins a tie with a registration of the same second
func (s *knockStore) writeForget(key [32]byte, made, expires int64) string {
	if s == nil {
		return ""
	}
	if s.waiting.Add(1) > knockForgetWaiters {
		s.waiting.Add(-1)
		return "rate-limited: too many forgets at once, try later"
	}
	defer s.waiting.Add(-1)
	r := &forgetReq{key: key, made: made, expires: expires, done: make(chan error, 1)}
	select {
	case s.fch <- r:
	case <-s.quit:
		return "error: the relay could not keep this, try again"
	}
	select {
	case err := <-r.done:
		if err != nil {
			log.Printf("knock: forgets not written: %v", err)
			return "error: the relay could not keep this, try again"
		}
		return ""
	case <-time.After(10 * time.Second):
		return "error: the relay could not keep this, try again"
	}
}

// the forgets waiting, in one synced transaction, then each answered
func (s *knockStore) forgetWriter() {
	for {
		var first *forgetReq
		select {
		case first = <-s.fch:
		case <-s.quit:
			return
		}
		batch := []*forgetReq{first}
	more:
		for len(batch) < knockForgetWaiters {
			select {
			case r := <-s.fch:
				batch = append(batch, r)
			default:
				break more
			}
		}
		err := s.writeForgets(batch)
		for _, r := range batch {
			r.done <- err
		}
	}
}

func (s *knockStore) writeForgets(batch []*forgetReq) error {
	tx, err := s.fdb.Begin()
	if err != nil {
		return err
	}
	for _, r := range batch {
		if _, err := tx.Exec(`INSERT INTO knock (addr, endpoint, made, expires) VALUES (?, '', ?, ?)
			ON CONFLICT(addr) DO UPDATE SET endpoint = '', made = excluded.made, expires = excluded.expires
			WHERE excluded.made >= knock.made`, r.key[:], r.made, r.expires); err != nil {
			tx.Rollback()
			return err
		}
	}
	return tx.Commit()
}

func (s *knockStore) close() {
	if s == nil {
		return
	}
	select {
	case <-s.quit:
	default:
		close(s.quit)
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
	rows, err := db.Query(`SELECT addr, endpoint, made, expires, born, proven FROM knock`)
	if err != nil {
		return err
	}
	defer rows.Close()
	k.mu.Lock()
	defer k.mu.Unlock()
	for rows.Next() {
		var a []byte
		var ep string
		var made, exp, born int64
		var proven bool
		if err := rows.Scan(&a, &ep, &made, &exp, &born, &proven); err != nil {
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
		// its age and whether it ever delivered, as they were before the
		// restart. a row from before born was kept counts from its signing
		e := k.eps[ep]
		if born <= 0 {
			born = made
		}
		if b := time.Unix(born, 0); b.Before(e.born) {
			e.born = b
		}
		if proven && !e.delivered {
			e.delivered = true
			k.settledLocked(e)
		}
		// an old endpoint's decoys keep their usual gaps, not a new one's
		// first decoy within minutes
		k.decoyLocked(e)
	}
	return rows.Err()
}
