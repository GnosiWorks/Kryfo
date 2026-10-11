// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// the censor is a test build's alone. this build has none, the scripts a
// release comes from never ask for it, build.sh refuses it outside the
// test app, and in any other app the test engine leaves it off.
func TestCensorNeverInRelease(t *testing.T) {
	if !censorBuild {
		if a := censorTorArgs(); a != nil {
			t.Fatalf("tor args without the tag: %v", a)
		}
		if err := censorPTDial("obfs4", "192.0.2.1:443"); err != nil {
			t.Fatalf("a dial cut without the tag: %v", err)
		}
	}
	for proc, want := range map[string]bool{
		"app.kryfo":                false,
		"app.kryfo:remote":         false,
		"app.kryfo.bridgetest":     true,
		"app.kryfo.bridgetest.bad": false,
		"org.other.bridgetest":     false,
		"":                         false,
	} {
		if got := censorAllowed(proc, "android"); got != want {
			t.Errorf("%q on android: %v, want %v", proc, got, want)
		}
	}
	// what a release is built with
	for _, f := range []string{"build.sh", "../repro/build-repro.sh", "../repro/engine-only.sh",
		"../repro/release.sh", "../repro/verify.sh", "../fdroiddata/app.kryfo.yml"} {
		b, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		s := string(b)
		if f != "build.sh" && (strings.Contains(s, "torblocked") || strings.Contains(s, "HALO_TOR_BLOCKED") || strings.Contains(s, "HALO_TEST_ID")) {
			t.Errorf("%s asks for the censor", f)
		}
	}
	// build.sh says no before it looks for anything
	sh, _ := filepath.Abs("build.sh")
	cmd := exec.Command("bash", sh)
	cmd.Env = append(os.Environ(), "HALO_TOR_BLOCKED=1", "HALO_TEST_ID=", "JNI_LIBS_DIR="+t.TempDir())
	out, err := cmd.CombinedOutput()
	if err == nil || !strings.Contains(string(out), "HALO_TOR_BLOCKED needs HALO_TEST_ID=1") {
		t.Fatalf("build.sh took the censor outside the test app: %v %s", err, out)
	}
}
