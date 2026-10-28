// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"go/parser"
	"go/token"
	"math"
	"strconv"
	"testing"
)

// the vector list: identity from private bytes 0x11.., the phone (reg
// 0x0102) and a desktop (key from 0x22.., id 0x2a, reg 0x3fff, answering),
// version 0x00aabbccddeeff01
func vectorList(t *testing.T) *List {
	t.Helper()
	id := fixedKey(t, 0x11)
	return &List{
		Identity: id,
		Version:  0x00aabbccddeeff01,
		Devices: []Entry{
			{ID: PhoneID, Key: id, Reg: 0x0102, Phone: true},
			{ID: 0x2a, Key: fixedKey(t, 0x22), Reg: 0x3fff, Answers: true},
		},
	}
}

const vectorBody = "" +
	"4b444c32" + // KDL2
	"05" + "7b4e909bbe7ffe44c465a220037d608ee35897d31ef972f07f74892cb0f73f13" + // identity
	"00aabbccddeeff01" + // version
	"02" + // count
	"01" + "05" + "7b4e909bbe7ffe44c465a220037d608ee35897d31ef972f07f74892cb0f73f13" + "00000102" + "01" +
	"2a" + "05" + "0faa684ed28867b97f4a6a2dee5df8ce974e76b7018e3f22a1c4cf2678570f20" + "00003fff" + "02"

func TestTheListVector(t *testing.T) {
	l := vectorList(t)
	if err := l.check(); err != nil {
		t.Fatal(err)
	}
	if got := hex.EncodeToString(l.Body()); got != vectorBody {
		t.Fatalf("body\n got %s\nwant %s", got, vectorBody)
	}
	sig := bytes.Repeat([]byte{0xa5}, SigSize)
	w := append(l.Body(), sig...)
	if len(w) != 110+2*39 {
		t.Fatalf("size %d", len(w))
	}
	back, err := ParseList(w)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(back.Wire(), w) || !SameBody(back, l) {
		t.Fatal("does not read back as itself")
	}
	if a, ok := back.Answering(); !ok || a.ID != 0x2a {
		t.Fatal("answering entry lost")
	}
}

func TestSizes(t *testing.T) {
	if MinListSize != 149 || MaxListSize != 344 {
		t.Fatalf("sizes %d %d", MinListSize, MaxListSize)
	}
	s := newShim()
	a := newAccount(t, s)
	if len(a.wire) != MinListSize {
		t.Fatalf("phone alone %d", len(a.wire))
	}
	for i := 1; i < MaxDevices; i++ {
		a.link(t)
		if len(a.wire) != 110+39*(i+1) {
			t.Fatalf("%d devices: %d bytes", i+1, len(a.wire))
		}
	}
	if len(a.wire) != MaxListSize {
		t.Fatalf("six devices %d", len(a.wire))
	}
	k, _ := newKey(t)
	if _, err := a.list.Add(Entry{ID: 99, Key: k, Reg: 5}, rand.Reader); !errors.Is(err, ErrTooMany) {
		t.Fatalf("a seventh device: %v", err)
	}
	// a seventh entry forged onto the wire
	seven := clone(a.list)
	seven.Devices = append(seven.Devices, Entry{ID: 126, Key: k, Reg: 5})
	b := forge(seven)
	b[listHead-1] = 7
	if _, err := ParseList(b); err == nil {
		t.Fatal("seven devices read")
	}
}

// a list has no field a name or a date could go in, and nothing in it
// moves with the clock
func TestAListCarriesNoNameOrDate(t *testing.T) {
	id := fixedKey(t, 0x11)
	l1, err := Genesis(id, 9, seeded(1))
	if err != nil {
		t.Fatal(err)
	}
	l2, err := Genesis(id, 9, seeded(1))
	if err != nil {
		t.Fatal(err)
	}
	if !SameBody(l1, l2) {
		t.Fatal("two lists from one random source differ")
	}
	k := fixedKey(t, 0x22)
	n1, err := l1.Add(Entry{ID: 5, Key: k, Reg: 6}, seeded(2))
	if err != nil {
		t.Fatal(err)
	}
	n2, err := l2.Add(Entry{ID: 5, Key: k, Reg: 6}, seeded(2))
	if err != nil {
		t.Fatal(err)
	}
	if !SameBody(n1, n2) || len(n1.Body()) != listHead+2*entrySize {
		t.Fatal("a change carries more than its devices")
	}
	// the formats never read the clock
	fs := token.NewFileSet()
	for _, f := range []string{"list.go", "known.go", "bundle.go", "keyring.go", "key.go"} {
		pf, err := parser.ParseFile(fs, f, nil, parser.ImportsOnly)
		if err != nil {
			t.Fatal(err)
		}
		for _, im := range pf.Imports {
			if p, _ := strconv.Unquote(im.Path.Value); p == "time" {
				t.Errorf("%s imports time", f)
			}
		}
	}
}

