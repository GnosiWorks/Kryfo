// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"testing"
)

// runners read the data dir while a start sets it: tor starts after the
// lanes when the app opens, and later still in a mode that sleeps
func TestDataDirSetWhileRunnersRead(t *testing.T) {
	old := savedDataDir()
	t.Cleanup(func() { setSavedDataDir(old) })
	setSavedDataDir("")
	dir := t.TempDir()
	const rcv = "00112233445566778899aabbccddeeff"
	done := make(chan struct{})
	go func() {
		defer close(done)
		for i := 0; i < 200; i++ {
			for _, p := range []string{heardFile(rcv), seenOf(addressFiles(rcv))} {
				if p != "" && !strings.HasPrefix(p, dir+"/") {
					t.Errorf("a file outside the data dir: %q", p)
					return
				}
			}
		}
	}()
	setSavedDataDir(dir)
	<-done
	if p := heardFile(rcv); p != dir+"/nostr_heard_0011223344556677" {
		t.Fatalf("heard file %q", p)
	}
}

func seenOf(seen, _ string) string { return seen }
