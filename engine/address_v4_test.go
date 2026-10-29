// SPDX-License-Identifier: GPL-3.0-or-later
package main

// v4 conversation addresses (identity v4 3.6, section 16 item 6): fixed
// keys, pinned outputs in testdata/address_v4.json, and the equalities
// and inequalities R1 asks for. KRYFO_WRITE_VECTORS=1 writes the file
// again; it is checked in and never written by a normal run

import (
	"encoding/hex"
	"encoding/json"
	"os"
	"testing"

	nostr2 "github.com/nbd-wtf/go-nostr"
)

const v4VectorFile = "testdata/address_v4.json"

func fixedXid(t *testing.T, privHex string) xid {
	t.Helper()
	id, err := xidFromPrivHex(privHex)
	if err != nil {
		t.Fatal(err)
	}
	return id
}

func fixedSeed(b byte) []byte {
	s := make([]byte, 32)
	for i := range s {
		s[i] = b + byte(i)
	}
	return s
}

// the keys of the vectors: a and b are phones (device key = identity
// key); da and db are devices of a and b with keys of their own
var v4Keys = map[string]string{
	"a":  "7f449a046d3c538ad7197d4ac149a2c2d12ce95128fdf9223badf3ff3c1e0f22",
	"b":  "bad448247defb16dd9ea37925e64113012d11164e78391a016c826671567feec",
	"da": "a4eb1450f7af275fbab5dd53f86f57759aa609337c8c21f1afc0447b47bdb335",
	"db": "2520d613ac15e8fda4fcb29362282656fe2af31d94e199051d2c65676e665395",
}

type v4Vectors struct {
	Keys map[string]string `json:"keys"`
	Seed string            `json:"seed"`
	Out  map[string]string `json:"out"`
}

func v4Outputs(t *testing.T) map[string]string {
	t.Helper()
	a, b := fixedXid(t, v4Keys["a"]), fixedXid(t, v4Keys["b"])
	da, db := fixedXid(t, v4Keys["da"]), fixedXid(t, v4Keys["db"])
	s, s2 := fixedSeed(1), fixedSeed(2)
	ab, ba := phonePair(a, b.pub, s), phonePair(b, a.pub, s)
	out := map[string]string{}
	pk := func(name string, sk, p string, err error) {
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		out[name] = p
		if name == "a rcv by a" || name == "hello a to b" {
			out[name+" sk"] = sk
		}
	}
	sk, p, err := ab.role(roleRcv, true)
	pk("a rcv by a", sk, p, err)
	_, p, err = ba.role(roleRcv, false)
	pk("a rcv by b", "", p, err)
	_, p, err = ba.role(roleRcv, true)
	pk("b rcv by b", "", p, err)
	_, p, err = ab.role(roleSnd, true)
	pk("a seal by a", "", p, err)
	_, p, err = ba.role(roleSnd, false)
	pk("a seal by b", "", p, err)
	_, p, err = ba.role(roleSnd, true)
	pk("b seal by b", "", p, err)
	_, p, err = nip17RcvAddressAs(a, b.pub)
	pk("a rcv v3", "", p, err)
	_, p, err = phonePair(a, b.pub, s2).role(roleRcv, true)
	pk("a rcv other seed", "", p, err)
	dev := v4Pair{me: da, their: db.pub, myIdent: a.pub, theirIdnt: b.pub, seed: s}
	_, p, err = dev.role(roleRcv, true)
	pk("da rcv by da", "", p, err)
	devB := v4Pair{me: db, their: da.pub, myIdent: b.pub, theirIdnt: a.pub, seed: s}
	_, p, err = devB.role(roleRcv, false)
	pk("da rcv by db", "", p, err)
	sk, p, err = v4HelloSealKey(a, b.pub)
	pk("hello a to b", sk, p, err)
	p, err = v4HelloSealPk(b, a.pub)
	pk("hello a to b by b", "", p, err)
	return out
}

