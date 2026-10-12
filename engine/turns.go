// SPDX-License-Identifier: GPL-3.0-or-later
package main

// every relay socket waits a turn of its own before it subscribes, at the
// start and after each wake, so a relay does not see all of one phone's
// addresses ask in the same instant. only the first goes at once, and the
// open chat's address goes with no turn.

import (
	"context"
	mrand "math/rand/v2"
	"sync"
	"sync/atomic"
	"time"
)

import "C"

// the longest turn a socket waits, at a start or wake in the foreground or
// always on
var subSpread = time.Minute

// in a check-in the turns are short and over this long after the job
// began. the dial and the longest catch-up behind the last one, then the
// app's tail, still fit inside the job's 170 s (HaloPeriodicJobService)
var (
	checkInSpread  = 10 * time.Second
	checkInTurnsBy = 15 * time.Second
)

// when the job of the check-in under way began, unix nanoseconds, 0 for none
var checkInJob atomic.Int64

// a check-in begins (v > 0) or ends. v-1 is how many seconds ago its job
// began, so turns are timed from the job and not from the app's start
func noteCheckIn(v int) {
	if v <= 0 {
		checkInJob.Store(0)
		return
	}
	checkInJob.Store(autoNow().Add(-time.Duration(v-1) * time.Second).UnixNano())
}

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

// the runner tag of the chat open on screen: its address asks with no turn
var firstTag atomic.Value // string

// the open chat's peer key, "" for none
//
//export HaloNostrFirst
func HaloNostrFirst(cTag *C.char) *C.char {
	firstTag.Store(goStr(cTag))
	return C.CString("ok")
}

func isFirstTag(tag string) bool {
	f, _ := firstTag.Load().(string)
	return tag != "" && f == tag
}

// one socket's turn
type subTurn struct {
	// the runner's tag, see isFirstTag
	tag string
	// the kick it last waited after, nil before its first turn
	kick chan struct{}
	// it got through since that turn. until it does, a kick is no new turn
	up bool
	// counted as a catch-up under way
	held bool
}

// waits the socket's turn, unless it has had one since the last kick or has
// not got through since its last. from the turn until the dial is over it
// counts as a catch-up under way, so a check-in waits for it, but not as one
// begun: with no network none ever begins. false once ctx is over
func (t *subTurn) take(ctx context.Context) bool {
	kc := kickChan()
	if t.kick == kc {
		return ctx.Err() == nil
	}
	again := t.kick != nil && !t.up
	t.kick = kc
	if again || isFirstTag(t.tag) {
		return ctx.Err() == nil
	}
	t.up = false
	t.hold()
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

// the kick was answered on the live socket: no turn for it
func (t *subTurn) skip() { t.kick = kickChan() }

// counted as a catch-up under way, until done
func (t *subTurn) hold() {
	if !t.held {
		t.held = true
		atomic.AddInt32(&catchupActive, 1)
	}
}

func (t *subTurn) done() {
	if t.held {
		t.held = false
		atomic.AddInt32(&catchupActive, -1)
	}
}

// the dial is over, through or not
func (t *subTurn) dialed(ok bool) {
	if ok {
		t.up = true
	}
	t.done()
}

// a turn drawn now
func turnDelay(now time.Time) time.Duration { return spreadDelay(subSpread, now) }

// a delay up to w, short enough to end inside a check-in under way
func spreadDelay(w time.Duration, now time.Time) time.Duration {
	if end, ok := checkInTurnsEnd(); ok {
		w = min(w, checkInSpread, end.Sub(now))
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
	from := until.Add(-checkInMax)
	if j := checkInJob.Load(); j != 0 {
		from = time.Unix(0, j)
	}
	return from.Add(checkInTurnsBy), true
}
