// SPDX-License-Identifier: GPL-3.0-or-later
package main

// no default identity: nothing that seals, opens,
// listens or derives an address reads the main identity's key from the
// globals, and the forms that did are gone, so a call that forgets the
// identity does not compile. the globals are read only where the face is
// made, restored and handed out

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

func TestNoDefaultIdentity(t *testing.T) {
	gone := regexp.MustCompile(`\b(myXid|nip17Wrap|nip17Unwrap|nip17UnwrapStamped|nip17RcvAddress|nip17DeriveRole|nip17FirstContactKeys|nip17WrapFirstContact|nip17UnwrapFirstContact|nip17UnwrapFirstContactStamped)\(`)
	global := regexp.MustCompile(`\bmyXPriv\b`)
	entries, err := os.ReadDir(".")
	if err != nil {
		t.Fatal(err)
	}
	for _, e := range entries {
		n := e.Name()
		if !strings.HasSuffix(n, ".go") || strings.HasSuffix(n, "_test.go") {
			continue
		}
		b, err := os.ReadFile(n)
		if err != nil {
			t.Fatal(err)
		}
		src := string(b)
		for _, m := range gone.FindAllString(src, -1) {
			t.Errorf("%s: %s is a default-identity form", n, m)
		}
		if n == "bridge.go" {
			continue
		}
		if global.MatchString(src) {
			t.Errorf("%s reads the main key from the globals", n)
		}
	}
	// in bridge.go the key is read only by the face's own exports
	b, _ := os.ReadFile("bridge.go")
	var fn string
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "func ") {
			fn = line
		}
		if global.MatchString(line) && !strings.HasPrefix(line, "\tmyXPriv  [32]byte") {
			ok := false
			for _, f := range []string{"func HaloGenerateIdentity(", "func HaloRestoreIdentity(", "func HaloMyXPrivkey("} {
				if strings.HasPrefix(fn, f) {
					ok = true
				}
			}
			if !ok {
				t.Errorf("bridge.go: %q reads the main key in %q", strings.TrimSpace(line), fn)
			}
		}
	}
}
