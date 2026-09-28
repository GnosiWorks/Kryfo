// SPDX-License-Identifier: GPL-3.0-or-later
// a relay hands back stored events newest first and stops at its cap, a
// hundred on ours, and a photo alone is a hundred wraps. this walks back from
// the oldest event the first answer held, a page at a time, until the relay
// has nothing older inside the window.
package catchup

import (
	"context"

	"fiatjaf.com/nostr"
)

// Page asks one relay for up to limit events with since <= created_at <=
// until, newest first, and returns when the relay says that was all. A page
// cut short returns its error with the events it did get.
type Page func(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error)

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
// ground it has not covered yet.
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
			// carries on from there instead of asking for the same page
			low := until
			for _, ev := range evs {
				res.Fetched++
				if deliver(ev) {
					res.Fresh++
				}
				if ev.CreatedAt < low {
					low = ev.CreatedAt
				}
			}
			res.Until = low
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
		low := until
		for _, ev := range evs {
			res.Fetched++
			if deliver(ev) {
				fresh++
			}
			if ev.CreatedAt < low {
				low = ev.CreatedAt
			}
		}
		res.Fresh += fresh
		if low == until {
			// nothing in this page was older than where it started: either
			// the tail, or a second holding more events than the relay
			// hands out. step over it. if that was the tail the next page
			// comes back empty, and an empty page is the only proof of the
			// end that holds for every relay.
			low = until - 1
		}
		until = low
		res.Until = until
	}
	return res
}
