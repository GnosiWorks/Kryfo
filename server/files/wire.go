// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the shape of a file on the wire, as the engine writes it (engine/filedrop.go).
// a file is sealed on the phone in chunks of 64 KiB, each chunk 16 bytes
// longer once sealed, and the chunk count is rounded up so the stored size
// says little about the real one. the service only ever sees sealed bytes.

import (
	"crypto/sha256"
	"math/bits"
	"regexp"
	"strconv"
)

const (
	chunkPlain  = 64 << 10
	chunkSealed = chunkPlain + 16
	// a part is 80 sealed chunks: the 5 MiB floor an s3 multipart part
	// needs, so an s3 store can take the parts as they come
	partChunks = 80
	partSize   = partChunks * chunkSealed
	// recipients one file may name: a group's other members (50 at most),
	// each with a token, and room to spare
	maxGot = 64
)

// the chunk count a file of n chunks is stored as: n up to 16, past that
// rounded up to k*2^e with k in 8..15, so at most 1/8 more
func padChunks(n int) int {
	if n <= 16 {
		return n
	}
	e := bits.Len(uint(n)) - 4
	step := 1 << e
	return (n + step - 1) / step * step
}

// the most sealed bytes a file of maxPlain bytes can take
func maxSealed(maxPlain int64) int64 {
	n := int((maxPlain + chunkPlain - 1) / chunkPlain)
	return int64(padChunks(n)) * chunkSealed
}

var (
	idShape  = regexp.MustCompile(`^[0-9a-f]{32}$`)
	keyShape = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// each upload costs a little work, bound to that file: its id and its size,
// more for a bigger file. nothing in it is the sender's, so two uploads from
// one person share nothing the service can see
func powBits(base int, size int64) int {
	return base + bits.Len64(uint64(size>>20))
}

func powText(id string, size int64, nonce uint64) string {
	return "kryfo-files-v2:" + id + ":" + strconv.FormatInt(size, 10) + ":" + strconv.FormatUint(nonce, 10)
}

func powOK(id string, size int64, nonce uint64, want int) bool {
	h := sha256.Sum256([]byte(powText(id, size, nonce)))
	got := 0
	for _, b := range h {
		if b == 0 {
			got += 8
			continue
		}
		got += bits.LeadingZeros8(b)
		break
	}
	return got >= want
}
