// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"errors"
	"testing"
	"time"

	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/event"
)

// a snowflake that keeps failing at the broker retries every ten seconds.
// those retries are no progress, and neither is anything a dropped client
// still says: the attempt fails at its stall limit.
func TestSnowflakeFailuresAreNotProgress(t *testing.T) {
	t0 := time.Unix(5000, 0)
	now := t0
	old := sfNow
	sfNow = func() time.Time { return now }
	defer func() { sfNow = old }()
	dropSnowflakeClients()
	stale := sfListener{gen: sfGen.Load()}
	dropSnowflakeClients()
	cur := sfListener{gen: sfGen.Load()}

	sl := methodLimit["snowflake"]
	a := newSeen(t0)
	a.firstDial = t0
	cur.OnNewSnowflakeEvent(event.EventOnOfferCreated{})
	noteSnowflake(a)
	for s := 10 * time.Second; s <= sl; s += 10 * time.Second {
		now = t0.Add(s)
		cur.OnNewSnowflakeEvent(event.EventOnBrokerRendezvous{Error: errors.New("cut")})
		cur.OnNewSnowflakeEvent(event.EventOnOfferCreated{})
		stale.OnNewSnowflakeEvent(event.EventOnSnowflakeConnected{})
		noteSnowflake(a)
		v, _ := judgeBridge(a, sl, now)
		if s < sl && v != seenTrying {
			t.Fatalf("failed early at %s: %s", s, v)
		}
		if s == sl && v != seenFailed {
			t.Fatalf("a broker failing every ten seconds kept snowflake going: %s", v)
		}
	}
	// a step forward is progress
	b := newSeen(t0)
	b.firstDial = t0
	now = t0.Add(100 * time.Second)
	cur.OnNewSnowflakeEvent(event.EventOnBrokerRendezvous{})
	noteSnowflake(b)
	if v, _ := judgeBridge(b, sl, t0.Add(sl+10*time.Second)); v != seenTrying {
		t.Fatalf("a broker answer was not progress: %s", v)
	}
}
