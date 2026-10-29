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
	if _, err := k.own.Set(k.me.wire, k.me.id.pub, s); err != nil {
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
	if gone, err := own.Set(first, me.id.pub, s); err != nil || gone != nil {
		t.Fatalf("first: %v %v", gone, err)
	}
	if gone, err := own.Set(first, me.id.pub, s); err != nil || gone != nil {
		t.Fatalf("the same again: %v %v", gone, err)
	}
	me.unlink(t, a.ID)
	gone, err := own.Set(me.wire, me.id.pub, s)
	if err != nil || len(gone) != 1 || gone[0] != a {
		t.Fatalf("a removal: %v %v", gone, err)
	}
	if _, err := own.Set(first, me.id.pub, s); !errors.Is(err, ErrRollback) {
		t.Fatalf("an older list: %v", err)
	}
	eq := clone(me.list)
	eq.Devices = eq.Devices[:1]
	if w, err := eq.Sign(me.id); err != nil {
		t.Fatal(err)
	} else if _, err := own.Set(w, me.id.pub, s); !errors.Is(err, ErrEquivocation) {
		t.Fatalf("two lists at one version: %v", err)
	}
	far := clone(me.list)
	far.Version += VersionWindow + 1
	if w, err := far.Sign(me.id); err != nil {
		t.Fatal(err)
	} else if _, err := own.Set(w, me.id.pub, s); !errors.Is(err, ErrJump) {
		t.Fatalf("too far ahead: %v", err)
	}
	if _, err := own.Set(forge(me.list), me.id.pub, s); !errors.Is(err, ErrSignature) {
		t.Fatalf("a forged list: %v", err)
	}
	// the linked device b's view: removed means wipe, and nothing is held
	devOwn := NewOwn()
	if _, err := devOwn.Set(me.wire, b.Key, s); err != nil {
		t.Fatal(err)
	}
	if o := devOwn.Others(me.id.pub); len(o) != 1 || !o[0].Phone {
		t.Fatalf("the device's others: %+v", o)
	}
	me.unlink(t, b.ID)
	if _, err := devOwn.Set(me.wire, b.Key, s); !errors.Is(err, ErrRemoved) {
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
	if _, err := own.Set(me.wire, me.id.pub, s); err != nil {
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
	gone, err = own.Set(w, me.id.pub, s)
	if err != nil || len(gone) != 1 || gone[0] != c {
		t.Fatalf("a key change: %v %v", gone, err)
	}
	if got := own.Stale(me.id.pub, []Held{{c.ID, c.Key}, {PhoneID, me.id.pub}}); !slices.Equal(got, []uint8{c.ID, PhoneID}) {
		t.Fatalf("own stale: %v", got)
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
	at := func(d time.Duration, v uint64) QuietState { return q.State(id, 5, v, t0.Add(d)) }
	if at(0, 1) != Open {
		t.Fatal("nothing sent")
	}
	q.Sent(id, 5, t0)
	q.Sent(id, 5, t0.Add(3*day))
	if at(15*day-time.Second, 1) != Open {
		t.Fatal("rebuilt too early")
	}
	if at(15*day, 1) != Rebuild {
		t.Fatal("not rebuilt at 15 days")
	}
	q.Rebuilt(id, 5)
	q.Sent(id, 5, t0.Add(16*day))
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
	q.Sent(id, 5, t0.Add(32*day))
	if at(61*day, 2) != Rebuild || at(62*day, 2) != Silent {
		t.Fatal("the second try has its own 30 days")
	}
	q.Heard(id, 5)
	if at(90*day, 2) != Open {
		t.Fatal("heard from, still silent")
	}
	// a clock set back counts no time
	q.Sent(id, 5, t0.Add(100*day))
	if at(10*day, 2) != Open {
		t.Fatal("a clock set back silenced it")
	}
	q.Forget(id, 5)
	if at(200*day, 2) != Open {
		t.Fatal("forgotten")
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
		k.f.Quiet.Sent(s.Identity, s.Device, t0)
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
	kdb1 := func(kyber uint32, e Entry) []byte {
		b := testBlock(t, e.ID, e.Reg, &e.Key, false)
		b.KyberID = kyber
		w, err := EncodeBundle(b)
		if err != nil {
			t.Fatal(err)
		}
		return w
	}
	p := NewPool()
	if _, _, err := p.Take(me.id.pub, desk.ID); !errors.Is(err, ErrNoBundle) {
		t.Fatalf("an empty pool: %v", err)
	}
	var once [][]byte
	for i := range PoolLow + 2 {
		once = append(once, kdb1(uint32(100+i), desk))
	}
	if err := p.Put(me.id.pub, desk, once, kdb1(1, desk)); err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for i := range PoolLow + 2 {
		b, low, err := p.Take(me.id.pub, desk.ID)
		if err != nil || seen[string(b)] {
			t.Fatalf("take %d: %v (again: %v)", i, err, seen[string(b)])
		}
		seen[string(b)] = true
		if low != (i >= 1) {
			t.Fatalf("take %d: low %v", i, low)
		}
	}
	for range 3 {
		b, low, err := p.Take(me.id.pub, desk.ID)
		if err != nil || !low || seen[string(b)] {
			t.Fatalf("the last resort: %v %v", low, err)
		}
		bl, _ := ParseBundle(b, me.id.pub)
		if bl.KyberID != 1 {
			t.Fatalf("not the last resort: %d", bl.KyberID)
		}
	}
	// a kyber key handed out once is never taken again
	if err := p.Put(me.id.pub, desk, [][]byte{kdb1(100, desk)}, nil); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("a kyber key again: %v", err)
	}
	if err := p.Put(me.id.pub, desk, [][]byte{kdb1(1, desk)}, nil); !errors.Is(err, ErrDuplicate) {
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
		if err := p.Put(me.id.pub, desk, [][]byte{b}, nil); err == nil {
			t.Errorf("%s bundle taken", name)
		}
	}
	if err := p.Put(me.id.pub, me.list.Devices[0], nil, nil); !errors.Is(err, ErrPhone) {
		t.Fatalf("the phone pooled: %v", err)
	}
	var many [][]byte
	for i := range PoolMost + 1 {
		many = append(many, kdb1(uint32(1000+i), other))
	}
	if err := p.Put(me.id.pub, other, many, nil); !errors.Is(err, ErrTooMany) {
		t.Fatalf("too many: %v", err)
	}
	// a failed put keeps nothing
	if err := p.Put(me.id.pub, other, [][]byte{kdb1(300, other), kdb1(300, other)}, nil); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("one kyber twice in a batch: %v", err)
	}
	if _, _, err := p.Take(me.id.pub, other.ID); !errors.Is(err, ErrNoBundle) {
		t.Fatalf("a failed put kept something: %v", err)
	}
	p.Drop(me.id.pub, desk.ID)
	if _, _, err := p.Take(me.id.pub, desk.ID); !errors.Is(err, ErrNoBundle) {
		t.Fatalf("a removed device's bundles: %v", err)
	}
}
