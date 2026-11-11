// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"testing"
)

// a chunk key crosses once: the bytes it came in are cleared, every chunk
// names it by its handle, and a dropped handle opens nothing
func TestChunkKeyHandle(t *testing.T) {
	key := bytes.Repeat([]byte{0x5a}, 32)
	h := chunkKeyOpen(key)
	if h <= 0 {
		t.Fatalf("handle %d", h)
	}
	if !bytes.Equal(key, make([]byte, 32)) {
		t.Fatal("the key bytes are not cleared")
	}
	plain := []byte("a slice of a photo")
	sealed := make([]byte, len(plain)+16)
	if n := sealChunkAt(h, 7, 2, plain, sealed); n != len(sealed) {
		t.Fatalf("sealed %d", n)
	}
	out := make([]byte, len(sealed))
	if n := openChunkAt(h, 7, 2, sealed, out); n != len(plain) ||
		!bytes.Equal(out[:n], plain) {
		t.Fatalf("opened %d", n)
	}
	if openChunkAt(h, 8, 2, sealed, out) != -1 || openChunkAt(h, 7, 1, sealed, out) != -1 {
		t.Fatal("opened at another place or type")
	}
	// the same key under a second handle reads it: one cipher per handle
	h2 := chunkKeyOpen(bytes.Repeat([]byte{0x5a}, 32))
	if h2 == h || openChunkAt(h2, 7, 2, sealed, out) != len(plain) {
		t.Fatal("a second handle on the same key")
	}
	chunkKeyDrop(h)
	if openChunkAt(h, 7, 2, sealed, out) != -1 || sealChunkAt(h, 7, 2, plain, sealed) != -1 {
		t.Fatal("a dropped handle still works")
	}
	chunkKeyDrop(h2)
	if chunkKeyOpen(make([]byte, 31)) != 0 {
		t.Fatal("a short key took a handle")
	}
	if sealChunkAt(0, 0, 0, plain, sealed) != -1 {
		t.Fatal("handle 0 sealed")
	}
}

// what a too small buffer would overrun is refused
func TestChunkSealRoom(t *testing.T) {
	h := chunkKeyOpen(bytes.Repeat([]byte{1}, 32))
	defer chunkKeyDrop(h)
	if sealChunkAt(h, 0, 0, make([]byte, 10), make([]byte, 25)) != -1 {
		t.Fatal("sealed into a buffer without room for the tag")
	}
}

func TestHexSecret(t *testing.T) {
	b, ok := hexSecret([]byte("00ff10"), 3)
	if !ok || !bytes.Equal(b, []byte{0, 0xff, 0x10}) {
		t.Fatalf("%x %v", b, ok)
	}
	for _, bad := range []string{"00ff1", "00ff1g", "00ff10aa"} {
		if _, ok := hexSecret([]byte(bad), 3); ok {
			t.Fatalf("%q taken", bad)
		}
	}
}

// a dropped identity leaves no key and no seed behind. the zeros identDrop
// lays over the map slots first cannot be seen from a test: only that
// nothing is held any more
func TestIdentDropClears(t *testing.T) {
	const ident = 41
	putIdentity(ident, xid{priv: [32]byte{9}, pub: [32]byte{8}})
	identsMu.Lock()
	pairSeeds[pairKey{ident, "ab"}] = [32]byte{7}
	identsMu.Unlock()
	identDrop(ident)
	if _, err := identityOf(ident); err == nil {
		t.Fatal("still held")
	}
	identsMu.Lock()
	_, seeded := pairSeeds[pairKey{ident, "ab"}]
	identsMu.Unlock()
	if seeded {
		t.Fatal("the seed is still held")
	}
}
