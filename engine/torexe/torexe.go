// SPDX-License-Identifier: GPL-3.0-or-later
// tor as a separate tor.exe on windows, where go-libtor does not build. a
// package of its own, so the android and linux engines never link it.
package torexe

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
)

// tor\tor.exe next to the app, as the expert bundle lays it out
func Path(appDir string) string {
	return filepath.Join(appDir, "tor", "tor.exe")
}

func PidPath(dataDir string) string {
	return filepath.Join(dataDir, "tor.pid")
}

// tor exits on its own once the app is gone, even when the app is killed
// and never gets to close it. the pid file lets the next start stop one
// that has not noticed yet.
func Args(pid int, args []string) []string {
	out := make([]string, 0, len(args)+6)
	out = append(out, args...)
	if d := ArgValue(args, "--DataDirectory"); d != "" {
		out = append(out, "--PidFile", PidPath(d))
	}
	// warnings and errors to stdout, which only the engine reads (Tail)
	out = append(out, "--Log", "warn stdout")
	return append(out, "--__OwningControllerProcess", strconv.Itoa(pid))
}

func ArgValue(args []string, name string) string {
	for i := 0; i+1 < len(args); i++ {
		if args[i] == name {
			return args[i+1]
		}
	}
	return ""
}

// the pid in tor's pid file, 0 when there is none or it does not parse
func ReadPid(path string) int {
	b, err := os.ReadFile(path)
	if err != nil || len(b) > 32 {
		return 0
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(b)))
	if err != nil || pid <= 0 {
		return 0
	}
	return pid
}

// only a process running our own tor.exe is stopped, never whatever took
// the pid since
func SameExe(a, b string) bool {
	return a != "" && strings.EqualFold(filepath.Clean(a), filepath.Clean(b))
}

const NoPin = "no tor.exe pin in this build"

// a tor.exe that is not the one the app was built with is not started. only
// a dev build runs without a pin.
func Check(path, want string, dev bool) error {
	if want == "" {
		if dev {
			return nil
		}
		return errors.New(NoPin)
	}
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return err
	}
	if got := hex.EncodeToString(h.Sum(nil)); got != strings.ToLower(want) {
		return fmt.Errorf("tor.exe does not match the build: %s", got)
	}
	return nil
}

// the empty openssl config the installer puts beside tor.exe
func ConfPath(torDir string) string {
	return filepath.Join(torDir, "openssl.cnf")
}

// tor.exe's openssl was built with a unix OPENSSLDIR, which windows reads
// as a folder at the root of the drive that any user can make, and tor
// loads its config from there. so tor gets its own config, modules and
// engines folder, ours, and no other OPENSSL_ setting gets through.
func Env(environ []string, torDir string) []string {
	out := make([]string, 0, len(environ)+3)
	for _, kv := range environ {
		if strings.HasPrefix(strings.ToUpper(kv), "OPENSSL_") {
			continue
		}
		out = append(out, kv)
	}
	return append(out,
		"OPENSSL_CONF="+ConfPath(torDir),
		"OPENSSL_MODULES="+torDir,
		"OPENSSL_ENGINES="+torDir)
}

// tor.exe's process dacl: the user's other processes may wait on it, ask
// its name, end it and put it in a job (which kryfo.exe does so tor ends
// with it), never read its memory or dump it. the owner rights entry keeps
// the owner from rewriting the dacl
func ProcessSDDL(userSID string) string {
	return "D:P(A;;0x101101;;;OW)(A;;0x101101;;;" + userSID + ")"
}

// the tor started on dataDir, told by its command line
func ForDataDir(args []string, dataDir string) bool {
	d := ArgValue(args, "--DataDirectory")
	return d != "" && dataDir != "" && strings.EqualFold(winPath(d), winPath(dataDir))
}

// either slash, no trailing separator
func winPath(s string) string {
	return strings.TrimRight(strings.ReplaceAll(s, "/", `\`), `\`)
}

// tor's warnings and errors go to stdout (Args), and the last of them are
// kept in memory to tell why a start failed. never written anywhere
type Tail struct {
	mu    sync.Mutex
	lines []string
	part  []byte
}

const tailLines = 32

func (t *Tail) Write(p []byte) (int, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.part = append(t.part, p...)
	for {
		i := bytes.IndexByte(t.part, '\n')
		if i < 0 {
			break
		}
		t.add(string(bytes.TrimRight(t.part[:i], "\r")))
		t.part = t.part[i+1:]
	}
	if len(t.part) > 4096 {
		t.add(string(t.part))
		t.part = nil
	}
	return len(p), nil
}

func (t *Tail) add(line string) {
	t.lines = append(t.lines, line)
	if len(t.lines) > tailLines {
		t.lines = t.lines[len(t.lines)-tailLines:]
	}
}

func (t *Tail) Lines() []string {
	t.mu.Lock()
	defer t.mu.Unlock()
	return append(append([]string(nil), t.lines...), string(t.part))
}

// why tor ended before it was up, from its last lines, in words the app's
// error line can carry. nothing of tor's own text, which may name addresses
func Reason(lines []string, exitCode uint32) string {
	has := func(s string) bool {
		for _, l := range lines {
			if strings.Contains(l, s) {
				return true
			}
		}
		return false
	}
	switch {
	case has("another Tor process is running with the same data directory"):
		return "another tor holds the data folder"
	case has("Could not bind to"), has("Failed to bind one of the listener ports"):
		return "a port tor needs is in use"
	case has("for locking"):
		return "tor cannot open its lock in the data folder"
	case has("Reading config failed"), has("Failed to parse/validate config"):
		return "tor refused its options"
	}
	return fmt.Sprintf("tor exited with code %d", exitCode)
}

// why tor.exe did not start at all. errno 5 is access denied, 2 and 3 a
// missing file or folder, 1260 a policy block
func StartReason(errno uintptr) string {
	switch errno {
	case 5:
		return "windows refused to start tor.exe (access denied)"
	case 2, 3:
		return "tor.exe is missing"
	case 1260:
		return "a policy blocks tor.exe"
	}
	return fmt.Sprintf("tor.exe did not start (error %d)", errno)
}
