package main

// the pin table. one salt, one scrypt cost measured on this phone, and eight
// entries of the same size. an entry that is set holds a tag and a sealed
// record of what it opens; one that is not holds random bytes of the same
// length, so the stored table does not say which pins exist. which entry
// plays which role is fixed by the app (0 app, 1 wipe, 2 decoy, 3 vault,
// the rest for pins set inside the decoy and for personas later).
//
// a check does the same work whatever was typed: one scrypt, eight tags
// compared with no early exit, one sealed record opened (the matching one,
// or entry 0 when none matches), both old sha256 checks with stand-ins when
// there is nothing old, and one wrapped key opened, real or a stand-in. the
// key made from the pin never leaves this file.

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
	pinEntries  = 8
	pinTagLen   = 32
	pinMetaLen  = 1 + 16 // kind, container id
	pinSealLen  = chacha20poly1305.NonceSize + pinMetaLen + chacha20poly1305.Overhead
	pinSaltLen  = 32
	pinLogNLow  = 14 // 16 MiB at r=8
	pinLogNHigh = 15 // 32 MiB, what backups use
	pinR        = 8
	pinP        = 1
)

var errPinCollision = errors.New("collision")

// what a check did, counted, so a test can show every pin costs the same
var pinCount struct{ kdf, mac, open, legacy int }

type pinEntry struct {
	T string `json:"t"` // tag, hex
	M string `json:"m"` // sealed kind and container, hex
}

type pinTable struct {
	V       int        `json:"v"`
	LogN    int        `json:"n"`
	Salt    string     `json:"s"`
	Entries []pinEntry `json:"e"`
}

// the old app and wipe checks: sha256 of "salt:pin" as hex, as lock_state
// stored them before the table
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
	t := pinTable{V: 1, LogN: logN, Salt: hex.EncodeToString(randBytes(pinSaltLen))}
	for i := 0; i < pinEntries; i++ {
		t.Entries = append(t.Entries, randomEntry())
	}
	return t
}

func randomEntry() pinEntry {
	return pinEntry{T: hex.EncodeToString(randBytes(pinTagLen)), M: hex.EncodeToString(randBytes(pinSealLen))}
}

// the table as bytes, refused whole if any part is the wrong shape
func (t pinTable) decode() (salt []byte, tags, seals [][]byte, err error) {
	if t.V != 1 || len(t.Entries) != pinEntries || t.LogN < pinLogNLow || t.LogN > pinLogNHigh {
		return nil, nil, nil, errors.New("bad table")
	}
	salt, err = hex.DecodeString(t.Salt)
	if err != nil || len(salt) != pinSaltLen {
		return nil, nil, nil, errors.New("bad salt")
	}
	for _, e := range t.Entries {
		tg, err1 := hex.DecodeString(e.T)
		sl, err2 := hex.DecodeString(e.M)
		if err1 != nil || err2 != nil || len(tg) != pinTagLen || len(sl) != pinSealLen {
			return nil, nil, nil, errors.New("bad entry")
		}
		tags = append(tags, tg)
		seals = append(seals, sl)
	}
	return salt, tags, seals, nil
}

func legacyHash(pin []byte, salt string) []byte {
	h := sha256.Sum256(append([]byte(salt+":"), pin...))
	return []byte(hex.EncodeToString(h[:]))
}

// one old check. with nothing stored it compares against a stand-in, so the
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

// the check. wrapped is the vault's wrapped database key, or nil: a
// stand-in of the same size is opened instead
func pinCheck(pin []byte, t pinTable, old pinLegacy, wrapped []byte) (pinResult, error) {
	salt, tags, seals, err := t.decode()
	if err != nil {
		return pinResult{}, err
	}
	k, err := pinKey(pin, salt, t.LogN)
	if err != nil {
		return pinResult{}, err
	}
	defer zero(k)

	match, any := -1, 0
	for i := 0; i < pinEntries; i++ {
		tag := label(k, "tag", i)
		eq := subtle.ConstantTimeCompare(tag, tags[i])
		match = subtle.ConstantTimeSelect(eq, i, match)
		any |= eq
		zero(tag)
	}
	at := subtle.ConstantTimeSelect(any, match, 0)
	mk := label(k, "meta", at)
	meta, opened := openSealed(mk, seals[at])
	zero(mk)

	if len(wrapped) == 0 {
		wrapped = randBytes(chacha20poly1305.NonceSize + 32 + chacha20poly1305.Overhead)
	}
	wk := label(k, "wrap", 0)
	unwrapped, unwrappedOK := openSealed(wk, wrapped)
	zero(wk)

	r := pinResult{Index: -1}
	r.LegacyApp = legacyMatch(pin, old.AppSalt, old.AppHash)
	r.LegacyWipe = legacyMatch(pin, old.WipeSalt, old.WipeHash)
	if any == 1 && opened && len(meta) == pinMetaLen {
		r.Index = match
		r.Kind = int(meta[0])
		r.Container = hex.EncodeToString(meta[1:])
	}
	if unwrappedOK {
		r.Unwrapped = hex.EncodeToString(unwrapped)
		zero(unwrapped)
	}
	return r, nil
}

// sets entry index to open kind/container with pin. refused, with nothing
// changed, when the pin already opens another entry or matches an old check.
// wrapPlain, when given, comes back sealed under this pin (the vault's key)
func pinSetup(pin []byte, t pinTable, old pinLegacy, index, kind int, container, wrapPlain []byte) (pinTable, []byte, error) {
	if index < 0 || index >= pinEntries || kind < 1 || kind > 255 || len(container) != 16 {
		return t, nil, errors.New("bad setup")
	}
	salt, tags, _, err := t.decode()
	if err != nil {
		return t, nil, err
	}
	k, err := pinKey(pin, salt, t.LogN)
	if err != nil {
		return t, nil, err
	}
	defer zero(k)

	clash := 0
	for i := 0; i < pinEntries; i++ {
		tag := label(k, "tag", i)
		eq := subtle.ConstantTimeCompare(tag, tags[i])
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
	if clash == 1 {
		return t, nil, errPinCollision
	}

	out := pinTable{V: t.V, LogN: t.LogN, Salt: t.Salt, Entries: append([]pinEntry(nil), t.Entries...)}
	tag := label(k, "tag", index)
	mk := label(k, "meta", index)
	meta := append([]byte{byte(kind)}, container...)
	out.Entries[index] = pinEntry{T: hex.EncodeToString(tag), M: hex.EncodeToString(seal(mk, meta))}
	zero(tag)
	zero(mk)

	var wrapped []byte
	if len(wrapPlain) > 0 {
		wk := label(k, "wrap", 0)
		wrapped = seal(wk, wrapPlain)
		zero(wk)
	}
	return out, wrapped, nil
}

// the entry goes back to random bytes
func pinClear(t pinTable, index int) (pinTable, error) {
	if _, _, _, err := t.decode(); err != nil {
		return t, err
	}
	if index < 0 || index >= pinEntries {
		return t, errors.New("bad index")
	}
	out := pinTable{V: t.V, LogN: t.LogN, Salt: t.Salt, Entries: append([]pinEntry(nil), t.Entries...)}
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
