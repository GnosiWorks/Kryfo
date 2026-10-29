// SPDX-License-Identifier: GPL-3.0-or-later

// Package pake runs pair codes: CPace (draft-irtf-cfrg-cpace-21, suite
// CPACE-X25519-SHA512, initiator-responder) and the KPO1, KPA1 and KPF1
// messages around it.
package pake

import (
	"crypto/sha512"
	"errors"

	"filippo.io/edwards25519/field"
	"gitlab.com/yawning/edwards25519-extra/elligator2"
	"golang.org/x/crypto/curve25519"
)

const (
	// PointSize is an x25519 u coordinate
	PointSize = 32
	// ScalarSize is a cpace scalar before clamping
	ScalarSize = 32
	// ISKSize is a sha-512 output
	ISKSize = 64

	dsi    = "CPace255"
	dsiISK = "CPace255_ISK"
	// sha-512 input block size
	hashBlock = 128
)

// ErrLowOrder is a share that puts K at the neutral element
var ErrLowOrder = errors.New("pake: low order share")

// prependLen puts the leb128 length of data before it
func prependLen(out, data []byte) []byte {
	n := len(data)
	for {
		if n < 128 {
			out = append(out, byte(n))
		} else {
			out = append(out, byte(n&0x7f)|0x80)
		}
		n >>= 7
		if n == 0 {
			break
		}
	}
	return append(out, data...)
}

func lvCat(out []byte, parts ...[]byte) []byte {
	for _, p := range parts {
		out = prependLen(out, p)
	}
	return out
}

// lebLen is len(prependLen(nil, data)) without building it
func lebLen(data []byte) int {
	n, l := len(data), 1
	for n >= 128 {
		n >>= 7
		l++
	}
	return l + len(data)
}

// generatorString is lv_cat(DSI, PRS, zero_bytes(len_zpad), CI, sid)
func generatorString(prs, ci, sid []byte) []byte {
	zpad := max(0, hashBlock-1-lebLen(prs)-lebLen([]byte(dsi)))
	return lvCat(nil, []byte(dsi), prs, make([]byte, zpad), ci, sid)
}

// generator maps prs, ci and sid to a point with elligator2
func generator(prs, ci, sid []byte) [PointSize]byte {
	gs := generatorString(prs, ci, sid)
	h := sha512.Sum512(gs)
	wipe(gs)
	// SetBytes drops bit 255 and reduces, as decodeUCoordinate does
	r, err := new(field.Element).SetBytes(h[:PointSize])
	wipe(h[:])
	if err != nil {
		panic("pake: field element of 32 bytes refused")
	}
	u, _ := elligator2.MontgomeryFlavor(r)
	var g [PointSize]byte
	copy(g[:], u.Bytes())
	r.Zero()
	u.Zero()
	return g
}

// scalarMult is X25519, refusing the neutral element. both sides use it
// for their own share and for K, as the draft has scalar_mult equal to
// scalar_mult_vfy for this group
func scalarMult(y *[ScalarSize]byte, p []byte) ([PointSize]byte, error) {
	var out [PointSize]byte
	if len(p) != PointSize {
		return out, ErrLowOrder
	}
	k, err := curve25519.X25519(y[:], p)
	if err != nil {
		// x25519 refuses an all-zero result: a low order point on the
		// curve or the twist
		return out, ErrLowOrder
	}
	copy(out[:], k)
	wipe(k)
	return out, nil
}

// isk is H(lv_cat(DSI_ISK, sid, K) || transcript_ir(Ya, ADa, Yb, ADb))
func isk(sid, k, ya, ada, yb, adb []byte) [ISKSize]byte {
	buf := lvCat(nil, []byte(dsiISK), sid, k)
	buf = lvCat(buf, ya, ada, yb, adb)
	out := sha512.Sum512(buf)
	wipe(buf)
	return out
}

// canonical says p is a u coordinate below 2^255 - 19 with bit 255 clear,
// the only encoding x25519 itself ever puts out
func canonical(p []byte) bool {
	if len(p) != PointSize || p[31]&0x80 != 0 {
		return false
	}
	e, err := new(field.Element).SetBytes(p)
	if err != nil {
		return false
	}
	return string(e.Bytes()) == string(p)
}

func wipe(b []byte) { clear(b) }
