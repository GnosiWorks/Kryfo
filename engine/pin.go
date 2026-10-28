package main

// the pin table: one salt, a scrypt cost measured on this phone and sixteen
// entries of the same size. each entry holds a tag, what it opens (sealed) and
// a wrap: a vault's database key sealed under the pin, or random bytes. an
// unset entry is random bytes too, so the table does not say which pins or
// vaults exist. roles are fixed by the app (0 app, 1 wipe, 2 decoy, 3 vault,
// 4 to 6 the decoy's own). a check does the same work whatever was typed.
//
// v3 mixes in a key the phone's keystore holds and never hands out: s is
// scrypt(pin, salt) as before, x = hmac(s, a label) goes to the keystore, m
// comes back, and the new key is hkdf(salt m, secret s). only x leaves this
// file. s waits under a one-use handle in between, zeroed when it is used or
// when the keystore takes too long. every check tries each entry under the
// old key and under the new one, so entries not moved yet still open.

import (
	"crypto/hkdf"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"sort"
	"sync"
	"time"
	"unicode"
	"unicode/utf8"

	"golang.org/x/crypto/chacha20poly1305"
	"golang.org/x/crypto/scrypt"
	"golang.org/x/text/unicode/norm"
)

const (
	pinVersion   = 2 // what a new table starts as, before any keystore key
	pinVersion3  = 3
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
	pinMacLen    = 32
	// the longest pin or passphrase, in utf-8 bytes
	pinPassMax = 256
)

// how long s waits for the keystore before it is zeroed
var pinHoldLife = 15 * time.Second

const (
	pinXLabel   = "kryfo pin keystore in v3"
	pinNewInfo  = "kryfo pin v3"
	pinV1Prefix = "kryfo pin v1 "
	pinV3Prefix = "kryfo pin v3 "
)

var (
	errPinCollision = errors.New("collision")
	errPinWrong     = errors.New("wrong pin")
	errPinKeystore  = errors.New("keystore")
	errPinBad       = errors.New("bad pin")
)

// what a check did, counted, so a test can show every pin costs the same
var pinCount struct{ kdf, mac, open, legacy, seal int }

type pinEntry struct {
	T string `json:"t"`           // tag, hex
	M string `json:"m"`           // sealed kind and container, hex
	W string `json:"w,omitempty"` // sealed database key or random, hex. v2 on
}

// the keystore key v3 entries need: which one (g), whether it works only
// while the phone is unlocked (u), where it lives (l: 0 software, 1 secure
// hardware, 2 strongbox) and its check value, an hmac of a fixed input that
// says nothing about any pin
type pinKeyInfo struct {
	G  int    `json:"g"`
	U  int    `json:"u"`
	L  int    `json:"l"`
	KC string `json:"kc"`
}

func (k *pinKeyInfo) ok() bool {
	if k == nil || k.G < 1 || k.G > 255 || (k.U != 0 && k.U != 1) || k.L < 0 || k.L > 2 {
		return false
	}
	b, err := hex.DecodeString(k.KC)
	return err == nil && len(b) == pinMacLen
}

type pinTable struct {
	V       int         `json:"v"`
	LogN    int         `json:"n"`
	Salt    string      `json:"s"`
	K       *pinKeyInfo `json:"k,omitempty"` // v3 only
	Entries []pinEntry  `json:"e"`
}

// the legacy app and wipe checks: hex sha256 of "salt:pin". am and wm name
// the entry each moves into once its pin is typed with the keystore there
type pinLegacy struct {
	AppSalt  string   `json:"as"`
	AppHash  string   `json:"ah"`
	WipeSalt string   `json:"ws"`
	WipeHash string   `json:"wh"`
	AppTo    *pinMove `json:"am,omitempty"`
	WipeTo   *pinMove `json:"wm,omitempty"`
}

type pinMove struct {
	I int    `json:"i"`
	K int    `json:"k"`
	C string `json:"c"`
}

