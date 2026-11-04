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
	me.link(t, desk.pub, false)
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
		"mine":     []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub), "key": hexKey(desk.pub)}},
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
