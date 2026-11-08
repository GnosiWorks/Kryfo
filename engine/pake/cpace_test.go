// SPDX-License-Identifier: GPL-3.0-or-later
package pake

import (
	"bytes"
	"crypto/sha512"
	"encoding/hex"
	"math/big"
	"math/rand/v2"
	"strings"
	"testing"

	"filippo.io/edwards25519/field"
	"gitlab.com/yawning/edwards25519-extra/elligator2"
)

// vectors from draft-irtf-cfrg-cpace-21, appendix a.1, a.3 and b.1

func unhex(t testing.TB, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(strings.Join(strings.Fields(s), ""))
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestPrependLenVectors(t *testing.T) {
	r127 := make([]byte, 127)
	r128 := make([]byte, 128)
	for i := range r128 {
		r128[i] = byte(i)
		if i < 127 {
			r127[i] = byte(i)
		}
	}
	for _, c := range []struct {
		in   []byte
		want string
	}{
		{nil, "00"},
		{[]byte("1234"), "0431323334"},
		{r127, "7f" + hex.EncodeToString(r127)},
		{r128, "8001" + hex.EncodeToString(r128)},
	} {
		got := prependLen(nil, c.in)
		if hex.EncodeToString(got) != c.want {
			t.Fatalf("prepend_len(%d bytes) = %x", len(c.in), got)
		}
		if lebLen(c.in) != len(got) {
			t.Fatalf("lebLen(%d bytes) = %d, want %d", len(c.in), lebLen(c.in), len(got))
		}
	}
	got := lvCat(nil, []byte("1234"), []byte("5"), nil, []byte("678"))
	if hex.EncodeToString(got) != "043132333401350003363738" {
		t.Fatalf("lv_cat = %x", got)
	}
}

func TestTranscriptIRVectors(t *testing.T) {
	for _, c := range []struct{ ya, ada, yb, adb, want string }{
		{"123", "PartyA", "234", "PartyB", "03313233065061727479410332333406506172747942"},
		{"3456", "PartyA", "2345", "PartyB", "043334353606506172747941043233343506506172747942"},
	} {
		got := lvCat(nil, []byte(c.ya), []byte(c.ada), []byte(c.yb), []byte(c.adb))
		if hex.EncodeToString(got) != c.want {
			t.Fatalf("transcript_ir = %x", got)
		}
	}
}

var (
	vPRS = []byte("Password")
	vCI  = "0b415f696e69746961746f720b425f726573706f6e646572"
	vSid = "7e4b4791d6a8ef019b936c79fb7f2c57"
)

func TestGeneratorVector(t *testing.T) {
	ci, sid := unhex(t, vCI), unhex(t, vSid)
	gs := generatorString(vPRS, ci, sid)
	want := unhex(t, `0843506163653235350850617373776f72646d000000000000000000
		00000000000000000000000000000000000000000000000000000000
		00000000000000000000000000000000000000000000000000000000
		00000000000000000000000000000000000000000000000000000000
		00000000000000000000000000000000180b415f696e69746961746f
		720b425f726573706f6e646572107e4b4791d6a8ef019b936c79fb7f
		2c57`)
	if !bytes.Equal(gs, want) {
		t.Fatalf("generator string\n got %x\nwant %x", gs, want)
	}
	h := sha512.Sum512(gs)
	if hex.EncodeToString(h[:32]) != "03998087bdb1a2617bbe25ef5a7c18cd4f84f902328701790958755ee4aed1d3" {
		t.Fatalf("hash = %x", h[:32])
	}
	g := generator(vPRS, ci, sid)
	if hex.EncodeToString(g[:]) != "d04bf6d41f6a289632a2e929fa29bebd51092512a7829fdde7d314b62f05a73f" {
		t.Fatalf("g = %x", g)
	}
}

func TestRunVectors(t *testing.T) {
	ci, sid := unhex(t, vCI), unhex(t, vSid)
	g := generator(vPRS, ci, sid)
	var ya, yb [ScalarSize]byte
	copy(ya[:], unhex(t, "21b4f4bd9e64ed355c3eb676a28ebedaf6d8f17bdc365995b319097153044080"))
	copy(yb[:], unhex(t, "848b0779ff415f0af4ea14df9dd1d3c29ac41d836c7808896c4eba19c51ac40a"))
	Ya, err := scalarMult(&ya, g[:])
	if err != nil || hex.EncodeToString(Ya[:]) != "1d13c89278cdadd826f6d8d7f887701430f8380ddc17611cdd6dc989ce0c9f32" {
		t.Fatalf("Ya = %x %v", Ya, err)
	}
	Yb, err := scalarMult(&yb, g[:])
	if err != nil || hex.EncodeToString(Yb[:]) != "248cccf6d5cdc3646f0ad593f9e6cef4e69d4945f8372e623512ecea32185623" {
		t.Fatalf("Yb = %x %v", Yb, err)
	}
	const wantK = "5b067effbdc0b2a0e1d907b21ebb25cfedb96a852179a847c37e43ee71322c6b"
	ka, err := scalarMult(&ya, Yb[:])
	if err != nil || hex.EncodeToString(ka[:]) != wantK {
		t.Fatalf("K at A = %x %v", ka, err)
	}
	kb, err := scalarMult(&yb, Ya[:])
	if err != nil || hex.EncodeToString(kb[:]) != wantK {
		t.Fatalf("K at B = %x %v", kb, err)
	}
	got := isk(sid, ka[:], Ya[:], []byte("ADa"), Yb[:], []byte("ADb"))
	want := `6e19b875f7a561d6b3ca3dbb9ef42ac55de3e717881018204b8922b4
		d5e53bb2aa82c300bea7b65d2b671da71922ddf6472301b79bc270ad
		fa8bf413285f2263`
	if !bytes.Equal(got[:], unhex(t, want)) {
		t.Fatalf("ISK_IR = %x", got)
	}
}

func TestLowOrderVectors(t *testing.T) {
	var s [ScalarSize]byte
	copy(s[:], unhex(t, "af46e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449aff"))
	for i, c := range []struct{ u, q string }{
		{"0000000000000000000000000000000000000000000000000000000000000000", ""},
		{"0100000000000000000000000000000000000000000000000000000000000000", ""},
		{"ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f", ""},
		{"e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800", ""},
		{"5f9c95bca3508c24b1d0b1559c83ef5b04445cc4581c8e86d8224eddd09f1157", ""},
		{"edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f", ""},
		{"daffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", "d8e2c776bbacd510d09fd9278b7edcd25fc5ae9adfba3b6e040e8d3b71b21806"},
		{"eeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f", ""},
		{"dbffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", "c85c655ebe8be44ba9c0ffde69f2fe10194458d137f09bbff725ce58803cdb38"},
		{"d9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", "db64dafa9b8fdd136914e61461935fe92aa372cb056314e1231bc4ec12417456"},
		{"cdeb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b880", "e062dcd5376d58297be2618c7498f55baa07d7e03184e8aada20bca28888bf7a"},
		{"4c9c95bca3508c24b1d0b1559c83ef5b04445cc4581c8e86d8224eddd09f11d7", "993c6ad11c4c29da9a56f7691fd0ff8d732e49de6250b6c2e80003ff4629a175"},
	} {
		q, err := scalarMult(&s, unhex(t, c.u))
		if c.q == "" {
			if err != ErrLowOrder {
				t.Fatalf("u%x: got %x, want the low order refusal", i, q)
			}
			continue
		}
		if err != nil || hex.EncodeToString(q[:]) != c.q {
			t.Fatalf("u%x: got %x %v, want %s", i, q, err, c.q)
		}
	}
}

// the draft's appendix a.5 elligator2, in big integers, against the
// vendored map
func refElligator2(r *big.Int) *big.Int {
	p := new(big.Int).Sub(new(big.Int).Lsh(big.NewInt(1), 255), big.NewInt(19))
	a := big.NewInt(486662)
	z := big.NewInt(2)
	mod := func(x *big.Int) *big.Int { return x.Mod(x, p) }
	// v = -A / (1 + z r^2)
	den := mod(new(big.Int).Add(big.NewInt(1), new(big.Int).Mul(z, new(big.Int).Mul(r, r))))
	v := mod(new(big.Int).Neg(new(big.Int).Mul(a, new(big.Int).ModInverse(den, p))))
	// epsilon = (v^3 + A v^2 + v)^((p-1)/2)
	v2 := mod(new(big.Int).Mul(v, v))
	f := mod(new(big.Int).Add(new(big.Int).Add(new(big.Int).Mul(v2, v), new(big.Int).Mul(a, v2)), v))
	e := new(big.Int).Exp(f, new(big.Int).Rsh(new(big.Int).Sub(p, big.NewInt(1)), 1), p)
	// x = epsilon v - (1 - epsilon) A / 2
	half := new(big.Int).ModInverse(big.NewInt(2), p)
	x := new(big.Int).Mul(e, v)
	x.Sub(x, new(big.Int).Mul(new(big.Int).Sub(big.NewInt(1), e), new(big.Int).Mul(a, half)))
	return mod(x)
}

func leToInt(b []byte) *big.Int {
	be := bytes.Clone(b)
	for i, j := 0, len(be)-1; i < j; i, j = i+1, j-1 {
		be[i], be[j] = be[j], be[i]
	}
	return new(big.Int).SetBytes(be)
}

func TestElligator2AgainstReference(t *testing.T) {
	rng := rand.New(rand.NewPCG(1, 2))
	p := new(big.Int).Sub(new(big.Int).Lsh(big.NewInt(1), 255), big.NewInt(19))
	in := make([][]byte, 0, 2005)
	for range 2000 {
		b := make([]byte, 32)
		for i := range b {
			b[i] = byte(rng.Uint32())
		}
		in = append(in, b)
	}
	// edges: zero, one, p - 1, p (non-canonical zero), bit 255 set
	pm1 := make([]byte, 32)
	pm1[0], pm1[31] = 0xec, 0x7f
	for i := 1; i < 31; i++ {
		pm1[i] = 0xff
	}
	pp := bytes.Clone(pm1)
	pp[0] = 0xed
	one := make([]byte, 32)
	one[0] = 1
	in = append(in, make([]byte, 32), one, pm1, pp, bytes.Repeat([]byte{0xff}, 32))
	for _, b := range in {
		r, err := new(field.Element).SetBytes(b)
		if err != nil {
			t.Fatal(err)
		}
		u, _ := elligator2.MontgomeryFlavor(r)
		m := bytes.Clone(b)
		m[31] &= 0x7f
		want := refElligator2(new(big.Int).Mod(leToInt(m), p))
		if leToInt(u.Bytes()).Cmp(want) != 0 {
			t.Fatalf("elligator2(%x) = %x, reference %x", b, u.Bytes(), want)
		}
	}
}
