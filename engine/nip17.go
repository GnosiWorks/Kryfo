package main

// nip17 gift-wrap layer. the old transport signed every message of a
// conversation with one deterministic key - a relay could link the whole
// thread and tie both sides together. now each message publishes under a
// fresh ephemeral key with a jittered timestamp, sealed to a per-conversation
// receive address. addresses share nothing across conversations and only the
// two peers can derive them, so this hides more than stock nip-17 (which
// puts your one real pubkey on every wrap).

import (
	"encoding/hex"
	"fmt"
	"time"

	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
	"github.com/nbd-wtf/go-nostr/nip59"
	"golang.org/x/crypto/curve25519"
)

const (
	nip17SndInfo = "halo-nip17-snd-v1:"
	nip17RcvInfo = "halo-nip17-rcv-v1:"
)

// derive the secp keypair for one role (send or receive) in one conversation.
// both peers can compute both roles from their shared secret; nobody else
// can compute either, and nothing links two conversations.
func nip17DeriveRole(peer [32]byte, info, ownerXPubHex string) (sk, pk string, err error) {
	shared, err := curve25519.X25519(myXPriv[:], peer[:])
	if err != nil {
		return "", "", err
	}
	cid := nostrConversationID(myXPub, peer)
	for ctr := 0; ctr < 4; ctr++ {
		seed := nostrHkdf(shared, cid, []byte(fmt.Sprintf("%s%s:%d", info, ownerXPubHex, ctr)), 32)
		sk = hex.EncodeToString(seed)
		if pk, err = nostr2.GetPublicKey(sk); err == nil {
			return sk, pk, nil
		}
	}
	return "", "", fmt.Errorf("nip17 derive failed")
}

// my receive address for this peer. the subscription filters on its pubkey.
func nip17RcvAddress(peer [32]byte) (sk, pk string, err error) {
	return nip17DeriveRole(peer, nip17RcvInfo, hex.EncodeToString(myXPub[:]))
}

// wrap msg for the peer: rumor -> seal (signed with our per-convo sender
// key) -> gift wrap (fresh throwaway key + jittered timestamp, done inside
// nip59). returns the wrap ready to publish.
func nip17Wrap(peer [32]byte, msg string) (nostr2.Event, error) {
	sndSk, sndPk, err := nip17DeriveRole(peer, nip17SndInfo, hex.EncodeToString(myXPub[:]))
	if err != nil {
		return nostr2.Event{}, err
	}
	_, rcvPk, err := nip17DeriveRole(peer, nip17RcvInfo, hex.EncodeToString(peer[:]))
	if err != nil {
		return nostr2.Event{}, err
	}

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
	exp := fmt.Sprintf("%d", time.Now().Add(30*24*time.Hour).Unix())
	return nip59.GiftWrap(rumor, rcvPk,
		func(pt string) (string, error) { return nip44.Encrypt(pt, ck) },
		func(e *nostr2.Event) error { return e.Sign(sndSk) },
		func(e *nostr2.Event) { e.Tags = append(e.Tags, nostr2.Tag{"expiration", exp}) },
	)
}

// unwrap a gift wrap from this peer. anything not sealed by the peer's
// derived sender key is dropped.
func nip17Unwrap(peer [32]byte, gw nostr2.Event) (string, error) {
	rcvSk, _, err := nip17RcvAddress(peer)
	if err != nil {
		return "", err
	}
	rumor, err := nip59.GiftUnwrap(gw, func(otherPk, ct string) (string, error) {
		k, err := nip44.GenerateConversationKey(otherPk, rcvSk)
		if err != nil {
			return "", err
		}
		return nip44.Decrypt(ct, k)
	})
	if err != nil {
		return "", err
	}
	_, wantSnd, err := nip17DeriveRole(peer, nip17SndInfo, hex.EncodeToString(peer[:]))
	if err != nil {
		return "", err
	}
	if rumor.PubKey != wantSnd {
		return "", fmt.Errorf("seal not from expected peer")
	}
	return rumor.Content, nil
}
