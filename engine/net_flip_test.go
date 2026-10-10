// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// every network change re-arms the rescue: the back-off, the floor and a
// reconnect still running from the network that went all give way, one
// clean reconnect follows the last of a burst, and a bounded check sees
// that tor carries something on the new network. no tor here: the
// reconnect is a stand-in that says whether a relay came through after it.

type flipRig struct {
	mu    sync.Mutex
	calls []time.Time
	prove atomic.Bool
}

func (r *flipRig) n() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.calls)
}

func rigFlips(t *testing.T, quiet, gap, proof time.Duration) *flipRig {
	t.Helper()
	oq, og, ob := netQuiet, netGap, netBounce
	or, op, ot, ost := netReconnect, netProof, netProofTries, netProofStep
	t.Cleanup(func() {
		// let a worker still sleeping finish against the stand-in
		time.Sleep(2 * (quiet + gap + proof))
		netQuiet, netGap, netBounce = oq, og, ob
		netReconnect, netProof, netProofTries, netProofStep = or, op, ot, ost
	})
	netQuiet, netGap = quiet, gap
	netProof, netProofTries, netProofStep = proof, 2, time.Millisecond
	netMu.Lock()
	lastNetBounce = time.Time{}
	netMu.Unlock()
	resetRoute(t, "publishing", 100)
	r := &flipRig{}
	netReconnect = func() string {
		r.mu.Lock()
		r.calls = append(r.calls, time.Now())
		r.mu.Unlock()
		routeFreshNetwork()
		routeBump()
		if r.prove.Load() {
			routeNoteOK()
		}
		return "ok"
	}
	return r
}

func waitCalls(r *flipRig, want int, limit time.Duration) int {
	end := time.Now().Add(limit)
	for time.Now().Before(end) && r.n() < want {
		time.Sleep(5 * time.Millisecond)
	}
	return r.n()
}

// airplane mode toggled over and over on a flight, wifi to mobile, a vpn up
// and down: twenty changes in a fifth of a second. one reconnect, after the
// last, and the flight's back-off gone with the first change
func TestFlipBurstSettlesIntoOneReconnect(t *testing.T) {
	r := rigFlips(t, 40*time.Millisecond, 150*time.Millisecond, 200*time.Millisecond)
	r.prove.Store(true)
	routeMu.Lock()
	rescues, lastRescue = 5, time.Now()
	routeMu.Unlock()

	var last time.Time
	for i := 0; i < 20; i++ {
		networkChanged()
		last = time.Now()
		if i == 0 {
			routeMu.Lock()
			n := rescues
			routeMu.Unlock()
			if n != 0 {
				t.Fatalf("the back-off survived a network change: %d rescues", n)
			}
		}
		time.Sleep(10 * time.Millisecond)
	}
	if got := waitCalls(r, 1, time.Second); got != 1 {
		t.Fatalf("%d reconnects for a burst, want 1", got)
	}
	time.Sleep(500 * time.Millisecond)
	if got := r.n(); got != 1 {
		t.Fatalf("%d reconnects once settled, want 1", got)
	}
	r.mu.Lock()
	at := r.calls[0]
	r.mu.Unlock()
	if at.Before(last) {
		t.Fatal("the reconnect came before the last change")
	}
	if got := lastNetCheck(); got == "" || got[:2] != "ok" {
		t.Fatalf("check after the burst: %q", got)
	}
}

// nothing comes through after the bounce: one more, then the route watch
// has it. two reconnects, not a loop
func TestUnprovenNetworkGetsOneMoreBounce(t *testing.T) {
	r := rigFlips(t, 10*time.Millisecond, 50*time.Millisecond, 100*time.Millisecond)
	networkChanged()
	waitCalls(r, 3, 800*time.Millisecond)
	if got := r.n(); got != 2 {
		t.Fatalf("%d reconnects on a network tor never proved, want 2", got)
	}
	if got := lastNetCheck(); got == "" || got[:2] != "no" {
		t.Fatalf("check on an unproven network: %q", got)
	}
}

// a change while the check for the last one runs: that check stands down,
// the new network gets its own bounce and its own check
func TestNewChangeSupersedesTheCheck(t *testing.T) {
	r := rigFlips(t, 20*time.Millisecond, 100*time.Millisecond, 500*time.Millisecond)
	networkChanged()
	waitCalls(r, 1, time.Second)
	networkChanged()
	waitCalls(r, 4, 2*time.Second)
	if got := r.n(); got != 3 {
		t.Fatalf("%d reconnects, want 3: one for the first network, one and "+
			"its retry for the second", got)
	}
}

// a reconnect still running began on the network that went, and the floor
// is for watchdogs: neither holds back the one a network change asks for
func TestNetworkChangeTakesOverARunningReconnect(t *testing.T) {
	f := newFakeControl(t, 100)
	fakeTor(t, f.port())
	resetRoute(t, "publishing", 100)
	atomic.StoreInt32(&torRestarting, 1)
	atomic.StoreInt64(&reconnectSince, time.Now().UnixNano())
	atomic.StoreInt64(&lastTorRestart, time.Now().Unix())
	before := reconnectRuns.Load()
	if r := netReconnect(); r != "ok" {
		t.Fatalf("a network change did not reconnect: %s", r)
	}
	if reconnectRuns.Load() != before+1 {
		t.Fatal("no reconnect ran")
	}
}
