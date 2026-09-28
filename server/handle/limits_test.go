// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
)

func TestNewNamesArePaced(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	newNameLim = newLimiter(0.001, 2)
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	claim(t, c, srv.URL, "kite", o)
	out := post(t, c, srv.URL, "/handle/claim", map[string]string{
		"handle": "lark", "invite": invite, "pubkey": o.hexPub(),
		"sig": o.sign("kryfo-handle-v1:lark"),
	})
	if out["ok"] != false || out["error"] != "slow down" {
		t.Fatalf("third new name: %v", out)
	}
	// repointing a name you hold is not a new name
	claim(t, c, srv.URL, "wren", o)
}

func TestRegistryCeiling(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	old := maxHandles
	maxHandles = 1
	t.Cleanup(func() { maxHandles = old })
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	out := post(t, c, srv.URL, "/handle/claim", map[string]string{
		"handle": "kite", "invite": invite, "pubkey": o.hexPub(),
		"sig": o.sign("kryfo-handle-v1:kite"),
	})
	if out["error"] != "the registry is full" {
		t.Fatalf("over the ceiling: %v", out)
	}
	claim(t, c, srv.URL, "wren", o)
}

func TestUnchangedRepointWritesNothing(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	before, err := os.Stat(st.path)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(st.path, before.ModTime().Add(-3600e9), before.ModTime().Add(-3600e9)); err != nil {
		t.Fatal(err)
	}
	claim(t, c, srv.URL, "wren", o)
	after, _ := os.Stat(st.path)
	if !after.ModTime().Before(before.ModTime()) {
		t.Fatal("an unchanged repoint rewrote the registry")
	}
	// a changed bio is written
	out := post(t, c, srv.URL, "/handle/claim", map[string]string{
		"handle": "wren", "invite": invite, "bio": "new", "pubkey": o.hexPub(),
		"sig": o.sign("kryfo-handle-v1:wren"),
	})
	if out["ok"] != true {
		t.Fatal(out)
	}
	if e, _ := st.get("wren"); e.Bio != "new" {
		t.Fatalf("bio not written: %q", e.Bio)
	}
}

func TestWritesAreLimited(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	writeLim = newLimiter(0.001, 1)
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	for _, path := range []string{"/handle/claim", "/handle/release", "/handle/listing"} {
		out := post(t, c, srv.URL, path, map[string]string{
			"handle": "wren", "invite": invite, "pubkey": o.hexPub(),
			"sig": o.sign("kryfo-handle-v1:wren"),
		})
		if out["error"] != "slow down" {
			t.Fatalf("%s over the limit: %v", path, out)
		}
	}
}

func TestReadsAreLimited(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	claim(t, c, srv.URL, "wren", newOwner(t))
	readLim = newLimiter(0.001, 1)
	get := func(path string) (int, string) {
		resp, err := c.Get(srv.URL + path)
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		b, _ := io.ReadAll(resp.Body)
		return resp.StatusCode, string(b)
	}
	if code, _ := get("/@wren"); code != http.StatusOK {
		t.Fatalf("first read: %d", code)
	}
	if code, body := get("/@wren"); code != http.StatusTooManyRequests || !strings.Contains(body, "try again") {
		t.Fatalf("page over the limit: %d", code)
	}
	if code, _ := get("/.well-known/kryfo.json?name=wren"); code != http.StatusTooManyRequests {
		t.Fatalf("lookup over the limit: %d", code)
	}
	// the check answers in plain text, so nothing reads it as taken
	resp, err := c.Post(srv.URL+"/handle/check", "application/json", strings.NewReader(`{"h":"kite"}`))
	if err != nil {
		t.Fatal(err)
	}
	b, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusTooManyRequests || strings.Contains(string(b), "free") {
		t.Fatalf("check over the limit: %d %s", resp.StatusCode, b)
	}
}
