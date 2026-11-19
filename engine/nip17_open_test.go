// SPDX-License-Identifier: GPL-3.0-or-later
package main

import "testing"

// an opener that falls over gives an error and nothing else
func TestUnwrapGuardedTakesAFall(t *testing.T) {
	out, err := unwrapGuarded(func() (string, error) {
		var b []byte
		return string(b[0:1]), nil
	})
	if err == nil || out != "" {
		t.Fatalf("got %q, %v", out, err)
	}
	out, err = unwrapGuarded(func() (string, error) { return "ok", nil })
	if err != nil || out != "ok" {
		t.Fatalf("got %q, %v", out, err)
	}
}
