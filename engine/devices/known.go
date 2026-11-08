// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"errors"
	"sync"
)

var (
	ErrRollback     = errors.New("devices: older list than the one held")
	ErrEquivocation = errors.New("devices: two lists at one version")
	ErrJump         = errors.New("devices: version too far ahead")
	ErrSource       = errors.New("devices: list from a place that cannot vouch for it")
	ErrTaken        = errors.New("devices: key held under another contact")
	ErrUnknown      = errors.New("devices: not a contact in this book")
)

// RollbackError is a list refused as older than the one held, which came
// from the identity's own phone. Held is the signed list held, to send
// back inside that session: another copy of the phone signed it, and this
// one signs above it (List.Above).
type RollbackError struct{ Held []byte }

func (e *RollbackError) Error() string        { return ErrRollback.Error() }
func (e *RollbackError) Is(target error) bool { return target == ErrRollback }

// From says where a list or a bundle came from. a first list is taken only
// from the contact's own invite or from inside a session with the
// contact's identity key, never from a third party.
type From struct {
	invite bool
	link   bool
	copy   bool
	phone  bool
	remote Key
}

// FromInvite is a list read out of the contact's invite (KIN4 bit 4).
func FromInvite() From { return From{invite: true} }

// FromLink is what this device's own phone handed over while linking it,
// on the channel the person confirmed. only an own list takes it (Own.Set);
// a contact's list or bundle never does. only the link layer builds one.
func FromLink() From { return From{link: true} }

// FromCopy is a contact's list my own phone held, carried in the history
// copy it sent this linked device under the link's stream key. it gives a
// first list only, never moves one held, and never carries a bundle or an
// own list. only the engine's copy call builds one.
func FromCopy() From { return From{copy: true} }

// FromMyPhone is a contact's list my own phone took and passed on to this
// linked device, inside the session whose remote is my identity key. it
// moves a list forward only, never answers a rollback, never carries a
// bundle or an own list. only the engine's session door builds one.
func FromMyPhone() From { return From{phone: true} }

// FromSession is what came inside a session whose remote identity is
// remote, as ks_decrypt_* returned it. only the session layer builds one;
// a key read out of a message is never a remote.
func FromSession(remote Key) From { return From{remote: remote} }

// Outcome is what Accept did with a list.
type Outcome int

const (
	// Same is the list already held, maybe under another signature
	Same Outcome = iota
	// First is the contact's first list
	First
	// Changed is a newer list. the app treats it as a key change: a calm
	// notice, sends held only for a verified contact
	Changed
)

// what is held for one contact identity. the identity is pinned from the
// invite the contact was added by, and is the key the session with the
// contact's phone runs on. reached only through a Book
type known struct {
	identity Key
	cur      *List
	// the list held came from the invite and the session has not sent its
	// own yet
	fromInvite bool
	// listed keys a message from this contact decrypted under
	proven map[Key]bool
	// listed keys someone else holds: never routed to for this contact
	disputed map[Key]bool
	// a session with one of its devices was post-quantum
	pq bool
}

func newKnown(identity Key) *known {
	return &known{identity: identity, proven: map[Key]bool{}, disputed: map[Key]bool{}}
}

// the key a session with the contact's device id has to run on: the
// identity for the phone, the listed key for any other device
func (k *known) pin(id uint8) (Key, bool) {
	if id == PhoneID {
		return k.identity, true
	}
	if k.cur == nil {
		return Key{}, false
	}
	e, ok := k.cur.Find(id)
	if !ok || k.disputed[e.Key] {
		return Key{}, false
	}
	return e.Key, true
}

// whether a session whose remote identity is remote speaks for this
// contact: the identity itself, or a device on the list held
func (k *known) vouches(remote Key) bool {
	if remote == k.identity {
		return true
	}
	if k.cur == nil || k.disputed[remote] {
		return false
	}
	_, ok := k.cur.FindKey(remote)
	return ok
}

// a second body at the version held is the identity's key signing two
// lists, whoever carries it: nobody without that key can make one
func (k *known) equivocates(l *List) bool {
	return k.cur != nil && l.Version == k.cur.Version && !SameBody(l, k.cur)
}

