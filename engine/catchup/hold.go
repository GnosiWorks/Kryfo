// SPDX-License-Identifier: GPL-3.0-or-later
package catchup

import "fiatjaf.com/nostr"

// Hold is what a relay's walk still owes the anchor. A Mark lets later walks
// step over a stretch, but a wrap is stamped up to ten hours before it is
// sent, so one that reaches the relay after its stretch was walked is
// stamped inside it, and no walk that steps over the stretch asks for it.
//
// While a walk is under way the relay's window is taken from no later than
// Floor, the anchor the walk began from, so the rest of the walk still
// reaches the bottom of it. A walk that stepped over stretches owes one more
// pass, taken from when it began: whatever reached the relay since is
// stamped no more than ten hours before Began. A walk that stepped over
// nothing owes nothing.
type Hold struct {
	Floor nostr.Timestamp
	Began nostr.Timestamp
}

func (h Hold) Held() bool { return h.Began > 0 }

// From is the anchor the relay's next window is taken from.
func (h Hold) From(anchor nostr.Timestamp) nostr.Timestamp {
	if h.Held() && h.Floor < anchor {
		return h.Floor
	}
	return anchor
}

// Start is a runner starting on an address with the anchor it read from the
// file. What our relay owed a process before this one is not known, only
// that none of it is later than the file. So it holds from there until a
// pass on it is clean, and another relay that answers first lifts neither
// its first window nor the file.
func (h Hold) Start(anchor, now nostr.Timestamp) Hold {
	if !h.Held() {
		return Hold{Floor: anchor, Began: now}
	}
	if anchor < h.Floor {
		h.Floor = anchor
	}
	return h
}

// Cut is a walk stopping short, on a connection that began at began and took
// its window from from. A walk that carried on from a Mark keeps the hold it
// has; one that began afresh holds from its own start.
func (h Hold) Cut(from, began nostr.Timestamp, resumed bool) Hold {
	if resumed && h.Held() {
		return h
	}
	if h.Held() && h.Floor < from {
		from = h.Floor
	}
	return Hold{Floor: from, Began: began}
}

// Done is a walk reaching the bottom of its window. stepped says it stepped
// over stretches walked on earlier connections.
func (h Hold) Done(stepped bool) Hold {
	if !stepped || !h.Held() {
		return Hold{}
	}
	return Hold{Floor: maxTs(h.Floor, h.Began), Began: h.Began}
}
