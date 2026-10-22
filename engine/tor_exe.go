// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !android

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// tor as a separate tor.exe on windows, where go-libtor does not build. no
// windows tag here, so the tests run on the build host.

// tor\tor.exe next to the app, as the expert bundle lays it out
func torExePath(appDir string) string {
	return filepath.Join(appDir, "tor", "tor.exe")
}

func torPidPath(dataDir string) string {
	return filepath.Join(dataDir, "tor.pid")
}

// tor exits on its own once the app is gone, even when the app is killed
// and never gets to close it. the pid file lets the next start stop one
// that has not noticed yet.
func torExeArgs(pid int, args []string) []string {
	out := make([]string, 0, len(args)+4)
	out = append(out, args...)
	if d := torArgValue(args, "--DataDirectory"); d != "" {
		out = append(out, "--PidFile", torPidPath(d))
	}
	return append(out, "--__OwningControllerProcess", strconv.Itoa(pid))
}

func torArgValue(args []string, name string) string {
	for i := 0; i+1 < len(args); i++ {
		if args[i] == name {
			return args[i+1]
		}
	}
	return ""
}

// the pid in tor's pid file, 0 when there is none or it does not parse
func readTorPid(path string) int {
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
func sameExe(a, b string) bool {
	return a != "" && strings.EqualFold(filepath.Clean(a), filepath.Clean(b))
}

var errNoTorPin = errors.New("no tor.exe pin in this build")

// a tor.exe that is not the one the app was built with is not started. only
// a dev build runs without a pin.
func torExeCheck(path, want string, dev bool) error {
	if want == "" {
		if dev {
			return nil
		}
		return errNoTorPin
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
