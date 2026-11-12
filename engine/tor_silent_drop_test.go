// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// a wifi that passes no tcp for minutes and then works again, with android
// saying nothing either way. what was open stays dead for good and connects
// made meanwhile never hear back. the engine finds its way back alone, no
// reconnect by hand:
//
//	go test -tags torconf -run TestSilentDropRecovers -v .
package main

import (
	"os"
	"strings"
	"testing"
	"time"
)

func dropTime() time.Duration {
	if v := os.Getenv("HALO_DROP"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	// long enough for release-061's waits to grow past the bound
	return 20 * time.Minute
}

// how long after the wifi works again the app may still be unable to send
const silentDropBound = 4 * time.Minute

func TestSilentDropRecovers(t *testing.T) {
	plane := newAirplane(t)
	torArgsExtra = []string{"--Socks5Proxy", plane.addr()}
	defer func() { torArgsExtra = nil }()
	// the wifi as android reports it, all along
	setNetInfo(netInfo{On: true, Validated: true, Kind: "wifi", Net: 7})

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
	for time.Since(up) < 2*time.Minute && (relaysSince(up) < 2 || !routeOK()) {
		time.Sleep(time.Second)
	}
	if !routeOK() {
		t.Skipf("the route never came up before the drop: %s", routeLine())
	}
	t.Logf("before the drop: %s", routeLine())

	plane.stall(true)
	dropped := time.Now()
	for d := dropTime(); time.Since(dropped) < d; {
		time.Sleep(30 * time.Second)
		t.Logf("dropped %s: %s", time.Since(dropped).Round(time.Second), routeLine())
	}

	plane.stall(false)
	back := time.Now()
	var readyAt time.Duration
	for time.Since(back) < 20*time.Minute {
		time.Sleep(5 * time.Second)
		since := time.Since(back).Round(time.Second)
		if routeOK() && relaysSince(back) > 0 {
			readyAt = since
			break
		}
		if since%(30*time.Second) < 5*time.Second {
			t.Logf("back %s: %s, %d relays back", since, routeLine(), relaysSince(back))
		}
	}
	t.Logf("after the drop: %s, can send at %s", routeLine(), readyAt)
	if readyAt == 0 || readyAt > silentDropBound {
		t.Fatalf("no send possible for %s after the wifi came back: %s",
			time.Since(back).Round(time.Second), routeLine())
	}
}
