// SPDX-License-Identifier: GPL-3.0-or-later
package main

// conversation addresses of a v4 pair (identity v4 3.6): the pair a v4
// first contact made. as v3 they name their owner and hold both keys in
// the salt; the key material also takes S, the 32-byte seed the opener
// carried inside the post-quantum session, so relay logs recorded today
// do not give the addresses to whoever breaks x25519 later.
//
//   ikm  = X25519(my device key, their device key) || S
//   salt = sha256(min(u_Ia, u_Ib) || max(u_Ia, u_Ib))[0:16]
//   info = "kryfo-conv-v4:" || owner device key (33) || other device key
//          (33) || role (3) || ctr (1)
//
// a phone's device key is its identity key, so 0.6's pairs have D = I.
// the hello seal key is the same with no seed and role "hlo", owner the
// sender: it signs the seal of an opener or a hello sent to a
// first-contact address, and is never an address.

import (
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
	"github.com/nbd-wtf/go-nostr/nip59"
	"golang.org/x/crypto/curve25519"
)

const convV4Label = "kryfo-conv-v4:"

const (
	roleSnd = "snd"
	roleRcv = "rcv"
	roleHlo = "hlo"
)

// the two ends of a v4 pair: my device key pair and theirs, and the two
// identity keys the salt holds (equal to the device keys on phones)
type v4Pair struct {
	me        xid
	their     [32]byte
	myIdent   [32]byte
	theirIdnt [32]byte
	seed      []byte
}

func phonePair(me xid, peer [32]byte, seed []byte) v4Pair {
	return v4Pair{me: me, their: peer, myIdent: me.pub, theirIdnt: peer, seed: seed}
}

func libsignalKey(u [32]byte) []byte { return append([]byte{0x05}, u[:]...) }

// the secp256k1 key of one role, owned by me ([mine]) or by them
func (p v4Pair) role(role string, mine bool) (sk, pk string, err error) {
	if len(role) != 3 {
		return "", "", fmt.Errorf("bad role")
	}
	shared, err := curve25519.X25519(p.me.priv[:], p.their[:])
	if err != nil {
		return "", "", err
	}
	ikm := append(append([]byte{}, shared...), p.seed...)
	salt := nostrConversationID(p.myIdent, p.theirIdnt)
	owner, other := libsignalKey(p.me.pub), libsignalKey(p.their)
	if !mine {
		owner, other = other, owner
	}
	for ctr := 0; ctr < 4; ctr++ {
		info := make([]byte, 0, len(convV4Label)+33+33+3+1)
		info = append(info, convV4Label...)
		info = append(info, owner...)
		info = append(info, other...)
		info = append(info, role...)
		info = append(info, byte(ctr))
		k := nostrHkdf(ikm, salt, info, 32)
		sk = hex.EncodeToString(k)
		if pk, err = nostr2.GetPublicKey(sk); err == nil {
			return sk, pk, nil
		}
	}
	return "", "", fmt.Errorf("v4 derive failed")
}

// my receive address on a v4 pair
func v4RcvAddress(p v4Pair) (sk, pk string, err error) {
	if len(p.seed) != 32 {
		return "", "", fmt.Errorf("a v4 pair needs its seed")
	}
	return p.role(roleRcv, true)
}

// the hello seal key of a sender to an answering key: no seed, owner the
// sender. both sides compute the same
func v4HelloSealKey(sender xid, answering [32]byte) (sk, pk string, err error) {
	return phonePair(sender, answering, nil).role(roleHlo, true)
}

// as v4HelloSealKey, from the answering side: the public half only
func v4HelloSealPk(answering xid, sender [32]byte) (string, error) {
	_, pk, err := phonePair(answering, sender, nil).role(roleHlo, false)
	return pk, err
}

func v4Wrap(p v4Pair, msg string) (nostr2.Event, error) {
	if len(p.seed) != 32 {
		return nostr2.Event{}, fmt.Errorf("a v4 pair needs its seed")
	}
	sndSk, sndPk, err := p.role(roleSnd, true)
	if err != nil {
		return nostr2.Event{}, err
	}
	_, rcvPk, err := p.role(roleRcv, false)
	if err != nil {
		return nostr2.Event{}, err
	}
	return giftWrapAs(sndSk, sndPk, rcvPk, msg)
}

