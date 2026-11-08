// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !android

// the desktop vault's key: scrypt of the passphrase at a cost the desktop
// sets. phones keep their keys in the keystore and never call this
package main

import "C"

import (
	"unsafe"

	"golang.org/x/crypto/scrypt"
)

const (
	vaultLogNMin = 15
	vaultLogNMax = 20
)

// the key's bytes, which the caller clears
func vaultKey(pass, salt []byte, logN int) ([]byte, bool) {
	if logN < vaultLogNMin || logN > vaultLogNMax || len(salt) != 16 {
		return nil, false
	}
	key, err := scrypt.Key(pass, salt, 1<<logN, 8, 1, 32)
	if err != nil {
		return nil, false
	}
	return key, true
}

// salt is exactly 16 bytes. returns the key as hex, or "error". the
// passphrase and the key are cleared here
//
//export HaloVaultKey
func HaloVaultKey(cPassphrase *C.char, cSalt *C.uchar, logN C.int) *C.char {
	salt := C.GoBytes(unsafe.Pointer(cSalt), 16)
	pass := goSecret(cPassphrase)
	k, ok := vaultKey(pass, salt, int(logN))
	clear(pass)
	if !ok {
		return C.CString("error")
	}
	defer clear(k)
	return cHexSecret(k)
}
