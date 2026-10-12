// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torblocked && torblocked2

package main

import (
	"errors"
	"syscall"
	"testing"
)

// HALO_TOR_BLOCKED=2 starts at level 2, run with -tags torblocked,torblocked2
func TestCensorLevelTwoBuild(t *testing.T) {
	if censorLevel != 2 {
		t.Fatalf("level %d", censorLevel)
	}
	b, _ := parseBridgeLine(builtinBundled["obfs4"][0])
	if err := censorPTDial("obfs4", b.addr); !errors.Is(err, syscall.ECONNRESET) {
		t.Fatalf("a built-in obfs4 bridge got through: %v", err)
	}
}
