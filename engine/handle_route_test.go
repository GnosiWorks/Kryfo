// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// the handle registry over real embedded tor. handleBase is clearnet through
// a tor exit, not the onion, so this drives the exact path the app uses: the
// same torNostrClient() the engine builds, the same requests.
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
// idempotent GET on a dead pooled connection; it does not retry a POST once
// anything has been written. so checks answer and claims time out.
func TestClaimAfterNetworkBounce(t *testing.T) {
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

	// the pool still holds sockets from before the bounce. with the port
	// pinned the held client survives it outright; if not, the cache resets
	// are carrying it.
	get("after bounce")
	post("after bounce")
	if heldDied {
		if socksPin() != 0 {
			t.Errorf("the socks port is pinned to %d yet a client built "+
				"before the bounce died - the pin did not hold", socksPin())
		} else {
			t.Log("  (no pin this run; the cache resets are carrying it)")
		}
	} else {
		t.Logf("  the held client survived the bounce, socks pinned to %d",
			socksPin())
	}

	// ask the way the app asks, with no manual reset: reconnectOn must have
	// dropped the stale client itself.
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

// every one-shot request in the engine goes through a cached client, so a
// socks port that moves takes all of them down together. this holds each
// client across a bounce, which is how the app has them: warm, from before.
//
//	torNostrClient()      the everyday lane: its relays, HaloTorGet,
//	                      HaloTorPost (the badge service), handle
//	                      check/claim/release
//	torNostrClientFor()   the other lanes: each room's relays, pair codes
//	torOnlyHTTP()         HaloTorGetStrict (link previews)
//
// moat is deliberately absent: it does not use tor, because tor is what is
// broken when you are asking for bridges. the onion dial in bridge.go builds
// its own dialer per call and cannot go stale.
func TestOneShotsSurviveBounce(t *testing.T) {
	mu.Lock()
	already := myAddr != ""
	mu.Unlock()
	if already {
		t.Skip("another test in this process already owns tor; run this one alone")
	}
	dir, err := os.MkdirTemp("", "halo-oneshot")
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
	// let the start settle: startListener pre-warms a client and the watchdogs
	// can fire one reconnect of their own right after.
	time.Sleep(5 * time.Second)
	if socksPin() == 0 {
		t.Skip("no pinned socks port this run - nothing to prove here")
	}
	t.Logf("socks pinned to %d", socksPin())

	// warm, from before the bounce, exactly as the app holds them
	shared, err := torNostrClient()
	if err != nil {
		t.Fatalf("shared client: %v", err)
	}
	reg, err := handleHTTP()
	if err != nil {
		t.Fatalf("registry client: %v", err)
	}
	only, err := torOnlyHTTP()
	if err != nil {
		t.Fatalf("preview client: %v", err)
	}

	probes := []struct {
		name string
		run  func() error
	}{
		{"HaloTorGet / handle check", func() error {
			return ping(shared, "GET", handleBase+"/handle/check?h=probeaudit", "")
		}},
		{"HaloTorPost / badge invoice / handle claim", func() error {
			return ping(shared, "POST", handleBase+"/handle/claim",
				`{"handle":"probeaudit","invite":"kryfo://share?id=x","bio":"p","pubkey":"00","sig":"00"}`)
		}},
		{"handle lookup", func() error {
			return ping(reg, "GET", handleBase+"/.well-known/kryfo.json?name=len", "")
		}},
		{"HaloTorGetStrict / link preview", func() error {
			return ping(only, "GET", "https://example.com/", "")
		}},
	}

	for _, phase := range []string{"before", "after"} {
		if phase == "after" {
			t.Log("bouncing DisableNetwork, as a reconnect or a check-in wake does")
			atomic_store_lastRestart(0)
			if r := reconnectTor(); r != "ok" {
				t.Fatalf("reconnect: %s", r)
			}
			for i := 0; i < 60 && !torReadyNow(); i++ {
				time.Sleep(time.Second)
			}
		}
		for _, p := range probes {
			g0 := time.Now()
			err := p.run()
			took := time.Since(g0).Round(time.Millisecond)
			if err != nil {
				t.Errorf("  %-6s %-44s FAILED after %s: %v",
					phase, p.name, took, err)
			} else {
				t.Logf("  %-6s %-44s ok in %s", phase, p.name, took)
			}
		}
	}
}

func ping(c *http.Client, method, url, body string) error {
	var rdr io.Reader
	if body != "" {
		rdr = strings.NewReader(body)
	}
	req, err := http.NewRequest(method, url, rdr)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "")
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
	if resp.StatusCode >= 500 {
		return fmt.Errorf("status %d", resp.StatusCode)
	}
	return nil
}
