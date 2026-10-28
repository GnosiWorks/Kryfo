// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the top-up. a send counts once any relay takes it, so a wrap one of our
// stores missed, down or turning it away at the time, would be on the other
// alone: a reader that only reads that one store, as every version before
// the second store does, would never get it. so the signed wrap waits here
// and is offered again once the store answers. the id is the same, so a
// store that has it already says so and nothing is stored twice. the stores
// never copy from each other: a feed of every wrap between the two boxes is
// what the relays refuse to give anyone.
//
// up to 14 days, the relays' own retention, and a cap on count and bytes.
// on disk in the data dir, so a restart does not lose it; the app's wipe
// takes it with everything else.

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"fiatjaf.com/nostr"
)

// a wrap older than this is gone from every relay anyway
const topupMaxAge = 14 * 24 * time.Hour

// the most the queue keeps, oldest out first. vars for the tests
var (
	topupMaxItems = 2000
	topupMaxBytes = 50 << 20
)

type topupItem struct {
	Store string      `json:"s"`
	Lane  string      `json:"l"`
	Ev    nostr.Event `json:"e"`
}

var (
	topupMu      sync.Mutex
	topupQueue   []topupItem
	topupLoaded  string // the data dir the queue was read from
	topupRunning = map[string]bool{}
	// a flush that stopped short waits this long before the next answer
	// starts another: every runner's answer would otherwise start one
	topupAfter = map[string]time.Time{}
)

// a var for the tests
var topupRetry = 30 * time.Second

func topupFile() string {
	dir := savedDataDir()
	if dir == "" {
		return ""
	}
	return dir + "/nostr_topup"
}

// the queue as the file has it, once per data dir. topupMu must be held
func topupLoadLocked() {
	dir := savedDataDir()
	if dir == topupLoaded {
		return
	}
	topupLoaded = dir
	topupQueue = nil
	p := topupFile()
	if p == "" {
		return
	}
	b, err := os.ReadFile(p)
	if err != nil {
		return
	}
	sc := bufio.NewScanner(bytes.NewReader(b))
	sc.Buffer(make([]byte, 0, 64<<10), 1<<20)
	for sc.Scan() {
		var it topupItem
		if json.Unmarshal(sc.Bytes(), &it) == nil && it.Store != "" && it.Ev.ID != (nostr.ID{}) {
			topupQueue = append(topupQueue, it)
		}
	}
	topupPruneLocked(time.Now())
}

func topupSize(it topupItem) int { return len(it.Ev.Content) + 512 }

// drops what aged out and what is past the caps, oldest first
func topupPruneLocked(now time.Time) {
	oldest := nostr.Timestamp(now.Add(-topupMaxAge).Unix())
	kept := topupQueue[:0]
	for _, it := range topupQueue {
		if it.Ev.CreatedAt > oldest {
			kept = append(kept, it)
		}
	}
	clear(topupQueue[len(kept):])
	topupQueue = kept
	bytes := 0
	for _, it := range topupQueue {
		bytes += topupSize(it)
	}
	for len(topupQueue) > 0 && (len(topupQueue) > topupMaxItems || bytes > topupMaxBytes) {
		bytes -= topupSize(topupQueue[0])
		topupQueue[0] = topupItem{}
		topupQueue = topupQueue[1:]
	}
}

// the file follows the queue. topupMu must be held
func topupWriteLocked() {
	p := topupFile()
	if p == "" || engineHeld.Load() {
		return
	}
	if len(topupQueue) == 0 {
		os.Remove(p)
		return
	}
	var buf bytes.Buffer
	for _, it := range topupQueue {
		b, err := json.Marshal(it)
		if err != nil {
			continue
		}
		buf.Write(b)
		buf.WriteByte('\n')
	}
	tmp := p + ".tmp"
	if os.WriteFile(tmp, buf.Bytes(), 0600) == nil {
		os.Rename(tmp, p)
	}
}

