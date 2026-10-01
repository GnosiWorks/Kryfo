// SPDX-License-Identifier: GPL-3.0-or-later
package catchup

import (
	"context"
	"errors"
	"math/rand"
	"slices"
	"sort"
	"testing"

	"fiatjaf.com/nostr"
)

// a relay with a cap: newest first, at most cap per answer, whatever was asked
type fakeRelay struct {
	events []nostr.Event
	cap    int
	asked  int
	failAt int
}

func (r *fakeRelay) page(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
	r.asked++
	if r.failAt > 0 && r.asked == r.failAt {
		return nil, errors.New("circuit died")
	}
	var hit []nostr.Event
	for _, e := range r.events {
		if e.CreatedAt >= since && e.CreatedAt <= until {
			hit = append(hit, e)
		}
	}
	sort.Slice(hit, func(i, j int) bool { return hit[i].CreatedAt > hit[j].CreatedAt })
	n := limit
	if r.cap < n {
		n = r.cap
	}
	if len(hit) > n {
		hit = hit[:n]
	}
	return hit, nil
}

func mk(n int, start nostr.Timestamp, step int) []nostr.Event {
	out := make([]nostr.Event, n)
	for i := range out {
		var id nostr.ID
		id[0], id[1], id[2] = byte(i), byte(i>>8), byte(i>>16)
		out[i] = nostr.Event{ID: id, CreatedAt: start + nostr.Timestamp(i*step)}
	}
	return out
}

func run(t *testing.T, r *fakeRelay, since nostr.Timestamp, limit, maxPages int) (Result, map[nostr.ID]bool) {
	t.Helper()
	got := map[nostr.ID]bool{}
	// the first answer, as the live subscription would have had it
	first, _ := r.page(context.Background(), since, 1<<40, limit)
	oldest := nostr.Timestamp(0)
	for _, e := range first {
		got[e.ID] = true
		if oldest == 0 || e.CreatedAt < oldest {
			oldest = e.CreatedAt
		}
	}
	res := Back(context.Background(), r.page, since, oldest, limit, maxPages, func(e nostr.Event) bool {
		if got[e.ID] {
			return false
		}
		got[e.ID] = true
		return true
	})
	return res, got
}

func TestEventsBehindCapArrive(t *testing.T) {
	r := &fakeRelay{events: mk(1234, 1000, 7), cap: 100}
	res, got := run(t, r, 500, 100, 200)
	if !res.Complete || len(got) != 1234 {
		t.Fatalf("complete=%v got=%d pages=%d", res.Complete, len(got), res.Pages)
	}
}

func TestRelayCapBelowLimit(t *testing.T) {
	r := &fakeRelay{events: mk(430, 1000, 3), cap: 50}
	res, got := run(t, r, 0, 100, 200)
	if !res.Complete || len(got) != 430 {
		t.Fatalf("complete=%v got=%d", res.Complete, len(got))
	}
}

func TestSinceIsRespected(t *testing.T) {
	r := &fakeRelay{events: mk(300, 1000, 10), cap: 100}
	res, got := run(t, r, 2500, 100, 200)
	want := 0
	for _, e := range r.events {
		if e.CreatedAt >= 2500 {
			want++
		}
	}
	if !res.Complete || len(got) != want {
		t.Fatalf("complete=%v got=%d want=%d", res.Complete, len(got), want)
	}
}

func TestSameSecondEventsDoNotLoop(t *testing.T) {
	ev := mk(250, 5000, 0)
	r := &fakeRelay{events: append(ev, mk(40, 100, 1)...), cap: 100}
	for i := range r.events[250:] {
		r.events[250+i].ID[5] = 9
	}
	res, got := run(t, r, 0, 100, 50)
	if !res.Complete {
		t.Fatalf("did not finish: %+v", res)
	}
	// the second itself cannot be paged past its first hundred, that is the
	// relay's limit and not ours. everything older must still arrive.
	older := 0
	for id := range got {
		if id[5] == 9 {
			older++
		}
	}
	if older != 40 {
		t.Fatalf("older events: %d of 40", older)
	}
}

func TestFailedPageIsNotComplete(t *testing.T) {
	r := &fakeRelay{events: mk(500, 1000, 5), cap: 100, failAt: 3}
	res, _ := run(t, r, 0, 100, 200)
	if res.Complete {
		t.Fatal("a broken catch-up reported complete")
	}
}

func TestPageCeilingIsNotComplete(t *testing.T) {
	r := &fakeRelay{events: mk(1000, 1000, 5), cap: 100}
	res, _ := run(t, r, 0, 100, 3)
	if res.Complete || res.Pages != 3 {
		t.Fatalf("%+v", res)
	}
}

func TestCancelledIsNotComplete(t *testing.T) {
	r := &fakeRelay{events: mk(500, 1000, 5), cap: 100}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	res := Back(ctx, r.page, 0, 3000, 100, 10, func(nostr.Event) bool { return true })
	if res.Complete || res.Pages != 0 {
		t.Fatalf("%+v", res)
	}
}

