// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/halo/engine/agefile"
)

func TestAgeByPathRoundTrip(t *testing.T) {
	dir := t.TempDir()
	in := filepath.Join(dir, "notes.txt")
	plain := bytes.Repeat([]byte("a plain line\n"), 5000)
	if err := os.WriteFile(in, plain, 0o600); err != nil {
		t.Fatal(err)
	}
	locked := filepath.Join(dir, "notes.txt.age")
	if err := ageLockPath(in, locked, "four plain words here"); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(locked)
	if !bytes.HasPrefix(got, []byte("age-encryption.org/v1\n")) || bytes.Contains(got, []byte("a plain line")) {
		t.Fatal("not an age file")
	}
	if st, _ := os.Stat(locked); st.Mode().Perm()&0o077 != 0 {
		t.Fatalf("open to others: %v", st.Mode())
	}

	if err := ageOpenBeginPath(locked, "wrong words"); !errors.Is(err, agefile.ErrWrongPassword) {
		t.Fatalf("wrong password: %v", err)
	}
	if err := ageOpenBeginPath(locked, "four plain words here"); err != nil {
		t.Fatal(err)
	}
	out := filepath.Join(dir, "back.txt")
	if err := ageOpenFinishPath(out); err != nil {
		t.Fatal(err)
	}
	back, _ := os.ReadFile(out)
	if !bytes.Equal(back, plain) {
		t.Fatal("round trip")
	}
	if ageSession != nil || ageIn != nil {
		t.Fatal("session kept")
	}
}

func TestAgeByPathNeverOverwrites(t *testing.T) {
	dir := t.TempDir()
	in := filepath.Join(dir, "a")
	there := filepath.Join(dir, "there")
	os.WriteFile(in, []byte("x"), 0o600)
	os.WriteFile(there, []byte("kept"), 0o600)
	if err := ageLockPath(in, there, "pw"); !errors.Is(err, agefile.ErrIO) {
		t.Fatalf("lock over a file: %v", err)
	}
	// no session: the out file is not made
	ageSession = nil
	if err := ageOpenFinishPath(filepath.Join(dir, "none")); !errors.Is(err, agefile.ErrIO) {
		t.Fatalf("finish without begin: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, "none")); !os.IsNotExist(err) {
		t.Fatal("half a file left")
	}
	if err := ageOpenFinishPath(there); !errors.Is(err, agefile.ErrIO) {
		t.Fatalf("finish over a file: %v", err)
	}
	if b, _ := os.ReadFile(there); string(b) != "kept" {
		t.Fatal("overwrote a file")
	}
}

func TestAgeByPathFailureLeavesNothing(t *testing.T) {
	dir := t.TempDir()
	out := filepath.Join(dir, "out.age")
	if err := ageLockPath(filepath.Join(dir, "missing"), out, "pw"); !errors.Is(err, agefile.ErrIO) {
		t.Fatalf("missing input: %v", err)
	}
	in := filepath.Join(dir, "a")
	os.WriteFile(in, []byte("x"), 0o600)
	if err := ageLockPath(in, out, ""); !errors.Is(err, agefile.ErrEmptyPassword) {
		t.Fatalf("empty password: %v", err)
	}
	if _, err := os.Stat(out); !os.IsNotExist(err) {
		t.Fatal("a failed lock left its file")
	}
	if err := ageOpenBeginPath(filepath.Join(dir, "missing"), "pw"); !errors.Is(err, agefile.ErrIO) {
		t.Fatalf("missing locked file: %v", err)
	}
	if err := ageOpenBeginPath(in, "pw"); !errors.Is(err, agefile.ErrNotAge) {
		t.Fatalf("not age: %v", err)
	}
	if ageIn != nil {
		t.Fatal("a refused file stays open")
	}
}
