// SPDX-License-Identifier: GPL-3.0-or-later
package main

// an identity's addresses reach each relay in batches of at most batchMax:
// a socket and a tor circuit per batch and relay. a relay sees the
// addresses of one batch together and of the others only their timing.
//
// a batch never changes. an address keeps the batch it was first listened
// on in until it is let go of, a new address joins the newest batch with
// room, and one let go of leaves a place that no other address moves into.
// moving addresses would hand a relay the union of every batch each was
// in, so nothing moves while the addresses stay the same (until 0.7).

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
)

const batchMax = 8

type batchPlace struct {
	set string
	n   int
}

type batchBook struct {
	dir string
	// by the address's first 16 hex, as its other files
	of   map[string]batchPlace
	size map[batchPlace]int
	// the highest batch each set has used, so a new one never takes the
	// number of one that emptied
	top map[string]int
}

var (
	batchMu sync.Mutex
	batches *batchBook
)

// the book for the data dir now, read from the address files once. under
// batchMu
func batchBookNow() *batchBook {
	dir := savedDataDir()
	if batches != nil && batches.dir == dir {
		return batches
	}
	b := &batchBook{dir: dir, of: map[string]batchPlace{}, size: map[batchPlace]int{}, top: map[string]int{}}
	if dir != "" {
		files, _ := filepath.Glob(filepath.Join(dir, "nostr_batch_*"))
		for _, f := range files {
			short := strings.TrimPrefix(filepath.Base(f), "nostr_batch_")
			if strings.HasSuffix(short, ".tmp") {
				continue
			}
			raw, err := os.ReadFile(f)
			if err != nil {
				continue
			}
			set, num, ok := strings.Cut(strings.TrimSpace(string(raw)), " ")
			n, err := strconv.Atoi(num)
			if !ok || err != nil || n < 0 || set == "" {
				continue
			}
			b.add(short, batchPlace{set, n})
		}
	}
	batches = b
	return b
}

func (b *batchBook) add(short string, p batchPlace) {
	b.of[short] = p
	b.size[p]++
	if t, ok := b.top[p.set]; !ok || p.n > t {
		b.top[p.set] = p.n
	}
}

func batchFile(dir, short string) string {
	return filepath.Join(dir, "nostr_batch_"+short)
}

func addrShort(rcvPk string) string {
	if len(rcvPk) > 16 {
		return rcvPk[:16]
	}
	return rcvPk
}

// the batch of rcvPk in set, given it now if it has none
func batchOf(set, rcvPk string) int {
	batchMu.Lock()
	defer batchMu.Unlock()
	b := batchBookNow()
	short := addrShort(rcvPk)
	if p, ok := b.of[short]; ok && p.set == set {
		return p.n
	} else if ok {
		b.size[p]--
	}
	top, used := b.top[set]
	n := top + 1
	if !used {
		n = 0
	}
	for i := top; used && i >= 0; i-- {
		if b.size[batchPlace{set, i}] < batchMax {
			n = i
			break
		}
	}
	p := batchPlace{set, n}
	b.add(short, p)
	if b.dir != "" && !engineHeld.Load() {
		path := batchFile(b.dir, short)
		goneFiles.Delete(path)
		tmp := path + ".tmp"
		if os.WriteFile(tmp, []byte(set+" "+strconv.Itoa(n)), 0600) == nil {
			os.Rename(tmp, path)
		}
	}
	return n
}

// an address let go of: its place stays empty
func batchForget(rcvPk string) {
	batchMu.Lock()
	defer batchMu.Unlock()
	b := batchBookNow()
	short := addrShort(rcvPk)
	if p, ok := b.of[short]; ok {
		delete(b.of, short)
		b.size[p]--
	}
	if b.dir != "" {
		path := batchFile(b.dir, short)
		goneFiles.Store(path, struct{}{})
		os.Remove(path)
		os.Remove(path + ".tmp")
	}
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
