// SPDX-License-Identifier: GPL-3.0-or-later
package main

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
