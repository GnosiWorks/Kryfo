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

	fresh := NewKnown(a.id.pub)
	if _, _, err := fresh.Accept(old, FromSession(desk.Key), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an old list from the removed desktop: %v", err)
	}
	if fresh.Current() != nil {
		t.Fatal("a list was kept")
	}
	// a third party's session carries no list for a
	b := newAccount(t, s)
	if _, _, err := fresh.Accept(a.wire, FromSession(b.id.pub), s); !errors.Is(err, ErrSource) {
		t.Fatalf("a's list in b's session: %v", err)
	}
	// a contact holding the new list refuses the old one, from anywhere
	k := NewKnown(a.id.pub)
	if _, _, err := k.Accept(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	if _, _, err := k.Accept(old, FromSession(a.id.pub), s); !errors.Is(err, ErrRollback) {
		t.Fatalf("the old list after the removal: %v", err)
	}
	if k.Vouches(desk.Key) {
		t.Fatal("the removed desktop still vouches")
	}
}

// versions are a counter with a window, never the clock: a phone restored
// after its clock ran ahead is taken, and a version thrown far ahead is not
func TestNoClockLocksOutLaterLists(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	backup := clone(a.list)
	k := NewKnown(a.id.pub)
	for range 50 {
		a.link(t)
		a.unlink(t, a.list.Devices[len(a.list.Devices)-1].ID)
	}
	if _, _, err := k.Accept(a.wire, FromSession(a.id.pub), s); err != nil {
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
		if _, out, err := k.Accept(w, FromSession(a.id.pub), s); err != nil || out != Changed {
			t.Fatalf("restore %d: %v %v", i, out, err)
		}
		cur = r
	}
	// a version past the window, as a root thief would sign it
	far := clone(k.Current())
	far.Version += VersionWindow + 1
	w, err := far.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := k.Accept(w, FromSession(a.id.pub), s); !errors.Is(err, ErrJump) {
		t.Fatalf("a jump past the window: %v", err)
	}
	edge := clone(k.Current())
	edge.Version += VersionWindow
	w, err = edge.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := k.Accept(w, FromSession(a.id.pub), s); err != nil {
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
	k := NewKnown(a.id.pub)
	if _, _, err := k.Accept(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	resigned, err := a.list.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(resigned, a.wire) {
		t.Fatal("the stand-in signs like ed25519, not xeddsa")
	}
	if _, out, err := k.Accept(resigned, FromSession(a.id.pub), s); err != nil || out != Same {
		t.Fatalf("one body, a second signature: %v %v", out, err)
	}
	other := clone(a.list)
	other.Devices[1].Reg++
	w, err := other.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	held := k.Current()
	if _, _, err := k.Accept(w, FromSession(a.id.pub), s); !errors.Is(err, ErrEquivocation) {
		t.Fatalf("two bodies at one version: %v", err)
	}
	if k.Current() != held {
		t.Fatal("the alarm moved the list held")
	}
}
