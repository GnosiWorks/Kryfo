// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/rand"
	"encoding/hex"
	"testing"

	"filippo.io/edwards25519"
	"filippo.io/edwards25519/field"
)

func keyOf(u []byte) []byte { return append([]byte{0x05}, u...) }

func uhex(t *testing.T, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(s)
	if err != nil || len(b) != 32 {
		t.Fatalf("bad hex %q", s)
	}
	return b
}

// montgomery u of an edwards point: (1 + y) / (1 - y)
func uOf(p *edwards25519.Point) []byte {
	b := p.Bytes()
	b[31] &= 0x7f
	var y field.Element
	if _, err := y.SetBytes(b); err != nil {
		panic(err)
	}
	one := new(field.Element).One()
	num := new(field.Element).Add(one, &y)
	den := new(field.Element).Subtract(one, &y)
	return new(field.Element).Multiply(num, new(field.Element).Invert(den)).Bytes()
}

// a point of small order: the torsion part of a random point
func torsionPoint(t *testing.T) *edwards25519.Point {
	t.Helper()
	for range 1000 {
		b := make([]byte, 32)
		rand.Read(b)
		r, err := new(edwards25519.Point).SetBytes(b)
		if err != nil {
			continue
		}
		pl := new(edwards25519.Point).MultByCofactor(r)
		pl.ScalarMult(invEight, pl)
		tp := new(edwards25519.Point).Subtract(r, pl)
		// order 8: [4]T is not the identity
		t4 := new(edwards25519.Point).Add(tp, tp)
		t4.Add(t4, t4)
		if t4.Equal(edwards25519.NewIdentityPoint()) == 0 {
			return tp
		}
	}
	t.Fatal("no torsion point found")
	return nil
}

func TestKeysFromX25519AreCanonical(t *testing.T) {
	for range 200 {
		k, _ := newKey(t)
		if _, err := ParseKey(k[:]); err != nil {
			t.Fatalf("%x: %v", k, err)
		}
	}
}

func TestNonCanonicalKeysAreRefused(t *testing.T) {
	good, _ := newKey(t)
	p := append([]byte{0xed}, make([]byte, 31)...)
	for i := 1; i < 31; i++ {
		p[i] = 0xff
	}
	p[31] = 0x7f
	above := append([]byte(nil), p...)
	above[0] = 0xf0
	minusOne := append([]byte(nil), p...)
	minusOne[0] = 0xec
	top := append([]byte(nil), good[1:]...)
	top[31] |= 0x80
	one := make([]byte, 32)
	one[0] = 1
	tp := torsionPoint(t)
	mixed := new(edwards25519.Point).Add(edwards25519.NewGeneratorPoint(), tp)
	cases := map[string][]byte{
		"short":         good[:32],
		"long":          append(append([]byte(nil), good[:]...), 0),
		"type":          append([]byte{0x06}, good[1:]...),
		"top bit":       keyOf(top),
		"u is p":        keyOf(p),
		"u above p":     keyOf(above),
		"u is -1":       keyOf(minusOne),
		"zero":          keyOf(make([]byte, 32)),
		"one":           keyOf(one),
		"order 8 a":     keyOf(uhex(t, "e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800")),
		"order 8 b":     keyOf(uhex(t, "5f9c95bca3508c24b1d0b1559c83ef5b04445cc4581c8e86d8224eddd09f1157")),
		"torsion":       keyOf(uOf(tp)),
		"mixed":         keyOf(uOf(mixed)),
		"twist":         keyOf(twistU(t)),
		"empty":         nil,
		"type and zero": {0x05},
	}
	for name, b := range cases {
		if _, err := ParseKey(b); err == nil {
			t.Errorf("%s: taken", name)
		}
	}
	// the generator itself is a good key
	if _, err := ParseKey(keyOf(uOf(edwards25519.NewGeneratorPoint()))); err != nil {
		t.Fatalf("generator: %v", err)
	}
	if u := uOf(edwards25519.NewGeneratorPoint()); u[0] != 9 {
		t.Fatalf("generator u %x", u)
	}
}

// a u whose curve equation has no square root: a point of the twist
func twistU(t *testing.T) []byte {
	t.Helper()
	a := new(field.Element)
	ab := make([]byte, 32)
	ab[0], ab[1], ab[2] = 0x06, 0x6d, 0x07 // 486662
	if _, err := a.SetBytes(ab); err != nil {
		t.Fatal(err)
	}
	for range 1000 {
		b := make([]byte, 32)
		rand.Read(b)
		b[31] &= 0x3f
		u, _ := new(field.Element).SetBytes(b)
		u2 := new(field.Element).Square(u)
		rhs := new(field.Element).Multiply(u2, u)
		rhs.Add(rhs, new(field.Element).Multiply(a, u2))
		rhs.Add(rhs, u)
		if _, sq := new(field.Element).SqrtRatio(rhs, new(field.Element).One()); sq == 0 {
			return u.Bytes()
		}
	}
	t.Fatal("no twist point found")
	return nil
}

// the same 20 digits key_number.dart gives for this key
func TestKeyNumberMatchesTheApp(t *testing.T) {
	var k Key
	k[0] = 0x05
	for i := range 32 {
		k[1+i] = byte(i)
	}
	if got := KeyNumber(k); got != "10009 47272 67828 22347" {
		t.Fatalf("key number %q", got)
	}
}
