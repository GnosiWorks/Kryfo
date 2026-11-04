// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/hkdf"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"io"
	"time"
)

// after the welcome: the phone tells the joiner where to find it (KLP1, on
// the rendezvous), and the joiner hands its first bundles to the phone's
// onion (KLB1). both sealed under keys of the link's own secrets, one
// message per key

const (
	placeMagic   = "KLP1"
	bundlesMagic = "KLB1"

	labelRendezvousJ = "kryfo-link-v2 rendezvous to joiner"
	labelRendezvousP = "kryfo-link-v2 rendezvous to phone"

	// OnionSize is a v3 onion name without ".onion"
	OnionSize = 56
	// TokenSize is the one-time token the phone's door takes KLB1 with
	TokenSize = 32

	placePlainMin = OnionSize + TokenSize + 2 + 2 + MinListSize
	placeSizeMax  = 4 + OnionSize + TokenSize + 2 + 2 + MaxListSize + 16

	// the largest KDB1: a block with a device key and an ec prekey
	maxBundle = 5 + BlockSize + KeySize + 4 + KeySize
	// BundlesMost is the most one-time bundles a KLB1 carries
	BundlesMost = PoolMost
	// BundlesSizeMax is the largest sealed KLB1
	BundlesSizeMax = 4 + 8 + (2+BundlesMost)*(2+maxBundle) + 2 + 16
)

// Rendezvous is the seeds of the two relay addresses a link runs on, one
// per direction, from the offer: only who saw the qr can reach them.
func Rendezvous(offer []byte) (toJoiner, toPhone [32]byte, err error) {
	if len(offer) != offerSize || string(offer[:4]) != offerMagic {
		return toJoiner, toPhone, ErrMalformed
	}
	j, err := hkdf.Key(sha256.New, offer, nil, labelRendezvousJ, 32)
	if err != nil {
		return toJoiner, toPhone, err
	}
	p, err := hkdf.Key(sha256.New, offer, nil, labelRendezvousP, 32)
	if err != nil {
		return toJoiner, toPhone, err
	}
	copy(toJoiner[:], j)
	copy(toPhone[:], p)
	return toJoiner, toPhone, nil
}

// NewToken is a fresh one-time token for the phone's door.
func NewToken() ([TokenSize]byte, error) {
	var t [TokenSize]byte
	_, err := io.ReadFull(rand.Reader, t[:])
	return t, err
}

// Place is what KLP1 carries: the phone's onion, the token its door takes
// KLB1 with, how many one-time bundles the phone wants for the first copies
// to contacts' devices, and the own list that names the new device, signed.
type Place struct {
	Onion string
	Token [TokenSize]byte
	Want  int
	List  []byte
}

func onionOK(s string) bool {
	if len(s) != OnionSize || s[OnionSize-1] != 'd' {
		return false
	}
	for i := 0; i < len(s); i++ {
		c := s[i]
		if (c < 'a' || c > 'z') && (c < '2' || c > '7') {
			return false
		}
	}
	return true
}

// SealPlace is KLP1 for p under the phone's after keys.
func SealPlace(a AfterKeys, bind [32]byte, p Place) ([]byte, error) {
	if !onionOK(p.Onion) || len(p.List) < MinListSize || len(p.List) > MaxListSize || p.Want < 0 || p.Want > BundlesMost {
		return nil, ErrMalformed
	}
	pt := make([]byte, 0, OnionSize+TokenSize+4+len(p.List))
	pt = append(pt, p.Onion...)
	pt = append(pt, p.Token[:]...)
	pt = binary.BigEndian.AppendUint16(pt, uint16(p.Want))
	pt = binary.BigEndian.AppendUint16(pt, uint16(len(p.List)))
	pt = append(pt, p.List...)
	ct, err := sealOnce(a.Place[:], pt, adOf(placeMagic, bind))
	wipe(pt)
	if err != nil {
		return nil, err
	}
	return append([]byte(placeMagic), ct...), nil
}

