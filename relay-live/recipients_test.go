package main

import (
	"context"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"math/rand"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/fiatjaf/eventstore/sqlite3"
	"github.com/nbd-wtf/go-nostr"
)

func randHex(r *rand.Rand, n int) string {
	b := make([]byte, (n+1)/2)
	r.Read(b)
	return hex.EncodeToString(b)[:n]
}

// a wrap as the store keeps it, unsigned: the store checks nothing
func rawWrap(r *rand.Rand, at int64, tags nostr.Tags) nostr.Event {
	return nostr.Event{
		ID:        randHex(r, 64),
		PubKey:    randHex(r, 64),
		CreatedAt: nostr.Timestamp(at),
		Kind:      wrapKind,
		Tags:      tags,
		Content:   "sealed " + randHex(r, 16),
		Sig:       randHex(r, 128),
	}
}

// a store the relay before the index left, holding evs
func preIndexStore(t testing.TB, path string, evs []nostr.Event) {
	t.Helper()
	old := &sqlite3.SQLite3Backend{DatabaseURL: path + "?_sync=OFF"}
	if err := old.Init(); err != nil {
		t.Fatal(err)
	}
	defer old.Close()
	for i := range evs {
		if err := old.SaveEvent(context.Background(), &evs[i]); err != nil {
			t.Fatal(err)
		}
	}
}

func ids(evs []*nostr.Event) []string {
	out := make([]string, len(evs))
	for i, ev := range evs {
		out[i] = ev.ID
	}
	return out
}

// the backend's own answer, the one the index must give
func oldPage(t testing.TB, s *store, f nostr.Filter) []string {
	t.Helper()
	ch, err := s.SQLite3Backend.QueryEvents(context.Background(), f)
	if err != nil {
		t.Fatal(err)
	}
	var got []*nostr.Event
	for ev := range ch {
		got = append(got, ev)
	}
	return ids(got)
}

func newPage(t testing.TB, s *store, f nostr.Filter) []string {
	t.Helper()
	got, err := s.page(context.Background(), f)
	if err != nil {
		t.Fatal(err)
	}
	return ids(got)
}

// the tags a wrap may carry, the odd ones too: the ones older relays took
// and the ones built to fool the index
type tagMaker struct {
	r     *rand.Rand
	pool  []string
	extra []string
}

func (m *tagMaker) tags() nostr.Tags {
	r := m.r
	a := m.pool[r.Intn(len(m.pool))]
	b := m.pool[r.Intn(len(m.pool))]
	switch r.Intn(14) {
	case 0:
		return nostr.Tags{{"p", strings.ToUpper(a)}}
	case 1:
		return nostr.Tags{{"p", a}, {"expiration", "1767225600"}}
	case 2:
		return nostr.Tags{{"p", a}, {"e", b}}
	case 3:
		// a longer run: matches a and the windows after it
		return nostr.Tags{{"p", a + "ff"}}
	case 4:
		// json writes the control byte as \u0001: its digits run on
		// into the hex after it
		w := "0001" + b[:60]
		m.extra = append(m.extra, w)
		return nostr.Tags{{"p", a}, {"x", "\x01" + b[:60]}}
	case 5:
		// more runs than maxRuns: listed under "*"
		long := randHex(r, 200)
		m.extra = append(m.extra, long[10:74])
		return nostr.Tags{{"p", a}, {"x", long}}
	case 6:
		return nostr.Tags{}
	case 7:
		return nostr.Tags{{"p", a[:63]}}
	case 8:
		return nostr.Tags{{"p", a, "wss://relay.example", "x"}}
	case 9:
		return nostr.Tags{{a}}
	default:
		return nostr.Tags{{"p", a}}
	}
}

