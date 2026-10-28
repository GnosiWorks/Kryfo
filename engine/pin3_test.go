package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"
	"unicode"
)

// a keystore key in plain go: hmac under a secret, counted
type standIn struct {
	secret []byte
	calls  int
	// answers this instead, when set
	fixed []byte
}

func newStandIn() *standIn { return &standIn{secret: randBytes(32)} }

func (k *standIn) mac(x []byte) []byte {
	k.calls++
	if k.fixed != nil {
		return append([]byte(nil), k.fixed...)
	}
	m := hmac.New(sha256.New, k.secret)
	m.Write(x)
	return m.Sum(nil)
}

var testKey = &pinKeyInfo{G: 1, U: 1, L: 2, KC: hex.EncodeToString(bytes.Repeat([]byte{5}, 32))}

func check3(t *testing.T, pin string, tb pinTable, ks *standIn) pinResult {
	t.Helper()
	var f pinMacFn
	if ks != nil {
		f = ks.mac
	}
	r, err := pinCheckKS([]byte(pin), tb, pinLegacy{}, f, testKey)
	if err != nil {
		t.Fatalf("%s: %v", pin, err)
	}
	return r
}

var vaultPins = []struct {
	pin         string
	index, kind int
	key         []byte
}{
	{"1234", 0, 1, nil}, {"9999", 1, 2, nil}, {"5555", 2, 3, nil}, {"246810", 3, 4, vaultKeyA},
	{"4444", 4, 2, nil}, {"3333", 5, 3, nil}, {"135790", 6, 4, vaultKeyB},
}

// each pin moves its own entry the first time it is typed with the
// keystore there, and only that one. the header goes to v3 with the first
func TestPinV3MovesEachEntry(t *testing.T) {
	tb := vaultTable(t)
	ks := newStandIn()
	for n, c := range vaultPins {
		r := check3(t, c.pin, tb, ks)
		if r.Index != c.index || r.G != 2 || r.Mv != "e" || r.R == nil {
			t.Fatalf("%s before its move: %+v", c.pin, r)
		}
		if r.R.V != pinVersion3 || r.R.K == nil || r.R.K.KC != testKey.KC {
			t.Fatalf("%s: the moved table is v%d", c.pin, r.R.V)
		}
		for i := range tb.Entries {
			if (i == c.index) == (r.R.Entries[i] == tb.Entries[i]) {
				t.Fatalf("%s moved entry %d", c.pin, i)
			}
		}
		tb = *r.R
		r = check3(t, c.pin, tb, ks)
		if r.Index != c.index || r.Kind != c.kind || r.G != 3 || r.Mv != "" || r.R != nil {
			t.Fatalf("%s after its move: %+v", c.pin, r)
		}
		if r.Unwrapped != hex.EncodeToString(c.key) {
			t.Fatalf("%s: the vault key changed in the move", c.pin)
		}
		// the ones not moved yet still open under the old key
		for _, o := range vaultPins[n+1:] {
			if r := check3(t, o.pin, tb, ks); r.Index != o.index || r.G != 2 {
				t.Fatalf("%s stopped opening after %s moved: %+v", o.pin, c.pin, r)
			}
		}
	}
	if r := check3(t, "000000", tb, ks); r.Index != -1 || r.R != nil || r.Mv != "" {
		t.Fatalf("a wrong pin: %+v", r)
	}
}

// a moved entry opens only with this phone's key: not without one, not
// with another phone's
func TestPinV3NeedsThisKeystore(t *testing.T) {
	tb := vaultTable(t)
	ks := newStandIn()
	tb = *check3(t, "246810", tb, ks).R
	if r := check3(t, "246810", tb, nil); r.Index != -1 || r.Unwrapped != "" {
		t.Fatalf("a moved vault opened without the keystore: %+v", r)
	}
	if r := check3(t, "246810", tb, newStandIn()); r.Index != -1 || r.Unwrapped != "" {
		t.Fatalf("a moved vault opened with another key: %+v", r)
	}
	// without the keystore the old entries open and nothing moves
	r := check3(t, "1234", tb, nil)
	if r.Index != 0 || r.G != 2 || r.R != nil {
		t.Fatalf("the app pin with no keystore: %+v", r)
	}
	// and nothing can be written under the old key once the table is v3
	if _, err := pinSetupKS([]byte("8080"), tb, pinLegacy{}, nil, nil, 7, 1, box, nil); !errors.Is(err, errPinKeystore) {
		t.Fatalf("a v3 table took an entry under the old key: %v", err)
	}
}

