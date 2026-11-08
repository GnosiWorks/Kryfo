// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"testing"
)

// a verifier that takes every signature, so the fuzzers reach past it
type yes struct{}

func (yes) Verify(Key, string, []byte, []byte) error { return nil }

func FuzzParseList(f *testing.F) {
	s := newShim()
	a := newAccount(f, s)
	f.Add(a.wire)
	a.link(f)
	a.link(f)
	f.Add(a.wire)
	f.Add(forge(vectorListF(f)))
	f.Add([]byte("KDL2"))
	f.Fuzz(func(t *testing.T, b []byte) {
		l, err := ParseList(b)
		if err != nil {
			return
		}
		// what reads, reads as itself and keeps every rule
		if !bytes.Equal(l.Wire(), b) || l.check() != nil || len(b) > MaxListSize {
			t.Fatalf("%x", b)
		}
		back, err := ParseList(l.Wire())
		if err != nil || !SameBody(back, l) {
			t.Fatal("does not read back")
		}
	})
}

// the kyber key stays fixed but for one changed byte, the rest is fuzzed
func FuzzParseBundle(f *testing.F) {
	k := fixedKey(f, 3)
	var kyber []byte
	for _, key := range []*Key{nil, &k} {
		for _, ec := range []bool{false, true} {
			b := testBlockF(f, key, ec)
			p, err := EncodeBundle(b)
			if err != nil {
				f.Fatal(err)
			}
			at := bytes.Index(p, b.Kyber)
			kyber = b.Kyber
			f.Add(p[:at], uint16(0), byte(0), p[at+KyberSize:])
		}
	}
	f.Fuzz(func(t *testing.T, head []byte, off uint16, val byte, tail []byte) {
		ky := bytes.Clone(kyber)
		ky[int(off)%len(ky)] ^= val
		p := append(append(bytes.Clone(head), ky...), tail...)
		b, err := ParseBundle(p, fixedKey(t, 0x11))
		if err != nil {
			return
		}
		again, err := EncodeBundle(b)
		if err != nil || !bytes.Equal(again, p) {
			t.Fatalf("%x", p)
		}
	})
}

// a contact fed any lists never goes back a version, and keeps only lists
// of its own identity
func FuzzKnown(f *testing.F) {
	s := newShim()
	a := newAccount(f, s)
	var seeds [][]byte
	for range 3 {
		a.link(f)
		seeds = append(seeds, a.wire)
	}
	f.Add(seeds[0], seeds[1], seeds[2], false)
	f.Add(seeds[2], seeds[0], seeds[1], true)
	id := a.id.pub
	f.Fuzz(func(t *testing.T, x, y, z []byte, invite bool) {
		k := newKnown(id)
		var last uint64
		for _, b := range [][]byte{x, y, z} {
			from := FromSession(id)
			if invite {
				from = FromInvite()
			}
			l, _, err := k.take(b, from, yes{})
			if err != nil {
				continue
			}
			if l.Identity != id || l.Version < last || (last != 0 && l.Version-last > VersionWindow) {
				t.Fatalf("version %d after %d", l.Version, last)
			}
			last = l.Version
		}
	})
}

func vectorListF(f *testing.F) *List {
	id := fixedKey(f, 0x11)
	return &List{
		Identity: id,
		Version:  7,
		Devices: []Entry{
			{ID: PhoneID, Key: id, Reg: 1, Phone: true},
			{ID: 9, Key: fixedKey(f, 0x22), Reg: 2, Answers: true},
		},
	}
}

func testBlockF(f *testing.F, key *Key, ec bool) *Block {
	b := &Block{
		Reg: 3, Device: PhoneID, SpkID: 1, Spk: fixedKey(f, 6),
		SpkSig:   bytes.Repeat([]byte{1}, SigSize),
		KyberID:  2,
		Kyber:    append([]byte{0x08}, bytes.Repeat([]byte{2}, KyberSize-1)...),
		KyberSig: bytes.Repeat([]byte{3}, SigSize),
	}
	if key != nil {
		b.Device = 2
		b.HasKey, b.Key = true, *key
	}
	if ec {
		b.HasEC, b.ECID, b.EC = true, 4, fixedKey(f, 7)
	}
	return b
}