func TestGenesisStartsBelow2To56(t *testing.T) {
	id := fixedKey(t, 0x11)
	seen := map[uint64]bool{}
	for i := range 2000 {
		l, err := Genesis(id, 9, seeded(uint64(i)))
		if err != nil {
			t.Fatal(err)
		}
		if l.Version == 0 || l.Version >= 1<<56 {
			t.Fatalf("start %d", l.Version)
		}
		seen[l.Version] = true
	}
	if len(seen) < 1990 {
		t.Fatalf("only %d distinct starts", len(seen))
	}
	// the top bits get used too, so starts do not cluster low
	l, _ := Genesis(id, 9, constReader(0xff))
	if l.Version != 1<<56-1 {
		t.Fatalf("all ones gives %d", l.Version)
	}
}

func TestVersionSteps(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	k, _ := newKey(t)
	e := Entry{ID: 40, Key: k, Reg: 3}
	for _, c := range []struct {
		r    constReader
		step uint64
	}{{0, 1}, {0x7f, 128}, {0xff, 256}} {
		n, err := a.list.Add(e, c.r)
		if err != nil {
			t.Fatal(err)
		}
		if n.Version-a.list.Version != c.step {
			t.Fatalf("add with %x: step %d", byte(c.r), n.Version-a.list.Version)
		}
		m, err := n.Remove(40, c.r)
		if err != nil || m.Version-n.Version != c.step {
			t.Fatalf("remove: %v", err)
		}
		st, err := n.Settled(c.r)
		if err != nil || st.Version-n.Version != c.step {
			t.Fatalf("settled: %v", err)
		}
	}
	// every step over many draws stays in 1..256
	for i := range 3000 {
		n, err := a.list.Add(e, seeded(uint64(i)))
		if err != nil {
			t.Fatal(err)
		}
		if d := n.Version - a.list.Version; d < 1 || d > 256 {
			t.Fatalf("step %d", d)
		}
	}
}

func TestTheRestoreJump(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	r, err := a.list.Restored(constReader(0))
	if err != nil || r.Version-a.list.Version != 1<<40 {
		t.Fatalf("lowest jump: %v", err)
	}
	r, err = a.list.Restored(constReader(0xff))
	if err != nil || r.Version-a.list.Version != 1<<40+math.MaxUint32 {
		t.Fatalf("highest jump: %v", err)
	}
	// a phone that signed a million changes after its backup still lands
	// above all of them
	if uint64(1<<40) <= 1_000_000*256 {
		t.Fatal("the jump is too small")
	}
	if !SameBody(&List{Identity: r.Identity, Version: r.Version, Devices: a.list.Devices}, r) {
		t.Fatal("a restore changed the phone")
	}
}

