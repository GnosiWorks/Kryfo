// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// a child that names the file and panics in a goroutine of its own: what
// ended it is in the file, and nothing of it needs stderr
func TestCrashTraceChild(t *testing.T) {
	path := os.Getenv("KRYFO_CRASH_CHILD")
	if path == "" {
		t.Skip("child only")
	}
	if !crashTraceTo(path) {
		t.Fatal("not taken")
	}
	done := make(chan struct{})
	go func() {
		defer close(done)
		var m map[string]int
		m["x"] = 1
	}()
	<-done
}

func TestCrashTraceWritesThePanic(t *testing.T) {
	path := filepath.Join(t.TempDir(), "engine-crash.txt")
	cmd := exec.Command(os.Args[0], "-test.run=^TestCrashTraceChild$")
	cmd.Env = append(os.Environ(), "KRYFO_CRASH_CHILD="+path)
	cmd.Stderr = nil
	cmd.Stdout = nil
	if err := cmd.Run(); err == nil {
		t.Fatal("the child should have ended on its panic")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("no crash file: %v", err)
	}
	s := string(b)
	if !strings.Contains(s, "panic: assignment to entry in nil map") ||
		!strings.Contains(s, "TestCrashTraceChild") {
		t.Fatalf("the crash file says: %q", s)
	}
	if fi, _ := os.Stat(path); fi.Mode().Perm() != 0600 {
		t.Fatalf("mode %v", fi.Mode().Perm())
	}
}

func TestCrashTraceNoPath(t *testing.T) {
	if crashTraceTo("") {
		t.Fatal("an empty path is taken")
	}
	if crashTraceTo(filepath.Join(t.TempDir(), "no", "such", "dir", "f")) {
		t.Fatal("a file that cannot be made is taken")
	}
}