// the same kdf, macs, opens, seals and one keystore call whatever was typed,
// on a table half moved: moved, unmoved, legacy and wrong pins
func TestPinV3SameWork(t *testing.T) {
	tb := vaultTable(t)
	ks := newStandIn()
	for _, pin := range []string{"1234", "246810", "4444"} {
		tb = *check3(t, pin, tb, ks).R
	}
	old := pinLegacy{
		WipeSalt: "c2FsdA==", WipeHash: string(legacyHash([]byte("7777"), "c2FsdA==")),
		WipeTo: &pinMove{I: 1, K: 2, C: hex.EncodeToString(box)},
	}
	type work struct{ kdf, mac, open, legacy, seal, ks int }
	var first *work
	for _, pin := range []string{"1234", "9999", "5555", "246810", "135790", "4444", "3333", "7777", "0000", "abcdefghijkl"} {
		pinCount = struct{ kdf, mac, open, legacy, seal int }{}
		ks.calls = 0
		if _, err := pinCheckKS([]byte(pin), tb, old, ks.mac, testKey); err != nil {
			t.Fatal(err)
		}
		c := work{pinCount.kdf, pinCount.mac, pinCount.open, pinCount.legacy, pinCount.seal, ks.calls}
		if first == nil {
			first = &c
		} else if c != *first {
			t.Fatalf("%s did %+v, the first did %+v", pin, c, *first)
		}
	}
	if first.kdf != 1 || first.ks != 1 {
		t.Fatalf("unexpected work %+v", *first)
	}
}

// a keystore that answers the same whatever it is asked leaves every pin
// its own key: the pins do not collapse into one
func TestPinV3ConstantKeystore(t *testing.T) {
	ks := &standIn{fixed: bytes.Repeat([]byte{0x42}, 32)}
	tb := newPinTable(pinLogNLow)
	var err error
	for _, c := range vaultPins {
		tb, err = pinSetupKS([]byte(c.pin), tb, pinLegacy{}, ks.mac, testKey, c.index, c.kind, box, c.key)
		if err != nil {
			t.Fatalf("setup %s: %v", c.pin, err)
		}
	}
	for _, c := range vaultPins {
		if r := check3(t, c.pin, tb, ks); r.Index != c.index || r.G != 3 {
			t.Fatalf("%s: %+v", c.pin, r)
		}
	}
	if r := check3(t, "0000", tb, ks); r.Index != -1 {
		t.Fatal("a wrong pin opened under a constant keystore")
	}
}

// answers that cannot be the keystore's are a keystore failure, never a
// wrong pin, and change nothing
func TestPinV3BadAnswers(t *testing.T) {
	tb := vaultTable(t)
	for name, f := range map[string]pinMacFn{
		"zeros": func(x []byte) []byte { return make([]byte, 32) },
		"x":     func(x []byte) []byte { return append([]byte(nil), x...) },
		"short": func(x []byte) []byte { return x[:16] },
		"long":  func(x []byte) []byte { return append(append([]byte(nil), x...), 1) },
	} {
		if _, err := pinCheckKS([]byte("1234"), tb, pinLegacy{}, f, testKey); !errors.Is(err, errPinKeystore) {
			t.Fatalf("%s: %v", name, err)
		}
		if _, err := pinSetupKS([]byte("8080"), tb, pinLegacy{}, f, testKey, 7, 1, box, nil); !errors.Is(err, errPinKeystore) {
			t.Fatalf("%s setup: %v", name, err)
		}
	}
}

