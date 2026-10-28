// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the sealed token. the app seals its fcm token to this gateway's x25519
// key with hpke (base mode: x25519, hkdf-sha256, chacha20-poly1305), a new
// ephemeral key and so a new key and nonce for every seal, so the sixteen
// seals of one token share nothing. the token is padded with dots to a
// fixed length first, so every endpoint is as long as every other, whatever
// the token. on the wire: base64url, no padding, of one version byte, the
// 32-byte encapsulated key and the ciphertext.
// engine/push_seal.go is the app's half and must stay the same.

import (
	"bytes"
	"crypto/ecdh"
	"crypto/hpke"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"strings"
)

const (
	sealVersion = 1
	sealInfo    = "kryfo push 1"
	// an fcm token is about 160 characters; the cap keeps the endpoint
	// under the relay's 512
	minToken = 20
	maxToken = 311
	// what every token is padded to, with a byte no token has
	padded  = maxToken
	padByte = '.'
	// in characters of the url: one length for every seal
	sealedLen = (1 + 32 + 16 + padded) * 4 / 3
	minSealed = sealedLen
	maxSealed = sealedLen
)

var (
	suiteKEM  = hpke.DHKEM(ecdh.X25519())
	suiteKDF  = hpke.HKDFSHA256()
	suiteAEAD = hpke.ChaCha20Poly1305()
	b64       = base64.RawURLEncoding

	errSealed = errors.New("not a sealed token")
)

// what a token is made of: fcm's have a colon and dashes
func tokenOK(t []byte) bool {
	if len(t) < minToken || len(t) > maxToken {
		return false
	}
	for _, c := range t {
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9',
			c == '-', c == '_', c == ':':
		default:
			return false
		}
	}
	return true
}

func sealedChars(s string) bool {
	if len(s) < minSealed || len(s) > maxSealed {
		return false
	}
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', c == '-', c == '_':
		default:
			return false
		}
	}
	return true
}

// opens a sealed token in memory. any failure is the same error, so an
// answer says nothing about why
func open(k hpke.PrivateKey, sealed string) (string, error) {
	if !sealedChars(sealed) {
		return "", errSealed
	}
	raw, err := b64.DecodeString(sealed)
	if err != nil || len(raw) < 1+32+16 || raw[0] != sealVersion {
		return "", errSealed
	}
	pt, err := hpke.Open(k, suiteKDF, suiteAEAD, []byte(sealInfo), raw[1:])
	if err != nil || len(pt) != padded {
		return "", errSealed
	}
	pt = bytes.TrimRight(pt, string(padByte))
	if !tokenOK(pt) {
		return "", errSealed
	}
	return string(pt), nil
}

// what the app does, for the tests and the check after keygen
func seal(pub hpke.PublicKey, token string) (string, error) {
	if len(token) > padded {
		return "", errSealed
	}
	pt := append([]byte(token), bytes.Repeat([]byte{padByte}, padded-len(token))...)
	ct, err := hpke.Seal(pub, suiteKDF, suiteAEAD, []byte(sealInfo), pt)
	if err != nil {
		return "", err
	}
	return b64.EncodeToString(append([]byte{sealVersion}, ct...)), nil
}

// the private key file: base64url of the 32-byte x25519 key and a newline
func readKey(path string) (hpke.PrivateKey, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("the key file could not be read: %w", errors.Unwrap(err))
	}
	raw, err := b64.DecodeString(strings.TrimSpace(string(b)))
	clear(b)
	if err != nil || len(raw) != 32 {
		return nil, errors.New("the key file holds no key")
	}
	k, err := suiteKEM.NewPrivateKey(raw)
	clear(raw)
	if err != nil {
		return nil, errors.New("the key file holds no key")
	}
	return k, nil
}

func pubString(k hpke.PrivateKey) string { return b64.EncodeToString(k.PublicKey().Bytes()) }

// a new key into path, which must not exist yet, readable by its owner
// only. the public key is what the app pins
func keygen(path string) (string, error) {
	k, err := suiteKEM.GenerateKey()
	if err != nil {
		return "", err
	}
	raw, err := k.Bytes()
	if err != nil {
		return "", err
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return "", err
	}
	_, werr := f.WriteString(b64.EncodeToString(raw) + "\n")
	clear(raw)
	if cerr := f.Close(); werr == nil {
		werr = cerr
	}
	if werr != nil {
		os.Remove(path)
		return "", werr
	}
	// read back and sealed to once, so a key that cannot open is never
	// handed out
	back, err := readKey(path)
	if err != nil {
		return "", err
	}
	probe := make([]byte, 24)
	rand.Read(probe)
	tok := b64.EncodeToString(probe)
	s, err := seal(back.PublicKey(), tok)
	if err != nil {
		return "", err
	}
	if got, err := open(back, s); err != nil || !bytes.Equal([]byte(got), []byte(tok)) {
		return "", errors.New("the new key does not open its own seal")
	}
	return pubString(back), nil
}
