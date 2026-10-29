// SPDX-License-Identifier: GPL-3.0-or-later
package main

// first-contact keys per invite (identity v4 3.6): a random secp256k1 key
// the app makes for each invite and keeps with it, so no address comes
// from an identity's key. the engine listens on the ones the app hands it
// and opens what lands there with that key alone. the main identity still
// listens on its v3 address for the v3 links it handed out (nip17_fc.go)

import "C"

import (
	"context"
	"encoding/hex"
	"errors"
	"log"
	"strconv"
	"sync"

	nostr2 "github.com/nbd-wtf/go-nostr"
)

type fcKey struct{ sk, pk string }

// the keys listened on, by subscription key
var (
	fcKeysMu sync.Mutex
	fcKeys   = map[string]fcKey{}
)

func fcSubPrefix(ident int) string { return "f" + strconv.Itoa(ident) + ":" }

func fcSubKey(ident int, invite string) string { return fcSubPrefix(ident) + invite }

// the x-only public key of a first-contact key, an error when its 32 bytes
// are not a secp256k1 scalar
func fcKeyPk(skHex string) (string, error) {
	b, err := hex.DecodeString(skHex)
	if err != nil || len(b) != 32 {
		return "", errors.New("a first-contact key is 32 bytes")
	}
	pk, err := nostr2.GetPublicKey(skHex)
	if err != nil {
		return "", err
	}
	return pk, nil
}

// the public half the invite carries, or "error: ..." for a key that is
// none
//
//export HaloFcKeyPk
func HaloFcKeyPk(cSkHex *C.char) *C.char {
	pk, err := fcKeyPk(goStr(cSkHex))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(pk)
}

// listen on invite [invite]'s first-contact key of identity [ident]. the
// inbox lines are tagged f<ident>:<invite>
//
//export HaloNostrSubscribeFcKey
func HaloNostrSubscribeFcKey(cIdent C.int, cInvite, cSkHex *C.char) *C.char {
	if err := subscribeFcKey(identArg(cIdent), goStr(cInvite), goStr(cSkHex)); err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString("ok")
}

func subscribeFcKey(ident int, invite, skHex string) error {
	if invite == "" {
		return errors.New("an invite has an id")
	}
	if _, err := identityOf(ident); err != nil {
		return err
	}
	pk, err := fcKeyPk(skHex)
	if err != nil {
		return err
	}
	key := fcSubKey(ident, invite)
	fcKeysMu.Lock()
	fcKeys[key] = fcKey{skHex, pk}
	fcKeysMu.Unlock()
	startSub(key, func(ctx context.Context) {
		nostrSubscribeRunnerFc(ctx, key, skHex, pk)
	})
	log.Printf("nostr: watching an invite's first-contact addr %s...", pk[:12])
	return nil
}

// the invite retired: nothing listens on its key
//
//export HaloNostrUnsubscribeFcKey
func HaloNostrUnsubscribeFcKey(cIdent C.int, cInvite *C.char) *C.char {
	unsubscribeFcKey(identArg(cIdent), goStr(cInvite))
	return C.CString("ok")
}

func unsubscribeFcKey(ident int, invite string) {
	key := fcSubKey(ident, invite)
	nostrMu.Lock()
	if cancel, ok := nostrSubs[key]; ok {
		cancel()
		delete(nostrSubs, key)
	}
	nostrMu.Unlock()
	fcKeysMu.Lock()
	k, ok := fcKeys[key]
	delete(fcKeys, key)
	fcKeysMu.Unlock()
	if ok {
		dropAddressFiles(k.pk)
	}
}
