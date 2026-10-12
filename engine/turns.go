// SPDX-License-Identifier: GPL-3.0-or-later
package main

// every relay socket waits a turn of its own before it subscribes, at the
// start and after each wake, so a relay does not see all of one phone's
// addresses ask in the same instant. only the first goes at once.

import (
	"context"
	mrand "math/rand/v2"
	"sync"
	"sync/atomic"
	"time"
)

// the longest turn a socket waits
var subSpread = time.Minute

// in a check-in every turn is over this long after it began. the dial and
// the catch-up behind the last one still fit before the app stops waiting
// (160 s, its checkIn)
var checkInTurnsBy = 75 * time.Second

// the first socket to ask after a start or a wake goes at once. the route
// counts as up only once a relay has answered (routeOK), and the outbox and
// a check-in wait for that
var firstTurn struct {
	sync.Mutex
	kick chan struct{}
}

// true for the first caller after the kick kc
func takeFirstTurn(kc chan struct{}) bool {
	firstTurn.Lock()
	defer firstTurn.Unlock()
	if firstTurn.kick == kc {
		return false
	}
	firstTurn.kick = kc
	return true
}

// one socket's turn
type subTurn struct {
	// the kick it last waited after, nil before its first turn
	kick chan struct{}
	// counted as a catch-up under way
	held bool
}

// waits the socket's turn, unless it has had one since the last kick. from
// the turn until the dial is over it counts as a catch-up under way, so a
// check-in waits for it, but not as one begun: with no network none ever
// begins. false once ctx is over
func (t *subTurn) take(ctx context.Context) bool {
	kc := kickChan()
	if t.kick == kc {
		return ctx.Err() == nil
	}
	t.kick = kc
	if !t.held {
		t.held = true
		atomic.AddInt32(&catchupActive, 1)
	}
	if takeFirstTurn(kc) {
		return ctx.Err() == nil
	}
	d := turnDelay(autoNow())
	if d <= 0 {
		return ctx.Err() == nil
	}
	tm := time.NewTimer(d)
	defer tm.Stop()
	select {
	case <-tm.C:
		return true
	case <-ctx.Done():
		return false
	}
}

// the kick was answered another way: no turn for it
func (t *subTurn) skip() { t.kick = kickChan() }

func (t *subTurn) done() {
	if t.held {
		t.held = false
		atomic.AddInt32(&catchupActive, -1)
	}
}

// a turn drawn now, short enough to end inside a check-in under way
func turnDelay(now time.Time) time.Duration {
	w := subSpread
	if end, ok := checkInTurnsEnd(); ok {
		w = min(w, end.Sub(now))
	}
	if w <= 0 {
		return 0
	}
	return time.Duration(mrand.Int64N(int64(w)))
}

// when the turns of the check-in under way must be over
func checkInTurnsEnd() (time.Time, bool) {
	checkInMu.Lock()
	until := checkInUntil
	checkInMu.Unlock()
	if until.IsZero() || !autoNow().Before(until) {
		return time.Time{}, false
	}
	return until.Add(-checkInMax).Add(checkInTurnsBy), true
}
