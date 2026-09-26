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

func vaultSeal(r *age.X25519Recipient, plain []byte) ([]byte, error) {
	var out bytes.Buffer
	w, err := age.Encrypt(&out, r)
	if err != nil {
		return nil, errVaultSeal
	}
	if _, err := w.Write(plain); err != nil {
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
	plain, err := io.ReadAll(r)
	if err != nil {
		return nil, errVaultOpen
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
	return vaultOut(vaultSealB64(C.GoString(cPub), C.GoString(cB64)))
}

// what HaloVaultSeal sealed, as base64
//
//export HaloVaultOpen
func HaloVaultOpen(cPriv, cB64 *C.char) *C.char {
	return vaultOut(vaultOpenB64(C.GoString(cPriv), C.GoString(cB64)))
}

// a json list of sealed base64 items, opened in one call: a list of base64,
// null where one will not open
//
//export HaloVaultOpenMany
func HaloVaultOpenMany(cPriv, cJSON *C.char) *C.char {
	return vaultOut(vaultOpenManyJSON(C.GoString(cPriv), C.GoString(cJSON)))
}
