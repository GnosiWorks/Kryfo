// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"testing"
)

func askStream(b byte) *[StreamKeySize]byte {
	k := &[StreamKeySize]byte{}
	for i := range k {
		k[i] = b + byte(i)
	}
	return k
}

func TestBothEndsAskAlike(t *testing.T) {
	bind := [32]byte{7}
	phone, err := AskFor(askStream(1), bind)
	if err != nil {
		t.Fatal(err)
	}
	dev, _ := AskFor(askStream(1), bind)
	if phone.Tag != dev.Tag {
		t.Fatal("the tags differ")
	}
	mac := dev.MAC("rec", "12")
	if !phone.Check("rec", "12", mac[:]) {
		t.Fatal("the phone refused the device's ask")
	}
	for _, c := range []struct{ op, arg string }{
		{"rec", "13"}, {"rec", "1"}, {"re", "c12"}, {"hello", "12"}, {"tally", "12"},
	} {
		if phone.Check(c.op, c.arg, mac[:]) {
			t.Fatalf("a mac for rec 12 passed as %s %s", c.op, c.arg)
		}
	}
	if phone.Check("rec", "12", mac[:31]) {
		t.Fatal("a short mac passed")
	}
	other, _ := AskFor(askStream(1), [32]byte{8})
	if other.Tag == phone.Tag || other.Check("rec", "12", mac[:]) {
		t.Fatal("another link's ask holds")
	}
	stranger, _ := AskFor(askStream(2), bind)
	if stranger.Tag == phone.Tag || phone.Check("rec", "12", func() []byte { m := stranger.MAC("rec", "12"); return m[:] }()) {
		t.Fatal("another stream key's ask holds")
	}
	phone.Wipe()
	if phone.Check("rec", "12", mac[:]) {
		t.Fatal("a wiped ask still checks")
	}
	if _, err := AskFor(nil, bind); err == nil {
		t.Fatal("no stream key, an ask")
	}
}

func TestEachCopyAgainHasItsOwnKey(t *testing.T) {
	k, bind := askStream(3), [32]byte{9}
	k0, err := AgainKey(k, bind, 0)
	if err != nil || *k0 != *k {
		t.Fatal("generation 0 is not the link's key")
	}
	seen := map[[StreamKeySize]byte]bool{*k: true}
	for gen := uint32(1); gen < 20; gen++ {
		g, err := AgainKey(k, bind, gen)
		if err != nil {
			t.Fatal(err)
		}
		if seen[*g] {
			t.Fatalf("generation %d repeats a key", gen)
		}
		seen[*g] = true
		again, _ := AgainKey(k, bind, gen)
		if *again != *g {
			t.Fatal("one generation, two keys")
		}
	}
	g1, _ := AgainKey(k, [32]byte{10}, 1)
	if seen[*g1] {
		t.Fatal("another link's generation repeats a key")
	}
	// the ask stays the link's: the device asks before it knows the generation
	a, _ := AskFor(k, bind)
	b, _ := AskFor(k0, bind)
	if a.Tag != b.Tag {
		t.Fatal("generation 0 asks otherwise")
	}
	// two generations in one process: two senders, never ErrUsed, and a
	// record of one opens under no other generation's key
	var id [IDSize]byte
	r1, _ := RecordKey(mustAgain(t, k, bind, 1), bind, id)
	r2, _ := RecordKey(mustAgain(t, k, bind, 2), bind, id)
	if bytes.Equal(r1, r2) {
		t.Fatal("two generations share a records key")
	}
	if _, err := AgainKey(nil, bind, 1); err == nil {
		t.Fatal("no stream key, a key")
	}
}

func mustAgain(t *testing.T, k *[StreamKeySize]byte, bind [32]byte, gen uint32) *[StreamKeySize]byte {
	t.Helper()
	g, err := AgainKey(k, bind, gen)
	if err != nil {
		t.Fatal(err)
	}
	return g
}
