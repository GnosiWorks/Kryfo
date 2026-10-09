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
