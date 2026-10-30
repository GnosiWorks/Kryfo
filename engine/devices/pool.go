// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"errors"
	"sync"
	"time"
)

const (
	// PoolMaxAge is how long a one-time bundle waits in the pool. the
	// device makes its kyber key to live this long and 16 days more
	// (kPoolKyberLife in the app), so one handed out on its last pool day
	// still opens for 16
	PoolMaxAge = 7 * 24 * time.Hour
	// PoolLastMaxAge is how long a last resort bundle is handed out after
	// it came. its session keys are replaced on their first use after 30
	// days and the device sends the next last resort then; the replaced
	// ones still open for 16 days
	PoolLastMaxAge = 30 * 24 * time.Hour
	// PoolMost is the most one-time bundles held for one device
	PoolMost = 64
	// PoolLow is when the phone asks the device for more
	PoolLow = 8
)

var (
	ErrNoBundle = errors.New("devices: no bundle held for that device")
	// a bundle on session keys other than the last resort's: the device
	// replaced them and sends its new last resort with it
	ErrOldKeys = errors.New("devices: a bundle on replaced session keys")
)

type poolBundle struct {
	b   []byte
	at  time.Time
	spk uint32
}

type pooled struct {
	entry Entry
	// oldest first
	once []poolBundle
	last *poolBundle
	// every kyber id taken for the device, last resorts' too
	kyber map[uint32]bool
}

// Pool is the phone's store of its linked devices' KDB1s, per (identity,
// device). the phone cannot make a device's prekeys, so each device hands
// over a batch, and the phone gives one to each device that has to start a
// session with it. a one-time bundle goes out once and only while it is
// young enough to open; with none left, the device's last resort bundle
// does, as libsignal's last resort kyber key. a clock set back counts no
// time.
type Pool struct {
	mu   sync.Mutex
	rows map[slotKey]*pooled
}

// NewPool is an empty pool.
func NewPool() *Pool { return &Pool{rows: map[slotKey]*pooled{}} }

func young(at, now time.Time, most time.Duration) bool { return now.Sub(at) < most }

// the one-time bundles still young enough, on the last resort's keys
func (r *pooled) prune(now time.Time) {
	keep := r.once[:0]
	for _, b := range r.once {
		if young(b.at, now, PoolMaxAge) && (r.last == nil || b.spk == r.last.spk) {
			keep = append(keep, b)
		}
	}
	clear(r.once[len(keep):])
	r.once = keep
	if r.last != nil && !young(r.last.at, now, PoolLastMaxAge) {
		r.last = nil
	}
}

// Put keeps KDB1s of identity's own device e, come at now: every one the
// device's own (its id, its registration id, its key), each kyber key
// once. last, when given, is the device's last resort bundle; a new one
// replaces the held one, and the one-time bundles on other session keys
// go. a one-time bundle must be on the last resort's session keys. on any
// error nothing is kept.
func (p *Pool) Put(identity Key, e Entry, once [][]byte, last []byte, now time.Time) error {
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
	next := &pooled{entry: e, once: append([]poolBundle(nil), r.once...), last: r.last, kyber: map[uint32]bool{}}
	for id := range r.kyber {
		next.kyber[id] = true
	}
	if last != nil && (next.last == nil || !bytes.Equal(last, next.last.b)) {
		bl, err := read(last)
		if err != nil {
			return err
		}
		if next.kyber[bl.KyberID] {
			return ErrDuplicate
		}
		next.kyber[bl.KyberID] = true
		next.last = &poolBundle{b: bytes.Clone(last), at: now, spk: bl.SpkID}
	}
	next.prune(now)
	if len(next.once)+len(once) > PoolMost {
		return ErrTooMany
	}
	for _, b := range once {
		bl, err := read(b)
		if err != nil {
			return err
		}
		if next.kyber[bl.KyberID] {
			return ErrDuplicate
		}
		if next.last != nil && bl.SpkID != next.last.spk {
			return ErrOldKeys
		}
		next.kyber[bl.KyberID] = true
		next.once = append(next.once, poolBundle{b: bytes.Clone(b), at: now, spk: bl.SpkID})
	}
	p.rows[k] = next
	return nil
}

// Take gives one KDB1 of identity's device at now, the oldest one-time one
// while any is young enough, and low when the device should be asked for
// more.
func (p *Pool) Take(identity Key, device uint8, now time.Time) (kdb1 []byte, low bool, err error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	r := p.rows[slotKey{identity, device}]
	if r == nil {
		return nil, true, ErrNoBundle
	}
	r.prune(now)
	if n := len(r.once); n > 0 {
		b := r.once[0].b
		r.once[0] = poolBundle{}
		r.once = r.once[1:]
		return b, n-1 <= PoolLow, nil
	}
	if r.last == nil {
		return nil, true, ErrNoBundle
	}
	return bytes.Clone(r.last.b), true, nil
}

// Drop forgets a device's bundles, as when it is removed.
func (p *Pool) Drop(identity Key, device uint8) {
	p.mu.Lock()
	defer p.mu.Unlock()
	delete(p.rows, slotKey{identity, device})
}
