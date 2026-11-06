// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"slices"
	"testing"

	"github.com/halo/engine/devices"
)

// a whole link on the link world: digits, both yeses, the bundles, the
// phone keeps the device, both runs taken
func (w *linkWorld) linkWhole(t *testing.T) (*devState, devEntry) {
	t.Helper()
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	jState, dev := w.toBundles(t, jid, pid)
	pt := link(t, "take", map[string]any{"link": pid})
	if pt.Err != "" {
		t.Fatalf("take: %s", pt.Err)
	}
	w.as(w.pState)
	var o devOut
	call(t, devSessionJSON("own_mine", jsonOf(t, map[string]any{"ident": 0, "list": pt.List})), &o)
	if o.Err != "" {
		t.Fatalf("the phone's own list: %s", o.Err)
	}
	if k := link(t, "kept", map[string]any{"link": pid}); k.Err != "" {
		t.Fatalf("kept: %s", k.Err)
	}
	waitState(t, jid, lsDone)
	if jt := link(t, "take", map[string]any{"link": jid}); jt.Err != "" {
		t.Fatalf("joiner take: %s", jt.Err)
	}
	return jState, dev
}

// the phone removes a linked computer, which comes back with a fresh key
// (a computer erases itself before it links): the second link is taken
// above the removal, names the new key alone, and the removed key stays
// out. then a third device and a remove all leave the phone alone
func TestARemovedComputerLinksAgainOnAFreshKey(t *testing.T) {
	w := newLinkWorld(t)
	oldKey := w.devKey.pub
	_, first := w.linkWhole(t)
	w.as(w.pState)
	v1 := w.pState.own.Current(w.phone.id.pub).Version

	out := devOutOf(t, devCallJSON("own_remove", devJSON(t, map[string]any{
		"ident": 0, "held": []map[string]any{{"id": first.ID}},
	})))
	if out.Err != "" || len(out.Gone) != 1 || out.Gone[0].Key != hexKey(oldKey) {
		t.Fatalf("the removal: %+v", out)
	}
	sig, err := w.phone.id.Sign(devices.ContextList, out.List)
	if err != nil {
		t.Fatal(err)
	}
	set := devOutOf(t, devSessionJSON("own_mine", devJSON(t, map[string]any{
		"ident": 0, "list": append(slices.Clone(out.List), sig...),
	})))
	if set.Err != "" || len(set.Gone) != 1 {
		t.Fatalf("the signed removal: %+v", set)
	}
	v2 := w.pState.own.Current(w.phone.id.pub).Version
	if v2 <= v1 || len(w.pState.own.Current(w.phone.id.pub).Devices) != 1 {
		t.Fatalf("after the removal: v%d over v%d", v2, v1)
	}

	// the same computer, erased: a new key, a new link
	w.devKey = newDevSigner(t, w.l)
	jState, second := w.linkWhole(t)
	if second.Key == hexKey(oldKey) || second.Key != hexKey(w.devKey.pub) {
		t.Fatalf("the second link's key: %+v", second)
	}
	w.as(w.pState)
	cur := w.pState.own.Current(w.phone.id.pub)
	if cur.Version <= v2 || len(cur.Devices) != 2 {
		t.Fatalf("the list after the relink: v%d (removal v%d), %d entries", cur.Version, v2, len(cur.Devices))
	}
	if _, ok := cur.FindKey(oldKey); ok {
		t.Fatal("the removed key came back with the relink")
	}
	if e, ok := cur.FindKey(w.devKey.pub); !ok || int(e.ID) != second.ID {
		t.Fatal("the phone's list does not name the relinked computer")
	}
	// the device holds the same list as the phone
	if dl := jState.own.Current(w.phone.id.pub); dl == nil || !devices.SameBody(dl, cur) {
		t.Fatal("the relinked computer holds another list than the phone")
	}
	// the removed key is let in nowhere
	opened := devOutOf(t, devSessionJSON("opened", devJSON(t, map[string]any{
		"ident": 0, "identity": hexKey(w.phone.id.pub), "device": first.ID, "remote": hexKey(oldKey),
	})))
	if second.ID != first.ID && opened.Err != "not_listed" {
		t.Fatalf("a copy from the removed key: %+v", opened)
	}

	// a third device, then remove all: the phone alone, above every list
	w.devKey = newDevSigner(t, w.l)
	_, third := w.linkWhole(t)
	w.as(w.pState)
	all := devOutOf(t, devCallJSON("own_remove", devJSON(t, map[string]any{
		"ident": 0, "held": []map[string]any{{"id": second.ID}, {"id": third.ID}},
	})))
	if all.Err != "" || len(all.Gone) != 2 {
		t.Fatalf("remove all: %+v", all)
	}
	sig, err = w.phone.id.Sign(devices.ContextList, all.List)
	if err != nil {
		t.Fatal(err)
	}
	mustOK(t, devSessionJSON("own_mine", devJSON(t, map[string]any{
		"ident": 0, "list": append(slices.Clone(all.List), sig...),
	})))
	end := w.pState.own.Current(w.phone.id.pub)
	if len(end.Devices) != 1 || end.Version <= cur.Version {
		t.Fatalf("after remove all: v%d, %d entries", end.Version, len(end.Devices))
	}
}