func TestNothingOlderIsOneCheapPage(t *testing.T) {
	r := &fakeRelay{events: mk(100, 1000, 5), cap: 100}
	res, got := run(t, r, 0, 100, 200)
	if !res.Complete || len(got) != 100 || res.Pages > 3 {
		t.Fatalf("%+v got=%d", res, len(got))
	}
}

// a relay that sends a live event, stamped below everything it holds, among
// the stored ones of every page: a full page is walked from its limit-th
// newest, so nothing stored is stepped over
func TestALiveEventInAFullPageStepsOverNothing(t *testing.T) {
	r := &fakeRelay{events: mk(1000, 100000, 60), cap: 100}
	n := 0
	page := func(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
		evs, err := r.page(ctx, since, until, limit)
		if len(evs) < limit {
			return evs, err
		}
		n++
		var live nostr.Event
		live.ID[3], live.ID[4] = 0xff, byte(n)
		live.CreatedAt = 1000 + nostr.Timestamp(n)
		at := len(evs) / 3
		return append(evs[:at:at], append([]nostr.Event{live}, evs[at:]...)...), err
	}
	got := map[nostr.ID]bool{}
	res := Back(context.Background(), page, 0, 1<<40, 100, 200, func(e nostr.Event) bool {
		fresh := !got[e.ID]
		got[e.ID] = true
		return fresh
	})
	if !res.Complete {
		t.Fatalf("did not finish: %+v", res)
	}
	for _, e := range r.events {
		if !got[e.ID] {
			t.Fatalf("the walk stepped over a stored event stamped %d: %+v", e.CreatedAt, res)
		}
	}
}

func TestBelowIsTheLimitThNewestOfAFullAnswer(t *testing.T) {
	ts := []nostr.Timestamp{50, 10, 40, 40, 30, 5}
	for _, c := range []struct {
		limit int
		want  nostr.Timestamp
	}{{4, 30}, {3, 40}, {6, 5}, {7, 5}, {0, 5}} {
		if got := Below(ts, c.limit); got != c.want {
			t.Fatalf("limit %d: %d, want %d", c.limit, got, c.want)
		}
	}
	if Below(nil, 3) != 0 {
		t.Fatal("an empty answer has a place")
	}
}

func TestNewestKeepsTiesAtTheLimitThStamp(t *testing.T) {
	var evs []nostr.Event
	for i, ts := range []nostr.Timestamp{50, 10, 40, 40, 30, 5, 40} {
		var e nostr.Event
		e.ID[0] = byte(i)
		e.CreatedAt = ts
		evs = append(evs, e)
	}
	got := Newest(append([]nostr.Event(nil), evs...), 3)
	want := []byte{0, 2, 3, 6}
	if len(got) != len(want) {
		t.Fatalf("kept %d, want %d", len(got), len(want))
	}
	for i, w := range want {
		if got[i].ID[0] != w {
			t.Fatalf("kept %v at %d, want event %d in the order given", got[i].ID[0], i, w)
		}
	}
	if len(Newest(evs[:3], 3)) != 3 || len(Newest(evs, 0)) != len(evs) {
		t.Fatal("dropped from an answer no larger than its limit")
	}
}

// a relay that keeps to the limit, newest first, and sends up to k live
// events among a page's stored ones, stamped anywhere in the window, the
// way a contact's photo can arrive while a page is written, budget in all.
// the reader is the one relayPage is: it reads up to reads times the limit
// and keeps the newest.
type liveRelay struct {
	rng    *rand.Rand
	store  []nostr.Event
	k      int
	budget int
	reads  int
	nextID int
}

func (l *liveRelay) id() nostr.ID {
	l.nextID++
	var id nostr.ID
	id[0], id[1], id[2], id[3] = 0xee, byte(l.nextID), byte(l.nextID>>8), byte(l.nextID>>16)
	return id
}

func (l *liveRelay) page(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
	var hit []nostr.Event
	for _, e := range l.store {
		if e.CreatedAt >= since && e.CreatedAt <= until {
			hit = append(hit, e)
		}
	}
	sort.SliceStable(hit, func(i, j int) bool { return hit[i].CreatedAt > hit[j].CreatedAt })
	if len(hit) > limit {
		hit = hit[:limit]
	}
	wire := append([]nostr.Event(nil), hit...)
	k := min(l.rng.Intn(l.k+1), l.budget)
	l.budget -= k
	for i := 0; i < k; i++ {
		var ts nostr.Timestamp
		switch l.rng.Intn(4) {
		case 0:
			ts = until
		case 1:
			ts = until
			if len(hit) > 0 {
				ts = hit[l.rng.Intn(len(hit))].CreatedAt
			}
		default:
			lo := max(since, 1)
			ts = lo + nostr.Timestamp(l.rng.Int63n(int64(until-lo+1)))
		}
		ev := nostr.Event{ID: l.id(), CreatedAt: ts}
		l.store = append(l.store, ev)
		at := l.rng.Intn(len(wire) + 1)
		wire = slices.Insert(wire, at, ev)
	}
	var out []nostr.Event
	for i, ev := range wire {
		if i == limit*l.reads {
			break
		}
		out = Newest(append(out, ev), limit)
	}
	return out, nil
}

