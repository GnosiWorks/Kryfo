// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// the redmi on 2026-09-22: check-ins put tor to sleep, a check-in woke it
// and put it back, and a minute later the mode went back to always on. that
// last resume never returned, and the reconnect the network change started
// afterwards sat at "network on" for twenty hours with tor itself healthy
// and the reconnect button answering "one already running". a release
// build cannot say which lock it was, so this replays the sequence against
// a real tor, with the relay runners up as they are in the app, and dumps
// every goroutine the moment a step takes longer than it ever should:
//
//	go test -tags torconf -run TestSleepWakeThenModeSwitch -v .
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"golang.org/x/crypto/curve25519"
)

// the app's private-mode relay list, our own onion relay first
const testRelays = "wss://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion," +
	"wss://relay.kryfo.app,wss://nos.lol,wss://relay.primal.net,wss://nostr.mom,wss://nostr.oxtr.dev"

// runs f and fails the test with a full goroutine dump if it has not come
// back within limit. the dump goes to a file so it survives -v truncation.
func mustReturn(t *testing.T, what string, limit time.Duration, f func() string) string {
	t.Helper()
	done := make(chan string, 1)
	t0 := time.Now()
	go func() { done <- f() }()
	select {
	case r := <-done:
		t.Logf("%-28s %-40s %s", what, r, time.Since(t0).Round(time.Millisecond))
		return r
	case <-time.After(limit):
		buf := make([]byte, 16<<20)
		n := runtime.Stack(buf, true)
		p := filepath.Join(os.TempDir(), fmt.Sprintf("halo-wedge-%s.txt",
			strings.ReplaceAll(what, " ", "_")))
		_ = os.WriteFile(p, buf[:n], 0600)
		t.Fatalf("%s did not return in %s - goroutines in %s (%d bytes)", what, limit, p, n)
		return ""
	}
}

func TestSleepWakeThenModeSwitch(t *testing.T) {
	dir := t.TempDir()
	addr := startListener(dir)
	if strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	if pct, took := waitBoot(4 * time.Minute); pct < 100 {
		t.Skipf("tor only reached %d%% here", pct)
	} else {
		t.Logf("cold start: 100%% in %dms", took.Milliseconds())
	}

	// the app's shape: an identity, the relay list, and runners for a few
	// peers. every runner loops through torNostrClient, which is where the
	// suspected lock lives. set directly - cgo is not allowed in a test file.
	mu.Lock()
	if _, err := rand.Read(myXPriv[:]); err != nil {
		mu.Unlock()
		t.Fatal(err)
	}
	curve25519.ScalarBaseMult(&myXPub, &myXPriv)
	mu.Unlock()
	nostrMu.Lock()
	nostrRelays = strings.Split(testRelays, ",")
	nostrMu.Unlock()
	for i := 0; i < 3; i++ {
		var peer [32]byte
		peer[0], peer[31] = byte(i+1), 0x42
		peerHex := hex.EncodeToString(peer[:])
		_, rcvPk, err := nip17RcvAddress(peer)
		if err != nil {
			t.Fatalf("derive %d: %v", i, err)
		}
		ctx, cancel := context.WithCancel(context.Background())
		nostrMu.Lock()
		nostrSubs[peerHex] = cancel
		nostrMu.Unlock()
		defer cancel()
		go nostrSubscribeRunner(ctx, peerHex, peer, rcvPk)
	}
	kickRelays()
	time.Sleep(20 * time.Second) // let the runners build a client and dial

	// the gaps between the last sleep and the wake that hung on the phone
	// are not known to the second; try the ones a person and a job produce.
	for round, gap := range []time.Duration{2 * time.Second, 20 * time.Second, 0, 45 * time.Second} {
		t.Logf("--- round %d, gap %s ---", round, gap)
		// check-ins chosen: tor goes to sleep
		if r := mustReturn(t, "stop (mode -> check-ins)", 90*time.Second, torStop); r != "ok" {
			t.Fatalf("round %d stop: %s", round, r)
		}
		time.Sleep(5 * time.Second)
		// a check-in: wake, kick the relays, fetch for a while, sleep
		if r := mustReturn(t, "resume (check-in)", 90*time.Second, torResume); r != "ok" {
			t.Fatalf("round %d resume: %s", round, r)
		}
		mustReturn(t, "start after resume", 90*time.Second, func() string { return startListener(dir) })
		kickRelays()
		if pct, took := waitBoot(2 * time.Minute); pct < 100 {
			t.Logf("round %d: bootstrap only %d%% after the check-in wake (%s)", round, pct, took)
		}
		time.Sleep(40 * time.Second)
		if r := mustReturn(t, "stop (check-in over)", 90*time.Second, torStop); r != "ok" {
			t.Fatalf("round %d sleep: %s", round, r)
		}
		time.Sleep(gap)
		// always on chosen again: this is the resume that never came back
		if r := mustReturn(t, "resume (mode -> always on)", 90*time.Second, torResume); r != "ok" {
			t.Fatalf("round %d wake: %s", round, r)
		}
		mustReturn(t, "start after wake", 90*time.Second, func() string { return startListener(dir) })
		// and the network change that followed
		atomic.StoreInt64(&lastTorRestart, 0)
		if r := mustReturn(t, "reconnect (network change)", 3*time.Minute, reconnectTor); r != "ok" {
			t.Fatalf("round %d reconnect: %s", round, r)
		}
		if pct, took := waitBoot(3 * time.Minute); pct < 100 {
			t.Fatalf("round %d: tor never came back after the reconnect (%d%% after %s)", round, pct, took)
		} else {
			t.Logf("round %d: back at 100%% in %s, status %s, reconnect %q",
				round, took.Round(time.Millisecond), status(), lastReconnectOutcome())
		}
	}
}
