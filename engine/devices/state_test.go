// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"crypto/rand"
	"errors"
	"slices"
	"testing"
	"time"
)

// a book kept and restored into a fresh one answers every question the
// same: the list, its source, the proofs, pq, the disputes
func TestABookComesBackAfterARestart(t *testing.T) {
	k := newFanoutKit(t, 1, 3)
	bob := k.bob.id.pub
	desk := k.bob.list.Devices[1]
	if _, err := k.book.Proven(bob, desk.Key); err != nil {
		t.Fatal(err)
	}
	if err := k.book.SawPQ(bob); err != nil {
		t.Fatal(err)
	}
	// carol lists one of bob's proven keys: hers is disputed
	carol := newAccount(t, k.s)
	n, err := carol.list.Add(Entry{ID: 40, Key: desk.Key, Reg: 9}, rand.Reader)
	carol.set(t, n, err)
	if _, err := k.book.Add(carol.id.pub); err != nil {
		t.Fatal(err)
	}
	if _, _, _, err := k.book.Accept(carol.id.pub, carol.wire, FromSession(carol.id.pub), k.s); err != nil {
		t.Fatal(err)
	}
	// dan is known from his invite alone
	dan := newAccount(t, k.s)
	n, err = dan.list.Add(Entry{ID: 3, Key: mustKey(t), Reg: 8, Answers: true}, rand.Reader)
	dan.set(t, n, err)
	if _, err := k.book.Add(dan.id.pub); err != nil {
		t.Fatal(err)
	}
	if _, _, _, err := k.book.Accept(dan.id.pub, dan.wire, FromInvite(), k.s); err != nil {
		t.Fatal(err)
	}

	fresh := NewBook(k.me.id.pub)
	fresh.Own(k.ownKeys()...)
	for _, c := range []Key{bob, carol.id.pub, dan.id.pub} {
		s, ok := k.book.Kept(c)
		if !ok {
			t.Fatal("not kept")
		}
		if _, err := fresh.Restore(s, k.s); err != nil {
			t.Fatal(err)
		}
		got, _ := fresh.Kept(c)
		if !bytes.Equal(got.List, s.List) || got.FromInvite != s.FromInvite || got.PQ != s.PQ || !slices.Equal(got.Proven, s.Proven) {
			t.Fatalf("kept %x differs after restore", c[:4])
		}
	}
	if !fresh.PQ(bob) || fresh.PQ(carol.id.pub) {
		t.Fatal("pq not kept")
	}
	if !slices.Equal(fresh.Claimants(), []Key{carol.id.pub}) {
		t.Fatalf("claimants after restore: %d", len(fresh.Claimants()))
	}
	if err := fresh.Admit(carol.id.pub, 40, desk.Key); !errors.Is(err, ErrTaken) {
		t.Fatalf("carol's claim admitted after restore: %v", err)
	}
	if err := fresh.Admit(bob, desk.ID, desk.Key); err != nil {
		t.Fatal(err)
	}
	// dan's invite list still gives way to his session's, and only once
	n, err = dan.list.Settled(rand.Reader)
	dan.set(t, n, err)
	if _, out, _, err := fresh.Accept(dan.id.pub, dan.wire, FromSession(dan.id.pub), k.s); err != nil || out != Changed {
		t.Fatalf("dan's session list after restore: %v %v", out, err)
	}
	// a classic phone session is still refused after pq
	f := &Fanout{Book: fresh}
	if _, err := f.To(k.me.id.pub, bob, Peer{Devices: true, PhoneClassic: true}, time.Now()); !errors.Is(err, ErrClassic) {
		t.Fatalf("classic after restore: %v", err)
	}
}

func TestABookRefusesWhatDoesNotHold(t *testing.T) {
	k := newFanoutKit(t, 0, 2)
	bob := k.bob.id.pub
	s, _ := k.book.Kept(bob)
	fresh := func() *Book { return NewBook(k.me.id.pub) }
	bad := s
	bad.List = bytes.Clone(s.List)
	bad.List[len(bad.List)-1] ^= 1
	if _, err := fresh().Restore(bad, k.s); !errors.Is(err, ErrSignature) {
		t.Fatalf("a list whose signature broke: %v", err)
	}
	other := s
	other.Identity = k.me.id.pub
	if _, err := fresh().Restore(other, k.s); err == nil {
		t.Fatal("bob's list under my own key")
	}
	// a proof of a key the list does not name is left out
	stray := s
	stray.Proven = []Key{mustKey(t), k.bob.list.Devices[1].Key}
	b := fresh()
	if _, err := b.Restore(stray, k.s); err != nil {
		t.Fatal(err)
	}
	got, _ := b.Kept(bob)
	if len(got.Proven) != 1 || got.Proven[0] != k.bob.list.Devices[1].Key {
		t.Fatalf("proofs after restore: %d", len(got.Proven))
	}
	// no list, no invite flag
	none := Kept{Identity: bob, FromInvite: true}
	b = fresh()
	if _, err := b.Restore(none, k.s); err != nil {
		t.Fatal(err)
	}
	if got, _ := b.Kept(bob); got.List != nil || got.FromInvite {
		t.Fatal("an empty contact came back with something")
	}
}

