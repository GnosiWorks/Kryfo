package main

// the recipient index. a phone's catch-up asks for the wraps to a few
// addresses since a time. the backend answers that with tags LIKE '%addr%'
// over every wrap in the window, reading each row to test it, and that kept
// a core busy once the store held 100k wraps. wrap_to lists each wrap under
// its address, so a catch-up picks its own wraps' ids from there and reads
// only those rows.
//
// it holds nothing the wrap does not: the address is the wrap's p tag, the
// time is its created_at and the id its id, all three in the event row
// already. a row goes with its wrap, by a trigger, whichever path deletes
// the wrap (the sweeps, DeleteEvent), so the index never outlives what it
// points at.
//
// what a catch-up gets is what the backend's query gives, row for row: the
// rows picked are read by id with the backend's own conditions and order
// (kind, time, tags LIKE, created_at desc then id, its limit), so those
// still decide. a wrap is listed under every 64-character hex run in its
// tags json, lowercased (LIKE is blind to ascii case), which is every
// address its LIKE can match. one with more runs than maxRuns, or saved by
// a relay that does not know the table, is listed under "*": every
// catch-up takes it as a candidate and the LIKE decides. a filter the
// index does not cover (ids, other kinds or tags, a window the start-up
// fill has not reached) goes to the backend's query as before.
//
// the property test (recipients_test.go) holds the two answers equal on
// random stores and filters.

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"math"
	"strings"
	"time"

	"github.com/fiatjaf/eventstore"
	"github.com/nbd-wtf/go-nostr"
)

const (
	// listed under no address: tags with no 64-character hex run
	noAddr = ""
	// listed for every catch-up, the LIKE decides
	anyAddr = "*"
	// a normal wrap has one run, its p tag
	maxRuns = 64
	// the start-up fill: rows per write and the pause between, so saves
	// and reads get the lock
	fillBatch = 500
	fillPause = 200 * time.Millisecond
)

// below: every wrap stamped at or after it is listed. done: every wrap is
const recipientSchema = `
CREATE TABLE IF NOT EXISTS wrap_to (
	address TEXT NOT NULL,
	created_at INTEGER NOT NULL,
	id TEXT NOT NULL,
	PRIMARY KEY (address, created_at DESC, id)) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS wrap_to_id ON wrap_to(id);
CREATE TABLE IF NOT EXISTS wrap_to_fill (
	one INTEGER PRIMARY KEY CHECK (one = 1),
	below INTEGER NOT NULL,
	done INTEGER NOT NULL);
CREATE TRIGGER IF NOT EXISTS wrap_to_gone AFTER DELETE ON event
WHEN OLD.kind = 1059 BEGIN
	DELETE FROM wrap_to WHERE id = OLD.id;
END;
CREATE TRIGGER IF NOT EXISTS wrap_to_unlisted AFTER INSERT ON event
WHEN NEW.kind = 1059 AND NOT EXISTS (SELECT 1 FROM wrap_to WHERE id = NEW.id) BEGIN
	INSERT OR IGNORE INTO wrap_to (address, created_at, id) VALUES ('*', NEW.created_at, NEW.id);
END;
`

func isHexByte(c byte) bool {
	return c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F'
}

// every 64-character window of every hex run in the tags json, lowercased,
// or any when there are more than maxRuns
func recipients(tags []byte) (addrs []string, any bool) {
	seen := map[string]bool{}
	for i := 0; i < len(tags); {
		if !isHexByte(tags[i]) {
			i++
			continue
		}
		j := i
		for j < len(tags) && isHexByte(tags[j]) {
			j++
		}
		for k := i; k+64 <= j; k++ {
			a := strings.ToLower(string(tags[k : k+64]))
			if seen[a] {
				continue
			}
			if len(addrs) == maxRuns {
				return nil, true
			}
			seen[a] = true
			addrs = append(addrs, a)
		}
		i = j
	}
	return addrs, false
}

