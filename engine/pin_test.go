package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"testing"
)

var box = bytes.Repeat([]byte{7}, 16)

func mustSetup(t *testing.T, tb pinTable, pin string, index, kind int, old pinLegacy) pinTable {
	t.Helper()
	out, err := pinSetup([]byte(pin), tb, old, index, kind, box, nil)
	if err != nil {
		t.Fatalf("setup %s at %d: %v", pin, index, err)
	}
	return out
}

func TestPinTableShape(t *testing.T) {
	a, b := newPinTable(pinLogNLow), newPinTable(pinLogNLow)
	if a.Salt == b.Salt || a.Entries[0].T == b.Entries[0].T {
		t.Fatal("two tables share random bytes")
	}
	if _, err := a.decode(); err != nil {
		t.Fatal(err)
	}
	if a.V != 2 || len(a.Entries) != 16 {
		t.Fatalf("a new table is v%d with %d entries", a.V, len(a.Entries))
	}
	set := mustSetup(t, a, "1234", 0, 1, pinLegacy{})
	set, err := pinSetup([]byte("246810"), set, pinLegacy{}, 3, 4, box, bytes.Repeat([]byte{9}, 32))
	if err != nil {
		t.Fatal(err)
	}
	for i := range set.Entries {
		e, f := set.Entries[i], a.Entries[i]
		if len(e.T) != len(f.T) || len(e.M) != len(f.M) || len(e.W) != len(f.W) || len(e.W) != 2*pinWrapLen {
			t.Fatalf("entry %d changes size when set", i)
		}
	}
	if _, err := pinSetup([]byte("135790"), set, pinLegacy{}, 6, 4, box, make([]byte, 31)); err == nil {
		t.Fatal("a key of the wrong size was wrapped")
	}
}

func TestPinCheckFindsEachEntry(t *testing.T) {
	tb := newPinTable(pinLogNLow)
	tb = mustSetup(t, tb, "1234", 0, 1, pinLegacy{})
	tb = mustSetup(t, tb, "9999", 1, 2, pinLegacy{})
	tb = mustSetup(t, tb, "5555", 2, 3, pinLegacy{})
	for _, c := range []struct {
		pin         string
		index, kind int
	}{{"1234", 0, 1}, {"9999", 1, 2}, {"5555", 2, 3}, {"0000", -1, 0}, {"12345", -1, 0}} {
		r, err := pinCheck([]byte(c.pin), tb, pinLegacy{})
		if err != nil {
			t.Fatal(err)
		}
		if r.Index != c.index || r.Kind != c.kind {
			t.Fatalf("%s: got %d/%d, want %d/%d", c.pin, r.Index, r.Kind, c.index, c.kind)
		}
		if c.index >= 0 && r.Container != hex.EncodeToString(box) {
			t.Fatalf("%s: container %s", c.pin, r.Container)
		}
	}
}

// the same kdf, macs, opens and old checks whatever was typed: app, wipe,
// decoy, both vaults, the decoy's own, a legacy wipe and a wrong pin, on the
// table and on the v1 table it came from
func TestPinCheckSameWork(t *testing.T) {
	tb := vaultTable(t)
	v1 := tb.copy()
	v1.V, v1.Entries = 1, v1.Entries[:8]
	for i := range v1.Entries {
		v1.Entries[i].W = ""
	}
	old := pinLegacy{WipeSalt: "c2FsdA==", WipeHash: string(legacyHash([]byte("7777"), "c2FsdA=="))}
	var first *struct{ kdf, mac, open, legacy int }
	for _, table := range []pinTable{tb, v1} {
		for _, pin := range []string{"1234", "9999", "5555", "246810", "135790", "4444", "3333", "7777", "0000"} {
			pinCount = struct{ kdf, mac, open, legacy int }{}
			if _, err := pinCheck([]byte(pin), table, old); err != nil {
				t.Fatal(err)
			}
			c := pinCount
			if first == nil {
				first = &c
			} else if c != *first {
				t.Fatalf("v%d %s did %+v, the first did %+v", table.V, pin, c, *first)
			}
		}
	}
	if first.kdf != 1 || first.mac != pinEntries+2 || first.open != 2 || first.legacy != 2 {
		t.Fatalf("unexpected work %+v", *first)
	}
}