// the index answers every catch-up as the backend's query does, row for
// row, in order, whatever the tags, the window, the limit, the fill's
// progress, deletes, and wraps saved by a relay that does not know it
func TestRecipientIndexMatchesTheOldQuery(t *testing.T) {
	r := rand.New(rand.NewSource(20261106))
	path := filepath.Join(t.TempDir(), "relay.sqlite")
	m := &tagMaker{r: r}
	for i := 0; i < 12; i++ {
		m.pool = append(m.pool, randHex(r, 64))
	}
	now := time.Now().Unix()
	// few distinct seconds, so ties are everywhere
	times := make([]int64, 150)
	for i := range times {
		times[i] = now - int64(r.Intn(40000))
	}
	at := func() int64 { return times[r.Intn(len(times))] }
	mk := func() nostr.Event {
		ev := rawWrap(r, at(), m.tags())
		if r.Intn(25) == 0 {
			ev.Kind = 1
		}
		return ev
	}
	var before []nostr.Event
	for i := 0; i < 700; i++ {
		before = append(before, mk())
	}
	preIndexStore(t, path, before)

	s, err := openStore(path + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { s.Close() })
	if s.filled.Load() || s.below.Load() != math.MaxInt64 {
		t.Fatal("a store with wraps in it starts filled")
	}
	ctx := context.Background()
	var all []nostr.Event
	all = append(all, before...)
	for i := 0; i < 500; i++ {
		ev := mk()
		var err error
		if i%5 == 0 {
			// a relay that does not know the table
			err = s.w.SaveEvent(ctx, &ev)
		} else {
			err = s.SaveEvent(ctx, &ev)
		}
		if err != nil {
			t.Fatal(err)
		}
		all = append(all, ev)
	}

	asked := 0
	check := func(n int) {
		t.Helper()
		for i := 0; i < n; i++ {
			f := nostr.Filter{Kinds: []int{wrapKind}}
			k := 1 + r.Intn(4)
			var ps []string
			for j := 0; j < k; j++ {
				switch r.Intn(6) {
				case 0:
					if len(m.extra) > 0 {
						ps = append(ps, m.extra[r.Intn(len(m.extra))])
						continue
					}
					fallthrough
				case 1:
					ps = append(ps, strings.ToUpper(m.pool[r.Intn(len(m.pool))]))
				case 2:
					ps = append(ps, randHex(r, 64))
				default:
					ps = append(ps, m.pool[r.Intn(len(m.pool))])
				}
			}
			f.Tags = nostr.TagMap{"p": ps}
			if r.Intn(4) > 0 {
				v := nostr.Timestamp(at() - int64(r.Intn(3)))
				f.Since = &v
			}
			if r.Intn(3) == 0 {
				v := nostr.Timestamp(at() + int64(r.Intn(3)))
				f.Until = &v
			}
			f.Limit = []int{0, 1, 2, 3, 5, 10, 40, 100, 150}[r.Intn(9)]
			want := oldPage(t, s, f)
			got := newPage(t, s, f)
			if !reflect.DeepEqual(got, want) {
				t.Fatalf("filter %v: index gave %d %v, the backend %d %v", f, len(got), got, len(want), want)
			}
			asked++
		}
	}

	check(150)
	for !s.filled.Load() {
		if _, err := s.fillStep(ctx, 37); err != nil {
			t.Fatal(err)
		}
		check(15)
	}
	idx0 := s.byIndex.Load()
	check(400)
	if got := s.byIndex.Load() - idx0; got < 300 {
		t.Fatalf("the index answered %d of 400 catch-ups once filled", got)
	}

	// deletes by every path
	for i := 0; i < 150; i++ {
		ev := all[r.Intn(len(all))]
		if i%2 == 0 {
			if err := s.DeleteEvent(ctx, &ev); err != nil {
				t.Fatal(err)
			}
		} else if _, err := s.ExecContext(ctx, `DELETE FROM event WHERE rowid IN (SELECT rowid FROM event WHERE id = ?)`, ev.ID); err != nil {
			t.Fatal(err)
		}
	}
	check(200)

	// a rollback: an older relay saves wraps the index does not list
	for i := 0; i < 120; i++ {
		ev := mk()
		if err := s.w.SaveEvent(ctx, &ev); err != nil {
			t.Fatal(err)
		}
		all = append(all, ev)
	}
	check(200)

	stars := func() int {
		var n int
		if err := s.DB.QueryRow(`SELECT count(*) FROM wrap_to WHERE address = '*'`).Scan(&n); err != nil {
			t.Fatal(err)
		}
		return n
	}
	b4 := stars()
	if _, err := s.relist(ctx, 13, 0); err != nil {
		t.Fatal(err)
	}
	if stars() >= b4 {
		t.Fatalf("relist left %d of %d \"*\" rows", stars(), b4)
	}
	check(300)
	noOrphans(t, s)
	t.Logf("%d catch-ups compared, %d through the index", asked, s.byIndex.Load())
}

