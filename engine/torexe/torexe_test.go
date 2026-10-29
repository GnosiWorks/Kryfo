// SPDX-License-Identifier: GPL-3.0-or-later
package torexe

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
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
		"--PidFile", PidPath("d"), "--Log", "warn stdout", "--__OwningControllerProcess", "4242"}
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

func TestProcessSDDL(t *testing.T) {
	got := ProcessSDDL("S-1-5-21-1-2-3-1001")
	want := "D:P(A;;0x101101;;;OW)(A;;0x101101;;;S-1-5-21-1-2-3-1001)"
	if got != want {
		t.Fatalf("got %q", got)
	}
	// synchronize, query limited information, set quota (a job) and
	// terminate. no vm read, no duplicate handle, no create thread
	if 0x101101 != 0x00100000|0x1000|0x0100|0x0001 {
		t.Fatal("rights")
	}
	if 0x101101&(0x0010|0x0040|0x0002|0x0020|0x0008) != 0 {
		t.Fatal("memory or thread rights given")
	}
}

func TestForDataDir(t *testing.T) {
	ours := `C:\Users\a\AppData\Local\Kryfo\tmp\engine/tor`
	for _, args := range [][]string{
		{"--DataDirectory", ours, "--quiet"},
		{"-f", "x", "--DataDirectory", `c:\users\A\appdata\local\kryfo\tmp\engine\tor\`},
	} {
		if !ForDataDir(args, ours) {
			t.Fatalf("own tor not found: %v", args)
		}
	}
	for _, args := range [][]string{
		{"--DataDirectory", `C:\Users\a\Desktop\Tor Browser\Data\Tor`},
		{"--DataDirectory", ours + "2"},
		{"-f", ours},
		{"--DataDirectory"},
		nil,
	} {
		if ForDataDir(args, ours) {
			t.Fatalf("another tor taken for ours: %v", args)
		}
	}
	if ForDataDir([]string{"--DataDirectory", ours}, "") {
		t.Fatal("matched an empty folder")
	}
}

func TestTailKeepsTheLast(t *testing.T) {
	var tl Tail
	for i := 0; i < 50; i++ {
		fmt.Fprintf(&tl, "line %d\r\n", i)
	}
	tl.Write([]byte("half"))
	got := tl.Lines()
	if len(got) != tailLines+1 || got[0] != "line 18" || got[tailLines-1] != "line 49" ||
		got[tailLines] != "half" {
		t.Fatalf("got %q", got)
	}
	var long Tail
	long.Write(bytes.Repeat([]byte("x"), 5000))
	if l := long.Lines(); len(l) != 2 || len(l[0]) != 5000 || l[1] != "" {
		t.Fatalf("an endless line is not cut: %d", len(l))
	}
}

func TestReason(t *testing.T) {
	for want, line := range map[string]string{
		"another tor holds the data folder":           "Oct 29 [warn] It looks like another Tor process is running with the same data directory.  Waiting 5 seconds to see if it goes away.",
		"a port tor needs is in use":                  "[warn] Could not bind to 127.0.0.1:9150: Address already in use [WSAEADDRINUSE ]. Is Tor already running?",
		"tor cannot open its lock in the data folder": `[warn] Couldn't open "C:\x\lock" for locking: Permission denied`,
		"tor refused its options":                     "[err] Reading config failed--see warnings above.",
	} {
		if got := Reason([]string{"[notice] hello", line}, 1); got != want {
			t.Fatalf("%q: got %q", line, got)
		}
	}
	if got := Reason(nil, 3); got != "tor exited with code 3" {
		t.Fatalf("got %q", got)
	}
	// tor's own text never reaches the reason
	if got := Reason([]string{"Could not bind to 10.1.2.3:443"}, 1); strings.Contains(got, "10.1") {
		t.Fatalf("an address got through: %q", got)
	}
}

func TestStartReason(t *testing.T) {
	if !strings.Contains(StartReason(5), "access denied") || StartReason(2) != "tor.exe is missing" ||
		!strings.Contains(StartReason(1260), "policy") || !strings.Contains(StartReason(87), "87") {
		t.Fatal("start reasons")
	}
}
