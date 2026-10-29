// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what the app's KIN4 invites and KHL1 hellos need of the engine (identity
// v4 2.1, 3.3): the face signature by the legacy ed key, the onion address
// of an invite's onion key, the hello seal key an arrival must carry, and
// a hello sent under it. the formats themselves are parsed and signed by
// the shim

import "C"

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"errors"
	"fmt"
	"log"

	"github.com/cretz/bine/torutil"
	bed25519 "github.com/cretz/bine/torutil/ed25519"
	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
)

// what a face signature covers starts with this, and nothing else is signed
// with the face key here
var faceText = []byte("kryfo-face-v4:")

// the face signature over [msg]: "kryfo-face-v4:", a 33-byte identity key
// and a 16-byte invite id, by my ed key
func faceSign(msg []byte) ([]byte, error) {
	if len(msg) != len(faceText)+33+16 || !bytes.HasPrefix(msg, faceText) ||
		msg[len(faceText)] != 0x05 {
		return nil, errors.New("not a face text")
	}
	mu.Lock()
	priv := myEdPriv
	mu.Unlock()
	if priv == nil {
		return nil, errNoIdentity
	}
	return ed25519.Sign(priv, msg), nil
}

//export HaloFaceSign
func HaloFaceSign(cMsgHex *C.char) *C.char {
	msg, err := hex.DecodeString(goStr(cMsgHex))
	if err != nil {
		return C.CString("error: bad hex")
	}
	sig, err := faceSign(msg)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(hex.EncodeToString(sig))
}

// the v3 onion address of an onion service's ed25519 public key
func onionOfKey(key []byte) (string, error) {
	if len(key) != ed25519.PublicKeySize {
		return "", errors.New("an onion key is 32 bytes")
	}
	return torutil.OnionServiceIDFromV3PublicKey(bed25519.PublicKey(key)) + ".onion", nil
}

//export HaloOnionOfKey
func HaloOnionOfKey(cKeyHex *C.char) *C.char {
	b, err := hex.DecodeString(goStr(cKeyHex))
	if err != nil {
		return C.CString("error: bad hex")
	}
	o, err := onionOfKey(b)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(o)
}

// the seal key an opener or a hello from [sender] to an invite of my
// [ident] must be signed with: its public half, x-only hex
func helloSealPkFor(ident int, senderHex string) (string, error) {
	sender, err := peerArr(senderHex)
	if err != nil {
		return "", err
	}
	me, err := identityOf(ident)
	if err != nil {
		return "", err
	}
	return v4HelloSealPk(me, sender)
}

//export HaloHelloSealPk
func HaloHelloSealPk(cIdent C.int, cSenderHex *C.char) *C.char {
	pk, err := helloSealPkFor(identArg(cIdent), goStr(cSenderHex))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(pk)
}

// a hello (or a v4 opener) from my [ident] to the first-contact key [fcPk]
// of an invite whose answering key is [ownerHex], sealed with the hello seal
// key of the two: it needs no seed, and a v3 link's owner reads it the same
//
//export HaloNostrSendHello
func HaloNostrSendHello(cIdent C.int, cOwnerHex, cFcPk, cMsg *C.char) *C.char {
	return C.CString(nostrSendHello(identArg(cIdent), goStr(cOwnerHex), goStr(cFcPk), goStr(cMsg)))
}

func nostrSendHello(ident int, ownerHex, fcPk, msg string) string {
	owner, err := peerArr(ownerHex)
	if err != nil {
		return "error: bad peer pubkey"
	}
	if b, err := hex.DecodeString(fcPk); err != nil || len(b) != 32 {
		return "error: bad first-contact pubkey"
	}
	me, err := identityOf(ident)
	if err != nil {
		return fmt.Sprintf("error: wrap: %v", err)
	}
	gw, err := helloWrap(me, owner, fcPk, msg)
	if err != nil {
		return fmt.Sprintf("error: wrap: %v", err)
	}
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		return fmt.Sprintf("error: wrap convert: %v", err)
	}
	nostrMu.Lock()
	nostrSentIDs[ev.ID.Hex()] = true
	if len(nostrSentIDs) > 4096 {
		nostrSentIDs = map[string]bool{}
	}
	nostrMu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), publishWait)
	defer cancel()
	if nostrPublishMulti(ctx, laneEveryday, ev) == 0 {
		return "error: no relays accepted"
	}
	log.Printf("nostr: sent a v4 first contact to addr %s...", fcPk[:12])
	return "ok"
}
