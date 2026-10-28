// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the top-up, on the fast route only. a send counts once any relay takes it,
// so a wrap one of our stores missed, down or turning it away at the time,
// would be on the other alone: a reader of that one store only, as every
// version before the second store is, would never get it. so it waits here
// and goes to the store once that answers: the same wrap within a few
// minutes, after that a fresh wrap around the same seal (rewrap.go), stamped
// now, so a reader whose window moved on still asks for it. the stores never
// copy from each other: a feed of every wrap between the two boxes is what
// the relays refuse to give anyone. the private route has none of this.
//
// up to fourteen days or the wrap's own expiration, whichever is first, and
// a cap on count and bytes. on disk, sealed under a key from the identity, as
// a log of added and done records that is compacted now and then; written by
// one goroutine of its own, so nothing that holds the queue's lock touches
// the disk. the app's wipe and a restore take the file with everything else.

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"log"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"fiatjaf.com/nostr"
	"golang.org/x/crypto/chacha20poly1305"
	"golang.org/x/crypto/hkdf"
)

// a wrap older than this is gone from every relay anyway
const topupMaxAge = 14 * 24 * time.Hour

// within this of the send the wrap goes as it was, after it a fresh one
const topupFresh = 5 * time.Minute

// tries per wrap before it is given up on
const topupMaxTries = 8

// the most the queue keeps, oldest out first. vars for the tests
var (
	topupMaxItems = 2000
	topupMaxBytes = 50 << 20
)

type topupItem struct {
	Store string      `json:"s"`
	Lane  string      `json:"l"`
	Ev    nostr.Event `json:"e"`
	// when it was queued, unix seconds
	At int64 `json:"a"`
	// how to make it again, when the send made it here
	Kept *keptSeal `json:"k,omitempty"`
	// failed tries, this process
	tries int
}

// one line of the log: an item added, or one done
type topupRec struct {
	Add  *topupItem `json:"a,omitempty"`
	Done string     `json:"d,omitempty"` // store and id: "1 <hex>"
}

var (
	topupMu      sync.Mutex
	topupQueue   []topupItem
	topupLoaded  string // the data dir the queue was read from
	topupRunning = map[string]bool{}
	// a flush that stopped short waits this long before the next answer
	// starts another: every runner's answer would otherwise start one
	topupAfter = map[string]time.Time{}
	// records not yet written, and how many lines the file holds
	topupPend  []topupRec
	topupLines int
)

// a var for the tests
var topupRetry = 30 * time.Second

// the loader and the writer, one at a time, never under topupMu
var topupFileMu sync.Mutex

func topupFile() string {
	dir := savedDataDir()
	if dir == "" {
		return ""
	}
	return dir + "/nostr_topup"
}

// the file's key, from the identity: nil while there is none
func topupKey() []byte {
	me, err := myXid()
	if err != nil {
		return nil
	}
	k := make([]byte, 32)
	r := hkdf.New(sha256.New, me.priv[:], nil, []byte("kryfo topup file v1"))
	if _, err := r.Read(k); err != nil {
		return nil
	}
	return k
}

func topupSeal(key, plain []byte) string {
	a, err := chacha20poly1305.NewX(key)
	if err != nil {
		return ""
	}
	nonce := randBytes(a.NonceSize())
	return base64.RawStdEncoding.EncodeToString(append(nonce, a.Seal(nil, nonce, plain, nil)...))
}

func topupOpen(key []byte, line string) ([]byte, bool) {
	b, err := base64.RawStdEncoding.DecodeString(line)
	if err != nil {
		return nil, false
	}
	a, err := chacha20poly1305.NewX(key)
	if err != nil || len(b) < a.NonceSize()+a.Overhead() {
		return nil, false
	}
	out, err := a.Open(nil, b[:a.NonceSize()], b[a.NonceSize():], nil)
	return out, err == nil
}

