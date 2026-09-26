package main

// the pin table: one salt, a scrypt cost measured on this phone and sixteen
// entries of the same size. each entry holds a tag, what it opens (sealed) and
// a wrap: a vault's database key sealed under the pin, or random bytes. an
// unset entry is random bytes too, so the table does not say which pins or
// vaults exist. roles are fixed by the app (0 app, 1 wipe, 2 decoy, 3 vault,
// 4 to 6 the decoy's own). a check does the same work whatever was typed, and
// the key made from the pin never leaves this file.

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"sort"
	"time"

	"golang.org/x/crypto/chacha20poly1305"
	"golang.org/x/crypto/scrypt"
)

const (
	pinVersion   = 2
	pinEntries   = 16
	pinEntriesV1 = 8
	pinTagLen    = 32
	pinMetaLen   = 1 + 16 // kind, container id
	pinSealLen   = chacha20poly1305.NonceSize + pinMetaLen + chacha20poly1305.Overhead
	pinKeyLen    = 32 // a vault's database key
	pinWrapLen   = chacha20poly1305.NonceSize + pinKeyLen + chacha20poly1305.Overhead
	pinSaltLen   = 32
	pinLogNLow   = 14 // 16 MiB at r=8
	pinLogNHigh  = 15 // 32 MiB, what backups use
	pinR         = 8
	pinP         = 1
)

var (
	errPinCollision = errors.New("collision")
	errPinWrong     = errors.New("wrong pin")
)

// what a check did, counted, so a test can show every pin costs the same
var pinCount struct{ kdf, mac, open, legacy int }

type pinEntry struct {
	T string `json:"t"`           // tag, hex
	M string `json:"m"`           // sealed kind and container, hex
	W string `json:"w,omitempty"` // sealed database key or random, hex. v2 only
}

type pinTable struct {
	V       int        `json:"v"`
	LogN    int        `json:"n"`
	Salt    string     `json:"s"`
	Entries []pinEntry `json:"e"`
}

// the legacy app and wipe checks: hex sha256 of "salt:pin"
type pinLegacy struct {
	AppSalt  string `json:"as"`
	AppHash  string `json:"ah"`
	WipeSalt string `json:"ws"`
	WipeHash string `json:"wh"`
}

type pinResult struct {
	Index      int    `json:"i"` // -1 when no entry matched
	Kind       int    `json:"k"`
	Container  string `json:"c"`
	LegacyApp  bool   `json:"la"`
	LegacyWipe bool   `json:"lw"`
	Unwrapped  string `json:"u"` // the vault key, hex, when the pin opened it
}

func randBytes(n int) []byte {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return b
}

func zero(b []byte) {
	for i := range b {
		b[i] = 0
	}
}

func label(k []byte, what string, i int) []byte {
	pinCount.mac++
	m := hmac.New(sha256.New, k)
	m.Write([]byte("kryfo pin v1 " + what))
	m.Write([]byte{byte(i)})
	return m.Sum(nil)
}

func pinKey(pin, salt []byte, logN int) ([]byte, error) {
	if logN < pinLogNLow || logN > pinLogNHigh {
		return nil, errors.New("cost out of range")
	}
	pinCount.kdf++
	return scrypt.Key(pin, salt, 1<<logN, pinR, pinP, 32)
}

// a fresh table: new salt, every entry random
func newPinTable(logN int) pinTable {
	t := pinTable{V: pinVersion, LogN: logN, Salt: hex.EncodeToString(randBytes(pinSaltLen))}
	for i := 0; i < pinEntries; i++ {
		t.Entries = append(t.Entries, randomEntry())
	}
	return t
}

func randomEntry() pinEntry {
	return pinEntry{
		T: hex.EncodeToString(randBytes(pinTagLen)),
		M: hex.EncodeToString(randBytes(pinSealLen)),
		W: hex.EncodeToString(randBytes(pinWrapLen)),
	}
}

func (t pinTable) copy() pinTable {
	return pinTable{V: t.V, LogN: t.LogN, Salt: t.Salt, Entries: append([]pinEntry(nil), t.Entries...)}
}

// the table as bytes
type pinRaw struct {
	salt               []byte
	tags, seals, wraps [][]byte
}

// v1 (eight entries, no wraps) or v2, refused whole if any part is the wrong
// shape
func (t pinTable) decode() (pinRaw, error) {
	var d pinRaw
	want := 0
	switch t.V {
	case 1:
		want = pinEntriesV1
	case pinVersion:
		want = pinEntries
	}
	if want == 0 || len(t.Entries) != want || t.LogN < pinLogNLow || t.LogN > pinLogNHigh {
		return d, errors.New("bad table")
	}
	salt, err := hex.DecodeString(t.Salt)
	if err != nil || len(salt) != pinSaltLen {
		return d, errors.New("bad salt")
	}
	d.salt = salt
	for _, e := range t.Entries {
		tg, err1 := hex.DecodeString(e.T)
		sl, err2 := hex.DecodeString(e.M)
		wr, err3 := hex.DecodeString(e.W)
		wrapOK := len(wr) == pinWrapLen
		if t.V == 1 {
			wrapOK = e.W == ""
		}
		if err1 != nil || err2 != nil || err3 != nil || len(tg) != pinTagLen || len(sl) != pinSealLen || !wrapOK {
			return pinRaw{}, errors.New("bad entry")
		}
		d.tags = append(d.tags, tg)
		d.seals = append(d.seals, sl)
		d.wraps = append(d.wraps, wr)
	}
	return d, nil
}

