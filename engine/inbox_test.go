// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"encoding/base64"
	"strings"
	"testing"
	"time"
)

func wire(first byte, n int) string {
	b := make([]byte, n)
	b[0] = first
	for i := 1; i < n; i++ {
		b[i] = byte(i)
	}
	return base64.StdEncoding.EncodeToString(b)
}

func TestInboxShape(t *testing.T) {
	if !inboxShapeOK(wire(3, 64)) || !inboxShapeOK(wire(2, 64)) {
		t.Fatal("a signal message should pass")
	}
	for _, bad := range []string{
		"",
		"{\"halo_ctl\":\"bundle\"}",
		"not base64 at all!",
		wire(7, 64),
		base64.StdEncoding.EncodeToString([]byte{3}),
		wire(3, inboxMaxLine),
	} {
		if inboxShapeOK(bad) {
			t.Fatalf("should not pass: %.20q", bad)
		}
	}
}

func TestInboxPutCaps(t *testing.T) {
	drainForTest()
	line := wire(3, 64)
	if !inboxPut(line) {
		t.Fatal("first copy should be taken")
	}
	if inboxPut(line) {
		t.Fatal("a repeat should not be taken while the first waits")
	}
	for i := 1; i < inboxMaxLines; i++ {
		if !inboxPut(wire(3, 64+i)) {
			t.Fatalf("line %d should fit", i)
		}
	}
	if inboxPut(wire(2, 64)) {
		t.Fatal("past the line cap nothing is taken")
	}
	drainForTest()
	if !inboxPut(line) {
		t.Fatal("after a drain the same line is welcome again")
	}
	// the byte cap: a few big lines fill it before the line cap does
	drainForTest()
	big := strings.Repeat("A", inboxMaxLine-4) + "AAA="
	var took int
	for i := 0; i < inboxMaxLines; i++ {
		// vary the tail so each is a new line
		l := big[:len(big)-8] + base64.StdEncoding.EncodeToString([]byte{byte(i), 1, 2, 3, 4})[:8]
		if inboxPut(l) {
			took++
		}
	}
	if took*inboxMaxLine < inboxMaxBytes-inboxMaxLine || took*inboxMaxLine > inboxMaxBytes {
		t.Fatalf("byte cap should stop near %d bytes, took %d lines", inboxMaxBytes, took)
	}
	drainForTest()
}

// a drain as these tests need it: the inbox and the budget both start over
func drainForTest() {
	mu.Lock()
	inboxDrained()
	inboxTokens, inboxFilled = inboxBurst, time.Time{}
	mu.Unlock()
}

// the door takes a full inbox at once, then no more than its steady rate,
// whatever dart drains in between
func TestInboxBudget(t *testing.T) {
	drainForTest()
	defer drainForTest()
	now := time.Now()
	mu.Lock()
	defer mu.Unlock()
	for i := 0; i < inboxBurst; i++ {
		if !inboxBudgetTake(now) {
			t.Fatalf("line %d of a burst should be taken", i)
		}
	}
	if inboxBudgetTake(now) {
		t.Fatal("past the burst nothing is taken at once")
	}
	inboxDrained()
	if inboxBudgetTake(now) {
		t.Fatal("a drain does not refill the budget")
	}
	later := now.Add(10 * time.Second)
	took := 0
	for inboxBudgetTake(later) {
		took++
	}
	if took != 10*inboxPerSec {
		t.Fatalf("ten seconds later %d lines were taken, want %d", took, 10*inboxPerSec)
	}
}