func v4UnwrapStamped(p v4Pair, gw nostr2.Event) (string, nostr2.Timestamp, error) {
	rcvSk, _, err := v4RcvAddress(p)
	if err != nil {
		return "", 0, err
	}
	rumor, err := nip59.GiftUnwrap(gw, func(otherPk, ct string) (string, error) {
		k, err := nip44.GenerateConversationKey(otherPk, rcvSk)
		if err != nil {
			return "", err
		}
		return nip44.Decrypt(ct, k)
	})
	if err != nil {
		return "", 0, err
	}
	_, wantSnd, err := p.role(roleSnd, false)
	if err != nil {
		return "", 0, err
	}
	if rumor.PubKey != wantSnd {
		return "", 0, fmt.Errorf("seal not from expected peer")
	}
	return rumor.Content, rumor.CreatedAt, nil
}

// a rumor sealed with [sndSk] for [rcvPk], gift wrapped under a fresh key
func giftWrapAs(sndSk, sndPk, rcvPk, msg string) (nostr2.Event, error) {
	rumor := nostr2.Event{
		Kind:      14,
		CreatedAt: nostr2.Now(),
		PubKey:    sndPk,
		Content:   msg,
		Tags:      nostr2.Tags{{"p", rcvPk}},
	}
	ck, err := nip44.GenerateConversationKey(rcvPk, sndSk)
	if err != nil {
		return nostr2.Event{}, err
	}
	exp := wrapExpiry(time.Now())
	return giftWrapKept(rumor, rcvPk,
		func(pt string) (string, error) { return nip44.Encrypt(pt, ck) },
		func(e *nostr2.Event) error { return e.Sign(sndSk) },
		func(e *nostr2.Event) { e.Tags = append(e.Tags, nostr2.Tag{"expiration", exp}) },
	)
}

// the pair of my [ident] with [peer]: its own addresses, v4 when the pair
// has a seed, v3 (the two keys alone) when it has none
type convPair struct {
	ident int
	me    xid
	peer  [32]byte
	seed  *[32]byte
	// one device of mine with one of theirs, nil on the identity pair
	// (address_device.go)
	dev *devPair
}

// the v3 pair of my [ident] with [peer]: the two keys alone. a pair the
// engine has seen seeded is refused here, so nothing falls back to its v3
// addresses (pairArg)
func pairOf(ident int, peer [32]byte) (convPair, error) {
	me, err := identityOf(ident)
	if err != nil {
		return convPair{}, err
	}
	if _, ok := pairSeed(ident, peer); ok {
		return convPair{}, errSeedMissing
	}
	return convPair{ident: ident, me: me, peer: peer}, nil
}

// the seeded pair of my [ident] with [peer]: its seed is kept for the
// refusal above, and a second seed for the pair is refused
func seededPairOf(ident int, peer [32]byte, seed [32]byte) (convPair, error) {
	me, err := identityOf(ident)
	if err != nil {
		return convPair{}, err
	}
	if err := putPairSeed(ident, peer, seed); err != nil {
		return convPair{}, err
	}
	return convPair{ident: ident, me: me, peer: peer, seed: &seed}, nil
}

// the pair a call names. [arg] is the peer's x key in hex (a v3 pair), or
// the key, a dot and the pair's seed in hex (a pair made by a v4 first
// contact), or a device pair (address_device.go). the mode comes from the
// call alone, never from what the engine holds; the peer's key in hex
// comes back as the subscription names it
func pairArg(ident int, arg string) (convPair, string, error) {
	base, seedHex, seeded := strings.Cut(arg, ".")
	if strings.Contains(base, "/") && !devicePairsOn.Load() {
		return convPair{}, "", errDevicePairsOff
	}
	x, their, my, dev, err := splitDeviceArg(base)
	if err != nil {
		return convPair{}, "", err
	}
	peer, err := peerArr(x)
	if err != nil {
		return convPair{}, "", err
	}
	x = strings.ToLower(x)
	// the identity pair named by its devices is the identity pair
	if dev && their == phoneDevice && my == phoneDevice && !isLinked(ident) {
		if !seeded {
			return convPair{}, "", errors.New("device 1 to device 1 is the identity pair")
		}
		dev = false
	}
	if dev {
		c, err := devicePairArg(ident, peer, their, my, seedHex, seeded)
		return c, x, err
	}
	// a linked device has no identity pair: its device key is not I
	if isLinked(ident) {
		return convPair{}, "", errors.New("a linked device names its device pair")
	}
	if !seeded {
		c, err := pairOf(ident, peer)
		return c, x, err
	}
	b, err := hex.DecodeString(seedHex)
	if err != nil || len(b) != 32 {
		return convPair{}, "", errors.New("a seed is 32 bytes")
	}
	var s [32]byte
	copy(s[:], b)
	c, err := seededPairOf(ident, peer, s)
	return c, x, err
}

