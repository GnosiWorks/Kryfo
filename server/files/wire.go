// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the shape of a file on the wire, as the engine writes it (engine/filedrop.go).
// a file is sealed on the phone in chunks of 64 KiB, each chunk 16 bytes
// longer once sealed, and the chunk count is rounded up so the stored size
// says little about the real one. the service only ever sees sealed bytes.

import (
	"crypto/sha256"
	"encoding/hex"
	"math/bits"
	"regexp"
	"strconv"
	"time"
)

const (
	chunkPlain  = 64 << 10
	chunkSealed = chunkPlain + 16
	// a part is 80 sealed chunks: the 5 MiB floor an s3 multipart part
	// needs, so an s3 store can take the parts as they come
	partChunks = 80
	partSize   = partChunks * chunkSealed
	// recipients one file may name: a group's members, each with a token
	maxGot = 256
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

func hashHex(s string) string {
	b, err := hex.DecodeString(s)
	if err != nil {
		return ""
	}
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

// a sender's key for one day costs a little work to make: the daily limit
// counts per key, and a key for free would make the limit free to dodge
func powText(day, who string, nonce uint64) string {
	return "kryfo-files-v1:" + day + ":" + who + ":" + strconv.FormatUint(nonce, 10)
}

func powOK(day, who string, nonce uint64, want int) bool {
	h := sha256.Sum256([]byte(powText(day, who, nonce)))
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

// the day a key is for: this box's day, the one before or the one after, so
// a phone near midnight on another clock still sends
func dayOK(day string, now time.Time) bool {
	for _, d := range []int{-1, 0, 1} {
		if now.UTC().AddDate(0, 0, d).Format("2006-01-02") == day {
			return true
		}
	}
	return false
}