func listAs(tags []byte) []string {
	addrs, any := recipients(tags)
	if any {
		return []string{anyAddr}
	}
	if len(addrs) == 0 {
		return []string{noAddr}
	}
	return addrs
}

type execerTx interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

func listRows(ctx context.Context, tx execerTx, as []string, at int64, id string) error {
	for _, a := range as {
		if _, err := tx.ExecContext(ctx, `INSERT OR IGNORE INTO wrap_to (address, created_at, id) VALUES (?, ?, ?)`,
			a, at, id); err != nil {
			return err
		}
	}
	return nil
}

func (s *store) initRecipients() error {
	if _, err := s.w.DB.Exec(recipientSchema); err != nil {
		return err
	}
	// a store with no wraps yet is listed in full from its first save
	if _, err := s.w.DB.Exec(`INSERT OR IGNORE INTO wrap_to_fill (one, below, done)
		SELECT 1, ?, NOT EXISTS (SELECT 1 FROM event WHERE kind = 1059)`, int64(math.MaxInt64)); err != nil {
		return err
	}
	var below int64
	var done bool
	if err := s.w.DB.QueryRow(`SELECT below, done FROM wrap_to_fill WHERE one = 1`).Scan(&below, &done); err != nil {
		return err
	}
	s.below.Store(below)
	s.filled.Store(done)
	return nil
}

// the wrap and its rows in one write, so none is ever saved unlisted. the
// rows go first: the unlisted trigger then finds them
func (s *store) saveListed(ctx context.Context, ev *nostr.Event) error {
	tagsj, _ := json.Marshal(ev.Tags)
	tx, err := s.w.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if ev.Kind == wrapKind {
		if err := listRows(ctx, tx, listAs(tagsj), int64(ev.CreatedAt), ev.ID); err != nil {
			return err
		}
	}
	// the backend's own insert
	res, err := tx.ExecContext(ctx, `
        INSERT OR IGNORE INTO event (id, pubkey, created_at, kind, tags, content, sig)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
    `, ev.ID, ev.PubKey, ev.CreatedAt, ev.Kind, tagsj, ev.Content, ev.Sig)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return eventstore.ErrDupEvent
	}
	return tx.Commit()
}

// a catch-up the index can answer: wraps to named addresses, with no ids,
// in a window the fill has listed
func (s *store) listable(f nostr.Filter) bool {
	if len(f.IDs) > 0 || len(f.Authors) > 0 || f.Search != "" {
		return false
	}
	if len(f.Kinds) != 1 || f.Kinds[0] != wrapKind || len(f.Tags) != 1 {
		return false
	}
	ps, ok := f.Tags["p"]
	if !ok || len(ps) == 0 || len(ps) > s.QueryTagsLimit {
		return false
	}
	for _, p := range ps {
		if !isKey(p) {
			return false
		}
	}
	if s.filled.Load() {
		return true
	}
	return f.Since != nil && int64(*f.Since) >= s.below.Load()
}

var errUnlisted = errors.New("the index cannot be sure of this page")

// "*" candidates one catch-up takes at most. past it the backend's query
// answers: only wraps built to fool the index are listed so
const maxAnyCandidates = 400

