// SPDX-License-Identifier: GPL-3.0-or-later
package main

// proves the first-contact path before any of it is wired to a phone. the
// dangerous failure here is silent: if the two sides derive the address even
// slightly differently, nothing arrives and nothing logs an error.

import (
	"crypto/rand"
	"testing"

	"golang.org/x/crypto/curve25519"
)

func newIdentity(t *testing.T) (priv, pub [32]byte) {
	t.Helper()
	if _, err := rand.Read(priv[:]); err != nil {
		t.Fatal(err)
	}
	priv[0] &= 248
	priv[31] &= 127
	priv[31] |= 64
	out, err := curve25519.X25519(priv[:], curve25519.Basepoint)
	if err != nil {
		t.Fatal(err)
	}
	copy(pub[:], out)
	return
}

func useIdentity(priv, pub [32]byte) func() {
	oldPriv, oldPub := myXPriv, myXPub
	myXPriv, myXPub = priv, pub
	return func() { myXPriv, myXPub = oldPriv, oldPub }
}

// the address must not move between runs, or a restart loses every pending
// introduction.
func TestFcAddressIsStable(t *testing.T) {
	priv, _ := newIdentity(t)
	_, pk1, err := fcKeysFrom(priv, 0)
	if err != nil {
		t.Fatal(err)
	}
	_, pk2, err := fcKeysFrom(priv, 0)
	if err != nil {
		t.Fatal(err)
	}
	if pk1 != pk2 {
		t.Fatalf("address moved between calls: %s vs %s", pk1, pk2)
	}
}

// bumping the counter has to actually retire the old invite.
func TestFcCounterRotates(t *testing.T) {
	priv, _ := newIdentity(t)
	_, pk0, _ := fcKeysFrom(priv, 0)
	_, pk1, _ := fcKeysFrom(priv, 1)
	if pk0 == pk1 {
		t.Fatal("counter did not change the address")
	}
}

// two identities must not collide.
func TestFcAddressesDiffer(t *testing.T) {
	a, _ := newIdentity(t)
	b, _ := newIdentity(t)
	_, pkA, _ := fcKeysFrom(a, 0)
	_, pkB, _ := fcKeysFrom(b, 0)
	if pkA == pkB {
		t.Fatal("two identities derived the same address")
	}
}

// the whole point: a stranger who has only our invite can reach us, and we
// can read it without knowing anything about them first.
func TestFirstContactRoundTrip(t *testing.T) {
	bobPriv, bobPub := newIdentity(t)
	alicePriv, alicePub := newIdentity(t)

	// bob publishes his invite. this is the only thing alice gets.
	restore := useIdentity(bobPriv, bobPub)
	_, bobFcPk, err := nip17FirstContactKeys(0)
	restore()
	if err != nil {
		t.Fatal(err)
	}

	// alice wraps an introduction to it, knowing bob's xpub and fc pk only.
	restore = useIdentity(alicePriv, alicePub)
	gw, err := nip17WrapFirstContact(bobPub, bobFcPk, "hello from a stranger")
	restore()
	if err != nil {
		t.Fatal(err)
	}

	// bob reads it with no prior knowledge of alice.
	restore = useIdentity(bobPriv, bobPub)
	got, sealPk, err := nip17UnwrapFirstContact(0, gw)
	restore()
	if err != nil {
		t.Fatalf("bob could not unwrap: %v", err)
	}
	if got != "hello from a stranger" {
		t.Fatalf("payload mangled: %q", got)
	}
	if sealPk == "" {
		t.Fatal("no seal pubkey returned")
	}
}

// a wrap aimed at one person must be unreadable by anyone else, even another
// kryfo user who knows the sender.
func TestFirstContactNotReadableByThirdParty(t *testing.T) {
	bobPriv, bobPub := newIdentity(t)
	alicePriv, alicePub := newIdentity(t)
	evePriv, evePub := newIdentity(t)

	restore := useIdentity(bobPriv, bobPub)
	_, bobFcPk, _ := nip17FirstContactKeys(0)
	restore()

	restore = useIdentity(alicePriv, alicePub)
	gw, err := nip17WrapFirstContact(bobPub, bobFcPk, "for bob only")
	restore()
	if err != nil {
		t.Fatal(err)
	}

	restore = useIdentity(evePriv, evePub)
	_, _, err = nip17UnwrapFirstContact(0, gw)
	restore()
	if err == nil {
		t.Fatal("a third party decrypted a first-contact wrap")
	}
}

// after the counter is bumped, invites printed against the old one must stop
// working - otherwise "reset my invite" is a lie.
func TestOldInviteStopsWorkingAfterRotate(t *testing.T) {
	bobPriv, bobPub := newIdentity(t)
	alicePriv, alicePub := newIdentity(t)

	restore := useIdentity(bobPriv, bobPub)
	_, oldFcPk, _ := nip17FirstContactKeys(0)
	restore()

	restore = useIdentity(alicePriv, alicePub)
	gw, err := nip17WrapFirstContact(bobPub, oldFcPk, "sent to a retired invite")
	restore()
	if err != nil {
		t.Fatal(err)
	}

	restore = useIdentity(bobPriv, bobPub)
	_, _, err = nip17UnwrapFirstContact(1, gw)
	restore()
	if err == nil {
		t.Fatal("a retired invite still worked")
	}
}
