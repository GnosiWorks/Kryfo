// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the v4 invite (KIN4) as the shim reads it (mobile/native/kryfo_signal,
// src/formats.rs), for the one thing the registry needs: that a handle
// points at a well formed invite whose face is the key that claimed it.
// big endian, fixed widths, every key in its one form, no trailing bytes,
// encoded again and compared, and only then the signatures. the module has
// no dependencies, so the curve work below is math/big and crypto/ed25519.
// it is slow next to the shim and only ever sees a claim or the gate.

import (
	"bytes"
	"crypto/ed25519"
	"encoding/binary"
	"errors"
	"math/big"
)

var (
	errFormat    = errors.New("kin4: format")
	errSignature = errors.New("kin4: signature")
)

const (
	kinOneTime = 1 << 0
	kinBundle  = 1 << 1
	kinOnion   = 1 << 2
	kinFace    = 1 << 3
	kinDevices = 1 << 4

	kinMaxLife  = 9000
	kyberLen    = 1569
	maxDevices  = 6
	phoneDevice = 1
)

var faceText = []byte("kryfo-face-v4:")

var (
	fieldP = new(big.Int).Sub(new(big.Int).Lsh(big.NewInt(1), 255), big.NewInt(19))
	// the ed25519 group order
	orderL, _ = new(big.Int).SetString("7237005577332262213973186563042994240857116359379907606001950938285454250989", 10)
	// d = -121665 / 121666
	edD = func() *big.Int {
		d := new(big.Int).ModInverse(big.NewInt(121666), fieldP)
		d.Mul(d, big.NewInt(-121665))
		return d.Mod(d, fieldP)
	}()
	edD2  = new(big.Int).Mod(new(big.Int).Lsh(edD, 1), fieldP)
	secpP = func() *big.Int {
		p, _ := new(big.Int).SetString("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f", 16)
		return p
	}()
)

// little endian bytes as a number
func leInt(b []byte) *big.Int {
	r := make([]byte, len(b))
	for i := range b {
		r[len(b)-1-i] = b[i]
	}
	return new(big.Int).SetBytes(r)
}

func le32(n *big.Int) []byte {
	out := make([]byte, 32)
	b := n.Bytes()
	for i := range b {
		out[i] = b[len(b)-1-i]
	}
	return out
}

func fmod(n *big.Int) *big.Int { return n.Mod(n, fieldP) }

func fmul(a, b *big.Int) *big.Int { return fmod(new(big.Int).Mul(a, b)) }

// an edwards point in extended coordinates
type edPoint struct{ x, y, z, t *big.Int }

func edIdentity() edPoint {
	return edPoint{big.NewInt(0), big.NewInt(1), big.NewInt(1), big.NewInt(0)}
}

// the unified addition for a = -1, complete on this curve
func edAdd(p, q edPoint) edPoint {
	a := fmul(new(big.Int).Sub(p.y, p.x), new(big.Int).Sub(q.y, q.x))
	b := fmul(new(big.Int).Add(p.y, p.x), new(big.Int).Add(q.y, q.x))
	c := fmul(fmul(p.t, edD2), q.t)
	d := fmul(new(big.Int).Lsh(p.z, 1), q.z)
	e := fmod(new(big.Int).Sub(b, a))
	f := fmod(new(big.Int).Sub(d, c))
	g := fmod(new(big.Int).Add(d, c))
	h := fmod(new(big.Int).Add(b, a))
	return edPoint{fmul(e, f), fmul(g, h), fmul(f, g), fmul(e, h)}
}

func edMul(p edPoint, k *big.Int) edPoint {
	r := edIdentity()
	for i := k.BitLen() - 1; i >= 0; i-- {
		r = edAdd(r, r)
		if k.Bit(i) == 1 {
			r = edAdd(r, p)
		}
	}
	return r
}

func (p edPoint) isIdentity() bool {
	return p.x.Sign() == 0 && p.y.Cmp(p.z) == 0
}

// y below p and a point on the curve; x zero with the sign set is a second
// encoding of the same point and refused
func edDecode(b []byte) (edPoint, bool) {
	if len(b) != 32 {
		return edPoint{}, false
	}
	yb := bytes.Clone(b)
	sign := yb[31] >> 7
	yb[31] &= 0x7f
	y := leInt(yb)
	if y.Cmp(fieldP) >= 0 {
		return edPoint{}, false
	}
	// x^2 = (y^2 - 1) / (d y^2 + 1)
	yy := fmul(y, y)
	num := fmod(new(big.Int).Sub(yy, big.NewInt(1)))
	den := fmod(new(big.Int).Add(fmul(edD, yy), big.NewInt(1)))
	xx := fmul(num, new(big.Int).ModInverse(den, fieldP))
	x := new(big.Int).ModSqrt(xx, fieldP)
	if x == nil {
		return edPoint{}, false
	}
	if x.Sign() == 0 && sign == 1 {
		return edPoint{}, false
	}
	if uint8(x.Bit(0)) != sign {
		x.Sub(fieldP, x)
	}
	return edPoint{x, y, big.NewInt(1), fmul(x, y)}, true
}

