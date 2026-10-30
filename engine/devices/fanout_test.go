// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/rand"
	"errors"
	"slices"
	"testing"
	"time"
)

// a device linked onto the account's list with a registration id of its own
func (a *account) linkReg(t testing.TB) Entry {
	t.Helper()
	k, _ := newKey(t)
	reg, err := NewReg(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	e, err := EntryFor(a.list, DeviceKeys{Identity: a.id.pub, Key: k, Reg: reg}, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	n, err := a.list.Add(e, rand.Reader)
	a.set(t, n, err)
	a.devs[e.ID] = k
	return e
}

// a phone (me) with own devices, and a contact (bob) with his, as my book
// and my own lists hold them
type fanoutKit struct {
	s    *shim
	me   *account
	bob  *account
	book *Book
	own  *Own
	f    *Fanout
}

func newFanoutKit(t *testing.T, mine, his int) *fanoutKit {
	t.Helper()
	s := newShim()
	k := &fanoutKit{s: s, me: newAccount(t, s), bob: newAccount(t, s)}
	for range mine {
		k.me.linkReg(t)
	}
	for range his {
		k.bob.linkReg(t)
	}
	k.book = NewBook(k.me.id.pub)
	k.book.Own(k.ownKeys()...)
	if _, err := k.book.Add(k.bob.id.pub); err != nil {
		t.Fatal(err)
	}
	k.takeBob(t)
	k.own = NewOwn()
	if _, err := k.own.Set(k.me.id.pub, k.me.wire, k.me.id.pub, s); err != nil {
		t.Fatal(err)
	}
	k.f = &Fanout{Book: k.book, Own: k.own, Quiet: NewQuiet(), Rand: rand.Reader}
	return k
}

func (k *fanoutKit) ownKeys() []Key {
	var out []Key
	for _, d := range k.me.devs {
		out = append(out, d)
	}
	return out
}

func (k *fanoutKit) takeBob(t *testing.T) {
	t.Helper()
	if _, _, _, err := k.book.Accept(k.bob.id.pub, k.bob.wire, FromSession(k.bob.id.pub), k.s); err != nil {
		t.Fatal(err)
	}
}

func (k *fanoutKit) to(t *testing.T, p Peer, now time.Time) []Slot {
	t.Helper()
	out, err := k.f.To(k.me.id.pub, k.bob.id.pub, p, now)
	if err != nil {
		t.Fatal(err)
	}
	return out
}

var withDevices = Peer{Devices: true}

func split(slots []Slot) (his, mine []Slot) {
	for _, s := range slots {
		if s.Own {
			mine = append(mine, s)
		} else {
			his = append(his, s)
		}
	}
	return
}

func ids(slots []Slot) []uint8 {
	var out []uint8
	for _, s := range slots {
		out = append(out, s.Device)
	}
	slices.Sort(out)
	return out
}

func TestASixDeviceAccountIsReachable(t *testing.T) {
	k := newFanoutKit(t, 2, MaxDevices-1)
	now := time.Unix(1_760_000_000, 0)
	his, mine := split(k.to(t, withDevices, now))
	if len(his) != MaxDevices || len(mine) != 2 {
		t.Fatalf("%d copies to him and %d to me, want 6 and 2", len(his), len(mine))
	}
	for _, s := range his {
		e, ok := k.bob.list.Find(s.Device)
		if !ok || s.Key != e.Key || s.Reg != e.Reg || s.Identity != k.bob.id.pub || s.Rebuild {
			t.Fatalf("a copy to %d not on its listed key and reg", s.Device)
		}
	}
	for _, s := range mine {
		e, ok := k.me.list.Find(s.Device)
		if !ok || e.Phone || s.Key != e.Key || s.Reg != e.Reg || s.Identity != k.me.id.pub {
			t.Fatalf("an own copy to %d is wrong", s.Device)
		}
	}
	// the order says nothing: the phone's copy is not always first
	firsts := map[uint8]bool{}
	for range 200 {
		firsts[k.to(t, withDevices, now)[0].Device] = true
	}
	if len(firsts) < 4 {
		t.Fatalf("copies keep their order: %v", firsts)
	}
}

func TestANilRandShufflesWithCryptoRand(t *testing.T) {
	k := newFanoutKit(t, 1, 3)
	k.f.Rand = nil
	if his, mine := split(k.to(t, withDevices, time.Now())); len(his) != 4 || len(mine) != 1 {
		t.Fatalf("%d and %d copies", len(his), len(mine))
	}
}

func TestAPeerWithoutDevicesGetsThePhoneAlone(t *testing.T) {
	k := newFanoutKit(t, 1, 3)
	his, mine := split(k.to(t, Peer{}, time.Now()))
	phone, _ := k.bob.list.Find(PhoneID)
	if len(his) != 1 || his[0].Device != PhoneID || his[0].Key != k.bob.id.pub || his[0].Reg != phone.Reg {
		t.Fatalf("a peer without the caps word: %+v", his)
	}
	// my own copies go whatever the contact runs
	if len(mine) != 1 {
		t.Fatalf("own copies: %d", len(mine))
	}
	// no list yet: the phone, its reg unknown
	ana := newAccount(t, k.s)
	if _, err := k.book.Add(ana.id.pub); err != nil {
		t.Fatal(err)
	}
	out, err := k.f.To(k.me.id.pub, ana.id.pub, withDevices, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	his, _ = split(out)
	if len(his) != 1 || his[0].Device != PhoneID || his[0].Key != ana.id.pub || his[0].Reg != 0 {
		t.Fatalf("a contact with no list: %+v", his)
	}
	if _, err := k.f.To(k.me.id.pub, fixedKey(t, 9), withDevices, time.Now()); !errors.Is(err, ErrUnknown) {
		t.Fatalf("a stranger: %v", err)
	}
	// a phone with no linked device has no own list
	lone := &Fanout{Book: k.book, Rand: rand.Reader}
	out, err = lone.To(k.me.id.pub, k.bob.id.pub, withDevices, time.Now())
	if err != nil || len(out) != 4 {
		t.Fatalf("no own list: %d %v", len(out), err)
	}
}

func TestARemovedDeviceGetsNoSlotAndIsRefused(t *testing.T) {
	k := newFanoutKit(t, 0, 3)
	gone := k.bob.list.Devices[2]
	kept := k.bob.list.Devices[1]
	if err := k.book.AdmitOpener(k.bob.id.pub, gone.ID, gone.Key, gone.Reg); err != nil {
		t.Fatalf("a listed device refused: %v", err)
	}
	k.bob.unlink(t, gone.ID)
	k.takeBob(t)
	if slices.Contains(ids(k.to(t, withDevices, time.Now())), gone.ID) {
		t.Fatal("a removed device still gets a copy")
	}
	if err := k.book.Admit(k.bob.id.pub, gone.ID, gone.Key); !errors.Is(err, ErrNotListed) {
		t.Fatalf("a removed device as sender: %v", err)
	}
	if err := k.book.AdmitOpener(k.bob.id.pub, gone.ID, gone.Key, gone.Reg); !errors.Is(err, ErrNotListed) {
		t.Fatalf("a removed device's opener: %v", err)
	}
	held := []Held{{PhoneID, k.bob.id.pub}, {kept.ID, kept.Key}, {gone.ID, gone.Key}}
	if got := k.book.Stale(k.bob.id.pub, held); !slices.Equal(got, []uint8{gone.ID}) {
		t.Fatalf("stale: %v", got)
	}
	// the same id later on another key: the old session is stale, and
	// nothing on the old key counts
	nk, _ := newKey(t)
	n, err := k.bob.list.Add(Entry{ID: gone.ID, Key: nk, Reg: gone.Reg}, rand.Reader)
	k.bob.set(t, n, err)
	k.takeBob(t)
	if got := k.book.Stale(k.bob.id.pub, held); !slices.Equal(got, []uint8{gone.ID}) {
		t.Fatalf("stale after the id came back on a new key: %v", got)
	}
	if err := k.book.Admit(k.bob.id.pub, gone.ID, gone.Key); !errors.Is(err, ErrNotItsKey) {
		t.Fatalf("the old key on a reused id: %v", err)
	}
	// a contact forgotten: every device session goes, the phone's with it
	k.book.Forget(k.bob.id.pub)
	if got := k.book.Stale(k.bob.id.pub, held); !slices.Equal(got, []uint8{kept.ID, gone.ID}) {
		t.Fatalf("stale of a forgotten contact: %v", got)
	}
}

func TestAdmitTakesOnlyTheListedKeyAndReg(t *testing.T) {
	k := newFanoutKit(t, 0, 2)
	d1, d2 := k.bob.list.Devices[1], k.bob.list.Devices[2]
	phone := k.bob.list.Devices[0]
	cases := map[string]struct {
		id     uint8
		remote Key
		reg    uint32
		want   error
	}{
		"the phone":                        {PhoneID, k.bob.id.pub, phone.Reg, nil},
		"the phone on a device key":        {PhoneID, d1.Key, phone.Reg, ErrNotItsKey},
		"the phone under another reg":      {PhoneID, k.bob.id.pub, phone.Reg + 1, ErrNotItsKey},
		"a device":                         {d1.ID, d1.Key, d1.Reg, nil},
		"a device on another device's key": {d1.ID, d2.Key, d1.Reg, ErrNotItsKey},
		"a device on the identity":         {d1.ID, k.bob.id.pub, d1.Reg, ErrNotItsKey},
		"a device under another reg":       {d1.ID, d1.Key, d1.Reg ^ 1, ErrNotItsKey},
		"an id not listed":                 {MaxID, d1.Key, d1.Reg, ErrNotListed},
	}
	for name, c := range cases {
		if err := k.book.AdmitOpener(k.bob.id.pub, c.id, c.remote, c.reg); !errors.Is(err, c.want) && err != c.want {
			t.Errorf("%s: %v, want %v", name, err, c.want)
		}
	}
	if err := k.book.Admit(fixedKey(t, 3), PhoneID, fixedKey(t, 3)); !errors.Is(err, ErrUnknown) {
		t.Fatalf("a stranger: %v", err)
	}
	// the phone of a contact with no list counts on its key alone
	ana := newAccount(t, k.s)
	k.book.Add(ana.id.pub)
	if err := k.book.AdmitOpener(ana.id.pub, PhoneID, ana.id.pub, 999); err != nil {
		t.Fatalf("a phone before its list: %v", err)
	}
	if err := k.book.Admit(ana.id.pub, 2, ana.id.pub); !errors.Is(err, ErrNotListed) {
		t.Fatalf("a device before any list: %v", err)
	}
}

func TestADisputedDeviceIsNeverASlot(t *testing.T) {
	k := newFanoutKit(t, 1, 1)
	// bob's list names one of my own device keys
	var mineKey Key
	for id, d := range k.me.devs {
		if id != PhoneID {
			mineKey = d
		}
	}
	id, err := FreeID(k.bob.list, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	n, err := k.bob.list.Add(Entry{ID: id, Key: mineKey, Reg: 5}, rand.Reader)
	k.bob.set(t, n, err)
	k.takeBob(t)
	his, _ := split(k.to(t, withDevices, time.Now()))
	if slices.Contains(ids(his), id) || len(his) != 2 {
		t.Fatalf("a disputed entry got a copy: %v", ids(his))
	}
	if err := k.book.Admit(k.bob.id.pub, id, mineKey); !errors.Is(err, ErrTaken) {
		t.Fatalf("a disputed device as sender: %v", err)
	}
	if got := k.book.Stale(k.bob.id.pub, []Held{{id, mineKey}}); !slices.Equal(got, []uint8{id}) {
		t.Fatalf("a disputed session is not stale: %v", got)
	}
}

func TestOwnCopiesOnlyThroughTheOwnDoor(t *testing.T) {
	k := newFanoutKit(t, 2, 1)
	var desk Entry
	for _, e := range k.me.list.Devices {
		if !e.Phone {
			desk = e
		}
	}
	if err := k.own.AdmitOpener(k.me.id.pub, desk.ID, desk.Key, desk.Reg); err != nil {
		t.Fatalf("my own device: %v", err)
	}
	his := k.bob.list.Devices[1]
	cases := map[string]struct {
		id     uint8
		remote Key
		want   error
	}{
		"the contact's key on mine":   {desk.ID, his.Key, ErrNotItsKey},
		"the contact's phone on mine": {desk.ID, k.bob.id.pub, ErrNotItsKey},
		"this phone itself":           {PhoneID, k.me.id.pub, ErrSelf},
	}
	for name, c := range cases {
		if err := k.own.Admit(k.me.id.pub, c.id, c.remote); !errors.Is(err, c.want) {
			t.Errorf("%s: %v, want %v", name, err, c.want)
		}
	}
	// the contact's device, at whatever id: not listed, or not that key
	if err := k.own.Admit(k.me.id.pub, his.ID, his.Key); err == nil {
		t.Fatal("the contact's device taken as mine")
	}
	if err := k.own.AdmitOpener(k.me.id.pub, desk.ID, desk.Key, desk.Reg+1); !errors.Is(err, ErrNotItsKey) {
		t.Fatalf("my device under another reg: %v", err)
	}
	if err := k.own.Admit(k.bob.id.pub, his.ID, his.Key); !errors.Is(err, ErrUnknown) {
		t.Fatalf("an identity not mine: %v", err)
	}
	// my own device is nobody's device: a contact's list naming it gets
	// nothing through the contact door either
	if err := k.book.Admit(k.bob.id.pub, desk.ID, desk.Key); err == nil {
		t.Fatal("my own device taken as the contact's")
	}
}

func TestOwnListsMoveForwardOnly(t *testing.T) {
	s := newShim()
	me := newAccount(t, s)
	a := me.linkReg(t)
	b := me.linkReg(t)
	own := NewOwn()
	first := me.wire
	if gone, err := own.Set(me.id.pub, first, me.id.pub, s); err != nil || gone != nil {
		t.Fatalf("first: %v %v", gone, err)
	}
	if gone, err := own.Set(me.id.pub, first, me.id.pub, s); err != nil || gone != nil {
		t.Fatalf("the same again: %v %v", gone, err)
	}
	me.unlink(t, a.ID)
	gone, err := own.Set(me.id.pub, me.wire, me.id.pub, s)
	if err != nil || len(gone) != 1 || gone[0] != a {
		t.Fatalf("a removal: %v %v", gone, err)
	}
	if _, err := own.Set(me.id.pub, first, me.id.pub, s); !errors.Is(err, ErrRollback) {
		t.Fatalf("an older list: %v", err)
	}
	eq := clone(me.list)
	eq.Devices = eq.Devices[:1]
	if w, err := eq.Sign(me.id); err != nil {
		t.Fatal(err)
	} else if _, err := own.Set(me.id.pub, w, me.id.pub, s); !errors.Is(err, ErrEquivocation) {
		t.Fatalf("two lists at one version: %v", err)
	}
	far := clone(me.list)
	far.Version += VersionWindow + 1
	if w, err := far.Sign(me.id); err != nil {
		t.Fatal(err)
	} else if _, err := own.Set(me.id.pub, w, me.id.pub, s); !errors.Is(err, ErrJump) {
		t.Fatalf("too far ahead: %v", err)
	}
	if _, err := own.Set(me.id.pub, forge(me.list), me.id.pub, s); !errors.Is(err, ErrSignature) {
		t.Fatalf("a forged list: %v", err)
	}
	// the linked device b's view: removed means wipe, and nothing is held
	devOwn := NewOwn()
	if _, err := devOwn.Set(me.id.pub, me.wire, b.Key, s); err != nil {
		t.Fatal(err)
	}
	if o := devOwn.Others(me.id.pub); len(o) != 1 || !o[0].Phone {
		t.Fatalf("the device's others: %+v", o)
	}
	me.unlink(t, b.ID)
	if _, err := devOwn.Set(me.id.pub, me.wire, b.Key, s); !errors.Is(err, ErrRemoved) {
		t.Fatalf("this device removed: %v", err)
	}
	if devOwn.Current(me.id.pub) != nil || devOwn.Others(me.id.pub) != nil {
		t.Fatal("a removed device keeps its list")
	}
	if got := devOwn.Stale(me.id.pub, []Held{{PhoneID, me.id.pub}}); !slices.Equal(got, []uint8{PhoneID}) {
		t.Fatalf("a removed device keeps its sessions: %v", got)
	}
	// a key change at one id is a device gone
	c := me.linkReg(t)
	if _, err := own.Set(me.id.pub, me.wire, me.id.pub, s); err != nil {
		t.Fatal(err)
	}
	nk, _ := newKey(t)
	l := clone(me.list)
	for i := range l.Devices {
		if l.Devices[i].ID == c.ID {
			l.Devices[i].Key = nk
		}
	}
	l.Version++
	w, err := l.Sign(me.id)
	if err != nil {
		t.Fatal(err)
	}
	gone, err = own.Set(me.id.pub, w, me.id.pub, s)
	if err != nil || len(gone) != 1 || gone[0] != c {
		t.Fatalf("a key change: %v %v", gone, err)
	}
	if got := own.Stale(me.id.pub, []Held{{c.ID, c.Key}, {PhoneID, me.id.pub}}); !slices.Equal(got, []uint8{c.ID, PhoneID}) {
		t.Fatalf("own stale: %v", got)
	}
}

func TestAFirstOwnListWithoutThisDeviceIsNoWipe(t *testing.T) {
	s := newShim()
	me := newAccount(t, s)
	genesis := me.wire
	b := me.linkReg(t)
	own := NewOwn()
	// the list from before this device was linked, replayed to it first
	if _, err := own.Set(me.id.pub, genesis, b.Key, s); !errors.Is(err, ErrNotListed) {
		t.Fatalf("a first list without this device: %v", err)
	}
	if own.Current(me.id.pub) != nil {
		t.Fatal("a list without this device held")
	}
	if _, err := own.Set(me.id.pub, me.wire, b.Key, s); err != nil {
		t.Fatal(err)
	}
	if _, err := own.Set(me.id.pub, genesis, b.Key, s); !errors.Is(err, ErrRollback) {
		t.Fatalf("the genesis list after this device's: %v", err)
	}
	// a contact's list, even one naming my keys, is not one of mine
	bob := newAccount(t, s)
	if _, err := own.Set(me.id.pub, bob.wire, b.Key, s); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("another identity's list: %v", err)
	}
	if _, err := own.Set(me.id.pub, bob.wire, bob.id.pub, s); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("another identity's list naming the key: %v", err)
	}
	if own.Current(bob.id.pub) != nil {
		t.Fatal("a contact's list held as my own")
	}
}

func TestClassicAfterPQIsRefused(t *testing.T) {
	k := newFanoutKit(t, 1, 2)
	classic := Peer{Devices: true, PhoneClassic: true}
	his, mine := split(k.to(t, classic, time.Now()))
	if len(his) != 1 || his[0].Device != PhoneID || len(mine) != 1 {
		t.Fatalf("a classic phone session: no device copies until the restart: %v %d", ids(his), len(mine))
	}
	if k.book.PQ(k.bob.id.pub) {
		t.Fatal("pq before any")
	}
	if err := k.book.SawPQ(k.bob.id.pub); err != nil {
		t.Fatal(err)
	}
	if _, err := k.f.To(k.me.id.pub, k.bob.id.pub, classic, time.Now()); !errors.Is(err, ErrClassic) {
		t.Fatalf("classic after pq: %v", err)
	}
	if _, err := k.f.To(k.me.id.pub, k.bob.id.pub, Peer{PhoneClassic: true}, time.Now()); !errors.Is(err, ErrClassic) {
		t.Fatalf("classic after pq, caps or not: %v", err)
	}
	if his, _ := split(k.to(t, withDevices, time.Now())); len(his) != 3 {
		t.Fatalf("after the restart: %v", ids(his))
	}
	// it sticks, whatever list comes
	k.bob.unlink(t, k.bob.list.Devices[1].ID)
	k.takeBob(t)
	if !k.book.PQ(k.bob.id.pub) {
		t.Fatal("pq forgotten on a list change")
	}
	if err := k.book.SawPQ(fixedKey(t, 4)); !errors.Is(err, ErrUnknown) {
		t.Fatalf("a stranger: %v", err)
	}
}

func TestADeviceThatNeverAnswers(t *testing.T) {
	q := NewQuiet()
	id := fixedKey(t, 6)
	t0 := time.Unix(1_760_000_000, 0)
	day := 24 * time.Hour
	key := fixedKey(t, 7)
	at := func(d time.Duration, v uint64) QuietState { return q.State(id, 5, key, v, t0.Add(d)) }
	if at(0, 1) != Open {
		t.Fatal("nothing sent")
	}
	q.Sent(id, 5, key, t0)
	q.Sent(id, 5, key, t0.Add(3*day))
	if at(15*day-time.Second, 1) != Open {
		t.Fatal("rebuilt too early")
	}
	if at(15*day, 1) != Rebuild {
		t.Fatal("not rebuilt at 15 days")
	}
	q.Rebuilt(id, 5)
	q.Sent(id, 5, key, t0.Add(16*day))
	if at(29*day, 1) != Open {
		t.Fatal("a rebuilt session starts its 15 days again")
	}
	if at(30*day, 1) != Silent {
		t.Fatal("not silent 30 days after the first copy")
	}
	if at(31*day, 1) != Silent {
		t.Fatal("silent ends by itself")
	}
	if at(32*day, 2) != Open {
		t.Fatal("a new list does not give another try")
	}
	q.Sent(id, 5, key, t0.Add(32*day))
	if at(61*day, 2) != Rebuild || at(62*day, 2) != Silent {
		t.Fatal("the second try has its own 30 days")
	}
	q.Heard(id, 5)
	if at(90*day, 2) != Open {
		t.Fatal("heard from, still silent")
	}
	// a clock set back counts no time
	q.Sent(id, 5, key, t0.Add(100*day))
	if at(10*day, 2) != Open {
		t.Fatal("a clock set back silenced it")
	}
	q.Forget(id, 5)
	if at(200*day, 2) != Open {
		t.Fatal("forgotten")
	}
}

func TestANewDeviceUnderAnOldIDStartsAfresh(t *testing.T) {
	q := NewQuiet()
	id := fixedKey(t, 6)
	old, fresh := fixedKey(t, 7), fixedKey(t, 8)
	t0 := time.Unix(1_760_000_000, 0)
	day := 24 * time.Hour
	q.Sent(id, 5, old, t0)
	// device 5 removed after 29 days unanswered, a new device 5 listed
	if got := q.State(id, 5, fresh, 2, t0.Add(29*day)); got != Open {
		t.Fatalf("the new device: %v", got)
	}
	q.Sent(id, 5, fresh, t0.Add(29*day))
	if got := q.State(id, 5, fresh, 2, t0.Add(31*day)); got != Open {
		t.Fatalf("the new device inherits the old one's days: %v", got)
	}
	if got := q.State(id, 5, fresh, 2, t0.Add(44*day)); got != Rebuild {
		t.Fatalf("its own 15 days: %v", got)
	}

	s := newShim()
	me := newAccount(t, s)
	desk := me.linkReg(t)
	p := NewPool()
	if err := p.Put(me.id.pub, desk, [][]byte{poolKDB1(t, 10, 7, desk)}, poolKDB1(t, 1, 7, desk), t0); err != nil {
		t.Fatal(err)
	}
	moved := desk
	moved.Key = fresh
	if _, _, err := p.Take(me.id.pub, moved, t0); !errors.Is(err, ErrNoBundle) {
		t.Fatalf("an old key's bundle handed out: %v", err)
	}
	if _, _, err := p.Take(me.id.pub, desk, t0); !errors.Is(err, ErrNoBundle) {
		t.Fatalf("the old key's bundles kept: %v", err)
	}
}

func TestQuietDevicesInTheFanout(t *testing.T) {
	k := newFanoutKit(t, 1, 2)
	t0 := time.Unix(1_760_000_000, 0)
	day := 24 * time.Hour
	d := k.bob.list.Devices[1]
	var desk Entry
	for _, e := range k.me.list.Devices {
		if !e.Phone {
			desk = e
		}
	}
	// every copy so far went unanswered, the phones' too
	for _, s := range k.to(t, withDevices, t0) {
		k.f.Quiet.Sent(s.Identity, s.Device, s.Key, t0)
	}
	k.f.Quiet.Heard(k.bob.id.pub, k.bob.list.Devices[2].ID)
	slots := k.to(t, withDevices, t0.Add(15*day))
	for _, s := range slots {
		want := s.Device == d.ID || (s.Own && s.Device == desk.ID)
		if s.Rebuild != want {
			t.Fatalf("rebuild on %d (own %v): %v", s.Device, s.Own, s.Rebuild)
		}
	}
	his, mine := split(k.to(t, withDevices, t0.Add(30*day)))
	if slices.Contains(ids(his), d.ID) || len(his) != 2 || len(mine) != 0 {
		t.Fatalf("silent devices still get copies: %v %v", ids(his), ids(mine))
	}
	if !slices.Contains(ids(his), PhoneID) {
		t.Fatal("the phone was silenced")
	}
	// bob signs a new list (another device linked): d gets another try
	k.bob.linkReg(t)
	k.takeBob(t)
	if his, _ := split(k.to(t, withDevices, t0.Add(31*day))); !slices.Contains(ids(his), d.ID) {
		t.Fatal("a new list did not resume the device")
	}
}

func TestThePoolHandsEachBundleOnce(t *testing.T) {
	s := newShim()
	me := newAccount(t, s)
	desk := me.linkReg(t)
	kdb1 := func(kyber uint32, e Entry) []byte { return poolKDB1(t, kyber, 7, e) }
	t0 := time.Unix(1_760_000_000, 0)
	p := NewPool()
	if _, _, err := p.Take(me.id.pub, desk, t0); !errors.Is(err, ErrNoBundle) {
		t.Fatalf("an empty pool: %v", err)
	}
	var once [][]byte
	for i := range PoolLow + 2 {
		once = append(once, kdb1(uint32(100+i), desk))
	}
	if err := p.Put(me.id.pub, desk, once, kdb1(1, desk), t0); err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for i := range PoolLow + 2 {
		b, low, err := p.Take(me.id.pub, desk, t0)
		if err != nil || seen[string(b)] {
			t.Fatalf("take %d: %v (again: %v)", i, err, seen[string(b)])
		}
		seen[string(b)] = true
		if low != (i >= 1) {
			t.Fatalf("take %d: low %v", i, low)
		}
	}
	for range 3 {
		b, low, err := p.Take(me.id.pub, desk, t0)
		if err != nil || !low || seen[string(b)] {
			t.Fatalf("the last resort: %v %v", low, err)
		}
		bl, _ := ParseBundle(b, me.id.pub)
		if bl.KyberID != 1 {
			t.Fatalf("not the last resort: %d", bl.KyberID)
		}
	}
	// a kyber key handed out once is never taken again
	if err := p.Put(me.id.pub, desk, [][]byte{kdb1(100, desk)}, nil, t0); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("a kyber key again: %v", err)
	}
	if err := p.Put(me.id.pub, desk, [][]byte{kdb1(1, desk)}, nil, t0); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("the last resort kyber as one-time: %v", err)
	}
	other := me.linkReg(t)
	wrongKey := desk
	wrongKey.Key = other.Key
	wrongReg := desk
	wrongReg.Reg++
	for name, b := range map[string][]byte{
		"another device's":  kdb1(200, other),
		"on another key":    kdb1(201, wrongKey),
		"under another reg": kdb1(202, wrongReg),
		"junk":              []byte("KDB1\x01"),
	} {
		if err := p.Put(me.id.pub, desk, [][]byte{b}, nil, t0); err == nil {
			t.Errorf("%s bundle taken", name)
		}
	}
	if err := p.Put(me.id.pub, me.list.Devices[0], nil, nil, t0); !errors.Is(err, ErrPhone) {
		t.Fatalf("the phone pooled: %v", err)
	}
	var many [][]byte
	for i := range PoolMost + 1 {
		many = append(many, kdb1(uint32(1000+i), other))
	}
	if err := p.Put(me.id.pub, other, many, nil, t0); !errors.Is(err, ErrTooMany) {
		t.Fatalf("too many: %v", err)
	}
	// a failed put keeps nothing
	if err := p.Put(me.id.pub, other, [][]byte{kdb1(300, other), kdb1(300, other)}, nil, t0); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("one kyber twice in a batch: %v", err)
	}
	if _, _, err := p.Take(me.id.pub, other, t0); !errors.Is(err, ErrNoBundle) {
		t.Fatalf("a failed put kept something: %v", err)
	}
	p.Drop(me.id.pub, desk.ID)
	if _, _, err := p.Take(me.id.pub, desk, t0); !errors.Is(err, ErrNoBundle) {
		t.Fatalf("a removed device's bundles: %v", err)
	}
}

