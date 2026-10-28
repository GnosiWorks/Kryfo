// SPDX-License-Identifier: GPL-3.0-or-later
package torexe

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestPath(t *testing.T) {
	got := Path(filepath.Join("app", "kryfo"))
	if want := filepath.Join("app", "kryfo", "tor", "tor.exe"); got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestArgsOwner(t *testing.T) {
	in := []string{"--DataDirectory", "d", "--SocksPort", "auto"}
	got := Args(4242, in)
	want := []string{"--DataDirectory", "d", "--SocksPort", "auto",
		"--PidFile", PidPath("d"), "--__OwningControllerProcess", "4242"}
	if strings.Join(got, " ") != strings.Join(want, " ") {
		t.Fatalf("got %v", got)
	}
	// bine's slice is left as it was
	if len(in) != 4 {
		t.Fatalf("input changed: %v", in)
	}
	got = Args(7, []string{"--SocksPort", "auto"})
	if strings.Contains(strings.Join(got, " "), "--PidFile") {
		t.Fatalf("pid file without a data dir: %v", got)
	}
}

func TestCheck(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "tor.exe")
	body := []byte("not really tor")
	if err := os.WriteFile(path, body, 0o600); err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(body)
	pin := hex.EncodeToString(sum[:])

	if err := Check(path, pin, false); err != nil {
		t.Fatalf("matching file refused: %v", err)
	}
	if err := Check(path, strings.ToUpper(pin), false); err != nil {
		t.Fatalf("upper-case pin refused: %v", err)
	}
	if err := Check(path, "", true); err != nil {
		t.Fatalf("dev build refused: %v", err)
	}
	if err := Check(path, "", false); err == nil || err.Error() != NoPin {
		t.Fatalf("release without a pin: %v", err)
	}

	other := sha256.Sum256([]byte("another tor"))
	if err := Check(path, hex.EncodeToString(other[:]), false); err == nil {
		t.Fatal("swapped tor.exe taken")
	}
	if err := Check(path, hex.EncodeToString(other[:]), true); err == nil {
		t.Fatal("swapped tor.exe taken in a dev build")
	}
	if err := Check(filepath.Join(dir, "missing.exe"), pin, false); err == nil {
		t.Fatal("missing tor.exe taken")
	}
}

func TestReadPid(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "tor.pid")
	if ReadPid(p) != 0 {
		t.Fatal("pid from a missing file")
	}
	for in, want := range map[string]int{
		"4242\n": 4242, "4242": 4242, "": 0, "-3\n": 0, "0\n": 0, "12ab\n": 0,
		strings.Repeat("1", 40): 0,
	} {
		if err := os.WriteFile(p, []byte(in), 0o600); err != nil {
			t.Fatal(err)
		}
		if got := ReadPid(p); got != want {
			t.Fatalf("%q: got %d, want %d", in, got, want)
		}
	}
}

func TestSameExe(t *testing.T) {
	a := filepath.Join("C:", "Users", "a", "Kryfo", "tor", "tor.exe")
	if !SameExe(a, a) || !SameExe(strings.ToUpper(a), a) {
		t.Fatal("own tor.exe not recognised")
	}
	if SameExe("", a) || SameExe(filepath.Join("C:", "Windows", "notepad.exe"), a) {
		t.Fatal("another program taken for tor.exe")
	}
}

// a release build without a pinned tor.exe stops before it builds anything
func TestBuildWindowsNeedsPin(t *testing.T) {
	if _, err := exec.LookPath("bash"); err != nil {
		t.Skip("no bash")
	}
	cmd := exec.Command("bash", "../build-windows.sh")
	cmd.Env = append(os.Environ(), "TOR_EXE=", "HALO_DEV=", "CC=/nonexistent/cc",
		"HALO_WINDOWS_OUT="+t.TempDir())
	out, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf("built without a pin: %s", out)
	}
	if !strings.Contains(string(out), "TOR_EXE") {
		t.Fatalf("not refused for the pin: %s", out)
	}
}

func TestEnvOwnOpenssl(t *testing.T) {
	dir := filepath.Join("app", "tor")
	in := []string{"PATH=x", "OPENSSL_CONF=C:\\var\\evil.cnf", "openssl_modules=C:\\evil",
		"Openssl_Engines=C:\\evil", "OPENSSL_CONF_INCLUDE=C:\\evil", "SystemRoot=C:\\Windows"}
	got := Env(in, dir)
	want := []string{"PATH=x", "SystemRoot=C:\\Windows",
		"OPENSSL_CONF=" + filepath.Join(dir, "openssl.cnf"),
		"OPENSSL_MODULES=" + dir, "OPENSSL_ENGINES=" + dir}
	if strings.Join(got, "|") != strings.Join(want, "|") {
		t.Fatalf("got %v", got)
	}
	if len(in) != 6 || in[1] != "OPENSSL_CONF=C:\\var\\evil.cnf" {
		t.Fatalf("input changed: %v", in)
	}
}