// a v1 table as v2: the same salt, cost and entries, each with a random wrap,
// and eight more random entries, so every pin opens what it did. a v2 table
// comes back as it is
func (t pinTable) upgrade() (pinTable, error) {
	if _, err := t.decode(); err != nil {
		return t, err
	}
	if t.V == pinVersion {
		return t.copy(), nil
	}
	out := pinTable{V: pinVersion, LogN: t.LogN, Salt: t.Salt}
	for _, e := range t.Entries {
		out.Entries = append(out.Entries, pinEntry{T: e.T, M: e.M, W: hex.EncodeToString(randBytes(pinWrapLen))})
	}
	for len(out.Entries) < pinEntries {
		out.Entries = append(out.Entries, randomEntry())
	}
	return out, nil
}

// every call works on v2. a v1 table is upgraded in memory, so it costs the
// same and opens the same until the upgraded one is written
func (t pinTable) current() (pinTable, pinRaw, error) {
	up, err := t.upgrade()
	if err != nil {
		return t, pinRaw{}, err
	}
	d, err := up.decode()
	return up, d, err
}

func legacyHash(pin []byte, salt string) []byte {
	h := sha256.Sum256(append([]byte(salt+":"), pin...))
	return []byte(hex.EncodeToString(h[:]))
}

// one legacy check. with nothing stored it compares against a stand-in, so the
// work is the same either way
func legacyMatch(pin []byte, salt, hash string) bool {
	pinCount.legacy++
	if salt == "" || hash == "" {
		salt = hex.EncodeToString(randBytes(16))
		hash = hex.EncodeToString(randBytes(32))
	}
	return subtle.ConstantTimeCompare(legacyHash(pin, salt), []byte(hash)) == 1
}

func openSealed(key, sealed []byte) ([]byte, bool) {
	pinCount.open++
	a, err := chacha20poly1305.New(key)
	if err != nil {
		return nil, false
	}
	n := chacha20poly1305.NonceSize
	if len(sealed) < n+chacha20poly1305.Overhead {
		return nil, false
	}
	out, err := a.Open(nil, sealed[:n], sealed[n:], nil)
	return out, err == nil
}

func seal(key, plain []byte) []byte {
	a, err := chacha20poly1305.New(key)
	if err != nil {
		panic(err)
	}
	nonce := randBytes(chacha20poly1305.NonceSize)
	return append(nonce, a.Seal(nil, nonce, plain, nil)...)
}

// the check: one kdf, every tag, then the record and the wrap of one entry,
// the match or entry 0 when nothing matched
func pinCheck(pin []byte, t pinTable, old pinLegacy) (pinResult, error) {
	t, d, err := t.current()
	if err != nil {
		return pinResult{}, err
	}
	k, err := pinKey(pin, d.salt, t.LogN)
	if err != nil {
		return pinResult{}, err
	}
	defer zero(k)

	match, any := -1, 0
	for i := 0; i < pinEntries; i++ {
		tag := label(k, "tag", i)
		eq := subtle.ConstantTimeCompare(tag, d.tags[i])
		match = subtle.ConstantTimeSelect(eq, i, match)
		any |= eq
		zero(tag)
	}
	at := subtle.ConstantTimeSelect(any, match, 0)
	mk := label(k, "meta", at)
	meta, opened := openSealed(mk, d.seals[at])
	zero(mk)
	wk := label(k, "wrap", at)
	key, keyOK := openSealed(wk, d.wraps[at])
	zero(wk)
	defer zero(key)

	r := pinResult{Index: -1}
	r.LegacyApp = legacyMatch(pin, old.AppSalt, old.AppHash)
	r.LegacyWipe = legacyMatch(pin, old.WipeSalt, old.WipeHash)
	if any == 1 && opened && len(meta) == pinMetaLen {
		r.Index = match
		r.Kind = int(meta[0])
		r.Container = hex.EncodeToString(meta[1:])
		if keyOK && len(key) == pinKeyLen {
			r.Unwrapped = hex.EncodeToString(key)
		}
	}
	return r, nil
}

