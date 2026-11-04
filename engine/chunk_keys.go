// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a chunk key held for a backup, a restore or the desktop vault: the key
// crosses once, as bytes, and every chunk names it by a handle. go never
// holds the key itself past the open, only its cipher

import "C"

import (
	"crypto/cipher"
	"sync"
	"unsafe"
)

var chunkKeys = struct {
	sync.Mutex
	next int64
	m    map[int64]cipher.AEAD
}{m: map[int64]cipher.AEAD{}}

// a handle for [key], cleared here once its cipher is made; 0 when it
// is no key
func chunkKeyOpen(key []byte) int64 {
	defer clear(key)
	gcm, err := backupGCM(key)
	if err != nil {
		return 0
	}
	chunkKeys.Lock()
	defer chunkKeys.Unlock()
	chunkKeys.next++
	chunkKeys.m[chunkKeys.next] = gcm
	return chunkKeys.next
}

func chunkKeyOf(h int64) cipher.AEAD {
	chunkKeys.Lock()
	defer chunkKeys.Unlock()
	return chunkKeys.m[h]
}

func chunkKeyDrop(h int64) {
	chunkKeys.Lock()
	defer chunkKeys.Unlock()
	delete(chunkKeys.m, h)
}

// 32 key bytes at [cKey] (dart zeroes its copy): a handle above 0, or 0
//
//export HaloChunkKeyOpen
func HaloChunkKeyOpen(cKey *C.uchar, n C.int) C.longlong {
	if cKey == nil || n != 32 {
		return 0
	}
	return C.longlong(chunkKeyOpen(C.GoBytes(unsafe.Pointer(cKey), n)))
}

// the handle let go: no chunk opens under it again
//
//export HaloChunkKeyDrop
func HaloChunkKeyDrop(h C.longlong) { chunkKeyDrop(int64(h)) }