// the page through the index, or errUnlisted when only the backend's query
// can be sure of it. candidates come in the backend's order, until limit
// of them are listed under an address asked for: those pass the backend's
// check by how they were listed, so the page is among them. the "*" ones
// on the way are read too and the check decides
func (s *store) pageByRecipient(ctx context.Context, f nostr.Filter) ([]*nostr.Event, error) {
	limit := f.Limit
	if limit < 1 || limit > s.QueryLimit {
		limit = s.QueryLimit
	}
	ps := f.Tags["p"]
	args := make([]any, 0, len(ps)+4)
	for _, p := range ps {
		args = append(args, strings.ToLower(p))
	}
	args = append(args, anyAddr)
	var window string
	var wargs []any
	if f.Since != nil {
		window += ` AND created_at >= ?`
		wargs = append(wargs, int64(*f.Since))
	}
	if f.Until != nil {
		window += ` AND created_at <= ?`
		wargs = append(wargs, int64(*f.Until))
	}
	args = append(args, wargs...)
	args = append(args, limit+maxAnyCandidates)
	rows, err := s.DB.QueryContext(ctx, `SELECT DISTINCT id, address = '*' FROM wrap_to WHERE address IN (`+
		makeMarks(len(ps)+1)+`)`+window+` ORDER BY created_at DESC, id LIMIT ?`, args...)
	if err != nil {
		return nil, err
	}
	var ids []any
	seen := map[string]bool{}
	listed, read := 0, 0
	for listed < limit && rows.Next() {
		var id string
		var any bool
		if err := rows.Scan(&id, &any); err != nil {
			rows.Close()
			return nil, err
		}
		read++
		if seen[id] {
			continue
		}
		seen[id] = true
		ids = append(ids, id)
		if !any {
			listed++
		}
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if listed < limit && read == limit+maxAnyCandidates {
		return nil, errUnlisted
	}
	if len(ids) == 0 {
		return nil, nil
	}
	// the backend's conditions and order, read by id
	q := `SELECT id, pubkey, created_at, kind, tags, content, sig FROM event INDEXED BY ididx WHERE id IN (` +
		makeMarks(len(ids)) + `) AND kind IN (?) AND (`
	qargs := append(ids, wrapKind)
	for i, p := range ps {
		if i > 0 {
			q += `OR `
		}
		q += `tags LIKE ? ESCAPE '\'`
		qargs = append(qargs, `%`+strings.ReplaceAll(p, `%`, `\%`)+`%`)
	}
	q += `)` + window + ` ORDER BY created_at DESC, id LIMIT ?`
	qargs = append(qargs, wargs...)
	qargs = append(qargs, limit)
	evs, err := s.DB.QueryContext(ctx, q, qargs...)
	if err != nil {
		return nil, err
	}
	defer evs.Close()
	var page []*nostr.Event
	for evs.Next() {
		var ev nostr.Event
		var at int64
		if err := evs.Scan(&ev.ID, &ev.PubKey, &at, &ev.Kind, &ev.Tags, &ev.Content, &ev.Sig); err != nil {
			return page, nil
		}
		ev.CreatedAt = nostr.Timestamp(at)
		page = append(page, &ev)
	}
	if ctx.Err() != nil {
		return page, nil
	}
	if err := evs.Err(); err != nil {
		return nil, err
	}
	// a candidate listed under an address that failed the check: a row
	// out of step with its wrap, which the triggers rule out
	if len(page) < listed {
		return nil, errUnlisted
	}
	return page, nil
}

func makeMarks(n int) string {
	return strings.TrimRight(strings.Repeat("?,", n), ",")
}

type unlisted struct {
	id   string
	at   int64
	tags []byte
}

// lists the wraps saved before the table was there, newest first, a batch
// a write, then the ones listed under "*" by a relay that did not know the
// table. a row deleted meanwhile is not listed: each insert checks it is
// still there, in the write that adds it
func (s *store) fill(ctx context.Context, batch int, pause time.Duration) error {
	start := time.Now()
	n := 0
	for !s.filled.Load() {
		k, err := s.fillStep(ctx, batch)
		if err != nil {
			return err
		}
		n += k
		if err := sleepCtx(ctx, pause); err != nil {
			return err
		}
	}
	if n > 0 {
		log.Printf("store: recipient index filled, %d wraps in %s", n, time.Since(start).Round(time.Second))
	}
	m, err := s.relist(ctx, batch, pause)
	if m > 0 {
		log.Printf("store: %d wraps saved by an older relay listed", m)
	}
	return err
}

func sleepCtx(ctx context.Context, d time.Duration) error {
	if d <= 0 {
		return ctx.Err()
	}
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(d):
		return nil
	}
}

