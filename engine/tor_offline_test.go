// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// airplane mode that android reports: tor goes off the network for the
// flight, nothing bounces it while there is none, it does not wander through
// new guards, and it carries traffic soon after landing:
//
//	go test -tags torconf -run TestReportedFlightStaysOff -v .
package main

import (
	"strings"
	"testing"
	"time"

	"github.com/cretz/bine/control"
)

// how many guards tor has sampled, and how many it has used
func guardCount(t *testing.T) (sampled, used int) {
	t.Helper()
	n := node(t)
	if n == nil {
		return 0, 0
	}
	_ = ctrlDo(n, "entry-guards", func(c *control.Conn) error {
		kv, err := c.GetInfo("entry-guards")
		if err != nil || len(kv) == 0 {
			return err
		}
		for _, l := range strings.Split(kv[0].Val, "\n") {
			if strings.TrimSpace(l) == "" {
				continue
			}
			sampled++
			if !strings.Contains(l, "never-connected") {
				used++
			}
		}
		return nil
	})
	return sampled, used
}

func TestReportedFlightStaysOff(t *testing.T) {
	plane := newAirplane(t)
	torArgsExtra = []string{"--Socks5Proxy", plane.addr()}
	defer func() { torArgsExtra = nil }()
	defer netOffline.Store(false)

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
		t.Skipf("the route never came up before the flight: %s", routeLine())
	}
	sampled0, used0 := guardCount(t)
	t.Logf("before the flight: %s, guards %d sampled %d used", routeLine(), sampled0, used0)

	plane.cut(true)
	networkChangedTo(false)
	took := time.Now()
	time.Sleep(5 * time.Second)
	runs := reconnectRuns.Load()
	for time.Since(took) < flightTime() {
		time.Sleep(30 * time.Second)
		t.Logf("in the air %s: %s", time.Since(took).Round(time.Second), routeLine())
	}
	if n := reconnectRuns.Load() - runs; n != 0 {
		t.Fatalf("%d reconnects during the flight", n)
	}
	sampled1, used1 := guardCount(t)
	t.Logf("landing: guards %d sampled %d used", sampled1, used1)
	if sampled1 > sampled0 {
		t.Fatalf("tor sampled %d new guards with no network", sampled1-sampled0)
	}

	plane.cut(false)
	networkChangedTo(true)
	landed := time.Now()
	var readyAt time.Duration
	for time.Since(landed) < 3*time.Minute {
		time.Sleep(2 * time.Second)
		if routeOK() && routeProven() {
			readyAt = time.Since(landed).Round(time.Second)
			break
		}
	}
	sampled2, used2 := guardCount(t)
	t.Logf("after landing: can send at %s, guards %d sampled %d used", readyAt, sampled2, used2)
	if readyAt == 0 || readyAt > time.Minute {
		t.Fatalf("not carrying anything %s after landing: %s", time.Since(landed).Round(time.Second), routeLine())
	}
}
