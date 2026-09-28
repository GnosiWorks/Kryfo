// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"
)

// a backlog of media slices waiting at our relay, fetched over a slow
// circuit, one connection per check-in. how many check-ins until every slice
// is in, and what each one cost. slow, so only on request:
//
//	HALO_RELAY_MEASURE=1 go test -run TestMeasureCatchup -v -timeout 30m .
//
// HALO_CU_SLICES (150), HALO_CU_RATE (bytes a second down the circuit,
// 150000) and HALO_CU_ROUNDS (8) change it.
func TestMeasureCatchup(t *testing.T) {
	if os.Getenv("HALO_RELAY_MEASURE") == "" {
		t.Skip("HALO_RELAY_MEASURE not set")
	}
	num := func(k string, def int) int {
		if v, err := strconv.Atoi(os.Getenv(k)); err == nil {
			return v
		}
		return def
	}
	slices := num("HALO_CU_SLICES", 150)
	rate := num("HALO_CU_RATE", 150000)
	rounds := num("HALO_CU_ROUNDS", 8)

	var logTo io.Writer = io.Discard
	if p := os.Getenv("HALO_CU_LOG"); p != "" {
		if f, err := os.Create(p); err == nil {
			defer f.Close()
			logTo = f
		}
	}
	log.SetOutput(logTo)
	defer log.SetOutput(os.Stderr)

	socks := newSocksStandIn(t)
	socks.connectDelay = 1200 * time.Millisecond
	socks.lag = 600 * time.Millisecond
	socks.rate = rate
	relay := newRelayStandIn(t, 0)
	relay.upgradeDelay = 1200 * time.Millisecond
	useStandIns(t, modePrivate, socks, relay)
	mu.Lock()
	inboxDrained()
	mu.Unlock()
	nostrMu.Lock()
	nostrInbox, nostrInboxDone = nil, nil
	nostrMu.Unlock()

	peer := newXid(t)
	peerHex := hex.EncodeToString(peer.pub[:])
	me := myXPub
	body := strings.Repeat("Q", 22000)
	for i := 0; i < slices; i++ {
		relay.store(wrapTo(t, peer, me, body))
	}
	rcv := mustRcv(t, peer)
	ck := catchupKey(relay.url(), rcv)

	got := func() int {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		n := 0
		for _, l := range nostrInbox {
			if strings.HasPrefix(l, peerHex+"|") {
				n++
			}
		}
		return n
	}
	ended := func() (catchupRun, bool) {
		catchupMu.Lock()
		defer catchupMu.Unlock()
		r, ok := catchupLast[ck]
		return r, ok
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	start := time.Now()
	go nostrSubscribeRunner(ctx, peerHex, peer.pub, rcv)
	var prev time.Time
	for round := 1; round <= rounds; round++ {
		roundStart := time.Now()
		relay.mu.Lock()
		sentB := relay.resentB
		relay.mu.Unlock()
		var r catchupRun
		waitFor(t, "a catch-up to end", 5*time.Minute, func() bool {
			var ok bool
			r, ok = ended()
			return ok && r.At.After(prev)
		})
		prev = r.At
		// a page cut by the cap is handed over as the cap ends it
		time.Sleep(500 * time.Millisecond)
		relay.mu.Lock()
		sentB = relay.resentB - sentB
		relay.mu.Unlock()
		n := got()
		t.Logf("check-in %d: %s, dropped %v, long %v, %d pages, %d events, %d KB queued by the relay, %d of %d slices in",
			round, time.Since(roundStart).Round(100*time.Millisecond), r.Dropped, r.Long, r.Pages, r.Events,
			sentB/1024, n, slices)
		if n >= slices && !r.Dropped {
			t.Logf("all %d in after %d check-ins, %s", slices, round, time.Since(start).Round(time.Second))
			return
		}
		// the check-in ends: tor goes, the socket with it
		socks.cut()
		relay.dropAll()
	}
	t.Logf("after %d check-ins, %d of %d slices in", rounds, got(), slices)
}
