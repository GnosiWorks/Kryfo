// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"strconv"
	"testing"
	"time"

	"github.com/nbd-wtf/go-nostr"
)

func wrapExpiring(at time.Time) *nostr.Event {
	return &nostr.Event{
		Kind:      1059,
		CreatedAt: nostr.Now(),
		Tags: nostr.Tags{
			{"p", "aa"},
			{"expiration", strconv.FormatInt(at.Unix(), 10)},
		},
	}
}

// the app stamps two weeks and up to a day; a phone an hour fast still
// gets its mail through
func TestExpiryTakesTheAppsSpread(t *testing.T) {
	now := time.Now()
	for _, d := range []time.Duration{
		wrapTTL,
		wrapTTL + 24*time.Hour,
		wrapTTL + 24*time.Hour + time.Hour,
	} {
		if bad, why := rejectEvent(context.Background(), wrapExpiring(now.Add(d))); bad {
			t.Fatalf("an expiration %s ahead refused: %s", d, why)
		}
	}
	if bad, _ := rejectEvent(context.Background(), wrapExpiring(now.Add(wrapTTL+3*24*time.Hour))); !bad {
		t.Fatal("an expiration three days past the fortnight taken")
	}
}
