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
	aHex := hex.EncodeToString(a.pub[:])
	keys := fakeDeviceKeys{}
	keys.put(a.pub, 5, da.pub)
	putIdentity(dvA1, a)
	putIdentity(dvA5, da)
	was := devicePairsOn.Load()
	devicePairsOn.Store(true)
	setDeviceKeys(keys)
	t.Cleanup(func() {
		identDrop(dvA1)
		identDrop(dvA5)
		devicePairsOn.Store(was)
		setDeviceKeys(nil)
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

	// as 0.6.0's first builds loaded it: no id, so the desk is no device
	load(desk)
	if isLinked(dvA5) {
		t.Fatal("linked with no id in the load")
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

	// a load without it again (an unlink): a phone once more
	delete(desk, "dev")
	load(desk)
	if isLinked(dvA5) {
		t.Fatal("still linked after a load without its id")
	}
	// an id with no key of its own is refused, the last state kept
	bad := map[string]any{"ident": dvA5, "identity": "05" + aHex, "dev": 5}
	if out := devCallJSON("load", devJSON(t, map[string]any{
		"mine": []map[string]any{bad},
	})); !strings.Contains(out, "err") {
		t.Fatalf("a device id with the identity as its key: %s", out)
	}
}
