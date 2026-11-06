// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"encoding/json"
	"slices"
	"testing"

	"github.com/halo/engine/devices"
)

func devOutOf(t *testing.T, answer string) devOut {
	t.Helper()
	var out devOut
	if err := json.Unmarshal([]byte(answer), &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func devX(k devices.Key) (out [32]byte) {
	copy(out[:], k[1:])
	return
}

// the phone signs its list without the device it removes: the device is
// no longer my own at once (nothing of it is admitted, its address goes),
// the phone itself and an id the list does not name are refused, and a
// linked device signs nothing
func TestARemovalIsSignedWithoutTheDevice(t *testing.T) {
	l := devTestShim(t)
	me := newDevAcct(t, l)
	deskKey, lapKey := newDevSigner(t, l).pub, newDevSigner(t, l).pub
	desk := me.link(t, deskKey, false)
	lap := me.link(t, lapKey, false)
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine": []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub)}},
	})))
	mustOK(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": me.wire})))
	remove := func(ids ...int) devOut {
		held := []map[string]any{}
		for _, id := range ids {
			held = append(held, map[string]any{"id": id})
		}
		return devOutOf(t, devCallJSON("own_remove", devJSON(t, map[string]any{"ident": 0, "held": held})))
	}
	if out := remove(1); out.Err != "phone" {
		t.Fatalf("the phone removed: %+v", out)
	}
	// an id the list does not hold: the devices' ids are drawn at random
	unlisted := 99
	for unlisted == int(desk.ID) || unlisted == int(lap.ID) {
		unlisted++
	}
	if out := remove(unlisted); out.Err != "not_listed" {
		t.Fatalf("an unlisted id: %+v", out)
	}
	if out := remove(); out.Err != "malformed" {
		t.Fatalf("nothing named: %+v", out)
	}
	if out := remove(int(desk.ID), int(desk.ID)); out.Err != "not_listed" {
		t.Fatalf("one id twice: %+v", out)
	}
	out := remove(int(desk.ID))
	if out.Err != "" || out.Outcome != "removed" || len(out.Gone) != 1 || out.Gone[0].Key != hexKey(deskKey) {
		t.Fatalf("the desk: %+v", out)
	}
	// nothing changed until the phone signed it and took it
	var src devKeySource
	if _, ok := src.deviceKey(0, devX(me.id.pub), desk.ID); !ok {
		t.Fatal("the desk went before the list was signed")
	}
	sig, err := me.id.Sign(devices.ContextList, out.List)
	if err != nil {
		t.Fatal(err)
	}
	set := devOutOf(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": append(slices.Clone(out.List), sig...)})))
	if set.Err != "" || len(set.Gone) != 1 || set.Gone[0].ID != int(desk.ID) {
		t.Fatalf("the signed removal: %+v", set)
	}
	cur := devNow().own.Current(me.id.pub)
	if cur.Version <= me.list.Version || len(cur.Devices) != 2 {
		t.Fatalf("the list after: v%d, %d devices", cur.Version, len(cur.Devices))
	}
	if _, ok := cur.Find(lap.ID); !ok {
		t.Fatal("the laptop went with the desk")
	}
	// the desk is let in nowhere, and has no address
	opened := devOutOf(t, devSessionJSON("opened", devJSON(t, map[string]any{
		"ident": 0, "identity": hexKey(me.id.pub), "device": int(desk.ID), "remote": hexKey(deskKey),
	})))
	if opened.Err != "not_listed" {
		t.Fatalf("a copy from the removed desk: %+v", opened)
	}
	if _, ok := src.deviceKey(0, devX(me.id.pub), desk.ID); ok {
		t.Fatal("the removed desk still has an address")
	}
	// remove all: both in one list
	if out := remove(int(lap.ID), int(desk.ID)); out.Err != "not_listed" {
		t.Fatalf("the desk again: %+v", out)
	}
	if out := remove(int(lap.ID)); out.Err != "" || len(out.Gone) != 1 {
		t.Fatalf("the laptop: %+v", out)
	}
	// a linked device signs no list of its own
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine": []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub), "key": hexKey(lapKey)}},
	})))
	mustOK(t, devSessionJSON("own_set", devJSON(t, map[string]any{
		"ident": 0, "identity": hexKey(me.id.pub), "list": me.wire, "remote": hexKey(me.id.pub),
	})))
	if out := remove(int(desk.ID)); out.Err != "source" {
		t.Fatalf("a linked device removing: %+v", out)
	}
	if out := devOutOf(t, devCallJSON("own_restored", devJSON(t, map[string]any{"ident": 0}))); out.Err != "source" {
		t.Fatalf("a linked device restoring: %+v", out)
	}
}

// the first list a restored phone signs names the phone alone, above any
// version the phone in the backup may have signed since; a phone that
// never linked has none to sign
func TestTheRestoredListIsThePhoneAlone(t *testing.T) {
	l := devTestShim(t)
	me, fresh := newDevAcct(t, l), newDevAcct(t, l)
	desk := me.link(t, newDevSigner(t, l).pub, false)
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine": []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub)}},
	})))
	mustOK(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": me.wire})))
	out := devOutOf(t, devCallJSON("own_restored", devJSON(t, map[string]any{"ident": 0})))
	if out.Err != "" || out.Outcome != "restored" || len(out.Gone) != 1 || out.Gone[0].ID != int(desk.ID) {
		t.Fatalf("restored: %+v", out)
	}
	sig, err := me.id.Sign(devices.ContextList, out.List)
	if err != nil {
		t.Fatal(err)
	}
	mustOK(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": append(slices.Clone(out.List), sig...)})))
	cur := devNow().own.Current(me.id.pub)
	if len(cur.Devices) != 1 || !cur.Devices[0].Phone || cur.Version < me.list.Version+1<<40 {
		t.Fatalf("the restored list: v%d over v%d, %d devices", cur.Version, me.list.Version, len(cur.Devices))
	}
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine": []map[string]any{{"ident": 0, "identity": hexKey(fresh.id.pub)}},
	})))
	if out := devOutOf(t, devCallJSON("own_restored", devJSON(t, map[string]any{"ident": 0}))); out.Err != "" || out.Outcome != "none" || out.List != nil {
		t.Fatalf("nothing linked: %+v", out)
	}
}

