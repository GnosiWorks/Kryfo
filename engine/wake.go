// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the phone asleep. with the screen off and no wakelock the cpu suspends,
// and go's monotonic clock and every timer stop with it. a long sleep can
// leave every socket dead at once, and on the wake they would all redial
// together: thousands of tor streams in one go on a big inbox. a wake shows
// as the boot clock running ahead of the monotonic one. from there the
// redials take turns, our relay first and the public relays after it, and
// what failed across the sleep or in the wake's first stretch counts
// against no relay and no route, once per route that carried.

import (
	"log"
	mrand "math/rand/v2"
	"sync"
	"sync/atomic"
	"time"
)

// the clock the outage round and the reads keep their times on: the boot
// clock, unless a test puts its own in
var ownClockFn atomic.Pointer[func() time.Duration]

func ownClock() time.Duration {
	if f := ownClockFn.Load(); f != nil {
		return (*f)()
	}
	return bootClock()
}

// a sleep at least this long is a wake: sockets live through a short one
var wakeJump = 3 * time.Minute

// go's monotonic clock, which stops while the phone sleeps
func awakeClock() time.Duration { return time.Since(awakeBase) }

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
	// the latest wake's turns, monotonic, and how many wakes were seen
	wakeTurnsAt time.Time
	wakeN       int64
	// the wake that reset and excused, and until when failures count for
	// nothing. once a route has carried again the next wake may do it again:
	// a phone that sleeps in short bursts must not excuse a dead tor for good
	wakeAt        time.Time
	wakeGraceTill time.Time
	wakeSpent     bool
	// our relay's first redial after the wake was made, with no turn
	wakeFirstGone bool
	// this wake's widths, in thousandths: a fifth either way, so the length
	// of the burst a relay sees does not give the inbox's size away
	wakeOwnK, wakePubK int64 = 1000, 1000
	// our relay answered since a wake last cut its failing span
	wakeOwnFresh = true
)

// looks for a sleep since the last look. true when this look found one
func wakeCheck() bool {
	wakeMu.Lock()
	defer wakeMu.Unlock()
	// read under the lock, so no look puts an older baseline back
	boot, awake := ownClock(), awakeClock()
	if !wakeLooked {
		wakeBoot, wakeAwake, wakeLooked = boot, awake, true
		return false
	}
	back := boot < wakeBoot || awake < wakeAwake
	slept := (boot - wakeBoot) - (awake - wakeAwake)
	wakeBoot, wakeAwake = boot, awake
	if back || slept < wakeJump {
		// a clock put back is no sleep
		return false
	}
	wokeLocked(slept)
	return true
}

// under wakeMu. the other locks are taken inside it, never the other way
func wokeLocked(slept time.Duration) {
	now := time.Now()
	wakeN++
	wakeTurnsAt, wakeFirstGone = now, false
	wakeOwnK, wakePubK = 800+mrand.Int64N(401), 800+mrand.Int64N(401)
	w := wakeWindowsLocked()
	span := w.own + w.pub
	// in a check-in the turns are over when its turns are
	if end, ok := checkInTurnsEnd(); ok {
		span = min(span, max(end.Sub(autoNow()), 0))
	}
	if wakeSpent {
		// no route has carried since the last wake: its grace was the one
		log.Printf("halo: woke after %s asleep, no relay answered since the last wake", slept.Round(time.Second))
		return
	}
	wakeSpent, wakeAt = true, now
	wakeGraceTill = now.Add(span + wakeGraceExtra)
	log.Printf("halo: woke after %s asleep, redials spread over %s, ours first",
		slept.Round(time.Second), span.Round(time.Millisecond))
	// a bench or a streak from before the sleep says nothing of now
	relayClearBenches()
	routeSlept()
	armRelayWatch()
	// our relay's failing span is cut once per answer of ours: a real outage
	// slept through in short bursts is still found
	if wakeOwnFresh && liveSlept() {
		wakeOwnFresh = false
	}
}

// our relay answered: the next wake may cut its failing span again
func wakeOwnProven() {
	wakeMu.Lock()
	wakeOwnFresh = true
	wakeMu.Unlock()
}

// a relay answered: the next wake may reset and excuse again
func wakeRouteProven() {
	wakeMu.Lock()
	wakeSpent = false
	wakeMu.Unlock()
}

// forgets every wake and looks afresh, for the tests
func wakeReset() {
	wakeMu.Lock()
	wakeLooked, wakeAt, wakeGraceTill, wakeFirstGone = false, time.Time{}, time.Time{}, false
	wakeTurnsAt, wakeSpent, wakeOwnFresh = time.Time{}, false, true
	wakeMu.Unlock()
}

// a failure of an attempt begun before the wake, or in its first stretch,
// says nothing of the relay or the route: tor is still finding its
// circuits again
func wakeExcuses(began time.Time) bool {
	wakeCheck()
	// a check-in begun after the wake was seen gets no longer than its own
	// turns either: the app stops waiting at 120 s
	end, inCheck := checkInTurnsEnd()
	now := time.Now()
	wakeMu.Lock()
	defer wakeMu.Unlock()
	if wakeAt.IsZero() {
		return false
	}
	till := wakeGraceTill
	if inCheck {
		if most := now.Add(end.Sub(autoNow()) + wakeGraceExtra); most.Before(till) {
			till = most
		}
	}
	return began.Before(wakeAt) || now.Before(till)
}

// how wide a wake's turns are now
type wakeTurns struct{ own, pub time.Duration }

// under wakeMu
func wakeWindowsLocked() wakeTurns {
	own := time.Duration(max(ownSockets.Load(), 0)) * wakeGap * time.Duration(wakeOwnK) / 1000
	pub := time.Duration(max(pubSockets.Load(), 0)) * wakeGap * time.Duration(wakePubK) / 1000
	own = min(own, wakeOwnMost, wakeMost)
	return wakeTurns{own, min(pub, wakeMost-own)}
}

func wakeWindows() wakeTurns {
	wakeMu.Lock()
	defer wakeMu.Unlock()
	return wakeWindowsLocked()
}

// the wake under way, if its turns still hold: its number and windows
func wakeNow() (int64, wakeTurns, bool) {
	wakeMu.Lock()
	defer wakeMu.Unlock()
	if wakeTurnsAt.IsZero() {
		return 0, wakeTurns{}, false
	}
	if d := time.Since(wakeTurnsAt); d < 0 || d >= wakeHold {
		return 0, wakeTurns{}, false
	}
	return wakeN, wakeWindowsLocked(), true
}

// when wake n was seen, or the far future once a later one was
func wakeSeenAt(n int64) time.Time {
	wakeMu.Lock()
	defer wakeMu.Unlock()
	if wakeN != n || wakeTurnsAt.IsZero() {
		return time.Now().Add(wakeHold)
	}
	return wakeTurnsAt
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
// relays' in the one after it, which begins somewhere in ours' last fifth.
// in a check-in both shrink to fit its turns, in the same order
func (w wakeTurns) turn(own bool, now time.Time) time.Duration {
	lo, span := time.Duration(0), w.own
	if !own {
		lo, span = w.own*4/5, w.pub
		if w.own > 0 {
			lo += time.Duration(mrand.Int64N(int64(w.own/5) + 1))
		}
	}
	if end, ok := checkInTurnsEnd(); ok {
		all := w.own + w.pub
		limit := min(all, checkInSpread, end.Sub(now))
		if limit <= 0 {
			return 0
		}
		if all > limit {
			// in floats: two nanosecond counts multiplied overflow int64
			f := float64(limit) / float64(all)
			lo, span = time.Duration(float64(lo)*f), time.Duration(float64(span)*f)
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
