// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"crypto/ed25519"
	"sync"
	"testing"
)

func swapInEdKey(t *testing.T, priv ed25519.PrivateKey) {
	mu.Lock()
	old, oldPub := myEdPriv, myEdPub
	myEdPriv = bytes.Clone(priv)
	myEdPub = priv.Public().(ed25519.PublicKey)
	mu.Unlock()
	t.Cleanup(func() {
		mu.Lock()
		myEdPriv, myEdPub = old, oldPub
		mu.Unlock()
	})
}

// a key handed out for a handle call or a drop still signs after a new
// identity zeroes the one it replaced
func TestAKeyInUseOutlivesANewIdentity(t *testing.T) {
	_, a, _ := ed25519.GenerateKey(nil)
	_, b, _ := ed25519.GenerateKey(nil)
	swapInEdKey(t, a)
	k := handleKey()
	secret, err := dropSecret()
	if err != nil {
		t.Fatal(err)
	}
	mu.Lock()
	setEdKeyLocked(bytes.Clone(b))
	mu.Unlock()
	msg := []byte("kryfo")
	if !ed25519.Verify(a.Public().(ed25519.PublicKey), msg, ed25519.Sign(k, msg)) {
		t.Fatal("the key in use was zeroed under its caller")
	}
	if !bytes.Equal(secret, dropMac(a.Seed(), "kryfo-files")) {
		t.Fatal("the drop secret changed under its caller")
	}
	if got := handleKey(); !bytes.Equal(got, b) {
		t.Fatal("the new key is not the one handed out")
	}
}

// signing beside a swap: no shared bytes, so -race stays quiet
func TestSigningBesideASwapIsRaceFree(t *testing.T) {
	_, a, _ := ed25519.GenerateKey(nil)
	swapInEdKey(t, a)
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		for range 200 {
			if k := handleKey(); k != nil {
				ed25519.Sign(k, []byte("x"))
				clear(k)
			}
		}
	}()
	go func() {
		defer wg.Done()
		for range 200 {
			_, n, _ := ed25519.GenerateKey(nil)
			mu.Lock()
			setEdKeyLocked(n)
			mu.Unlock()
		}
	}()
	wg.Wait()
}
