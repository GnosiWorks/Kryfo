// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/rand"
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

// a list my phone took and passed on moves the list held forward only:
// a first, the same, a newer one; never an older one (and no rollback
// answer), never an answering list, a bundle or an own list
func TestMyPhonePassesAListForwardOnly(t *testing.T) {
	s := newShim()
	me := newAccount(t, s)
	ana := newAccount(t, s)
	book := NewBook(me.id.pub)
	if _, err := book.Add(ana.id.pub); err != nil {
		t.Fatal(err)
	}
	first := ana.wire
	if _, out, _, err := book.Accept(ana.id.pub, first, FromCopy(), s); err != nil || out != First {
		t.Fatalf("the copy's first list: %v %v", out, err)
	}
	ana.linkReg(t)
	newer := ana.wire
	if _, out, _, err := book.Accept(ana.id.pub, newer, FromMyPhone(), s); err != nil || out != Changed {
		t.Fatalf("a newer list from my phone: %v %v", out, err)
	}
	if _, out, _, err := book.Accept(ana.id.pub, newer, FromMyPhone(), s); err != nil || out != Same {
		t.Fatalf("the same list again: %v %v", out, err)
	}
	_, _, _, err := book.Accept(ana.id.pub, first, FromMyPhone(), s)
	var rb *RollbackError
	if !errors.Is(err, ErrRollback) || errors.As(err, &rb) {
		t.Fatalf("an older list from my phone: %v", err)
	}
	if book.Current(ana.id.pub).Version != ana.list.Version {
		t.Fatal("my phone moved the list back")
	}
	// an answering list (an invite's) never comes this way
	k, _ := newKey(t)
	e, err := EntryFor(ana.list, DeviceKeys{Identity: ana.id.pub, Key: k, Reg: 78}, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	e.Answers = true
	n, err := ana.list.Add(e, rand.Reader)
	ana.set(t, n, err)
	if _, _, _, err := book.Accept(ana.id.pub, ana.wire, FromMyPhone(), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an answering list from my phone: %v", err)
	}
	// a first list on a book that holds none
	fresh := NewBook(me.id.pub)
	fresh.Add(ana.id.pub)
	if _, out, _, err := fresh.Accept(ana.id.pub, newer, FromMyPhone(), s); err != nil || out != First {
		t.Fatalf("a first list from my phone: %v %v", out, err)
	}
	d := ana.linkReg(t)
	if _, err := book.TakeBundle(ana.id.pub, poolKDB1(t, 3, 7, d), FromMyPhone()); !errors.Is(err, ErrSource) {
		t.Fatalf("a bundle from my phone: %v", err)
	}
	own := NewOwn()
	b := me.linkReg(t)
	if _, err := own.Set(me.id.pub, me.wire, b.Key, FromMyPhone(), s); !errors.Is(err, ErrSource) {
		t.Fatalf("an own list from my phone: %v", err)
	}
	// another identity's list under ana is refused
	ben := newAccount(t, s)
	if _, _, _, err := book.Accept(ana.id.pub, ben.wire, FromMyPhone(), s); err == nil {
		t.Fatal("ben's list taken as ana's")
	}
}
