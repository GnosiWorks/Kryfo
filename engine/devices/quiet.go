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
)

// QuietState is what a sender does with a device's copy.
type QuietState int

const (
	// Open: the copy goes on the session held
	Open QuietState = iota
	// Rebuild: the session goes, and the copy waits for a fresh bundle
	Rebuild
	// Silent: no copy until the device is heard from or its list moves
	Silent
)

type slotKey struct {
	identity Key
	device   uint8
}

type quietRow struct {
	// the first copy on a session the device never answered since
	first time.Time
	// the first copy on the session held now
	session time.Time
	silent  bool
	// the list version the device went silent under
	under uint64
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

// Sent records a copy sealed to the device on a session it has not
// answered on.
func (q *Quiet) Sent(identity Key, device uint8, now time.Time) {
	q.mu.Lock()
	defer q.mu.Unlock()
	k := slotKey{identity, device}
	r := q.rows[k]
	if r == nil {
		r = &quietRow{}
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

// Forget drops what is held for a device that left its list.
func (q *Quiet) Forget(identity Key, device uint8) { q.Heard(identity, device) }

// State is what to do with the device's copy now, version being the
// version of the list that names it. a clock set back counts no time.
func (q *Quiet) State(identity Key, device uint8, version uint64, now time.Time) QuietState {
	q.mu.Lock()
	defer q.mu.Unlock()
	k := slotKey{identity, device}
	r := q.rows[k]
	if r == nil {
		return Open
	}
	if r.silent {
		if r.under == version {
			return Silent
		}
		// the owner signed a new list since: the device gets another try
		delete(q.rows, k)
		return Open
	}
	if now.Sub(r.first) >= QuietSilent {
		r.silent, r.under = true, version
		return Silent
	}
	if !r.session.IsZero() && now.Sub(r.session) >= QuietRebuild {
		return Rebuild
	}
	return Open
}
