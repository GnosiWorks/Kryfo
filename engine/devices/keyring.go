// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"encoding/binary"
	"io"
	"sync"
)

// MaxReg is the top registration id, as libsignal and the app make them.
const MaxReg = 16380

// KeySource makes a fresh libsignal identity key pair on this device and
// gives its public half. the private half stays in the app's store
// (ks_identity_generate).
type KeySource interface {
	NewKey() (Key, error)
}

// DeviceKeys is what a linked device holds for one identity: a key and a
// registration id of its own. the device id is the phone's to give.
type DeviceKeys struct {
	Identity Key
	Key      Key
	Reg      uint32
}

// Keyring is a linked device's keys, one set per identity. no key serves
// two identities, so contacts of two identities cannot tie them together
// through this device.
type Keyring struct {
	mu   sync.Mutex
	src  KeySource
	rnd  io.Reader
	keys map[Key]DeviceKeys
	used map[Key]Key
}

// NewKeyring is an empty keyring over src, drawing ids from rnd.
func NewKeyring(src KeySource, rnd io.Reader) *Keyring {
	return &Keyring{src: src, rnd: rnd, keys: map[Key]DeviceKeys{}, used: map[Key]Key{}}
}

// For is this device's keys for identity, made on first use.
func (k *Keyring) For(identity Key) (DeviceKeys, error) {
	k.mu.Lock()
	defer k.mu.Unlock()
	if dk, ok := k.keys[identity]; ok {
		return dk, nil
	}
	key, err := k.src.NewKey()
	if err != nil {
		return DeviceKeys{}, err
	}
	if key[0] != 0x05 || !canonicalU(key[1:]) {
		return DeviceKeys{}, ErrKey
	}
	reg, err := NewReg(k.rnd)
	if err != nil {
		return DeviceKeys{}, err
	}
	dk := DeviceKeys{Identity: identity, Key: key, Reg: reg}
	if err := k.put(dk); err != nil {
		return DeviceKeys{}, err
	}
	return dk, nil
}

// Load puts back keys read from storage.
func (k *Keyring) Load(dk DeviceKeys) error {
	k.mu.Lock()
	defer k.mu.Unlock()
	return k.put(dk)
}

func (k *Keyring) put(dk DeviceKeys) error {
	if dk.Reg == 0 || dk.Reg > MaxReg || dk.Key[0] != 0x05 || !canonicalU(dk.Key[1:]) {
		return ErrMalformed
	}
	// a device key is never an identity key, its own or another's
	if dk.Key == dk.Identity {
		return ErrDuplicate
	}
	if _, ok := k.used[dk.Identity]; ok {
		return ErrDuplicate
	}
	if old, ok := k.used[dk.Key]; ok && old != dk.Identity {
		return ErrDuplicate
	}
	if _, ok := k.keys[dk.Key]; ok {
		return ErrDuplicate
	}
	if old, ok := k.keys[dk.Identity]; ok && old != dk {
		return ErrDuplicate
	}
	k.keys[dk.Identity] = dk
	k.used[dk.Key] = dk.Identity
	return nil
}

// Forget drops the keys for identity, as when the device leaves its list.
func (k *Keyring) Forget(identity Key) {
	k.mu.Lock()
	defer k.mu.Unlock()
	if dk, ok := k.keys[identity]; ok {
		delete(k.used, dk.Key)
		delete(k.keys, identity)
	}
}

// NewReg is a random registration id, 1..MaxReg.
func NewReg(r io.Reader) (uint32, error) {
	var b [2]byte
	for range 1 << 10 {
		if _, err := io.ReadFull(r, b[:]); err != nil {
			return 0, err
		}
		// 14 bits, so most draws land in range
		v := uint32(binary.BigEndian.Uint16(b[:]) & 0x3fff)
		if v >= 1 && v <= MaxReg {
			return v, nil
		}
	}
	return 0, errRandom
}

// FreeID is a random device id for a new device on l: never the phone's,
// never one l already has.
func FreeID(l *List, r io.Reader) (uint8, error) { return FreeIDBut(l, nil, r) }

// FreeIDBut is FreeID that also passes over the ids busy says are in use
// off the list (a device just removed whose last word still goes).
func FreeIDBut(l *List, busy func(uint8) bool, r io.Reader) (uint8, error) {
	if len(l.Devices) >= MaxDevices {
		return 0, ErrTooMany
	}
	var b [1]byte
	for range 1 << 12 {
		if _, err := io.ReadFull(r, b[:]); err != nil {
			return 0, err
		}
		id := b[0] & 0x7f
		if id <= PhoneID {
			continue
		}
		if _, taken := l.Find(id); !taken && (busy == nil || !busy(id)) {
			return id, nil
		}
	}
	return 0, errRandom
}

// EntryFor is the entry a phone puts on l for a device's keys.
func EntryFor(l *List, dk DeviceKeys, r io.Reader) (Entry, error) {
	return EntryForBut(l, dk, nil, r)
}

// EntryForBut is EntryFor on an id busy does not name (FreeIDBut).
func EntryForBut(l *List, dk DeviceKeys, busy func(uint8) bool, r io.Reader) (Entry, error) {
	if dk.Identity != l.Identity {
		return Entry{}, ErrWrongIdentity
	}
	id, err := FreeIDBut(l, busy, r)
	if err != nil {
		return Entry{}, err
	}
	return Entry{ID: id, Key: dk.Key, Reg: dk.Reg}, nil
}
