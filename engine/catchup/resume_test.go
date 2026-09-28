// SPDX-License-Identifier: GPL-3.0-or-later
package catchup

import (
	"context"
	"testing"

	"fiatjaf.com/nostr"
)

// a relay that costs time to page. each answer takes pageCost, and the caller
// is given a budget per check-in, like the engine's 30s cap. the clock is
// counted rather than slept so the test is fast and deterministic.
type slowRelay struct {
	*fakeRelay
	pageCost int // "seconds" per page
	spent    int
	budget   int
	cancel   context.CancelFunc
}

func (r *slowRelay) page(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	evs, err := r.fakeRelay.page(ctx, since, until, limit)
	r.spent += r.pageCost
	if r.spent >= r.budget && r.cancel != nil {
		// the window is up: the engine cancels this relay's backfill
		r.cancel()
	}
	return evs, err
}

// one check-in against that relay, carrying the mark in and out.
func checkIn(t *testing.T, r *slowRelay, since nostr.Timestamp, limit, maxPages int,
	got map[nostr.ID]bool, m Mark) (Result, Mark) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	r.spent = 0
	r.cancel = cancel

	// the live subscription's first answer, newest first, as the runner has it
	first, _ := r.fakeRelay.page(context.Background(), since, 1<<40, limit)
	oldest := nostr.Timestamp(0)
	for _, e := range first {
		got[e.ID] = true
		if oldest == 0 || e.CreatedAt < oldest {
			oldest = e.CreatedAt
		}
	}
	return Continue(ctx, r.page, since, oldest, limit, maxPages, func(e nostr.Event) bool {
		if got[e.ID] {
			return false
		}
		got[e.ID] = true
		return true
	}, m)
}

// a relay holding more backlog than one check-in's window can page. across
// three check-ins every event must arrive, and no check-in may spend its
// window re-walking ground an earlier one already covered.
func TestBacklogArrivesOverThreeCheckIns(t *testing.T) {
	const total = 140
	// 140 events, 20 to a page, 10 "seconds" a page: about 70 seconds of
	// paging. a check-in gets 30, so it takes three of them.
	r := &slowRelay{
		fakeRelay: &fakeRelay{events: mk(total, 1_000_000, 13), cap: 20},
		pageCost:  10,
		budget:    30,
	}
	got := map[nostr.ID]bool{}
	var m Mark
	var res Result

	deepest := nostr.Timestamp(1 << 40)
	askedBefore := 0
	for i := 1; i <= 3; i++ {
		res, m = checkIn(t, r, 0, 20, 1000, got, m)
		t.Logf("check-in %d: pages=%d fetched=%d fresh=%d complete=%v until=%d mark=%+v",
			i, res.Pages, res.Fetched, res.Fresh, res.Complete, res.Until, m)

		if res.Pages == 0 {
			t.Fatalf("check-in %d walked nothing at all", i)
		}
		// each check-in must get strictly deeper than the last
		if !res.Complete && res.Until >= deepest {
			t.Fatalf("check-in %d did not get deeper: until=%d, previous %d "+
				"- it is re-walking ground already covered", i, res.Until, deepest)
		}
		if res.Until < deepest {
			deepest = res.Until
		}
		if r.fakeRelay.asked <= askedBefore {
			t.Fatalf("check-in %d asked nothing new", i)
		}
		askedBefore = r.fakeRelay.asked
		if res.Complete {
			break
		}
	}

	if !res.Complete {
		t.Fatalf("three check-ins did not finish the backlog; mark still %+v", m)
	}
	if m.Started() {
		t.Fatalf("a finished window must spend its mark, got %+v", m)
	}
	if len(got) != total {
		t.Fatalf("only %d of %d events arrived", len(got), total)
	}
}

// and the point of the mark: without it the same first pages are fetched over
// and over. with it, the work done across three windows is close to the work
// one uninterrupted pass would do.
func TestMarkStopsRewalking(t *testing.T) {
	const total = 300
	mkRelay := func() *slowRelay {
		return &slowRelay{
			fakeRelay: &fakeRelay{events: mk(total, 1_000_000, 13), cap: 20},
			pageCost:  10,
			budget:    30,
		}
	}

	// with the mark carried across
	withMark := mkRelay()
	got := map[nostr.ID]bool{}
	var m Mark
	for i := 0; i < 8; i++ {
		var res Result
		res, m = checkIn(t, withMark, 0, 20, 1000, got, m)
		if res.Complete {
			break
		}
	}
	if len(got) != total {
		t.Fatalf("with a mark, only %d of %d arrived", len(got), total)
	}

	// and without: the mark thrown away each time
	without := mkRelay()
	got2 := map[nostr.ID]bool{}
	for i := 0; i < 8; i++ {
		res, _ := checkIn(t, without, 0, 20, 1000, got2, Mark{})
		if res.Complete {
			break
		}
	}

	t.Logf("pages asked: with a mark %d, without %d; delivered %d vs %d",
		withMark.fakeRelay.asked, without.fakeRelay.asked, len(got), len(got2))
	if len(got2) >= total {
		t.Fatal("the no-mark run finished too, so this test proves nothing " +
			"- make the backlog deeper than eight windows")
	}
	if withMark.fakeRelay.asked >= without.fakeRelay.asked {
		t.Fatalf("carrying the mark asked for as much or more (%d vs %d)",
			withMark.fakeRelay.asked, without.fakeRelay.asked)
	}
}

