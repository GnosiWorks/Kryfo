// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"encoding/json"
	"testing"
)

// a list the phone held, from the history copy: a first list on a linked
// device, never on the phone, never for someone not a contact
func TestACopiedListOnlyOnALinkedDevice(t *testing.T) {
	l := devTestShim(t)
	me, bob, cy := newDevAcct(t, l), newDevAcct(t, l), newDevAcct(t, l)
	desk := newDevSigner(t, l)
	deskE := me.link(t, desk.pub, false)
	outcome := func(answer string) string {
		var out devOut
		if err := json.Unmarshal([]byte(answer), &out); err != nil {
			t.Fatal(err)
		}
		if out.Err != "" {
			return out.Err
		}
		return out.Outcome
	}
	copyList := func(who *devAcct) string {
		return outcome(devCallJSON("copy_list", devJSON(t, map[string]any{
			"ident": 0, "identity": hexKey(who.id.pub), "list": who.wire,
		})))
	}
	// the phone itself: never from a copy
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine":     []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub)}},
		"contacts": []map[string]any{{"ident": 0, "identity": hexKey(bob.id.pub)}},
	})))
	if got := copyList(bob); got != "source" {
		t.Fatalf("a copied list on the phone: %s", got)
	}
	// the desk: bob's first list, the same again, never cy's
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine":     []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub), "key": hexKey(desk.pub), "dev": int(deskE.ID)}},
		"contacts": []map[string]any{{"ident": 0, "identity": hexKey(bob.id.pub)}},
	})))
	if got := copyList(bob); got != "first" {
		t.Fatalf("bob's list from the copy: %s", got)
	}
	if got := copyList(bob); got != "same" {
		t.Fatalf("bob's list again: %s", got)
	}
	if got := copyList(cy); got != "unknown" {
		t.Fatalf("a stranger's list from the copy: %s", got)
	}
	if got := outcome(devCallJSON("copy_list", devJSON(t, map[string]any{
		"ident": 3, "identity": hexKey(bob.id.pub), "list": bob.wire,
	}))); got != "source" {
		t.Fatalf("another identity of mine: %s", got)
	}
}

// a list my phone passed on: on a linked device alone, inside the session
// whose remote is my phone, for a contact, forward only
func TestAListFromMyPhoneOnlyOnItsSession(t *testing.T) {
	l := devTestShim(t)
	me, bob, cy := newDevAcct(t, l), newDevAcct(t, l), newDevAcct(t, l)
	desk := newDevSigner(t, l)
	deskE := me.link(t, desk.pub, false)
	outcome := func(answer string) string {
		var out devOut
		if err := json.Unmarshal([]byte(answer), &out); err != nil {
			t.Fatal(err)
		}
		if out.Err != "" {
			return out.Err
		}
		return out.Outcome
	}
	phoneList := func(who *devAcct, wire []byte, remote string) string {
		return outcome(devSessionJSON("phone_list", devJSON(t, map[string]any{
			"ident": 0, "identity": hexKey(who.id.pub), "list": wire, "remote": remote,
		})))
	}
	// the phone itself: never
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine":     []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub)}},
		"contacts": []map[string]any{{"ident": 0, "identity": hexKey(bob.id.pub)}},
	})))
	if got := phoneList(bob, bob.wire, hexKey(me.id.pub)); got != "source" {
		t.Fatalf("a passed list on the phone: %s", got)
	}
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine":     []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub), "key": hexKey(desk.pub), "dev": int(deskE.ID)}},
		"contacts": []map[string]any{{"ident": 0, "identity": hexKey(bob.id.pub)}},
	})))
	first := bob.wire
	// only inside my phone's session: not bob's, not the desk's own
	for _, r := range []string{hexKey(bob.id.pub), hexKey(desk.pub), hexKey(cy.id.pub)} {
		if got := phoneList(bob, first, r); got != "source" {
			t.Fatalf("a passed list on another session: %s", got)
		}
	}
	if got := phoneList(bob, first, hexKey(me.id.pub)); got != "first" {
		t.Fatalf("bob's list from my phone: %s", got)
	}
	bob.link(t, newDevSigner(t, l).pub, false)
	if got := phoneList(bob, bob.wire, hexKey(me.id.pub)); got != "changed" {
		t.Fatalf("bob's newer list from my phone: %s", got)
	}
	if got := phoneList(bob, first, hexKey(me.id.pub)); got != "rollback" {
		t.Fatalf("bob's older list from my phone: %s", got)
	}
	if got := phoneList(cy, cy.wire, hexKey(me.id.pub)); got != "unknown" {
		t.Fatalf("a stranger's list from my phone: %s", got)
	}
}
