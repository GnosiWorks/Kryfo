package main

import (
	"os"
	"testing"
)

// a restore's floor: read as written, nothing when there is none or it
// does not read
func TestReadFloor(t *testing.T) {
	old := savedDataDir
	defer func() { savedDataDir = old }()
	savedDataDir = t.TempDir()
	if f := readFloor(); f != 0 {
		t.Fatalf("no file: %d", f)
	}
	for in, want := range map[string]int64{
		"1791500000\n": 1791500000,
		"garbage":      0,
		"-5":           0,
	} {
		if err := os.WriteFile(savedDataDir+"/nostr_floor", []byte(in), 0o600); err != nil {
			t.Fatal(err)
		}
		if f := readFloor(); f != want {
			t.Fatalf("%q: %d, want %d", in, f, want)
		}
	}
	savedDataDir = ""
	if f := readFloor(); f != 0 {
		t.Fatalf("no dir: %d", f)
	}
}
