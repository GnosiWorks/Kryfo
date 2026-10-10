// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// airplane mode on a flight: the network goes for minutes while the engine
// keeps trying, then comes back with the app's network-change call. tor
// reaches the network only through a proxy the test cuts:
//
//	go test -tags torconf -run TestAirplaneThenLand -v .
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"golang.org/x/crypto/curve25519"
	"golang.org/x/net/proxy"
)

// how long the flight is. long enough for the route watch to rescue a dead
// route several times over, which is what grows its back-off.
func flightTime() time.Duration {
	if v := os.Getenv("HALO_FLIGHT"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return 8 * time.Minute
}

// one fresh stream through tor to a clearnet host: a circuit and an exit
func probeThroughTor() error {
	d, err := proxy.SOCKS5("tcp", fmt.Sprintf("127.0.0.1:%d", socksPin()),
		&proxy.Auth{User: "probe" + fmt.Sprint(time.Now().UnixNano()), Password: "x"}, nil)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	c, err := d.(proxy.ContextDialer).DialContext(ctx, "tcp", "relay.kryfo.app:443")
	if err != nil {
		return err
	}
	return c.Close()
}

func routeLine() string {
	routeMu.Lock()
	r, last := rescues, lastRescue
	routeMu.Unlock()
	ago := "never"
	if !last.IsZero() {
		ago = time.Since(last).Round(time.Second).String() + " ago"
	}
	return fmt.Sprintf("status %s %d%% route ok %t, %d rescues, last %s, reconnect %q",
		status(), bootPct(), routeOK(), r, ago, lastReconnectOutcome())
}

func startRunners(t *testing.T, n int) {
	t.Helper()
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
	for i := 0; i < n; i++ {
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
		t.Cleanup(cancel)
		go nostrSubscribeRunner(ctx, peerHex, peer, rcvPk)
	}
	kickRelays()
}

func relaysSince(at time.Time) int {
	n := 0
	for _, u := range strings.Split(testRelays, ",") {
		if relayConnectedAt(u).After(at) {
			n++
		}
	}
	return n
}

func TestAirplaneThenLand(t *testing.T) {
	plane := newAirplane(t)
	torArgsExtra = []string{"--Socks5Proxy", plane.addr()}
	defer func() { torArgsExtra = nil }()

	dir := t.TempDir()
	if addr := startListener(dir); strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	if pct, took := waitBoot(4 * time.Minute); pct < 100 {
		t.Skipf("tor only reached %d%% here", pct)
	} else {
		t.Logf("cold start: 100%% in %s", took.Round(time.Millisecond))
	}
	startRunners(t, 3)
	up := time.Now()
	for time.Since(up) < 2*time.Minute && (relaysSince(up) < 3 || !routeOK()) {
		time.Sleep(time.Second)
	}
	if !routeOK() {
		t.Skipf("the route never came up before the flight: %s", routeLine())
	}
	t.Logf("before the flight: %s", routeLine())

	// take-off: the network is gone, and android says nothing to the engine
	plane.cut(true)
	took := time.Now()
	flight := flightTime()
	for time.Since(took) < flight {
		time.Sleep(30 * time.Second)
		t.Logf("in the air %s: %s", time.Since(took).Round(time.Second), routeLine())
	}

	// landing: the network is back and the app reports the change
	plane.cut(false)
	landed := time.Now()
	// HALO_LAND_SILENT=1: android never says the network came back, as
	// when the app sat in doze through it
	if os.Getenv("HALO_LAND_SILENT") == "" {
		networkChanged()
	}
	var probeOK, relayOK, readyAt time.Duration
	for time.Since(landed) < 20*time.Minute {
		time.Sleep(5 * time.Second)
		since := time.Since(landed).Round(time.Second)
		if relayOK == 0 && relaysSince(landed) > 0 {
			relayOK = since
		}
		if readyAt == 0 && routeOK() {
			readyAt = since
		}
		if probeOK == 0 {
			if err := probeThroughTor(); err == nil {
				probeOK = since
			}
		}
		t.Logf("landed %s: %s, %d relays back", since, routeLine(), relaysSince(landed))
		if relayOK > 0 && readyAt > 0 && probeOK > 0 {
			break
		}
	}
	t.Logf("after landing: a fresh stream at %s, a relay at %s, can send at %s",
		probeOK, relayOK, readyAt)
	if readyAt == 0 || readyAt > 2*time.Minute {
		t.Fatalf("the app could not send for %s after landing: %s", time.Since(landed).Round(time.Second), routeLine())
	}
}

// a flight's worth of flips in a minute: airplane mode on and off, a dead
// wifi that swallows everything, mobile data, each one reported. it has to
// settle into one clean reconnect after the last change, not a storm and
// not a wedge, and tor has to carry traffic soon after
func TestFlipStormSettles(t *testing.T) {
	plane := newAirplane(t)
	torArgsExtra = []string{"--Socks5Proxy", plane.addr()}
	defer func() { torArgsExtra = nil }()

	dir := t.TempDir()
	if addr := startListener(dir); strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	if pct, _ := waitBoot(4 * time.Minute); pct < 100 {
		t.Skipf("tor only reached %d%% here", pct)
	}
	startRunners(t, 3)
	up := time.Now()
	for time.Since(up) < 2*time.Minute && !routeOK() {
		time.Sleep(time.Second)
	}
	if !routeOK() {
		t.Skipf("the route never came up before the flips: %s", routeLine())
	}
	runs, timeouts := reconnectRuns.Load(), ctrlTimeoutCount()

	steps := []struct {
		what string
		do   func()
	}{
		{"airplane on", func() { plane.cut(true) }},
		{"airplane off", func() { plane.cut(false) }},
		{"airplane on", func() { plane.cut(true) }},
		{"dead wifi", func() { plane.blackhole(true) }},
		{"airplane on", func() { plane.blackhole(false); plane.cut(true) }},
		{"mobile data", func() { plane.cut(false) }},
		{"airplane on", func() { plane.cut(true) }},
		{"airplane off", func() { plane.cut(false) }},
		{"dead wifi", func() { plane.blackhole(true) }},
		{"mobile data", func() { plane.blackhole(false) }},
		{"airplane on", func() { plane.cut(true) }},
		{"airplane off", func() { plane.cut(false) }},
	}
	for i, st := range steps {
		st.do()
		networkChanged()
		t.Logf("flip %d: %s", i+1, st.what)
		time.Sleep(time.Duration(1+i%3) * time.Second)
	}
	last := time.Now()
	t.Logf("flips done, %d reconnects ran during them", reconnectRuns.Load()-runs)
	var readyAt time.Duration
	for time.Since(last) < 3*time.Minute {
		time.Sleep(5 * time.Second)
		if routeOK() && routeProven() {
			readyAt = time.Since(last).Round(time.Second)
			break
		}
		t.Logf("%s after the last flip: %s", time.Since(last).Round(time.Second), routeLine())
	}
	// and settled: nothing more bounces once it works
	time.Sleep(30 * time.Second)
	n := reconnectRuns.Load() - runs
	t.Logf("can send %s after the last flip, %d reconnects in all, %d control timeouts, check %q",
		readyAt, n, ctrlTimeoutCount()-timeouts, lastNetCheck())
	if readyAt == 0 {
		t.Fatalf("tor not carrying anything 3m after the last flip: %s", routeLine())
	}
	// the flips come faster than the quiet window, so the debounce merges
	// them: a handful at most, never one per flip
	if n > 4 {
		t.Fatalf("%d reconnects for %d flips: a storm", n, len(steps))
	}
	if d := ctrlTimeoutCount() - timeouts; d > 0 {
		t.Fatalf("%d control timeouts during the flips", d)
	}
}
