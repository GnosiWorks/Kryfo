// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/rand"
	"errors"
	"sync"
	"testing"
)

func TestTheFirstListFromTheSession(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	a.link(t)
	k := NewKnown(a.id.pub)
	l, out, err := k.Accept(a.wire, FromSession(a.id.pub), s)
	if err != nil || out != First || l.Version != a.list.Version {
		t.Fatalf("first list: %v %v", out, err)
	}
	again, out, err := k.Accept(a.wire, FromSession(a.id.pub), s)
	if err != nil || out != Same || again != l {
		t.Fatalf("the same list again: %v %v", out, err)
	}
	e := a.link(t)
	l2, out, err := k.Accept(a.wire, FromSession(a.id.pub), s)
	if err != nil || out != Changed || l2.Version != a.list.Version {
		t.Fatalf("a newer list: %v %v", out, err)
	}
	// a listed device may carry the next list
	a.unlink(t, e.ID)
	if _, out, err := k.Accept(a.wire, FromSession(l2.Devices[1].Key), s); err != nil || out != Changed {
		t.Fatalf("from a listed device: %v %v", out, err)
	}
}

func TestPins(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	e := a.link(t)
	k := NewKnown(a.id.pub)
	if p, ok := k.Pin(PhoneID); !ok || p != a.id.pub {
		t.Fatal("the phone pins the identity before any list")
	}
	if _, ok := k.Pin(e.ID); ok {
		t.Fatal("a device pinned before its list")
	}
	if _, _, err := k.Accept(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	if p, ok := k.Pin(e.ID); !ok || p != e.Key {
		t.Fatal("the listed key is not the pin")
	}
	if _, ok := k.Pin(e.ID + 1); ok {
		t.Fatal("an unlisted id pinned")
	}
	other, _ := newKey(t)
	if k.Vouches(other) || !k.Vouches(e.Key) || !k.Vouches(a.id.pub) {
		t.Fatal("vouches")
	}
}

func TestAnInviteListCountsUntilTheSessionSendsOne(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	dk, _ := newKey(t)
	e, err := EntryFor(a.list, DeviceKeys{Identity: a.id.pub, Key: dk, Reg: 8}, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	e.Answers = true
	n, err := a.list.Add(e, rand.Reader)
	a.set(t, n, err)
	pool := a.wire

	k := NewKnown(a.id.pub)
	if _, out, err := k.Accept(pool, FromInvite(), s); err != nil || out != First {
		t.Fatalf("pool invite list: %v %v", out, err)
	}
	// the pool desktop answers, so its session vouches
	if !k.Vouches(dk) {
		t.Fatal("the answering desktop does not vouch")
	}
	// an answering list inside a session is refused
	if _, _, err := k.Accept(pool, FromSession(dk), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an answering list in a session: %v", err)
	}
	st, err := a.list.Settled(rand.Reader)
	a.set(t, st, err)
	if _, out, err := k.Accept(a.wire, FromSession(dk), s); err != nil || out != Changed {
		t.Fatalf("the session's own list: %v %v", out, err)
	}
	// now an invite cannot bring a list back in
	e2 := a.link(t)
	ans := clone(a.list)
	for i := range ans.Devices {
		if ans.Devices[i].ID == e2.ID {
			ans.Devices[i].Answers = true
		}
	}
	ans.Version++
	w, err := ans.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := k.Accept(w, FromInvite(), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an invite list after the session's: %v", err)
	}
	// an invite list must name the answering device
	b := newAccount(t, s)
	kb := NewKnown(b.id.pub)
	if _, _, err := kb.Accept(b.wire, FromInvite(), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an invite list without an answering device: %v", err)
	}
}

func TestAnErrorKeepsTheListHeld(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	k := NewKnown(a.id.pub)
	if _, _, err := k.Accept(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	held := k.Current()
	old := a.wire
	a.link(t)
	newer := a.wire
	if _, _, err := k.Accept(newer, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	held = k.Current()
	for name, b := range map[string][]byte{
		"rollback": old,
		"junk":     []byte("KDL2 junk"),
		"flipped":  append(newer[:len(newer)-1:len(newer)-1], newer[len(newer)-1]^1),
	} {
		if _, _, err := k.Accept(b, FromSession(a.id.pub), s); err == nil {
			t.Fatalf("%s taken", name)
		}
		if k.Current() != held {
			t.Fatalf("%s moved the list held", name)
		}
	}
	if _, _, err := k.Accept(old, FromSession(a.id.pub), s); !errors.Is(err, ErrRollback) {
		t.Fatalf("rollback: %v", err)
	}
}

func TestAnotherIdentitysListIsRefused(t *testing.T) {
	s := newShim()
	a, b := newAccount(t, s), newAccount(t, s)
	k := NewKnown(a.id.pub)
	if _, _, err := k.Accept(b.wire, FromSession(a.id.pub), s); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("b's list for a: %v", err)
	}
	if _, _, err := k.Accept(b.wire, FromSession(b.id.pub), s); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("b's list from b for a: %v", err)
	}
}

func TestBook(t *testing.T) {
	s := newShim()
	a, b := newAccount(t, s), newAccount(t, s)
	desk := a.link(t)
	book := NewBook()
	if _, err := book.Add(a.id.pub); err != nil {
		t.Fatal(err)
	}
	if _, err := book.Add(b.id.pub); err != nil {
		t.Fatal(err)
	}
	if _, _, err := book.Accept(a.id.pub, a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	// b lists a's desktop as its own device: public keys are all it takes
	claimed, err := b.list.Add(Entry{ID: desk.ID, Key: desk.Key, Reg: desk.Reg}, rand.Reader)
	b.set(t, claimed, err)
	if _, _, err := book.Accept(b.id.pub, b.wire, FromSession(b.id.pub), s); !errors.Is(err, ErrTaken) {
		t.Fatalf("a's device on b's list: %v", err)
	}
	// or a's identity key as a device
	c := newAccount(t, s)
	if _, err := book.Add(c.id.pub); err != nil {
		t.Fatal(err)
	}
	withA, err := c.list.Add(Entry{ID: 9, Key: a.id.pub, Reg: 1}, rand.Reader)
	c.set(t, withA, err)
	if _, _, err := book.Accept(c.id.pub, c.wire, FromSession(c.id.pub), s); !errors.Is(err, ErrTaken) {
		t.Fatalf("a's identity on c's list: %v", err)
	}
	// or the identity of a contact that has sent no list yet
	d := newAccount(t, s)
	if _, err := book.Add(d.id.pub); err != nil {
		t.Fatal(err)
	}
	e := newAccount(t, s)
	if _, err := book.Add(e.id.pub); err != nil {
		t.Fatal(err)
	}
	withD, err := e.list.Add(Entry{ID: 9, Key: d.id.pub, Reg: 1}, rand.Reader)
	e.set(t, withD, err)
	if _, _, err := book.Accept(e.id.pub, e.wire, FromSession(e.id.pub), s); !errors.Is(err, ErrTaken) {
		t.Fatalf("d's identity on e's list: %v", err)
	}
	// a contact whose identity is a's desktop
	if _, err := book.Add(desk.Key); !errors.Is(err, ErrTaken) {
		t.Fatalf("a's desktop as a contact: %v", err)
	}
	if _, _, err := book.Accept(fixedKey(t, 1), a.wire, FromSession(a.id.pub), s); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("an unknown contact: %v", err)
	}
	// once a is gone its keys are free again
	book.Forget(a.id.pub)
	if _, _, err := book.Accept(b.id.pub, b.wire, FromSession(b.id.pub), s); err != nil {
		t.Fatalf("after a is forgotten: %v", err)
	}
	if k, ok := book.Get(b.id.pub); !ok || k.Current() == nil {
		t.Fatal("b's list not held")
	}
}

// lists for several contacts arriving at once, as the engine's readers
// deliver them
func TestBookTakesListsAtOnce(t *testing.T) {
	s := newShim()
	book := NewBook()
	var accounts []*account
	for range 8 {
		a := newAccount(t, s)
		a.link(t)
		if _, err := book.Add(a.id.pub); err != nil {
			t.Fatal(err)
		}
		accounts = append(accounts, a)
	}
	var wg sync.WaitGroup
	for _, a := range accounts {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range 20 {
				if _, _, err := book.Accept(a.id.pub, a.wire, FromSession(a.id.pub), s); err != nil {
					t.Error(err)
					return
				}
				phone := a.list.Devices[0]
				p, err := EncodeBundle(testBlockFor(phone))
				if err != nil {
					t.Error(err)
					return
				}
				if _, err := book.TakeBundle(a.id.pub, p, FromSession(a.id.pub)); err != nil {
					t.Error(err)
					return
				}
				if pin, ok := book.Pin(a.id.pub, PhoneID); !ok || pin != a.id.pub {
					t.Error("pin")
					return
				}
			}
		}()
	}
	wg.Wait()
	if _, ok := book.Pin(fixedKey(t, 1), PhoneID); ok {
		t.Fatal("a pin for nobody")
	}
	if _, err := book.TakeBundle(fixedKey(t, 1), nil, FromSession(fixedKey(t, 1))); !errors.Is(err, ErrWrongIdentity) {
		t.Fatal(err)
	}
}

func testBlockFor(e Entry) *Block {
	return &Block{
		Reg: e.Reg, Device: e.ID, SpkID: 1, Spk: e.Key,
		SpkSig:   make([]byte, SigSize),
		KyberID:  2,
		Kyber:    append([]byte{0x08}, make([]byte, KyberSize-1)...),
		KyberSig: make([]byte, SigSize),
	}
}
