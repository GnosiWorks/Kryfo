// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/sha256"
	"encoding/base64"
	"io"
	"regexp"
	"strings"
	"testing"
)

// every page's style block is the one the csp names, and nothing else
// inline gets through: no unsafe-inline, no style attribute. only the
// invite page has a script, the one its csp names
func TestPagesMatchTheirCSP(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	claim(t, c, srv.URL, "wren", newOwner(t))
	for _, path := range []string{"/@wren", "/@nobody", "/", "/i", "/i?" + goodQuery} {
		resp, err := c.Get(srv.URL + path)
		if err != nil {
			t.Fatal(err)
		}
		b, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		pol := resp.Header.Get("Content-Security-Policy")
		if strings.Contains(pol, "unsafe") {
			t.Fatalf("%s: %s", path, pol)
		}
		scripts := scriptOf(string(b))
		if strings.HasPrefix(path, "/i") {
			sum := sha256.Sum256([]byte(scripts[0]))
			if len(scripts) != 1 || !strings.Contains(pol, "script-src 'sha256-"+base64.StdEncoding.EncodeToString(sum[:])+"'") {
				t.Fatalf("%s: the script is not the one the csp names", path)
			}
		} else if len(scripts) != 0 || strings.Contains(pol, "script-src") {
			t.Fatalf("%s: a script: %s", path, pol)
		}
		m := regexp.MustCompile(`(?s)<style>(.*?)</style>`).FindAllStringSubmatch(string(b), -1)
		if len(m) != 1 {
			t.Fatalf("%s: %d style blocks", path, len(m))
		}
		sum := sha256.Sum256([]byte(m[0][1]))
		if !strings.Contains(pol, "'sha256-"+base64.StdEncoding.EncodeToString(sum[:])+"'") {
			t.Fatalf("%s: the style block is not the one the csp names", path)
		}
		if strings.Contains(string(b), " style=") {
			t.Fatalf("%s: a style attribute", path)
		}
	}
}
