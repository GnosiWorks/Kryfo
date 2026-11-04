// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"errors"
	"testing"
)

// the history copy brings the lists the phone held: a first list for a
// linked device, nothing more
func TestACopyGivesAFirstListOnly(t *testing.T) {
	s := newShim()
	me := newAccount(t, s)
	ana := newAccount(t, s)
	book := NewBook(me.id.pub)
	if _, err := book.Add(ana.id.pub); err != nil {
		t.Fatal(err)
	}
	first := ana.wire
	l, out, _, err := book.Accept(ana.id.pub, first, FromCopy(), s)
	if err != nil || out != First || l == nil {
		t.Fatalf("a first list from the copy: %v %v", out, err)
	}
	// the same list again changes nothing
	if _, out, _, err := book.Accept(ana.id.pub, first, FromCopy(), s); err != nil || out != Same {
		t.Fatalf("the same list from the copy: %v %v", out, err)
	}
	// a newer one comes only from ana: the copy never moves a list held
	ana.linkReg(t)
	newer := ana.wire
	if _, _, _, err := book.Accept(ana.id.pub, newer, FromCopy(), s); !errors.Is(err, ErrSource) {
		t.Fatalf("a newer list from the copy: %v", err)
	}
	if book.Current(ana.id.pub).Version != l.Version {
		t.Fatal("the copy moved the list held")
	}
	if _, out, _, err := book.Accept(ana.id.pub, newer, FromSession(ana.id.pub), s); err != nil || out != Changed {
		t.Fatalf("ana's own newer list: %v %v", out, err)
	}
	// an older one from the copy, after ana spoke: refused, no rollback answer
	if _, _, _, err := book.Accept(ana.id.pub, first, FromCopy(), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an older list from the copy: %v", err)
	}
	// never a bundle, never an own list
	d := ana.linkReg(t)
	if _, _, _, err := book.Accept(ana.id.pub, ana.wire, FromSession(ana.id.pub), s); err != nil {
		t.Fatal(err)
	}
	if _, err := book.TakeBundle(ana.id.pub, poolKDB1(t, 3, 7, d), FromCopy()); !errors.Is(err, ErrSource) {
		t.Fatalf("a bundle from the copy: %v", err)
	}
	own := NewOwn()
	b := me.linkReg(t)
	if _, err := own.Set(me.id.pub, me.wire, b.Key, FromCopy(), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an own list from the copy: %v", err)
	}
	// a contact not in the book gets nothing
	ben := newAccount(t, s)
	if _, _, _, err := book.Accept(ben.id.pub, ben.wire, FromCopy(), s); !errors.Is(err, ErrUnknown) {
		t.Fatalf("a stranger's list from the copy: %v", err)
	}
	// another identity's list under ana is refused, as from anywhere
	cy := NewBook(me.id.pub)
	cy.Add(ana.id.pub)
	if _, _, _, err := cy.Accept(ana.id.pub, ben.wire, FromCopy(), s); err == nil {
		t.Fatal("ben's list taken as ana's")
	}
}
