// SPDX-License-Identifier: GPL-3.0-or-later
package main

import "C"

import (
	"encoding/json"
	"errors"

	"github.com/halo/engine/devices"
)

// the one door through which a session's remote becomes a From or a
// proof: what ks_decrypt_* returned for a message that opened, handed on
// by the app's session layer (app/signal.dart) and nothing else. the
// identity is the one the session record and pair address belong to,
// never a key a message names. TestOnlyTheSessionLayerNamesARemote keeps
// it so, here and in dart.

// HaloDevSession runs one call that names a session's remote: op, and its
// args as json.
//
//export HaloDevSession
func HaloDevSession(cOp, cArgs *C.char) *C.char {
	return C.CString(devSessionJSON(goStr(cOp), goStr(cArgs)))
}

func devSessionJSON(op, raw string) string {
	out := &devOut{}
	var a devArgs
	if err := json.Unmarshal([]byte(raw), &a); err != nil {
		return devAnswer(out, devices.ErrMalformed)
	}
	d := devNow()
	d.mu.Lock()
	defer d.mu.Unlock()
	return devAnswer(out, d.session(op, &a, out))
}

func (d *devState) session(op string, a *devArgs, out *devOut) error {
	if op == "own_mine" {
		return d.ownMine(a, out)
	}
	id, err := a.identity()
	if err != nil {
		return err
	}
	remote, err := parseHexKey(a.Remote)
	if err != nil {
		return err
	}
	switch op {
	case "opened":
		return d.opened(id, remote, a, out)
	case "accept":
		return d.accept(id, a.List, devices.FromSession(remote), out)
	case "bundle":
		b, err := d.book.TakeBundle(id, a.KDB1, devices.FromSession(remote))
		if err != nil {
			return err
		}
		out.Block = &devBlock{Device: int(b.Device), Reg: b.Reg, SpkID: b.SpkID, KyberID: b.KyberID}
		if b.HasKey {
			out.Block.Key = hexKey(b.Key)
		}
		return nil
	case "own_set":
		return d.ownSet(id, a, devices.FromSession(remote), out)
	}
	return errors.New("no such call")
}

// a message from device a.Device of the contact id opened on a session
// whose libsignal remote was remote: admitted first, then the key is
// proven for the contact, and a post-quantum session noted for good. a
// contact the book does not hold yet is added only from its phone's
// session on its own identity
func (d *devState) opened(id, remote devices.Key, a *devArgs, out *devOut) error {
	dev, err := a.device()
	if err != nil {
		return err
	}
	if _, mine := d.mine[id]; mine {
		// own devices go through Own's door, in the receive wiring
		return devices.ErrSelf
	}
	if i, ok := d.peers[id]; ok && i != a.Ident {
		return devices.ErrTaken
	}
	s := d.snap(id)
	defer func() { out.Rows = s.rows() }()
	if _, ok := d.peers[id]; !ok {
		if dev != devices.PhoneID || remote != id {
			return devices.ErrUnknown
		}
		claimants, err := d.book.Add(id)
		if err != nil {
			return err
		}
		d.peers[id] = a.Ident
		s.ident = a.Ident
		out.Claimants = keysOut(claimants)
	}
	if err := d.book.Admit(id, dev, remote); err != nil {
		return err
	}
	claimants, err := d.book.Proven(id, remote)
	if err != nil {
		return err
	}
	out.Claimants = keysOut(claimants)
	if a.PQ {
		return d.book.SawPQ(id)
	}
	return nil
}

// an own list of my identity id, from the phone's session (or, once one
// is held, a listed own device's)
func (d *devState) ownSet(id devices.Key, a *devArgs, from devices.From, out *devOut) error {
	m, ok := d.mine[id]
	if !ok || m.ident != a.Ident {
		return devices.ErrUnknown
	}
	s := d.snap(id)
	gone, err := d.own.Set(id, a.List, m.key, from, d.v)
	out.Rows = s.rows()
	for _, e := range gone {
		out.Gone = append(out.Gone, entryOut(e))
	}
	return err
}

// the phone's own list of my identity a.Ident, as it signed it: the
// phone's own key vouches for it. a linked device has no such call
func (d *devState) ownMine(a *devArgs, out *devOut) error {
	id, ok := d.idents[a.Ident]
	if !ok {
		return devices.ErrUnknown
	}
	if d.mine[id].key != id {
		return devices.ErrSource
	}
	return d.ownSet(id, a, devices.FromSession(id), out)
}
