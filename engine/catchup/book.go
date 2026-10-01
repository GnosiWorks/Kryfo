// SPDX-License-Identifier: GPL-3.0-or-later
package catchup

import "fiatjaf.com/nostr"

// Book is where each relay's walk has got to and what it owes the anchor,
// by one key per relay and address. Only our relay holds anything: a sender
// in balanced mode publishes only there and public relays may refuse media
// slices, so most wraps only it has. That is a trade-off, not a guarantee. A
// send counts once any relay takes it and ours is not tried again, so a wrap
// ours refused or never got is on public relays alone, and a walk there that
// stepped over the stretch it is stamped into does not come back for it.
// Holding the anchor for public relays as well would let one that never
// gets through hold it for good. Our relay's entries, an onion and its
// clearnet name, are ways into one store, so each takes its window from the
// lowest floor any of them owes, and a pass on one lets the others go. A
// Book is not safe for concurrent use.
type Book struct {
	Marks map[string]Mark
	Holds map[string]Hold
	Freed map[string]Freed
}

// Freed is a key let go of by a pass on another entry of our relay, or by a
// refusal: nothing it owed from From down is owed any more. N counts them,
// so a connection that began before one does not hold again for what the
// pass took.
type Freed struct {
	N    uint64
	From nostr.Timestamp
}

func NewBook() *Book {
	return &Book{Marks: map[string]Mark{}, Holds: map[string]Hold{}, Freed: map[string]Freed{}}
}

// Conn is what a connection took from the book as it connected.
type Conn struct {
	Key string
	// Own: the relay is one of our relay's entries, the others are Twins
	Own   bool
	Twins []string
	// the relay was part way through a walk
	Resumed bool
	// the anchor the window is taken from, and what the walk owes if it
	// stops short. only our relay owes anything
	Base nostr.Timestamp
	Owed Hold
	// Freed's count for the key then
	freed uint64
}

func (b *Book) setHold(key string, h Hold) {
	if h.Held() {
		b.Holds[key] = h
	} else {
		delete(b.Holds, key)
	}
}

// Connect is a connection to key from the anchor last at now. own names the
// keys of our relay's entries for the same address.
func (b *Book) Connect(key string, own []string, last, now nostr.Timestamp) Conn {
	c := Conn{Key: key, Base: last, Resumed: b.Marks[key].Started(), freed: b.Freed[key].N}
	for _, k := range own {
		if k == key {
			c.Own = true
		} else {
			c.Twins = append(c.Twins, k)
		}
	}
	if !c.Own {
		return c
	}
	c.Base = b.Holds[key].From(c.Base)
	for _, k := range c.Twins {
		c.Base = b.Holds[k].From(c.Base)
	}
	c.Owed = b.Holds[key].Cut(c.Base, now, c.Resumed)
	return c
}

// a pass on another entry, or a refusal, came after c connected and took
// all its walk owes
func (b *Book) covered(c Conn) bool {
	f := b.Freed[c.Key]
	return f.N != c.freed && c.Owed.Floor >= f.From
}

// Owe is a connection's first answer coming full: the walk owes what c says.
func (b *Book) Owe(c Conn) {
	if c.Own && !b.covered(c) {
		b.setHold(c.Key, c.Owed)
	}
}

// Cut is a walk stopping short at m.
func (b *Book) Cut(c Conn, m Mark) {
	if b.covered(c) {
		return
	}
	if m.Started() {
		b.Marks[c.Key] = m
	}
	if c.Own {
		b.setHold(c.Key, c.Owed)
	}
}

// KeepFirst is a connection's first answer cut short, its oldest event at
// oldest: everything from top down to it is in, and the next walk may step
// over it. when a gap lies between this and the place already kept, the
// kept place stays.
func (b *Book) KeepFirst(c Conn, oldest, top nostr.Timestamp) {
	if oldest <= 0 || b.covered(c) {
		return
	}
	if c.Own {
		b.setHold(c.Key, c.Owed)
	}
	m := b.Marks[c.Key]
	switch {
	case !m.Started():
		m = Mark{Top: top, Cursor: oldest}
	case oldest <= m.Top:
		m = Mark{Top: top, Cursor: min(m.Cursor, oldest)}
	default:
		return
	}
	b.Marks[c.Key] = m
}

// Done is a walk reaching the bottom of its window. stepped: it stepped over
// stretches walked on earlier connections. on our relay the pass took
// everything the store had from c.Base down, so the other entries owe none
// of it; what reached the store since is left to this entry's hold.
func (b *Book) Done(c Conn, stepped bool) {
	delete(b.Marks, c.Key)
	if !c.Own {
		return
	}
	b.setHold(c.Key, b.Holds[c.Key].Done(stepped))
	for _, k := range c.Twins {
		b.Freed[k] = Freed{N: b.Freed[k].N + 1, From: c.Base}
		if h := b.Holds[k]; h.Held() && h.Floor >= c.Base {
			delete(b.Holds, k)
			delete(b.Marks, k)
		}
	}
}

// Refused is the relay answering the subscription with CLOSED. it hands over
// nothing, so it owes nothing, and a walk still under way on it does not
// hold again.
func (b *Book) Refused(c Conn) {
	delete(b.Marks, c.Key)
	delete(b.Holds, c.Key)
	b.Freed[c.Key] = Freed{N: b.Freed[c.Key].N + 1}
}

// Start is a runner starting on an address, see Hold.Start. only our relay
// holds: a public relay that never gets through must not keep the anchor
// file back.
func (b *Book) Start(own []string, anchor, now nostr.Timestamp) {
	for _, k := range own {
		b.setHold(k, b.Holds[k].Start(anchor, now))
	}
}

// Floor is the lowest anchor a walk on our relay still owes.
func (b *Book) Floor(own []string) (nostr.Timestamp, bool) {
	var low nostr.Timestamp
	held := false
	for _, k := range own {
		if h := b.Holds[k]; h.Held() && (!held || h.Floor < low) {
			low, held = h.Floor, true
		}
	}
	return low, held
}