func (c convPair) v4() v4Pair {
	if c.dev != nil {
		return c.devV4()
	}
	return phonePair(c.me, c.peer, c.seed[:])
}

func (c convPair) rcvAddress() (sk, pk string, err error) {
	if c.dev != nil && c.dev.opener {
		return devOpenerRcv(c.v4())
	}
	if c.seed != nil {
		return v4RcvAddress(c.v4())
	}
	return nip17RcvAddressAs(c.me, c.peer)
}

// their receive address: where what I send them lands
func (c convPair) theirAddress() (string, error) {
	if c.dev != nil && c.dev.opener {
		p := c.v4()
		_, pk, err := p.role(roleOpn, false)
		return pk, err
	}
	if c.seed != nil {
		_, pk, err := c.v4().role(roleRcv, false)
		return pk, err
	}
	_, pk, err := nip17DeriveRoleAs(c.me, c.peer, nip17RcvInfo, hex.EncodeToString(c.peer[:]))
	return pk, err
}

func (c convPair) wrap(msg string) (nostr2.Event, error) {
	if c.dev != nil && c.dev.opener {
		return devOpenerWrap(c.v4(), msg)
	}
	if c.seed != nil {
		return v4Wrap(c.v4(), msg)
	}
	return nip17WrapAs(c.me, c.peer, msg)
}

func (c convPair) unwrapStamped(gw nostr2.Event) (string, nostr2.Timestamp, error) {
	if c.dev != nil && c.dev.opener {
		return devOpenerUnwrapStamped(c.v4(), gw)
	}
	if c.seed != nil {
		return v4UnwrapStamped(c.v4(), gw)
	}
	return nip17UnwrapAsStamped(c.me, c.peer, gw)
}

// an opener or a hello for a stranger's first-contact address [fcPk]. the
// main identity's v3 pair seals it as 0.5 does, so a 0.5 phone reads it;
// a seeded pair (a v4 first contact) and any other identity with the hello
// seal key, which needs no seed
func (c convPair) wrapFirstContact(fcPk, msg string) (nostr2.Event, error) {
	if c.dev != nil {
		return nostr2.Event{}, errors.New("a device pair has no first contact")
	}
	if c.ident == mainIdent && c.seed == nil {
		return nip17WrapFirstContactAs(c.me, c.peer, fcPk, msg)
	}
	return helloWrap(c.me, c.peer, fcPk, msg)
}

// [msg] from [me] to the first-contact key [fcPk] of an invite answered by
// [answering], sealed with the two's hello seal key
func helloWrap(me xid, answering [32]byte, fcPk, msg string) (nostr2.Event, error) {
	sk, pk, err := v4HelloSealKey(me, answering)
	if err != nil {
		return nostr2.Event{}, err
	}
	rumor := nostr2.Event{
		Kind:      14,
		CreatedAt: nostr2.Now(),
		PubKey:    pk,
		Content:   msg,
		Tags:      nostr2.Tags{{"p", fcPk}},
	}
	ck, err := nip44.GenerateConversationKey(fcPk, sk)
	if err != nil {
		return nostr2.Event{}, err
	}
	exp := wrapExpiry(time.Now())
	return giftWrapKept(rumor, fcPk,
		func(pt string) (string, error) { return nip44.Encrypt(pt, ck) },
		func(e *nostr2.Event) error { return e.Sign(sk) },
		func(e *nostr2.Event) { e.Tags = append(e.Tags, nostr2.Tag{"expiration", exp}) },
	)
}
