// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"errors"
	"sync"
)

const (
	// PoolMost is the most one-time bundles held for one device
	PoolMost = 64
	// PoolLow is when the phone asks the device for more
	PoolLow = 8
)

var ErrNoBundle = errors.New("devices: no bundle held for that device")

type pooled struct {
	entry Entry
	once  [][]byte
	last  []byte
	kyber map[uint32]bool
}

// Pool is the phone's store of its linked devices' KDB1s, per (identity,
// device). the phone cannot make a device's prekeys, so each device hands
// over a batch, and the phone gives one to each device that has to start a
// session with it. a one-time bundle goes out once; with none left, the
// device's last resort bundle does, as libsignal's last resort kyber key.
type Pool struct {
	mu   sync.Mutex
	rows map[slotKey]*pooled
}

// NewPool is an empty pool.
func NewPool() *Pool { return &Pool{rows: map[slotKey]*pooled{}} }

// Put keeps KDB1s of identity's own device e: every one the device's own
// (its id, its registration id, its key), each one-time kyber key once.
// last, when given, replaces the device's last resort bundle. on any error
// nothing is kept.
func (p *Pool) Put(identity Key, e Entry, once [][]byte, last []byte) error {
	if e.Phone {
		return ErrPhone
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	k := slotKey{identity, e.ID}
	r := p.rows[k]
	if r == nil || r.entry != e {
		r = &pooled{entry: e, kyber: map[uint32]bool{}}
	}
	if len(r.once)+len(once) > PoolMost {
		return ErrTooMany
	}
	read := func(b []byte) (*Block, error) {
		bl, err := ParseBundle(b, identity)
		if err != nil {
			return nil, err
		}
		if !bl.HasKey || bl.Key != e.Key || bl.Device != e.ID || bl.Reg != e.Reg {
			return nil, ErrNotListed
		}
		return bl, nil
	}
	next := &pooled{entry: e, once: append([][]byte(nil), r.once...), last: r.last, kyber: map[uint32]bool{}}
	for id := range r.kyber {
		next.kyber[id] = true
	}
	if last != nil {
		bl, err := read(last)
		if err != nil {
			return err
		}
		if next.kyber[bl.KyberID] {
			return ErrDuplicate
		}
		next.last = bytes.Clone(last)
	}
	var lastKyber uint32
	if next.last != nil {
		bl, _ := read(next.last)
		lastKyber = bl.KyberID
	}
	for _, b := range once {
		bl, err := read(b)
		if err != nil {
			return err
		}
		if next.kyber[bl.KyberID] || (next.last != nil && bl.KyberID == lastKyber) {
			return ErrDuplicate
		}
		next.kyber[bl.KyberID] = true
		next.once = append(next.once, bytes.Clone(b))
	}
	p.rows[k] = next
	return nil
}

// Take gives one KDB1 of identity's device, a one-time one while any is
// left, and low when the device should be asked for more.
func (p *Pool) Take(identity Key, device uint8) (kdb1 []byte, low bool, err error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	r := p.rows[slotKey{identity, device}]
	if r == nil {
		return nil, true, ErrNoBundle
	}
	if n := len(r.once); n > 0 {
		b := r.once[n-1]
		r.once = r.once[:n-1]
		return b, n-1 <= PoolLow, nil
	}
	if r.last == nil {
		return nil, true, ErrNoBundle
	}
	return bytes.Clone(r.last), true, nil
}

// Drop forgets a device's bundles, as when it is removed.
func (p *Pool) Drop(identity Key, device uint8) {
	p.mu.Lock()
	defer p.mu.Unlock()
	delete(p.rows, slotKey{identity, device})
}
