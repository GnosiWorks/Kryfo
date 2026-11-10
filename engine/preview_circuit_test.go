// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
)

// each preview leaves on a circuit of its own and keeps no connection, so
// two previews never share an exit
func TestPreviewsTakeACircuitEach(t *testing.T) {
	socks := newSocksStandIn(t)
	useStandIns(t, modeBalanced, socks)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("<title>x</title>"))
	}))
	defer srv.Close()
	for range 3 {
		if got := torGetStrict(srv.URL); got != "<title>x</title>" {
			t.Fatalf("preview: %q", got)
		}
	}
	socks.mu.Lock()
	defer socks.mu.Unlock()
	// nothing else dials here: every name is a preview's
	names := 0
	for n, c := range socks.byName {
		if n == "" {
			t.Error("a preview went with no name")
		}
		names++
		if c != 1 {
			t.Errorf("%d streams under %s, want one", c, n)
		}
	}
	if names != 3 {
		t.Fatalf("three previews went under %d names: %v", names, socks.byName)
	}
}

func TestAPreviewNeverLeavesHttps(t *testing.T) {
	req := func(u string) *http.Request {
		p, _ := url.Parse(u)
		return &http.Request{URL: p}
	}
	for _, c := range []struct {
		to  string
		via []string
		ok  bool
	}{
		{"https://b.example/", []string{"https://a.example/"}, true},
		{"https://b.example/", []string{"http://a.example/"}, true},
		{"http://b.example/", []string{"http://a.example/"}, true},
		{"http://b.example/", []string{"https://a.example/"}, false},
		{"http://c.example/", []string{"http://a.example/", "https://b.example/"}, false},
		{"https://d.example/", []string{"https://a.example/", "https://b.example/", "https://c.example/"}, false},
	} {
		var via []*http.Request
		for _, v := range c.via {
			via = append(via, req(v))
		}
		if err := previewRedirect(req(c.to), via); (err == nil) != c.ok {
			t.Errorf("%v -> %s: %v", c.via, c.to, err)
		}
	}
}
