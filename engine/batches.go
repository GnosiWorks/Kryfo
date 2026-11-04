// SPDX-License-Identifier: GPL-3.0-or-later
package main

// an identity's addresses reach each relay in batches of at most batchMax:
// a socket and a tor circuit per batch and relay. a relay sees the
// addresses of one batch together and of the others only their timing.
//
// a batch never changes. an address keeps the place it was first listened
// on for good: one let go of (a delete, a block aged out, a request
// dropped) keeps it, so it comes back to the same batch, and a new address
// takes a seat never given before. moving addresses would hand a relay the
// union of every batch each was in, so nothing moves while the addresses
// stay the same (until 0.7).
//
// the book is one file, sealed under a key from the main identity and
// padded, naming each address by a keyed hash. the places of chats hidden
// after they were batched go in a part of it that only the vault's key
// opens. with no vault, or the vault shut since this process began, that
// part is random bytes of the same size, so the file reads the same with a
// vault and without.

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"

	"golang.org/x/crypto/chacha20poly1305"
)

import "C"

const batchMax = 8

// the book's file in the engine's folder
const bookName = "nostr_book"

// the vault's part is padded to whole steps of this, so a few hidden
// places and none take the same room
const bookVaultStep = 4 << 10

type batchPlace struct {
	set string
	n   int
}

// a set's newest batch and the seats given in it
type batchTop struct {
	n, given int
}

type batchBook struct {
	dir string
	// the file's key and the ids' key, from the main identity. nil with no
	// identity: the book then lives in memory only
	key, idKey []byte
	// the everyday part, by keyed hash
	every map[string]batchPlace
	top   map[string]batchTop
	// the vault's part as the file holds it, kept as it is while the vault
	// is shut
	vaultSealed []byte
	// while the vault's key is at hand: its part, opened
	vaultKey []byte
	vault    map[string]batchPlace
	// ids heard hidden while the vault's key was not at hand: their places
	// go to its part once it is
	hide map[string]bool
}

var (
	batchMu sync.Mutex
	batches *batchBook
)

func bookKeys() (key, idKey []byte) {
	me, err := identityOf(mainIdent)
	if err != nil {
		return nil, nil
	}
	return nostrHkdf(me.priv[:], nil, []byte("kryfo batch book v1"), 32),
		nostrHkdf(me.priv[:], nil, []byte("kryfo batch book id v1"), 32)
}

// the book for the data dir and identity now, read once. under batchMu
func batchBookNow() *batchBook {
	dir := savedDataDir()
	key, idKey := bookKeys()
	if b := batches; b != nil && b.dir == dir && bytes.Equal(b.key, key) {
		return b
	}
	b := &batchBook{dir: dir, key: key, idKey: idKey, every: map[string]batchPlace{}, top: map[string]batchTop{}, hide: map[string]bool{}}
	if dir != "" {
		// the files of a version that kept a file per address
		olds, _ := filepath.Glob(filepath.Join(dir, "nostr_batch_*"))
		for _, f := range olds {
			os.Remove(f)
		}
		if key != nil {
			if raw, err := os.ReadFile(filepath.Join(dir, bookName)); err == nil {
				b.read(raw)
			}
		}
	}
	batches = b
	return b
}

// the book read again at the next use: a restore landed another, or the
// identity changed
func batchBookReset() {
	batchMu.Lock()
	batches = nil
	batchMu.Unlock()
}

func (b *batchBook) id(rcvPk string) string {
	if b.idKey == nil {
		return "a:" + rcvPk
	}
	m := hmac.New(sha256.New, b.idKey)
	m.Write([]byte(rcvPk))
	return hex.EncodeToString(m.Sum(nil))[:32]
}

type bookFile struct {
	// id -> [set, n]
	E map[string][2]any `json:"e"`
	// set -> [newest batch, seats given in it]
	T map[string][2]int `json:"t"`
	// the vault's part, sealed
	V []byte `json:"v"`
}

type bookVaultFile struct {
	E map[string][2]any `json:"e"`
}

