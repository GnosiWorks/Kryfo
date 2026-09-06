// SPDX-License-Identifier: GPL-3.0-or-later
package main

// first-contact addresses. every other address on the wire comes from
// ECDH(myPriv, peerPub), which means both sides need each other's key before
// either can compute anything. that is fine once you are paired and useless
// before it: a phone with no contacts subscribes to nothing, so a one-way qr
// scan only ever worked because the direct onion carried the introduction.
// when the onion will not publish, nothing arrives and nothing says why.
//
// this address comes from our own private key alone. we can always derive it,
// a stranger gets the public half out of our invite, and nobody else can read
// what lands there.
//
// the counter is not decoration. an invite can end up in a bio, a screenshot
// or a forum post, and without a counter the address it points at would be
// permanent - unrotatable for the life of the identity, and a stable thing for
// a relay to count. bumping it retires old invites and leaves the identity and
// every existing conversation untouched.

import (
	"encoding/hex"
	"fmt"
	"time"

	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
	"github.com/nbd-wtf/go-nostr/nip59"
)

const nip17FcInfo = "halo-nip17-fc-v1:"

// split out from the global so it can be tested with two identities in one
// process.
func fcKeysFrom(priv [32]byte, counter int) (sk, pk string, err error) {
	for ctr := 0; ctr < 4; ctr++ {
		seed := nostrHkdf(
			priv[:],
			nil,
			[]byte(fmt.Sprintf("%s%d:%d", nip17FcInfo, counter, ctr)),
			32,
		)
		sk = hex.EncodeToString(seed)
		if pk, err = nostr2.GetPublicKey(sk); err == nil {
			return sk, pk, nil
		}
	}
	return "", "", fmt.Errorf("fc derive failed")
}

func nip17FirstContactKeys(counter int) (sk, pk string, err error) {
	return fcKeysFrom(myXPriv, counter)
}

// wrap an introduction for a stranger's first-contact address. the seal is
// still signed with our per-conversation sender key, so once they know who we
// are the same verification as every other message applies. only the outer
// wrap is addressed differently.
func nip17WrapFirstContact(peer [32]byte, fcPk, msg string) (nostr2.Event, error) {
	return nip17WrapFirstContactAs(myXid(), peer, fcPk, msg)
}

func nip17WrapFirstContactAs(me xid, peer [32]byte, fcPk, msg string) (nostr2.Event, error) {
	sndSk, sndPk, err := nip17DeriveRoleAs(me, peer, nip17SndInfo, hex.EncodeToString(me.pub[:]))
	if err != nil {
		return nostr2.Event{}, err
	}
	rumor := nostr2.Event{
		Kind:      14,
		CreatedAt: nostr2.Now(),
		PubKey:    sndPk,
		Content:   msg,
		Tags:      nostr2.Tags{{"p", fcPk}},
	}
	ck, err := nip44.GenerateConversationKey(fcPk, sndSk)
	if err != nil {
		return nostr2.Event{}, err
	}
	exp := fmt.Sprintf("%d", time.Now().Add(14*24*time.Hour).Unix())
	return nip59.GiftWrap(rumor, fcPk,
		func(pt string) (string, error) { return nip44.Encrypt(pt, ck) },
		func(e *nostr2.Event) error { return e.Sign(sndSk) },
		func(e *nostr2.Event) { e.Tags = append(e.Tags, nostr2.Tag{"expiration", exp}) },
	)
}

// unwrap something that landed on our first-contact address. we cannot check
// who sent it - not knowing them yet is what makes it first contact - so the
// caller must treat the result as untrusted and put it through the same pow
// and request gates as any other stranger. returns the payload and the seal's
// pubkey so the caller can tie later messages to the same sender.
func nip17UnwrapFirstContact(counter int, gw nostr2.Event) (content, sealPk string, err error) {
	fcSk, _, err := nip17FirstContactKeys(counter)
	if err != nil {
		return "", "", err
	}
	return nip17UnwrapFirstContactWith(fcSk, gw)
}

func nip17UnwrapFirstContactWith(fcSk string, gw nostr2.Event) (content, sealPk string, err error) {
	rumor, err := nip59.GiftUnwrap(gw, func(otherPk, ct string) (string, error) {
		k, kerr := nip44.GenerateConversationKey(otherPk, fcSk)
		if kerr != nil {
			return "", kerr
		}
		return nip44.Decrypt(ct, k)
	})
	if err != nil {
		return "", "", err
	}
	return rumor.Content, rumor.PubKey, nil
}