func TestPinSetupRefusesUsedPin(t *testing.T) {
	tb := newPinTable(pinLogNLow)
	tb = mustSetup(t, tb, "1234", 0, 1, pinLegacy{})
	if _, err := pinSetup([]byte("1234"), tb, pinLegacy{}, 2, 3, box, nil); !errors.Is(err, errPinCollision) {
		t.Fatalf("same pin in another entry: %v", err)
	}
	// changing an entry to its own pin again is fine
	if _, err := pinSetup([]byte("1234"), tb, pinLegacy{}, 0, 1, box, nil); err != nil {
		t.Fatal(err)
	}
	old := pinLegacy{AppSalt: "YQ==", AppHash: string(legacyHash([]byte("4321"), "YQ==")), WipeSalt: "Yg==", WipeHash: string(legacyHash([]byte("8765"), "Yg=="))}
	for _, pin := range []string{"4321", "8765"} {
		if _, err := pinSetup([]byte(pin), tb, old, 2, 3, box, nil); !errors.Is(err, errPinCollision) {
			t.Fatalf("%s equals an old pin: %v", pin, err)
		}
	}
}

// lock_state stored sha256("$salt:$pin") as hex
func TestPinLegacyMatchesOldHash(t *testing.T) {
	sum := sha256.Sum256([]byte("c2FsdHNhbHQ=:2468"))
	want := hex.EncodeToString(sum[:])
	old := pinLegacy{AppSalt: "c2FsdHNhbHQ=", AppHash: want}
	r, err := pinCheck([]byte("2468"), newPinTable(pinLogNLow), old)
	if err != nil || !r.LegacyApp || r.LegacyWipe || r.Index != -1 {
		t.Fatalf("old app pin not recognised: %+v %v", r, err)
	}
	r, _ = pinCheck([]byte("2469"), newPinTable(pinLogNLow), old)
	if r.LegacyApp {
		t.Fatal("a wrong pin matched the old hash")
	}
}

func TestPinClear(t *testing.T) {
	tb := vaultTable(t)
	before := tb.Entries[3].W
	tb, err := pinClear(tb, 3)
	if err != nil {
		t.Fatal(err)
	}
	if r, _ := pinCheck([]byte("246810"), tb, pinLegacy{}); r.Index != -1 || r.Unwrapped != "" {
		t.Fatal("a cleared pin still opens")
	}
	if tb.Entries[3].W == before || len(tb.Entries[3].W) != len(before) {
		t.Fatal("the wrap was not replaced with random bytes of its size")
	}
	if r, _ := pinCheck([]byte("135790"), tb, pinLegacy{}); r.Unwrapped != hex.EncodeToString(vaultKeyB) {
		t.Fatal("clearing one vault touched the other")
	}
}

var (
	vaultKeyA = bytes.Repeat([]byte{9}, 32)
	vaultKeyB = bytes.Repeat([]byte{8}, 32)
)

// app 1234, wipe 9999, decoy 5555, vault 246810 wrapping key a, the decoy's
// wipe 4444 and decoy 3333, the decoy's vault 135790 wrapping key b
func vaultTable(t *testing.T) pinTable {
	t.Helper()
	tb := newPinTable(pinLogNLow)
	for _, s := range []struct {
		pin         string
		index, kind int
		key         []byte
	}{
		{"1234", 0, 1, nil}, {"9999", 1, 2, nil}, {"5555", 2, 3, nil}, {"246810", 3, 4, vaultKeyA},
		{"4444", 4, 2, nil}, {"3333", 5, 3, nil}, {"135790", 6, 4, vaultKeyB},
	} {
		var err error
		if tb, err = pinSetup([]byte(s.pin), tb, pinLegacy{}, s.index, s.kind, box, s.key); err != nil {
			t.Fatalf("setup %s: %v", s.pin, err)
		}
	}
	return tb
}

