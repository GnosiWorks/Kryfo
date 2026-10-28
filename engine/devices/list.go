// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"encoding/binary"
	"errors"
	"io"
	"math"
	"slices"
)

const (
	// MaxDevices counts the phone: the phone and five more
	MaxDevices = 6

	listMagic = "KDL2"
	// magic, identity, version, count
	listHead = 4 + KeySize + 8 + 1
	// device id, device key, registration id, flags
	entrySize = 1 + KeySize + 4 + 1

	// MinListSize is the phone alone, signed
	MinListSize = listHead + entrySize + SigSize
	// MaxListSize is six devices, signed
	MaxListSize = listHead + MaxDevices*entrySize + SigSize

	// PhoneID is the phone's device id on every list: libsignal's device 1,
	// where the phone's sessions already live
	PhoneID = 1
	// MaxID is the top of libsignal's device id range
	MaxID = 127

	flagPhone   = 1 << 0
	flagAnswers = 1 << 1

	// a new list starts below this
	versionStart = 1 << 56
	// a restored phone jumps by this plus a random 32-bit number
	versionRestore = 1 << 40
	// VersionWindow is the most a contact takes above the version it holds:
	// 256 restores while it was away, and no counter run to the top
	VersionWindow = 1 << 48
)

var (
	ErrMalformed     = errors.New("devices: malformed")
	ErrWrongIdentity = errors.New("devices: another identity's list")
	ErrTooMany       = errors.New("devices: too many devices")
	ErrDuplicate     = errors.New("devices: device already listed")
	ErrNotListed     = errors.New("devices: device not listed")
	ErrPhone         = errors.New("devices: the phone cannot be removed")
	ErrVersion       = errors.New("devices: no version left after this one")
	ErrUnsigned      = errors.New("devices: list not signed")
)

// Entry is one device on a list. nothing in it names or dates the device.
type Entry struct {
	ID      uint8
	Key     Key
	Reg     uint32
	Phone   bool
	Answers bool
}

// List is one identity's devices, signed by that identity's key.
type List struct {
	Identity Key
	Version  uint64
	Devices  []Entry

	sig []byte
}

// Genesis is an identity's first list: the phone alone, its key the
// identity key itself, at a random start version.
func Genesis(identity Key, phoneReg uint32, r io.Reader) (*List, error) {
	v, err := randBelow(r, versionStart)
	if err != nil {
		return nil, err
	}
	l := &List{
		Identity: identity,
		Version:  v,
		Devices:  []Entry{{ID: PhoneID, Key: identity, Reg: phoneReg, Phone: true}},
	}
	if err := l.check(); err != nil {
		return nil, err
	}
	return l, nil
}

// the next list with devs, a random step on. unsigned
func (l *List) next(devs []Entry, step uint64) (*List, error) {
	if l.Version > math.MaxUint64-step {
		return nil, ErrVersion
	}
	n := &List{Identity: l.Identity, Version: l.Version + step, Devices: devs}
	n.sort()
	if err := n.check(); err != nil {
		return nil, err
	}
	return n, nil
}

func randStep(r io.Reader) (uint64, error) {
	var b [1]byte
	if _, err := io.ReadFull(r, b[:]); err != nil {
		return 0, err
	}
	return 1 + uint64(b[0]), nil
}

// Add is the list with e on it, unsigned.
func (l *List) Add(e Entry, r io.Reader) (*List, error) {
	if e.Phone {
		return nil, ErrDuplicate
	}
	if len(l.Devices) >= MaxDevices {
		return nil, ErrTooMany
	}
	for _, d := range l.Devices {
		if d.ID == e.ID || d.Key == e.Key {
			return nil, ErrDuplicate
		}
	}
	step, err := randStep(r)
	if err != nil {
		return nil, err
	}
	return l.next(append(slices.Clone(l.Devices), e), step)
}

