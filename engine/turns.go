// SPDX-License-Identifier: GPL-3.0-or-later
package main

// every relay socket waits a turn of its own before it subscribes, at the
// start and after each wake, so a relay does not see all of one phone's
// addresses ask in the same instant. only the first goes at once, and the
// open chat's address, and a just-added one's first ask right after the add,
// go with no turn.

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
// began, and a dial and a long catch-up are cut, so the last answer is in
// well before the app stops waiting, 120 s into the job (app/engine.dart,
// kCheckLoopBy). the job stops at 170 (HaloPeriodicJobService)
var (
	checkInSpread   = 10 * time.Second
	checkInTurnsBy  = 15 * time.Second
	checkInDialWait = 30 * time.Second
	checkInLongCap  = 40 * time.Second
)

// d, or limit if that is shorter and a check-in is under way
func checkInBound(d, limit time.Duration) time.Duration {
	if inCheckIn() {
		return min(d, limit)
	}
	return d
}

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
	// the start's is the first batch's
	return !startFirstHolds(kc)
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

// how long after an add or accept its free turn holds
var freshFor = 15 * time.Second

// a runner started for someone just added or accepted: the kick it was
// started under, and until when its free turn holds
type freshMark struct {
	kick  chan struct{}
	until time.Time
}

type freshKey struct{}

func asFresh(ctx context.Context) context.Context {
	return context.WithValue(ctx, freshKey{}, freshMark{kickChan(), autoNow().Add(freshFor)})
}

func freshOf(ctx context.Context) *freshMark {
	if m, ok := ctx.Value(freshKey{}).(freshMark); ok {
		return &m
	}
	return nil
}

// the free turn holds only under the kick the add or accept came in, and
// only soon after it. one that parked offline or waited for tor would ask
// at the wake or the start, beside the phone's other addresses, so the
// runner drops it there too
func (m *freshMark) holds(kc chan struct{}, now time.Time) bool {
	return m != nil && kc == m.kick && now.Before(m.until)
}

// one socket's turn
type subTurn struct {
	// the runner's tag, see isFirstTag
	tag string
	// the address was just added or accepted: its first turn is free. the
	// add or accept is already the user's own act on this lane, not a start
	// or a wake, so it shows up beside none of the phone's other addresses
	fresh *freshMark
	// its last turn was that free one: a dial that failed there waits a
	// turn on the next kick, as a first one would
	free bool
	// the kick it last waited after, nil before its first turn
	kick chan struct{}
	// it got through since that turn. until it does, a kick is no new turn
	up bool
	// counted as a catch-up under way
	held bool
	// a socket on one of our relay's entries: first at a wake
	own bool
	// the wake it last had a turn in, see takeWake
	wake int64
	// closed once the socket it shares is up, nil for a socket of its own:
	// then its turn is over, and it does not take the first one
	ready func() <-chan struct{}
	// the socket it shares, nil for one of its own: the socket's turn is
	// drawn once for all of its addresses (sharedDelay)
	batch *hubKey
}

// a shared socket's turn under a kick or a wake: drawn once, by the first
// of its addresses to wait, over the whole spread. the others wait for the
// same moment or for the socket to be up. drawn per address, a batch would
// dial at the first of up to eight draws and a phone's batches would come
// up within seconds of each other
var batchTurns = struct {
	sync.Mutex
	m map[hubKey]batchTurn
}{m: map[hubKey]batchTurn{}}

type batchTurn struct {
	kick chan struct{}
	wake int64
	at   time.Time
}

func (t *subTurn) sharedDelay(kc chan struct{}, wake int64, now time.Time, draw func() time.Duration) time.Duration {
	if t.batch == nil {
		return draw()
	}
	batchTurns.Lock()
	defer batchTurns.Unlock()
	if bt, ok := batchTurns.m[*t.batch]; ok && bt.kick == kc && bt.wake == wake {
		return bt.at.Sub(now)
	}
	d := draw()
	batchTurns.m[*t.batch] = batchTurn{kc, wake, now.Add(d)}
	return d
}

func (t *subTurn) readyChan() <-chan struct{} {
	if t.ready == nil {
		return nil
	}
	return t.ready()
}

func isClosed(c <-chan struct{}) bool {
	if c == nil {
		return false
	}
	select {
	case <-c:
		return true
	default:
		return false
	}
}

// waits the socket's turn, unless it has had one since the last kick or has
// not got through since its last. from here until the dial is over it
// counts as a catch-up under way, so a check-in waits for it, but not as one
// begun: with no network none ever begins. false once ctx is over
func (t *subTurn) take(ctx context.Context) bool {
	// every dial is counted until it is over (dialed), turn or none
	t.hold()
	wakeCheck()
	kc := kickChan()
	if n, w, ok := wakeNow(); ok {
		return t.takeWake(ctx, kc, n, w)
	}
	if t.kick == kc {
		return ctx.Err() == nil
	}
	again := t.kick != nil && !t.up && !t.free
	first := t.kick == nil && t.fresh.holds(kc, autoNow())
	t.kick = kc
	t.free = first
	if again || first || isFirstTag(t.tag) {
		return ctx.Err() == nil
	}
	t.up = false
	up := t.readyChan()
	if isClosed(up) {
		return ctx.Err() == nil
	}
	now := autoNow()
	d := t.sharedDelay(kc, 0, now, func() time.Duration {
		if t.batch != nil && startFirstFor(t.batch.lane, kc) {
			return 0
		}
		if takeFirstTurn(kc) {
			return 0
		}
		return turnDelay(now)
	})
	if d <= 0 {
		return ctx.Err() == nil
	}
	tm := time.NewTimer(d)
	defer tm.Stop()
	select {
	case <-tm.C:
		return true
	case <-up:
		return ctx.Err() == nil
	case <-ctx.Done():
		return false
	}
}

// after a wake every redial takes a turn, with or without a kick: the
// sockets the sleep killed find out at once or one ping at a time, and
// either way they would redial together. one turn per wake, and one more
// once it got through, as a socket that dies again after that does. ours
// before the public relays, the first of ours at once
func (t *subTurn) takeWake(ctx context.Context, kc chan struct{}, n int64, w wakeTurns) bool {
	now := autoNow()
	first := t.kick == nil && t.fresh.holds(kc, now)
	had := t.wake == n
	t.kick, t.wake, t.free = kc, n, first
	// a retry after a failed turn goes at its own backoff's pace
	if (had && !t.up) || first || isFirstTag(t.tag) {
		return ctx.Err() == nil
	}
	t.up = false
	up := t.readyChan()
	if isClosed(up) {
		return ctx.Err() == nil
	}
	d := t.sharedDelay(kc, n, now, func() time.Duration {
		if t.own && takeWakeFirst(n) {
			return 0
		}
		return w.turn(t.own, now)
	})
	if d <= 0 {
		return ctx.Err() == nil
	}
	tm := time.NewTimer(d)
	defer tm.Stop()
	select {
	case <-tm.C:
		return true
	case <-up:
		return ctx.Err() == nil
	case <-ctx.Done():
		return false
	}
}

// the kick was answered on the live socket: no turn for it
func (t *subTurn) skip() { t.kick = kickChan() }

// a kick's probe went out at the socket's turn: in a wake that was its
// turn, and a redial after it failing goes at once
func (t *subTurn) probed(ok bool) {
	if n, _, waking := wakeNow(); waking {
		t.wake, t.up = n, ok
	}
}

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
