// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"crypto/rand"
	"errors"
	"testing"
	"time"
)

// a removed desktop keeps an old list naming itself. it cannot be anyone's
// first list: it does not come from the invite, and a session on the
// desktop's key vouches for nothing before a list names it
func TestARemovedDeviceCannotPlantAnOldList(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	desk := a.link(t)
	old := a.wire
	a.unlink(t, desk.ID)

	fresh := newKnown(a.id.pub)
	if _, _, err := fresh.take(old, FromSession(desk.Key), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an old list from the removed desktop: %v", err)
	}
	if fresh.cur != nil {
		t.Fatal("a list was kept")
	}
	// a third party's session carries no list for a
	b := newAccount(t, s)
	if _, _, err := fresh.take(a.wire, FromSession(b.id.pub), s); !errors.Is(err, ErrSource) {
		t.Fatalf("a's list in b's session: %v", err)
	}
	// a contact holding the new list refuses the old one, from anywhere
	k := newKnown(a.id.pub)
	if _, _, err := k.take(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	if _, _, err := k.take(old, FromSession(a.id.pub), s); !errors.Is(err, ErrRollback) {
		t.Fatalf("the old list after the removal: %v", err)
	}
	if k.vouches(desk.Key) {
		t.Fatal("the removed desktop still vouches")
	}
}

// versions are a counter with a window, never the clock: a phone restored
// after its clock ran ahead is taken, and a version thrown far ahead is not
func TestNoClockLocksOutLaterLists(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	backup := clone(a.list)
	k := newKnown(a.id.pub)
	for range 50 {
		a.link(t)
		a.unlink(t, a.list.Devices[len(a.list.Devices)-1].ID)
	}
	if _, _, err := k.take(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	// three restores from that old backup in a row
	cur := backup
	for i := range 3 {
		r, err := cur.Restored(rand.Reader)
		if err != nil {
			t.Fatal(err)
		}
		w, err := r.Sign(a.id)
		if err != nil {
			t.Fatal(err)
		}
		if _, out, err := k.take(w, FromSession(a.id.pub), s); err != nil || out != Changed {
			t.Fatalf("restore %d: %v %v", i, out, err)
		}
		cur = r
	}
	// a version past the window, as a root thief would sign it
	far := clone(k.cur)
	far.Version += VersionWindow + 1
	w, err := far.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := k.take(w, FromSession(a.id.pub), s); !errors.Is(err, ErrJump) {
		t.Fatalf("a jump past the window: %v", err)
	}
	edge := clone(k.cur)
	edge.Version += VersionWindow
	w, err = edge.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := k.take(w, FromSession(a.id.pub), s); err != nil {
		t.Fatalf("a jump at the window: %v", err)
	}
}

// the list does not show when a device was linked: a change made a day
// later is byte for byte the change made now
func TestTheTimeOfAChangeDoesNotShow(t *testing.T) {
	id := fixedKey(t, 0x11)
	k := fixedKey(t, 0x22)
	var bodies [][]byte
	for range []time.Time{time.Now(), time.Now().Add(26 * time.Hour)} {
		l, err := Genesis(id, 9, seeded(4))
		if err != nil {
			t.Fatal(err)
		}
		n, err := l.Add(Entry{ID: 3, Key: k, Reg: 4}, seeded(5))
		if err != nil {
			t.Fatal(err)
		}
		bodies = append(bodies, n.Body())
	}
	if !bytes.Equal(bodies[0], bodies[1]) {
		t.Fatal("the time shows")
	}
}

// one device's key never serves two identities, so contacts of a decoy
// and of the main identity, or of two pairwise identities, cannot match
// the device between them
func TestTwoIdentitiesOnOneDeviceShareNoKey(t *testing.T) {
	s := newShim()
	i1, i2 := s.identity(t), s.identity(t)
	ring := NewKeyring(keySource{t}, rand.Reader)
	d1, err := ring.For(i1.pub)
	if err != nil {
		t.Fatal(err)
	}
	d2, err := ring.For(i2.pub)
	if err != nil {
		t.Fatal(err)
	}
	if d1.Key == d2.Key || d1.Key == i1.pub || d2.Key == i2.pub {
		t.Fatal("a key shared")
	}
	if again, _ := ring.For(i1.pub); again != d1 {
		t.Fatal("keys for one identity changed")
	}
	// the ids the phones give it are drawn per list, so they carry nothing
	// from one list to the other
	a1, a2 := &account{id: i1}, &account{id: i2}
	for _, a := range []*account{a1, a2} {
		l, err := Genesis(a.id.pub, 1, rand.Reader)
		if err != nil {
			t.Fatal(err)
		}
		a.list = l
	}
	e1, err := EntryFor(a1.list, d1, seeded(1))
	if err != nil {
		t.Fatal(err)
	}
	e2, err := EntryFor(a2.list, d2, seeded(2))
	if err != nil {
		t.Fatal(err)
	}
	if e1.Key == e2.Key {
		t.Fatal("one key on two lists")
	}
	if _, err := EntryFor(a1.list, d2, rand.Reader); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("i2's keys on i1's list: %v", err)
	}
	// a key source that hands the same key out twice is caught
	same := fixedKey(t, 0x33)
	dup := NewKeyring(fixedSource{same}, rand.Reader)
	if _, err := dup.For(i1.pub); err != nil {
		t.Fatal(err)
	}
	if _, err := dup.For(i2.pub); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("one key for two identities: %v", err)
	}
	// and so is storage that holds it twice
	if err := ring.Load(DeviceKeys{Identity: fixedKey(t, 0x44), Key: d1.Key, Reg: 5}); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("a stored key for a second identity: %v", err)
	}
	if err := ring.Load(DeviceKeys{Identity: d1.Key, Key: fixedKey(t, 0x45), Reg: 5}); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("a device key as an identity: %v", err)
	}
	ring.Forget(i1.pub)
	if err := ring.Load(DeviceKeys{Identity: fixedKey(t, 0x44), Key: d1.Key, Reg: 5}); err != nil {
		t.Fatalf("after forgetting: %v", err)
	}
}

