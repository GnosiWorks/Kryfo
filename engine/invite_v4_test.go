// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"crypto/ed25519"
	"encoding/hex"
	"strings"
	"testing"
)

// the face key signs a face text and nothing else, and only for the main
// identity's key
func TestFaceSignsOnlyAFaceText(t *testing.T) {
	_, priv, _ := ed25519.GenerateKey(nil)
	mu.Lock()
	was := myEdPriv
	myEdPriv = priv
	mu.Unlock()
	identsMu.Lock()
	wasMain, hadMain := idents[mainIdent]
	identsMu.Unlock()
	var mainPriv, mainPub [32]byte
	mainPriv[0], mainPub = 1, [32]byte(bytes.Repeat([]byte{7}, 32))
	putIdentity(mainIdent, xid{priv: mainPriv, pub: mainPub})
	defer func() {
		mu.Lock()
		myEdPriv = was
		mu.Unlock()
		identsMu.Lock()
		if hadMain {
			idents[mainIdent] = wasMain
		} else {
			delete(idents, mainIdent)
		}
		identsMu.Unlock()
	}()
	ik := append([]byte{5}, mainPub[:]...)
	id := bytes.Repeat([]byte{9}, 16)
	msg := append(append(append([]byte{}, faceText...), ik...), id...)
	sig, err := faceSign(msg)
	if err != nil {
		t.Fatal(err)
	}
	if !ed25519.Verify(priv.Public().(ed25519.PublicKey), msg, sig) {
		t.Fatal("the face signature does not hold")
	}
	for _, bad := range [][]byte{
		msg[:len(msg)-1],
		append(append([]byte{}, msg...), 0),
		append([]byte("kryfo-face-v5:"), msg[len(faceText):]...),
		append(append(append([]byte{}, faceText...), append([]byte{8}, ik[1:]...)...), id...),
		// another identity's key, a Ci say
		append(append(append([]byte{}, faceText...), append([]byte{5}, bytes.Repeat([]byte{6}, 32)...)...), id...),
		[]byte("anything"),
	} {
		if _, err := faceSign(bad); err == nil {
			t.Fatalf("signed %q", bad)
		}
	}
}

// an invite's onion key gives the address tor gives the same key
func TestOnionOfKey(t *testing.T) {
	q, err := quietNew()
	if err != nil {
		t.Fatal(err)
	}
	ok, _ := hex.DecodeString(q.OnionKey)
	pub := ed25519.PrivateKey(ok).Public().(ed25519.PublicKey)
	got, err := onionOfKey(pub)
	if err != nil || got != q.Onion {
		t.Fatalf("%s, want %s (%v)", got, q.Onion, err)
	}
	if _, err := onionOfKey(pub[:31]); err == nil {
		t.Fatal("a short key taken")
	}
}

