// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// the bridge switch and the dialer watchdog both come through reconnectTor.
// this is that path, over and over, against the real network:
//
//	go test -tags torconf -run TestReconnect -v .
//
// tor must never be replaced: a second tor in one process hangs or aborts,
// so the same *tor.Tor has to still be there at the end.
package main

import (
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/cretz/bine/tor"
)

const fakeBridge = "obfs4 1.2.3.4:443 0000000000000000000000000000000000000000 " +
	"cert=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA iat-mode=0"

func node(t *testing.T) *tor.Tor {
	t.Helper()
	mu.Lock()
	defer mu.Unlock()
	return torNode
}

func bootPct() int {
	statusMu.RLock()
	defer statusMu.RUnlock()
	return bootstrapPct
}

func status() string {
	statusMu.RLock()
	defer statusMu.RUnlock()
	return torStatus
}

func waitBoot(limit time.Duration) (int, time.Duration) {
	t0 := time.Now()
	for time.Since(t0) < limit {
		if bootPct() >= 100 {
			break
		}
		time.Sleep(250 * time.Millisecond)
	}
	return bootPct(), time.Since(t0)
}

func conf(t *testing.T, keys ...string) map[string]string {
	t.Helper()
	out := map[string]string{}
	n := node(t)
	if n == nil || n.Control == nil {
		return out
	}
	vals, err := n.Control.GetConf(keys...)
	if err != nil {
		t.Fatalf("GETCONF %v: %v", keys, err)
	}
	for _, v := range vals {
		if old, ok := out[v.Key]; ok {
			out[v.Key] = old + "|" + v.Val
			continue
		}
		out[v.Key] = v.Val
	}
	return out
}

func TestReconnect(t *testing.T) {
	dir := t.TempDir()
	addr := startListener(dir)
	if strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	first := node(t)
	if first == nil {
		t.Fatal("no tor")
	}
	pct, took := waitBoot(4 * time.Minute)
	if pct < 100 {
		t.Skipf("tor only reached %d%% here, nothing to reconnect", pct)
	}
	t.Logf("cold start: 100%% in %dms", took.Milliseconds())
	goFirst := runtime.NumGoroutine()

	// three switches in a row, which is what a person poking the bridges
	// screen does: on, off, on.
	for i, on := range []bool{true, false, true} {
		bridgeMu.Lock()
		bridgeList = []string{fakeBridge}
		bridgeOn = on
		bridgeMu.Unlock()
		if on {
			if err := startPTListener(); err != nil {
				t.Fatalf("pt listener: %v", err)
			}
		}
		atomic_store_lastRestart(0)
		t0 := time.Now()
		if r := reconnectTor(); r != "ok" {
			t.Fatalf("switch %d (%v): %s", i, on, r)
		}
		took := time.Since(t0)

		got := conf(t, "UseBridges", "Bridge", "ClientTransportPlugin", "DisableNetwork")
		if got["DisableNetwork"] != "0" {
			t.Fatalf("switch %d: left the network off: %q", i, got["DisableNetwork"])
		}
		if on {
			if got["UseBridges"] != "1" {
				t.Fatalf("switch %d: UseBridges=%q", i, got["UseBridges"])
			}
			if !strings.Contains(got["Bridge"], "1.2.3.4:443") {
				t.Fatalf("switch %d: tor did not take the bridge line: %q", i, got["Bridge"])
			}
			if !strings.Contains(got["ClientTransportPlugin"], "obfs4 socks5") {
				t.Fatalf("switch %d: no transport plugin: %q", i, got["ClientTransportPlugin"])
			}
		} else {
			if got["UseBridges"] == "1" {
				t.Fatalf("switch %d: bridges still on", i)
			}
			if strings.Contains(got["Bridge"], "1.2.3.4") {
				t.Fatalf("switch %d: the bridge line was left behind: %q", i, got["Bridge"])
			}
		}
		if node(t) != first {
			t.Fatalf("switch %d: tor was replaced", i)
		}
		t.Logf("switch %d (bridges=%v): %dms, UseBridges=%q, status %q",
			i, on, took.Milliseconds(), got["UseBridges"], status())
	}

	// back to no bridges, and the network has to come all the way back
	bridgeMu.Lock()
	bridgeOn = false
	bridgeList = nil
	bridgeMu.Unlock()
	atomic_store_lastRestart(0)
	if r := reconnectTor(); r != "ok" {
		t.Fatalf("back to direct: %s", r)
	}
	pct, back := waitBoot(3 * time.Minute)
	if pct < 100 {
		t.Fatalf("direct again stopped at %d%%", pct)
	}
	t.Logf("direct again: 100%% in %dms", back.Milliseconds())

	// the watchdog, forced twice in a row
	for i := 0; i < 2; i++ {
		atomic_store_lastRestart(0)
		t0 := time.Now()
		if r := reconnectTor(); r != "ok" {
			t.Fatalf("watchdog %d: %s", i, r)
		}
		pct, took := waitBoot(2 * time.Minute)
		if pct < 100 {
			t.Fatalf("watchdog %d: stopped at %d%%", i, pct)
		}
		t.Logf("watchdog %d: back at 100%% %dms after the bounce (%dms total)",
			i, took.Milliseconds(), time.Since(t0).Milliseconds())
	}

	if node(t) != first {
		t.Fatal("tor was replaced somewhere")
	}
	// all of the above must have gone over a control socket the engine owns:
	// on the fallback path there is nothing to close when tor wedges
	if ctrlDialCount() == 0 {
		t.Fatal("no control connection of our own was ever dialled - " +
			"every command went through bine, where a wedge cannot be closed")
	}
	if n := ctrlTimeoutCount(); n != 0 {
		t.Fatalf("a healthy tor timed out %d times on its control port", n)
	}
	if n := runtime.NumGoroutine(); n > goFirst+4 {
		t.Fatalf("goroutines climbed: %d -> %d", goFirst, n)
	}
	// and the cooldown still bites when nothing resets it
	if r := reconnectTor(); r != "error: too soon" {
		t.Fatalf("the cooldown did not hold: %s", r)
	}
}