// an id a device just removed still uses (its last word goes) is never
// drawn for a new one, and with every other id busy the one left comes
func TestFreeIDPassesOverBusyIds(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	busy := func(id uint8) bool { return id%2 == 0 }
	for i := range 2000 {
		id, err := FreeIDBut(a.list, busy, seeded(uint64(i)))
		if err != nil {
			t.Fatal(err)
		}
		if busy(id) {
			t.Fatalf("busy id %d drawn", id)
		}
	}
	id, err := FreeIDBut(a.list, func(id uint8) bool { return id != 77 }, rand.Reader)
	if err != nil || id != 77 {
		t.Fatalf("the one free id: %d %v", id, err)
	}
	dk := DeviceKeys{Identity: a.id.pub, Key: s.identity(t).pub, Reg: 9}
	e, err := EntryForBut(a.list, dk, func(id uint8) bool { return id != 42 }, rand.Reader)
	if err != nil || e.ID != 42 {
		t.Fatalf("entry on the one free id: %d %v", e.ID, err)
	}
}

type fixedSource struct{ k Key }

func (f fixedSource) NewKey() (Key, error) { return f.k, nil }

func TestIdsAndRegs(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	seen := map[uint8]bool{}
	for i := range 4000 {
		id, err := FreeID(a.list, seeded(uint64(i)))
		if err != nil {
			t.Fatal(err)
		}
		if id <= PhoneID || id > MaxID {
			t.Fatalf("id %d", id)
		}
		seen[id] = true
	}
	if len(seen) != MaxID-1 {
		t.Fatalf("%d of %d ids drawn", len(seen), MaxID-1)
	}
	for range 4 {
		a.link(t)
	}
	for i := range 500 {
		id, _ := FreeID(a.list, seeded(uint64(i)))
		if _, taken := a.list.Find(id); taken {
			t.Fatalf("id %d already listed", id)
		}
	}
	if _, err := FreeID(a.list, constReader(PhoneID)); err == nil {
		t.Fatal("a source stuck on the phone's id gave an id")
	}
	a.link(t)
	if _, err := FreeID(a.list, rand.Reader); !errors.Is(err, ErrTooMany) {
		t.Fatalf("an id on a full list: %v", err)
	}
	for i := range 2000 {
		r, err := NewReg(seeded(uint64(i)))
		if err != nil || r < 1 || r > MaxReg {
			t.Fatalf("reg %d %v", r, err)
		}
	}
}

