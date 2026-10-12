// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the hidden chats' sealing key. an arrival for a hidden chat is sealed to the
// public half while the vault is shut, and opened with the private half, which
// only the vault holds. pure like quiet.go: no engine state, nothing logged,
// and no error carries a key.

/*
#include <stdlib.h>
*/
import "C"

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"io"

	"filippo.io/age"
)

type vaultKeys struct {
	Pub  string `json:"pub"`
	Priv string `json:"priv"`
}

var (
	errVaultKey  = errors.New("bad key")
	errVaultData = errors.New("bad data")
	errVaultSeal = errors.New("cannot seal")
	errVaultOpen = errors.New("cannot open")
)

func vaultNewKeys() (vaultKeys, error) {
	id, err := age.GenerateX25519Identity()
	if err != nil {
		return vaultKeys{}, errors.New("no keys")
	}
	return vaultKeys{Pub: id.Recipient().String(), Priv: id.String()}, nil
}

// age's parse errors quote what they were given, so they never pass through
func vaultRecipient(pub string) (*age.X25519Recipient, error) {
	r, err := age.ParseX25519Recipient(pub)
	if err != nil {
		return nil, errVaultKey
	}
	return r, nil
}

func vaultIdentity(priv string) (*age.X25519Identity, error) {
	id, err := age.ParseX25519Identity(priv)
	if err != nil {
		return nil, errVaultKey
	}
	return id, nil
}

// sealed rows are padded to a bucket, so a short marker reads like a short
// message. a row sealed before carries no header and opens as it was
var vaultPadMagic = []byte{0, 'K', 'V', '1'}

const (
	vaultPadHead = 8
	vaultPadMin  = 1 << 10
	vaultPadStep = 64 << 10
)

// the size a padded row of n bytes takes: powers of two up to the step,
// whole steps past it
func vaultBucket(n int) int {
	b := vaultPadMin
	for b < n && b < vaultPadStep {
		b <<= 1
	}
	if b >= n {
		return b
	}
	return (n + vaultPadStep - 1) / vaultPadStep * vaultPadStep
}

func vaultPad(plain []byte) []byte {
	out := make([]byte, vaultBucket(vaultPadHead+len(plain)))
	copy(out, vaultPadMagic)
	binary.BigEndian.PutUint32(out[4:vaultPadHead], uint32(len(plain)))
	copy(out[vaultPadHead:], plain)
	return out
}

// the bytes a padded row carries, or the row itself when it is not one. a
// padded row is its bucket's size exactly and zero past its bytes, so an
// older row that only starts like the header opens as it was
func vaultUnpad(b []byte) ([]byte, error) {
	if len(b) < vaultPadHead || !bytes.Equal(b[:4], vaultPadMagic) {
		return b, nil
	}
	n := uint64(binary.BigEndian.Uint32(b[4:vaultPadHead]))
	if n > uint64(len(b)-vaultPadHead) || vaultBucket(vaultPadHead+int(n)) != len(b) {
		return b, nil
	}
	for _, c := range b[vaultPadHead+int(n):] {
		if c != 0 {
			return b, nil
		}
	}
	return b[vaultPadHead : vaultPadHead+int(n)], nil
}

func vaultSeal(r *age.X25519Recipient, plain []byte) ([]byte, error) {
	var out bytes.Buffer
	w, err := age.Encrypt(&out, r)
	if err != nil {
		return nil, errVaultSeal
	}
	padded := vaultPad(plain)
	defer zero(padded)
	if _, err := w.Write(padded); err != nil {
		return nil, errVaultSeal
	}
	if err := w.Close(); err != nil {
		return nil, errVaultSeal
	}
	return out.Bytes(), nil
}

func vaultOpen(id *age.X25519Identity, sealed []byte) ([]byte, error) {
	r, err := age.Decrypt(bytes.NewReader(sealed), id)
	if err != nil {
		return nil, errVaultOpen
	}
	padded, err := io.ReadAll(r)
	if err != nil {
		return nil, errVaultOpen
	}
	plain, err := vaultUnpad(padded)
	if err != nil {
		zero(padded)
		return nil, err
	}
	return plain, nil
}

func vaultSealB64(pub, b64 string) (string, error) {
	r, err := vaultRecipient(pub)
	if err != nil {
		return "", err
	}
	plain, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return "", errVaultData
	}
	defer zero(plain)
	sealed, err := vaultSeal(r, plain)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(sealed), nil
}

func vaultOpenB64(priv, b64 string) (string, error) {
	id, err := vaultIdentity(priv)
	if err != nil {
		return "", err
	}
	sealed, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return "", errVaultData
	}
	plain, err := vaultOpen(id, sealed)
	if err != nil {
		return "", err
	}
	defer zero(plain)
	return base64.StdEncoding.EncodeToString(plain), nil
}

// a json list of base64 items in, the same list opened out: base64 each, or
// null where one will not open, so a bad row does not hold up the rest
func vaultOpenManyJSON(priv, list string) (string, error) {
	id, err := vaultIdentity(priv)
	if err != nil {
		return "", err
	}
	var in []string
	if json.Unmarshal([]byte(list), &in) != nil {
		return "", errors.New("bad list")
	}
	out := make([]*string, len(in))
	for i, s := range in {
		sealed, err := base64.StdEncoding.DecodeString(s)
		if err != nil {
			continue
		}
		plain, err := vaultOpen(id, sealed)
		if err != nil {
			continue
		}
		b := base64.StdEncoding.EncodeToString(plain)
		zero(plain)
		out[i] = &b
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}

func vaultOut(s string, err error) *C.char {
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(s)
}

// {"pub": "age1...", "priv": "AGE-SECRET-KEY-1..."}
//
//export HaloVaultKeys
func HaloVaultKeys() *C.char {
	k, err := vaultNewKeys()
	if err != nil {
		return vaultOut("", err)
	}
	b, _ := json.Marshal(k)
	return C.CString(string(b))
}

// the bytes in b64 sealed to pub, as base64
//
//export HaloVaultSeal
func HaloVaultSeal(cPub, cB64 *C.char) *C.char {
	return vaultOut(vaultSealB64(goStr(cPub), goStr(cB64)))
}

// what HaloVaultSeal sealed, as base64
//
//export HaloVaultOpen
func HaloVaultOpen(cPriv, cB64 *C.char) *C.char {
	return vaultOut(vaultOpenB64(goStr(cPriv), goStr(cB64)))
}

// a json list of sealed base64 items, opened in one call: a list of base64,
// null where one will not open
//
//export HaloVaultOpenMany
func HaloVaultOpenMany(cPriv, cJSON *C.char) *C.char {
	return vaultOut(vaultOpenManyJSON(goStr(cPriv), goStr(cJSON)))
}
