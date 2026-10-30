// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/rand"
	"errors"
	"io"
	"time"
)

var (
	ErrClassic   = errors.New("devices: a classic session after a post-quantum one")
	ErrNotItsKey = errors.New("devices: not the listed key or registration id")
	ErrSelf      = errors.New("devices: this device itself")
)

// Slot is one copy of a message: a libsignal session per slot, on its own
// device-pair address. every copy is the same padded plaintext.
type Slot struct {
	// the contact's identity, or mine for a copy to my own device
	Identity Key
	Device   uint8
	// the key the session has to run on (the pin)
	Key Key
	// the listed registration id; 0 for a phone before its first list
	Reg uint32
	Own bool
	// the session held goes, and the copy waits for a fresh bundle
	Rebuild bool
}

// Peer is what the app knows of a contact's sessions.
type Peer struct {
	// the contact showed the device caps word: it reads per-device copies
	Devices bool
	// the phone's session (device 1) is a held classic one
	PhoneClassic bool
}

// Fanout says where a message goes. Own may be nil on a phone with no
// linked device, Quiet nil to send to every device always, Rand nil for
// crypto/rand.
type Fanout struct {
	Book  *Book
	Own   *Own
	Quiet *Quiet
	Rand  io.Reader
}

// To is every copy of a message from my identity mine to the contact
// identity, in random order: one per routed device on the contact's list,
// one per other device of mine. a contact without the caps word or a list
// gets its phone alone, as a 0.5.x phone does.
func (f *Fanout) To(mine, contact Key, p Peer, now time.Time) ([]Slot, error) {
	l, routes, ok := f.Book.routes(contact)
	if !ok {
		return nil, ErrUnknown
	}
	if p.PhoneClassic && f.Book.PQ(contact) {
		return nil, ErrClassic
	}
	var out []Slot
	if !p.Devices || p.PhoneClassic || l == nil {
		var reg uint32
		if l != nil {
			e, _ := l.Find(PhoneID)
			reg = e.Reg
		}
		out = append(out, Slot{Identity: contact, Device: PhoneID, Key: contact, Reg: reg})
	} else {
		for _, e := range routes {
			s := Slot{Identity: contact, Device: e.ID, Key: e.Key, Reg: e.Reg}
			if !e.Phone && !f.quiet(&s, l.Version, now) {
				continue
			}
			out = append(out, s)
		}
	}
	if f.Own != nil {
		ol := f.Own.Current(mine)
		for _, e := range f.Own.Others(mine) {
			s := Slot{Identity: mine, Device: e.ID, Key: e.Key, Reg: e.Reg, Own: true}
			// the own phone is never silenced, as a contact's is not
			if ol != nil && !e.Phone && !f.quiet(&s, ol.Version, now) {
				continue
			}
			out = append(out, s)
		}
	}
	r := f.Rand
	if r == nil {
		r = rand.Reader
	}
	if err := shuffle(out, r); err != nil {
		return nil, err
	}
	return out, nil
}

// whether the slot goes, marked Rebuild when its session has to be built
// again
func (f *Fanout) quiet(s *Slot, version uint64, now time.Time) bool {
	if f.Quiet == nil {
		return true
	}
	switch f.Quiet.State(s.Identity, s.Device, s.Key, version, now) {
	case Silent:
		return false
	case Rebuild:
		s.Rebuild = true
	}
	return true
}

func shuffle(s []Slot, r io.Reader) error {
	for i := len(s) - 1; i > 0; i-- {
		j, err := randBelow(r, uint64(i)+2)
		if err != nil {
			return err
		}
		s[i], s[j-1] = s[j-1], s[i]
	}
	return nil
}
