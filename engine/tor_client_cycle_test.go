// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torcycle

// a linked device's tor against the real network, in one process as the
// app runs it: a first start publishes the new device's onion, the link
// makes tor a client and the onion goes, then sleep, wake and a bounce on
// the same tor, which is never closed. needs a network:
//
//	go test -tags torcycle -run TestClientTorCycles -v .
package main

import (
	"strings"
	"testing"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// the services the onion connection owns, as tor lists them. tor drops one
// only on the connection that added it, so this is what is published
func onionsOwned(t *testing.T, n *tor.Tor) string {
	t.Helper()
	var kv []*control.KeyVal
	err := onionDo(n, "GETINFO onions/current", ctrlDeadline(), func(tc *tor.Tor) error {
		var gerr error
		kv, gerr = tc.Control.GetInfo("onions/current")
		return gerr
	})
	if err != nil {
		t.Fatalf("onions/current: %v", err)
	}
	var out []string
	for _, v := range kv {
		out = append(out, v.Val)
	}
	return strings.Join(out, ",")
}

func waitStatus(t *testing.T, want string, limit time.Duration) {
	t.Helper()
	for t0 := time.Now(); time.Since(t0) < limit; time.Sleep(100 * time.Millisecond) {
		if torStatusNow() == want {
			return
		}
	}
	t.Fatalf("status %q after %s, want %q", torStatusNow(), limit, want)
}

func TestClientTorCycles(t *testing.T) {
	dir := t.TempDir()
	addr := startListener(dir)
	if strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	if pct, _ := waitBoot(4 * time.Minute); pct < 100 {
		t.Skipf("tor only bootstrapped to %d%% here", pct)
	}
	mu.Lock()
	first := torNode
	mu.Unlock()
	id := strings.TrimSuffix(addr, ".onion")
	if got := onionsOwned(t, first); !strings.Contains(got, id) {
		t.Fatalf("the phone's onion %s is not up: %q", id, got)
	}

	// the link: a client from here, the device's onion down
	t0 := time.Now()
	if r := torClientOn(); r != "ok" {
		t.Fatalf("made a client: %s", r)
	}
	t.Logf("onion down in %dms", time.Since(t0).Milliseconds())
	if got := onionsOwned(t, first); got != "" {
		t.Fatalf("tor still holds %q", got)
	}
	waitStatus(t, "bootstrapped", 5*time.Second)
	if r := startListener(dir); r != torClientAddr {
		t.Fatalf("start on a client: %s", r)
	}

	for i := 0; i < 4; i++ {
		if r := torStop(); r != "ok" {
			t.Fatalf("cycle %d sleep: %s", i, r)
		}
		waitStatus(t, "off", time.Second)
		if r := startListener(dir); !strings.HasPrefix(r, "error: tor is stopped") {
			t.Fatalf("cycle %d: a start while asleep: %s", i, r)
		}
		if r := torResume(); r != "ok" {
			t.Fatalf("cycle %d wake: %s", i, r)
		}
		if r := startListener(dir); r != torClientAddr {
			t.Fatalf("cycle %d: start after the wake: %s", i, r)
		}
		pct, woke := waitBoot(3 * time.Minute)
		if pct < 100 {
			t.Fatalf("cycle %d: awake but at %d%%", i, pct)
		}
		waitStatus(t, "bootstrapped", 5*time.Second)
		if got := onionsOwned(t, first); got != "" {
			t.Fatalf("cycle %d: an onion came back: %q", i, got)
		}
		t.Logf("cycle %d: awake and at 100%% in %dms", i, woke.Milliseconds())
	}

	// a bounce, as a bridge change or a rescue does
	if r := reconnectNow(); r != "ok" {
		t.Fatalf("bounce: %s", r)
	}
	if pct, _ := waitBoot(3 * time.Minute); pct < 100 {
		t.Fatalf("after the bounce at %d%%", pct)
	}
	waitStatus(t, "bootstrapped", 5*time.Second)
	if got := onionsOwned(t, first); got != "" {
		t.Fatalf("an onion came back after the bounce: %q", got)
	}
	// 100% comes back at once after a bounce: the circuits follow
	circ := ""
	for t0 := time.Now(); circ != "1" && time.Since(t0) < 2*time.Minute; time.Sleep(time.Second) {
		var kv []*control.KeyVal
		if err := ctrlDo(first, "GETINFO circuit-established", func(c *control.Conn) error {
			var gerr error
			kv, gerr = c.GetInfo("status/circuit-established")
			return gerr
		}); err == nil && len(kv) > 0 {
			circ = kv[0].Val
		}
	}
	if circ != "1" {
		t.Fatalf("no circuit on the client after the bounce: %q", circ)
	}
	mu.Lock()
	same, left := torNode == first, myAddr
	mu.Unlock()
	if !same {
		t.Fatal("a second tor in the process")
	}
	if left != "" {
		t.Fatalf("an address came back: %q", left)
	}
}
