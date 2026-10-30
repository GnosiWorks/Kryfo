// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the identities the app holds, by the id its database gives them. 0 is
// the main one: the words, the onion and the face, set by HaloGenerate or
// HaloRestoreIdentity. any other is put here by the app with its own key.
// nothing that seals, opens, listens or derives an address falls back to
// one: every such call names the identity it runs on.

import "C"

import (
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync"
)

const mainIdent = 0

var (
	identsMu sync.Mutex
	idents   = map[int]xid{}
	// the address seed of each pair made by a v4 first contact, by
	// identity and the peer's x key in hex
	pairSeeds = map[pairKey][32]byte{}
)

type pairKey struct {
	ident int
	peer  string
}

var errNoSuchIdentity = errors.New("no such identity")

// a call for a seeded pair that came without its seed
var errSeedMissing = errors.New("the pair is seeded and the call has no seed")

// identity [ident], as the app put it
func identityOf(ident int) (xid, error) {
	identsMu.Lock()
	defer identsMu.Unlock()
	id, ok := idents[ident]
	if !ok || id.priv == ([32]byte{}) {
		if ident == mainIdent {
			return xid{}, errNoIdentity
		}
		return xid{}, errNoSuchIdentity
	}
	return id, nil
}

func putIdentity(ident int, id xid) {
	identsMu.Lock()
	idents[ident] = id
	identsMu.Unlock()
}

// the seed of [ident]'s pair with [peer], when it has one
func pairSeed(ident int, peer [32]byte) (*[32]byte, bool) {
	identsMu.Lock()
	defer identsMu.Unlock()
	s, ok := pairSeeds[pairKey{ident, hex.EncodeToString(peer[:])}]
	if !ok {
		return nil, false
	}
	return &s, true
}

// an identity of the app's other than the main one, from its x25519
// private key in hex. the main one comes only with the onion and the face
//
//export HaloIdentityPut
func HaloIdentityPut(cIdent C.int, cXPrivHex *C.char) *C.char {
	ident := int(cIdent)
	if ident <= mainIdent {
		return C.CString("error: the main identity comes with the face")
	}
	id, err := xidFromPrivHex(goStr(cXPrivHex))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	putIdentity(ident, id)
	return C.CString("ok")
}

// an identity let go: its key, its seeds and everything listening on it
//
//export HaloIdentityDrop
func HaloIdentityDrop(cIdent C.int) *C.char {
	ident := int(cIdent)
	if ident <= mainIdent {
		return C.CString("error: the main identity stays")
	}
	identDrop(ident)
	return C.CString("ok")
}

func identDrop(ident int) {
	identsMu.Lock()
	delete(idents, ident)
	for k := range pairSeeds {
		if k.ident == ident {
			delete(pairSeeds, k)
		}
	}
	for k := range devSeeds {
		if k.ident == ident {
			delete(devSeeds, k)
		}
	}
	delete(linkedIdents, ident)
	identsMu.Unlock()
	pre := subPrefix(ident)
	dropDevListens(pre)
	fcPre := fcSubPrefix(ident)
	nostrMu.Lock()
	for k, cancel := range nostrSubs {
		if strings.HasPrefix(k, pre) || strings.HasPrefix(k, fcPre) {
			cancel()
			delete(nostrSubs, k)
		}
	}
	nostrMu.Unlock()
	fcKeysMu.Lock()
	for k := range fcKeys {
		if strings.HasPrefix(k, fcPre) {
			delete(fcKeys, k)
		}
	}
	fcKeysMu.Unlock()
}

// the address seed of a pair made by a v4 first contact: from now on its
// addresses mix it in. a new first contact with the same peer (a re-add)
// makes the pair again with its own seed, which replaces the one held.
// [cPeer] may name a device pair as "peer/their/my": its opener's seed
//
//export HaloPairSeed
func HaloPairSeed(cIdent C.int, cPeer, cSeedHex *C.char) *C.char {
	if err := pairSeedAfresh(int(cIdent), goStr(cPeer), goStr(cSeedHex)); err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString("ok")
}

func pairSeedAfresh(ident int, peerArg, seedHex string) error {
	if strings.Contains(peerArg, ".") {
		return errors.New("the seed comes apart")
	}
	b, err := hex.DecodeString(seedHex)
	if err != nil || len(b) != 32 {
		return errors.New("a seed is 32 bytes")
	}
	var s [32]byte
	copy(s[:], b)
	if strings.Contains(peerArg, "/") {
		// the pair as its opener address names it, so the device key is
		// the one on the list now
		c, _, err := pairArg(ident, peerArg)
		if err != nil {
			return err
		}
		if c.dev == nil {
			return errors.New("device 1 to device 1 is the identity pair")
		}
		putDevSeedAfresh(c.devKey(), s)
		return nil
	}
	peer, err := peerArr(peerArg)
	if err != nil {
		return err
	}
	putPairSeedAfresh(ident, peer, s)
	return nil
}

// a call naming a seed for the pair: one it has not seen it takes, another
// than the one it holds is refused (a call on a stale pair fails closed)
func putPairSeed(ident int, peer [32]byte, s [32]byte) error {
	identsMu.Lock()
	defer identsMu.Unlock()
	k := pairKey{ident, hex.EncodeToString(peer[:])}
	if had, ok := pairSeeds[k]; ok && had != s {
		return errors.New("the pair has another seed")
	}
	pairSeeds[k] = s
	return nil
}

// the pair made again by a new first contact (HaloPairSeed, which the app
// calls only then and at start): its seed replaces the one held
func putPairSeedAfresh(ident int, peer [32]byte, s [32]byte) {
	identsMu.Lock()
	defer identsMu.Unlock()
	pairSeeds[pairKey{ident, hex.EncodeToString(peer[:])}] = s
}

// the subscription of [ident]'s pair with [peerHex]: the main identity's
// keep the peer's key alone, as before, so their lanes and files stay
func subKey(ident int, peerHex string) string {
	if ident == mainIdent {
		return strings.ToLower(peerHex)
	}
	return subPrefix(ident) + strings.ToLower(peerHex)
}

func subPrefix(ident int) string { return "i" + strconv.Itoa(ident) + ":" }

// the identity and peer a subscription key names, ok false for any other
// kind of key
func subOf(k string) (int, string, bool) {
	if isHexKey(k) {
		return mainIdent, k, true
	}
	if !strings.HasPrefix(k, "i") {
		return 0, "", false
	}
	i := strings.IndexByte(k, ':')
	if i < 2 {
		return 0, "", false
	}
	n, err := strconv.Atoi(k[1:i])
	if err != nil || n <= mainIdent || !isHexKey(k[i+1:]) {
		return 0, "", false
	}
	return n, k[i+1:], true
}

// the identity a dart call names, as a C int
func identArg(c C.int) int { return int(c) }

// a json list of peers with the identity each is reached on
type identPeer struct {
	I int    `json:"i"`
	X string `json:"x"`
	// the pair's seed in hex, for a pair made by a v4 first contact
	S string `json:"s,omitempty"`
	// a device pair: their device and mine, both 0 on the identity pair
	T int `json:"t,omitempty"`
	M int `json:"m,omitempty"`
}

// the pair as pairArg reads it
func (p identPeer) arg() string {
	x := p.X
	if p.T != 0 || p.M != 0 {
		x += "/" + strconv.Itoa(p.T) + "/" + strconv.Itoa(p.M)
	}
	if p.S == "" {
		return x
	}
	return x + "." + p.S
}

func (p identPeer) String() string { return fmt.Sprintf("%d:%s", p.I, p.X) }
