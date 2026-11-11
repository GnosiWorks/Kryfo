// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"crypto/ed25519"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// a stand-in registry on [h], the handle calls pointed at it, a key to sign
// with and short waits. undone at the end of the test
func standInRegistry(t *testing.T, h http.HandlerFunc) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(h)
	wasBase, wasHTTP, wasWait, wasBack, wasUp, wasNew :=
		handleBase, handleHTTP, handleWait, handleBackoff, handleTorUp, handleNewCircuit
	handleBase = srv.URL
	handleHTTP = func() (*http.Client, error) { return srv.Client(), nil }
	handleWait = 5 * time.Second
	handleBackoff = []time.Duration{10 * time.Millisecond, 20 * time.Millisecond}
	handleTorUp = func() bool { return true }
	handleNewCircuit = func() {}
	_, priv, _ := ed25519.GenerateKey(nil)
	mu.Lock()
	key := myEdPriv
	myEdPriv = priv
	mu.Unlock()
	t.Cleanup(func() {
		srv.Close()
		handleBase, handleHTTP, handleWait, handleBackoff, handleTorUp, handleNewCircuit =
			wasBase, wasHTTP, wasWait, wasBack, wasUp, wasNew
		mu.Lock()
		myEdPriv = key
		mu.Unlock()
	})
	return srv
}

// the connection is cut before any answer, as a stalled exit does
func cut(w http.ResponseWriter) {
	c, _, err := w.(http.Hijacker).Hijack()
	if err == nil {
		c.Close()
	}
}

// the registry's limits are for everyone together: a full bucket is said as
// busy, not as a registry out of reach
func TestHandleBusyIsSaid(t *testing.T) {
	var hits atomic.Int32
	standInRegistry(t, func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		if r.URL.Path == "/handle/check" {
			// what server/handle answers: plain text
			http.Error(w, "slow down", http.StatusTooManyRequests)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusTooManyRequests)
		w.Write([]byte(`{"ok":false,"error":"slow down"}`))
	})
	if r := handleCheck("wren"); r != "error: busy" {
		t.Fatalf("check: %s", r)
	}
	if r := handleClaim("wren", "kryfo://x", ""); r != "error: busy" {
		t.Fatalf("claim: %s", r)
	}
	// a busy registry is not asked again at once
	if n := hits.Load(); n != 2 {
		t.Fatalf("%d asks", n)
	}
}

// a read cut short on the way is asked again on a new circuit
func TestHandleCheckTriesAgain(t *testing.T) {
	var hits, renewed atomic.Int32
	standInRegistry(t, func(w http.ResponseWriter, r *http.Request) {
		if hits.Add(1) == 1 {
			cut(w)
			return
		}
		w.Write([]byte(`{"free":true}`))
	})
	handleNewCircuit = func() { renewed.Add(1) }
	if r := handleCheck("wren"); r != "free" {
		t.Fatal(r)
	}
	if hits.Load() != 2 || renewed.Load() != 1 {
		t.Fatalf("%d asks, %d new circuits", hits.Load(), renewed.Load())
	}
}

// a registry that never answers is asked a few times, inside the bound
func TestHandleTriesAreBounded(t *testing.T) {
	var hits atomic.Int32
	standInRegistry(t, func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		cut(w)
	})
	start := time.Now()
	r := handleCheck("wren")
	if !strings.HasPrefix(r, "error: ") || r == "error: busy" || r == "error: no tor" {
		t.Fatal(r)
	}
	if n := hits.Load(); n != 3 {
		t.Fatalf("%d asks", n)
	}
	if took := time.Since(start); took > 2*time.Second {
		t.Fatalf("took %s", took)
	}
	// a gateway in front of a registry that is restarting is asked again too
	hits.Store(0)
	standInRegistry(t, func(w http.ResponseWriter, r *http.Request) {
		if hits.Add(1) < 3 {
			w.WriteHeader(http.StatusBadGateway)
			return
		}
		w.Write([]byte(`{"free":false}`))
	})
	if r := handleCheck("wren"); r != "taken" {
		t.Fatal(r)
	}
}