func torsionFree(p edPoint) bool { return edMul(p, orderL).isIdentity() }

// a curve key as libsignal's PublicKey::is_canonical takes it: 33 bytes,
// 0x05, u below p with the top bit clear, a point of the curve (not its
// twist) in the prime order group
func strictPublic(k []byte) bool {
	if len(k) != 33 || k[0] != 0x05 || k[32]&0x80 != 0 {
		return false
	}
	u := leInt(k[1:])
	if u.Cmp(fieldP) >= 0 {
		return false
	}
	den := fmod(new(big.Int).Add(u, big.NewInt(1)))
	if den.Sign() == 0 {
		return false
	}
	y := fmul(fmod(new(big.Int).Sub(u, big.NewInt(1))), new(big.Int).ModInverse(den, fieldP))
	p, ok := edDecode(le32(y))
	return ok && torsionFree(p)
}

// an ed25519 key in its one encoding, in the prime order group
func strictEd(b []byte) bool {
	p, ok := edDecode(b)
	if !ok {
		return false
	}
	return !edMul(p, big.NewInt(8)).isIdentity() && torsionFree(p)
}

// s below l, as the 32 bytes stand
func edSigCanonical(sig []byte) bool {
	return len(sig) == 64 && leInt(sig[32:]).Cmp(orderL) < 0
}

// an xeddsa signature: s without its sign bit below l
func xedSigCanonical(sig []byte) bool {
	if len(sig) != 64 {
		return false
	}
	s := bytes.Clone(sig[32:])
	s[31] &= 0x7f
	return leInt(s).Cmp(orderL) < 0
}

// xeddsa as libsignal checks it: the edwards key from u with the sign bit
// the signature carries, then ed25519 over the message as it is
func xedVerify(key, msg, sig []byte) bool {
	if !strictPublic(key) || !xedSigCanonical(sig) {
		return false
	}
	u := leInt(key[1:])
	y := fmul(fmod(new(big.Int).Sub(u, big.NewInt(1))), new(big.Int).ModInverse(fmod(new(big.Int).Add(u, big.NewInt(1))), fieldP))
	a := le32(y)
	a[31] |= sig[63] & 0x80
	s := bytes.Clone(sig)
	s[63] &= 0x7f
	return ed25519.Verify(a, msg, s)
}

// what the shim signs under a context (src/sig.rs, signed_text)
func signedText(context string, body []byte) []byte {
	t := append([]byte("kryfo-sig-v1\x00"+context+"\x00"), body...)
	return t
}

// whether 32 bytes are the x of a secp256k1 point: below p and x^3 + 7 a
// square
func secpLifts(b []byte) bool {
	if len(b) != 32 {
		return false
	}
	x := new(big.Int).SetBytes(b)
	if x.Cmp(secpP) >= 0 {
		return false
	}
	r := new(big.Int).Exp(x, big.NewInt(3), secpP)
	r.Add(r, big.NewInt(7)).Mod(r, secpP)
	e := new(big.Int).Rsh(new(big.Int).Sub(secpP, big.NewInt(1)), 1)
	return new(big.Int).Exp(r, e, secpP).Cmp(big.NewInt(1)) == 0
}

// a reader that never reads past the end and says so once
type kinReader struct {
	b   []byte
	bad bool
}

func (r *kinReader) take(n int) []byte {
	if r.bad || n > len(r.b) {
		r.bad = true
		return make([]byte, n)
	}
	out := r.b[:n]
	r.b = r.b[n:]
	return out
}

func (r *kinReader) u8() byte    { return r.take(1)[0] }
func (r *kinReader) u16() int    { return int(binary.BigEndian.Uint16(r.take(2))) }
func (r *kinReader) u32() uint32 { return binary.BigEndian.Uint32(r.take(4)) }
func (r *kinReader) u64() uint64 { return binary.BigEndian.Uint64(r.take(8)) }

// a curve key, or the reader goes bad
func (r *kinReader) key() []byte {
	k := r.take(33)
	if !r.bad && !strictPublic(k) {
		r.bad = true
	}
	return k
}

func (r *kinReader) sig() []byte {
	s := r.take(64)
	if !r.bad && !xedSigCanonical(s) {
		r.bad = true
	}
	return s
}

func u32be(out []byte, v uint32) []byte { return binary.BigEndian.AppendUint32(out, v) }

