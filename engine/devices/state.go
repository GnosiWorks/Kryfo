// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"slices"
	"time"
)

// what the engine keeps of a Book, an Own, a Quiet and a Pool across a
// restart: the app stores these rows and hands them back at the next start.
// every list is read again under the verifier as it comes back, and every
// bundle parsed again, so a row that no longer holds is left out.

// Kept is what a Book holds for one contact identity.
type Kept struct {
	Identity Key
	// the signed list held, nil before the first
	List       []byte
	FromInvite bool
	// listed keys a message from the contact decrypted under
	Proven []Key
	PQ     bool
}

// Kept is what the book holds for the contact identity.
func (b *Book) Kept(identity Key) (Kept, bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return Kept{}, false
	}
	out := Kept{Identity: identity, FromInvite: k.fromInvite, PQ: k.pq}
	if k.cur != nil {
		out.List = k.cur.Wire()
	}
	for p := range k.proven {
		out.Proven = append(out.Proven, p)
	}
	slices.SortFunc(out.Proven, func(a, b Key) int { return bytes.Compare(a[:], b[:]) })
	return out, true
}

// Restore puts back what Kept gave before a restart. the contact is added
// as Add adds it; its list must read under v and name the identity; a
// proof of a key the list no longer names is left out. the claimants come
// back as from Add.
func (b *Book) Restore(s Kept, v Verifier) ([]Key, error) {
	var l *List
	if s.List != nil {
		var err error
		if l, err = ReadList(s.List, v); err != nil {
			return nil, err
		}
		if l.Identity != s.Identity {
			return nil, ErrWrongIdentity
		}
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[s.Identity]
	if !ok {
		if b.heldElsewhere(s.Identity, s.Identity) {
			return nil, ErrTaken
		}
		k = newKnown(s.Identity)
		b.known[s.Identity] = k
	}
	k.cur, k.fromInvite = l, l != nil && s.FromInvite
	k.pq = k.pq || s.PQ
	clear(k.proven)
	if l != nil {
		for _, p := range s.Proven {
			if _, listed := l.FindKey(p); listed && p != s.Identity {
				k.proven[p] = true
			}
		}
	}
	return b.settle(), nil
}

// Contacts are the contact identities in the book.
func (b *Book) Contacts() []Key {
	b.mu.Lock()
	defer b.mu.Unlock()
	out := make([]Key, 0, len(b.known))
	for k := range b.known {
		out = append(out, k)
	}
	return out
}

// OwnKept is an identity's own list held, and this device's key on it.
type OwnKept struct {
	Identity Key
	List     []byte
	Mine     Key
}

// Kept is the identity's own list held, false before the first.
func (o *Own) Kept(identity Key) (OwnKept, bool) {
	o.mu.Lock()
	defer o.mu.Unlock()
	l := o.lists[identity]
	if l == nil {
		return OwnKept{}, false
	}
	return OwnKept{Identity: identity, List: l.Wire(), Mine: o.me[identity].Key}, true
}

// Restore puts back what Kept gave before a restart: a list of the
// identity, read under v, that names this device's key.
func (o *Own) Restore(s OwnKept, v Verifier) error {
	l, err := ReadList(s.List, v)
	if err != nil {
		return err
	}
	if l.Identity != s.Identity {
		return ErrWrongIdentity
	}
	me, ok := l.FindKey(s.Mine)
	if !ok {
		return ErrNotListed
	}
	o.mu.Lock()
	defer o.mu.Unlock()
	o.lists[s.Identity], o.me[s.Identity] = l, me
	return nil
}

// QuietKept is what Quiet holds for one device.
type QuietKept struct {
	Identity Key
	Device   uint8
	Key      Key
	// zero when not set
	First, Session, Probed time.Time
	Silent                 bool
	Under                  uint64
}

// Kept is what Quiet holds for the device, false when nothing.
func (q *Quiet) Kept(identity Key, device uint8) (QuietKept, bool) {
	q.mu.Lock()
	defer q.mu.Unlock()
	r := q.rows[slotKey{identity, device}]
	if r == nil {
		return QuietKept{}, false
	}
	return QuietKept{
		Identity: identity, Device: device, Key: r.key,
		First: r.first, Session: r.session, Probed: r.probed,
		Silent: r.silent, Under: r.under,
	}, true
}

// Slots are the devices Quiet holds anything for under identity.
func (q *Quiet) Slots(identity Key) []uint8 {
	q.mu.Lock()
	defer q.mu.Unlock()
	var out []uint8
	for k := range q.rows {
		if k.identity == identity {
			out = append(out, k.device)
		}
	}
	slices.Sort(out)
	return out
}

// Restore puts back what Kept gave before a restart.
func (q *Quiet) Restore(s QuietKept) {
	q.mu.Lock()
	defer q.mu.Unlock()
	q.rows[slotKey{s.Identity, s.Device}] = &quietRow{
		key: s.Key, first: s.First, session: s.Session, probed: s.Probed,
		silent: s.Silent, under: s.Under,
	}
}

// PoolBundle is one kyber id the pool took for a device. KDB1 is nil once
// the bundle went out or aged out: its id is kept so the same bundle is
// never taken twice.
type PoolBundle struct {
	Kyber uint32
	Spk   uint32
	KDB1  []byte
	// when it ages from
	At   time.Time
	Last bool
}

// PoolKept is what the pool holds for one device of an identity.
type PoolKept struct {
	Identity Key
	Entry    Entry
	// the one-time bundles oldest first, then the last resort, then the
	// spent ids by id
	Bundles []PoolBundle
}

// Kept is what the pool holds for identity's device, false when nothing.
func (p *Pool) Kept(identity Key, device uint8) (PoolKept, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	r := p.rows[slotKey{identity, device}]
	if r == nil {
		return PoolKept{}, false
	}
	out := PoolKept{Identity: identity, Entry: r.entry}
	held := map[uint32]bool{}
	add := func(b poolBundle, last bool) {
		bl, err := ParseBundle(b.b, identity)
		if err != nil {
			return
		}
		held[bl.KyberID] = true
		out.Bundles = append(out.Bundles, PoolBundle{Kyber: bl.KyberID, Spk: b.spk, KDB1: bytes.Clone(b.b), At: b.at, Last: last})
	}
	for _, b := range r.once {
		add(b, false)
	}
	if r.last != nil {
		add(*r.last, true)
	}
	var spent []uint32
	for id := range r.kyber {
		if !held[id] {
			spent = append(spent, id)
		}
	}
	slices.Sort(spent)
	for _, id := range spent {
		out.Bundles = append(out.Bundles, PoolBundle{Kyber: id})
	}
	return out, true
}

// Restore puts back what Kept gave before a restart. each bundle must
// still be the device's own, on its kyber id, and at most one last resort;
// on any error nothing is kept for the device.
func (p *Pool) Restore(s PoolKept) error {
	if s.Entry.Phone {
		return ErrPhone
	}
	r := &pooled{entry: s.Entry, kyber: map[uint32]bool{}}
	for _, b := range s.Bundles {
		if r.kyber[b.Kyber] {
			return ErrDuplicate
		}
		r.kyber[b.Kyber] = true
		if b.KDB1 == nil {
			continue
		}
		bl, err := ParseBundle(b.KDB1, s.Identity)
		if err != nil {
			return err
		}
		e := s.Entry
		if !bl.HasKey || bl.Key != e.Key || bl.Device != e.ID || bl.Reg != e.Reg || bl.KyberID != b.Kyber || bl.SpkID != b.Spk {
			return ErrNotListed
		}
		pb := poolBundle{b: bytes.Clone(b.KDB1), at: b.At, spk: b.Spk}
		if b.Last {
			if r.last != nil {
				return ErrDuplicate
			}
			r.last = &pb
			continue
		}
		r.once = append(r.once, pb)
	}
	// oldest first, as Put keeps them
	slices.SortStableFunc(r.once, func(a, b poolBundle) int { return a.at.Compare(b.at) })
	p.mu.Lock()
	defer p.mu.Unlock()
	p.rows[slotKey{s.Identity, s.Entry.ID}] = r
	return nil
}

// Slots are the devices the pool holds anything for under identity.
func (p *Pool) Slots(identity Key) []uint8 {
	p.mu.Lock()
	defer p.mu.Unlock()
	var out []uint8
	for k := range p.rows {
		if k.identity == identity {
			out = append(out, k.device)
		}
	}
	slices.Sort(out)
	return out
}
