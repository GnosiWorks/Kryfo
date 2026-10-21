// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"testing"
	"time"
)

// four rebuilds in a row, then a relay answers, then a new dead spell:
// how long until the next rebuild
func TestGapAfterRecoveryStartsAgain(t *testing.T) {
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	t0 := time.Now()
	failAll(t0, "wss://a", "wss://b")
	var last time.Time
	n := 0
	for now := t0; n < 4 && now.Before(t0.Add(time.Hour)); now = now.Add(10 * time.Second) {
		why := routeNeedsRescue(now)
		if why != "" && !strings.HasPrefix(why, "new circuits") {
			n++
			last = now
		}
	}
	if n != 4 {
		t.Fatalf("%d rebuilds", n)
	}
	routeNoteOK()
	again := last.Add(time.Minute)
	failAll(again, "wss://a", "wss://b")
	for now := again; now.Before(again.Add(time.Hour)); now = now.Add(10 * time.Second) {
		why := routeNeedsRescue(now)
		if why != "" && !strings.HasPrefix(why, "new circuits") {
			t.Logf("next rebuild %s after the new spell began", now.Sub(again))
			if now.Sub(again) > 3*time.Minute {
				t.Fatalf("rebuild waited %s after a recovered streak", now.Sub(again))
			}
			return
		}
	}
	t.Fatal("no rebuild within an hour")
}