// a hello sealed by the sender opens on the invite's key, and its seal is
// the key the owner computes for that sender; any other identity's is not
func TestHelloSealIsTheOwnersCheck(t *testing.T) {
	a, b := fixedXid(t, v4Keys["a"]), fixedXid(t, v4Keys["b"])
	putIdentity(51, b)
	defer identDrop(51)
	fcSk := strings.Repeat("3c", 32)
	fcPk, err := fcKeyPk(fcSk)
	if err != nil {
		t.Fatal(err)
	}
	gw, err := helloWrap(a, b.pub, fcPk, "hello")
	if err != nil {
		t.Fatal(err)
	}
	got, sealPk, _, err := nip17UnwrapFirstContactWithStamped(fcSk, gw)
	if err != nil || got != "hello" {
		t.Fatalf("%q %v", got, err)
	}
	want, err := helloSealPkFor(51, hex.EncodeToString(a.pub[:]))
	if err != nil || sealPk != want {
		t.Fatalf("seal %s, owner wants %s (%v)", sealPk, want, err)
	}
	// another sender's seal is not the one the owner wants for a
	da := fixedXid(t, v4Keys["da"])
	other, _ := helloWrap(da, b.pub, fcPk, "hello")
	_, otherPk, _, _ := nip17UnwrapFirstContactWithStamped(fcSk, other)
	if otherPk == want {
		t.Fatal("another sender's seal passed")
	}
	// a seeded pair of the main identity seals its opener the same way;
	// its v3 pair as 0.5 does
	identsMu.Lock()
	was, had := idents[mainIdent]
	identsMu.Unlock()
	putIdentity(mainIdent, a)
	defer func() {
		identsMu.Lock()
		if had {
			idents[mainIdent] = was
		} else {
			delete(idents, mainIdent)
		}
		identsMu.Unlock()
	}()
	var s [32]byte
	copy(s[:], fixedSeed(3))
	seeded := convPair{ident: mainIdent, me: a, peer: b.pub, seed: &s}
	gw, err = seeded.wrapFirstContact(fcPk, "opener")
	if err != nil {
		t.Fatal(err)
	}
	if _, pk, _, _ := nip17UnwrapFirstContactWithStamped(fcSk, gw); pk != want {
		t.Fatalf("a seeded opener sealed with %s", pk)
	}
	classic := convPair{ident: mainIdent, me: a, peer: b.pub}
	gw, _ = classic.wrapFirstContact(fcPk, "v3")
	if _, pk, _, _ := nip17UnwrapFirstContactWithStamped(fcSk, gw); pk == want {
		t.Fatal("a v3 first contact sealed with the hello seal key")
	}
}

// a hello on the v3 first-contact address carries its seal key to the app;
// anything else goes as it came
func TestHelloLineOnTheV3Address(t *testing.T) {
	seal := strings.Repeat("ab", 32)
	if got := helloLine("S0hMMQEAAA", seal); got != "khl:"+seal+"|S0hMMQEAAA" {
		t.Fatal(got)
	}
	for _, c := range []string{"AwAAAA", "{\"halo_ctl\":1}", ""} {
		if got := helloLine(c, seal); got != c {
			t.Fatalf("%q became %q", c, got)
		}
	}
}

// a face text is signed by the ed key of the identity it names, even while
// a new identity comes in beside it
func TestFaceSignBesideANewIdentity(t *testing.T) {
	type pair struct {
		x  [32]byte
		ed ed25519.PrivateKey
	}
	var pairs [3]pair
	for i := range pairs {
		_, pairs[i].ed, _ = ed25519.GenerateKey(nil)
		pairs[i].x[0], pairs[i].x[1] = byte(i+1), 0x55
	}
	mu.Lock()
	was := myEdPriv
	mu.Unlock()
	identsMu.Lock()
	wasMain, hadMain := idents[mainIdent]
	identsMu.Unlock()
	t.Cleanup(func() {
		mu.Lock()
		myEdPriv = was
		mu.Unlock()
		identsMu.Lock()
		if hadMain {
			idents[mainIdent] = wasMain
		} else {
			delete(idents, mainIdent)
		}
		identsMu.Unlock()
	})
	use := func(p pair) {
		mu.Lock()
		myEdPriv = bytes.Clone(p.ed)
		putIdentity(mainIdent, xid{priv: [32]byte{1}, pub: p.x})
		mu.Unlock()
	}
	use(pairs[0])
	done := make(chan struct{})
	go func() {
		defer close(done)
		for i := range 20000 {
			use(pairs[i%len(pairs)])
		}
	}()
	id := bytes.Repeat([]byte{9}, 16)
	for n := 0; ; n++ {
		select {
		case <-done:
			return
		default:
		}
		p := pairs[n%len(pairs)]
		msg := append(append(append([]byte{}, faceText...), 5), p.x[:]...)
		msg = append(msg, id...)
		sig, err := faceSign(msg)
		if err != nil {
			continue
		}
		if !ed25519.Verify(p.ed.Public().(ed25519.PublicKey), msg, sig) {
			t.Fatal("a face text signed by another identity's key")
		}
	}
}