// a backup made while a laptop was linked, the laptop stolen and removed,
// then the phone restored from that backup: the laptop is not back
func TestARestoreListsThePhoneAlone(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	desk := a.link(t)
	a.link(t)
	backup := clone(a.list)
	k := newKnown(a.id.pub)
	a.unlink(t, desk.ID)
	if _, _, err := k.take(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	r, err := backup.Restored(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	if len(r.Devices) != 1 || !r.Devices[0].Phone || r.Devices[0].Key != a.id.pub {
		t.Fatalf("the restore lists %d devices", len(r.Devices))
	}
	w, err := r.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	if _, out, err := k.take(w, FromSession(a.id.pub), s); err != nil || out != Changed {
		t.Fatalf("the restore list: %v %v", out, err)
	}
	if k.vouches(desk.Key) {
		t.Fatal("the removed laptop is back")
	}
}

func TestTheLastVersionDoesNotWrap(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	top := clone(a.list)
	top.Version = MaxVersion - 10
	k, _ := newKey(t)
	if _, err := top.Add(Entry{ID: 9, Key: k, Reg: 1}, constReader(0xff)); !errors.Is(err, ErrVersion) {
		t.Fatalf("add past the top: %v", err)
	}
	if _, err := top.Restored(rand.Reader); !errors.Is(err, ErrVersion) {
		t.Fatalf("restore past the top: %v", err)
	}
	n, err := top.Add(Entry{ID: 9, Key: k, Reg: 1}, constReader(5))
	if err != nil || n.Version != MaxVersion-4 {
		t.Fatalf("a step that fits: %v", err)
	}
	// a step onto 2^63 itself is refused, as the shim refuses that list
	if _, err := top.Add(Entry{ID: 9, Key: k, Reg: 1}, constReader(9)); !errors.Is(err, ErrVersion) {
		t.Fatalf("a step onto 2^63: %v", err)
	}
	high := clone(a.list)
	high.Version = MaxVersion
	if _, err := ParseList(forge(high)); err == nil {
		t.Fatal("a list at 2^63 read")
	}
	if _, err := high.Sign(a.id); err == nil {
		t.Fatal("a list at 2^63 signed")
	}
}

func TestBrokenListsAreRefused(t *testing.T) {
	good := vectorList(t)
	other, _ := newKey(t)
	cases := map[string]func(l *List){
		"two phones": func(l *List) {
			l.Devices[1].Phone = true
		},
		"phone not device 1": func(l *List) {
			l.Devices[0].ID = 2
		},
		"device 1 not the phone": func(l *List) {
			l.Devices[0].Phone = false
		},
		"phone on another key": func(l *List) {
			l.Devices[0].Key = other
		},
		"a device on the identity key": func(l *List) {
			l.Devices[1].Key = l.Identity
		},
		"the phone answers": func(l *List) {
			l.Devices[0].Answers = true
			l.Devices[1].Answers = false
		},
		"two answer": func(l *List) {
			l.Devices = append(l.Devices, Entry{ID: 0x50, Key: other, Reg: 4, Answers: true})
		},
		"id 0": func(l *List) {
			l.Devices[0].ID = 0
		},
		"id 128": func(l *List) {
			l.Devices[1].ID = 128
		},
		"unsorted": func(l *List) {
			l.Devices = append(l.Devices, Entry{ID: 0x10, Key: other, Reg: 4})
		},
		"same id twice": func(l *List) {
			l.Devices = append(l.Devices, Entry{ID: 0x2a, Key: other, Reg: 4})
		},
		"same key twice": func(l *List) {
			l.Devices = append(l.Devices, Entry{ID: 0x50, Key: l.Devices[1].Key, Reg: 4})
		},
		"reg 0": func(l *List) {
			l.Devices[1].Reg = 0
		},
		"device key with top bit": func(l *List) {
			l.Devices[1].Key[32] |= 0x80
		},
		"device key of small order": func(l *List) {
			l.Devices[1].Key = Key{0x05}
		},
		"identity of small order": func(l *List) {
			l.Identity = Key{0x05, 1}
			l.Devices[0].Key = l.Identity
		},
	}
	for name, breakIt := range cases {
		l := clone(good)
		breakIt(l)
		if _, err := ParseList(forge(l)); err == nil {
			t.Errorf("%s: read", name)
		}
		if _, err := l.Sign(anySigner{l.Identity}); err == nil {
			t.Errorf("%s: signed", name)
		}
	}
	w := forge(good)
	bad := map[string][]byte{
		"trailing byte": append(bytes.Clone(w), 0),
		"short":         w[:len(w)-1],
		"no signature":  w[:len(w)-SigSize],
		"magic":         append([]byte("KDL1"), w[4:]...),
		"empty":         nil,
	}
	flag := bytes.Clone(w)
	flag[listHead+entrySize-1] |= 0x04
	bad["unknown flag"] = flag
	count := bytes.Clone(w)
	count[listHead-1] = 3
	bad["count above the entries"] = count
	zero := bytes.Clone(w)
	zero[listHead-1] = 0
	bad["count zero"] = zero
	for name, b := range bad {
		if _, err := ParseList(b); err == nil {
			t.Errorf("%s: read", name)
		}
	}
}

// every byte of a signed list matters: a flip is refused by the parser
// or by the signature
func TestEveryFlipIsRefused(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	a.link(t)
	a.link(t)
	for i := range a.wire {
		for _, bit := range []byte{0x01, 0x80} {
			b := bytes.Clone(a.wire)
			b[i] ^= bit
			if _, err := ReadList(b, s); err == nil {
				t.Fatalf("byte %d bit %x: taken", i, bit)
			}
		}
	}
	if _, err := ReadList(a.wire, s); err != nil {
		t.Fatal(err)
	}
}

func TestOnlyTheIdentitySigns(t *testing.T) {
	s := newShim()
	a, b := newAccount(t, s), newAccount(t, s)
	if _, err := a.list.Sign(b.id); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("another identity signed: %v", err)
	}
	// b's signature over a's body under a's name does not verify
	forged := append(a.list.Body(), b.wire[len(b.wire)-SigSize:]...)
	if _, err := ReadList(forged, s); !errors.Is(err, ErrSignature) {
		t.Fatalf("a foreign signature: %v", err)
	}
	// the stand-in, like the shim after phase 2, will not sign a body that
	// names another identity
	if _, err := b.id.Sign(ContextList, a.list.Body()); err == nil {
		t.Fatal("signed another identity's body")
	}
	if _, err := a.id.Sign("invite", a.list.Body()); err == nil {
		t.Fatal("signed a list under another context")
	}
	if l := (&List{}); l.Verify(s) == nil {
		t.Fatal("an unsigned list verified")
	}

}
