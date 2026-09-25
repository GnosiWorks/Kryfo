package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"testing"
)

var box = bytes.Repeat([]byte{7}, 16)

func mustSetup(t *testing.T, tb pinTable, pin string, index, kind int, old pinLegacy) pinTable {
	t.Helper()
	out, _, err := pinSetup([]byte(pin), tb, old, index, kind, box, nil)
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
	if _, _, _, err := a.decode(); err != nil {
		t.Fatal(err)
	}
	set := mustSetup(t, a, "1234", 0, 1, pinLegacy{})
	for i := range set.Entries {
		if len(set.Entries[i].T) != len(a.Entries[i].T) || len(set.Entries[i].M) != len(a.Entries[i].M) {
			t.Fatalf("entry %d changes size when set", i)
		}
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
		r, err := pinCheck([]byte(c.pin), tb, pinLegacy{}, nil)
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

// the same kdf, macs, opens and old checks whatever was typed
func TestPinCheckSameWork(t *testing.T) {
	tb := newPinTable(pinLogNLow)
	tb = mustSetup(t, tb, "1234", 0, 1, pinLegacy{})
	tb = mustSetup(t, tb, "5555", 2, 3, pinLegacy{})
	old := pinLegacy{WipeSalt: "c2FsdA==", WipeHash: string(legacyHash([]byte("7777"), "c2FsdA=="))}
	var first *struct{ kdf, mac, open, legacy int }
	for _, pin := range []string{"1234", "5555", "7777", "0000"} {
		pinCount = struct{ kdf, mac, open, legacy int }{}
		if _, err := pinCheck([]byte(pin), tb, old, nil); err != nil {
			t.Fatal(err)
		}
		c := pinCount
		if first == nil {
			first = &c
		} else if c != *first {
			t.Fatalf("%s did %+v, the first did %+v", pin, c, *first)
		}
	}
	if first.kdf != 1 || first.mac != pinEntries+2 || first.open != 2 || first.legacy != 2 {
		t.Fatalf("unexpected work %+v", *first)
	}
}

func TestPinSetupRefusesAPinAlreadyInUse(t *testing.T) {
	tb := newPinTable(pinLogNLow)
	tb = mustSetup(t, tb, "1234", 0, 1, pinLegacy{})
	if _, _, err := pinSetup([]byte("1234"), tb, pinLegacy{}, 2, 3, box, nil); !errors.Is(err, errPinCollision) {
		t.Fatalf("same pin in another entry: %v", err)
	}
	// changing an entry to its own pin again is fine
	if _, _, err := pinSetup([]byte("1234"), tb, pinLegacy{}, 0, 1, box, nil); err != nil {
		t.Fatal(err)
	}
	old := pinLegacy{AppSalt: "YQ==", AppHash: string(legacyHash([]byte("4321"), "YQ==")), WipeSalt: "Yg==", WipeHash: string(legacyHash([]byte("8765"), "Yg=="))}
	for _, pin := range []string{"4321", "8765"} {
		if _, _, err := pinSetup([]byte(pin), tb, old, 2, 3, box, nil); !errors.Is(err, errPinCollision) {
			t.Fatalf("%s equals an old pin: %v", pin, err)
		}
	}
}

// lock_state stored sha256("$salt:$pin") as hex
func TestPinLegacyMatchesTheOldHash(t *testing.T) {
	sum := sha256.Sum256([]byte("c2FsdHNhbHQ=:2468"))
	want := hex.EncodeToString(sum[:])
	old := pinLegacy{AppSalt: "c2FsdHNhbHQ=", AppHash: want}
	r, err := pinCheck([]byte("2468"), newPinTable(pinLogNLow), old, nil)
	if err != nil || !r.LegacyApp || r.LegacyWipe || r.Index != -1 {
		t.Fatalf("old app pin not recognised: %+v %v", r, err)
	}
	r, _ = pinCheck([]byte("2469"), newPinTable(pinLogNLow), old, nil)
	if r.LegacyApp {
		t.Fatal("a wrong pin matched the old hash")
	}
}

func TestPinClear(t *testing.T) {
	tb := mustSetup(t, newPinTable(pinLogNLow), "5555", 2, 3, pinLegacy{})
	tb, err := pinClear(tb, 2)
	if err != nil {
		t.Fatal(err)
	}
	if r, _ := pinCheck([]byte("5555"), tb, pinLegacy{}, nil); r.Index != -1 {
		t.Fatal("a cleared pin still opens")
	}
}

func TestPinWrapOpensOnlyForItsPin(t *testing.T) {
	tb := mustSetup(t, newPinTable(pinLogNLow), "1234", 0, 1, pinLegacy{})
	key := bytes.Repeat([]byte{9}, 32)
	tb, wrapped, err := pinSetup([]byte("246810"), tb, pinLegacy{}, 3, 4, box, key)
	if err != nil {
		t.Fatal(err)
	}
	r, _ := pinCheck([]byte("246810"), tb, pinLegacy{}, wrapped)
	if r.Index != 3 || r.Unwrapped != hex.EncodeToString(key) {
		t.Fatalf("vault pin: %+v", r)
	}
	r, _ = pinCheck([]byte("1234"), tb, pinLegacy{}, wrapped)
	if r.Unwrapped != "" {
		t.Fatal("the app pin opened the vault key")
	}
	// a new vault pin wraps the same key again; the database is untouched
	tb2, wrapped2, err := pinSetup([]byte("135791"), tb, pinLegacy{}, 3, 4, box, key)
	if err != nil {
		t.Fatal(err)
	}
	if r, _ := pinCheck([]byte("135791"), tb2, pinLegacy{}, wrapped2); r.Unwrapped != hex.EncodeToString(key) {
		t.Fatal("re-wrapped key did not open")
	}
	if r, _ := pinCheck([]byte("246810"), tb2, pinLegacy{}, wrapped2); r.Index != -1 || r.Unwrapped != "" {
		t.Fatal("the old vault pin still opens")
	}
}

func TestPinBadTablesAreRefused(t *testing.T) {
	good := newPinTable(pinLogNLow)
	short := good
	short.Entries = good.Entries[:7]
	badHex := newPinTable(pinLogNLow)
	badHex.Entries[3].T = "zz"
	cheap := newPinTable(pinLogNLow)
	cheap.LogN = 10
	for name, tb := range map[string]pinTable{"short": short, "bad hex": badHex, "cheap": cheap} {
		if _, err := pinCheck([]byte("1234"), tb, pinLegacy{}, nil); err == nil {
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