func poolKDB1(t *testing.T, kyber, spk uint32, e Entry) []byte {
	t.Helper()
	b := testBlock(t, e.ID, e.Reg, &e.Key, false)
	b.KyberID, b.SpkID = kyber, spk
	w, err := EncodeBundle(b)
	if err != nil {
		t.Fatal(err)
	}
	return w
}

func TestNoDeadBundleIsHandedOut(t *testing.T) {
	s := newShim()
	me := newAccount(t, s)
	desk := me.linkReg(t)
	t0 := time.Unix(1_760_000_000, 0)
	day := 24 * time.Hour
	kyberOf := func(b []byte) uint32 {
		bl, err := ParseBundle(b, me.id.pub)
		if err != nil {
			t.Fatal(err)
		}
		return bl.KyberID
	}
	p := NewPool()
	if err := p.Put(me.id.pub, desk, [][]byte{poolKDB1(t, 10, 7, desk), poolKDB1(t, 11, 7, desk)}, poolKDB1(t, 1, 7, desk), t0); err != nil {
		t.Fatal(err)
	}
	if err := p.Put(me.id.pub, desk, [][]byte{poolKDB1(t, 12, 7, desk)}, nil, t0.Add(5*day)); err != nil {
		t.Fatal(err)
	}
	// 10 and 11 are past the pool's age at day 7: never handed out
	b, low, err := p.Take(me.id.pub, desk, t0.Add(PoolMaxAge))
	if err != nil || kyberOf(b) != 12 || !low {
		t.Fatalf("an old bundle handed out: %d %v %v", kyberOf(b), low, err)
	}
	if b, _, err := p.Take(me.id.pub, desk, t0.Add(PoolMaxAge)); err != nil || kyberOf(b) != 1 {
		t.Fatalf("not the last resort: %v", err)
	}
	// the device replaced its session keys: one-time bundles on the old
	// ones go when the new last resort comes, and none come without it
	if err := p.Put(me.id.pub, desk, [][]byte{poolKDB1(t, 13, 7, desk)}, nil, t0.Add(8*day)); err != nil {
		t.Fatal(err)
	}
	if err := p.Put(me.id.pub, desk, [][]byte{poolKDB1(t, 14, 8, desk)}, nil, t0.Add(8*day)); !errors.Is(err, ErrOldKeys) {
		t.Fatalf("a bundle on keys the last resort is not on: %v", err)
	}
	last2 := poolKDB1(t, 2, 8, desk)
	if err := p.Put(me.id.pub, desk, [][]byte{poolKDB1(t, 14, 8, desk)}, last2, t0.Add(8*day)); err != nil {
		t.Fatal(err)
	}
	for _, want := range []uint32{14, 2} {
		if b, _, err := p.Take(me.id.pub, desk, t0.Add(8*day)); err != nil || kyberOf(b) != want {
			t.Fatalf("want %d: %v", want, err)
		}
	}
	// the same last resort again keeps the day it came
	if err := p.Put(me.id.pub, desk, nil, last2, t0.Add(30*day)); err != nil {
		t.Fatal(err)
	}
	if _, _, err := p.Take(me.id.pub, desk, t0.Add(8*day+PoolLastMaxAge)); !errors.Is(err, ErrNoBundle) {
		t.Fatalf("a last resort past its age handed out: %v", err)
	}
	// a replaced last resort's kyber key is never taken again
	if err := p.Put(me.id.pub, desk, nil, poolKDB1(t, 1, 9, desk), t0.Add(40*day)); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("an old last resort again: %v", err)
	}
}

