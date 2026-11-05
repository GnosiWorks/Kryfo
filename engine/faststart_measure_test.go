// SPDX-License-Identifier: GPL-3.0-or-later
package main

// how long a start takes before chats can be used: the real tor, the app's
// private relay list, n contacts in their batches, one hidden chat and the
// first-contact address, listened on as the app does, before tor is up.
// it times tor's steps, the route proven (the pill's ready), the first
// relay socket up, the first batch and every batch caught up, and every
// socket up. slow and on the network, so only on request:
//
//	HALO_FASTSTART_MEASURE=1 FS_N=30 go test -run TestMeasureFastStart -v -timeout 20m .
//
// FS_N (30) contacts. FS_TORCACHE: a folder whose tor cache is used and
// kept, so a run starts warm as a computer does after its first start.
// FS_LOG: a file for the engine log. one run per process: tor survives one
// close only.

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"

	"golang.org/x/crypto/curve25519"
)

func TestMeasureFastStart(t *testing.T) {
	if os.Getenv("HALO_FASTSTART_MEASURE") == "" {
		t.Skip("HALO_FASTSTART_MEASURE not set")
	}
	n := 30
	if v, err := strconv.Atoi(os.Getenv("FS_N")); err == nil && v > 0 {
		n = v
	}
	var logTo io.Writer = io.Discard
	if p := os.Getenv("FS_LOG"); p != "" {
		if f, err := os.Create(p); err == nil {
			defer f.Close()
			logTo = f
		}
	}
	log.SetFlags(log.Ltime | log.Lmicroseconds)
	log.SetOutput(logTo)
	defer log.SetOutput(os.Stderr)
	transportMode.Store(modePrivate)
	// the app's turns and settle: TestMain and an init set the tests' own
	oldSpread, oldKick, oldSettle := subSpread, kickSpread, liveSettle
	subSpread, kickSpread, liveSettle = time.Minute, time.Minute, 3*time.Second
	defer func() { subSpread, kickSpread, liveSettle = oldSpread, oldKick, oldSettle }()

	dir, err := os.MkdirTemp("", "halo-faststart-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)
	cache := os.Getenv("FS_TORCACHE")
	cached := []string{"cached-certs", "cached-microdesc-consensus", "cached-microdescs", "cached-microdescs.new", "state"}
	if cache != "" {
		os.MkdirAll(filepath.Join(dir, "tor"), 0o700)
		for _, f := range cached {
			if b, err := os.ReadFile(filepath.Join(cache, f)); err == nil {
				os.WriteFile(filepath.Join(dir, "tor", f), b, 0o600)
			}
		}
	}

	// the identity and the relays before tor, as the app's boot has them
	var priv, pub [32]byte
	rand.Read(priv[:])
	curve25519.ScalarBaseMult(&pub, &priv)
	mu.Lock()
	setMainForTest(priv, pub)
	mu.Unlock()
	relays := strings.Split(measureRelays+",ws://cvwpee5zgbargtxd5wtbtnc6lkbgzxj5byfig3e53ic4t7su7r45n4yd.onion", ",")
	nostrMu.Lock()
	nostrRelays = relays
	nostrMu.Unlock()

	// FS_OLD=1: the start as before this branch, for a side by side run:
	// no wait for tor, no first batch
	old := os.Getenv("FS_OLD") == "1"
	if old {
		was := startGateMost
		startGateMost = 0
		defer func() { startGateMost = was }()
	}
	t0 := time.Now()
	startSteps.reset(t0)
	done := make(chan string, 1)
	go func() { done <- startListener(dir) }()
	// the app listens a moment after it starts the engine
	for savedDataDir() == "" {
		time.Sleep(10 * time.Millisecond)
	}
	batchBookReset()
	type addr struct {
		rcv   string
		batch string
	}
	var addrs []addr
	var tops []identPeer
	for i := 0; i < n+1; i++ {
		var pp, pk [32]byte
		rand.Read(pp[:])
		curve25519.ScalarBaseMult(&pk, &pp)
		hidden := i == n
		peerHex := hex.EncodeToString(pk[:])
		if r := nostrSubscribeAs(mainIdent, peerHex, false, hidden); r != "ok" {
			t.Fatal(r)
		}
		_, rcv, err := nip17RcvAddressAs(testMain(), pk)
		if err != nil {
			t.Fatal(err)
		}
		b := "hidden"
		if !hidden {
			b = batchLane(contactSet(mainIdent), batchOf(contactSet(mainIdent), rcv))
		}
		addrs = append(addrs, addr{rcv, b})
		if !hidden && i >= n-3 {
			tops = append([]identPeer{{I: mainIdent, X: peerHex}}, tops...)
		}
	}
	// the app tells its top chats before it listens; here the newest
	// three, before tor is up and any turn is taken
	if !old {
		noteFirstChats(tops)
	}
	firstLane := startFirstLane()
	if err := subscribeFirstContact(mainIdent, 0); err != nil {
		t.Logf("first contact: %v", err)
	}
	listenAt := time.Since(t0)

	pctAt := map[int]time.Duration{}
	var readyAt, routeAt, firstBatch, topsIn, allBatches, allSockets time.Duration
	batchesOf := map[string][]string{}
	for _, a := range addrs {
		if a.batch != "hidden" {
			batchesOf[a.batch] = append(batchesOf[a.batch], a.rcv)
		}
	}
	// an address is caught up once one relay finished its window
	caughtAt := func(rcv string) (time.Time, bool) {
		var best time.Time
		for _, u := range relays {
			if r, ok := catchupLast[catchupKey(u, rcv)]; ok && r.At.After(t0) && !r.Dropped {
				if best.IsZero() || r.At.Before(best) {
					best = r.At
				}
			}
		}
		return best, !best.IsZero()
	}
	relayUpAt := map[string]time.Duration{}
	// each batch's socket on relay.kryfo.app, when it first came up
	batchUp := map[string]time.Duration{}
	lastSocks, movedAt, cacheKept := -1, time.Duration(0), false
	keepCache := func() {
		if cache == "" {
			return
		}
		os.MkdirAll(cache, 0o700)
		for _, f := range cached {
			if b, err := os.ReadFile(filepath.Join(dir, "tor", f)); err == nil {
				os.WriteFile(filepath.Join(cache, f), b, 0o600)
			}
		}
	}
	end := time.Now().Add(5 * time.Minute)
	for time.Now().Before(end) {
		now := time.Since(t0)
		statusMu.RLock()
		pct := bootstrapPct
		statusMu.RUnlock()
		if _, ok := pctAt[pct]; !ok {
			pctAt[pct] = now
		}
		if readyAt == 0 && torReadyNow() {
			readyAt = now
		}
		if routeAt == 0 && readyAt != 0 && routeOK() {
			routeAt = now
		}
		hubsMu.Lock()
		for k, h := range hubs {
			if k.url == relays[1] && h.up {
				if _, ok := batchUp[k.lane]; !ok {
					batchUp[k.lane] = now
				}
			}
		}
		hubsMu.Unlock()
		catchupMu.Lock()
		var bt []time.Time
		allIn := true
		for lane, rcvs := range batchesOf {
			var last time.Time
			in := true
			for _, r := range rcvs {
				at, ok := caughtAt(r)
				if !ok {
					in = false
					break
				}
				if at.After(last) {
					last = at
				}
			}
			if in {
				bt = append(bt, last)
				if lane == firstLane && topsIn == 0 {
					topsIn = last.Sub(t0)
				}
			} else {
				allIn = false
			}
		}
		// every address on our two relays (the public ones hold at most 24
		// live), of those that answered at all
		for _, u := range relays {
			if at, ok := connectAt[u]; ok && at.After(t0) {
				if _, seen := relayUpAt[u]; !seen {
					relayUpAt[u] = at.Sub(t0)
				}
			}
		}
		socks, want := 0, 0
		for _, u := range relays[:2] {
			if _, ok := relayUpAt[u]; !ok {
				continue
			}
			want += len(addrs)
			for _, a := range addrs {
				if r, ok := catchupLast[catchupKey(u, a.rcv)]; ok && r.At.After(t0) {
					socks++
				}
			}
		}
		catchupMu.Unlock()
		if socks != lastSocks {
			lastSocks, movedAt = socks, now
		}
		if firstBatch == 0 && len(bt) > 0 {
			sort.Slice(bt, func(i, j int) bool { return bt[i].Before(bt[j]) })
			firstBatch = bt[0].Sub(t0)
		}
		if allBatches == 0 && allIn {
			allBatches = now
		}
		if allSockets == 0 && want > 0 && socks == want && now-movedAt > 20*time.Second {
			allSockets = movedAt
		}
		if allSockets != 0 && allBatches != 0 {
			break
		}
		if readyAt != 0 && !cacheKept {
			cacheKept = true
			keepCache()
		}
		time.Sleep(100 * time.Millisecond)
	}
	keepCache()
	var ups []string
	for _, u := range relays {
		if d, ok := relayUpAt[u]; ok {
			ups = append(ups, fmt.Sprintf("%s@%s", relayHost(u), secs(d)))
		} else {
			ups = append(ups, relayHost(u)+"@never")
		}
	}
	t.Logf("relays up: %s", strings.Join(ups, " "))
	var bu []time.Duration
	for _, d := range batchUp {
		bu = append(bu, d-readyAt)
	}
	sort.Slice(bu, func(i, j int) bool { return bu[i] < bu[j] })
	var bs []string
	for _, d := range bu {
		bs = append(bs, secs(d))
	}
	t.Logf("BATCHES old=%v batch sockets on relay.kryfo.app up, from tor ready: %s", old, strings.Join(bs, " "))
	var steps []int
	for p := range pctAt {
		steps = append(steps, p)
	}
	sort.Ints(steps)
	var ps []string
	for _, p := range steps {
		ps = append(ps, fmt.Sprintf("%d%%@%s", p, secs(pctAt[p])))
	}
	or := func(d time.Duration) string {
		if d == 0 {
			return "never"
		}
		return secs(d)
	}
	t.Logf("tor steps: %s", strings.Join(ps, " "))
	t.Logf("engine steps: %s", strings.ReplaceAll(startSteps.take(), "\n", " | "))
	t.Logf("SUMMARY old=%v n=%d batches=%d relays=%d warm=%v | listened %s | tor ready %s | route proven %s | first batch caught up %s | top chats' batch caught up %s | all batches caught up %s | every address on our relays %s",
		old, n, len(batchesOf), len(relays), cache != "", secs(listenAt), or(readyAt), or(routeAt), or(firstBatch), or(topsIn), or(allBatches), or(allSockets))
}