// whether a walk over a liveRelay ends with every event stored before it
// began, and how many it stepped over
func walkWithLive(seed int64, k, reads int, marks bool) (bool, int) {
	rng := rand.New(rand.NewSource(seed))
	l := &liveRelay{rng: rng, k: k, budget: 4 * k, reads: reads}
	const limit = 20
	n := 50 + rng.Intn(400)
	ts := nostr.Timestamp(100000)
	same := 0
	for i := 0; i < n; i++ {
		// ties, never limit on one stamp: the walk cannot page inside one
		if rng.Intn(3) != 0 {
			ts -= nostr.Timestamp(rng.Intn(50))
		}
		if i > 0 && l.store[i-1].CreatedAt == ts {
			same++
		} else {
			same = 0
		}
		if same >= limit-1 {
			ts--
			same = 0
		}
		l.store = append(l.store, nostr.Event{ID: l.id(), CreatedAt: ts})
	}
	before := slices.Clone(l.store)
	since := max(nostr.Timestamp(100000-60*int64(n)), 1)
	if rng.Intn(2) == 0 {
		since = 1
	}
	got := map[nostr.ID]bool{}
	deliver := func(e nostr.Event) bool { f := !got[e.ID]; got[e.ID] = true; return f }
	complete := false
	if marks {
		var m Mark
		for run := 0; run < 400 && !complete; run++ {
			var r Result
			r, m = Continue(context.Background(), l.page, since, 100000, limit, 1+rng.Intn(3), deliver, m)
			complete = r.Complete
		}
	} else {
		complete = Back(context.Background(), l.page, since, 100000, limit, 100000, deliver).Complete
	}
	missing := 0
	for _, e := range before {
		if e.CreatedAt >= since && !got[e.ID] {
			missing++
		}
	}
	return complete, missing
}

// up to three times the limit in live events inside every page, and
// nothing stored is stepped over, walked in one go or a few pages per
// check-in
func TestLiveBurstsInsidePagesStepOverNothing(t *testing.T) {
	for _, marks := range []bool{false, true} {
		for seed := int64(0); seed < 1500; seed++ {
			complete, missing := walkWithLive(seed, 60, 4, marks)
			if !complete || missing > 0 {
				t.Fatalf("marks %v seed %d: complete %v with %d stored events stepped over",
					marks, seed, complete, missing)
			}
		}
	}
}

// a page cut after the relay sent its limit stored events and a live one,
// stamped below them all: the next check-in carries on from the oldest
// stored one, not from the live one
func TestACutPageWithALiveEventStepsOverNothing(t *testing.T) {
	r := &fakeRelay{events: mk(500, 100000, 60), cap: 100}
	cut := true
	page := func(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
		evs, err := r.page(ctx, since, until, limit)
		if !cut || len(evs) < limit {
			return evs, err
		}
		cut = false
		var live nostr.Event
		live.ID[3] = 0xff
		live.CreatedAt = 100001
		return append(evs, live), errors.New("circuit died")
	}
	got := map[nostr.ID]bool{}
	deliver := func(e nostr.Event) bool { f := !got[e.ID]; got[e.ID] = true; return f }
	var m Mark
	complete := false
	for run := 0; run < 20 && !complete; run++ {
		var res Result
		res, m = Continue(context.Background(), page, 0, 1<<40, 100, 2, deliver, m)
		complete = res.Complete
	}
	if !complete {
		t.Fatal("did not finish")
	}
	for _, e := range r.events {
		if !got[e.ID] {
			t.Fatalf("the walk stepped over a stored event stamped %d", e.CreatedAt)
		}
	}
}

// an answer followed while it comes gives what Below of all of it gives,
// and keeps no more than twice the limit
func TestAnAnswerKeepsWhatBelowNeeds(t *testing.T) {
	rng := rand.New(rand.NewSource(1))
	for _, limit := range []int{0, 1, 3, 20} {
		for round := 0; round < 200; round++ {
			a := NewAnswer(limit)
			var all []nostr.Timestamp
			n := rng.Intn(150)
			for i := 0; i < n; i++ {
				ts := nostr.Timestamp(1 + rng.Intn(60))
				a.Add(ts)
				all = append(all, ts)
				if got, want := a.Below(), Below(all, limit); got != want {
					t.Fatalf("limit %d after %d: %d, want %d", limit, len(all), got, want)
				}
				if limit > 0 && len(a.stamps) >= 2*limit {
					t.Fatalf("limit %d: kept %d stamps", limit, len(a.stamps))
				}
			}
		}
	}
}
