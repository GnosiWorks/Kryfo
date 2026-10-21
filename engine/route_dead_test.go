// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"testing"
	"time"
)

const ownOnion = "ws://ours.onion"

// routeNoteFail with the spell's start on the test clock
func failAtClock(now time.Time, u string) {
	routeMu.Lock()
	was := len(failedSinceOK) == 0
	routeMu.Unlock()
	routeNoteFail(u)
	routeMu.Lock()
	if was && len(failedSinceOK) > 0 {
		firstFailAt = now
	}
	routeMu.Unlock()
}

// the same with a list that has only one entry of ours
func TestDeadTorOneOwnEntry(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	setRelays([]string{ownOnion, "wss://pub1.example", "wss://pub2.example"})
	resetRoute(t, "publishing", 100)
	routeBump()
	t0 := time.Now()
	for now := t0; now.Before(t0.Add(30 * time.Minute)); now = now.Add(10 * time.Second) {
		for _, u := range []string{ownOnion, "wss://pub1.example", "wss://pub2.example"} {
			failAtClock(now, u)
		}
		why := routeNeedsRescue(now)
		if why != "" && !strings.HasPrefix(why, circuitsWhy) && !strings.HasPrefix(why, probeWhy) {
			t.Logf("first bounce %s after start: %s", now.Sub(t0), why)
			return
		}
	}
	t.Fatal("a dead tor with one entry of ours was never bounced")
}
