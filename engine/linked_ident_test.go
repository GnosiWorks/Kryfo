// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a linked container learns from the app's load that it is device n of its
// phone's identity: without it every address is derived as a phone and
// nothing its phone or a contact sends reaches it

import (
	"encoding/hex"
	"strings"
	"testing"
)

func TestALoadMakesTheContainerItsDevice(t *testing.T) {
	devTestShim(t)
	a, da := fixedXid(t, v4Keys["a"]), fixedXid(t, v4Keys["da"])
	b, db := fixedXid(t, v4Keys["b"]), fixedXid(t, v4Keys["db"])
	aHex, bHex := hex.EncodeToString(a.pub[:]), hex.EncodeToString(b.pub[:])
	keys := fakeDeviceKeys{}
	keys.put(a.pub, 5, da.pub)
	keys.put(b.pub, 9, db.pub)
	putIdentity(dvA1, a)
	putIdentity(dvA5, da)
	putIdentity(dvB9, db)
	was := devicePairsOn.Load()
	devicePairsOn.Store(true)
	setDeviceKeys(keys)
	t.Cleanup(func() {
		identDrop(dvA1)
		identDrop(dvA5)
		identDrop(dvB9)
		devicePairsOn.Store(was)
		setDeviceKeys(devKeySource{})
	})
	load := func(mine map[string]any) {
		t.Helper()
		mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
			"mine": []map[string]any{mine},
		})))
	}
	seed := strings.Repeat("ab", 32)
	desk := map[string]any{
		"ident": dvA5, "identity": "05" + aHex,
		"key": "05" + hex.EncodeToString(da.pub[:]),
	}

	// before the load says what it is, the desk is no device: its phone's
	// pair cannot be named, so nothing its phone sends is heard
	if isLinked(dvA5) {
		t.Fatal("linked before any load")
	}
	if _, _, err := pairArg(dvA5, aHex+"/1/5."+seed); err == nil {
		t.Fatal("the phone's pair named by a container that is no device")
	}

	// with its id: the desk's pair with its phone is the phone's pair
	desk["dev"] = 5
	load(desk)
	if !isLinked(dvA5) {
		t.Fatal("not linked after a load with its id")
	}
	pc := mustPair(t, dvA5, aHex+"/1/5."+seed)
	phone := mustPair(t, dvA1, aHex+"/5/1."+seed)
	_, pcRcv, err := pc.rcvAddress()
	if err != nil {
		t.Fatal(err)
	}
	phoneTo, err := phone.theirAddress()
	if err != nil {
		t.Fatal(err)
	}
	if pcRcv != phoneTo {
		t.Fatalf("the phone sends to %s, the desk listens on %s", phoneTo, pcRcv)
	}
	// the phone's last word to a removed desk goes to the opener address
	po, err := phone.openerOf()
	if err != nil {
		t.Fatal(err)
	}
	evt, err := devOpenerWrap(po.v4(), "bye")
	if err != nil {
		t.Fatal(err)
	}
	pco, err := pc.openerOf()
	if err != nil {
		t.Fatal(err)
	}
	if got, _, err := devOpenerUnwrapStamped(pco.v4(), evt); err != nil || got != "bye" {
		t.Fatalf("the desk's opener address: %q %v", got, err)
	}
	// no identity pair on a linked container
	if _, _, err := pairArg(dvA5, aHex+"."+seed); err == nil {
		t.Fatal("a linked container named an identity pair")
	}
	// a contact's device and this one agree on their pair: b's desk 9 is
	// linked here too, as its own container would be
	desk["dev"] = 5
	load2 := func(mine ...map[string]any) string {
		return devCallJSON("load", devJSON(t, map[string]any{"mine": mine}))
	}
	bDesk := map[string]any{
		"ident": dvB9, "identity": "05" + bHex,
		"key": "05" + hex.EncodeToString(db.pub[:]), "dev": 9,
	}
	mustOK(t, load2(desk, bDesk))
	x := mustPair(t, dvA5, bHex+"/9/5."+seed)
	y := mustPair(t, dvB9, aHex+"/5/9."+seed)
	_, xRcv, err := x.rcvAddress()
	if err != nil {
		t.Fatal(err)
	}
	yTo, err := y.theirAddress()
	if err != nil {
		t.Fatal(err)
	}
	if xRcv != yTo {
		t.Fatalf("b's desk sends to %s, a's desk listens on %s", yTo, xRcv)
	}

	// loads that do not hold are refused and the linked state stays
	for name, bad := range map[string]map[string]any{
		"an id with the identity as its key": {"ident": dvA5, "identity": "05" + aHex, "key": "05" + aHex, "dev": 5},
		"an id with no key of its own":       {"ident": dvA5, "identity": "05" + aHex, "dev": 5},
		"a key of its own with no id":        {"ident": dvA5, "identity": desk["identity"], "key": desk["key"]},
		"a key of its own as device 1":       {"ident": dvA5, "identity": desk["identity"], "key": desk["key"], "dev": 1},
		"device 128":                         {"ident": dvA5, "identity": desk["identity"], "key": desk["key"], "dev": 128},
		"device -1":                          {"ident": dvA5, "identity": desk["identity"], "key": desk["key"], "dev": -1},
	} {
		if out := load2(bad); !strings.Contains(out, "malformed") {
			t.Fatalf("%s: %s", name, out)
		}
		if !isLinked(dvA5) || !isLinked(dvB9) {
			t.Fatalf("%s: the linked state went", name)
		}
	}

	// a phone's own load (no id, its key the identity): a phone once more
	mustOK(t, load2(map[string]any{"ident": dvA5, "identity": "05" + aHex}))
	if isLinked(dvA5) || isLinked(dvB9) {
		t.Fatal("still linked after a phone's load")
	}
}