type kinBlock struct {
	reg      uint32
	device   byte
	key      []byte // nil: the bundle runs on the frame's identity
	spkID    uint32
	spk      []byte
	spkSig   []byte
	kyberID  uint32
	kyber    []byte
	kyberSig []byte
	hasEC    bool
	ecID     uint32
	ec       []byte
}

func readBlock(r *kinReader, frame []byte) (*kinBlock, error) {
	b := &kinBlock{}
	b.reg = r.u32()
	b.device = r.u8()
	f := r.u8()
	if r.bad || b.reg == 0 || b.device < 1 || b.device > 127 || f&^3 != 0 {
		return nil, errFormat
	}
	if f&1 != 0 {
		b.key = r.key()
		if r.bad || bytes.Equal(b.key, frame) {
			return nil, errFormat
		}
	}
	// the phone is device 1 and runs on the identity, every other device
	// on a key of its own
	if (b.key != nil) == (b.device == phoneDevice) {
		return nil, errFormat
	}
	b.spkID = r.u32()
	b.spk = r.key()
	b.spkSig = r.sig()
	b.kyberID = r.u32()
	b.kyber = r.take(kyberLen)
	if !r.bad && b.kyber[0] != 0x08 {
		r.bad = true
	}
	b.kyberSig = r.sig()
	if f&2 != 0 {
		b.hasEC = true
		b.ecID = r.u32()
		b.ec = r.key()
		if !r.bad && bytes.Equal(b.ec, b.spk) {
			return nil, errFormat
		}
	}
	if r.bad {
		return nil, errFormat
	}
	return b, nil
}

func (b *kinBlock) encode(out []byte) []byte {
	var f byte
	if b.key != nil {
		f |= 1
	}
	if b.hasEC {
		f |= 2
	}
	out = u32be(out, b.reg)
	out = append(out, b.device, f)
	out = append(out, b.key...)
	out = u32be(out, b.spkID)
	out = append(out, b.spk...)
	out = append(out, b.spkSig...)
	out = u32be(out, b.kyberID)
	out = append(out, b.kyber...)
	out = append(out, b.kyberSig...)
	if b.hasEC {
		out = u32be(out, b.ecID)
		out = append(out, b.ec...)
	}
	return out
}

type kinEntry struct {
	device         byte
	key            []byte
	reg            uint32
	phone, answers bool
}

// a KDL2, signed
type kinList struct {
	identity []byte
	version  uint64
	entries  []kinEntry
	sig      []byte
}

func readList(r *kinReader) (*kinList, error) {
	l := &kinList{}
	if string(r.take(4)) != "KDL2" {
		return nil, errFormat
	}
	l.identity = r.key()
	l.version = r.u64()
	n := int(r.u8())
	if r.bad || n < 1 || n > maxDevices || l.version >= 1<<63 {
		return nil, errFormat
	}
	var after byte
	for range n {
		e := kinEntry{device: r.u8(), key: r.key(), reg: r.u32()}
		f := r.u8()
		e.phone, e.answers = f&1 != 0, f&2 != 0
		// sorted, so each list has one order
		if r.bad || e.device <= after || e.device > 127 || e.phone != (e.device == phoneDevice) ||
			e.reg == 0 || f&^3 != 0 {
			return nil, errFormat
		}
		after = e.device
		l.entries = append(l.entries, e)
	}
	phones, answering := 0, 0
	for i, e := range l.entries {
		if e.phone {
			phones++
			// the phone runs on the identity and never answers
			if !bytes.Equal(e.key, l.identity) || e.answers {
				return nil, errFormat
			}
		} else if bytes.Equal(e.key, l.identity) {
			return nil, errFormat
		}
		if e.answers {
			answering++
		}
		for _, o := range l.entries[:i] {
			if bytes.Equal(o.key, e.key) {
				return nil, errFormat
			}
		}
	}
	if phones != 1 || answering > 1 {
		return nil, errFormat
	}
	l.sig = r.sig()
	if r.bad {
		return nil, errFormat
	}
	return l, nil
}

func (l *kinList) body() []byte {
	out := append([]byte("KDL2"), l.identity...)
	out = binary.BigEndian.AppendUint64(out, l.version)
	out = append(out, byte(len(l.entries)))
	for _, e := range l.entries {
		var f byte
		if e.phone {
			f |= 1
		}
		if e.answers {
			f |= 2
		}
		out = append(out, e.device)
		out = append(out, e.key...)
		out = u32be(out, e.reg)
		out = append(out, f)
	}
	return out
}

func (l *kinList) answering() *kinEntry {
	for i := range l.entries {
		if l.entries[i].answers {
			return &l.entries[i]
		}
	}
	return nil
}

type kin4 struct {
	oneTime         bool
	issued, expires uint32
	id              []byte
	identity        []byte
	firstContact    []byte
	onion           []byte
	face, faceSig   []byte
	block           *kinBlock
	list            *kinList
	sig             []byte
}

