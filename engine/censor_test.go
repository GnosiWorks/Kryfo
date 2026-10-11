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
		if kv := censorConf(false); kv != nil {
			t.Fatalf("setconf without the tag: %v", kv)
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
	// release.sh and every gradle build but the test app's look for the
	// censor's marker, with one script that says no when unsure
	on, _ := os.ReadFile("censor_on.go")
	scanSrc, _ := os.ReadFile("censor-scan.sh")
	rel, _ := os.ReadFile("../repro/release.sh")
	gradle, _ := os.ReadFile("../mobile/android/app/build.gradle.kts")
	if !strings.Contains(string(on), `censorMarker = "kryfo test censor build"`) ||
		!strings.Contains(string(scanSrc), "grep -aq 'kryfo test censor build'") {
		t.Error("the scan does not look for the censor's marker")
	}
	if !strings.Contains(string(rel), "censor-scan.sh") || !strings.Contains(string(rel), "unzip -l") {
		t.Error("release.sh does not scan the engines it ships")
	}
	if !strings.Contains(string(gradle), "censor-scan.sh") {
		t.Error("gradle does not scan the engine it packs")
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

// the scan says no to a test engine, to a missing one, and to none at all
func TestCensorScan(t *testing.T) {
	dir := t.TempDir()
	clean := filepath.Join(dir, "clean.so")
	dirty := filepath.Join(dir, "dirty.so")
	os.WriteFile(clean, []byte("\x7fELF an engine"), 0o644)
	os.WriteFile(dirty, []byte("\x7fELF censor: kryfo test censor build, tor is cut off"), 0o644)
	sh, _ := filepath.Abs("censor-scan.sh")
	for _, c := range []struct {
		files []string
		ok    bool
	}{
		{[]string{clean}, true},
		{[]string{clean, dirty}, false},
		{[]string{clean, filepath.Join(dir, "gone.so")}, false},
		{nil, false},
	} {
		err := exec.Command("bash", append([]string{sh}, c.files...)...).Run()
		if (err == nil) != c.ok {
			t.Errorf("%v: passed %v, want %v", c.files, err == nil, c.ok)
		}
	}
}