// Remove is the list without id, unsigned.
func (l *List) Remove(id uint8, r io.Reader) (*List, error) {
	e, ok := l.Find(id)
	if !ok {
		return nil, ErrNotListed
	}
	if e.Phone {
		return nil, ErrPhone
	}
	step, err := randStep(r)
	if err != nil {
		return nil, err
	}
	devs := slices.DeleteFunc(slices.Clone(l.Devices), func(d Entry) bool { return d.ID == id })
	return l.next(devs, step)
}

// Settled is the list with no device answering first contacts, unsigned:
// what a pool identity sends inside its sessions once its invite is used.
func (l *List) Settled(r io.Reader) (*List, error) {
	step, err := randStep(r)
	if err != nil {
		return nil, err
	}
	devs := slices.Clone(l.Devices)
	for i := range devs {
		devs[i].Answers = false
	}
	return l.next(devs, step)
}

// Restored is the list a phone restored from a backup signs first. it does
// not know the last version it signed after the backup, and steps are at
// most 256, so the jump clears every one of them.
func (l *List) Restored(r io.Reader) (*List, error) {
	var b [4]byte
	if _, err := io.ReadFull(r, b[:]); err != nil {
		return nil, err
	}
	return l.next(slices.Clone(l.Devices), versionRestore+uint64(binary.BigEndian.Uint32(b[:])))
}

// Find is the entry for id.
func (l *List) Find(id uint8) (Entry, bool) {
	for _, e := range l.Devices {
		if e.ID == id {
			return e, true
		}
	}
	return Entry{}, false
}

// FindKey is the entry whose device key is k.
func (l *List) FindKey(k Key) (Entry, bool) {
	for _, e := range l.Devices {
		if e.Key == k {
			return e, true
		}
	}
	return Entry{}, false
}

// Answering is the entry that answers first contacts, if any.
func (l *List) Answering() (Entry, bool) {
	for _, e := range l.Devices {
		if e.Answers {
			return e, true
		}
	}
	return Entry{}, false
}

func (l *List) sort() {
	slices.SortFunc(l.Devices, func(a, b Entry) int { return int(a.ID) - int(b.ID) })
}

// the rules a list keeps, on the way out and on the way in alike
func (l *List) check() error {
	n := len(l.Devices)
	if n < 1 || n > MaxDevices {
		return ErrTooMany
	}
	if !canonicalU(l.Identity[1:]) || l.Identity[0] != 0x05 {
		return ErrMalformed
	}
	phones, answers := 0, 0
	for i, e := range l.Devices {
		if e.ID < PhoneID || e.ID > MaxID || (i > 0 && l.Devices[i-1].ID >= e.ID) {
			return ErrMalformed
		}
		if e.Reg == 0 || e.Key[0] != 0x05 || !canonicalU(e.Key[1:]) {
			return ErrMalformed
		}
		for _, o := range l.Devices[:i] {
			if o.Key == e.Key {
				return ErrMalformed
			}
		}
		// the phone is device 1 on the identity key; nothing else holds
		// either
		if e.Phone != (e.ID == PhoneID) || e.Phone != (e.Key == l.Identity) {
			return ErrMalformed
		}
		if e.Phone {
			phones++
		}
		if e.Answers {
			if e.Phone {
				return ErrMalformed
			}
			answers++
		}
	}
	if phones != 1 || answers > 1 {
		return ErrMalformed
	}
	return nil
}

// Body is the list as ks_sign takes it under ContextList.
func (l *List) Body() []byte {
	b := make([]byte, 0, MaxListSize)
	b = append(b, listMagic...)
	b = append(b, l.Identity[:]...)
	b = binary.BigEndian.AppendUint64(b, l.Version)
	b = append(b, byte(len(l.Devices)))
	for _, e := range l.Devices {
		var f byte
		if e.Phone {
			f |= flagPhone
		}
		if e.Answers {
			f |= flagAnswers
		}
		b = append(b, e.ID)
		b = append(b, e.Key[:]...)
		b = binary.BigEndian.AppendUint32(b, e.Reg)
		b = append(b, f)
	}
	return b
}

