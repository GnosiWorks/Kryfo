// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"encoding/binary"
)

const (
	bundleMagic   = "KDB1"
	bundleVersion = 1

	blockHasKey = 1 << 0
	blockHasEC  = 1 << 1

	// a block without a bundle identity or an ec prekey
	BlockSize = 4 + 1 + 1 + 4 + KeySize + SigSize + 4 + KyberSize + SigSize
)

// Block is the bundle block of identity v4 (KIN4, KHB1, KDB1): one device's
// prekeys. the prekey signatures are libsignal's, checked by the shim when
// the bundle is built.
type Block struct {
	Reg    uint32
	Device uint8
	// HasKey is set when the bundle runs on Key, a device key, instead of
	// the frame's identity
	HasKey   bool
	Key      Key
	SpkID    uint32
	Spk      Key
	SpkSig   []byte
	KyberID  uint32
	Kyber    []byte
	KyberSig []byte
	HasEC    bool
	ECID     uint32
	EC       Key
}

// Encode is the block's one encoding.
func (b *Block) Encode() []byte {
	out := make([]byte, 0, BlockSize+KeySize+4+KeySize)
	out = binary.BigEndian.AppendUint32(out, b.Reg)
	out = append(out, b.Device)
	var f byte
	if b.HasKey {
		f |= blockHasKey
	}
	if b.HasEC {
		f |= blockHasEC
	}
	out = append(out, f)
	if b.HasKey {
		out = append(out, b.Key[:]...)
	}
	out = binary.BigEndian.AppendUint32(out, b.SpkID)
	out = append(out, b.Spk[:]...)
	out = append(out, b.SpkSig...)
	out = binary.BigEndian.AppendUint32(out, b.KyberID)
	out = append(out, b.Kyber...)
	out = append(out, b.KyberSig...)
	if b.HasEC {
		out = binary.BigEndian.AppendUint32(out, b.ECID)
		out = append(out, b.EC[:]...)
	}
	return out
}

func (b *Block) check() error {
	if b.Reg == 0 || b.Device < PhoneID || b.Device > MaxID {
		return ErrMalformed
	}
	// the phone is device 1 and runs on the identity itself; every other
	// device has a key of its own
	if b.HasKey == (b.Device == PhoneID) {
		return ErrMalformed
	}
	// a one-time prekey that is the signed prekey would be one key twice
	if b.HasEC && b.EC == b.Spk {
		return ErrMalformed
	}
	keys := []Key{b.Spk}
	if b.HasKey {
		keys = append(keys, b.Key)
	}
	if b.HasEC {
		keys = append(keys, b.EC)
	}
	for _, k := range keys {
		if k[0] != 0x05 || !canonicalU(k[1:]) {
			return ErrMalformed
		}
	}
	if len(b.SpkSig) != SigSize || len(b.KyberSig) != SigSize || !kyberShape(b.Kyber) {
		return ErrMalformed
	}
	return nil
}

// ParseBlock reads exactly one block.
func ParseBlock(p []byte) (*Block, error) {
	b := &Block{}
	r := &reader{b: p}
	b.Reg = r.u32()
	b.Device = r.u8()
	f := r.u8()
	if f&^(blockHasKey|blockHasEC) != 0 {
		return nil, ErrMalformed
	}
	b.HasKey, b.HasEC = f&blockHasKey != 0, f&blockHasEC != 0
	if b.HasKey {
		b.Key = r.key()
	}
	b.SpkID = r.u32()
	b.Spk = r.key()
	b.SpkSig = r.take(SigSize)
	b.KyberID = r.u32()
	b.Kyber = r.take(KyberSize)
	b.KyberSig = r.take(SigSize)
	if b.HasEC {
		b.ECID = r.u32()
		b.EC = r.key()
	}
	if r.bad || len(r.b) != 0 {
		return nil, ErrMalformed
	}
	if err := b.check(); err != nil {
		return nil, err
	}
	if !bytes.Equal(b.Encode(), p) {
		return nil, ErrMalformed
	}
	return b, nil
}

// EncodeBundle is a KDB1 around block.
func EncodeBundle(b *Block) ([]byte, error) {
	if err := b.check(); err != nil {
		return nil, err
	}
	return append(append([]byte(bundleMagic), bundleVersion), b.Encode()...), nil
}

// ParseBundle reads a KDB1 of identity's device. a block on the identity
// has one form, no key, so a key equal to it is refused.
func ParseBundle(p []byte, identity Key) (*Block, error) {
	if len(p) < len(bundleMagic)+1+BlockSize || string(p[:4]) != bundleMagic || p[4] != bundleVersion {
		return nil, ErrMalformed
	}
	b, err := ParseBlock(p[5:])
	if err != nil {
		return nil, err
	}
	if b.HasKey && b.Key == identity {
		return nil, ErrMalformed
	}
	return b, nil
}

// a reader that never reads past the end and says so once, at the end
type reader struct {
	b   []byte
	bad bool
}

func (r *reader) take(n int) []byte {
	if r.bad || n < 0 || n > len(r.b) {
		r.bad = true
		return make([]byte, max(n, 0))
	}
	out := r.b[:n]
	r.b = r.b[n:]
	return out
}

func (r *reader) key() (k Key) { copy(k[:], r.take(KeySize)); return }
func (r *reader) u8() byte     { return r.take(1)[0] }
func (r *reader) u16() int     { return int(binary.BigEndian.Uint16(r.take(2))) }
func (r *reader) u32() uint32  { return binary.BigEndian.Uint32(r.take(4)) }
func (r *reader) u64() uint64  { return binary.BigEndian.Uint64(r.take(8)) }
