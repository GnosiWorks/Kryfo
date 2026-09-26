// SPDX-License-Identifier: GPL-3.0-or-later
package catchup

import (
	"context"
	"errors"
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