func TestPinVaultsOpenOnlyTheirOwnKey(t *testing.T) {
	tb := vaultTable(t)
	for _, c := range []struct {
		pin   string
		index int
		key   []byte
	}{
		{"246810", 3, vaultKeyA}, {"135790", 6, vaultKeyB},
		{"1234", 0, nil}, {"9999", 1, nil}, {"5555", 2, nil}, {"4444", 4, nil}, {"3333", 5, nil},
		{"000000", -1, nil}, {"24681", -1, nil}, {"2468100", -1, nil},
	} {
		r, err := pinCheck([]byte(c.pin), tb, pinLegacy{})
		if err != nil {
			t.Fatal(err)
		}
		if r.Index != c.index || r.Unwrapped != hex.EncodeToString(c.key) {
			t.Fatalf("%s: entry %d key %q", c.pin, r.Index, r.Unwrapped)
		}
	}
	// setting up again wraps a new key; the old one no longer comes out
	tb2, err := pinSetup([]byte("246810"), tb, pinLegacy{}, 3, 4, box, vaultKeyB)
	if err != nil {
		t.Fatal(err)
	}
	if r, _ := pinCheck([]byte("246810"), tb2, pinLegacy{}); r.Unwrapped != hex.EncodeToString(vaultKeyB) {
		t.Fatal("a new setup did not replace the wrapped key")
	}
}

func TestPinRewrapKeepsTheKey(t *testing.T) {
	tb := vaultTable(t)
	out, err := pinRewrap([]byte("246810"), []byte("112233"), tb, pinLegacy{}, 3)
	if err != nil {
		t.Fatal(err)
	}
	r, _ := pinCheck([]byte("112233"), out, pinLegacy{})
	if r.Index != 3 || r.Kind != 4 || r.Container != hex.EncodeToString(box) || r.Unwrapped != hex.EncodeToString(vaultKeyA) {
		t.Fatalf("the new pin: %+v", r)
	}
	if r, _ := pinCheck([]byte("246810"), out, pinLegacy{}); r.Index != -1 || r.Unwrapped != "" {
		t.Fatal("the old pin still opens")
	}
	for i := range tb.Entries {
		if i != 3 && tb.Entries[i] != out.Entries[i] {
			t.Fatalf("entry %d changed", i)
		}
	}
	// the decoy's vault, and the same pin again (fresh nonces, same key)
	out, err = pinRewrap([]byte("135790"), []byte("135790"), out, pinLegacy{}, 6)
	if err != nil {
		t.Fatal(err)
	}
	if r, _ := pinCheck([]byte("135790"), out, pinLegacy{}); r.Index != 6 || r.Unwrapped != hex.EncodeToString(vaultKeyB) {
		t.Fatalf("the decoy's vault after a rewrap: %+v", r)
	}
}

func TestPinRewrapRefusedLeavesTheTable(t *testing.T) {
	tb := vaultTable(t)
	keep, _ := json.Marshal(tb)
	old := pinLegacy{AppSalt: "YQ==", AppHash: string(legacyHash([]byte("8642"), "YQ=="))}
	for _, c := range []struct {
		oldPin, newPin string
		index          int
		want           error
	}{
		{"000000", "112233", 3, errPinWrong},
		{"135790", "112233", 3, errPinWrong}, // the other vault's pin
		{"1234", "112233", 3, errPinWrong},
		{"246810", "1234", 3, errPinCollision},
		{"246810", "135790", 3, errPinCollision},
		{"246810", "9999", 3, errPinCollision},
		{"246810", "8642", 3, errPinCollision}, // the legacy app pin
		{"1234", "4321", 0, nil},               // nothing wrapped there
	} {
		out, err := pinRewrap([]byte(c.oldPin), []byte(c.newPin), tb, old, c.index)
		if err == nil || (c.want != nil && !errors.Is(err, c.want)) {
			t.Fatalf("%s to %s at %d: %v", c.oldPin, c.newPin, c.index, err)
		}
		got, _ := json.Marshal(out)
		now, _ := json.Marshal(tb)
		if !bytes.Equal(got, keep) || !bytes.Equal(now, keep) {
			t.Fatalf("%s to %s: the table changed", c.oldPin, c.newPin)
		}
	}
	if r, _ := pinCheck([]byte("246810"), tb, old); r.Unwrapped != hex.EncodeToString(vaultKeyA) {
		t.Fatal("the vault no longer opens after refused changes")
	}
}

