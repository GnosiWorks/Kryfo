// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"testing"
	"time"

	"fiatjaf.com/nostr"
)

// a relay closed while it dials: the connection the dial brings is closed
// too, not left open with nothing reading it
func TestARelayClosedWhileDialingClosesItsSocket(t *testing.T) {
	si := newRelayStandIn(t, 0)
	si.mu.Lock()
	si.upgradeDelay = 300 * time.Millisecond
	si.mu.Unlock()
	ctx, cancel := context.WithCancel(context.Background())
	r := nostr.NewRelay(ctx, si.url(), nostr.RelayOptions{})
	time.AfterFunc(50*time.Millisecond, cancel)
	err := r.Connect(context.Background())
	if err == nil && r.IsConnected() {
		t.Fatal("connected after the close")
	}
	waitFor(t, "the socket closed", 3*time.Second, func() bool {
		cs := si.snapshot()
		return len(cs) == 1 && !cs[0].closed.IsZero()
	})
}
