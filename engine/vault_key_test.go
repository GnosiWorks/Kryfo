// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !android

package main

import (
	"bytes"
	"testing"
)

func TestVaultKeyCost(t *testing.T) {
	salt := bytes.Repeat([]byte{7}, 16)
	a, ok := vaultKey([]byte("four random words here"), salt, 15)
	if !ok || len(a) != 32 {
		t.Fatalf("no key: %x", a)
	}
	b, _ := vaultKey([]byte("four random words here"), salt, 16)
	if bytes.Equal(a, b) {
		t.Fatal("the cost does not change the key")
	}
	for _, n := range []int{14, 21} {
		if _, ok := vaultKey([]byte("x"), salt, n); ok {
			t.Fatalf("cost 2^%d taken", n)
		}
	}
	if _, ok := vaultKey([]byte("x"), salt[:15], 15); ok {
		t.Fatal("a short salt taken")
	}
}

func BenchmarkVaultKey17(b *testing.B) {
	salt := bytes.Repeat([]byte{7}, 16)
	for range b.N {
		vaultKey([]byte("four random words here"), salt, 17)
	}
}
