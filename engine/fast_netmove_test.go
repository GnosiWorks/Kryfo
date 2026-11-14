// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"sync/atomic"
	"testing"
	"time"
)

// fast bounces no tor on a network change, so nothing else breaks the
// sockets off the network that went: the change kicks them, and each asks
// its probe. private keeps its bounce
func TestAFastNetworkMoveKicksTheSockets(t *testing.T) {
	keepBounceKnobs(t)
	var bounces atomic.Int32
	underNetMu(func() {
		netBounce = func() { bounces.Add(1) }
		netQuiet, netGap = time.Millisecond, time.Millisecond
	})
	netMu.Lock()
	lastNetBounce = time.Time{}
	netMu.Unlock()
	old := currentMode()
	t.Cleanup(func() { transportMode.Store(old) })
	setOffline(false)
	torParked.Store(false)

	kicked := func(kc chan struct{}) bool {
		select {
		case <-kc:
			return true
		default:
			return false
		}
	}

	transportMode.Store(modeBalanced)
	kc := kickChan()
	networkChanged()
	if !waitUntil(2*time.Second, func() bool { return kicked(kc) }) {
		t.Fatal("fast: a network change left the sockets of the old network alone")
	}
	if !kickIsMade(kickChan()) {
		t.Fatal("fast: the kick is not the phone's own, the open chat waits its turn")
	}
	waitUntil(time.Second, func() bool {
		netMu.Lock()
		defer netMu.Unlock()
		return !netWorker
	})
	if n := bounces.Load(); n != 0 {
		t.Fatalf("fast: tor bounced %d times on a network change", n)
	}

	// no network: nothing to dial on, the change that brings one kicks
	setOffline(true)
	t.Cleanup(func() { setOffline(false) })
	kc = kickChan()
	networkChanged()
	time.Sleep(100 * time.Millisecond)
	if kicked(kc) {
		t.Fatal("fast: a change to no network kicked the sockets")
	}
}