func TestThePoolKeepsEightAfterTheLink(t *testing.T) {
	s := newShim()
	me := newAccount(t, s)
	desk := me.linkReg(t)
	t0 := time.Unix(1_760_000_000, 0)
	p := NewPool()
	if n := p.Need(me.id.pub, desk, t0); n != PoolKeep {
		t.Fatalf("an empty pool asks for %d", n)
	}
	// the link: one for each of 400 devices the first push reaches
	var link [][]byte
	for i := range 400 {
		link = append(link, poolKDB1(t, uint32(100+i), 7, desk))
	}
	if err := p.Put(me.id.pub, desk, link, poolKDB1(t, 1, 7, desk), t0); err != nil {
		t.Fatal(err)
	}
	for range 400 - PoolLow - 1 {
		if _, _, err := p.Take(me.id.pub, desk, t0); err != nil {
			t.Fatal(err)
		}
	}
	if n := p.Need(me.id.pub, desk, t0); n != 0 {
		t.Fatalf("%d asked for with %d left", n, PoolLow+1)
	}
	if _, low, err := p.Take(me.id.pub, desk, t0); err != nil || !low {
		t.Fatalf("not low at %d: %v", PoolLow, err)
	}
	if n := p.Need(me.id.pub, desk, t0); n != PoolKeep-PoolLow {
		t.Fatalf("a refill of %d", n)
	}
	var refill [][]byte
	for i := range PoolKeep - PoolLow {
		refill = append(refill, poolKDB1(t, uint32(1000+i), 7, desk))
	}
	if err := p.Put(me.id.pub, desk, refill, nil, t0); err != nil {
		t.Fatal(err)
	}
	if n := p.Need(me.id.pub, desk, t0); n != 0 {
		t.Fatalf("a full pool asks for %d", n)
	}
	// all of them aged out: a full batch again
	if n := p.Need(me.id.pub, desk, t0.Add(PoolMaxAge)); n != PoolKeep {
		t.Fatalf("an aged pool asks for %d", n)
	}
}