func TestAddressV4Vectors(t *testing.T) {
	got := v4Outputs(t)
	if os.Getenv("KRYFO_WRITE_VECTORS") == "1" {
		b, _ := json.MarshalIndent(v4Vectors{Keys: v4Keys, Seed: hex.EncodeToString(fixedSeed(1)), Out: got}, "", "  ")
		if err := os.WriteFile(v4VectorFile, append(b, '\n'), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	raw, err := os.ReadFile(v4VectorFile)
	if err != nil {
		t.Fatal(err)
	}
	var want v4Vectors
	if err := json.Unmarshal(raw, &want); err != nil {
		t.Fatal(err)
	}
	if want.Seed != hex.EncodeToString(fixedSeed(1)) {
		t.Fatal("the vectors' seed moved")
	}
	for k, v := range v4Keys {
		if want.Keys[k] != v {
			t.Fatalf("the vectors' key %s moved", k)
		}
	}
	if len(want.Out) != len(got) {
		t.Fatalf("%d outputs pinned, %d made", len(want.Out), len(got))
	}
	for k, v := range want.Out {
		if got[k] != v {
			t.Errorf("%s: %s, pinned %s", k, got[k], v)
		}
	}
	eq := func(x, y string) {
		if got[x] != got[y] {
			t.Errorf("%s and %s differ", x, y)
		}
	}
	ne := func(x, y string) {
		if got[x] == got[y] {
			t.Errorf("%s and %s are the same", x, y)
		}
	}
	// R1: the owner is in the label, so a's and b's differ, and both
	// sides compute each
	eq("a rcv by a", "a rcv by b")
	ne("a rcv by a", "b rcv by b")
	eq("a seal by a", "a seal by b")
	ne("a seal by a", "b seal by b")
	ne("a rcv by a", "a seal by a")
	ne("a rcv by a", "a rcv v3")
	ne("a rcv by a", "a rcv other seed")
	eq("da rcv by da", "da rcv by db")
	ne("da rcv by da", "a rcv by a")
	eq("hello a to b", "hello a to b by b")
	ne("hello a to b", "a seal by a")
	ne("hello a to b", "a rcv by a")
}

// a v4 wrap opens on the pair's other side only: not without the seed,
// not with another, not on the v3 addresses of the same keys
func TestAddressV4WrapOpensOnItsPair(t *testing.T) {
	a, b := fixedXid(t, v4Keys["a"]), fixedXid(t, v4Keys["b"])
	s := fixedSeed(1)
	gw, err := v4Wrap(phonePair(a, b.pub, s), "to b")
	if err != nil {
		t.Fatal(err)
	}
	got, _, err := v4UnwrapStamped(phonePair(b, a.pub, s), gw)
	if err != nil || got != "to b" {
		t.Fatalf("b: %q %v", got, err)
	}
	if _, _, err := v4UnwrapStamped(phonePair(b, a.pub, fixedSeed(2)), gw); err == nil {
		t.Fatal("opened under another seed")
	}
	if _, _, err := nip17UnwrapAsStamped(b, a.pub, gw); err == nil {
		t.Fatal("opened on the v3 addresses")
	}
	if _, _, err := v4UnwrapStamped(phonePair(a, b.pub, s), gw); err == nil {
		t.Fatal("opened by its sender")
	}
	if _, err := v4Wrap(phonePair(a, b.pub, nil), "x"); err == nil {
		t.Fatal("a v4 wrap without a seed")
	}
	v3, err := nip17WrapAs(a, b.pub, "v3")
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := v4UnwrapStamped(phonePair(b, a.pub, s), v3); err == nil {
		t.Fatal("a v3 wrap opened on the v4 pair")
	}
}

// the engine's own pair: a seed put for the pair moves its addresses to
// v4, for that identity and peer only
func TestPairSeedMovesThePairOnly(t *testing.T) {
	a, b := fixedXid(t, v4Keys["a"]), fixedXid(t, v4Keys["b"])
	putIdentity(41, a)
	defer identDrop(41)
	var s [32]byte
	copy(s[:], fixedSeed(1))
	before, err := pairOf(41, b.pub)
	if err != nil {
		t.Fatal(err)
	}
	_, v3, _ := before.rcvAddress()
	if err := putPairSeed(41, b.pub, s); err != nil {
		t.Fatal(err)
	}
	after, _ := pairOf(41, b.pub)
	_, v4, _ := after.rcvAddress()
	_, want, _ := v4RcvAddress(phonePair(a, b.pub, s[:]))
	if v4 != want || v4 == v3 {
		t.Fatalf("v4 %s, want %s (v3 %s)", v4, want, v3)
	}
	var other [32]byte
	if err := putPairSeed(41, b.pub, other); err == nil {
		t.Fatal("a pair took a second seed")
	}
	gw, err := after.wrap("seeded")
	if err != nil {
		t.Fatal(err)
	}
	got, _, err := v4UnwrapStamped(phonePair(b, a.pub, s[:]), gw)
	if err != nil || got != "seeded" {
		t.Fatalf("%q %v", got, err)
	}
	if _, ok := pairSeed(mainIdent, b.pub); ok {
		t.Fatal("the seed reached another identity")
	}
}

// a seal from a non-main identity to a first-contact address is signed
// with its hello seal key, which the answering side derives
func TestFirstContactSealOfAnotherIdentity(t *testing.T) {
	a, b := fixedXid(t, v4Keys["a"]), fixedXid(t, v4Keys["b"])
	putIdentity(42, a)
	defer identDrop(42)
	fcSk := hex.EncodeToString(fixedSeed(9))
	fcPk, err := fcKeyPk(fcSk)
	if err != nil {
		t.Fatal(err)
	}
	c, _ := pairOf(42, b.pub)
	gw, err := c.wrapFirstContact(fcPk, "hello")
	if err != nil {
		t.Fatal(err)
	}
	got, sealPk, err := nip17UnwrapFirstContactWith(fcSk, gw)
	if err != nil || got != "hello" {
		t.Fatalf("%q %v", got, err)
	}
	want, _ := v4HelloSealPk(b, a.pub)
	if sealPk != want {
		t.Fatalf("sealed by %s, want the hello seal key %s", sealPk, want)
	}
}

// every wrap the phone makes keeps its seal, so a late top-up goes as a
// fresh wrap whatever the pair: v3, v4 and both first contacts
func TestEveryWrapKeepsItsSeal(t *testing.T) {
	a, b := fixedXid(t, v4Keys["a"]), fixedXid(t, v4Keys["b"])
	putIdentity(43, a)
	defer identDrop(43)
	fcPk, err := fcKeyPk(hex.EncodeToString(fixedSeed(9)))
	if err != nil {
		t.Fatal(err)
	}
	v3, _ := pairOf(43, b.pub)
	var s [32]byte
	copy(s[:], fixedSeed(1))
	v4 := v3
	v4.seed = &s
	main := convPair{ident: mainIdent, me: a, peer: b.pub}
	for name, wrap := range map[string]func() (nostr2.Event, error){
		"v3":                  func() (nostr2.Event, error) { return v3.wrap("x") },
		"v4":                  func() (nostr2.Event, error) { return v4.wrap("x") },
		"main first contact":  func() (nostr2.Event, error) { return main.wrapFirstContact(fcPk, "x") },
		"other first contact": func() (nostr2.Event, error) { return v3.wrapFirstContact(fcPk, "x") },
	} {
		gw, err := wrap()
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if _, ok := keptSealOf(gw.ID); !ok {
			t.Fatalf("%s: no seal kept", name)
		}
	}
}