func placesOf(m map[string][2]any) map[string]batchPlace {
	out := map[string]batchPlace{}
	for id, p := range m {
		set, ok1 := p[0].(string)
		n, ok2 := p[1].(float64)
		if !ok1 || !ok2 || set == "" || n < 0 {
			continue
		}
		out[id] = batchPlace{set, int(n)}
	}
	return out
}

func placesJSON(m map[string]batchPlace) map[string][2]any {
	out := make(map[string][2]any, len(m))
	for id, p := range m {
		out[id] = [2]any{p.set, p.n}
	}
	return out
}

func bookSeal(key, plain []byte) []byte {
	a, err := chacha20poly1305.NewX(key)
	if err != nil {
		return nil
	}
	nonce := randBytes(a.NonceSize())
	return append(nonce, a.Seal(nil, nonce, plain, nil)...)
}

func bookOpen(key, b []byte) ([]byte, bool) {
	a, err := chacha20poly1305.NewX(key)
	if err != nil || len(b) < a.NonceSize()+a.Overhead() {
		return nil, false
	}
	out, err := a.Open(nil, b[:a.NonceSize()], b[a.NonceSize():], nil)
	return out, err == nil
}

// whole steps, so the size says no more than how many steps
func bookVaultPad(plain []byte) []byte {
	n := (vaultPadHead + len(plain) + bookVaultStep - 1) / bookVaultStep * bookVaultStep
	out := make([]byte, n)
	copy(out, vaultPadMagic)
	out[4], out[5], out[6], out[7] = byte(len(plain)>>24), byte(len(plain)>>16), byte(len(plain)>>8), byte(len(plain))
	copy(out[vaultPadHead:], plain)
	return out
}

func bookVaultUnpad(b []byte) ([]byte, bool) {
	if len(b) < vaultPadHead || !bytes.Equal(b[:4], vaultPadMagic) {
		return nil, false
	}
	n := int(b[4])<<24 | int(b[5])<<16 | int(b[6])<<8 | int(b[7])
	if n < 0 || n > len(b)-vaultPadHead {
		return nil, false
	}
	return b[vaultPadHead : vaultPadHead+n], true
}

// the size a sealed vault part of one step takes, for the filler
func bookVaultFiller() []byte {
	return randBytes(chacha20poly1305.NonceSizeX + bookVaultStep + chacha20poly1305.Overhead)
}

func (b *batchBook) read(raw []byte) {
	sealed, err := base64.RawStdEncoding.DecodeString(strings.TrimSpace(string(raw)))
	if err != nil {
		return
	}
	plain, ok := bookOpen(b.key, sealed)
	if !ok {
		return
	}
	plain, err = vaultUnpad(plain)
	if err != nil {
		return
	}
	var f bookFile
	if json.Unmarshal(plain, &f) != nil {
		return
	}
	b.every = placesOf(f.E)
	for set, t := range f.T {
		if set != "" && t[0] >= 0 && t[1] >= 0 && t[1] <= batchMax {
			b.top[set] = batchTop{t[0], t[1]}
		}
	}
	b.vaultSealed = f.V
}

// the book on disk, whole or not at all. never while the engine is held
func (b *batchBook) write() {
	if b.dir == "" || b.key == nil || engineHeld.Load() {
		return
	}
	if b.vaultKey != nil {
		plain, _ := json.Marshal(bookVaultFile{E: placesJSON(b.vault)})
		if s := bookSeal(b.vaultKey, bookVaultPad(plain)); s != nil {
			b.vaultSealed = s
		}
	}
	if b.vaultSealed == nil {
		b.vaultSealed = bookVaultFiller()
	}
	t := make(map[string][2]int, len(b.top))
	for set, x := range b.top {
		t[set] = [2]int{x.n, x.given}
	}
	plain, err := json.Marshal(bookFile{E: placesJSON(b.every), T: t, V: b.vaultSealed})
	if err != nil {
		return
	}
	sealed := bookSeal(b.key, vaultPad(plain))
	if sealed == nil {
		return
	}
	path := filepath.Join(b.dir, bookName)
	tmp := path + ".tmp"
	if os.WriteFile(tmp, []byte(base64.RawStdEncoding.EncodeToString(sealed)+"\n"), 0600) == nil {
		os.Rename(tmp, path)
	}
}