// a claim that reached the registry is not sent twice: the answer may be
// all that was lost
func TestHandleClaimSentOnce(t *testing.T) {
	var hits atomic.Int32
	standInRegistry(t, func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		buf := make([]byte, 1<<10)
		r.Body.Read(buf)
		cut(w)
	})
	// said as no answer: the app looks to see whether it landed
	if r := handleClaim("wren", "kryfo://x", ""); !strings.HasPrefix(r, "error: no answer: ") {
		t.Fatal(r)
	}
	if n := hits.Load(); n != 1 {
		t.Fatalf("%d claims sent", n)
	}
}

// a claim whose connection never got made goes again: nothing was sent
func TestHandleClaimTriesAgainUnsent(t *testing.T) {
	var dials atomic.Int32
	srv := standInRegistry(t, func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"ok":true}`))
	})
	handleHTTP = func() (*http.Client, error) {
		c := srv.Client()
		tr := c.Transport.(*http.Transport).Clone()
		dial := tr.DialContext
		tr.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
			if dials.Add(1) == 1 {
				return nil, errors.New("connection refused")
			}
			return dial(ctx, network, addr)
		}
		return &http.Client{Transport: tr}, nil
	}
	if r := handleClaim("wren", "kryfo://x", ""); r != "ok" {
		t.Fatal(r)
	}
	if n := dials.Load(); n != 2 {
		t.Fatalf("%d dials", n)
	}
}

// tor that never carries inside the bound is named, not the registry
func TestHandleSaysNoTor(t *testing.T) {
	standInRegistry(t, func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"free":true}`))
	})
	release := make(chan struct{})
	defer close(release)
	handleHTTP = func() (*http.Client, error) {
		<-release
		return nil, nil
	}
	handleTorUp = func() bool { return false }
	handleWait = 200 * time.Millisecond
	start := time.Now()
	for name, call := range map[string]func() string{
		"check": func() string { return handleCheck("wren") },
		"claim": func() string { return handleClaim("wren", "kryfo://x", "") },
	} {
		if r := call(); r != "error: no tor" {
			t.Fatalf("%s: %s", name, r)
		}
	}
	if took := time.Since(start); took > 2*time.Second {
		t.Fatalf("took %s", took)
	}
}

// sockets that take their time to close
type slowClose struct {
	http.RoundTripper
	closing, closed chan struct{}
}

func (s *slowClose) CloseIdleConnections() {
	close(s.closing)
	<-s.closed
}

// a new circuit closes the old client's sockets, and after every lock is
// let go: no other lane waits on them meanwhile
func TestHandleNewCircuitLetsGoFirst(t *testing.T) {
	key := "tor:" + laneOwnHandle
	tr := &slowClose{http.DefaultTransport, make(chan struct{}), make(chan struct{})}
	cachedNostrClientMu.Lock()
	was := cachedNostrClients[key]
	cachedNostrClients[key] = &http.Client{Transport: tr}
	cachedNostrClientMu.Unlock()
	t.Cleanup(func() {
		cachedNostrClientMu.Lock()
		if was != nil {
			cachedNostrClients[key] = was
		}
		cachedNostrClientMu.Unlock()
	})
	name := laneName(laneOwnHandle)
	done := make(chan struct{})
	go func() {
		handleNewCircuit()
		close(done)
	}()
	select {
	case <-tr.closing:
	case <-time.After(5 * time.Second):
		t.Fatal("the old client's sockets were never closed")
	}
	// the old sockets are still closing: the clients stay free to take
	if !cachedNostrClientMu.TryLock() {
		close(tr.closed)
		t.Fatal("the clients were held while the old sockets closed")
	}
	_, kept := cachedNostrClients[key]
	cachedNostrClientMu.Unlock()
	close(tr.closed)
	<-done
	if kept {
		t.Fatal("the old client was kept")
	}
	if laneName(laneOwnHandle) == name {
		t.Fatal("the lane kept its socks name")
	}
}
