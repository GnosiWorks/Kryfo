// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !android

package main

import (
	"bytes"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"sync/atomic"
	"testing"
)

func TestQuietLogGate(t *testing.T) {
	old := atomic.LoadInt32(&debugOn)
	t.Cleanup(func() { atomic.StoreInt32(&debugOn, old) })

	dir := t.TempDir()
	q := &quietLog{dir: func() string { return dir }}
	t.Cleanup(func() {
		if q.f != nil {
			q.f.Close()
		}
	})
	line := []byte("halo: args --Bridge obfs4 1.2.3.4:443 kryfo=" + ptToken + "\n")
	file := filepath.Join(dir, debugLogName)

	atomic.StoreInt32(&debugOn, 0)
	if n, err := q.Write(line); err != nil || n != len(line) {
		t.Fatalf("off: n=%d err=%v", n, err)
	}
	if _, err := os.Stat(file); !os.IsNotExist(err) {
		t.Fatalf("off made the file: %v", err)
	}

	atomic.StoreInt32(&debugOn, 1)
	if n, err := q.Write(line); err != nil || n != len(line) {
		t.Fatalf("on: n=%d err=%v", n, err)
	}
	got, err := os.ReadFile(file)
	if err != nil || len(got) == 0 {
		t.Fatalf("on wrote nothing: %v", err)
	}
	if strings.Contains(string(got), ptToken) {
		t.Fatalf("bridge not scrubbed: %q", got)
	}
	st, err := os.Stat(file)
	if err != nil || st.Mode().Perm() != 0600 {
		t.Fatalf("mode %v err %v", st.Mode().Perm(), err)
	}
}

func TestQuietLogLooseFile(t *testing.T) {
	old := atomic.LoadInt32(&debugOn)
	t.Cleanup(func() { atomic.StoreInt32(&debugOn, old) })
	atomic.StoreInt32(&debugOn, 1)

	dir := t.TempDir()
	file := filepath.Join(dir, debugLogName)
	if err := os.WriteFile(file, []byte("old run\n"), 0644); err != nil {
		t.Fatal(err)
	}
	q := &quietLog{dir: func() string { return dir }}
	t.Cleanup(func() {
		if q.f != nil {
			q.f.Close()
		}
	})
	q.Write([]byte("new run\n"))
	got, _ := os.ReadFile(file)
	if string(got) != "new run\n" {
		t.Fatalf("file %q", got)
	}
	st, _ := os.Stat(file)
	if st.Mode().Perm() != 0600 {
		t.Fatalf("mode %v", st.Mode().Perm())
	}
}

func TestQuietLogNoDir(t *testing.T) {
	old := atomic.LoadInt32(&debugOn)
	t.Cleanup(func() { atomic.StoreInt32(&debugOn, old) })
	atomic.StoreInt32(&debugOn, 1)
	q := &quietLog{dir: func() string { return "" }}
	if n, err := q.Write([]byte("x\n")); err != nil || n != 2 || q.f != nil {
		t.Fatalf("n=%d err=%v f=%v", n, err, q.f)
	}
}

// a fresh process, since other tests point the log elsewhere
func TestQuietLogNothingOnStderr(t *testing.T) {
	if os.Getenv("KRYFO_QUIET_CHILD") == "1" {
		quietChild()
		return
	}
	dir := t.TempDir()
	cmd := exec.Command(os.Args[0], "-test.run=^TestQuietLogNothingOnStderr$")
	cmd.Env = append(os.Environ(), "KRYFO_QUIET_CHILD=1", "KRYFO_QUIET_DIR="+dir)
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	if err := cmd.Run(); err != nil {
		t.Fatalf("child: %v\nstdout %q\nstderr %q", err, stdout.String(), stderr.String())
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr: %q", stderr.String())
	}
	if strings.Contains(stdout.String(), "secret line") {
		t.Fatalf("stdout: %q", stdout.String())
	}
	got, err := os.ReadFile(filepath.Join(dir, debugLogName))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(got), "secret line off") || !strings.Contains(string(got), "secret line on") {
		t.Fatalf("file: %q", got)
	}
}

func quietChild() {
	fail := func(msg string) {
		os.Stdout.WriteString("child: " + msg + "\n")
		os.Exit(3)
	}
	if _, ok := log.Writer().(*quietLog); !ok {
		fail("log writer is not quietLog")
	}
	if !slices.Contains(torArgs(), "--quiet") {
		fail("tor is not started quiet")
	}
	dir := os.Getenv("KRYFO_QUIET_DIR")
	mu.Lock()
	savedDataDir = dir
	mu.Unlock()

	atomic.StoreInt32(&debugOn, 0)
	log.Println("secret line off")
	libLog{}.Write([]byte("secret line off lib\n"))
	(&gatedWriter{}).Write([]byte("secret line off tor\n"))

	atomic.StoreInt32(&debugOn, 1)
	log.Println("secret line on")
	libLog{}.Write([]byte("secret line on lib\n"))
	(&gatedWriter{on: 1}).Write([]byte("secret line on tor\n"))
}
