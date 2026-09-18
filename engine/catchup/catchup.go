// SPDX-License-Identifier: GPL-3.0-or-later
// a relay hands back stored events newest first and stops at its cap, a
// hundred on ours. a phone that was connected the whole time never meets
// that cap. one that was away does: a photo is a hundred wraps on its own,
// and whatever sat behind the newest hundred was never asked for again, so
// a file could not complete and an old-stamped text could be buried for
// good. this walks back from the oldest event the first answer held, a page
// at a time, until the relay has nothing older inside the window.
package catchup

import (
	"context"

	"fiatjaf.com/nostr"
)

// Page asks one relay for up to limit events with since <= created_at <=
// until, newest first, and returns when the relay says that was all.
type Page func(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error)

type Result struct {
	Pages    int
	Fetched  int
	Fresh    int
	Complete bool
}

// Back pages from oldest down to since. deliver reports whether the event
// was new. Complete is false when a page failed, the context ended or
// maxPages ran out: the caller must then not move its anchor, so the next
// connect asks again.
//
// it stops on an empty page, not on a short one: a relay may cap below what
// was asked for, and a short page from such a relay is not the end.
func Back(ctx context.Context, fetch Page, since, oldest nostr.Timestamp, limit, maxPages int, deliver func(nostr.Event) bool) Result {
	var res Result
	until := oldest
	for res.Pages < maxPages {
		if ctx.Err() != nil {
			return res
		}
		if until <= 0 || (since > 0 && until < since) {
			res.Complete = true
			return res
		}
		evs, err := fetch(ctx, since, until, limit)
		if err != nil {
			return res
		}
		res.Pages++
		if len(evs) == 0 {
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
	}
	return res
}
