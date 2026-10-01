// SPDX-License-Identifier: GPL-3.0-or-later
// a relay hands back stored events newest first and stops at its cap, a
// hundred on ours, and a photo alone is a hundred wraps. this walks back from
// the oldest event the first answer held, a page at a time, until the relay
// has nothing older inside the window.
package catchup

import (
	"context"
	"slices"

	"fiatjaf.com/nostr"
)

// Page asks one relay for up to limit events with since <= created_at <=
// until, newest first, and returns when the relay says that was all. A page
// cut short returns its error with the events it did get. More than limit
// may come back: live events the relay sent among the stored ones, and ties
// at the limit-th newest stamp.
type Page func(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error)

// Below is where a walk carries on under an answer to a request for limit
// events: the limit-th newest stamp of a full one, the oldest of any other.
// A live event sent among the stored ones can be stamped hours back, below
// stored events the relay never got to, while more events can only raise
// the limit-th newest. Ties at it are asked for again, until is inclusive.
func Below(stamps []nostr.Timestamp, limit int) nostr.Timestamp {
	if len(stamps) == 0 {
		return 0
	}
	s := slices.Clone(stamps)
	slices.Sort(s)
	if limit > 0 && len(s) >= limit {
		return s[len(s)-limit]
	}
	return s[0]
}

// Newest drops, in place and keeping the order, the events stamped below
// the limit-th newest of evs. The walk carries on from that stamp, so what
// is dropped is asked for again; everything stamped at it or above stays.
func Newest(evs []nostr.Event, limit int) []nostr.Event {
	if limit <= 0 || len(evs) <= limit {
		return evs
	}
	stamps := make([]nostr.Timestamp, len(evs))
	for i, ev := range evs {
		stamps[i] = ev.CreatedAt
	}
	low := Below(stamps, limit)
	kept := evs[:0]
	for _, ev := range evs {
		if ev.CreatedAt >= low {
			kept = append(kept, ev)
		}
	}
	clear(evs[len(kept):])
	return kept
}

// Answer follows an answer to a request for limit events while it comes,
// for Below of it so far. Only the limit newest stamps can decide it, so it
// keeps no more than twice the limit.
type Answer struct {
	limit  int
	stamps []nostr.Timestamp
}

func NewAnswer(limit int) *Answer { return &Answer{limit: limit} }

func (a *Answer) Add(ts nostr.Timestamp) {
	a.stamps = append(a.stamps, ts)
	if a.limit > 0 && len(a.stamps) >= 2*a.limit {
		slices.Sort(a.stamps)
		a.stamps = append(a.stamps[:0], a.stamps[len(a.stamps)-a.limit:]...)
	}
}

// Below of what has come so far
func (a *Answer) Below() nostr.Timestamp { return Below(a.stamps, a.limit) }

type Result struct {
	Pages    int
	Fetched  int
	Fresh    int
	Complete bool
	// where the walk stopped. on an incomplete result this is the resume
	// point: everything above it has been fetched, so the next attempt can
	// carry on from here instead of covering the same ground again.
	Until nostr.Timestamp
}

// Mark is how much of a relay's backlog has already been walked: everything
// between Cursor and Top. A relay whose backlog takes longer than one
// check-in is allowed keeps its Mark, so the next check-in spends its time on
// ground it has not covered yet. What reaches the relay later can be stamped
// inside the walked part; Hold covers that.
type Mark struct {
	Top    nostr.Timestamp
	Cursor nostr.Timestamp
}

func (m Mark) Started() bool { return m.Top > 0 }

// Continue pages the window, stepping over the part Mark says is already
// done. It returns the Mark to keep for next time; a zero Mark means the
// window is finished and the anchor may move.
//
// It is one downward walk, not two: a new gap paged before the old tail can
// eat every window, while one descending cursor cannot starve itself.
func Continue(ctx context.Context, fetch Page, since, oldest nostr.Timestamp,
	limit, maxPages int, deliver func(nostr.Event) bool, m Mark) (Result, Mark) {

	r := walk(ctx, fetch, since, oldest, limit, maxPages, deliver, m)
	if r.Complete {
		return r, Mark{}
	}
	return r, Mark{Top: maxTs(oldest, m.Top), Cursor: r.Until}
}

func maxTs(a, b nostr.Timestamp) nostr.Timestamp {
	if a > b {
		return a
	}
	return b
}

// Back pages from oldest down to since. deliver reports whether the event
// was new. Complete is false when a page failed, the context ended or
// maxPages ran out: the caller must then not move its anchor, so the next
// connect asks again.
func Back(ctx context.Context, fetch Page, since, oldest nostr.Timestamp,
	limit, maxPages int, deliver func(nostr.Event) bool) Result {
	return walk(ctx, fetch, since, oldest, limit, maxPages, deliver, Mark{})
}

// the walk itself. skip names an interval already covered; on reaching it the
// cursor jumps to its far side instead of asking for it again. that keeps the
// whole thing one monotonically descending cursor, so wherever it stops is a
// resume point.
func walk(ctx context.Context, fetch Page, since, oldest nostr.Timestamp,
	limit, maxPages int, deliver func(nostr.Event) bool, skip Mark) Result {
	var res Result
	until := oldest
	for res.Pages < maxPages {
		if skip.Started() && until <= skip.Top && until > skip.Cursor {
			until = skip.Cursor
		}
		res.Until = until
		if ctx.Err() != nil {
			return res
		}
		if until <= 0 || (since > 0 && until < since) {
			res.Complete = true
			return res
		}
		// above the part already walked, a page stops at its top, so the
		// walked part is not fetched again on the way down to it
		pageSince := since
		above := skip.Started() && until > skip.Top
		if above && skip.Top > pageSince {
			pageSince = skip.Top
		}
		evs, err := fetch(ctx, pageSince, until, limit)
		if err != nil {
			// a page cut short still brought what it brought, newest first,
			// so everything down to its oldest is in, and the next attempt
			// carries on from there instead of asking for the same page.
			// that holds for the stored ones only: a live event the relay
			// sent among them can be stamped below them, so a cut page with
			// limit events is judged as a full one is. with fewer there is
			// no telling them apart; our relay sends no live event before a
			// page's eose
			stamps := make([]nostr.Timestamp, 0, len(evs))
			for _, ev := range evs {
				res.Fetched++
				if deliver(ev) {
					res.Fresh++
				}
				stamps = append(stamps, ev.CreatedAt)
			}
			res.Until = until
			if len(stamps) > 0 {
				res.Until = min(Below(stamps, limit), until)
			}
			return res
		}
		res.Pages++
		if len(evs) == 0 {
			if above {
				until = skip.Cursor
				res.Until = until
				continue
			}
			res.Complete = true
			return res
		}
		fresh := 0
		stamps := make([]nostr.Timestamp, 0, len(evs))
		for _, ev := range evs {
			res.Fetched++
			if deliver(ev) {
				fresh++
			}
			stamps = append(stamps, ev.CreatedAt)
		}
		res.Fresh += fresh
		low := min(Below(stamps, limit), until)
		if low == until {
			// the page did not get below where it started: either the
			// tail, or a second holding more events than the relay hands
			// out. step over it. if that was the tail the next page
			// comes back empty, and an empty page is the only proof of the
			// end that holds for every relay.
			low = until - 1
		}
		until = low
		res.Until = until
	}
	return res
}
