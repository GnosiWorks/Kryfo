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
// padded, naming each address by a keyed hash. a chat hidden after it was
// batched keeps its entry: it reads like any address let go of, and every
// seat given has one, so the book says nothing of a vault. a part only the
// vault's key opened would not: the seats given less the entries left
// would count the hidden chats, and an entry gone would name one.

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

const batchMax = 8

// the book's file in the engine's folder
const bookName = "nostr_book"

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
	// the places, by keyed hash
	every map[string]batchPlace
	top   map[string]batchTop
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
	b := &batchBook{dir: dir, key: key, idKey: idKey, every: map[string]batchPlace{}, top: map[string]batchTop{}}
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
}

// the book on disk, whole or not at all. never while the engine is held
func (b *batchBook) write() {
	if b.dir == "" || b.key == nil || engineHeld.Load() {
		return
	}
	t := make(map[string][2]int, len(b.top))
	for set, x := range b.top {
		t[set] = [2]int{x.n, x.given}
	}
	plain, err := json.Marshal(bookFile{E: placesJSON(b.every), T: t})
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

// the batch of rcvPk in set, given it now if it has none
func batchOf(set, rcvPk string) int {
	batchMu.Lock()
	defer batchMu.Unlock()
	b := batchBookNow()
	id := b.id(rcvPk)
	if p, ok := b.every[id]; ok && p.set == set {
		return p.n
	}
	p := batchPlace{set, b.seat(set)}
	b.every[id] = p
	b.write()
	return p.n
}

// the batch of rcvPk in set, if it has one. none is given
func batchFind(set, rcvPk string) (int, bool) {
	batchMu.Lock()
	defer batchMu.Unlock()
	b := batchBookNow()
	if p, ok := b.every[b.id(rcvPk)]; ok && p.set == set {
		return p.n, true
	}
	return 0, false
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