func TestAnOwnListComesBackAfterARestart(t *testing.T) {
	k := newFanoutKit(t, 2, 0)
	me := k.me.id.pub
	s, ok := k.own.Kept(me)
	if !ok || s.Mine != me {
		t.Fatal("own list not kept")
	}
	o := NewOwn()
	if err := o.Restore(s, k.s); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(ids(slotsOf(o.Others(me))), ids(slotsOf(k.own.Others(me)))) {
		t.Fatal("others differ after restore")
	}
	// it moves forward from where it was
	if _, err := o.Set(me, s.List, me, FromSession(me), k.s); err != nil {
		t.Fatalf("the same list again: %v", err)
	}
	e := k.me.list.Devices[1]
	k.me.unlink(t, e.ID)
	gone, err := o.Set(me, k.me.wire, me, FromSession(me), k.s)
	if err != nil || len(gone) != 1 || gone[0].ID != e.ID {
		t.Fatalf("a removal after restore: %v %v", gone, err)
	}
	notMine := s
	notMine.Mine = mustKey(t)
	if err := NewOwn().Restore(notMine, k.s); !errors.Is(err, ErrNotListed) {
		t.Fatalf("a list without this device: %v", err)
	}
	broken := s
	broken.List = bytes.Clone(s.List)
	broken.List[10] ^= 1
	if err := NewOwn().Restore(broken, k.s); err == nil {
		t.Fatal("a broken own list restored")
	}
}

func slotsOf(es []Entry) []Slot {
	var out []Slot
	for _, e := range es {
		out = append(out, Slot{Device: e.ID})
	}
	return out
}

// a device going quiet keeps counting across a restart: its 15 and 30
// days run from the first copy, not from the start
func TestQuietCountsAcrossARestart(t *testing.T) {
	k := newFanoutKit(t, 0, 1)
	bob := k.bob.id.pub
	e := k.bob.list.Devices[1]
	v := k.bob.list.Version
	t0 := time.Unix(1_760_000_000, 0)
	q := NewQuiet()
	q.Sent(bob, e.ID, e.Key, t0)
	restart := func(q *Quiet) *Quiet {
		n := NewQuiet()
		for _, d := range q.Slots(bob) {
			s, _ := q.Kept(bob, d)
			n.Restore(s)
		}
		return n
	}
	q = restart(q)
	if st := q.State(bob, e.ID, e.Key, v, t0.Add(QuietRebuild)); st != Rebuild {
		t.Fatalf("day 15 after a restart: %v", st)
	}
	q.Rebuilt(bob, e.ID)
	q = restart(q)
	if st := q.State(bob, e.ID, e.Key, v, t0.Add(QuietRebuild+time.Hour)); st != Open {
		t.Fatalf("rebuilt, restarted: %v", st)
	}
	q.Sent(bob, e.ID, e.Key, t0.Add(QuietRebuild+time.Hour))
	if st := q.State(bob, e.ID, e.Key, v, t0.Add(QuietSilent)); st != Silent {
		t.Fatalf("day 30: %v", st)
	}
	q = restart(q)
	if st := q.State(bob, e.ID, e.Key, v, t0.Add(QuietSilent+time.Hour)); st != Silent {
		t.Fatalf("silent across a restart: %v", st)
	}
	if st := q.State(bob, e.ID, e.Key, v, t0.Add(QuietSilent+QuietProbe)); st != Rebuild {
		t.Fatalf("the weekly probe after a restart: %v", st)
	}
	q = restart(q)
	if st := q.State(bob, e.ID, e.Key, v, t0.Add(QuietSilent+QuietProbe+time.Hour)); st != Silent {
		t.Fatalf("the probe's time not kept: %v", st)
	}
	if !q.Fresh(bob, e.ID, e.Key) {
		t.Fatal("a fresh bundle for a silent device after a restart")
	}
	if len(q.Slots(bob)) != 0 {
		t.Fatal("fresh left a row")
	}
}

