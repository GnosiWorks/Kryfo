// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"os"
	"testing"

	"filippo.io/edwards25519"
	"filippo.io/edwards25519/field"
)

// testdata/vectors.json holds every format vector as bytes, for any other
// parser of these formats to read. KRYFO_WRITE_VECTORS=1 writes it again.

type vector struct {
	Name string `json:"name"`
	Hex  string `json:"hex"`
	OK   bool   `json:"ok"`
}

type vectorFile struct {
	Keys []vector `json:"keys"`
	KDL2 []vector `json:"kdl2"`
	KDB1 []vector `json:"kdb1"`
}

// the edwards point for a u, sign 0
func pointOfU(t *testing.T, u []byte) *edwards25519.Point {
	t.Helper()
	var fu field.Element
	if _, err := fu.SetBytes(u); err != nil {
		t.Fatal(err)
	}
	one := new(field.Element).One()
	y := new(field.Element).Subtract(&fu, one)
	y.Multiply(y, new(field.Element).Invert(new(field.Element).Add(&fu, one)))
	p, err := new(edwards25519.Point).SetBytes(y.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	return p
}

// the first n u values from 2 up whose curve equation has no root
func twists(t *testing.T, n int) [][]byte {
	a := new(field.Element)
	ab := make([]byte, 32)
	ab[0], ab[1], ab[2] = 0x06, 0x6d, 0x07 // 486662
	if _, err := a.SetBytes(ab); err != nil {
		t.Fatal(err)
	}
	var out [][]byte
	for v := 2; len(out) < n; v++ {
		b := make([]byte, 32)
		b[0], b[1] = byte(v), byte(v>>8)
		u, _ := new(field.Element).SetBytes(b)
		u2 := new(field.Element).Square(u)
		rhs := new(field.Element).Multiply(u2, u)
		rhs.Add(rhs, new(field.Element).Multiply(a, u2))
		rhs.Add(rhs, u)
		if _, sq := new(field.Element).SqrtRatio(rhs, new(field.Element).One()); sq == 0 {
			out = append(out, b)
		}
	}
	return out
}

func buildVectors(t *testing.T) vectorFile {
	var vf vectorFile
	key := func(name string, b []byte, ok bool) {
		vf.Keys = append(vf.Keys, vector{name, hex.EncodeToString(b), ok})
	}
	for i, seed := range []byte{0x11, 0x22, 0x33} {
		k := fixedKey(t, seed)
		key("x25519 public "+string(rune('a'+i)), k[:], true)
	}
	order8 := uhex(t, "e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800")
	mixed := new(edwards25519.Point).Add(edwards25519.NewGeneratorPoint(), pointOfU(t, order8))
	p := bytes.Repeat([]byte{0xff}, 32)
	p[0], p[31] = 0xed, 0x7f
	minusOne := bytes.Clone(p)
	minusOne[0] = 0xec
	one := make([]byte, 32)
	one[0] = 1
	top := fixedKey(t, 0x11)
	top[32] |= 0x80
	key("generator", keyOf(uOf(edwards25519.NewGeneratorPoint())), true)
	key("top bit set", top[:], false)
	key("u is p", keyOf(p), false)
	key("u is p minus one", keyOf(minusOne), false)
	key("zero", keyOf(make([]byte, 32)), false)
	key("one", keyOf(one), false)
	key("order 8", keyOf(order8), false)
	key("generator plus order 8", keyOf(uOf(mixed)), false)
	k22 := fixedKey(t, 0x22)
	mixed22 := new(edwards25519.Point).Add(pointOfU(t, k22[1:]), pointOfU(t, order8))
	key("x25519 public b plus order 8", keyOf(uOf(mixed22)), false)
	for i, u := range twists(t, 3) {
		key("twist point "+string(rune('a'+i)), keyOf(u), false)
	}
	k11 := fixedKey(t, 0x11)
	key("type 0x06", append([]byte{0x06}, k11[1:]...), false)
	key("trailing byte", append(k11[:], 0), false)

	// a signature the shim's parser takes as a shape: zero is below the order
	sig := make([]byte, SigSize)
	list := func(name string, l *List, ok bool) {
		vf.KDL2 = append(vf.KDL2, vector{name, hex.EncodeToString(append(l.Body(), sig...)), ok})
	}
	id := fixedKey(t, 0x11)
	phone := Entry{ID: PhoneID, Key: id, Reg: 0x0102, Phone: true}
	desk := Entry{ID: 0x2a, Key: fixedKey(t, 0x22), Reg: 0x3fff}
	mk := func(v uint64, es ...Entry) *List { return &List{Identity: id, Version: v, Devices: es} }
	list("phone alone", mk(1, phone), true)
	list("phone and desktop", mk(0x00aabbccddeeff01, phone, desk), true)
	ans := desk
	ans.Answers = true
	list("pool list, desktop answers", mk(5, phone, ans), true)
	six := mk(1<<56-1, phone)
	for i := range 5 {
		six.Devices = append(six.Devices, Entry{ID: uint8(10 + i), Key: fixedKey(t, byte(0x40+i)), Reg: uint32(100 + i)})
	}
	list("six devices, the largest list", six, true)
	list("the last version", mk(MaxVersion-1, phone, desk), true)
	list("version 2^63", mk(MaxVersion, phone, desk), false)
	list("version 2^64 - 1", mk(1<<64-1, phone, desk), false)
	list("phone not device 1", mk(1, Entry{ID: 2, Key: id, Reg: 1, Phone: true}), false)
	list("no phone", mk(1, desk), false)
	two := desk
	two.Phone = true
	list("two phones", mk(1, phone, two), false)
	pa := phone
	pa.Answers = true
	list("the phone answers", mk(1, pa, desk), false)
	list("unsorted", mk(1, phone, Entry{ID: 0x50, Key: fixedKey(t, 0x33), Reg: 1}, desk), false)
	list("same key twice", mk(1, phone, desk, Entry{ID: 0x50, Key: desk.Key, Reg: 1}), false)
	ri := desk
	ri.Reg = 0
	list("registration id 0", mk(1, phone, ri), false)
	di := desk
	di.ID = 128
	list("device id 128", mk(1, phone, di), false)
	tb := desk
	tb.Key[32] |= 0x80
	list("device key top bit", mk(1, phone, tb), false)
	seven := clone(six)
	seven.Devices = append(seven.Devices, Entry{ID: 20, Key: fixedKey(t, 0x50), Reg: 9})
	list("seven devices", seven, false)
	good := append(mk(3, phone, desk).Body(), sig...)
	raw := func(name string, b []byte) { vf.KDL2 = append(vf.KDL2, vector{name, hex.EncodeToString(b), false}) }
	raw("trailing byte", append(bytes.Clone(good), 0))
	raw("one byte short", good[:len(good)-1])
	uf := bytes.Clone(good)
	uf[listHead+entrySize-1] = 0x05
	raw("unknown flag", uf)
	cnt := bytes.Clone(good)
	cnt[listHead-1] = 1
	raw("count below the entries", cnt)
	raw("magic KDL1", append([]byte("KDL1"), good[4:]...))

	bundle := func(name string, b []byte, ok bool) {
		vf.KDB1 = append(vf.KDB1, vector{name, hex.EncodeToString(b), ok})
	}
	blk := &Block{
		Reg: 0x01020304, Device: PhoneID, SpkID: 7, Spk: fixedKey(t, 0x61),
		SpkSig: bytes.Repeat([]byte{0x5a}, SigSize), KyberID: 8,
		Kyber:    append([]byte{0x08}, bytes.Repeat([]byte{0x33}, KyberSize-1)...),
		KyberSig: bytes.Repeat([]byte{0x6b}, SigSize),
	}
	enc := func(b *Block) []byte { return append(append([]byte(bundleMagic), bundleVersion), b.Encode()...) }
	bundle("on the identity", enc(blk), true)
	wk := *blk
	wk.Device, wk.HasKey, wk.Key = 0x2a, true, fixedKey(t, 0x22)
	bundle("on a device key", enc(&wk), true)
	we := wk
	we.HasEC, we.ECID, we.EC = true, 9, fixedKey(t, 0x62)
	bundle("on a device key with an ec prekey", enc(&we), true)
	v2 := enc(blk)
	v2[4] = 2
	bundle("version 2", v2, false)
	bundle("trailing byte", append(enc(blk), 0), false)
	kt := *blk
	kt.Kyber = append([]byte{0x05}, blk.Kyber[1:]...)
	bundle("kyber type 0x05", enc(&kt), false)
	ks := *blk
	ks.Kyber = blk.Kyber[:KyberSize-1]
	bundle("kyber one byte short", enc(&ks), false)
	fl := enc(blk)
	fl[10] = 4
	bundle("unknown block flag", fl, false)
	d0 := *blk
	d0.Device = 0
	bundle("device id 0", enc(&d0), false)
	// the bundles below read against the identity of key 0x11
	ki := wk
	ki.Key = fixedKey(t, 0x11)
	bundle("key is the identity", enc(&ki), false)
	es := we
	es.EC = es.Spk
	bundle("ec prekey is the spk", enc(&es), false)
	kp := wk
	kp.Device = PhoneID
	bundle("a key on device 1", enc(&kp), false)
	nk := *blk
	nk.Device = 0x2a
	bundle("no key on device 0x2a", enc(&nk), false)
	return vf
}

func TestVectors(t *testing.T) {
	vf := buildVectors(t)
	for _, v := range vf.Keys {
		b, _ := hex.DecodeString(v.Hex)
		if _, err := ParseKey(b); (err == nil) != v.OK {
			t.Errorf("key %s: %v", v.Name, err)
		}
	}
	for _, v := range vf.KDL2 {
		b, _ := hex.DecodeString(v.Hex)
		if _, err := ParseList(b); (err == nil) != v.OK {
			t.Errorf("kdl2 %s: %v", v.Name, err)
		}
	}
	for _, v := range vf.KDB1 {
		b, _ := hex.DecodeString(v.Hex)
		if _, err := ParseBundle(b, fixedKey(t, 0x11)); (err == nil) != v.OK {
			t.Errorf("kdb1 %s: %v", v.Name, err)
		}
	}
	out, err := json.MarshalIndent(vf, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	out = append(out, '\n')
	const path = "testdata/vectors.json"
	if os.Getenv("KRYFO_WRITE_VECTORS") == "1" {
		if err := os.WriteFile(path, out, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	have, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(have, out) {
		t.Fatal("testdata/vectors.json is not what the formats give")
	}
}
