// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"maps"
	"testing"
)

// the main identity in tests, for the forms that name it

func testMain() xid {
	me, err := identityOf(mainIdent)
	if err != nil {
		panic(err)
	}
	return me
}

func mainPair(peer [32]byte) convPair {
	c, err := pairOf(mainIdent, peer)
	if err != nil {
		panic(err)
	}
	return c
}

func mainPeers(hexes ...string) []identPeer {
	out := make([]identPeer, 0, len(hexes))
	for _, h := range hexes {
		out = append(out, identPeer{I: mainIdent, X: h})
	}
	return out
}

// the main identity set by hand, as the globals once were
func setMainForTest(priv, pub [32]byte) {
	myXPriv, myXPub = priv, pub
	putIdentity(mainIdent, xid{priv: priv, pub: pub})
}

// the identities as a phone's for [t], whatever a test before it linked;
// what was there comes back after
func phoneOnly(t *testing.T) {
	t.Helper()
	identsMu.Lock()
	was := linkedIdents
	linkedIdents = map[int]linkedIdent{}
	identsMu.Unlock()
	t.Cleanup(func() {
		identsMu.Lock()
		linkedIdents = was
		identsMu.Unlock()
	})
}

// what a dev load links stays with the test that loaded it
func keepLinked(t *testing.T) {
	t.Helper()
	identsMu.Lock()
	was := maps.Clone(linkedIdents)
	identsMu.Unlock()
	t.Cleanup(func() {
		identsMu.Lock()
		linkedIdents = was
		identsMu.Unlock()
	})
}