// a new pin clashes with an entry under either key: an untouched v2 entry
// under the old one, a moved one under the new one
func TestPinV3CollisionsAcrossKeys(t *testing.T) {
	tb := vaultTable(t)
	ks := newStandIn()
	tb = *check3(t, "246810", tb, ks).R // the vault moved, the rest not
	for _, pin := range []string{"1234", "9999", "246810", "135790"} {
		if _, err := pinSetupKS([]byte(pin), tb, pinLegacy{}, ks.mac, testKey, 7, 1, box, nil); !errors.Is(err, errPinCollision) {
			t.Fatalf("%s at a free entry: %v", pin, err)
		}
	}
	// the same pin at its own entry is no clash, and lands under the new key
	out, err := pinSetupKS([]byte("1234"), tb, pinLegacy{}, ks.mac, testKey, 0, 1, box, nil)
	if err != nil {
		t.Fatal(err)
	}
	if r := check3(t, "1234", out, ks); r.Index != 0 || r.G != 3 {
		t.Fatalf("a set pin is not under the new key: %+v", r)
	}
	// a rewrap's new pin is checked under both keys too
	for _, pin := range []string{"1234", "9999", "135790"} {
		if _, err := pinRewrapKS([]byte("246810"), []byte(pin), tb, pinLegacy{}, ks.mac, testKey, 3); !errors.Is(err, errPinCollision) {
			t.Fatalf("rewrap to %s: %v", pin, err)
		}
	}
	// a legacy pin clashes as before
	old := pinLegacy{AppSalt: "YQ==", AppHash: string(legacyHash([]byte("8642"), "YQ=="))}
	if _, err := pinSetupKS([]byte("8642"), tb, old, ks.mac, testKey, 7, 1, box, nil); !errors.Is(err, errPinCollision) {
		t.Fatalf("a legacy pin: %v", err)
	}
}

// the old pin of a rewrap may open its entry under either key; the new one
// is always written under the new key, and the vault key stays
func TestPinV3RewrapEitherKey(t *testing.T) {
	ks := newStandIn()
	for _, moved := range []bool{false, true} {
		tb := vaultTable(t)
		tb = *check3(t, "1234", tb, ks).R // the header is v3 either way
		if moved {
			tb = *check3(t, "246810", tb, ks).R
		}
		out, err := pinRewrapKS([]byte("246810"), []byte("112233"), tb, pinLegacy{}, ks.mac, testKey, 3)
		if err != nil {
			t.Fatalf("moved %v: %v", moved, err)
		}
		r := check3(t, "112233", out, ks)
		if r.Index != 3 || r.G != 3 || r.Unwrapped != hex.EncodeToString(vaultKeyA) {
			t.Fatalf("moved %v, the new pin: %+v", moved, r)
		}
		if r := check3(t, "246810", out, ks); r.Index != -1 {
			t.Fatalf("moved %v: the old pin still opens", moved)
		}
		if _, err := pinRewrapKS([]byte("000000"), []byte("112244"), tb, pinLegacy{}, ks.mac, testKey, 3); !errors.Is(err, errPinWrong) {
			t.Fatalf("a wrong old pin: %v", err)
		}
	}
}

// a match under the new key wins over one under the old key
func TestPinV3NewKeyWins(t *testing.T) {
	ks := newStandIn()
	tb := vaultTable(t)
	tb = *check3(t, "1234", tb, ks).R
	// the same pin set again at another entry under the old key, past the
	// clash check, as only a bug could
	ko, _ := pinKey([]byte("1234"), mustSalt(t, tb), tb.LogN)
	tb.Entries[9] = pinSealEntry(ko, 9, append([]byte{3}, box...), nil)
	if r := check3(t, "1234", tb, ks); r.Index != 0 || r.G != 3 || r.Kind != 1 {
		t.Fatalf("the old key's match won: %+v", r)
	}
	// without the keystore only the old one is there
	if r := check3(t, "1234", tb, nil); r.Index != 9 || r.G != 2 {
		t.Fatalf("with no keystore: %+v", r)
	}
}