// Sign is the list in its wire form, signed by the identity it names.
func (l *List) Sign(s Signer) ([]byte, error) {
	if s.Public() != l.Identity {
		return nil, ErrWrongIdentity
	}
	if err := l.check(); err != nil {
		return nil, err
	}
	body := l.Body()
	sig, err := s.Sign(ContextList, body)
	if err != nil {
		return nil, err
	}
	if len(sig) != SigSize {
		return nil, ErrSignature
	}
	l.sig = slices.Clone(sig)
	return append(body, sig...), nil
}

// Wire is the signed list, nil before it is signed or read.
func (l *List) Wire() []byte {
	if l.sig == nil {
		return nil
	}
	return append(l.Body(), l.sig...)
}

// SameBody is true for two lists with one body, whatever their signatures:
// xeddsa signs one body differently each time.
func SameBody(a, b *List) bool { return bytes.Equal(a.Body(), b.Body()) }

// ParseList reads a signed list: one encoding per value, canonical keys,
// every list rule. the signature is not checked here; Verify does that.
func ParseList(b []byte) (*List, error) {
	if len(b) < MinListSize || len(b) > MaxListSize || (len(b)-listHead-SigSize)%entrySize != 0 {
		return nil, ErrMalformed
	}
	if string(b[:4]) != listMagic {
		return nil, ErrMalformed
	}
	l := &List{}
	copy(l.Identity[:], b[4:4+KeySize])
	l.Version = binary.BigEndian.Uint64(b[4+KeySize:])
	n := int(b[listHead-1])
	if n < 1 || n > MaxDevices || len(b) != listHead+n*entrySize+SigSize {
		return nil, ErrMalformed
	}
	p := b[listHead:]
	for range n {
		var e Entry
		e.ID = p[0]
		copy(e.Key[:], p[1:1+KeySize])
		e.Reg = binary.BigEndian.Uint32(p[1+KeySize:])
		f := p[entrySize-1]
		if f&^(flagPhone|flagAnswers) != 0 {
			return nil, ErrMalformed
		}
		e.Phone = f&flagPhone != 0
		e.Answers = f&flagAnswers != 0
		l.Devices = append(l.Devices, e)
		p = p[entrySize:]
	}
	if err := l.check(); err != nil {
		return nil, ErrMalformed
	}
	l.sig = slices.Clone(p)
	// one list, one encoding
	if !bytes.Equal(l.Wire(), b) {
		return nil, ErrMalformed
	}
	return l, nil
}

// Verify checks the list's signature by the identity it names.
func (l *List) Verify(v Verifier) error {
	if l.sig == nil {
		return ErrUnsigned
	}
	if err := v.Verify(l.Identity, ContextList, l.Body(), l.sig); err != nil {
		return ErrSignature
	}
	return nil
}

// ReadList is ParseList and Verify.
func ReadList(b []byte, v Verifier) (*List, error) {
	l, err := ParseList(b)
	if err != nil {
		return nil, err
	}
	if err := l.Verify(v); err != nil {
		return nil, err
	}
	return l, nil
}

// a uniform number in [1, n), n at most 2^64-1
func randBelow(r io.Reader, n uint64) (uint64, error) {
	// smallest mask over n-1
	mask := uint64(math.MaxUint64)
	for mask>>1 >= n-1 && mask > 0 {
		mask >>= 1
	}
	var b [8]byte
	for range 1 << 10 {
		if _, err := io.ReadFull(r, b[:]); err != nil {
			return 0, err
		}
		v := binary.BigEndian.Uint64(b[:]) & mask
		if v >= 1 && v < n {
			return v, nil
		}
	}
	return 0, errRandom
}

var errRandom = errors.New("devices: the random source gives no usable number")
