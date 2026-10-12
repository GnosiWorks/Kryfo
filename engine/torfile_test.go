// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGetFileWholeOrNothing(t *testing.T) {
	gif := append([]byte("GIF89a"), bytes.Repeat([]byte{0, 1, 2}, 1000)...)
	var ct string
	var body []byte
	var status int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Kryfo") != "1" {
			http.Error(w, "app only", http.StatusForbidden)
			return
		}
		w.Header().Set("Content-Type", ct)
		if strings.HasSuffix(r.URL.Path, "/short") {
			// says more than it sends
			w.Header().Set("Content-Length", "99999")
		}
		w.WriteHeader(status)
		w.Write(body)
	}))
	defer srv.Close()
	dir := t.TempDir()
	path := filepath.Join(dir, "a.gif")

	ct, body, status = "image/gif", gif, 200
	if out := getFileWith(srv.Client(), srv.URL+"/m/x", path); out != "ok 3006" {
		t.Fatalf("got %q", out)
	}
	if b, _ := os.ReadFile(path); !bytes.Equal(b, gif) {
		t.Fatal("bytes differ, nul bytes and all")
	}

	for name, c := range map[string]struct {
		ct     string
		status int
		path   string
		size   int
	}{
		"html":      {"text/html", 200, "/m/x", 10},
		"not found": {"image/gif", 404, "/m/x", 10},
		"too big":   {"image/webp", 200, "/m/x", torFileMax + 1},
		"cut short": {"image/gif", 200, "/m/short", 10},
	} {
		os.Remove(path)
		ct, status, body = c.ct, c.status, bytes.Repeat([]byte{1}, c.size)
		out := getFileWith(srv.Client(), srv.URL+c.path, path)
		if !strings.HasPrefix(out, "error:") {
			t.Errorf("%s: %q", name, out)
		}
		if _, err := os.Stat(path); err == nil {
			t.Errorf("%s: a file was left", name)
		}
	}
	left, _ := os.ReadDir(dir)
	if len(left) != 0 {
		t.Fatalf("parts left behind: %v", left)
	}
}

// search and trending say they are the app's, on the gif lane and no other
func TestGifAsksOnItsOwnLane(t *testing.T) {
	var got []*http.Request
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got = append(got, r.Clone(r.Context()))
		if r.Header.Get("X-Kryfo") != "1" {
			http.Error(w, "app only", http.StatusForbidden)
			return
		}
		w.Write([]byte(`{"items":[]}`))
	}))
	defer srv.Close()
	lanes := 0
	old := gifClient
	gifClient = func() (*http.Client, error) {
		lanes++
		return srv.Client(), nil
	}
	defer func() { gifClient = old }()
	if out := gifAsk(http.MethodPost, srv.URL+"/gif/v1/search", `{"q":"seal"}`); out != `{"items":[]}` {
		t.Fatalf("search: %q", out)
	}
	if out := gifAsk(http.MethodGet, srv.URL+"/gif/v1/trending", ""); out != `{"items":[]}` {
		t.Fatalf("trending: %q", out)
	}
	if lanes != 2 || got[0].Header.Get("Content-Type") != "application/json" {
		t.Fatalf("lanes %d, type %q", lanes, got[0].Header.Get("Content-Type"))
	}
	if laneName(laneGifs) == laneName(laneServices) {
		t.Fatal("gifs and the services share a socks name")
	}
}

// an answer past the cap is an error, never the part that fits
func TestGifAskRefusesAnAnswerPastTheCap(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := gifAskMax
		if r.URL.Path == "/big" {
			n++
		}
		w.Write(bytes.Repeat([]byte("x"), n))
	}))
	defer srv.Close()
	old := gifClient
	gifClient = func() (*http.Client, error) { return srv.Client(), nil }
	defer func() { gifClient = old }()
	if out := gifAsk(http.MethodGet, srv.URL+"/big", ""); out != "error: read: too big" {
		t.Fatalf("past the cap: %d bytes", len(out))
	}
	if out := gifAsk(http.MethodGet, srv.URL+"/full", ""); len(out) != gifAskMax {
		t.Fatalf("at the cap: %d bytes", len(out))
	}
}