// no row for a wrap that is gone, none missing for one that is there
func noOrphans(t *testing.T, s *store) {
	t.Helper()
	var n int
	if err := s.DB.QueryRow(`SELECT count(*) FROM wrap_to w WHERE NOT EXISTS (SELECT 1 FROM event e WHERE e.id = w.id)`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatalf("%d index rows for wraps that are gone", n)
	}
}

// what the index must hold for the wraps listed, from their stored tags
func wantRows(t *testing.T, s *store, where string, args ...any) map[string]bool {
	t.Helper()
	rows, err := s.DB.Query(`SELECT id, created_at, tags FROM event WHERE kind = 1059 `+where, args...)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	want := map[string]bool{}
	for rows.Next() {
		var id string
		var at int64
		var tags []byte
		if err := rows.Scan(&id, &at, &tags); err != nil {
			t.Fatal(err)
		}
		for _, a := range listAs(tags) {
			want[fmt.Sprintf("%s|%d|%s", a, at, id)] = true
		}
	}
	return want
}

func haveRows(t *testing.T, s *store) map[string]bool {
	t.Helper()
	rows, err := s.DB.Query(`SELECT address, created_at, id FROM wrap_to`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	have := map[string]bool{}
	for rows.Next() {
		var a, id string
		var at int64
		if err := rows.Scan(&a, &at, &id); err != nil {
			t.Fatal(err)
		}
		have[fmt.Sprintf("%s|%d|%s", a, at, id)] = true
	}
	return have
}

// the fill lists the wraps saved before the index in batches, newest
// first, never splits a second, keeps its mark over a restart, and leaves
// no row for a wrap deleted while it runs
func TestRecipientIndexFill(t *testing.T) {
	r := rand.New(rand.NewSource(7))
	path := filepath.Join(t.TempDir(), "relay.sqlite")
	m := &tagMaker{r: r}
	for i := 0; i < 30; i++ {
		m.pool = append(m.pool, randHex(r, 64))
	}
	now := time.Now().Unix()
	var evs []nostr.Event
	for i := 0; i < 2300; i++ {
		at := now - int64(r.Intn(14*86400))
		if i < 450 {
			// one busy second, across several batches
			at = now - 3*86400
		}
		evs = append(evs, rawWrap(r, at, m.tags()))
	}
	preIndexStore(t, path, evs)

	ctx := context.Background()
	open := func() *store {
		s, err := openStore(path + "?_sync=OFF")
		if err != nil {
			t.Fatal(err)
		}
		return s
	}
	// every wrap stamped at or after the mark is listed
	listedFromMark := func(s *store) {
		t.Helper()
		have := haveRows(t, s)
		for k := range wantRows(t, s, `AND created_at >= ?`, s.below.Load()) {
			if !have[k] {
				t.Fatalf("below %d: %s not listed", s.below.Load(), k)
			}
		}
	}
	s := open()
	steps := 0
	for i := 0; i < 8; i++ {
		if _, err := s.fillStep(ctx, 100); err != nil {
			t.Fatal(err)
		}
		steps++
		listedFromMark(s)
	}
	mark := s.below.Load()
	s.Close()

	s = open()
	if s.below.Load() != mark || s.filled.Load() {
		t.Fatalf("after a restart the mark is %d (filled %v), was %d", s.below.Load(), s.filled.Load(), mark)
	}
	// deletes and saves while the fill runs
	gone := 0
	for !s.filled.Load() {
		for j := 0; j < 5; j++ {
			ev := evs[r.Intn(len(evs))]
			if err := s.DeleteEvent(ctx, &ev); err != nil {
				t.Fatal(err)
			}
			gone++
		}
		ev := rawWrap(r, now-int64(r.Intn(14*86400)), m.tags())
		if err := s.SaveEvent(ctx, &ev); err != nil {
			t.Fatal(err)
		}
		if _, err := s.fillStep(ctx, 100); err != nil {
			t.Fatal(err)
		}
		steps++
		listedFromMark(s)
	}
	// the busy second took one batch, not a split
	if steps > 2300/100+8 {
		t.Fatalf("%d steps for 2300 wraps", steps)
	}
	if want, have := wantRows(t, s, ``), haveRows(t, s); !reflect.DeepEqual(want, have) {
		t.Fatalf("filled: %d rows, want %d", len(have), len(want))
	}
	noOrphans(t, s)
	s.Close()

	s = open()
	defer s.Close()
	if !s.filled.Load() {
		t.Fatal("filled is not kept over a restart")
	}
	if err := s.fill(ctx, 100, 0); err != nil {
		t.Fatal(err)
	}
	t.Logf("%d steps, %d deleted meanwhile", steps, gone)
}

// a store that starts empty is listed from its first save, with no fill
func TestEmptyStoreStartsFilled(t *testing.T) {
	s, err := openStore(filepath.Join(t.TempDir(), "relay.sqlite") + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if !s.filled.Load() {
		t.Fatal("an empty store is not filled")
	}
	to := addr()
	ev := wrap(t, to, nil)
	if err := s.SaveEvent(context.Background(), &ev); err != nil {
		t.Fatal(err)
	}
	// the same wrap again is the backend's duplicate, and lists nothing twice
	if err := s.SaveEvent(context.Background(), &ev); err == nil || !strings.Contains(err.Error(), "duplicate") {
		t.Fatalf("a duplicate save gave %v", err)
	}
	since := nostr.Timestamp(0)
	got := newPage(t, s, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Since: &since})
	if len(got) != 1 || got[0] != ev.ID || s.byIndex.Load() != 1 {
		t.Fatalf("got %v, %d through the index", got, s.byIndex.Load())
	}
}

func indexRows(t *testing.T, s *store) int {
	t.Helper()
	var n int
	if err := s.DB.QueryRow(`SELECT count(*) FROM wrap_to`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

// the sweep, the file slice sweep and DeleteEvent take a wrap's index rows
// with it, and wraps an older relay saved too
func TestSweepsDeleteFromTheIndex(t *testing.T) {
	path := filepath.Join(t.TempDir(), "relay.sqlite")
	fillExpired(t, path, sweepBatch+9)
	s, err := openStore(path + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(s.Close)
	ctx := context.Background()
	if n := indexRows(t, s); n != sweepBatch+9 {
		t.Fatalf("%d index rows for %d wraps", n, sweepBatch+9)
	}
	to := addr()
	old := nostr.Now() - nostr.Timestamp(wrapTTL/time.Second) - 60
	unlisted := wrap(t, to, func(e *nostr.Event) { e.CreatedAt = old })
	if err := s.w.SaveEvent(ctx, &unlisted); err != nil {
		t.Fatal(err)
	}
	if n := sweep(ctx, s, 0); n != sweepBatch+10 {
		t.Fatalf("swept %d", n)
	}
	if n := indexRows(t, s); n != 0 {
		t.Fatalf("%d index rows left after the sweep", n)
	}

	small := wrap(t, to, nil)
	slice := sliceWrap(t, to)
	kept := wrap(t, to, nil)
	for _, ev := range []*nostr.Event{&small, &slice, &kept} {
		if err := s.SaveEvent(ctx, ev); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := s.DB.Exec(`UPDATE big_wrap SET at = ?`, time.Now().Add(-9*24*time.Hour).Unix()); err != nil {
		t.Fatal(err)
	}
	if n := sweepBig(ctx, s, 0); n != 1 {
		t.Fatalf("swept %d slices", n)
	}
	if err := s.DeleteEvent(ctx, &small); err != nil {
		t.Fatal(err)
	}
	var left []string
	rows, err := s.DB.Query(`SELECT id FROM wrap_to`)
	if err != nil {
		t.Fatal(err)
	}
	for rows.Next() {
		var id string
		rows.Scan(&id)
		left = append(left, id)
	}
	rows.Close()
	if len(left) != 1 || left[0] != kept.ID {
		t.Fatalf("index rows left %v, want only %s", left, kept.ID)
	}
	noOrphans(t, s)
}

// the plans: candidates from the index's key, rows by id, never the scan
// of the time index
func TestRecipientIndexPlans(t *testing.T) {
	s, err := openStore(filepath.Join(t.TempDir(), "relay.sqlite") + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	plan := func(q string, args ...any) string {
		rows, err := s.DB.Query(`EXPLAIN QUERY PLAN `+q, args...)
		if err != nil {
			t.Fatal(err)
		}
		defer rows.Close()
		var out []string
		for rows.Next() {
			var a, b, c int
			var d string
			rows.Scan(&a, &b, &c, &d)
			out = append(out, d)
		}
		return strings.Join(out, "; ")
	}
	p := plan(`SELECT DISTINCT id, created_at FROM wrap_to WHERE address IN (?, ?) AND created_at >= ? ORDER BY created_at DESC, id LIMIT ?`,
		"a", "*", 0, 100)
	if !strings.Contains(p, "wrap_to USING PRIMARY KEY") {
		t.Fatalf("candidates: %s", p)
	}
	p = plan(`SELECT id, pubkey, created_at, kind, tags, content, sig FROM event INDEXED BY ididx WHERE id IN (?,?,?) AND kind IN (?) AND (tags LIKE ? ESCAPE '\') AND created_at >= ? ORDER BY created_at DESC, id LIMIT ?`,
		"a", "b", "c", 1059, "%a%", 0, 100)
	if !strings.Contains(p, "ididx") {
		t.Fatalf("rows: %s", p)
	}
}

// a catch-up for one address over 12 h, 100k wraps in the window, 1% of
// them to that address, sized as relay1's (27.8 kB a row on average: about
// half are file slices). and the common one: an address with nothing new.
//
//	go test -run '^$' -bench CatchUp -benchtime 20x
//
// RELAY_BENCH_ROWS sets the rows (default 100000)
func BenchmarkCatchUp(b *testing.B) {
	rows := 100000
	if n, err := fmt.Sscan(os.Getenv("RELAY_BENCH_ROWS"), &rows); n != 1 || err != nil {
		rows = 100000
	}
	r := rand.New(rand.NewSource(1))
	path := filepath.Join(b.TempDir(), "relay.sqlite")
	s, err := openStore(path + "?_sync=OFF")
	if err != nil {
		b.Fatal(err)
	}
	defer s.Close()
	ctx := context.Background()
	target := randHex(r, 64)
	blob := randHex(r, 56000)
	now := time.Now().Unix()
	start := time.Now()
	tx, err := s.w.DB.BeginTx(ctx, nil)
	if err != nil {
		b.Fatal(err)
	}
	for i := 0; i < rows; i++ {
		to := randHex(r, 64)
		if i%100 == 0 {
			to = target
		}
		ev := rawWrap(r, now-int64(r.Intn(43200)), nostr.Tags{{"p", to}, {"expiration", "1767225600"}})
		ev.Content = blob[:1500]
		if r.Float64() < 0.49 {
			ev.Content = blob[:55149]
		}
		if err := saveInTx(ctx, tx, &ev); err != nil {
			b.Fatal(err)
		}
		if i%2000 == 1999 {
			if err := tx.Commit(); err != nil {
				b.Fatal(err)
			}
			if tx, err = s.w.DB.BeginTx(ctx, nil); err != nil {
				b.Fatal(err)
			}
		}
	}
	if err := tx.Commit(); err != nil {
		b.Fatal(err)
	}
	if err := s.checkpoint(ctx); err != nil {
		b.Fatal(err)
	}
	st, _ := os.Stat(path)
	b.Logf("%d wraps, %d MB, made in %s", rows, st.Size()>>20, time.Since(start).Round(time.Second))

	since := nostr.Timestamp(now - 43200)
	cases := []struct {
		name string
		to   string
	}{{"one-percent", target}, {"nothing-new", randHex(r, 64)}}
	for _, c := range cases {
		f := nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {c.to}}, Since: &since, Limit: 100}
		want := oldPage(b, s, f)
		if got := newPage(b, s, f); !reflect.DeepEqual(got, want) {
			b.Fatalf("%s: the index gave %d, the backend %d", c.name, len(got), len(want))
		}
		b.Run(c.name+"/old", func(b *testing.B) {
			for i := 0; i < b.N; i++ {
				oldPage(b, s, f)
			}
		})
		b.Run(c.name+"/new", func(b *testing.B) {
			for i := 0; i < b.N; i++ {
				newPage(b, s, f)
			}
		})
	}
}

// saveListed's two inserts, in a caller's write
func saveInTx(ctx context.Context, tx *sql.Tx, ev *nostr.Event) error {
	tagsj, _ := json.Marshal(ev.Tags)
	if err := listRows(ctx, tx, listAs(tagsj), int64(ev.CreatedAt), ev.ID); err != nil {
		return err
	}
	_, err := tx.ExecContext(ctx, `INSERT INTO event (id, pubkey, created_at, kind, tags, content, sig)
		VALUES (?, ?, ?, ?, ?, ?, ?)`, ev.ID, ev.PubKey, ev.CreatedAt, ev.Kind, tagsj, ev.Content, ev.Sig)
	return err
}

// 0001020304...: every window of it a different one
func counting(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = byte(i)
	}
	return hex.EncodeToString(b)
}

// a run is every window of it, json escapes included, and the case of
// hex is not kept
func TestRecipientsFromTags(t *testing.T) {
	a := strings.Repeat("ab", 32)
	tj := func(tags nostr.Tags) []byte { b, _ := json.Marshal(tags); return b }
	got, any := recipients(tj(nostr.Tags{{"p", strings.ToUpper(a)}, {"expiration", "1767225600"}}))
	if any || !reflect.DeepEqual(got, []string{a}) {
		t.Fatalf("one p tag: %v %v", got, any)
	}
	got, _ = recipients(tj(nostr.Tags{{"p", a + "c"}}))
	sort.Strings(got)
	if len(got) != 2 || got[0] != a {
		t.Fatalf("a run of 65: %v", got)
	}
	got, _ = recipients(tj(nostr.Tags{{"x", "\x01" + a[:60]}}))
	if !reflect.DeepEqual(got, []string{"0001" + a[:60]}) {
		t.Fatalf("an escape: %v", got)
	}
	if _, any = recipients(tj(nostr.Tags{{"x", counting(100)}})); !any {
		t.Fatal("200 hex is not listed under *")
	}
	if as := listAs(tj(nostr.Tags{{"p", a[:63]}})); !reflect.DeepEqual(as, []string{noAddr}) {
		t.Fatalf("no run: %v", as)
	}
}

// the fill runs beside the relay, stops with the store, and goes on from
// its mark at the next start
func TestFillRunsBesideTheRelay(t *testing.T) {
	r := rand.New(rand.NewSource(3))
	path := filepath.Join(t.TempDir(), "relay.sqlite")
	m := &tagMaker{r: r, pool: []string{randHex(r, 64), randHex(r, 64)}}
	var evs []nostr.Event
	now := time.Now().Unix()
	for i := 0; i < fillBatch*3+11; i++ {
		evs = append(evs, rawWrap(r, now-int64(r.Intn(86400)), m.tags()))
	}
	preIndexStore(t, path, evs)
	s, err := openStore(path + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	s.startFill()
	closed := make(chan struct{})
	go func() { s.Close(); close(closed) }()
	select {
	case <-closed:
	case <-time.After(5 * time.Second):
		t.Fatal("the store does not close while its fill runs")
	}
	s, err = openStore(path + "?_sync=OFF")
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	s.startFill()
	end := time.Now().Add(20 * time.Second)
	for !s.filled.Load() {
		if time.Now().After(end) {
			t.Fatal("not filled in 20 s")
		}
		time.Sleep(50 * time.Millisecond)
	}
	if want, have := wantRows(t, s, ``), haveRows(t, s); !reflect.DeepEqual(want, have) {
		t.Fatalf("filled: %d rows, want %d", len(have), len(want))
	}
}