// OpenPlace reads KLP1. the list is only parsed here: the caller checks
// its signature and that it names this device.
func OpenPlace(a AfterKeys, bind [32]byte, msg []byte) (Place, error) {
	var p Place
	if len(msg) < 4+placePlainMin+16 || len(msg) > placeSizeMax || string(msg[:4]) != placeMagic {
		return p, ErrMalformed
	}
	pt, err := openOnce(a.Place[:], msg[4:], adOf(placeMagic, bind))
	if err != nil {
		return p, err
	}
	defer wipe(pt)
	r := &reader{b: pt}
	onion := string(r.take(OnionSize))
	copy(p.Token[:], r.take(TokenSize))
	want := r.u16()
	n := r.u16()
	list := r.take(n)
	if r.bad || len(r.b) != 0 || !onionOK(onion) || want > BundlesMost {
		return Place{}, ErrMalformed
	}
	if _, err := ParseList(list); err != nil {
		return Place{}, ErrMalformed
	}
	p.Onion, p.Want, p.List = onion, want, append([]byte(nil), list...)
	return p, nil
}

// Bundles is what KLB1 carries: the device's first own bundle, which the
// phone builds its session with, its last resort, a batch for the first
// copies to contacts' devices, and when the device made them by its own
// clock.
type Bundles struct {
	Made  time.Time
	First []byte
	Last  []byte
	Once  [][]byte
}

func putBundle(out, b []byte) []byte {
	out = binary.BigEndian.AppendUint16(out, uint16(len(b)))
	return append(out, b...)
}

// SealBundles is KLB1 for b under the joiner's after keys.
func SealBundles(a AfterKeys, bind [32]byte, b Bundles) ([]byte, error) {
	if len(b.Once) > BundlesMost || b.Made.IsZero() {
		return nil, ErrMalformed
	}
	all := append([][]byte{b.First, b.Last}, b.Once...)
	for _, x := range all {
		if len(x) == 0 || len(x) > maxBundle {
			return nil, ErrMalformed
		}
	}
	pt := binary.BigEndian.AppendUint64(nil, uint64(b.Made.UnixMilli()))
	pt = putBundle(pt, b.First)
	pt = putBundle(pt, b.Last)
	pt = binary.BigEndian.AppendUint16(pt, uint16(len(b.Once)))
	for _, x := range b.Once {
		pt = putBundle(pt, x)
	}
	ct, err := sealOnce(a.Bundles[:], pt, adOf(bundlesMagic, bind))
	if err != nil {
		return nil, err
	}
	return append([]byte(bundlesMagic), ct...), nil
}

// OpenBundles reads KLB1 from the device dev of identity: every bundle a
// KDB1 of that device, on its own key and registration id, no kyber id
// twice. the prekey signatures are the shim's to check, when a session is
// built or a bundle handed out.
func OpenBundles(a AfterKeys, bind [32]byte, msg []byte, identity Key, dev Entry) (Bundles, error) {
	var b Bundles
	if len(msg) < 4+8+2*(2+5+BlockSize)+2+16 || len(msg) > BundlesSizeMax || string(msg[:4]) != bundlesMagic {
		return b, ErrMalformed
	}
	if dev.Phone || dev.ID <= PhoneID {
		return b, ErrMalformed
	}
	pt, err := openOnce(a.Bundles[:], msg[4:], adOf(bundlesMagic, bind))
	if err != nil {
		return b, err
	}
	r := &reader{b: pt}
	made := r.u64()
	first := r.take(r.u16())
	last := r.take(r.u16())
	n := r.u16()
	if r.bad || n > BundlesMost {
		return Bundles{}, ErrMalformed
	}
	once := make([][]byte, 0, n)
	for i := 0; i < n; i++ {
		x := r.take(r.u16())
		if r.bad {
			return Bundles{}, ErrMalformed
		}
		once = append(once, x)
	}
	if len(r.b) != 0 || made == 0 || made > 1<<62 {
		return Bundles{}, ErrMalformed
	}
	seen := map[uint32]bool{}
	for _, x := range append([][]byte{first, last}, once...) {
		blk, err := ParseBundle(x, identity)
		if err != nil {
			return Bundles{}, err
		}
		if blk.Device != dev.ID || !blk.HasKey || blk.Key != dev.Key || blk.Reg != dev.Reg {
			return Bundles{}, ErrNotItsKey
		}
		if seen[blk.KyberID] {
			return Bundles{}, ErrDuplicate
		}
		seen[blk.KyberID] = true
	}
	b.Made = time.UnixMilli(int64(made))
	b.First = append([]byte(nil), first...)
	b.Last = append([]byte(nil), last...)
	for _, x := range once {
		b.Once = append(b.Once, append([]byte(nil), x...))
	}
	return b, nil
}
