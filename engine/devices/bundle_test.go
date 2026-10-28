// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"encoding/binary"
	"errors"
	"testing"
)

func testBlock(t *testing.T, device uint8, reg uint32, key *Key, ec bool) *Block {
	t.Helper()
	spk, _ := newKey(t)
	b := &Block{
		Reg:      reg,
		Device:   device,
		SpkID:    0x01020304,
		Spk:      spk,
		SpkSig:   bytes.Repeat([]byte{0x5a}, SigSize),
		KyberID:  0x0a0b0c0d,
		Kyber:    append([]byte{0x08}, bytes.Repeat([]byte{0x33}, KyberSize-1)...),
		KyberSig: bytes.Repeat([]byte{0x6b}, SigSize),
	}
	if key != nil {
		b.HasKey, b.Key = true, *key
	}
	if ec {
		ecKey, _ := newKey(t)
		b.HasEC, b.ECID, b.EC = true, 0x11223344, ecKey
	}
	return b
}

func TestBlockSizes(t *testing.T) {
	k, _ := newKey(t)
	for _, c := range []struct {
		key  *Key
		ec   bool
		size int
	}{{nil, false, 1744}, {&k, false, 1777}, {nil, true, 1781}, {&k, true, 1814}} {
		b := testBlock(t, 3, 9, c.key, c.ec)
		enc := b.Encode()
		if len(enc) != c.size {
			t.Fatalf("block %d bytes, want %d", len(enc), c.size)
		}
		back, err := ParseBlock(enc)
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(back.Encode(), enc) {
			t.Fatal("block does not read back as itself")
		}
		kdb, err := EncodeBundle(b)
		if err != nil {
			t.Fatal(err)
		}
		if len(kdb) != 5+c.size || string(kdb[:4]) != "KDB1" || kdb[4] != 1 {
			t.Fatalf("kdb1 head %x", kdb[:5])
		}
		if _, err := ParseBundle(kdb); err != nil {
			t.Fatal(err)
		}
	}
	// the layout, field by field
	b := testBlock(t, 0x2a, 0x01020304, &k, true)
	enc := b.Encode()
	if binary.BigEndian.Uint32(enc) != 0x01020304 || enc[4] != 0x2a || enc[5] != 3 ||
		!bytes.Equal(enc[6:39], k[:]) || binary.BigEndian.Uint32(enc[39:]) != b.SpkID ||
		!bytes.Equal(enc[43:76], b.Spk[:]) || enc[76] != 0x5a || binary.BigEndian.Uint32(enc[140:]) != b.KyberID ||
		enc[144] != 0x08 || enc[144+KyberSize] != 0x6b || binary.BigEndian.Uint32(enc[1777:]) != b.ECID ||
		!bytes.Equal(enc[1781:], b.EC[:]) {
		t.Fatal("block layout")
	}
}

func TestBrokenBundlesAreRefused(t *testing.T) {
	k, _ := newKey(t)
	good, err := EncodeBundle(testBlock(t, 3, 9, &k, true))
	if err != nil {
		t.Fatal(err)
	}
	set := func(i int, v byte) []byte {
		b := bytes.Clone(good)
		b[i] = v
		return b
	}
	or := func(i int, v byte) []byte {
		b := bytes.Clone(good)
		b[i] |= v
		return b
	}
	cases := map[string][]byte{
		"magic":           append([]byte("KDB2"), good[4:]...),
		"version 2":       set(4, 2),
		"trailing":        append(bytes.Clone(good), 0),
		"short":           good[:len(good)-1],
		"reg 0":           append(append(bytes.Clone(good[:5]), 0, 0, 0, 0), good[9:]...),
		"device 0":        set(9, 0),
		"device 128":      set(9, 128),
		"unknown flag":    or(10, 4),
		"key top bit":     or(5+6+32, 0x80),
		"key type":        set(5+6, 0x06),
		"spk top bit":     or(5+39+4+32, 0x80),
		"kyber type":      set(5+144, 0x05),
		"flag without ec": set(10, 1),
		"empty":           nil,
	}
	for name, b := range cases {
		if _, err := ParseBundle(b); err == nil {
			t.Errorf("%s: read", name)
		}
	}
	if _, err := EncodeBundle(&Block{Reg: 1, Device: 1}); err == nil {
		t.Fatal("an empty block encoded")
	}
}

func TestBundlesOnlyForListedDevices(t *testing.T) {
	s := newShim()
	a := newAccount(t, s)
	desk := a.link(t)
	k := NewKnown(a.id.pub)
	if _, _, err := k.Accept(a.wire, FromSession(a.id.pub), s); err != nil {
		t.Fatal(err)
	}
	enc := func(b *Block) []byte {
		t.Helper()
		p, err := EncodeBundle(b)
		if err != nil {
			t.Fatal(err)
		}
		return p
	}
	phone := a.list.Devices[0]
	if _, err := k.TakeBundle(enc(testBlock(t, PhoneID, phone.Reg, nil, false)), FromSession(a.id.pub)); err != nil {
		t.Fatalf("the phone's bundle: %v", err)
	}
	if _, err := k.TakeBundle(enc(testBlock(t, desk.ID, desk.Reg, &desk.Key, false)), FromSession(desk.Key)); err != nil {
		t.Fatalf("the desktop's bundle: %v", err)
	}
	other, _ := newKey(t)
	for name, c := range map[string]struct {
		p    []byte
		from From
		want error
	}{
		"phone bundle on a key":    {enc(testBlock(t, PhoneID, phone.Reg, &phone.Key, false)), FromSession(a.id.pub), ErrNotListed},
		"desktop on the identity":  {enc(testBlock(t, desk.ID, desk.Reg, nil, false)), FromSession(a.id.pub), ErrNotListed},
		"desktop on another key":   {enc(testBlock(t, desk.ID, desk.Reg, &other, false)), FromSession(a.id.pub), ErrNotListed},
		"another registration id":  {enc(testBlock(t, desk.ID, desk.Reg+1, &desk.Key, false)), FromSession(a.id.pub), ErrNotListed},
		"a device not listed":      {enc(testBlock(t, desk.ID+1, desk.Reg, &desk.Key, false)), FromSession(a.id.pub), ErrNotListed},
		"from an invite":           {enc(testBlock(t, PhoneID, phone.Reg, nil, false)), FromInvite(), ErrSource},
		"from a stranger":          {enc(testBlock(t, PhoneID, phone.Reg, nil, false)), FromSession(other), ErrSource},
		"from a removed device":    {enc(testBlock(t, desk.ID, desk.Reg, &desk.Key, false)), FromSession(other), ErrSource},
		"junk from a good session": {[]byte("KDB1"), FromSession(a.id.pub), ErrMalformed},
	} {
		if _, err := k.TakeBundle(c.p, c.from); !errors.Is(err, c.want) {
			t.Errorf("%s: %v, want %v", name, err, c.want)
		}
	}
	// no list held yet: nothing to take a bundle for
	fresh := NewKnown(a.id.pub)
	if _, err := fresh.TakeBundle(enc(testBlock(t, PhoneID, phone.Reg, nil, false)), FromSession(a.id.pub)); !errors.Is(err, ErrNotListed) {
		t.Fatalf("before any list: %v", err)
	}
}