// ev reached a relay but none of store st's entries: it waits for st
func topupAdd(st, lane string, ev nostr.Event) {
	if ev.CreatedAt <= nostr.Timestamp(time.Now().Add(-topupMaxAge).Unix()) {
		return
	}
	topupMu.Lock()
	defer topupMu.Unlock()
	topupLoadLocked()
	for _, it := range topupQueue {
		if it.Store == st && it.Ev.ID == ev.ID {
			return
		}
	}
	topupQueue = append(topupQueue, topupItem{Store: st, Lane: lane, Ev: ev})
	topupPruneLocked(time.Now())
	topupWriteLocked()
	log.Printf("nostr: a wrap waits for store %s, %d waiting", st, len(topupQueue))
}

// what waits for st, oldest first
func topupFor(st string) []topupItem {
	topupMu.Lock()
	defer topupMu.Unlock()
	topupLoadLocked()
	topupPruneLocked(time.Now())
	var out []topupItem
	for _, it := range topupQueue {
		if it.Store == st {
			out = append(out, it)
		}
	}
	return out
}

func topupDone(st string, id nostr.ID) {
	topupMu.Lock()
	defer topupMu.Unlock()
	kept := topupQueue[:0]
	for _, it := range topupQueue {
		if !(it.Store == st && it.Ev.ID == id) {
			kept = append(kept, it)
		}
	}
	clear(topupQueue[len(kept):])
	topupQueue = kept
	topupWriteLocked()
}

// u answered: what waits for its store goes there now, one at a time, by
// one flush per store
func topupKick(u string) {
	nostrMu.Lock()
	urls := nostrRelays
	nostrMu.Unlock()
	st := storeOf(urls, u)
	if st == "" || savedDataDir() == "" {
		return
	}
	topupMu.Lock()
	topupLoadLocked()
	waiting := false
	for _, it := range topupQueue {
		if it.Store == st {
			waiting = true
			break
		}
	}
	if !waiting || topupRunning[st] || time.Now().Before(topupAfter[st]) {
		topupMu.Unlock()
		return
	}
	topupRunning[st] = true
	topupMu.Unlock()
	go func() {
		defer func() {
			topupMu.Lock()
			delete(topupRunning, st)
			topupMu.Unlock()
		}()
		if !topupFlush(st, u) {
			topupMu.Lock()
			topupAfter[st] = time.Now().Add(topupRetry)
			topupMu.Unlock()
		}
	}()
}

// offers store st everything waiting for it through its entry u. stops at
// the first failure: the store went again, or is busy, and an answer after
// topupRetry starts over. true when nothing is left
func topupFlush(st, u string) bool {
	items := topupFor(st)
	if len(items) == 0 {
		return true
	}
	sent := 0
	for _, it := range items {
		routeC := routeEnded()
		if !relayListedNow(u) || routeGone(routeC) {
			return false
		}
		client, err := relayClientFor(it.Lane, u)
		if err != nil {
			return false
		}
		ctx, cancel := onRoute(context.Background(), routeC)
		pctx, pcancel := context.WithTimeout(ctx, publishWait)
		err = publishTo(pctx, it.Lane, u, client, it.Ev)
		pcancel()
		cancel()
		if relayHasIt(err) {
			err = nil
		}
		switch {
		case err == nil:
			sent++
			topupDone(st, it.Ev.ID)
		case topupRefused(err):
			// turned away for good, not for now: it would only be asked again
			log.Printf("nostr: store %s turned a waiting wrap away: %v", st, err)
			topupDone(st, it.Ev.ID)
		default:
			log.Printf("nostr: store %s took %d waiting wraps, then: %v", st, sent, err)
			return false
		}
	}
	if sent > 0 {
		log.Printf("nostr: store %s took %d waiting wraps", st, sent)
	}
	return true
}

// the relay's own no that holds for good: a wrap it will never keep. busy,
// full and an http status at the upgrade are for now
func topupRefused(err error) bool {
	e := err.Error()
	return strings.HasPrefix(e, "msg: ") && (strings.Contains(e, "blocked:") || strings.Contains(e, "invalid:"))
}

// whether the list set now names u
func relayListedNow(u string) bool {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	return !nostrRelaysStale && containsStr(nostrRelays, u)
}

// for the tests: the queue as a new process would find it
func topupForget() {
	topupMu.Lock()
	topupQueue, topupLoaded = nil, ""
	clear(topupRunning)
	clear(topupAfter)
	topupMu.Unlock()
}