// whether the pin behind k already opens an entry other than index, or matches
// an old check
func pinClashes(k []byte, d pinRaw, index int, pin []byte, old pinLegacy) bool {
	clash := 0
	for i := 0; i < pinEntries; i++ {
		tag := label(k, "tag", i)
		eq := subtle.ConstantTimeCompare(tag, d.tags[i])
		if i != index {
			clash |= eq
		}
		zero(tag)
	}
	if legacyMatch(pin, old.AppSalt, old.AppHash) {
		clash = 1
	}
	if legacyMatch(pin, old.WipeSalt, old.WipeHash) {
		clash = 1
	}
	return clash == 1
}

// entry index under k: the tag, what it opens, and the key sealed, or random
// bytes when there is none
func pinSealEntry(k []byte, index int, meta, key []byte) pinEntry {
	tag := label(k, "tag", index)
	mk := label(k, "meta", index)
	e := pinEntry{T: hex.EncodeToString(tag), M: hex.EncodeToString(seal(mk, meta))}
	zero(tag)
	zero(mk)
	if len(key) > 0 {
		wk := label(k, "wrap", index)
		e.W = hex.EncodeToString(seal(wk, key))
		zero(wk)
	} else {
		e.W = hex.EncodeToString(randBytes(pinWrapLen))
	}
	return e
}

// sets entry index to open kind/container with pin, with wrapPlain (a vault's
// database key) sealed into it when given. refused, with nothing changed, when
// the pin already opens another entry or matches an old check
func pinSetup(pin []byte, t pinTable, old pinLegacy, index, kind int, container, wrapPlain []byte) (pinTable, error) {
	if index < 0 || index >= pinEntries || kind < 1 || kind > 255 || len(container) != 16 ||
		(len(wrapPlain) != 0 && len(wrapPlain) != pinKeyLen) {
		return t, errors.New("bad setup")
	}
	up, d, err := t.current()
	if err != nil {
		return t, err
	}
	k, err := pinKey(pin, d.salt, t.LogN)
	if err != nil {
		return t, err
	}
	defer zero(k)
	if pinClashes(k, d, index, pin, old) {
		return t, errPinCollision
	}
	out := up.copy()
	out.Entries[index] = pinSealEntry(k, index, append([]byte{byte(kind)}, container...), wrapPlain)
	return out, nil
}

// the pin of entry index changes from oldPin to newPin. what the entry opens
// and the key it wraps stay, opened and sealed again here, so the key never
// leaves. a wrong old pin, an entry with no key, or a new pin that clashes
// changes nothing
func pinRewrap(oldPin, newPin []byte, t pinTable, old pinLegacy, index int) (pinTable, error) {
	if index < 0 || index >= pinEntries {
		return t, errors.New("bad index")
	}
	up, d, err := t.current()
	if err != nil {
		return t, err
	}
	ko, err := pinKey(oldPin, d.salt, t.LogN)
	if err != nil {
		return t, err
	}
	defer zero(ko)
	tag := label(ko, "tag", index)
	eq := subtle.ConstantTimeCompare(tag, d.tags[index])
	zero(tag)
	if eq != 1 {
		return t, errPinWrong
	}
	mk := label(ko, "meta", index)
	meta, metaOK := openSealed(mk, d.seals[index])
	zero(mk)
	defer zero(meta)
	wk := label(ko, "wrap", index)
	key, keyOK := openSealed(wk, d.wraps[index])
	zero(wk)
	defer zero(key)
	if !metaOK || len(meta) != pinMetaLen || !keyOK || len(key) != pinKeyLen {
		return t, errors.New("nothing wrapped")
	}

	kn, err := pinKey(newPin, d.salt, t.LogN)
	if err != nil {
		return t, err
	}
	defer zero(kn)
	if pinClashes(kn, d, index, newPin, old) {
		return t, errPinCollision
	}
	out := up.copy()
	out.Entries[index] = pinSealEntry(kn, index, meta, key)
	return out, nil
}

// the entry goes back to random bytes, its wrap too
func pinClear(t pinTable, index int) (pinTable, error) {
	up, _, err := t.current()
	if err != nil {
		return t, err
	}
	if index < 0 || index >= pinEntries {
		return t, errors.New("bad index")
	}
	out := up.copy()
	out.Entries[index] = randomEntry()
	return out, nil
}

// the cost for this phone: the median of three runs at the low cost, and the
// high cost when that fits under 250 ms. never below the low cost, and the
// low one when memory is short
func pinCalibrate(memAvail int64) (logN int, ms int64) {
	salt := randBytes(pinSaltLen)
	run := func(n int) int64 {
		var d []int64
		for i := 0; i < 3; i++ {
			start := time.Now()
			k, _ := scrypt.Key([]byte("calibrate"), salt, 1<<n, pinR, pinP, 32)
			d = append(d, time.Since(start).Milliseconds())
			zero(k)
		}
		sort.Slice(d, func(a, b int) bool { return d[a] < d[b] })
		return d[1]
	}
	low := run(pinLogNLow)
	if memAvail > 0 && memAvail < 96<<20 {
		return pinLogNLow, low
	}
	if low*2 <= 250 {
		return pinLogNHigh, low * 2
	}
	return pinLogNLow, low
}