// a device just removed keeps an address for its last word while the app
// says so: for the address layer alone (nothing of it is admitted), only
// for an id the list does not name, never for the phone, never on a
// linked device, and gone once the app lets it go
func TestALeavingKeyOnlyAddresses(t *testing.T) {
	l := devTestShim(t)
	me := newDevAcct(t, l)
	deskKey := newDevSigner(t, l).pub
	desk := me.link(t, deskKey, false)
	lap := me.link(t, newDevSigner(t, l).pub, false)
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine": []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub)}},
	})))
	out := devOutOf(t, devCallJSON("own_remove", devJSON(t, map[string]any{"ident": 0, "held": []map[string]any{{"id": int(desk.ID)}}})))
	if out.Err != "not_listed" {
		t.Fatalf("no list held yet: %+v", out)
	}
	mustOK(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": me.wire})))
	out = devOutOf(t, devCallJSON("own_remove", devJSON(t, map[string]any{"ident": 0, "held": []map[string]any{{"id": int(desk.ID)}}})))
	sig, err := me.id.Sign(devices.ContextList, out.List)
	if err != nil {
		t.Fatal(err)
	}
	mustOK(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": append(slices.Clone(out.List), sig...)})))
	var src devKeySource
	leave := func(held ...map[string]any) string {
		return devErr(t, devCallJSON("own_leaving", devJSON(t, map[string]any{"ident": 0, "held": held})))
	}
	if e := leave(map[string]any{"id": 1, "key": hexKey(deskKey)}); e != "malformed" {
		t.Fatalf("the phone as leaving: %s", e)
	}
	if e := leave(map[string]any{"id": int(desk.ID), "key": hexKey(me.id.pub)}); e != "malformed" {
		t.Fatalf("my identity as a leaving key: %s", e)
	}
	other := newDevSigner(t, l).pub
	if e := leave(map[string]any{"id": int(desk.ID), "key": hexKey(deskKey)}, map[string]any{"id": int(lap.ID), "key": hexKey(other)}); e != "" {
		t.Fatal(e)
	}
	t.Cleanup(func() { leave() })
	if k, ok := src.deviceKey(0, devX(me.id.pub), desk.ID); !ok || k != devX(deskKey) {
		t.Fatal("the leaving desk has no address for its last word")
	}
	if k, ok := src.deviceKey(0, devX(me.id.pub), lap.ID); !ok || k != devX(lap.Key) {
		t.Fatal("a listed device's key gave way to a leaving one")
	}
	if _, ok := src.deviceKey(1, devX(me.id.pub), desk.ID); ok {
		t.Fatal("a leaving key under another identity")
	}
	opened := devOutOf(t, devSessionJSON("opened", devJSON(t, map[string]any{
		"ident": 0, "identity": hexKey(me.id.pub), "device": int(desk.ID), "remote": hexKey(deskKey),
	})))
	if opened.Err != "not_listed" {
		t.Fatalf("a leaving device let in: %+v", opened)
	}
	if e := leave(); e != "" {
		t.Fatal(e)
	}
	if _, ok := src.deviceKey(0, devX(me.id.pub), desk.ID); ok {
		t.Fatal("the leaving key stayed after it was let go")
	}
	// a linked device has no leaving keys of its own
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine": []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub), "key": hexKey(lap.Key)}},
	})))
	if e := leave(map[string]any{"id": int(desk.ID), "key": hexKey(deskKey)}); e != "source" {
		t.Fatalf("a linked device leaving: %s", e)
	}
}

// a load starts with no leaving keys: the rows set them again, and an id a
// new link reuses never gets the old device's key from a state gone by
func TestALoadForgetsLeavingKeys(t *testing.T) {
	l := devTestShim(t)
	me := newDevAcct(t, l)
	deskKey := newDevSigner(t, l).pub
	desk := me.link(t, deskKey, false)
	load := func() {
		mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
			"mine": []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub)}},
		})))
	}
	load()
	mustOK(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": me.wire})))
	out := devOutOf(t, devCallJSON("own_remove", devJSON(t, map[string]any{"ident": 0, "held": []map[string]any{{"id": int(desk.ID)}}})))
	sig, err := me.id.Sign(devices.ContextList, out.List)
	if err != nil {
		t.Fatal(err)
	}
	mustOK(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": append(slices.Clone(out.List), sig...)})))
	mustOK(t, devCallJSON("own_leaving", devJSON(t, map[string]any{"ident": 0, "held": []map[string]any{{"id": int(desk.ID), "key": hexKey(deskKey)}}})))
	t.Cleanup(devLeavingReset)
	var src devKeySource
	if _, ok := src.deviceKey(0, devX(me.id.pub), desk.ID); !ok {
		t.Fatal("no leaving key before the load")
	}
	load()
	if _, ok := src.deviceKey(0, devX(me.id.pub), desk.ID); ok {
		t.Fatal("a leaving key outlived the load")
	}
}
