// SPDX-License-Identifier: GPL-3.0-or-later
package main

import "testing"

// every decoy session gets a socks name of its own, never the services
// lane's, and the last session's client goes with it
func TestDecoyLaneIsItsOwn(t *testing.T) {
	lane, name := decoyLane()
	if lane == laneServices || name == laneName(laneServices) || len(name) != 32 {
		t.Fatalf("decoy lane %q %q shares the services lane", lane, name)
	}
	if l2, n2 := decoyLane(); l2 != lane || n2 != name {
		t.Fatal("one session, one name")
	}
	cachedNostrClientMu.Lock()
	cachedNostrClients["tor:"+lane] = nil
	cachedNostrClientMu.Unlock()
	decoyLaneNew()
	l3, n3 := decoyLane()
	if l3 == lane || n3 == name {
		t.Fatal("a new decoy session kept the old name")
	}
	cachedNostrClientMu.Lock()
	_, kept := cachedNostrClients["tor:"+lane]
	cachedNostrClientMu.Unlock()
	if kept {
		t.Fatal("the last session's client stayed")
	}
}
