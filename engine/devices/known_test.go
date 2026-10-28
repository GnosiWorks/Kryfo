// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/rand"
	"errors"
	"slices"
	"sync"
	"testing"
)

func TestTheFirstListFromTheSession(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	a.link(t)
	k := newKnown(a.id.pub)
	l, out, err := k.take(a.wire, FromSession(a.id.pub), s)
	if err != nil || out != First || l.Version != a.list.Version {
		t.Fatalf("first list: %v %v", out, err)
	}
	again, out, err := k.take(a.wire, FromSession(a.id.pub), s)
	if err != nil || out != Same || again != l {
		t.Fatalf("the same list again: %v %v", out, err)
	}
	e := a.link(t)
	l2, out, err := k.take(a.wire, FromSession(a.id.pub), s)
	if err != nil || out != Changed || l2.Version != a.list.Version {
		t.Fatalf("a newer list: %v %v", out, err)
	}
	// a listed device may carry the next list
	a.unlink(t, e.ID)
	if _, out, err := k.take(a.wire, FromSession(l2.Devices[1].Key), s); err != nil || out != Changed {
		t.Fatalf("from a listed device: %v %v", out, err)
	}
}

func TestPins(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	e := a.link(t)
	k := newKnown(a.id.pub)
	if p, ok := k.pin(PhoneID); !ok || p != a.id.pub {
		t.Fatal("the phone pins the identity before any list")
	}
	if _, ok := k.pin(e.ID); ok {
		t.Fatal("a device pinned before its list")
	}
	if _, _, err := k.take(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	if p, ok := k.pin(e.ID); !ok || p != e.Key {
		t.Fatal("the listed key is not the pin")
	}
	if _, ok := k.pin(e.ID + 1); ok {
		t.Fatal("an unlisted id pinned")
	}
	other, _ := newKey(t)
	if k.vouches(other) || !k.vouches(e.Key) || !k.vouches(a.id.pub) {
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

	k := newKnown(a.id.pub)
	if _, out, err := k.take(pool, FromInvite(), s); err != nil || out != First {
		t.Fatalf("pool invite list: %v %v", out, err)
	}
	// the pool desktop answers, so its session vouches
	if !k.vouches(dk) {
		t.Fatal("the answering desktop does not vouch")
	}
	// an answering list inside a session is refused
	if _, _, err := k.take(pool, FromSession(dk), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an answering list in a session: %v", err)
	}
	st, err := a.list.Settled(rand.Reader)
	a.set(t, st, err)
	if _, out, err := k.take(a.wire, FromSession(dk), s); err != nil || out != Changed {
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
	if _, _, err := k.take(w, FromInvite(), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an invite list after the session's: %v", err)
	}
	// an invite list must name the answering device
	b := newAccount(t, s)
	kb := newKnown(b.id.pub)
	if _, _, err := kb.take(b.wire, FromInvite(), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an invite list without an answering device: %v", err)
	}
}

func TestAnErrorKeepsTheListHeld(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	k := newKnown(a.id.pub)
	if _, _, err := k.take(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	held := k.cur
	old := a.wire
	a.link(t)
	newer := a.wire
	if _, _, err := k.take(newer, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	held = k.cur
	for name, b := range map[string][]byte{
		"rollback": old,
		"junk":     []byte("KDL2 junk"),
		"flipped":  append(newer[:len(newer)-1:len(newer)-1], newer[len(newer)-1]^1),
	} {
		if _, _, err := k.take(b, FromSession(a.id.pub), s); err == nil {
			t.Fatalf("%s taken", name)
		}
		if k.cur != held {
			t.Fatalf("%s moved the list held", name)
		}
	}
	if _, _, err := k.take(old, FromSession(a.id.pub), s); !errors.Is(err, ErrRollback) {
		t.Fatalf("rollback: %v", err)
	}
}

func TestAnotherIdentitysListIsRefused(t *testing.T) {
	s := newShim()
	a, b := newAccount(t, s), newAccount(t, s)
	k := newKnown(a.id.pub)
	if _, _, err := k.take(b.wire, FromSession(a.id.pub), s); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("b's list for a: %v", err)
	}
	if _, _, err := k.take(b.wire, FromSession(b.id.pub), s); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("b's list from b for a: %v", err)
	}
}

func TestBook(t *testing.T) {
	s := newShim()
	a, b := newAccount(t, s), newAccount(t, s)
	desk := a.link(t)
	book := NewBook()
	for _, x := range []*account{a, b} {
		if _, err := book.Add(x.id.pub); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, _, err := book.Accept(a.id.pub, a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	if _, err := book.Proven(a.id.pub, desk.Key); err != nil {
		t.Fatal(err)
	}
	// b lists a's proven desktop as its own device
	claimed, err := b.list.Add(Entry{ID: desk.ID, Key: desk.Key, Reg: desk.Reg}, rand.Reader)
	b.set(t, claimed, err)
	_, _, claimants, err := book.Accept(b.id.pub, b.wire, FromSession(b.id.pub), s)
	if err != nil || !slices.Contains(claimants, b.id.pub) {
		t.Fatalf("a's proven device on b's list: %v %v", claimants, err)
	}
	if book.Vouches(b.id.pub, desk.Key) || !book.Vouches(a.id.pub, desk.Key) {
		t.Fatal("a's desktop routes as b's")
	}
	if _, ok := book.Pin(b.id.pub, desk.ID); ok {
		t.Fatal("b's copy is pinned")
	}
	// or a's identity key as a device
	c := newAccount(t, s)
	if _, err := book.Add(c.id.pub); err != nil {
		t.Fatal(err)
	}
	withA, err := c.list.Add(Entry{ID: 9, Key: a.id.pub, Reg: 1}, rand.Reader)
	c.set(t, withA, err)
	_, _, claimants, err = book.Accept(c.id.pub, c.wire, FromSession(c.id.pub), s)
	if err != nil || !slices.Contains(claimants, c.id.pub) || book.Vouches(c.id.pub, a.id.pub) {
		t.Fatalf("a's identity on c's list: %v %v", claimants, err)
	}
	// a contact whose identity is a's proven desktop
	if _, err := book.Add(desk.Key); !errors.Is(err, ErrTaken) {
		t.Fatalf("a's desktop as a contact: %v", err)
	}
	if _, _, _, err := book.Accept(fixedKey(t, 1), a.wire, FromSession(a.id.pub), s); !errors.Is(err, ErrUnknown) {
		t.Fatalf("an unknown contact: %v", err)
	}
	// a proof only for a key the contact lists, and never for one proven
	// elsewhere
	if _, err := book.Proven(b.id.pub, desk.Key); !errors.Is(err, ErrTaken) {
		t.Fatalf("b proving a's proven desktop: %v", err)
	}
	if _, err := book.Proven(c.id.pub, fixedKey(t, 0x55)); !errors.Is(err, ErrNotListed) {
		t.Fatalf("c proving a key c's list does not hold: %v", err)
	}
	// once a is gone its keys are free again
	book.Forget(a.id.pub)
	if _, _, _, err := book.Accept(b.id.pub, b.wire, FromSession(b.id.pub), s); err != nil {
		t.Fatalf("after a is forgotten: %v", err)
	}
	if book.Current(b.id.pub) == nil {
		t.Fatal("b's list not held")
	}
}

// mallory, a contact of bob, puts carol's public identity key on her list.
// bob can still add carol, and the doubt goes on mallory
func TestAClaimDoesNotBlockAnAdd(t *testing.T) {
	s := newShim()
	mallory, carol := newAccount(t, s), newAccount(t, s)
	book := NewBook()
	if _, err := book.Add(mallory.id.pub); err != nil {
		t.Fatal(err)
	}
	n, err := mallory.list.Add(Entry{ID: 9, Key: carol.id.pub, Reg: 5}, rand.Reader)
	mallory.set(t, n, err)
	if _, _, _, err := book.Accept(mallory.id.pub, mallory.wire, FromSession(mallory.id.pub), s); err != nil {
		t.Fatal(err)
	}
	claimants, err := book.Add(carol.id.pub)
	if err != nil {
		t.Fatalf("adding carol: %v", err)
	}
	if len(claimants) != 1 || claimants[0] != mallory.id.pub {
		t.Fatalf("the doubt is on %v", claimants)
	}
	if _, ok := book.Pin(mallory.id.pub, 9); ok || book.Vouches(mallory.id.pub, carol.id.pub) {
		t.Fatal("carol's key still routes as mallory's")
	}
}

// mallory copies alice's new desktop key into her own list and gets it to
// bob first. alice's lists still go through, a later removal included,
// and once the desktop proves itself mallory's entry is the suspect one
func TestACopiedDeviceKeyFreezesNothing(t *testing.T) {
	s := newShim()
	alice, mallory := newAccount(t, s), newAccount(t, s)
	book := NewBook()
	for _, x := range []*account{alice, mallory} {
		if _, err := book.Add(x.id.pub); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, _, err := book.Accept(alice.id.pub, alice.wire, FromSession(alice.id.pub), s); err != nil {
		t.Fatal(err)
	}
	stolen := alice.link(t)
	if _, _, _, err := book.Accept(alice.id.pub, alice.wire, FromSession(alice.id.pub), s); err != nil {
		t.Fatal(err)
	}
	desk := alice.link(t)
	n, err := mallory.list.Add(Entry{ID: 9, Key: desk.Key, Reg: 5}, rand.Reader)
	mallory.set(t, n, err)
	if _, _, _, err := book.Accept(mallory.id.pub, mallory.wire, FromSession(mallory.id.pub), s); err != nil {
		t.Fatal(err)
	}
	if _, out, _, err := book.Accept(alice.id.pub, alice.wire, FromSession(alice.id.pub), s); err != nil || out != Changed {
		t.Fatalf("alice's real list: %v %v", out, err)
	}
	alice.unlink(t, stolen.ID)
	if _, out, _, err := book.Accept(alice.id.pub, alice.wire, FromSession(alice.id.pub), s); err != nil || out != Changed {
		t.Fatalf("alice's removal: %v %v", out, err)
	}
	if book.Vouches(alice.id.pub, stolen.Key) {
		t.Fatal("the removed device still speaks for alice")
	}
	claimants, err := book.Proven(alice.id.pub, desk.Key)
	if err != nil {
		t.Fatal(err)
	}
	if len(claimants) != 1 || claimants[0] != mallory.id.pub {
		t.Fatalf("the doubt is on %v", claimants)
	}
	if !book.Vouches(alice.id.pub, desk.Key) || book.Vouches(mallory.id.pub, desk.Key) {
		t.Fatal("the desktop routes to the wrong contact")
	}
	if _, ok := book.Pin(mallory.id.pub, 9); ok {
		t.Fatal("mallory's copy is still pinned")
	}
	if got := book.Claimants(); len(got) != 1 || got[0] != mallory.id.pub {
		t.Fatalf("claimants %v", got)
	}
	// mallory's next list that keeps the copy is taken, the copy still
	// unrouted and mallory still the one doubted
	st, err := mallory.list.Settled(rand.Reader)
	mallory.set(t, st, err)
	_, _, claimants, err = book.Accept(mallory.id.pub, mallory.wire, FromSession(mallory.id.pub), s)
	if err != nil || len(claimants) != 1 || claimants[0] != mallory.id.pub || book.Vouches(mallory.id.pub, desk.Key) {
		t.Fatalf("mallory keeping the copy: %v %v", claimants, err)
	}
	if _, err := book.Proven(mallory.id.pub, desk.Key); !errors.Is(err, ErrTaken) {
		t.Fatalf("mallory proving the copy: %v", err)
	}
}

// bob adds a contact whose identity is alice's desktop key before the
// desktop ever wrote to him. alice's later lists still go through, her
// removals included; the desktop entry is the doubted one
func TestAClashHoldsBackNoLaterChange(t *testing.T) {
	s := newShim()
	alice := newAccount(t, s)
	desk := alice.link(t)
	book := NewBook()
	if _, err := book.Add(alice.id.pub); err != nil {
		t.Fatal(err)
	}
	if _, _, _, err := book.Accept(alice.id.pub, alice.wire, FromSession(alice.id.pub), s); err != nil {
		t.Fatal(err)
	}
	claimants, err := book.Add(desk.Key)
	if err != nil || !slices.Contains(claimants, alice.id.pub) {
		t.Fatalf("the clash: %v %v", claimants, err)
	}
	stolen := alice.link(t)
	if _, out, _, err := book.Accept(alice.id.pub, alice.wire, FromSession(alice.id.pub), s); err != nil || out != Changed {
		t.Fatalf("alice adding a device: %v %v", out, err)
	}
	if !book.Vouches(alice.id.pub, stolen.Key) {
		t.Fatal("the new device is not routed")
	}
	alice.unlink(t, stolen.ID)
	if _, out, _, err := book.Accept(alice.id.pub, alice.wire, FromSession(alice.id.pub), s); err != nil || out != Changed {
		t.Fatalf("alice's removal: %v %v", out, err)
	}
	if book.Vouches(alice.id.pub, stolen.Key) || book.Vouches(alice.id.pub, desk.Key) {
		t.Fatal("a removed or doubted device still routes")
	}
}

// your own identities and devices are on no contact's list
func TestOwnKeysAreNobodysDevice(t *testing.T) {
	s := newShim()
	me, desk := fixedKey(t, 0x70), fixedKey(t, 0x71)
	c := newAccount(t, s)
	book := NewBook(me)
	if _, err := book.Add(c.id.pub); err != nil {
		t.Fatal(err)
	}
	if _, err := book.Add(me); !errors.Is(err, ErrTaken) {
		t.Fatalf("my own identity as a contact: %v", err)
	}
	book.Own(desk)
	n, err := c.list.Add(Entry{ID: 9, Key: desk, Reg: 5}, rand.Reader)
	c.set(t, n, err)
	_, _, claimants, err := book.Accept(c.id.pub, c.wire, FromSession(c.id.pub), s)
	if err != nil || !slices.Contains(claimants, c.id.pub) || book.Vouches(c.id.pub, desk) {
		t.Fatalf("my desktop on a contact's list: %v %v", claimants, err)
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
				if _, _, _, err := book.Accept(a.id.pub, a.wire, FromSession(a.id.pub), s); err != nil {
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
	if _, err := book.TakeBundle(fixedKey(t, 1), nil, FromSession(fixedKey(t, 1))); !errors.Is(err, ErrUnknown) {
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
