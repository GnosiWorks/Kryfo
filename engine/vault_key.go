// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !android

// the desktop vault's key: scrypt of the passphrase at a cost the desktop
// sets. phones keep their keys in the keystore and never call this
package main

import "C"

import (
	"encoding/hex"
	"unsafe"

	"golang.org/x/crypto/scrypt"
)

const (
	vaultLogNMin = 15
	vaultLogNMax = 20
)

func vaultKey(pass, salt []byte, logN int) (string, bool) {
	if logN < vaultLogNMin || logN > vaultLogNMax || len(salt) != 16 {
		return "", false
	}
	key, err := scrypt.Key(pass, salt, 1<<logN, 8, 1, 32)
	if err != nil {
		return "", false
	}
	out := hex.EncodeToString(key)
	clear(key)
	return out, true
}

// salt is exactly 16 bytes. returns the key as hex, or "error".
//
//export HaloVaultKey
func HaloVaultKey(cPassphrase *C.char, cSalt *C.uchar, logN C.int) *C.char {
	salt := C.GoBytes(unsafe.Pointer(cSalt), 16)
	pass := []byte(goStr(cPassphrase))
	k, ok := vaultKey(pass, salt, int(logN))
	clear(pass)
	if !ok {
		return C.CString("error")
	}
	return C.CString(k)
}
