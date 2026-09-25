// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the decoy's identity: made and described by pure functions that touch no
// engine state and log nothing. the decoy is never brought online, so none
// of it is ever used to connect; it is only what a decoy session shows, and
// what a backup made there carries.

/*
#include <stdlib.h>
*/
import "C"

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"

	bed25519 "github.com/cretz/bine/torutil/ed25519"

	"github.com/cretz/bine/torutil"
	"golang.org/x/crypto/curve25519"
)

type quietIdentity struct {
	EdPriv   string `json:"ed_priv"`
	XPriv    string `json:"x_priv"`
	OnionKey string `json:"onion_key"`
	ID       string `json:"id"`
	EdPub    string `json:"ed_pub"`
	XPub     string `json:"x_pub"`
	Onion    string `json:"onion"`
}

// everything an identity shows, from its three private keys
func quietDescribe(ed ed25519.PrivateKey, xPriv []byte, onion ed25519.PrivateKey) (quietIdentity, error) {
	if len(ed) != ed25519.PrivateKeySize || len(xPriv) != 32 ||
		len(onion) != ed25519.PrivateKeySize {
		return quietIdentity{}, errors.New("bad key")
	}
	var xp, xpub [32]byte
	copy(xp[:], xPriv)
	curve25519.ScalarBaseMult(&xpub, &xp)
	pub := ed.Public().(ed25519.PublicKey)
	opub := onion.Public().(ed25519.PublicKey)
	return quietIdentity{
		EdPriv:   hex.EncodeToString(ed),
		XPriv:    hex.EncodeToString(xPriv),
		OnionKey: hex.EncodeToString(onion),
		ID:       idFromPubkey(pub),
		EdPub:    hex.EncodeToString(pub),
		XPub:     hex.EncodeToString(xpub[:]),
		Onion:    torutil.OnionServiceIDFromV3PublicKey(bed25519.FromCryptoPublicKey(opub)) + ".onion",
	}, nil
}

func quietNew() (quietIdentity, error) {
	_, ed, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return quietIdentity{}, err
	}
	x := make([]byte, 32)
	if _, err := rand.Read(x); err != nil {
		return quietIdentity{}, err
	}
	_, onion, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return quietIdentity{}, err
	}
	return quietDescribe(ed, x, onion)
}

func quietOut(q quietIdentity, err error) *C.char {
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	b, _ := json.Marshal(q)
	return C.CString(string(b))
}

// a new identity for the decoy, as json, or a line starting with "error:"
//
//export HaloQuietIdentity
func HaloQuietIdentity() *C.char {
	return quietOut(quietNew())
}

// what an identity kept in a decoy's database shows, from its private keys
//
//export HaloQuietDescribe
func HaloQuietDescribe(cEd, cX, cOnion *C.char) *C.char {
	ed, err1 := hex.DecodeString(C.GoString(cEd))
	x, err2 := hex.DecodeString(C.GoString(cX))
	onion, err3 := hex.DecodeString(C.GoString(cOnion))
	if err := errors.Join(err1, err2, err3); err != nil {
		return C.CString("error: bad hex")
	}
	return quietOut(quietDescribe(ed25519.PrivateKey(ed), x, ed25519.PrivateKey(onion)))
}

// the first-contact address an invite of this identity carries
//
//export HaloQuietFirstContactPk
func HaloQuietFirstContactPk(cX *C.char, counter C.int) *C.char {
	x, err := hex.DecodeString(C.GoString(cX))
	if err != nil || len(x) != 32 {
		return C.CString("error: bad x priv")
	}
	var priv [32]byte
	copy(priv[:], x)
	_, pk, err := fcKeysFrom(priv, int(counter))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(pk)
}
