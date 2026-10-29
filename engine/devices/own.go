// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"errors"
	"sync"
)

// ErrRemoved is this device's own list without it: the device wipes.
var ErrRemoved = errors.New("devices: this device is no longer on the list")

// Own is this device's lists of its own identities, and its place on each.
// the phone signs them; a linked device takes them from its phone.
type Own struct {
	mu    sync.Mutex
	lists map[Key]*List
	me    map[Key]Entry
}

// NewOwn is an Own with no list yet.
func NewOwn() *Own { return &Own{lists: map[Key]*List{}, me: map[Key]Entry{}} }

// Set takes a signed list of one of this container's identities, mine
// being this device's key for it (the identity itself on the phone). it
// moves forward only, as a contact's does, and gives the own devices it no
// longer names. a list without this device is ErrRemoved, and the identity's
// list is dropped.
func (o *Own) Set(wire []byte, mine Key, v Verifier) (gone []Entry, err error) {
	l, err := ReadList(wire, v)
	if err != nil {
		return nil, err
	}
	o.mu.Lock()
	defer o.mu.Unlock()
	held := o.lists[l.Identity]
	if held != nil {
		switch {
		case l.Version == held.Version && SameBody(l, held):
			return nil, nil
		case l.Version == held.Version:
			return nil, ErrEquivocation
		case l.Version < held.Version:
			return nil, ErrRollback
		case l.Version-held.Version > VersionWindow:
			return nil, ErrJump
		}
	}
	me, ok := l.FindKey(mine)
	if !ok {
		delete(o.lists, l.Identity)
		delete(o.me, l.Identity)
		return nil, ErrRemoved
	}
	if held != nil {
		for _, e := range held.Devices {
			if n, ok := l.Find(e.ID); !ok || n.Key != e.Key {
				gone = append(gone, e)
			}
		}
	}
	o.lists[l.Identity], o.me[l.Identity] = l, me
	return gone, nil
}

// Current is the identity's own list held, nil before the first.
func (o *Own) Current(identity Key) *List {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.lists[identity]
}

// Others are the identity's own devices but this one: where a copy of what
// this device sends goes.
func (o *Own) Others(identity Key) []Entry {
	o.mu.Lock()
	defer o.mu.Unlock()
	l, me := o.lists[identity], o.me[identity]
	if l == nil {
		return nil
	}
	var out []Entry
	for _, e := range l.Devices {
		if e.ID != me.ID {
			out = append(out, e)
		}
	}
	return out
}

// Admit says whether a message that opened on a session with own device id
// of identity came from that device: listed, not this one, on its listed
// key. only this door takes a copy of a message sent from another device.
func (o *Own) Admit(identity Key, id uint8, remote Key) error {
	_, err := o.admit(identity, id, remote)
	return err
}

// AdmitOpener is Admit for an opener, whose registration id must be the
// listed one.
func (o *Own) AdmitOpener(identity Key, id uint8, remote Key, reg uint32) error {
	e, err := o.admit(identity, id, remote)
	if err == nil && e.Reg != reg {
		err = ErrNotItsKey
	}
	return err
}

func (o *Own) admit(identity Key, id uint8, remote Key) (Entry, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	l := o.lists[identity]
	if l == nil {
		return Entry{}, ErrUnknown
	}
	if id == o.me[identity].ID {
		return Entry{}, ErrSelf
	}
	e, ok := l.Find(id)
	if !ok {
		return Entry{}, ErrNotListed
	}
	if e.Key != remote {
		return Entry{}, ErrNotItsKey
	}
	return e, nil
}

// Stale are the own device ids in held whose sessions the list held no
// longer names on that key. with no list for the identity, all of them.
func (o *Own) Stale(identity Key, held []Held) []uint8 {
	o.mu.Lock()
	defer o.mu.Unlock()
	l := o.lists[identity]
	var out []uint8
	for _, h := range held {
		if l == nil || h.ID == o.me[identity].ID {
			out = append(out, h.ID)
			continue
		}
		if e, ok := l.Find(h.ID); !ok || e.Key != h.Key {
			out = append(out, h.ID)
		}
	}
	return out
}
