// SPDX-License-Identifier: GPL-3.0-or-later

//go:build mtecheck

package cstr

import (
	"os"
	"strings"
	"testing"
	"unsafe"
)

// run by mtecheck.sh under qemu with glibc heap tagging

func TestMTEOn(t *testing.T) {
	if c := tagCtl(); c < 0 || c&6 == 0 {
		t.Fatalf("mte is off, tagged_addr_ctrl %#x", c)
	}
	tagged := false
	for i := 0; i < 16; i++ {
		p := heapCopy("x")
		if uintptr(p)>>56 != 0 {
			tagged = true
		}
		heapFree(p)
	}
	if !tagged {
		t.Fatal("malloc hands out untagged pointers")
	}
}

func convertAll(t *testing.T, conv func(unsafe.Pointer) string) {
	lens := []int{1000, 4095, 4096}
	for n := 0; n <= 160; n++ {
		lens = append(lens, n)
	}
	for round := 0; round < 20; round++ {
		for _, n := range lens {
			want := strings.Repeat("f", n)
			p := heapCopy(want)
			if got := conv(p); got != want {
				t.Fatalf("length %d came back as %d", n, len(got))
			}
			heapFree(p)
		}
	}
}

func TestString(t *testing.T) {
	if String(nil) != "" {
		t.Fatal("nil is not empty")
	}
	convertAll(t, String)
}

// has to die with SIGSEGV, mtecheck.sh runs it alone with MTECHECK_OLD=1
func TestOldGoString(t *testing.T) {
	if os.Getenv("MTECHECK_OLD") == "" {
		t.Skip("run by mtecheck.sh")
	}
	convertAll(t, oldString)
	t.Log("old C.GoString survived")
}