// the queue as the file has it, once per data dir. the file is read with
// topupFileMu alone; topupMu is taken only to put what it held in place
func topupEnsureLoaded() {
	dir := savedDataDir()
	topupMu.Lock()
	done := topupLoaded == dir
	topupMu.Unlock()
	if done {
		return
	}
	topupFileMu.Lock()
	defer topupFileMu.Unlock()
	var items []topupItem
	lines := 0
	if p, key := topupFile(), topupKey(); p != "" && key != nil {
		if b, err := os.ReadFile(p); err == nil {
			items, lines = topupReplay(key, b)
		}
	} else if p != "" {
		// no identity yet: read it once there is one
		return
	}
	topupMu.Lock()
	defer topupMu.Unlock()
	if topupLoaded == dir {
		return
	}
	topupLoaded = dir
	// what this process queued before the file was read goes after it
	have := map[string]bool{}
	for _, it := range items {
		have[it.Store+" "+it.Ev.ID.Hex()] = true
	}
	for _, it := range topupQueue {
		if !have[it.Store+" "+it.Ev.ID.Hex()] {
			items = append(items, it)
		}
	}
	topupQueue = items
	topupLines = lines
	topupPruneLocked(time.Now())
}

// the log replayed: what was added and not yet done
func topupReplay(key, b []byte) ([]topupItem, int) {
	var items []topupItem
	at := map[string]int{}
	lines := 0
	sc := bufio.NewScanner(bytes.NewReader(b))
	sc.Buffer(make([]byte, 0, 64<<10), 2<<20)
	for sc.Scan() {
		lines++
		plain, ok := topupOpen(key, sc.Text())
		if !ok {
			continue
		}
		var r topupRec
		if json.Unmarshal(plain, &r) != nil {
			continue
		}
		switch {
		case r.Add != nil && r.Add.Store != "" && r.Add.Ev.ID != (nostr.ID{}):
			k := r.Add.Store + " " + r.Add.Ev.ID.Hex()
			if _, dup := at[k]; !dup {
				at[k] = len(items)
				items = append(items, *r.Add)
			}
		case r.Done != "":
			if i, ok := at[r.Done]; ok {
				items[i].Store = ""
			}
		}
	}
	kept := items[:0]
	for _, it := range items {
		if it.Store != "" {
			kept = append(kept, it)
		}
	}
	return kept, lines
}

func topupSize(it topupItem) int {
	n := len(it.Ev.Content) + 512
	if it.Kept != nil {
		n += it.Kept.size()
	}
	return n
}

// when an item stops being worth sending: fourteen days from the send, or
// the wrap's own expiration if that comes first
func topupEnd(it topupItem) time.Time {
	end := time.Unix(it.At, 0).Add(topupMaxAge)
	for _, tag := range it.Ev.Tags {
		if len(tag) >= 2 && tag[0] == "expiration" {
			if v, err := strconv.ParseInt(tag[1], 10, 64); err == nil && time.Unix(v, 0).Before(end) {
				end = time.Unix(v, 0)
			}
		}
	}
	return end
}

