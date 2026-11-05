// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/rand"
	"sync"

	"github.com/halo/engine/devices"
)

// removing my own devices (linked step 7, job 9): the phone's next list
// without them, the list a restored phone signs first, and the keys of a
// device just removed that its last word still goes to. only the phone
// signs; dart signs the body with ks_sign and takes it with own_mine

// the body of my list of identity a.Ident without the devices a.Held
// names (by id), for the phone to sign. the phone itself is never one, and
// an id the list does not name is refused: nothing is signed for nothing
func (d *devState) ownRemove(a *devArgs, out *devOut) error {
	id, ok := d.idents[a.Ident]
	if !ok {
		return devices.ErrUnknown
	}
	if d.mine[id].key != id {
		return devices.ErrSource
	}
	l := d.own.Current(id)
	if l == nil {
		return devices.ErrNotListed
	}
	if len(a.Held) == 0 {
		return devices.ErrMalformed
	}
	next := l
	for _, h := range a.Held {
		if h.ID <= devices.PhoneID || h.ID > devices.MaxID {
			return devices.ErrPhone
		}
		e, ok := next.Find(uint8(h.ID))
		if !ok {
			return devices.ErrNotListed
		}
		var err error
		if next, err = next.Remove(e.ID, rand.Reader); err != nil {
			return err
		}
		out.Gone = append(out.Gone, entryOut(e))
	}
	out.Outcome, out.List = "removed", next.Body()
	return nil
}

// the body of the list a restored phone signs first for a.Ident: the phone
// alone, its version past any the backup's phone may have signed since.
// "none" with no list held (nothing was ever linked)
func (d *devState) ownRestored(a *devArgs, out *devOut) error {
	id, ok := d.idents[a.Ident]
	if !ok {
		return devices.ErrUnknown
	}
	if d.mine[id].key != id {
		return devices.ErrSource
	}
	l := d.own.Current(id)
	if l == nil {
		out.Outcome = "none"
		return nil
	}
	next, err := l.Restored(rand.Reader)
	if err != nil {
		return err
	}
	for _, e := range l.Devices {
		if !e.Phone {
			out.Gone = append(out.Gone, entryOut(e))
		}
	}
	out.Outcome, out.List = "restored", next.Body()
	return nil
}

// a device of mine just removed: its last word (the list without it) goes
// to its pair's addresses, which need its key. kept here for the address
// layer alone, never in Own (nothing is admitted on it), and only for an id
// my list does not name. by ident, then id
var (
	devLeavingMu   sync.Mutex
	devLeavingKeys = map[int]map[uint8]devices.Key{}
)

// the leaving keys of my identity a.Ident, in place of any held (the phone
// only); none forgets them
func (d *devState) ownLeaving(a *devArgs) error {
	id, ok := d.idents[a.Ident]
	if !ok {
		return devices.ErrUnknown
	}
	if d.mine[id].key != id {
		return devices.ErrSource
	}
	keys := map[uint8]devices.Key{}
	for _, h := range a.Held {
		k, err := parseHexKey(h.Key)
		if err != nil || h.ID <= devices.PhoneID || h.ID > devices.MaxID || k == id {
			return devices.ErrMalformed
		}
		keys[uint8(h.ID)] = k
	}
	devLeavingMu.Lock()
	defer devLeavingMu.Unlock()
	if len(keys) == 0 {
		delete(devLeavingKeys, a.Ident)
		return nil
	}
	devLeavingKeys[a.Ident] = keys
	return nil
}

// every leaving key forgotten, at a load: the device state there names
// other identities, or a container wiped since
func devLeavingReset() {
	devLeavingMu.Lock()
	defer devLeavingMu.Unlock()
	clear(devLeavingKeys)
}

func devLeavingKey(ident int, dev uint8) (devices.Key, bool) {
	devLeavingMu.Lock()
	defer devLeavingMu.Unlock()
	k, ok := devLeavingKeys[ident][dev]
	return k, ok
}
