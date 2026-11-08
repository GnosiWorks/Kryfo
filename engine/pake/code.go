// SPDX-License-Identifier: GPL-3.0-or-later
package pake

import (
	"crypto/rand"
	"encoding/binary"
	"errors"
	"io"
	"strconv"
	"time"
	"unicode/utf8"
)

const (
	// SecretDigits never go on the wire: they are the cpace password
	SecretDigits = 6
	// BoxDigits are public and pick the rendezvous address
	BoxDigits = 2

	// WindowLength is how long one box address lives
	WindowLength = 10 * time.Minute

	ciPrefix = "kryfo-pair-v4:"
)

// ErrCode is a code that is not eight digits
var ErrCode = errors.New("pake: a pair code is eight digits")

// Code is a pair code: box then secret, NN NNN NNN on screen
type Code struct {
	box    [BoxDigits]byte
	secret [SecretDigits]byte
}

// NewCode draws a box and a secret, each uniform over its digits
func NewCode(rnd io.Reader) (Code, error) {
	if rnd == nil {
		rnd = rand.Reader
	}
	var c Code
	b, err := uniform(rnd, 100)
	if err != nil {
		return c, err
	}
	s, err := uniform(rnd, 1_000_000)
	if err != nil {
		return c, err
	}
	putDigits(c.box[:], b)
	putDigits(c.secret[:], s)
	return c, nil
}

// ParseCode takes the eight digits as typed. spaces, dashes and the marks
// text fields and copy-paste put around digits (bidi marks, no-break
// spaces, the non-breaking hyphen) are skipped, and arabic-indic, extended
// arabic-indic, devanagari and fullwidth digits read as ascii ones, so the
// password matches on both phones
func ParseCode(s string) (Code, error) { return ParseCodeBytes([]byte(s)) }

// ParseCodeBytes is ParseCode on the typed bytes, so the caller can clear
// them; nothing here keeps a copy
func ParseCodeBytes(s []byte) (Code, error) {
	var c Code
	var d [BoxDigits + SecretDigits]byte
	n, ok := codeDigits(s, d[:])
	if !ok || n != len(d) {
		wipe(d[:])
		return c, ErrCode
	}
	copy(c.box[:], d[:BoxDigits])
	copy(c.secret[:], d[BoxDigits:])
	wipe(d[:])
	return c, nil
}

// OldCode is six digits and nothing else: the code of a Kryfo before 0.6,
// which has no box and no pake, so nothing here can take it
func OldCode(s []byte) bool {
	var d [SecretDigits]byte
	n, ok := codeDigits(s, d[:])
	wipe(d[:])
	return ok && n == SecretDigits
}

// codeDigits folds the typed digits into d as ascii. false for any other
// character or more digits than d holds
func codeDigits(s []byte, d []byte) (int, bool) {
	n := 0
	for len(s) > 0 {
		r, size := utf8.DecodeRune(s)
		s = s[size:]
		if skipped(r) {
			continue
		}
		v, ok := digitOf(r)
		if !ok || n == len(d) {
			return n, false
		}
		d[n] = '0' + v
		n++
	}
	return n, true
}

// skipped is what may sit between typed digits
func skipped(r rune) bool {
	switch r {
	case ' ', '-', '\u00a0', '\u202f', '\u2011', '\u200e', '\u200f', '\u061c':
		return true
	}
	return r >= '\u2066' && r <= '\u2069'
}

func digitOf(r rune) (byte, bool) {
	for _, zero := range []rune{'0', '\u0660', '\u06f0', '\u0966', '\uff10'} {
		if r >= zero && r <= zero+9 {
			return byte(r - zero), true
		}
	}
	return 0, false
}

// Box is the public part, two ascii digits
func (c *Code) Box() string { return string(c.box[:]) }

// String is the code as shown: NN NNN NNN
func (c *Code) String() string {
	b := c.Shown()
	defer wipe(b)
	return string(b)
}

// Shown is String as bytes the caller can clear
func (c *Code) Shown() []byte {
	b := make([]byte, 0, BoxDigits+SecretDigits+2)
	b = append(b, c.box[:]...)
	b = append(b, ' ')
	b = append(b, c.secret[:3]...)
	b = append(b, ' ')
	return append(b, c.secret[3:]...)
}

// Wipe clears the secret digits
func (c *Code) Wipe() { wipe(c.secret[:]) }

// Window is the ten-minute window t falls in, as the box address and ci
// count it
func Window(t time.Time) uint64 {
	return uint64(t.Unix()) / uint64(WindowLength/time.Second)
}

// ci binds a run to its box and window: "kryfo-pair-v4:" || b || ":" || w,
// w in decimal
func channelID(box [BoxDigits]byte, w uint64) []byte {
	ci := append([]byte(ciPrefix), box[:]...)
	ci = append(ci, ':')
	return strconv.AppendUint(ci, w, 10)
}

// uniform draws below n by rejection, so no digit is more likely
func uniform(rnd io.Reader, n uint32) (uint32, error) {
	limit := ^uint32(0) - ^uint32(0)%n
	var b [4]byte
	for {
		if _, err := io.ReadFull(rnd, b[:]); err != nil {
			return 0, err
		}
		v := binary.BigEndian.Uint32(b[:])
		if v < limit {
			wipe(b[:])
			return v % n, nil
		}
	}
}

func putDigits(dst []byte, v uint32) {
	for i := len(dst) - 1; i >= 0; i-- {
		dst[i] = '0' + byte(v%10)
		v /= 10
	}
}