// takes l if it is the contact's, came from where it may, and moves
// forward. on any error the list held stays
func (k *known) accept(l *List, from From) (*List, Outcome, error) {
	if l.Identity != k.identity {
		return nil, 0, ErrWrongIdentity
	}
	if k.equivocates(l) {
		return nil, 0, ErrEquivocation
	}
	_, answering := l.Answering()
	if from.link {
		return nil, 0, ErrSource
	}
	if from.copy {
		// the phone's word stands in for the contact's session only until
		// one speaks: a first list, or the very one held
		switch {
		case answering:
			return nil, 0, ErrSource
		case k.cur == nil:
			k.cur, k.fromInvite = l, false
			return l, First, nil
		case l.Version == k.cur.Version:
			return k.cur, Same, nil
		}
		return nil, 0, ErrSource
	}
	if from.phone {
		// my phone's word on a list the contact signed: forward only
		if answering {
			return nil, 0, ErrSource
		}
	} else if from.invite {
		// an invite list names the device that answers its first
		// contacts, and counts only until the session sends one
		if !answering || (k.cur != nil && !k.fromInvite) {
			return nil, 0, ErrSource
		}
	} else if answering || !k.vouches(from.remote) {
		return nil, 0, ErrSource
	}
	if k.cur == nil {
		k.cur, k.fromInvite = l, from.invite
		return l, First, nil
	}
	switch {
	case l.Version < k.cur.Version:
		// only the identity's own phone learns what is held, so it can
		// sign above it
		if !from.invite && !from.phone && from.remote == k.identity {
			return nil, 0, &RollbackError{Held: k.cur.Wire()}
		}
		return nil, 0, ErrRollback
	case l.Version == k.cur.Version:
		if !from.invite {
			k.fromInvite = false
		}
		return k.cur, Same, nil
	case l.Version-k.cur.Version > VersionWindow:
		return nil, 0, ErrJump
	}
	k.cur, k.fromInvite = l, from.invite
	for p := range k.proven {
		if _, ok := l.FindKey(p); !ok {
			delete(k.proven, p)
		}
	}
	return l, Changed, nil
}

// a KDB1 that came inside a session, for a device on the list held: same
// device id, same registration id, on the device's own key or the identity
// for the phone. it comes from the identity's own session or the device's,
// never one device handing over another's, so an old bundle is not replayed
func (k *known) takeBundle(p []byte, from From) (*Block, error) {
	if from.invite || from.link || from.copy || from.phone || !k.vouches(from.remote) {
		return nil, ErrSource
	}
	b, err := ParseBundle(p, k.identity)
	if err != nil {
		return nil, err
	}
	if k.cur == nil {
		return nil, ErrNotListed
	}
	e, ok := k.cur.Find(b.Device)
	if !ok || e.Reg != b.Reg || k.disputed[e.Key] {
		return nil, ErrNotListed
	}
	if e.Phone == b.HasKey || (b.HasKey && b.Key != e.Key) {
		return nil, ErrNotListed
	}
	if from.remote != k.identity && from.remote != e.Key {
		return nil, ErrSource
	}
	return b, nil
}

// Book is every contact's lists for one container, and the one way to
// them. a key counts as a contact's only once proven: a message from that
// contact decrypted on a session whose libsignal remote was that key. a
// list can name any public key, so a claim alone never takes a key from
// anyone.
type Book struct {
	mu    sync.Mutex
	known map[Key]*known
	// this device's own identities and device keys
	own map[Key]bool
}

// NewBook is a book that knows own: this container's identities and its
// devices' keys, which no contact can list.
func NewBook(own ...Key) *Book {
	b := &Book{known: map[Key]*known{}, own: map[Key]bool{}}
	for _, k := range own {
		b.own[k] = true
	}
	return b
}

// Own adds keys of this container, as when a device of its own is linked.
func (b *Book) Own(keys ...Key) []Key {
	b.mu.Lock()
	defer b.mu.Unlock()
	for _, k := range keys {
		b.own[k] = true
	}
	return b.settle()
}

// whether key is held by anyone but the contact except: this container,
// another contact's identity, or a key proven under another contact
func (b *Book) heldElsewhere(key, except Key) bool {
	if b.own[key] {
		return true
	}
	for id, o := range b.known {
		if id == except {
			continue
		}
		if id == key || o.proven[key] {
			return true
		}
	}
	return false
}

// marks every listed key someone else holds, and gives the contacts whose
// lists name one: the alarm goes on them
func (b *Book) settle() []Key {
	var claimants []Key
	for id, k := range b.known {
		clear(k.disputed)
		if k.cur == nil {
			continue
		}
		for _, e := range k.cur.Devices {
			if !e.Phone && b.heldElsewhere(e.Key, id) {
				k.disputed[e.Key] = true
			}
		}
		if len(k.disputed) > 0 {
			claimants = append(claimants, id)
		}
	}
	return claimants
}

// Add starts a contact identity, which must already be proven: a KIN4
// signed by it, or a session that runs on it. one of this container's own
// keys, or a key proven as another contact's device, is refused; an
// identity some list only claims is taken, and that list's owner is the
// one to doubt.
func (b *Book) Add(identity Key) ([]Key, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if _, ok := b.known[identity]; ok {
		return nil, nil
	}
	if b.heldElsewhere(identity, identity) {
		return nil, ErrTaken
	}
	b.known[identity] = newKnown(identity)
	return b.settle(), nil
}

// Forget drops a contact identity, as when the contact is deleted.
func (b *Book) Forget(identity Key) []Key {
	b.mu.Lock()
	defer b.mu.Unlock()
	delete(b.known, identity)
	return b.settle()
}

