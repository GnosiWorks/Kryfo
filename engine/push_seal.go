// SPDX-License-Identifier: GPL-3.0-or-later
package main

// google push, the engine's half: the play build seals its fcm token to the
// push gateway's pinned key once per slot (server/push/seal.go opens it).
// hpke base mode, x25519, hkdf-sha256, chacha20-poly1305: a new ephemeral
// key and nonce for every seal, so the sixteen endpoints of one token share
// nothing the relay could match. on the wire: base64url, no padding, of a
// version byte, the encapsulated key and the ciphertext.

import (
	"crypto/ecdh"
	"crypto/hpke"
	"encoding/base64"
	"errors"
)

import "C"

const (
	pushSealVersion = 1
	pushSealInfo    = "kryfo push 1"
	// what the gateway takes: an endpoint stays under the relay's 512
	pushTokenMin = 20
	pushTokenMax = 311
)

var errPushSeal = errors.New("cannot seal")

func pushTokenOK(t string) bool {
	if len(t) < pushTokenMin || len(t) > pushTokenMax {
		return false
	}
	for i := 0; i < len(t); i++ {
		c := t[i]
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9',
			c == '-', c == '_', c == ':':
		default:
			return false
		}
	}
	return true
}

func pushSeal(pubB64, token string) (string, error) {
	if !pushTokenOK(token) {
		return "", errPushSeal
	}
	raw, err := base64.RawURLEncoding.DecodeString(pubB64)
	if err != nil || len(raw) != 32 {
		return "", errPushSeal
	}
	pub, err := hpke.DHKEM(ecdh.X25519()).NewPublicKey(raw)
	if err != nil {
		return "", errPushSeal
	}
	ct, err := hpke.Seal(pub, hpke.HKDFSHA256(), hpke.ChaCha20Poly1305(), []byte(pushSealInfo), []byte(token))
	if err != nil {
		return "", errPushSeal
	}
	return base64.RawURLEncoding.EncodeToString(append([]byte{pushSealVersion}, ct...)), nil
}

// the sealed token for the gateway's url, or "error: ..." for a key or a
// token that is not one
//
//export HaloPushSeal
func HaloPushSeal(cPub, cToken *C.char) *C.char {
	s, err := pushSeal(goStr(cPub), goStr(cToken))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(s)
}
