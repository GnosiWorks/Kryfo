// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"testing"
)

// puts bridge lines in place with no mode, as the tests set them up
func setBridgeLines(raw string, on bool) string {
	good, bad, checks := sortBridgeLines(raw)
	lineChecksMu.Lock()
	lineChecks = checks
	lineChecksMu.Unlock()
	noteBridgeSecrets(good)
	dropSnowflakeClients()
	bridgeMu.Lock()
	bridgeList = good
	bridgeFails = map[string]bridgeFail{}
	bridgeOn = on && len(good) > 0
	enabled := bridgeOn
	bridgeMu.Unlock()
	noteLinesChanged()
	if !on || len(good) > 0 {
		modeSet.Store(true)
	}
	if enabled {
		if err := startPTListeners(); err != nil {
			return fmt.Sprintf("error: %v", err)
		}
	}
	if len(bad) > 0 {
		return fmt.Sprintf("ok: %d accepted, %d not understood", len(good), len(bad))
	}
	return fmt.Sprintf("ok: %d bridges", len(good))
}

// the old call for the lines is gone, so nothing outside a mode sets them
func TestNoOldBridgeCall(t *testing.T) {
	files, _ := filepath.Glob("*.go")
	re := regexp.MustCompile(`(?m)^//export HaloSetBridges$`)
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		if re.Match(b) {
			t.Fatalf("%s exports the old call", f)
		}
	}
}
