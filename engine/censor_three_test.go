// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torblocked && torblocked3

package main

import (
	"errors"
	"syscall"
	"testing"
)

// HALO_TOR_BLOCKED=3 starts at level 3, run with -tags torblocked,torblocked3
func TestCensorLevelThreeBuild(t *testing.T) {
	if censorLevel != 3 {
		t.Fatalf("level %d", censorLevel)
	}
	b, _ := parseBridgeLine(builtinBundled["obfs4"][0])
	for _, c := range [][2]string{{"obfs4", b.addr}, {"snowflake", "192.0.2.3:80"}, {"webtunnel", "192.0.2.4:443"}} {
		if err := censorPTDial(c[0], c[1]); !errors.Is(err, syscall.ECONNRESET) {
			t.Fatalf("%s got through: %v", c[0], err)
		}
	}
}
