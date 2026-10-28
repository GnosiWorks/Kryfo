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
)

// From says where a list came from. a first list is taken only from the
// contact's own invite or from inside a session with the contact's identity
// key, never from a third party.
type From struct {
	// Invite is a list carried in the contact's KIN4 (flag bit 4)
	Invite bool
	// Remote is the libsignal identity of the session that carried the
	// list, when it came inside one
	Remote Key
}

// FromInvite is a list read out of the contact's invite.
func FromInvite() From { return From{Invite: true} }

// FromSession is a list that came inside a session whose remote identity
// libsignal reported as remote.
func FromSession(remote Key) From { return From{Remote: remote} }

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

// Known is the list held for one contact identity. the identity is pinned
// from the invite the contact was added by, and is the key the session
// with the contact's phone runs on. not safe for concurrent use; a Book is.
type Known struct {
	identity Key
	cur      *List
	// the list held came from the invite and the session has not sent its
	// own yet
	fromInvite bool
}

// NewKnown starts with no list for the contact whose identity is identity.
func NewKnown(identity Key) *Known { return &Known{identity: identity} }

// Identity is the contact identity this holds lists for.
func (k *Known) Identity() Key { return k.identity }

// Current is the list held, nil before the first.
func (k *Known) Current() *List { return k.cur }

// Pin is the key a session with the contact's device id has to run on:
// the identity for the phone, the listed key for any other device.
func (k *Known) Pin(id uint8) (Key, bool) {
	if id == PhoneID {
		return k.identity, true
	}
	if k.cur == nil {
		return Key{}, false
	}
	e, ok := k.cur.Find(id)
	return e.Key, ok
}

// Vouches is true when a session whose remote identity is remote speaks for
// this contact: the identity itself, or a device on the list held.
func (k *Known) Vouches(remote Key) bool {
	if remote == k.identity {
		return true
	}
	if k.cur == nil {
		return false
	}
	_, ok := k.cur.FindKey(remote)
	return ok
}

// Accept takes a signed list for this contact if it is the contact's,
// came from where it may, and moves forward. on any error the list held
// stays.
func (k *Known) Accept(b []byte, from From, v Verifier) (*List, Outcome, error) {
	l, err := ReadList(b, v)
	if err != nil {
		return nil, 0, err
	}
	return k.accept(l, from)
}

func (k *Known) accept(l *List, from From) (*List, Outcome, error) {
	if l.Identity != k.identity {
		return nil, 0, ErrWrongIdentity
	}
	_, answering := l.Answering()
	if from.Invite {
		// an invite list names the device that answers its first
		// contacts, and counts only until the session sends one
		if !answering || (k.cur != nil && !k.fromInvite) {
			return nil, 0, ErrSource
		}
	} else {
		if answering || !k.Vouches(from.Remote) {
			return nil, 0, ErrSource
		}
	}
	if k.cur == nil {
		k.cur, k.fromInvite = l, from.Invite
		return l, First, nil
	}
	switch {
	case l.Version < k.cur.Version:
		return nil, 0, ErrRollback
	case l.Version == k.cur.Version:
		if !SameBody(l, k.cur) {
			return nil, 0, ErrEquivocation
		}
		if !from.Invite {
			k.fromInvite = false
		}
		return k.cur, Same, nil
	case l.Version-k.cur.Version > VersionWindow:
		return nil, 0, ErrJump
	}
	k.cur, k.fromInvite = l, from.Invite
	return l, Changed, nil
}

// Book is every contact's Known for one container, so no list can name a
// key that is already another contact's.
type Book struct {
	mu    sync.Mutex
	known map[Key]*Known
}

// NewBook is an empty book.
func NewBook() *Book { return &Book{known: map[Key]*Known{}} }

// Add starts a contact identity, or gives the one held. an identity that
// is a device of another contact is refused.
func (b *Book) Add(identity Key) (*Known, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if k, ok := b.known[identity]; ok {
		return k, nil
	}
	for _, o := range b.known {
		if o.cur != nil {
			if _, ok := o.cur.FindKey(identity); ok {
				return nil, ErrTaken
			}
		}
	}
	k := NewKnown(identity)
	b.known[identity] = k
	return k, nil
}

// Get is the contact identity's Known.
func (b *Book) Get(identity Key) (*Known, bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	return k, ok
}

// Forget drops a contact identity, as when the contact is deleted.
func (b *Book) Forget(identity Key) {
	b.mu.Lock()
	defer b.mu.Unlock()
	delete(b.known, identity)
}

// Accept is Known.Accept for the contact identity, refusing a list that
// names a key any other contact holds as its identity or a device.
func (b *Book) Accept(identity Key, list []byte, from From, v Verifier) (*List, Outcome, error) {
	l, err := ReadList(list, v)
	if err != nil {
		return nil, 0, err
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return nil, 0, ErrWrongIdentity
	}
	for other, o := range b.known {
		if other == identity {
			continue
		}
		for _, e := range l.Devices {
			if e.Key == other {
				return nil, 0, ErrTaken
			}
			if o.cur != nil {
				if _, ok := o.cur.FindKey(e.Key); ok {
					return nil, 0, ErrTaken
				}
			}
		}
	}
	return k.accept(l, from)
}

// TakeBundle is Known.TakeBundle for the contact identity.
func (b *Book) TakeBundle(identity Key, p []byte, from From) (*Block, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return nil, ErrWrongIdentity
	}
	return k.TakeBundle(p, from)
}

// Pin is Known.Pin for the contact identity.
func (b *Book) Pin(identity Key, id uint8) (Key, bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k, ok := b.known[identity]
	if !ok {
		return Key{}, false
	}
	return k.Pin(id)
}