// made by the step-1 code (v1): app 1234 at 0, wipe 9999 at 1, decoy 5555 at
// 2, the decoy's wipe 4444 at 4 and decoy 3333 at 5, container 0707..07
const pinV1Table = `{"v":1,"n":14,"s":"c792ae3f5ee3324c5f657a7865304d7847a0a85d44568694b6fbdd21a1d664d1","e":[{"t":"db772c89c7a08c4f393cdb46eeb853f0134def9c9050b06afb4eee41690eb7ad","m":"21472c2026ae6ebac0316a6d4a9b98e662ca814dde6e99ecd50df06fd2dba33670b5a271c6e45298e9e1a0ab75"},{"t":"5e24ae5dc258c71268db5f48e480fdb03d5182de0e71b5eae9c772dc3181e8c5","m":"381369eda48b46013279ffa01bdcd56b56942aae0f97e4cc22bc1d9c814db87f109aa331dbff70656da7340b10"},{"t":"df8512ea9370982c4ebcefa3ba4b41b86a7d501b3bf4bfa0939d2c49c0ca448b","m":"e94e4c3a985daee74805433b5c9f3f89c20ed659b4c5264eefb9ff89e8ce196345276d6f9ee370759c2684ee24"},{"t":"7a87a94165aa4a85c2d901d7315ec97b03e83a1c01f0d6c5aef2d3e5e5124616","m":"eaec005f341e8328417d14c46e2bc9b154265b4ea500c24925efbe31b6356c4e0874f0d6d1814a56073f79a626"},{"t":"58117466769fc4fedf74d17a192da0237b35bf6486e02c20c00153d686151383","m":"667028270e3bf8dbff4c6e840d718ee6b7b050ae037b6d698c17bc9dbc7df51663822c638157c473286dd6d3e5"},{"t":"7f181bab6cfa00c6cddede0b59c476b1bc603324d4f63bd19cc74554816ad12e","m":"6233590beebfef4f62924311bbbae10d026957e70c555ea7d96e472cae090f74ae366b9f03bef358e6dac94351"},{"t":"29e365227745443b97b3031ff474124b7201391c2370d78c8fc6c13565177c4c","m":"eb5daa4d3d37710328c4289c3ddd18750cbffd292c1f5299943afdd504844321a6c7d790a0bfcb82f6a86b6b7a"},{"t":"b5b0de9efea3dc3c22ed5b3ba70b0bef37d48c79f42133587f5de0bd1ab201de","m":"f7b6ca28af580b163444ab7062962b8eadd23f1ae0b4730c2da79db7a128a7dd659dd86ea2db5004caa346bed9"}]}`

