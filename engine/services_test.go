// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/ed25519"
	"net/http"
	"net/http/httptest"
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

// the services lane never takes a route's client, even one cached for its
// own lane name: a mode switch under a call must not hand it a direct one
func TestServicesNeverTakeTheRouteClient(t *testing.T) {
	socks := newSocksStandIn(t)
	useStandIns(t, modePrivate, socks, newRelayStandIn(t, 0))
	svc := newServiceStandIn(t)
	nostrResetClient()
	var took int
	cachedNostrClientMu.Lock()
	cachedNostrClients[laneServices] = &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		took++
		return http.DefaultTransport.RoundTrip(r)
	})}
	cachedNostrClientMu.Unlock()
	if r := torGetJSON(svc.srv.URL + "/receipt?id=1"); strings.HasPrefix(r, "error") {
		t.Fatal(r)
	}
	if took != 0 {
		t.Fatal("a services call went out on the route's client")
	}
	for _, rem := range svc.remotes() {
		if n, ok := socks.nameOf(rem); !ok || n != laneName(laneServices) {
			t.Fatal("a services call did not go through tor under its lane's name")
		}
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

// a registry answer that points elsewhere is not followed
func TestServicesFollowNoRedirect(t *testing.T) {
	for _, m := range []string{modePrivate, modeFast} {
		t.Run(m, func(t *testing.T) {
			socks := newSocksStandIn(t)
			useStandIns(t, m, socks, newRelayStandIn(t, 0))
			useEdKey(t)
			other := newServiceStandIn(t)
			reg := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				http.Redirect(w, r, other.srv.URL+r.URL.Path, http.StatusFound)
			}))
			defer reg.Close()
			oldBase := handleBase
			handleBase = reg.URL
			defer func() { handleBase = oldBase }()
			for what, r := range serviceCalls(reg.URL) {
				if !strings.HasPrefix(r, "error") {
					t.Fatalf("%s took a redirect as an answer: %s", what, r)
				}
			}
			if n := len(other.remotes()); n != 0 {
				t.Fatalf("%d calls followed the redirect", n)
			}
		})
	}
}