func (m *pinMove) meta() ([]byte, bool) {
	if m == nil || m.I < 0 || m.I >= pinEntries || m.K < 1 || m.K > 255 {
		return nil, false
	}
	c, err := hex.DecodeString(m.C)
	if err != nil || len(c) != 16 {
		return nil, false
	}
	return append([]byte{byte(m.K)}, c...), true
}

type pinResult struct {
	Index      int    `json:"i"` // -1 when no entry matched
	Kind       int    `json:"k"`
	Container  string `json:"c"`
	LegacyApp  bool   `json:"la"`
	LegacyWipe bool   `json:"lw"`
	Unwrapped  string `json:"u"` // the vault key, hex, when the pin opened it
	// the key the match opened under: 2 the old one, 3 the keystore's, 0 none
	G int `json:"g"`
	// the table with the typed pin moved under the keystore's key, checked
	// by opening it again: the entry it opened (e), or a legacy app (a) or
	// wipe (w) pin moved into its entry. absent when nothing can move
	Mv string    `json:"mv,omitempty"`
	R  *pinTable `json:"r,omitempty"`
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

func allZero(b []byte) bool {
	v := byte(0)
	for _, c := range b {
		v |= c
	}
	return v == 0
}

func pinLabel(k []byte, prefix, what string, i int) []byte {
	pinCount.mac++
	m := hmac.New(sha256.New, k)
	m.Write([]byte(prefix + what))
	m.Write([]byte{byte(i)})
	return m.Sum(nil)
}

func label(k []byte, what string, i int) []byte { return pinLabel(k, pinV1Prefix, what, i) }

// a label under the keystore's key: its own prefix, so no bug that made the
// two keys equal could make a v3 tag read as a v1 one
func label3(k []byte, what string, i int) []byte { return pinLabel(k, pinV3Prefix, what, i) }

// what the keystore is asked to sign: opens nothing by itself, unlike s
func pinX(s []byte) []byte {
	pinCount.mac++
	m := hmac.New(sha256.New, s)
	m.Write([]byte(pinXLabel))
	return m.Sum(nil)
}

// the new key. s stays in, so a keystore that answered the same for every
// pin leaves the key no weaker than v2
func pinKeyNew(s, m []byte) []byte {
	pinCount.mac++
	k, err := hkdf.Key(sha256.New, s, m, pinNewInfo, 32)
	if err != nil {
		panic(err)
	}
	return k
}

func pinKey(pin, salt []byte, logN int) ([]byte, error) {
	if logN < pinLogNLow || logN > pinLogNHigh {
		return nil, errors.New("cost out of range")
	}
	pinCount.kdf++
	return scrypt.Key(pin, salt, 1<<logN, pinR, pinP, 32)
}

// a pin or passphrase as the kdf takes it: nfc, every decimal digit as its
// ascii one and every space as a plain one, so a phrase typed on another
// keyboard tomorrow still opens. no control characters, at most 256 bytes
func pinNormal(pin []byte) ([]byte, error) {
	if len(pin) == 0 || !utf8.Valid(pin) {
		return nil, errPinBad
	}
	n := norm.NFC.Bytes(pin)
	// nfc hands back the same bytes when nothing changes: those are the
	// caller's to zero
	own := len(n) > 0 && &n[0] != &pin[0]
	defer func() {
		if own {
			zero(n)
		}
	}()
	out := make([]byte, 0, len(n))
	for i := 0; i < len(n); {
		r, w := utf8.DecodeRune(n[i:])
		i += w
		switch {
		case r == 0 || unicode.IsControl(r):
			zero(out)
			return nil, errPinBad
		case r >= '0' && r <= '9':
			out = append(out, byte(r))
		case unicode.IsDigit(r):
			out = append(out, byte('0'+pinDigit(r)))
		case r != ' ' && unicode.Is(unicode.Zs, r):
			out = append(out, ' ')
		default:
			out = utf8.AppendRune(out, r)
		}
	}
	if len(out) > pinPassMax {
		zero(out)
		return nil, errPinBad
	}
	return out, nil
}

// a decimal digit's value: unicode keeps each script's 0 to 9 in a row
func pinDigit(r rune) int {
	for _, g := range unicode.Nd.R16 {
		if r >= rune(g.Lo) && r <= rune(g.Hi) {
			return int(r-rune(g.Lo)) % 10
		}
	}
	for _, g := range unicode.Nd.R32 {
		if r >= rune(g.Lo) && r <= rune(g.Hi) {
			return int(r-rune(g.Lo)) % 10
		}
	}
	return 0
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
	out := pinTable{V: t.V, LogN: t.LogN, Salt: t.Salt, Entries: append([]pinEntry(nil), t.Entries...)}
	if t.K != nil {
		k := *t.K
		out.K = &k
	}
	return out
}

// the table as bytes
type pinRaw struct {
	salt               []byte
	tags, seals, wraps [][]byte
}

// v1 (eight entries, no wraps), v2, or v3 (v2's entries and the keystore
// key's header), refused whole if any part is the wrong shape
func (t pinTable) decode() (pinRaw, error) {
	var d pinRaw
	want := 0
	switch t.V {
	case 1:
		want = pinEntriesV1
	case pinVersion, pinVersion3:
		want = pinEntries
	}
	if want == 0 || len(t.Entries) != want || t.LogN < pinLogNLow || t.LogN > pinLogNHigh {
		return d, errors.New("bad table")
	}
	if (t.V == pinVersion3) != (t.K != nil) || (t.K != nil && !t.K.ok()) {
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
// and eight more random entries, so every pin opens what it did. a v2 or v3
// table comes back as it is
func (t pinTable) upgrade() (pinTable, error) {
	if _, err := t.decode(); err != nil {
		return t, err
	}
	if t.V != 1 {
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

// every call works on v2 or v3. a v1 table is upgraded in memory, so it costs
// the same and opens the same until the upgraded one is written
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
	pinCount.seal++
	a, err := chacha20poly1305.New(key)
	if err != nil {
		panic(err)
	}
	nonce := randBytes(chacha20poly1305.NonceSize)
	return append(nonce, a.Seal(nil, nonce, plain, nil)...)
}

// s between the kdf and the keystore's answer, with what the legacy checks
// found for the same pin
type pinHeld struct {
	s          []byte
	salt       string
	logN       int
	legacyApp  bool
	legacyWipe bool
}

var pinHolds = struct {
	sync.Mutex
	m map[string]*pinHeld
}{m: map[string]*pinHeld{}}

func pinHold(p *pinHeld) string {
	h := hex.EncodeToString(randBytes(16))
	pinHolds.Lock()
	pinHolds.m[h] = p
	pinHolds.Unlock()
	time.AfterFunc(pinHoldLife, func() { pinDrop(h) })
	return h
}

func pinTake(h string) *pinHeld {
	pinHolds.Lock()
	defer pinHolds.Unlock()
	p := pinHolds.m[h]
	delete(pinHolds.m, h)
	return p
}

// zeroed under the lock, so whoever looks next sees it gone
func pinDrop(h string) {
	pinHolds.Lock()
	defer pinHolds.Unlock()
	if p := pinHolds.m[h]; p != nil {
		delete(pinHolds.m, h)
		zero(p.s)
	}
}

// the handle's s, for the table it was made for only
func pinTakeFor(h string, t pinTable) (*pinHeld, error) {
	p := pinTake(h)
	if p == nil {
		return nil, errors.New("no such check")
	}
	if p.salt != t.Salt || p.logN != t.LogN {
		zero(p.s)
		return nil, errors.New("stale check")
	}
	return p, nil
}

// the first half of every check: the kdf and the legacy checks. s stays
// here under the handle; x is what the keystore signs
func pinBegin(pin []byte, t pinTable, old pinLegacy) (string, []byte, error) {
	p, err := pinNormal(pin)
	if err != nil {
		return "", nil, err
	}
	defer zero(p)
	up, d, err := t.current()
	if err != nil {
		return "", nil, err
	}
	s, err := pinKey(p, d.salt, up.LogN)
	if err != nil {
		return "", nil, err
	}
	held := &pinHeld{
		s: s, salt: t.Salt, logN: t.LogN,
		legacyApp:  legacyMatch(p, old.AppSalt, old.AppHash),
		legacyWipe: legacyMatch(p, old.WipeSalt, old.WipeHash),
	}
	return pinHold(held), pinX(s), nil
}

// both keys for one pin. without the keystore's m a random one stands in,
// so the work is the same and nothing opens under the new key (ok3 0). an
// m that is the wrong size, all zeros or x itself is the keystore failing
type pinKeys struct {
	old, new []byte
	ok3      int
}

func pinKeysFor(s, m []byte) (pinKeys, error) {
	x := pinX(s)
	bad := len(m) != pinMacLen || allZero(m) || hmac.Equal(m, x)
	zero(x)
	ok3 := 1
	if len(m) == 0 {
		m, ok3 = randBytes(pinMacLen), 0
	} else if bad {
		return pinKeys{}, errPinKeystore
	}
	return pinKeys{old: append([]byte(nil), s...), new: pinKeyNew(s, m), ok3: ok3}, nil
}

func (k pinKeys) zero() {
	zero(k.old)
	zero(k.new)
}

// a when on is 1, else b, without a branch. both are zeroed, the copy kept
func pinPick(on int, a, b []byte) []byte {
	out := append([]byte(nil), b...)
	subtle.ConstantTimeCopy(on, out, a)
	zero(a)
	zero(b)
	return out
}

// the check's second half: every tag under both keys, then the record and
// the wrap of one entry (the match, or entry 0 when nothing matched), then
// the move worked out and opened again, whatever matched
func pinFinish(p *pinHeld, m []byte, t pinTable, old pinLegacy, key *pinKeyInfo) (pinResult, error) {
	up, d, err := t.current()
	if err != nil {
		return pinResult{}, err
	}
	ks, err := pinKeysFor(p.s, m)
	if err != nil {
		return pinResult{}, err
	}
	defer ks.zero()

	matchOld, anyOld, matchNew, anyNew := -1, 0, -1, 0
	for i := 0; i < pinEntries; i++ {
		a := label(ks.old, "tag", i)
		b := label3(ks.new, "tag", i)
		eqA := subtle.ConstantTimeCompare(a, d.tags[i])
		eqB := subtle.ConstantTimeCompare(b, d.tags[i]) & ks.ok3
		matchOld = subtle.ConstantTimeSelect(eqA, i, matchOld)
		matchNew = subtle.ConstantTimeSelect(eqB, i, matchNew)
		anyOld |= eqA
		anyNew |= eqB
		zero(a)
		zero(b)
	}
	// a match under the new key wins: it is the one written last
	match := subtle.ConstantTimeSelect(anyNew, matchNew, matchOld)
	any := anyOld | anyNew
	at := subtle.ConstantTimeSelect(any, match, 0)
	mk := pinPick(anyNew, label3(ks.new, "meta", at), label(ks.old, "meta", at))
	meta, opened := openSealed(mk, d.seals[at])
	zero(mk)
	defer zero(meta)
	wk := pinPick(anyNew, label3(ks.new, "wrap", at), label(ks.old, "wrap", at))
	wrapped, keyOK := openSealed(wk, d.wraps[at])
	zero(wk)
	defer zero(wrapped)

	r := pinResult{Index: -1, LegacyApp: p.legacyApp, LegacyWipe: p.legacyWipe}
	found := any == 1 && opened && len(meta) == pinMetaLen
	vaultKey := []byte(nil)
	if keyOK && len(wrapped) == pinKeyLen {
		vaultKey = wrapped
	}
	if found {
		r.Index = match
		r.Kind = int(meta[0])
		r.Container = hex.EncodeToString(meta[1:])
		r.Unwrapped = hex.EncodeToString(vaultKey)
		r.G = 2 + anyNew
	}

	// the move. sealed and checked every time, so it costs the same; kept
	// only when the keystore answered and something can move
	target, moveMeta, moveKey, mv := at, randBytes(pinMetaLen), []byte(nil), ""
	appTo, appOK := old.AppTo.meta()
	wipeTo, wipeOK := old.WipeTo.meta()
	switch {
	case found && anyNew == 0:
		copy(moveMeta, meta)
		moveKey, mv = vaultKey, "e"
	case any == 0 && r.LegacyApp && !r.LegacyWipe && appOK:
		target, mv = old.AppTo.I, "a"
		copy(moveMeta, appTo)
	case any == 0 && r.LegacyWipe && !r.LegacyApp && wipeOK:
		target, mv = old.WipeTo.I, "w"
		copy(moveMeta, wipeTo)
	}
	moved := up.copy()
	moved.Entries[target] = pinSealEntry3(ks.new, target, moveMeta, moveKey)
	verified := pinVerify3(ks.new, moved, target, moveMeta, moveKey)
	zero(moveMeta)
	if mv != "" && ks.ok3 == 1 && verified {
		if moved.V != pinVersion3 {
			if !key.ok() {
				return r, nil
			}
			k := *key
			moved.V, moved.K = pinVersion3, &k
		}
		r.Mv, r.R = mv, &moved
	}
	return r, nil
}

// whether entry i of t opens under the new key with what was sealed in it
func pinVerify3(k []byte, t pinTable, i int, meta, key []byte) bool {
	t.V, t.K = pinVersion, nil
	d, err := t.decode()
	if err != nil {
		return false
	}
	tag := label3(k, "tag", i)
	ok := subtle.ConstantTimeCompare(tag, d.tags[i]) == 1
	zero(tag)
	mk := label3(k, "meta", i)
	m, mOK := openSealed(mk, d.seals[i])
	zero(mk)
	ok = ok && mOK && subtle.ConstantTimeCompare(m, meta) == 1
	zero(m)
	wk := label3(k, "wrap", i)
	w, wOK := openSealed(wk, d.wraps[i])
	zero(wk)
	if len(key) > 0 {
		ok = ok && wOK && subtle.ConstantTimeCompare(w, key) == 1
	}
	zero(w)
	return ok
}

// whether the pin behind ks already opens an entry other than index, under
// either key, or matches an old check
func pinClashes(ks pinKeys, d pinRaw, index int, legacy bool) bool {
	clash := 0
	for i := 0; i < pinEntries; i++ {
		a := label(ks.old, "tag", i)
		b := label3(ks.new, "tag", i)
		eq := subtle.ConstantTimeCompare(a, d.tags[i]) | (subtle.ConstantTimeCompare(b, d.tags[i]) & ks.ok3)
		if i != index {
			clash |= eq
		}
		zero(a)
		zero(b)
	}
	if legacy {
		clash = 1
	}
	return clash == 1
}

// entry index under k: the tag, what it opens, and the key sealed, or random
// bytes when there is none
func pinSealWith(lbl func([]byte, string, int) []byte, k []byte, index int, meta, key []byte) pinEntry {
	tag := lbl(k, "tag", index)
	mk := lbl(k, "meta", index)
	e := pinEntry{T: hex.EncodeToString(tag), M: hex.EncodeToString(seal(mk, meta))}
	zero(tag)
	zero(mk)
	// the wrap is sealed either way, so an entry with no key costs the same.
	// an unset wrap is random bytes, never a seal of anything
	wk := lbl(k, "wrap", index)
	plain := key
	if len(key) == 0 {
		plain = randBytes(pinKeyLen)
	}
	w := seal(wk, plain)
	zero(wk)
	if len(key) == 0 {
		w = randBytes(pinWrapLen)
	}
	e.W = hex.EncodeToString(w)
	return e
}

func pinSealEntry(k []byte, index int, meta, key []byte) pinEntry {
	return pinSealWith(label, k, index, meta, key)
}

func pinSealEntry3(k []byte, index int, meta, key []byte) pinEntry {
	return pinSealWith(label3, k, index, meta, key)
}

// entry index written for the pin behind ks: under the new key when the
// keystore answered, the table's header going to v3 then, else under the
// old one, which only a table still on v2 takes
func pinWriteEntry(up pinTable, ks pinKeys, key *pinKeyInfo, index int, meta, wrapPlain []byte) (pinTable, error) {
	out := up.copy()
	if ks.ok3 == 0 {
		if out.V == pinVersion3 {
			return up, errPinKeystore
		}
		out.Entries[index] = pinSealEntry(ks.old, index, meta, wrapPlain)
		return out, nil
	}
	if out.V != pinVersion3 {
		if !key.ok() {
			return up, errors.New("bad key info")
		}
		k := *key
		out.V, out.K = pinVersion3, &k
	}
	out.Entries[index] = pinSealEntry3(ks.new, index, meta, wrapPlain)
	return out, nil
}

// sets entry index to open kind/container with the pin behind p, with
// wrapPlain (a vault's database key) sealed into it when given. refused, with
// nothing changed, when the pin already opens another entry under either key
// or matches an old check
func pinSetupFinish(p *pinHeld, m []byte, t pinTable, key *pinKeyInfo, index, kind int, container, wrapPlain []byte) (pinTable, error) {
	if index < 0 || index >= pinEntries || kind < 1 || kind > 255 || len(container) != 16 ||
		(len(wrapPlain) != 0 && len(wrapPlain) != pinKeyLen) {
		return t, errors.New("bad setup")
	}
	up, d, err := t.current()
	if err != nil {
		return t, err
	}
	ks, err := pinKeysFor(p.s, m)
	if err != nil {
		return t, err
	}
	defer ks.zero()
	if ks.ok3 == 0 && up.V == pinVersion3 {
		return t, errPinKeystore
	}
	if pinClashes(ks, d, index, p.legacyApp || p.legacyWipe) {
		return t, errPinCollision
	}
	out, err := pinWriteEntry(up, ks, key, index, append([]byte{byte(kind)}, container...), wrapPlain)
	if err != nil {
		return t, err
	}
	return out, nil
}

// the pin of entry index changes from the one behind po to the one behind
// pn. what the entry opens and the key it wraps stay, opened and sealed
// again here, so the key never leaves. the old pin may open it under either
// key; the new one is written under the new key. a wrong old pin, an entry
// with no key, or a new pin that clashes changes nothing
func pinRewrapFinish(po *pinHeld, mo []byte, pn *pinHeld, mn []byte, t pinTable, key *pinKeyInfo, index int) (pinTable, error) {
	if index < 0 || index >= pinEntries {
		return t, errors.New("bad index")
	}
	up, d, err := t.current()
	if err != nil {
		return t, err
	}
	ko, err := pinKeysFor(po.s, mo)
	if err != nil {
		return t, err
	}
	defer ko.zero()
	kn, err := pinKeysFor(pn.s, mn)
	if err != nil {
		return t, err
	}
	defer kn.zero()
	if ko.ok3 != kn.ok3 || (kn.ok3 == 0 && up.V == pinVersion3) {
		return t, errPinKeystore
	}
	a := label(ko.old, "tag", index)
	b := label3(ko.new, "tag", index)
	eqA := subtle.ConstantTimeCompare(a, d.tags[index])
	eqB := subtle.ConstantTimeCompare(b, d.tags[index]) & ko.ok3
	zero(a)
	zero(b)
	if eqA|eqB != 1 {
		return t, errPinWrong
	}
	mk := pinPick(eqB, label3(ko.new, "meta", index), label(ko.old, "meta", index))
	meta, metaOK := openSealed(mk, d.seals[index])
	zero(mk)
	defer zero(meta)
	wk := pinPick(eqB, label3(ko.new, "wrap", index), label(ko.old, "wrap", index))
	wrapped, keyOK := openSealed(wk, d.wraps[index])
	zero(wk)
	defer zero(wrapped)
	if !metaOK || len(meta) != pinMetaLen || !keyOK || len(wrapped) != pinKeyLen {
		return t, errors.New("nothing wrapped")
	}
	if pinClashes(kn, d, index, pn.legacyApp || pn.legacyWipe) {
		return t, errPinCollision
	}
	out, err := pinWriteEntry(up, kn, key, index, meta, wrapped)
	if err != nil {
		return t, err
	}
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

// a keystore stand-in for the calls below: x in, m out, nil for none
type pinMacFn func(x []byte) []byte

// a whole check in one go, the keystore asked once in the middle. nil for
// none, as on a phone with no key yet
func pinCheckKS(pin []byte, t pinTable, old pinLegacy, ks pinMacFn, key *pinKeyInfo) (pinResult, error) {
	h, x, err := pinBegin(pin, t, old)
	if err != nil {
		return pinResult{}, err
	}
	var m []byte
	if ks != nil {
		m = ks(x)
	}
	zero(x)
	p, err := pinTakeFor(h, t)
	if err != nil {
		return pinResult{}, err
	}
	defer zero(p.s)
	return pinFinish(p, m, t, old, key)
}

func pinCheck(pin []byte, t pinTable, old pinLegacy) (pinResult, error) {
	return pinCheckKS(pin, t, old, nil, nil)
}

func pinSetupKS(pin []byte, t pinTable, old pinLegacy, ks pinMacFn, key *pinKeyInfo, index, kind int, container, wrapPlain []byte) (pinTable, error) {
	h, x, err := pinBegin(pin, t, old)
	if err != nil {
		return t, err
	}
	var m []byte
	if ks != nil {
		m = ks(x)
	}
	zero(x)
	p, err := pinTakeFor(h, t)
	if err != nil {
		return t, err
	}
	defer zero(p.s)
	return pinSetupFinish(p, m, t, key, index, kind, container, wrapPlain)
}

func pinSetup(pin []byte, t pinTable, old pinLegacy, index, kind int, container, wrapPlain []byte) (pinTable, error) {
	return pinSetupKS(pin, t, old, nil, nil, index, kind, container, wrapPlain)
}

func pinRewrapKS(oldPin, newPin []byte, t pinTable, old pinLegacy, ks pinMacFn, key *pinKeyInfo, index int) (pinTable, error) {
	ho, xo, err := pinBegin(oldPin, t, old)
	if err != nil {
		return t, err
	}
	hn, xn, err := pinBegin(newPin, t, old)
	if err != nil {
		pinDrop(ho)
		return t, err
	}
	var mo, mn []byte
	if ks != nil {
		mo, mn = ks(xo), ks(xn)
	}
	zero(xo)
	zero(xn)
	po, err := pinTakeFor(ho, t)
	if err != nil {
		pinDrop(hn)
		return t, err
	}
	defer zero(po.s)
	pn, err := pinTakeFor(hn, t)
	if err != nil {
		return t, err
	}
	defer zero(pn.s)
	return pinRewrapFinish(po, mo, pn, mn, t, key, index)
}

func pinRewrap(oldPin, newPin []byte, t pinTable, old pinLegacy, index int) (pinTable, error) {
	return pinRewrapKS(oldPin, newPin, t, old, nil, nil, index)
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