func (s *store) readUnlisted(ctx context.Context, q string, args ...any) ([]unlisted, error) {
	rows, err := s.DB.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []unlisted
	for rows.Next() {
		var u unlisted
		if err := rows.Scan(&u.id, &u.at, &u.tags); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// one batch below the mark. a batch takes every wrap of its last second,
// so the mark never splits a second
func (s *store) fillStep(ctx context.Context, batch int) (int, error) {
	below := s.below.Load()
	got, err := s.readUnlisted(ctx, `SELECT id, created_at, tags FROM event
		WHERE kind = 1059 AND created_at < ? ORDER BY created_at DESC LIMIT ?`, below, batch)
	if err != nil {
		return 0, err
	}
	done := len(got) < batch
	next := below
	if len(got) > 0 {
		next = got[len(got)-1].at
	}
	if !done {
		rest, err := s.readUnlisted(ctx, `SELECT id, created_at, tags FROM event
			WHERE kind = 1059 AND created_at = ?`, next)
		if err != nil {
			return 0, err
		}
		had := map[string]bool{}
		for _, u := range got {
			had[u.id] = true
		}
		for _, u := range rest {
			if !had[u.id] {
				got = append(got, u)
			}
		}
	}
	if err := s.listBatch(ctx, got, func(tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `UPDATE wrap_to_fill SET below = ?, done = ? WHERE one = 1`, next, done)
		return err
	}); err != nil {
		return 0, err
	}
	s.below.Store(next)
	if done {
		s.filled.Store(true)
	}
	return len(got), nil
}

// the rows of each wrap still in the store, and its "*" row gone when it
// has addresses now. then the mark, in the same write
func (s *store) listBatch(ctx context.Context, got []unlisted, mark func(*sql.Tx) error) error {
	tx, err := s.w.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, u := range got {
		as := listAs(u.tags)
		for _, a := range as {
			if _, err := tx.ExecContext(ctx, `INSERT OR IGNORE INTO wrap_to (address, created_at, id)
				SELECT ?, ?, ? WHERE EXISTS (SELECT 1 FROM event WHERE id = ?)`, a, u.at, u.id, u.id); err != nil {
				return err
			}
		}
		if as[0] != anyAddr {
			if _, err := tx.ExecContext(ctx, `DELETE FROM wrap_to WHERE address = '*' AND created_at = ? AND id = ?`,
				u.at, u.id); err != nil {
				return err
			}
		}
	}
	if mark != nil {
		if err := mark(tx); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// wraps under "*" that have addresses: saved by a relay that did not know
// the table (a rollback). the ones with more runs than maxRuns stay
func (s *store) relist(ctx context.Context, batch int, pause time.Duration) (int, error) {
	n := 0
	after := ""
	for {
		got, err := s.readUnlisted(ctx, `SELECT w.id, w.created_at, e.tags FROM wrap_to w
			JOIN event e ON e.id = w.id WHERE w.address = '*' AND w.id > ? ORDER BY w.id LIMIT ?`, after, batch)
		if err != nil || len(got) == 0 {
			return n, err
		}
		after = got[len(got)-1].id
		if err := s.listBatch(ctx, got, nil); err != nil {
			return n, err
		}
		n += len(got)
		if len(got) < batch {
			return n, nil
		}
		if err := sleepCtx(ctx, pause); err != nil {
			return n, err
		}
	}
}

// the fill, once, beside the relay. a failed one tries again after a
// minute: until it is done, unlisted windows go to the backend's query
func (s *store) startFill() {
	s.fillWG.Add(1)
	go func() {
		defer s.fillWG.Done()
		for {
			err := s.fill(s.stop, fillBatch, fillPause)
			if err == nil || s.stop.Err() != nil {
				return
			}
			log.Printf("store: recipient index fill: %v", err)
			if sleepCtx(s.stop, time.Minute) != nil {
				return
			}
		}
	}()
}
