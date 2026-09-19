// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// why does claiming a handle time out from the phone while the registry
// answers in 150ms from a laptop?
//
// handleBase is "https://relay.kryfo.app" - clearnet, through a tor exit, not
// the onion. so this drives the exact path the app uses: real embedded tor,
// the same torNostrClient() the engine builds, the same GET. if it works here
// the fault is on the phone; if it fails here the fault is in this code.
//
//   go test -tags torconf -run TestRegistryOverTor -timeout 20m -v .
//
// one at a time: tor is per-process and both tests here start and bounce it,
// so running them together leaves the second one fighting the first's state.

package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"
)

func TestRegistryOverTor(t *testing.T) {
	dir, err := os.MkdirTemp("", "halo-route")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	t.Logf("handleBase = %s", handleBase)
	t.Logf("mode = %q, needs tor = %v", currentMode(), modeNeedsTor())

	started := time.Now()
	if out := startListener(dir); out == "" || out[:5] == "error" {
		t.Fatalf("tor would not start: %s", out)
	}
	t.Logf("tor up in %s", time.Since(started).Round(time.Second))

	// wait for a usable route, the way a check-in does
	for i := 0; i < 90 && !torReadyNow(); i++ {
		time.Sleep(time.Second)
	}
	t.Logf("tor ready = %v after %s", torReadyNow(),
		time.Since(started).Round(time.Second))

	c0 := time.Now()
	client, err := torNostrClient()
	if err != nil {
		t.Fatalf("no client after %s: %v", time.Since(c0).Round(time.Second), err)
	}
	t.Logf("client built in %s", time.Since(c0).Round(time.Millisecond))

	// the three calls the handle screen makes, in order
	for _, tc := range []struct{ what, url string }{
		{"check", handleBase + "/handle/check?h=probeaudit"},
		{"lookup", handleBase + "/.well-known/kryfo.json?name=len"},
		{"page", handleBase + "/@len"},
	} {
		req, _ := http.NewRequest("GET", tc.url, nil)
		req.Header.Set("User-Agent", "")
		g0 := time.Now()
		resp, err := client.Do(req)
		took := time.Since(g0).Round(time.Millisecond)
		if err != nil {
			t.Errorf("  %-6s FAILED after %s: %v", tc.what, took, err)
			continue
		}
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 300))
		resp.Body.Close()
		t.Logf("  %-6s %d in %s  %s", tc.what, resp.StatusCode, took,
			trunc(string(b), 90))
	}

	// and a control: somewhere else entirely, to tell "exits are broken" from
	// "our host is unreachable through tor"
	req, _ := http.NewRequest("GET", "https://example.com/", nil)
	g0 := time.Now()
	resp, err := client.Do(req)
	if err != nil {
		t.Errorf("  control example.com FAILED after %s: %v",
			time.Since(g0).Round(time.Millisecond), err)
	} else {
		resp.Body.Close()
		t.Logf("  control example.com %d in %s", resp.StatusCode,
			time.Since(g0).Round(time.Millisecond))
	}
}

// the phone bounces tor's network on every reconnect and every check-in
// wake. a pooled keep-alive connection through a circuit that died in the
// bounce is still in the transport's pool afterwards. go retries an
// idempotent GET on a dead pooled connection; it does NOT retry a POST once
// anything has been written. that would look exactly like what the samsung
// does: checks answer, claims time out.
func TestClaimAfterANetworkBounce(t *testing.T) {
	mu.Lock()
	already := myAddr != ""
	mu.Unlock()
	if already {
		t.Skip("another test in this process already owns tor; run this one alone")
	}
	dir, err := os.MkdirTemp("", "halo-bounce")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)
	if out := startListener(dir); out == "" || out[:5] == "error" {
		t.Fatalf("tor would not start: %s", out)
	}
	for i := 0; i < 90 && !torReadyNow(); i++ {
		time.Sleep(time.Second)
	}
	client, err := torNostrClient()
	if err != nil {
		t.Fatal(err)
	}

	var heldDied bool
	post := func(label string) {
		body := `{"handle":"probeaudit","invite":"kryfo://share?id=x","bio":"p","pubkey":"00","sig":"00"}`
		req, _ := http.NewRequest("POST", handleBase+"/handle/claim",
			strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("User-Agent", "")
		g0 := time.Now()
		resp, err := client.Do(req)
		took := time.Since(g0).Round(time.Millisecond)
		if err != nil {
			if strings.Contains(label, "after bounce") {
				heldDied = true
				t.Logf("  POST %-18s died as expected: %v", label, err)
				return
			}
			t.Errorf("  POST %-18s FAILED after %s: %v", label, took, err)
			return
		}
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 200))
		resp.Body.Close()
		t.Logf("  POST %-18s %d in %s  %s", label, resp.StatusCode, took, trunc(string(b), 60))
	}
	get := func(label string) {
		req, _ := http.NewRequest("GET", handleBase+"/handle/check?h=probeaudit", nil)
		req.Header.Set("User-Agent", "")
		g0 := time.Now()
		resp, err := client.Do(req)
		took := time.Since(g0).Round(time.Millisecond)
		if err != nil {
			if strings.Contains(label, "after bounce") {
				heldDied = true
				t.Logf("  GET  %-18s died as expected: %v", label, err)
				return
			}
			t.Errorf("  GET  %-18s FAILED after %s: %v", label, took, err)
			return
		}
		resp.Body.Close()
		t.Logf("  GET  %-18s %d in %s", label, resp.StatusCode, took)
	}

	get("before bounce")
	post("before bounce")

	// exactly what a check-in wake or a bridge switch does
	t.Log("bouncing DisableNetwork, as a reconnect does")
	atomic_store_lastRestart(0)
	if r := reconnectTor(); r != "ok" {
		t.Fatalf("reconnect: %s", r)
	}
	for i := 0; i < 60 && !torReadyNow(); i++ {
		time.Sleep(time.Second)
	}

	// the pool still holds sockets from before the bounce
	// a client captured before the bounce is bound to the old socks port and
	// cannot survive - that is the premise, not the bug.
	get("after bounce")
	post("after bounce")
	if !heldDied {
		t.Log("  (the held client survived the bounce; tor kept its socks port)")
	}

	// the regression this test exists for: ask the way the app asks, with no
	// manual reset. reconnectOn must have dropped the stale client itself.
	c2, err := torNostrClient()
	if err != nil {
		t.Fatalf("rebuild after bounce: %v", err)
	}
	if c2 == client {
		t.Error("reconnectOn left the stale client in the cache - every " +
			"one-shot request through it dies on a closed socks port")
	}
	client = c2
	get("after reconnect, fresh ask")
	post("after reconnect, fresh ask")
}

func trunc(s string, n int) string {
	s = fmt.Sprintf("%q", s)
	if len(s) > n {
		return s[:n] + "…"
	}
	return s
}