func TestPinV1TableUpgrades(t *testing.T) {
	var v1 pinTable
	if err := json.Unmarshal([]byte(pinV1Table), &v1); err != nil {
		t.Fatal(err)
	}
	up, err := v1.upgrade()
	if err != nil {
		t.Fatal(err)
	}
	if up.V != 2 || len(up.Entries) != pinEntries || up.Salt != v1.Salt || up.LogN != v1.LogN {
		t.Fatalf("upgraded to v%d with %d entries", up.V, len(up.Entries))
	}
	if _, err := up.decode(); err != nil {
		t.Fatal(err)
	}
	for i, e := range v1.Entries {
		if up.Entries[i].T != e.T || up.Entries[i].M != e.M || len(up.Entries[i].W) != 2*pinWrapLen {
			t.Fatalf("entry %d changed in the upgrade", i)
		}
	}
	// a v2 table comes back as it was
	again, err := up.upgrade()
	if err != nil {
		t.Fatal(err)
	}
	a, _ := json.Marshal(up)
	b, _ := json.Marshal(again)
	if !bytes.Equal(a, b) {
		t.Fatal("upgrading a v2 table changed it")
	}

	old := pinLegacy{
		AppSalt: "YQ==", AppHash: string(legacyHash([]byte("8642"), "YQ==")),
		WipeSalt: "Yg==", WipeHash: string(legacyHash([]byte("7531"), "Yg==")),
	}
	for _, c := range []struct {
		pin                   string
		index, kind           int
		legacyApp, legacyWipe bool
	}{
		{"1234", 0, 1, false, false}, {"9999", 1, 2, false, false}, {"5555", 2, 3, false, false},
		{"4444", 4, 2, false, false}, {"3333", 5, 3, false, false},
		{"8642", -1, 0, true, false}, {"7531", -1, 0, false, true}, {"0000", -1, 0, false, false},
	} {
		for _, table := range []pinTable{v1, up} {
			r, err := pinCheck([]byte(c.pin), table, old)
			if err != nil {
				t.Fatal(err)
			}
			if r.Index != c.index || r.Kind != c.kind || r.LegacyApp != c.legacyApp || r.LegacyWipe != c.legacyWipe || r.Unwrapped != "" {
				t.Fatalf("v%d %s: %+v", table.V, c.pin, r)
			}
			if c.index >= 0 && r.Container != hex.EncodeToString(box) {
				t.Fatalf("v%d %s: container %s", table.V, c.pin, r.Container)
			}
		}
	}

	// a setup on the v1 table writes v2, and the vault opens there
	set, err := pinSetup([]byte("246810"), v1, old, 3, 4, box, vaultKeyA)
	if err != nil {
		t.Fatal(err)
	}
	if set.V != 2 || len(set.Entries) != pinEntries {
		t.Fatal("setup on a v1 table did not write v2")
	}
	for i, e := range v1.Entries {
		if i != 3 && (set.Entries[i].T != e.T || set.Entries[i].M != e.M) {
			t.Fatalf("setup on a v1 table changed entry %d", i)
		}
	}
	if r, _ := pinCheck([]byte("246810"), set, old); r.Index != 3 || r.Unwrapped != hex.EncodeToString(vaultKeyA) {
		t.Fatalf("the vault on an upgraded table: %+v", r)
	}
	if r, _ := pinCheck([]byte("1234"), set, old); r.Index != 0 {
		t.Fatal("the app pin stopped opening after a setup on a v1 table")
	}
}

func TestPinRefusesBadTables(t *testing.T) {
	good := newPinTable(pinLogNLow)
	short := good
	short.Entries = good.Entries[:7]
	badHex := newPinTable(pinLogNLow)
	badHex.Entries[3].T = "zz"
	cheap := newPinTable(pinLogNLow)
	cheap.LogN = 10
	noWrap := newPinTable(pinLogNLow)
	noWrap.Entries[5].W = ""
	v1WithWrap := newPinTable(pinLogNLow)
	v1WithWrap.V, v1WithWrap.Entries = 1, v1WithWrap.Entries[:8]
	v1Long := newPinTable(pinLogNLow)
	v1Long.V = 1
	v3 := newPinTable(pinLogNLow)
	v3.V = 3
	for name, tb := range map[string]pinTable{
		"short": short, "bad hex": badHex, "cheap": cheap, "no wrap": noWrap,
		"v1 with wraps": v1WithWrap, "v1 with 16": v1Long, "v3": v3,
	} {
		if _, err := pinCheck([]byte("1234"), tb, pinLegacy{}); err == nil {
			t.Fatalf("%s table accepted", name)
		}
	}
}

func TestPinCalibrateStaysInRange(t *testing.T) {
	n, ms := pinCalibrate(1 << 30)
	if n < pinLogNLow || n > pinLogNHigh || ms <= 0 {
		t.Fatalf("calibrated to %d (%d ms)", n, ms)
	}
	if n, _ := pinCalibrate(64 << 20); n != pinLogNLow {
		t.Fatal("short memory did not keep the low cost")
	}
}