// a seat never given before: in the newest batch while it has one, else in
// a new batch
func (b *batchBook) seat(set string) int {
	t, used := b.top[set]
	switch {
	case !used:
		t = batchTop{0, 1}
	case t.given < batchMax:
		t.given++
	default:
		t = batchTop{t.n + 1, 1}
	}
	b.top[set] = t
	return t.n
}

// the batch of rcvPk in set, given it now if it has none. a place in the
// vault's part comes back to the everyday one: the chat is out of the vault
func batchOf(set, rcvPk string) int {
	batchMu.Lock()
	defer batchMu.Unlock()
	b := batchBookNow()
	id := b.id(rcvPk)
	delete(b.hide, id)
	if p, ok := b.every[id]; ok && p.set == set {
		return p.n
	}
	if p, ok := b.vault[id]; ok && p.set == set {
		delete(b.vault, id)
		b.every[id] = p
		b.write()
		return p.n
	}
	p := batchPlace{set, b.seat(set)}
	b.every[id] = p
	b.write()
	return p.n
}

// rcvPk is listened on as a hidden chat's: a place it has goes into the
// vault's part, or there once the vault's key is at hand
func batchHide(rcvPk string) {
	batchMu.Lock()
	defer batchMu.Unlock()
	b := batchBookNow()
	id := b.id(rcvPk)
	p, ok := b.every[id]
	if !ok {
		return
	}
	if b.vaultKey == nil {
		b.hide[id] = true
		return
	}
	delete(b.every, id)
	b.vault[id] = p
	b.write()
}

// the vault's key, as the open vault hands it, or none as it shuts. its
// part opens with it, and what was heard hidden meanwhile goes in. a part
// that does not open (none yet, another vault's) starts empty
func batchVault(secret []byte) {
	batchMu.Lock()
	defer batchMu.Unlock()
	b := batchBookNow()
	if len(secret) == 0 {
		clear(b.vaultKey)
		b.vaultKey, b.vault = nil, nil
		return
	}
	key := nostrHkdf(secret, nil, []byte("kryfo batch book vault v1"), 32)
	if b.vaultKey != nil && bytes.Equal(b.vaultKey, key) {
		return
	}
	b.vaultKey, b.vault = key, map[string]batchPlace{}
	if plain, ok := bookOpen(key, b.vaultSealed); ok {
		if plain, ok = bookVaultUnpad(plain); ok {
			var f bookVaultFile
			if json.Unmarshal(plain, &f) == nil {
				b.vault = placesOf(f.E)
			}
		}
	}
	moved := false
	for id := range b.hide {
		if p, ok := b.every[id]; ok {
			delete(b.every, id)
			b.vault[id] = p
			moved = true
		}
	}
	clear(b.hide)
	if moved {
		b.write()
	}
}

// the open vault's key ("" as it shuts). nothing of it is kept on disk
//
//export HaloNostrBookVault
func HaloNostrBookVault(cSecret *C.char) *C.char {
	s := goSecret(cSecret)
	defer clear(s)
	batchVault(s)
	return C.CString("ok")
}

// the batches of an identity's contact addresses, and of its device pairs'
// opener addresses, which are apart from them (address_device.go)
func contactSet(ident int) string { return "i" + strconv.Itoa(ident) }
func openerSet(ident int) string  { return "o" + strconv.Itoa(ident) }

// a batch's lane: its own socks name, so its own circuits
func batchLane(set string, n int) string {
	if strings.HasPrefix(set, "o") {
		return opnLane(identOfSet(set)) + ":" + strconv.Itoa(n)
	}
	return laneEveryday + ":" + set[1:] + ":" + strconv.Itoa(n)
}

func identOfSet(set string) int {
	n, _ := strconv.Atoi(set[1:])
	return n
}