// the pool hands out after a restart exactly what it would have, and a
// kyber id it handed out before is still refused
func TestThePoolComesBackAfterARestart(t *testing.T) {
	s := newShim()
	me := newAccount(t, s)
	desk := me.linkReg(t)
	t0 := time.Unix(1_760_000_000, 0)
	kdb1 := func(kyber uint32) []byte { return poolKDB1(t, kyber, 7, desk) }
	p := NewPool()
	if err := p.Put(me.id.pub, desk, [][]byte{kdb1(10), kdb1(11)}, kdb1(1), t0.Add(-time.Hour), t0); err != nil {
		t.Fatal(err)
	}
	if err := p.Put(me.id.pub, desk, [][]byte{kdb1(12), kdb1(13), kdb1(14)}, nil, t0, t0); err != nil {
		t.Fatal(err)
	}
	first, _, err := p.Take(me.id.pub, desk, t0)
	if err != nil {
		t.Fatal(err)
	}
	kept, ok := p.Kept(me.id.pub, desk.ID)
	if !ok {
		t.Fatal("pool not kept")
	}
	q := NewPool()
	if err := q.Restore(kept); err != nil {
		t.Fatal(err)
	}
	again, _ := q.Kept(me.id.pub, desk.ID)
	if len(again.Bundles) != len(kept.Bundles) {
		t.Fatalf("bundles after restore: %d of %d", len(again.Bundles), len(kept.Bundles))
	}
	for i := range again.Bundles {
		a, b := again.Bundles[i], kept.Bundles[i]
		if a.Kyber != b.Kyber || a.Last != b.Last || !a.At.Equal(b.At) || !bytes.Equal(a.KDB1, b.KDB1) {
			t.Fatalf("bundle %d differs", i)
		}
	}
	for range 4 {
		a, la, ea := p.Take(me.id.pub, desk, t0)
		b, lb, eb := q.Take(me.id.pub, desk, t0)
		if !bytes.Equal(a, b) || la != lb || (ea == nil) != (eb == nil) {
			t.Fatal("the restored pool hands out something else")
		}
	}
	if err := q.Put(me.id.pub, desk, [][]byte{first}, nil, t0, t0); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("a bundle handed out before the restart taken again: %v", err)
	}
	if q.Need(me.id.pub, desk, t0) != p.Need(me.id.pub, desk, t0) {
		t.Fatal("need differs")
	}
	// what does not hold is refused whole
	for name, f := range map[string]func(*PoolKept){
		"another device's bundle": func(k *PoolKept) { k.Bundles[0].KDB1 = poolKDB1(t, k.Bundles[0].Kyber, 7, me.linkReg(t)) },
		"a kyber id not its own":  func(k *PoolKept) { k.Bundles[0].Kyber++ },
		"one kyber id twice":      func(k *PoolKept) { k.Bundles[1].Kyber = k.Bundles[0].Kyber },
		"two last resorts":        func(k *PoolKept) { k.Bundles[0].Last = true },
		"junk":                    func(k *PoolKept) { k.Bundles[0].KDB1 = []byte("KDB1") },
		"the phone":               func(k *PoolKept) { k.Entry = me.list.Devices[0] },
	} {
		k, _ := p.Kept(me.id.pub, desk.ID)
		k.Bundles = append([]PoolBundle{{Kyber: 50, Spk: 7, KDB1: kdb1(50), At: t0}}, k.Bundles...)
		f(&k)
		r := NewPool()
		if err := r.Restore(k); err == nil {
			t.Errorf("%s restored", name)
		}
		if len(r.Slots(me.id.pub)) != 0 {
			t.Errorf("%s: something kept", name)
		}
	}
}

func mustKey(t *testing.T) Key {
	k, _ := newKey(t)
	return k
}

// a peek answers as a send would and moves nothing: the silent mark, the
// weekly probe and a row on another key stay for the send after it
func TestAPeekSpendsNoProbe(t *testing.T) {
	k := newFanoutKit(t, 0, 1)
	bob := k.bob.id.pub
	e := k.bob.list.Devices[1]
	v := k.bob.list.Version
	t0 := time.Unix(1_760_000_000, 0)
	q := NewQuiet()
	q.Sent(bob, e.ID, e.Key, t0)
	if st := q.Peek(bob, e.ID, e.Key, v, t0.Add(QuietSilent)); st != Silent {
		t.Fatalf("day 30 peeked: %v", st)
	}
	if st := q.State(bob, e.ID, e.Key, v, t0.Add(QuietSilent)); st != Silent {
		t.Fatalf("day 30: %v", st)
	}
	at := t0.Add(QuietSilent + QuietProbe)
	for range 3 {
		if st := q.Peek(bob, e.ID, e.Key, v, at); st != Rebuild {
			t.Fatalf("the probe peeked: %v", st)
		}
	}
	if st := q.State(bob, e.ID, e.Key, v, at); st != Rebuild {
		t.Fatalf("the probe after three peeks: %v", st)
	}
	if st := q.Peek(bob, e.ID, e.Key, v, at); st != Silent {
		t.Fatalf("after the probe: %v", st)
	}
	other := e.Key
	other[5] ^= 1
	if st := q.Peek(bob, e.ID, other, v, at); st != Open {
		t.Fatalf("another key peeked: %v", st)
	}
	if len(q.Slots(bob)) != 1 {
		t.Fatal("a peek on another key dropped the row")
	}
}