// equal bodies under two xeddsa signatures are one list. two bodies at one
// version are the alarm
func TestEquivocationComparesBodies(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	a.link(t)
	k := newKnown(a.id.pub)
	if _, _, err := k.take(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	resigned, err := a.list.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(resigned, a.wire) {
		t.Fatal("the stand-in signs like ed25519, not xeddsa")
	}
	if _, out, err := k.take(resigned, FromSession(a.id.pub), s); err != nil || out != Same {
		t.Fatalf("one body, a second signature: %v %v", out, err)
	}
	other := clone(a.list)
	other.Devices[1].Reg++
	w, err := other.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	held := k.cur
	if _, _, err := k.take(w, FromSession(a.id.pub), s); !errors.Is(err, ErrEquivocation) {
		t.Fatalf("two bodies at one version: %v", err)
	}
	if k.cur != held {
		t.Fatal("the alarm moved the list held")
	}
}

// two phones restored from one backup: the second lands below the first
// half the time. the contact sends back the list it holds, the second
// phone signs above it and is shown the device the other copy linked
func TestASecondRestoreClimbsAboveTheFirst(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	backup := clone(a.list)
	k := newKnown(a.id.pub)
	r1, err := backup.Restored(constReader(0xff))
	if err != nil {
		t.Fatal(err)
	}
	// the first copy links a desktop
	dk, _ := newKey(t)
	r1d, err := r1.Add(Entry{ID: 30, Key: dk, Reg: 7}, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	w1, _ := r1d.Sign(a.id)
	if _, _, err := k.take(w1, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	r2, _ := backup.Restored(constReader(0x01))
	w2, _ := r2.Sign(a.id)
	_, _, err = k.take(w2, FromSession(a.id.pub), s)
	var rb *RollbackError
	if !errors.As(err, &rb) || !errors.Is(err, ErrRollback) {
		t.Fatalf("the second restore: %v", err)
	}
	// the second phone checks what came back under its own key
	up, unknown, err := r2.Above(rb.Held, s, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	if len(unknown) != 1 || unknown[0].Key != dk {
		t.Fatalf("unknown devices %v", unknown)
	}
	if !SameBody(&List{Identity: up.Identity, Version: up.Version, Devices: r2.Devices}, up) {
		t.Fatal("above changed the devices")
	}
	wu, _ := up.Sign(a.id)
	if _, out, err := k.take(wu, FromSession(a.id.pub), s); err != nil || out != Changed {
		t.Fatalf("the list above: %v %v", out, err)
	}
	if k.vouches(dk) {
		t.Fatal("the other copy's desktop is still on the list")
	}
	// another identity's list is not a base
	b := newAccount(t, s)
	if _, _, err := r2.Above(b.wire, s, rand.Reader); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("another identity's list: %v", err)
	}
}

// a contact sends back a list near the top: signed by the identity, it is
// still refused past the window, and an unsigned one fails the signature
func TestAHeldListCannotPushTheVersionToTheTop(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	top := clone(a.list)
	top.Version = MaxVersion - 300
	w, err := top.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := a.list.Above(w, s, rand.Reader); !errors.Is(err, ErrJump) {
		t.Fatalf("a held list near the top: %v", err)
	}
	edge := clone(a.list)
	edge.Version += VersionWindow
	w, _ = edge.Sign(a.id)
	if up, _, err := a.list.Above(w, s, rand.Reader); err != nil || up.Version <= edge.Version {
		t.Fatalf("a held list at the window: %v", err)
	}
	if _, _, err := a.list.Above(forge(edge), s, rand.Reader); !errors.Is(err, ErrSignature) {
		t.Fatalf("an unsigned held list: %v", err)
	}
	if _, _, err := a.list.Above([]byte("KDL2"), s, rand.Reader); !errors.Is(err, ErrMalformed) {
		t.Fatalf("junk: %v", err)
	}
}

// only the identity's own phone is told what is held
func TestTheHeldListGoesOnlyToThePhone(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	desk := a.link(t)
	old := a.wire
	k := newKnown(a.id.pub)
	a.link(t)
	if _, _, err := k.take(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	_, _, err := k.take(old, FromSession(desk.Key), s)
	var rb *RollbackError
	if !errors.Is(err, ErrRollback) || errors.As(err, &rb) {
		t.Fatalf("an old list through the desktop: %v", err)
	}
}

// a second body at the version held is the alarm whoever carries it
func TestEquivocationFromAnyCarrier(t *testing.T) {
	s := newShim()
	a, other := newAccount(t, s), newAccount(t, s)
	k := newKnown(a.id.pub)
	if _, _, err := k.take(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	held := k.cur
	fork := clone(a.list)
	nk, _ := newKey(t)
	fork.Devices = append(fork.Devices, Entry{ID: 50, Key: nk, Reg: 3})
	w, _ := fork.Sign(a.id)
	for name, from := range map[string]From{
		"a third party": FromSession(other.id.pub),
		"an invite":     FromInvite(),
	} {
		if _, _, err := k.take(w, from, s); !errors.Is(err, ErrEquivocation) {
			t.Fatalf("%s: %v", name, err)
		}
	}
	if k.cur != held {
		t.Fatal("the alarm moved the list held")
	}
	// and through the book
	book := NewBook()
	book.Add(a.id.pub)
	_, _, _, _ = book.Accept(a.id.pub, a.wire, FromSession(a.id.pub), s)
	if _, _, _, err := book.Accept(a.id.pub, w, FromSession(other.id.pub), s); !errors.Is(err, ErrEquivocation) {
		t.Fatalf("through the book: %v", err)
	}
}
