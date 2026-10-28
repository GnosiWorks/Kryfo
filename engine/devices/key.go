// SPDX-License-Identifier: GPL-3.0-or-later

// Package devices is linked devices on identity v4: the signed device list
// (KDL2), a device's bundle (KDB1), what contacts keep, and linking.
package devices

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"

	"filippo.io/edwards25519"
	"filippo.io/edwards25519/field"
)

// KeySize is a libsignal curve key on the wire: 0x05, then u.
const KeySize = 33

// Key is a libsignal curve key in its one canonical encoding.
type Key [KeySize]byte

func (k Key) String() string { return hex.EncodeToString(k[:]) }

var ErrKey = errors.New("devices: not a canonical key")

// ParseKey takes a key only in the form libsignal's is_canonical accepts:
// exactly 33 bytes, 0x05 first, u below p with the top bit clear, on the
// curve and torsion free. libsignal itself reads trailing bytes and ignores
// the top bit, so every compare here is on these bytes alone.
func ParseKey(b []byte) (Key, error) {
	var k Key
	if len(b) != KeySize || b[0] != 0x05 || !canonicalU(b[1:]) {
		return k, ErrKey
	}
	copy(k[:], b)
	return k, nil
}

// the scalar 1/8 mod l, for the torsion check
var invEight = func() *edwards25519.Scalar {
	var b [32]byte
	b[0] = 8
	s, err := edwards25519.NewScalar().SetCanonicalBytes(b[:])
	if err != nil {
		panic(err)
	}
	return edwards25519.NewScalar().Invert(s)
}()

// the same rules as libsignal's PublicKey::is_canonical, in the same order
func canonicalU(u []byte) bool {
	if len(u) != 32 || u[31]&0x80 != 0 {
		return false
	}
	if u[31] == 0x7f && u[0] >= 0xed {
		high := true
		for _, c := range u[1:31] {
			if c != 0xff {
				high = false
				break
			}
		}
		if high {
			return false
		}
	}
	var fu field.Element
	if _, err := fu.SetBytes(u); err != nil {
		return false
	}
	one := new(field.Element).One()
	den := new(field.Element).Add(&fu, one)
	if den.Equal(new(field.Element).Zero()) == 1 {
		return false
	}
	// birational map to edwards with sign 0, as to_edwards(0) does. a twist
	// point has no edwards point and fails here
	y := new(field.Element).Subtract(&fu, one)
	y.Multiply(y, new(field.Element).Invert(den))
	p, err := new(edwards25519.Point).SetBytes(y.Bytes())
	if err != nil {
		return false
	}
	// p is torsion free when clearing the cofactor and undoing it gives p
	q := new(edwards25519.Point).MultByCofactor(p)
	q.ScalarMult(invEight, q)
	return q.Equal(p) == 1
}

// KyberSize is a kyber1024 public key with libsignal's type byte.
const KyberSize = 1569

// a kyber key here is only its shape; libsignal reads the rest when the
// bundle is built
func kyberShape(b []byte) bool { return len(b) == KyberSize && b[0] == 0x08 }

const keyNumberDomain = "kryfo key number v1"

// KeyNumber is the 20 digits the pair-code screens show for an identity
// key (key_number.dart), so a linked device shows the same number the
// phone shows for itself.
func KeyNumber(k Key) string {
	h := sha256.New()
	h.Write([]byte(keyNumberDomain))
	h.Write([]byte{0})
	h.Write(k[:])
	d := h.Sum(nil)
	var out []byte
	for i := range 4 {
		var b [8]byte
		copy(b[3:], d[5*i:5*i+5])
		if i > 0 {
			out = append(out, ' ')
		}
		out = fmt.Appendf(out, "%05d", binary.BigEndian.Uint64(b[:])%100000)
	}
	return string(out)
}

func wipe(b []byte) {
	for i := range b {
		b[i] = 0
	}
}
