// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"net"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
)

// the relay, gif and registry clients answer with the redirect itself and
// never go where it points
func TestLaneClientsFollowNoRedirect(t *testing.T) {
	var reached atomic.Int32
	other := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reached.Add(1)
	}))
	defer other.Close()
	first := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, other.URL+"/elsewhere", http.StatusFound)
	}))
	defer first.Close()
	clients := map[string]*http.Client{
		"tor lane": torLaneClient((&net.Dialer{}).DialContext),
		"direct":   directNostrClient(),
	}
	for name, c := range clients {
		resp, err := c.Get(first.URL)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		resp.Body.Close()
		if resp.StatusCode != http.StatusFound {
			t.Fatalf("%s: status %d", name, resp.StatusCode)
		}
	}
	if n := reached.Load(); n != 0 {
		t.Fatalf("a redirect was followed %d times", n)
	}
}