func (k *kin4) flags() uint16 {
	var f uint16
	if k.oneTime {
		f |= kinOneTime
	}
	if k.block != nil {
		f |= kinBundle
	}
	if k.onion != nil {
		f |= kinOnion
	}
	if k.face != nil {
		f |= kinFace
	}
	if k.list != nil {
		f |= kinDevices
	}
	return f
}

func (k *kin4) body() []byte {
	out := append([]byte("KIN4"), 1)
	out = binary.BigEndian.AppendUint16(out, k.flags())
	out = u32be(out, k.issued)
	out = u32be(out, k.expires)
	out = append(out, k.id...)
	out = append(out, k.identity...)
	out = append(out, k.firstContact...)
	out = append(out, k.onion...)
	out = append(out, k.face...)
	out = append(out, k.faceSig...)
	if k.block != nil {
		out = k.block.encode(out)
	}
	if k.list != nil {
		l := append(k.list.body(), k.list.sig...)
		out = binary.BigEndian.AppendUint16(out, uint16(len(l)))
		out = append(out, l...)
	}
	return out
}

// parseKIN4 reads a signed KIN4 and checks every signature in it: the face,
// both prekey signatures, the device list and the invite's own. the times
// are only checked against each other, never against a clock: the registry
// keeps what was claimed, and the reader judges the times.
func parseKIN4(p []byte) (*kin4, error) {
	r := &kinReader{b: p}
	k := &kin4{}
	if string(r.take(4)) != "KIN4" || r.u8() != 1 {
		return nil, errFormat
	}
	f := r.u16()
	k.issued, k.expires = r.u32(), r.u32()
	if r.bad || f&^0x1f != 0 || k.expires <= k.issued || k.expires-k.issued > kinMaxLife {
		return nil, errFormat
	}
	k.oneTime = f&kinOneTime != 0
	k.id = r.take(16)
	// all zero is how a hello names a v3 link
	if r.bad || bytes.Equal(k.id, make([]byte, 16)) {
		return nil, errFormat
	}
	k.identity = r.key()
	k.firstContact = r.take(32)
	if r.bad || !secpLifts(k.firstContact) {
		return nil, errFormat
	}
	if f&kinOnion != 0 {
		k.onion = r.take(32)
		if r.bad || !strictEd(k.onion) {
			return nil, errFormat
		}
	}
	if f&kinFace != 0 {
		k.face, k.faceSig = r.take(32), r.take(64)
		if r.bad || !strictEd(k.face) || !edSigCanonical(k.faceSig) {
			return nil, errFormat
		}
	}
	if f&kinBundle != 0 {
		b, err := readBlock(r, k.identity)
		if err != nil {
			return nil, err
		}
		k.block = b
	}
	if f&kinDevices != 0 {
		n := r.u16()
		lr := &kinReader{b: r.take(n)}
		if r.bad {
			return nil, errFormat
		}
		l, err := readList(lr)
		if err != nil || len(lr.b) != 0 {
			return nil, errFormat
		}
		k.list = l
	}
	k.sig = r.sig()
	if r.bad || len(r.b) != 0 {
		return nil, errFormat
	}
	// a bundle on another key needs the list that vouches for it, and runs
	// on the device the list says answers
	ok := true
	switch {
	case k.block != nil && k.list != nil:
		a := k.list.answering()
		ok = a != nil && bytes.Equal(k.block.key, a.key) && k.block.device == a.device && k.block.reg == a.reg
	case k.block != nil:
		ok = k.block.key == nil
	case k.list != nil:
		ok = k.list.answering() != nil
	}
	if !ok || (k.list != nil && !bytes.Equal(k.list.identity, k.identity)) ||
		(k.oneTime && k.block != nil && !k.block.hasEC) {
		return nil, errFormat
	}
	if !bytes.Equal(append(k.body(), k.sig...), p) {
		return nil, errFormat
	}

	if k.face != nil {
		text := append(append(bytes.Clone(faceText), k.identity...), k.id...)
		if !ed25519.Verify(k.face, text, k.faceSig) {
			return nil, errSignature
		}
	}
	if b := k.block; b != nil {
		signer := b.key
		if signer == nil {
			signer = k.identity
		}
		if !xedVerify(signer, b.spk, b.spkSig) || !xedVerify(signer, b.kyber, b.kyberSig) {
			return nil, errSignature
		}
	}
	if l := k.list; l != nil && !xedVerify(l.identity, signedText("device-list", l.body()), l.sig) {
		return nil, errSignature
	}
	if !xedVerify(k.identity, signedText("invite", k.body()), k.sig) {
		return nil, errSignature
	}
	return k, nil
}