func mustSalt(t *testing.T, tb pinTable) []byte {
	t.Helper()
	s, err := hex.DecodeString(tb.Salt)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

// the header moves only with key info, and only once: later moves keep it
func TestPinV3Header(t *testing.T) {
	ks := newStandIn()
	tb := vaultTable(t)
	r, err := pinCheckKS([]byte("1234"), tb, pinLegacy{}, ks.mac, nil)
	if err != nil || r.Index != 0 || r.R != nil {
		t.Fatalf("a move with no key info: %+v %v", r, err)
	}
	if _, err := pinSetupKS([]byte("8080"), tb, pinLegacy{}, ks.mac, nil, 7, 1, box, nil); err == nil {
		t.Fatal("a v2 table went to v3 with no key info")
	}
	tb = *check3(t, "1234", tb, ks).R
	other := &pinKeyInfo{G: 2, U: 0, L: 1, KC: hex.EncodeToString(bytes.Repeat([]byte{6}, 32))}
	r, err = pinCheckKS([]byte("9999"), tb, pinLegacy{}, ks.mac, other)
	if err != nil || r.R == nil || *r.R.K != *testKey {
		t.Fatalf("a later move changed the header: %+v %v", r.R, err)
	}
	cl, err := pinClear(*r.R, 3)
	if err != nil || cl.V != pinVersion3 || *cl.K != *testKey {
		t.Fatal("a clear dropped the header")
	}
	up, err := cl.upgrade()
	if err != nil || up.V != pinVersion3 || *up.K != *testKey {
		t.Fatal("an upgrade changed a v3 table")
	}
	b, _ := json.Marshal(cl)
	var back pinTable
	if json.Unmarshal(b, &back) != nil || back.K == nil || *back.K != *testKey {
		t.Fatal("the header did not survive json")
	}
	for name, k := range map[string]*pinKeyInfo{
		"no kc": {G: 1, U: 1, L: 2}, "gen 0": {G: 0, KC: testKey.KC}, "u 2": {G: 1, U: 2, KC: testKey.KC},
		"l 3": {G: 1, L: 3, KC: testKey.KC},
	} {
		bad := cl.copy()
		bad.K = k
		if _, err := bad.decode(); err == nil {
			t.Fatalf("%s: a bad header read", name)
		}
	}
	v2k := cl.copy()
	v2k.V = 2
	if _, err := v2k.decode(); err == nil {
		t.Fatal("a v2 table with a header read")
	}
}

// the legacy sha256 pins move into their entries under the new key
func TestPinV3LegacyMoves(t *testing.T) {
	ks := newStandIn()
	tb := vaultTable(t)
	tb, _ = pinClear(tb, 1)
	tb, _ = pinClear(tb, 0)
	old := pinLegacy{
		AppSalt: "YQ==", AppHash: string(legacyHash([]byte("8642"), "YQ==")),
		WipeSalt: "Yg==", WipeHash: string(legacyHash([]byte("7531"), "Yg==")),
		AppTo:  &pinMove{I: 0, K: 1, C: hex.EncodeToString(box)},
		WipeTo: &pinMove{I: 1, K: 2, C: hex.EncodeToString(box)},
	}
	for _, c := range []struct {
		pin         string
		mv          string
		index, kind int
	}{{"7531", "w", 1, 2}, {"8642", "a", 0, 1}} {
		r, err := pinCheckKS([]byte(c.pin), tb, old, ks.mac, testKey)
		if err != nil || r.Mv != c.mv || r.R == nil || r.Index != -1 {
			t.Fatalf("%s: %+v %v", c.pin, r, err)
		}
		got := check3(t, c.pin, *r.R, ks)
		if got.Index != c.index || got.Kind != c.kind || got.G != 3 {
			t.Fatalf("%s after its move: %+v", c.pin, got)
		}
		// without the keystore a legacy pin does not move
		if r, _ := pinCheckKS([]byte(c.pin), tb, old, nil, testKey); r.R != nil {
			t.Fatalf("%s moved with no keystore", c.pin)
		}
	}
	// with no entry named, nothing moves
	if r, _ := pinCheckKS([]byte("7531"), tb, pinLegacy{WipeSalt: old.WipeSalt, WipeHash: old.WipeHash}, ks.mac, testKey); r.R != nil || !r.LegacyWipe {
		t.Fatalf("a legacy wipe pin with nowhere to go: %+v", r)
	}
}

// s waits for the keystore under a handle that works once, for its own
// table, and not past its life
func TestPinHandles(t *testing.T) {
	tb := vaultTable(t)
	h, x, err := pinBegin([]byte("1234"), tb, pinLegacy{})
	if err != nil || len(x) != 32 || len(h) != 32 {
		t.Fatalf("begin: %q %d %v", h, len(x), err)
	}
	p, err := pinTakeFor(h, tb)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := pinTakeFor(h, tb); err == nil {
		t.Fatal("a handle worked twice")
	}
	if bytes.Contains(x, p.s) || hmac.Equal(x, p.s) {
		t.Fatal("x is s")
	}
	h, _, _ = pinBegin([]byte("1234"), tb, pinLegacy{})
	if _, err := pinTakeFor(h, newPinTable(pinLogNLow)); err == nil {
		t.Fatal("a handle worked for another table")
	}
	was := pinHoldLife
	pinHoldLife = 20 * time.Millisecond
	defer func() { pinHoldLife = was }()
	h, _, _ = pinBegin([]byte("1234"), tb, pinLegacy{})
	pinHolds.Lock()
	held := pinHolds.m[h]
	pinHolds.Unlock()
	time.Sleep(150 * time.Millisecond)
	if _, err := pinTakeFor(h, tb); err == nil {
		t.Fatal("a handle outlived its life")
	}
	if !allZero(held.s) {
		t.Fatal("an expired handle kept s")
	}
}

// pins and passphrases as the kdf sees them
func TestPinNormal(t *testing.T) {
	same := map[string]string{
		"۱۲۳۴":               "1234", // extended arabic-indic, a persian keyboard
		"١٢٣٤":               "1234", // arabic-indic
		"१२३४":               "1234", // devanagari
		"１２３４":               "1234", // fullwidth
		"e\u0301te":          "\u00e9te",
		"long\u00a0phrase":   "long phrase",
		"ideo\u3000space":    "ideo space",
		" keeps its spaces ": " keeps its spaces ",
		"Ünïcödé ok":         "Ünïcödé ok",
	}
	for in, want := range same {
		got, err := pinNormal([]byte(in))
		if err != nil || string(got) != want {
			t.Fatalf("%q: %q %v", in, got, err)
		}
	}
	for _, bad := range []string{"", "a\x00b", "tab\there", "new\nline", "\x7f", string([]byte{0xff, 0xfe}), string(bytes.Repeat([]byte("a"), pinPassMax+1))} {
		if _, err := pinNormal([]byte(bad)); err == nil {
			t.Fatalf("%q taken", bad)
		}
	}
	if _, err := pinNormal(bytes.Repeat([]byte("a"), pinPassMax)); err != nil {
		t.Fatal("the longest passphrase refused")
	}
	// a pin typed on a persian keyboard opens what the pad set
	tb := vaultTable(t)
	if r, _ := pinCheck([]byte("۲۴۶۸۱۰"), tb, pinLegacy{}); r.Index != 3 {
		t.Fatalf("persian digits: %+v", r)
	}
	// the digit folding rests on every decimal digit range being whole runs
	// of 0 to 9
	for _, g := range unicode.Nd.R16 {
		if g.Stride != 1 || (int(g.Hi)-int(g.Lo)+1)%10 != 0 {
			t.Fatalf("nd range %x-%x", g.Lo, g.Hi)
		}
	}
	for _, g := range unicode.Nd.R32 {
		if g.Stride != 1 || (int(g.Hi)-int(g.Lo)+1)%10 != 0 {
			t.Fatalf("nd range %x-%x", g.Lo, g.Hi)
		}
	}
}

// a passphrase in the vault's entry opens it like a pin, under the new key
func TestPinV3Passphrase(t *testing.T) {
	ks := newStandIn()
	tb := vaultTable(t)
	tb = *check3(t, "1234", tb, ks).R
	out, err := pinRewrapKS([]byte("246810"), []byte("correct horse ۱۲ battery"), tb, pinLegacy{}, ks.mac, testKey, 3)
	if err != nil {
		t.Fatal(err)
	}
	if r := check3(t, "correct horse 12 battery", out, ks); r.Index != 3 || r.Unwrapped != hex.EncodeToString(vaultKeyA) {
		t.Fatalf("the passphrase typed with ascii digits: %+v", r)
	}
}

// a vault entry whose wrap does not open is never moved: its key would go
func TestPinV3BrokenVaultStays(t *testing.T) {
	tb := vaultTable(t)
	tb.Entries[3].W = hex.EncodeToString(randBytes(pinWrapLen))
	ks := newStandIn()
	r := check3(t, "246810", tb, ks)
	if r.Index != 3 || r.Kind != 4 || r.Unwrapped != "" || r.R != nil || r.Mv != "" {
		t.Fatalf("a vault with no key moved: %+v", r)
	}
	// a whole one still moves
	if r := check3(t, "135790", tb, ks); r.Mv != "e" || r.R == nil {
		t.Fatalf("a whole vault did not move: %+v", r)
	}
}

// a phrase nfc makes longer than the kdf takes is refused up front
func TestPinFits(t *testing.T) {
	qa := strings.Repeat("\u0958", 85) // 255 bytes, 510 after nfc
	if pinFits([]byte(qa)) {
		t.Fatal("a phrase too long after nfc fits")
	}
	if !pinFits([]byte("correct horse battery")) || pinFits([]byte("a\nb")) {
		t.Fatal("fits is wrong for a plain phrase or a control character")
	}
}