// Accept takes a signed list for the contact identity. a second body at the
// version held is ErrEquivocation from any carrier. an entry naming a key
// someone else holds is taken but never routed to, and the contact comes
// back among the claimants for the alarm: refusing the whole list would
// let one clash hold back every later change, a removal included.
func (b *Book) Accept(identity Key, list []byte, from From, v Verifier) (*List, Outcome, []Key, error) {
	l, err := ReadList(list, v)
	if err != nil {
		return nil, 0, nil, err
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return nil, 0, nil, ErrUnknown
	}
	if l.Identity != identity {
		return nil, 0, nil, ErrWrongIdentity
	}
	if k.equivocates(l) {
		return nil, 0, nil, ErrEquivocation
	}
	got, out, err := k.accept(l, from)
	if err != nil {
		return nil, 0, nil, err
	}
	return got, out, b.settle(), nil
}

// Proven records that a message from the contact identity decrypted on a
// session whose libsignal remote was remote (what ks_decrypt_* returned).
// it gives the contacts whose lists claim that key too: the alarm goes on
// them, and their claim is never routed to.
func (b *Book) Proven(identity, remote Key) ([]Key, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return nil, ErrUnknown
	}
	if remote == identity {
		return b.settle(), nil
	}
	if k.cur == nil {
		return nil, ErrNotListed
	}
	if _, ok := k.cur.FindKey(remote); !ok {
		return nil, ErrNotListed
	}
	if b.heldElsewhere(remote, identity) {
		return nil, ErrTaken
	}
	k.proven[remote] = true
	return b.settle(), nil
}

// SawPQ records that a session with a device of the contact identity is
// post-quantum. it never goes back: from then on a classic session with
// any of its devices is not sealed on.
func (b *Book) SawPQ(identity Key) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return ErrUnknown
	}
	k.pq = true
	return nil
}

// PQ is true once a session with any device of the contact identity was
// post-quantum.
func (b *Book) PQ(identity Key) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	return ok && k.pq
}

// Held is a session the app keeps with a device: its id and the remote
// key its record runs on (ks_session_info).
type Held struct {
	ID  uint8
	Key Key
}

// Stale are the device ids in held, sessions the app keeps with the
// contact identity's devices, that the list held no longer routes to on
// that key: their sessions, pair seeds and addresses go. the phone is never
// stale here; its session goes only with the contact.
func (b *Book) Stale(identity Key, held []Held) []uint8 {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	var out []uint8
	for _, h := range held {
		if h.ID == PhoneID {
			continue
		}
		if !ok {
			out = append(out, h.ID)
			continue
		}
		if pin, routed := k.pin(h.ID); !routed || pin != h.Key {
			out = append(out, h.ID)
		}
	}
	return out
}

// Admit says whether a message that opened on a session with the contact
// identity's device id may count as the contact's: the phone on the
// identity, any other device only while listed, undisputed, and on its
// listed key. remote is what ks_decrypt_* returned, never a key a message
// names.
func (b *Book) Admit(identity Key, id uint8, remote Key) error {
	_, err := b.admit(identity, id, remote)
	return err
}

// AdmitOpener is Admit for an opener, whose registration id
// (ks_prekey_message_info) must also be the listed one. a phone with no
// list yet is checked on its key alone.
func (b *Book) AdmitOpener(identity Key, id uint8, remote Key, reg uint32) error {
	e, err := b.admit(identity, id, remote)
	if err != nil {
		return err
	}
	if e != nil && e.Reg != reg {
		return ErrNotItsKey
	}
	return nil
}

func (b *Book) admit(identity Key, id uint8, remote Key) (*Entry, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return nil, ErrUnknown
	}
	if id == PhoneID {
		if remote != identity {
			return nil, ErrNotItsKey
		}
		if k.cur == nil {
			return nil, nil
		}
		e, _ := k.cur.Find(PhoneID)
		return &e, nil
	}
	if k.cur == nil {
		return nil, ErrNotListed
	}
	e, ok := k.cur.Find(id)
	if !ok {
		return nil, ErrNotListed
	}
	if k.disputed[e.Key] {
		return nil, ErrTaken
	}
	if e.Key != remote {
		return nil, ErrNotItsKey
	}
	return &e, nil
}

// the contact identity's list held and the entries a copy goes to
func (b *Book) routes(identity Key) (*List, []Entry, bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok || k.cur == nil {
		return nil, nil, ok
	}
	var out []Entry
	for _, e := range k.cur.Devices {
		if _, routed := k.pin(e.ID); routed {
			out = append(out, e)
		}
	}
	return k.cur, out, true
}

// Claimants are the contacts whose lists name a key someone else holds.
func (b *Book) Claimants() []Key {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.settle()
}

// Current is the list held for the contact identity, nil before the first.
func (b *Book) Current(identity Key) *List {
	b.mu.Lock()
	defer b.mu.Unlock()
	if k, ok := b.known[identity]; ok {
		return k.cur
	}
	return nil
}

// Pin is the key a session with the contact's device id has to run on.
func (b *Book) Pin(identity Key, id uint8) (Key, bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return Key{}, false
	}
	return k.pin(id)
}

// Vouches is true when a session whose remote identity is remote speaks
// for the contact identity.
func (b *Book) Vouches(identity, remote Key) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	return ok && k.vouches(remote)
}

// TakeBundle reads a KDB1 for the contact identity.
func (b *Book) TakeBundle(identity Key, p []byte, from From) (*Block, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return nil, ErrUnknown
	}
	return k.takeBundle(p, from)
}
