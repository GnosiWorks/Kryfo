// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"os"
	"path/filepath"
	"testing"
)

// a start clears only what a dead process left in tor's folder: the lock,
// bine's torrc and control port files. the cached directory and the state
// file with the guards stay, so the next start reads kilobytes, not the
// whole directory again (tor_dircache_test.go measures it)
func TestStartKeepsTorsCache(t *testing.T) {
	dir := t.TempDir()
	keep := []string{"cached-certs", "cached-microdesc-consensus", "cached-microdescs",
		"cached-microdescs.new", "state", "keys"}
	gone := []string{"lock", "torrc-123", "control-port-456"}
	for _, n := range append(append([]string(nil), keep...), gone...) {
		if err := os.WriteFile(filepath.Join(dir, n), []byte("x"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	cleanTorRunFiles(dir)
	for _, n := range keep {
		if _, err := os.Stat(filepath.Join(dir, n)); err != nil {
			t.Errorf("%s went: %v", n, err)
		}
	}
	for _, n := range gone {
		if _, err := os.Stat(filepath.Join(dir, n)); err == nil {
			t.Errorf("%s is still there", n)
		}
	}
}