func TestASilentDeviceIsProbedAndTakesAFreshBundle(t *testing.T) {
	q := NewQuiet()
	id, key := fixedKey(t, 6), fixedKey(t, 7)
	t0 := time.Unix(1_760_000_000, 0)
	day := 24 * time.Hour
	at := func(d time.Duration) QuietState { return q.State(id, 5, key, 1, t0.Add(d)) }
	q.Sent(id, 5, key, t0)
	if at(30*day) != Silent || at(36*day) != Silent {
		t.Fatal("not silent")
	}
	// a week on: one copy on a session from a fresh bundle, then silent
	if at(37*day) != Rebuild {
		t.Fatal("no weekly probe")
	}
	if at(37*day) != Silent {
		t.Fatal("the probe is more than one copy")
	}
	q.Rebuilt(id, 5)
	q.Sent(id, 5, key, t0.Add(37*day))
	if at(43*day) != Silent || at(44*day) != Rebuild {
		t.Fatal("no probe the week after")
	}
	// a bundle its owner's phone pushed ends the silence; not one of
	// another key, and not for a device that is not silent
	if q.Fresh(id, 5, fixedKey(t, 8)) {
		t.Fatal("another key's bundle")
	}
	q.Sent(id, 5, key, t0.Add(44*day))
	if !q.Fresh(id, 5, key) {
		t.Fatal("a fresh bundle did not end the silence")
	}
	if at(45*day) != Open {
		t.Fatal("still silent after a fresh bundle")
	}
	q.Sent(id, 5, key, t0.Add(45*day))
	if q.Fresh(id, 5, key) || at(46*day) != Open {
		t.Fatal("a fresh bundle for a device that is not silent")
	}
}
