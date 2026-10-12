// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/ed25519"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"
)

func useEdKey(t *testing.T) {
	t.Helper()
	_, priv, _ := ed25519.GenerateKey(nil)
	mu.Lock()
	old := myEdPriv
	myEdPriv = priv
	mu.Unlock()
	t.Cleanup(func() {
		mu.Lock()
		myEdPriv = old
		mu.Unlock()
	})
}

// the registry calls, people search and the badge calls as the app makes
// them, each with what it answered
func serviceCalls(base string) map[string]string {
	return map[string]string{
		"check":   handleCheck("wren"),
		"claim":   handleClaim("wren", "kryfo://share?id=a-b-c", ""),
		"release": handleRelease("wren"),
		"listing": handlePost("/handle/listing", []byte(`{}`)),
		"search":  torPost(base+"/handle/search", `{"q":"wren"}`),
		"badge":   torGetJSON(base + "/receipt?id=1"),
	}
}

// on every route the registry, search and badge calls go through tor under
// the services lane's own name, so the registry's box never sees the ip.
// gifs follow the route: direct on relay and fast
func TestServicesOverTorOnEveryRoute(t *testing.T) {
	for _, m := range []string{modePrivate, modeBalanced, modeFast} {
		t.Run(m, func(t *testing.T) {
			socks := newSocksStandIn(t)
			useStandIns(t, m, socks, newRelayStandIn(t, 0))
			useEdKey(t)
			svc := newServiceStandIn(t)
			oldBase := handleBase
			handleBase = svc.srv.URL
			defer func() { handleBase = oldBase }()
			for what, r := range serviceCalls(svc.srv.URL) {
				if strings.HasPrefix(r, "error") {
					t.Fatalf("%s: %s", what, r)
				}
			}
			calls := svc.remotes()
			if len(calls) != 6 {
				t.Fatalf("%d calls reached the service, want 6", len(calls))
			}
			for _, rem := range calls {
				n, ok := socks.nameOf(rem)
				if !ok {
					t.Fatalf("a service call went out directly in %s mode", m)
				}
				if n != laneName(laneServices) {
					t.Fatalf("a service call went under %q, not the services lane's name", n)
				}
			}

			gifs := newServiceStandIn(t)
			if r := gifAsk(http.MethodGet, gifs.srv.URL+"/search?q=cat", ""); strings.HasPrefix(r, "error") {
				t.Fatalf("gif: %s", r)
			}
			rem := gifs.remotes()
			if len(rem) != 1 {
				t.Fatalf("%d gif calls", len(rem))
			}
			n, viaTor := socks.nameOf(rem[0])
			if viaTor != (m == modePrivate) {
				t.Fatalf("in %s mode the gif call went through tor: %v", m, viaTor)
			}
			if viaTor && n == laneName(laneServices) {
				t.Fatal("the gif call shares the services lane's name")
			}
		})
	}
}

// a call made before tor is up waits for it, inside the call's own bound,
// and gets through once it is
func TestServicesWaitForTor(t *testing.T) {
	for _, m := range []string{modePrivate, modeFast} {
		t.Run(m, func(t *testing.T) {
			socks := newSocksStandIn(t)
			useStandIns(t, m, socks, newRelayStandIn(t, 0))
			useEdKey(t)
			svc := newServiceStandIn(t)
			oldBase := handleBase
			handleBase = svc.srv.URL
			defer func() { handleBase = oldBase }()
			mu.Lock()
			node := torNode
			torNode = nil
			mu.Unlock()
			nostrResetClient()
			go func() {
				time.Sleep(time.Second)
				mu.Lock()
				torNode = node
				mu.Unlock()
			}()
			start := time.Now()
			var wg sync.WaitGroup
			got := map[string]string{}
			var gotMu sync.Mutex
			for what, call := range map[string]func() string{
				"check":  func() string { return handleCheck("wren") },
				"search": func() string { return torPost(svc.srv.URL+"/handle/search", `{"q":"wren"}`) },
				"badge":  func() string { return torGetJSON(svc.srv.URL + "/receipt?id=1") },
			} {
				wg.Add(1)
				go func() {
					defer wg.Done()
					r := call()
					gotMu.Lock()
					got[what] = r
					gotMu.Unlock()
				}()
			}
			wg.Wait()
			for what, r := range got {
				if strings.HasPrefix(r, "error") {
					t.Fatalf("%s: %s", what, r)
				}
			}
			if took := time.Since(start); took < time.Second {
				t.Fatalf("the calls answered in %s, before tor was there", took)
			}
			for _, rem := range svc.remotes() {
				if _, ok := socks.nameOf(rem); !ok {
					t.Fatal("a call went out directly while tor was starting")
				}
			}
		})
	}
}

// a tor that never comes: the calls give up inside their bounds, saying it
// was tor, which the app shows as tor not ready yet. never a direct call
func TestServicesNeverGoDirect(t *testing.T) {
	socks := newSocksStandIn(t)
	useStandIns(t, modeFast, socks, newRelayStandIn(t, 0))
	useEdKey(t)
	svc := newServiceStandIn(t)
	oldBase, oldWait, oldSvc := handleBase, handleWait, servicesWait
	handleBase = svc.srv.URL
	handleWait = 600 * time.Millisecond
	servicesWait = 600 * time.Millisecond
	defer func() { handleBase, handleWait, servicesWait = oldBase, oldWait, oldSvc }()
	mu.Lock()
	node := torNode
	torNode = nil
	mu.Unlock()
	defer func() {
		mu.Lock()
		torNode = node
		mu.Unlock()
	}()
	nostrResetClient()
	start := time.Now()
	if r := handleCheck("wren"); !strings.HasPrefix(r, "error") {
		t.Fatalf("check: %s", r)
	}
	if took := time.Since(start); took > 2*time.Second {
		t.Fatalf("the check took %s past its bound", took)
	}
	for what, r := range map[string]string{
		"search": torPost(svc.srv.URL+"/handle/search", `{"q":"wren"}`),
		"badge":  torGetJSON(svc.srv.URL + "/receipt?id=1"),
	} {
		if !strings.HasPrefix(r, "error: tor client") {
			t.Fatalf("%s: %s", what, r)
		}
	}
	if took := time.Since(start); took > 4*time.Second {
		t.Fatalf("the calls took %s past their bounds", took)
	}
	if n := len(svc.remotes()); n != 0 {
		t.Fatalf("%d calls reached the service with no tor", n)
	}
}
