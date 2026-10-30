// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"sync"
	"time"
)

const (
	// QuietRebuild is how long a session goes unanswered before it is
	// built again from a fresh bundle: the one-time kyber its openers name
	// is deleted on the device after 16 days
	QuietRebuild = 15 * 24 * time.Hour
	// QuietSilent is how long a device gets copies without ever answering
	QuietSilent = 30 * 24 * time.Hour
	// QuietProbe is how often a silent device gets one more try: a copy
	// on a session built from a fresh bundle
	QuietProbe = 7 * 24 * time.Hour
)

// QuietState is what a sender does with a device's copy.
type QuietState int

const (
	// Open: the copy goes on the session held
	Open QuietState = iota
	// Rebuild: the session goes, and the copy waits for a fresh bundle
	Rebuild
	// Silent: no copy until the device is heard from, its list moves, a
	// fresh bundle of it comes or its weekly probe (a Rebuild) is due
	Silent
)

type slotKey struct {
	identity Key
	device   uint8
}

type quietRow struct {
	// the device's key: a new device under the same id starts afresh
	key Key
	// the first copy on a session the device never answered since
	first time.Time
	// the first copy on the session held now
	session time.Time
	silent  bool
	// the list version the device went silent under
	under uint64
	// the last probe of a silent device, or when it went silent
	probed time.Time
}

// Quiet keeps, per (identity, device), how long copies have gone to a
// device that never answers, so a broken or hostile list costs a sender at
// most QuietSilent of copies. the phone of a contact is never silenced:
// its session is the chat itself.
type Quiet struct {
	mu   sync.Mutex
	rows map[slotKey]*quietRow
}

// NewQuiet is a Quiet with nothing held.
func NewQuiet() *Quiet { return &Quiet{rows: map[slotKey]*quietRow{}} }

// the row for the device on key, a fresh one when the id came back on
// another key
func (q *Quiet) row(k slotKey, key Key) *quietRow {
	r := q.rows[k]
	if r != nil && r.key != key {
		delete(q.rows, k)
		r = nil
	}
	return r
}

// Sent records a copy to the device on key, on a session it has not
// answered on. now is when the copy went to the relay, not when it was
// sealed: a copy held back counts no time.
func (q *Quiet) Sent(identity Key, device uint8, key Key, now time.Time) {
	q.mu.Lock()
	defer q.mu.Unlock()
	k := slotKey{identity, device}
	r := q.row(k, key)
	if r == nil {
		r = &quietRow{key: key}
		q.rows[k] = r
	}
	if r.first.IsZero() {
		r.first = now
	}
	if r.session.IsZero() {
		r.session = now
	}
}

// Heard is a message from the device that opened: it answers.
func (q *Quiet) Heard(identity Key, device uint8) {
	q.mu.Lock()
	defer q.mu.Unlock()
	delete(q.rows, slotKey{identity, device})
}

// Rebuilt is a new session with the device after Rebuild: its 15 days
// start again, its 30 do not.
func (q *Quiet) Rebuilt(identity Key, device uint8) {
	q.mu.Lock()
	defer q.mu.Unlock()
	if r := q.rows[slotKey{identity, device}]; r != nil {
		r.session = time.Time{}
	}
}

// Fresh is a KDB1 of the device on key that its owner's phone pushed
// unasked: a silent device gets another try (true: build on it in place of
// the session held). a bundle asked for after a Rebuild is Rebuilt.
func (q *Quiet) Fresh(identity Key, device uint8, key Key) bool {
	q.mu.Lock()
	defer q.mu.Unlock()
	k := slotKey{identity, device}
	if r := q.rows[k]; r != nil && r.key == key && r.silent {
		delete(q.rows, k)
		return true
	}
	return false
}

// Forget drops what is held for a device that left its list.
func (q *Quiet) Forget(identity Key, device uint8) { q.Heard(identity, device) }

// State is what to do with the copy to the device on key now, version
// being the version of the list that names it. a clock set back counts no
// time.
func (q *Quiet) State(identity Key, device uint8, key Key, version uint64, now time.Time) QuietState {
	q.mu.Lock()
	defer q.mu.Unlock()
	k := slotKey{identity, device}
	r := q.row(k, key)
	if r == nil {
		return Open
	}
	if r.silent {
		if r.under == version {
			if now.Sub(r.probed) >= QuietProbe {
				r.probed = now
				return Rebuild
			}
			return Silent
		}
		// the owner signed a new list since: the device gets another try
		delete(q.rows, k)
		return Open
	}
	if now.Sub(r.first) >= QuietSilent {
		r.silent, r.under, r.probed = true, version, now
		return Silent
	}
	if !r.session.IsZero() && now.Sub(r.session) >= QuietRebuild {
		return Rebuild
	}
	return Open
}