// drops what aged out and what is past the caps, oldest first. topupMu
func topupPruneLocked(now time.Time) {
	kept := topupQueue[:0]
	for _, it := range topupQueue {
		if now.Before(topupEnd(it)) {
			kept = append(kept, it)
		} else {
			topupPend = append(topupPend, topupRec{Done: it.Store + " " + it.Ev.ID.Hex()})
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
		topupPend = append(topupPend, topupRec{Done: topupQueue[0].Store + " " + topupQueue[0].Ev.ID.Hex()})
		topupQueue[0] = topupItem{}
		topupQueue = topupQueue[1:]
	}
}

// the records waiting go to the file, by one goroutine at a time
func topupWriteSoon() {
	go topupWrite()
}

func topupWrite() {
	topupFileMu.Lock()
	defer topupFileMu.Unlock()
	p, key := topupFile(), topupKey()
	// nothing is let go of while the wipe holds the engine, or before there
	// is a key to seal it with
	if p == "" || key == nil || engineHeld.Load() || fileGone(p) {
		return
	}
	topupMu.Lock()
	recs := topupPend
	topupPend = nil
	compact := topupLines > 2*len(topupQueue)+200
	var live []topupItem
	if compact {
		live = append(live, topupQueue...)
	}
	topupMu.Unlock()
	line := func(r topupRec) string {
		b, err := json.Marshal(r)
		if err != nil {
			return ""
		}
		return topupSeal(key, b)
	}
	if compact {
		var buf bytes.Buffer
		for i := range live {
			if l := line(topupRec{Add: &live[i]}); l != "" {
				buf.WriteString(l)
				buf.WriteByte('\n')
			}
		}
		tmp := p + ".tmp"
		if len(live) == 0 {
			os.Remove(p)
		} else if os.WriteFile(tmp, buf.Bytes(), 0600) == nil {
			os.Rename(tmp, p)
		}
		topupMu.Lock()
		topupLines = len(live)
		topupMu.Unlock()
		return
	}
	if len(recs) == 0 {
		return
	}
	f, err := os.OpenFile(p, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	n := 0
	for _, r := range recs {
		if l := line(r); l != "" {
			f.WriteString(l + "\n")
			n++
		}
	}
	topupMu.Lock()
	topupLines += n
	topupMu.Unlock()
}

// ev reached a relay but none of store st's entries: it waits for st. only
// on fast, and never a pair code's: that lives two minutes
func topupAdd(st, lane string, ev nostr.Event) {
	if currentMode() != modeBalanced || strings.HasPrefix(lane, "pair:") {
		return
	}
	topupEnsureLoaded()
	it := topupItem{Store: st, Lane: lane, Ev: ev, At: time.Now().Unix()}
	if k, ok := keptSealOf(ev.ID.Hex()); ok {
		it.Kept = &k
		// the queue has its own copy now
		forgetSeal(ev.ID.Hex())
	}
	if !time.Now().Before(topupEnd(it)) {
		return
	}
	topupMu.Lock()
	for _, have := range topupQueue {
		if have.Store == st && have.Ev.ID == ev.ID {
			topupMu.Unlock()
			return
		}
	}
	topupQueue = append(topupQueue, it)
	topupPend = append(topupPend, topupRec{Add: &it})
	topupPruneLocked(time.Now())
	n := len(topupQueue)
	topupMu.Unlock()
	topupWriteSoon()
	log.Printf("nostr: a wrap waits for store %s, %d waiting", st, n)
}

// what waits for st, oldest first
func topupFor(st string) []topupItem {
	topupEnsureLoaded()
	topupMu.Lock()
	defer topupMu.Unlock()
	topupPruneLocked(time.Now())
	var out []topupItem
	for _, it := range topupQueue {
		if it.Store == st {
			out = append(out, it)
		}
	}
	return out
}

// the item is out of the queue: sent, turned away, or given up on
func topupDone(st string, id nostr.ID) {
	topupMu.Lock()
	kept := topupQueue[:0]
	for _, it := range topupQueue {
		if !(it.Store == st && it.Ev.ID == id) {
			kept = append(kept, it)
		}
	}
	clear(topupQueue[len(kept):])
	topupQueue = kept
	topupPend = append(topupPend, topupRec{Done: st + " " + id.Hex()})
	topupMu.Unlock()
	topupWriteSoon()
}

// one more failed try at an item. false once it is given up on
func topupTried(st string, id nostr.ID) bool {
	topupMu.Lock()
	for i := range topupQueue {
		if topupQueue[i].Store == st && topupQueue[i].Ev.ID == id {
			topupQueue[i].tries++
			if topupQueue[i].tries < topupMaxTries {
				topupMu.Unlock()
				return true
			}
		}
	}
	topupMu.Unlock()
	topupDone(st, id)
	return false
}

// everything waiting that drop says goes: a contact deleted, a room ended
func topupPurge(drop func(topupItem) bool) {
	topupEnsureLoaded()
	topupMu.Lock()
	kept := topupQueue[:0]
	gone := 0
	for _, it := range topupQueue {
		if drop(it) {
			topupPend = append(topupPend, topupRec{Done: it.Store + " " + it.Ev.ID.Hex()})
			gone++
			continue
		}
		kept = append(kept, it)
	}
	clear(topupQueue[len(kept):])
	topupQueue = kept
	topupMu.Unlock()
	if gone > 0 {
		topupWriteSoon()
	}
}

// what waits for an address goes
func topupPurgeAddr(addr string) {
	topupPurge(func(it topupItem) bool { return wrapAddr(it.Ev) == addr })
}

// what a lane sent and still waits goes
func topupPurgeLane(lane string) {
	topupPurge(func(it topupItem) bool { return it.Lane == lane })
}

// u answered: what waits for its store goes there now, one flush per store.
// nothing here touches the disk: an answer is never held up by the queue
func topupKick(u string) {
	if currentMode() != modeBalanced || savedDataDir() == "" {
		return
	}
	nostrMu.Lock()
	urls := nostrRelays
	nostrMu.Unlock()
	st := storeOf(urls, u)
	if st == "" {
		return
	}
	topupMu.Lock()
	loaded := topupLoaded == savedDataDir()
	waiting := !loaded
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
		ok := topupFlush(st, u)
		topupMu.Lock()
		delete(topupRunning, st)
		if !ok {
			topupAfter[st] = time.Now().Add(topupRetry)
		}
		topupMu.Unlock()
	}()
}

// offers store st everything waiting for it through its entry u. a relay's
// own no drops a wrap, unless it only asks to slow down; a socket or circuit
// failing stops the flush, and an answer after topupRetry starts over. true
// when nothing is left
func topupFlush(st, u string) bool {
	items := topupFor(st)
	sent := 0
	for _, it := range items {
		routeC := routeEnded()
		if currentMode() != modeBalanced || !relayListedNow(u) || routeGone(routeC) {
			return false
		}
		ev := it.Ev
		if time.Since(time.Unix(it.At, 0)) > topupFresh {
			// late: stamped from now, or a reader that moved on never asks
			if it.Kept == nil {
				topupDone(st, it.Ev.ID)
				continue
			}
			fresh, err := rewrap(*it.Kept)
			if err != nil {
				topupDone(st, it.Ev.ID)
				continue
			}
			ev = fresh
		}
		client, err := relayClientFor(it.Lane, u)
		if err != nil {
			return false
		}
		ctx, cancel := onRoute(context.Background(), routeC)
		pctx, pcancel := context.WithTimeout(ctx, publishWait)
		err = publishTo(pctx, it.Lane, u, client, ev)
		pcancel()
		cancel()
		if relayHasIt(err) {
			err = nil
		}
		switch {
		case err == nil:
			sent++
			topupDone(st, it.Ev.ID)
		case topupBusy(err):
			// the relay asks for later. slow down is only that, until the
			// wrap's own end; an error of the relay's counts as a try
			if strings.Contains(err.Error(), "error:") {
				topupTried(st, it.Ev.ID)
			}
			log.Printf("nostr: store %s took %d waiting wraps, then: %v", st, sent, err)
			return false
		case strings.HasPrefix(err.Error(), "msg: "):
			// the relay will not keep it: asking again changes nothing
			log.Printf("nostr: store %s turned a waiting wrap away: %v", st, err)
			topupDone(st, it.Ev.ID)
		default:
			// the way to it gone: later, and no try counted
			log.Printf("nostr: store %s took %d waiting wraps, then: %v", st, sent, err)
			return false
		}
	}
	if sent > 0 {
		log.Printf("nostr: store %s took %d waiting wraps", st, sent)
	}
	return true
}

// the relay's own answer that it is busy or full for now
func topupBusy(err error) bool {
	e := err.Error()
	return strings.HasPrefix(e, "msg: ") && (strings.Contains(e, "rate-limited") || strings.Contains(e, "error:"))
}

// whether the list set now names u
func relayListedNow(u string) bool {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	return !nostrRelaysStale && containsStr(nostrRelays, u)
}

// for the tests: the queue as a new process would find it
func topupForget() {
	topupFileMu.Lock()
	defer topupFileMu.Unlock()
	topupMu.Lock()
	topupQueue, topupLoaded, topupPend, topupLines = nil, "", nil, 0
	clear(topupRunning)
	clear(topupAfter)
	topupMu.Unlock()
}

// for the tests: every record written
func topupSync() { topupWrite() }