// events that arrive above the walked region between two check-ins are not
// skipped by resuming lower down.
func TestNewEventsAboveMarkFetched(t *testing.T) {
	r := &slowRelay{
		fakeRelay: &fakeRelay{events: mk(100, 1_000_000, 13), cap: 20},
		pageCost:  10,
		budget:    30,
	}
	got := map[nostr.ID]bool{}
	_, m := checkIn(t, r, 0, 20, 1000, got, Mark{})
	if !m.Started() {
		t.Fatal("the first window should not have finished this backlog")
	}

	// 40 newer events land while we were away
	newer := mk(40, 1_000_000+nostr.Timestamp(100*13)+100, 7)
	for i := range newer {
		newer[i].ID[3] = 0xAA // keep them distinct from the first batch
	}
	r.fakeRelay.events = append(r.fakeRelay.events, newer...)

	for i := 0; i < 10; i++ {
		var res Result
		res, m = checkIn(t, r, 0, 20, 1000, got, m)
		if res.Complete {
			break
		}
	}
	missingNew := 0
	for _, e := range newer {
		if !got[e.ID] {
			missingNew++
		}
	}
	missingOld := 0
	for _, e := range mk(100, 1_000_000, 13) {
		if !got[e.ID] {
			missingOld++
		}
	}
	t.Logf("missing: %d of 40 new, %d of 100 old; mark %+v", missingNew, missingOld, m)
	if missingNew > 0 {
		t.Fatalf("%d events newer than the mark were skipped", missingNew)
	}
	if len(got) != 140 {
		t.Fatalf("want all 140, got %d", len(got))
	}
}

// a relay whose answers are cut after cut events, the way a slow circuit
// cuts a page of media wraps at the check-in's cap
type cutRelay struct {
	*fakeRelay
	cut int
}

func (r *cutRelay) page(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
	evs, err := r.fakeRelay.page(ctx, since, until, limit)
	if err != nil || len(evs) <= r.cut {
		return evs, err
	}
	return evs[:r.cut], context.DeadlineExceeded
}

// every page is cut before it ends, and still each check-in gets further
// than the last, until the whole backlog is in
func TestCutPagesStillGetDeeper(t *testing.T) {
	const total = 200
	r := &cutRelay{fakeRelay: &fakeRelay{events: mk(total, 1_000_000, 13), cap: 100}, cut: 30}
	got := map[nostr.ID]bool{}
	deliver := func(e nostr.Event) bool {
		if got[e.ID] {
			return false
		}
		got[e.ID] = true
		return true
	}
	first, _ := r.fakeRelay.page(context.Background(), 0, 1<<40, 20)
	oldest := first[len(first)-1].CreatedAt
	for _, e := range first {
		got[e.ID] = true
	}
	var m Mark
	var res Result
	deepest := oldest
	for i := 0; i < 20; i++ {
		res, m = Continue(context.Background(), r.page, 0, oldest, 100, 200, deliver, m)
		if res.Complete {
			break
		}
		if res.Until >= deepest {
			t.Fatalf("check-in %d did not get deeper than %d", i+1, deepest)
		}
		deepest = res.Until
	}
	if !res.Complete || len(got) != total {
		t.Fatalf("complete=%v, %d of %d", res.Complete, len(got), total)
	}
}

// with a mark, the pages above it stop at its top: the walked part is not
// fetched again on the way down
func TestAboveMarkDoesNotRefetchTheWalkedPart(t *testing.T) {
	evs := mk(300, 1_000_000, 10)
	r := &fakeRelay{events: evs, cap: 100}
	// the top 250 are walked already: everything from the 50th up
	m := Mark{Top: evs[299].CreatedAt, Cursor: evs[50].CreatedAt}
	// ten new ones above it
	newer := mk(10, evs[299].CreatedAt+100, 5)
	for i := range newer {
		newer[i].ID[3] = 0xBB
	}
	r.events = append(r.events, newer...)
	fetched := 0
	count := func(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
		out, err := r.page(ctx, since, until, limit)
		fetched += len(out)
		return out, err
	}
	got := map[nostr.ID]bool{}
	res, _ := Continue(context.Background(), count, 0, newer[9].CreatedAt+1, 100, 200,
		func(e nostr.Event) bool { got[e.ID] = true; return true }, m)
	if !res.Complete {
		t.Fatalf("%+v", res)
	}
	for _, e := range newer {
		if !got[e.ID] {
			t.Fatal("a new event above the mark was missed")
		}
	}
	for _, e := range evs[:50] {
		if !got[e.ID] {
			t.Fatal("an event below the mark was missed")
		}
	}
	// the new ten, the two boundary seconds and the fifty below
	if fetched > 10+2+51 {
		t.Fatalf("fetched %d events, the walked part came again", fetched)
	}
}
