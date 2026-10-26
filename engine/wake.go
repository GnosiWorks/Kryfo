// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the phone asleep. with the screen off and no wakelock the cpu suspends,
// and go's monotonic clock and every timer stop with it. a long sleep can
// leave every socket dead at once, and on the wake they would all redial
// together: thousands of tor streams in one go on a big inbox. a wake shows
// as the boot clock running ahead of the monotonic one. from there the
// redials take turns, our relay first and the public relays after it, and
// what failed across the sleep or in the wake's first stretch counts
// against no relay and no route.

import (
	"log"
	mrand "math/rand/v2"
	"sync"
	"sync/atomic"
	"time"
)

// a sleep at least this long is a wake. a var for the tests
var wakeJump = time.Minute

// go's monotonic clock, which stops while the phone sleeps. a var for the tests
var awakeClock = func() time.Duration { return time.Since(awakeBase) }

var awakeBase = time.Now()

// the room each socket gets at a wake: the turns spread wider with more
// sockets, up to the ceilings, so a small inbox is back as fast as before
var (
	wakeGap     = 50 * time.Millisecond
	wakeOwnMost = 30 * time.Second
	wakeMost    = 2 * time.Minute
)

// how long after a wake a redial takes a wake turn: a socket can find out
// it is dead minutes in, when its ping goes unanswered
var wakeHold = 5 * time.Minute

// how long past the wake's turns a failure still counts for nothing
var wakeGraceExtra = 30 * time.Second

// the runners' sockets on our relay's entries and on the public relays
var ownSockets, pubSockets atomic.Int32

var (
	wakeMu sync.Mutex
	// both clocks at the last look
	wakeBoot, wakeAwake time.Duration
	wakeLooked          bool
	// the latest wake, monotonic, and how many were seen
	wakeAt time.Time
	wakeN  int64
	// failures before this count for nothing
	wakeGraceTill time.Time
	// our relay's first redial after the wake was made, with no turn
	wakeFirstGone bool
)

// looks for a sleep since the last look. true when this look found one
func wakeCheck() bool {
	boot, awake := ownClock(), awakeClock()
	wakeMu.Lock()
	defer wakeMu.Unlock()
	if !wakeLooked {
		wakeBoot, wakeAwake, wakeLooked = boot, awake, true
		return false
	}
	back := boot < wakeBoot || awake < wakeAwake
	slept := (boot - wakeBoot) - (awake - wakeAwake)
	wakeBoot, wakeAwake = boot, awake
	if back {
		// a clock put back, or a look that read before the last one did
		return false
	}
	if slept < wakeJump {
		return false
	}
	wokeLocked(slept)
	return true
}

// under wakeMu. the other locks are taken inside it, never the other way
func wokeLocked(slept time.Duration) {
	now := time.Now()
	w := wakeWindows()
	wakeAt, wakeFirstGone = now, false
	wakeN++
	wakeGraceTill = now.Add(w.own + w.pub + wakeGraceExtra)
	log.Printf("halo: woke after %s asleep, redials spread: ours over %s, the public relays after it over %s",
		slept.Round(time.Second), w.own.Round(time.Millisecond), w.pub.Round(time.Millisecond))
	// a bench or a streak from before the sleep says nothing of now
	relayClearBenches()
	routeSlept()
	armRelayWatch()
	liveSlept()
}

// forgets every wake and looks afresh, for the tests
func wakeReset() {
	wakeMu.Lock()
	wakeLooked, wakeAt, wakeGraceTill, wakeFirstGone = false, time.Time{}, time.Time{}, false
	wakeMu.Unlock()
}

// a failure of an attempt begun before the latest wake, or in its first
// stretch, says nothing of the relay or the route: tor is still finding
// its circuits again
func wakeExcuses(began time.Time) bool {
	wakeCheck()
	wakeMu.Lock()
	defer wakeMu.Unlock()
	if wakeAt.IsZero() {
		return false
	}
	return began.Before(wakeAt) || time.Now().Before(wakeGraceTill)
}

// how wide a wake's turns are now
type wakeTurns struct{ own, pub time.Duration }

func wakeWindows() wakeTurns {
	own := min(time.Duration(max(ownSockets.Load(), 0))*wakeGap, wakeOwnMost, wakeMost)
	pub := min(time.Duration(max(pubSockets.Load(), 0))*wakeGap, wakeMost-own)
	return wakeTurns{own, pub}
}

// the wake under way, if its turns still hold: its number and windows
func wakeNow() (int64, wakeTurns, bool) {
	wakeMu.Lock()
	at, n := wakeAt, wakeN
	wakeMu.Unlock()
	if at.IsZero() {
		return 0, wakeTurns{}, false
	}
	if d := time.Since(at); d < 0 || d >= wakeHold {
		return 0, wakeTurns{}, false
	}
	return n, wakeWindows(), true
}

// true for our relay's first redial in wake n: it goes at once, so the
// route is proven as soon as before
func takeWakeFirst(n int64) bool {
	wakeMu.Lock()
	defer wakeMu.Unlock()
	if wakeN != n || wakeFirstGone {
		return false
	}
	wakeFirstGone = true
	return true
}

// a socket's turn at a wake: ours anywhere in the first window, the public
// relays' in the one after it. in a check-in both shrink to fit its turns
func (w wakeTurns) turn(own bool, now time.Time) time.Duration {
	lo, span := time.Duration(0), w.own
	if !own {
		lo, span = w.own, w.pub
	}
	if end, ok := checkInTurnsEnd(); ok {
		all := w.own + w.pub
		limit := min(all, checkInSpread, end.Sub(now))
		if limit <= 0 {
			return 0
		}
		if all > limit {
			lo = time.Duration(int64(lo) * int64(limit) / int64(all))
			span = time.Duration(int64(span) * int64(limit) / int64(all))
		}
	}
	if span <= 0 {
		return lo
	}
	return lo + time.Duration(mrand.Int64N(int64(span)))
}

// the wait before a live socket answers a kick: in a wake's turns, as its
// redial would
func kickDelayFor(own bool) time.Duration {
	if _, w, ok := wakeNow(); ok {
		return w.turn(own, autoNow())
	}
	return kickDelay()
}
