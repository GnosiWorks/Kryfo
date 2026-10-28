// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"testing"
	"time"
)

func statusForTest(t *testing.T, s string) {
	t.Helper()
	statusMu.Lock()
	old := torStatus
	torStatus = s
	statusMu.Unlock()
	t.Cleanup(func() {
		statusMu.Lock()
		torStatus = old
		statusMu.Unlock()
	})
}

// before our onion is published a direct send answers at once and dials
// nothing, so the app takes the relays without waiting on the publish
func TestDirectRouteWaitsForThePublish(t *testing.T) {
	socks := newSocksStandIn(t)
	d := newTestDoor(t, handleConn)
	doorSetup(t, socks, map[string]*testDoor{"aaaa.onion": d})
	for _, st := range []string{"starting", "bootstrapped", "publishing"} {
		statusForTest(t, st)
		began := time.Now()
		if r := sendDirect("aaaa.onion", doorLine(t, 64)); r != errNotPublished {
			t.Fatalf("%s: %q, want %q", st, r, errNotPublished)
		}
		if took := time.Since(began); took > 200*time.Millisecond {
			t.Fatalf("%s: the answer took %s", st, took)
		}
		if n := d.count(); n != 0 {
			t.Fatalf("%s: %d streams reached the door", st, n)
		}
	}
	statusForTest(t, "reachable")
	if r := sendDirect("aaaa.onion", doorLine(t, 64)); r != "ok" {
		t.Fatalf("published: %q", r)
	}
	if n := d.count(); n != 1 {
		t.Fatalf("published: %d streams, want 1", n)
	}
}

// no tor at all still says so, published or not
func TestDirectRouteWithNoTor(t *testing.T) {
	mu.Lock()
	old := torNode
	torNode = nil
	mu.Unlock()
	defer func() {
		mu.Lock()
		torNode = old
		mu.Unlock()
	}()
	statusForTest(t, "reachable")
	if r := sendDirect("aaaa.onion", "x"); r != "error: tor not started" {
		t.Fatalf("%q", r)
	}
}
