// SPDX-License-Identifier: GPL-3.0-or-later
package main

// every relay socket waits a turn of its own before it subscribes, at the
// start and after each wake, so a relay does not see all of one phone's
// addresses ask in the same instant. only the first goes at once, and the
// open chat's address under a network change or the app coming to the
// front, and a just-added one's first ask right after the add, go with no
// turn. at the start our own relays wait less: the first batch
// and the first-contact listener go at once there, the first socket of ours
// too when there is no first batch (a linked device has none), and the rest
// of ours within ownStartSpread.

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
// under an event a server can't cause (phoneMade)
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

// the open chat's priority (no turn, the first redial) holds only after an
// event no server can cause: a network change or the app coming to the
// front. a check-in or drain kick, a push wake or a relay's drop can be had
// from our relays or the push gateway at will, and which address comes
// first would name the open chat each time
var phoneEv struct {
	sync.Mutex
	// the last one, zero for none
	at time.Time
	// closed at each one: the open chat's waiting turn ends
	ch chan struct{}
}

// the app is in front, as it last said
var appFront atomic.Bool

// the app came to the front (1) or left it (0)
//
//export HaloAppFront
func HaloAppFront(on C.int) *C.char {
	noteAppFront(on != 0)
	return C.CString("ok")
}

func noteAppFront(on bool) {
	if was := appFront.Swap(on); on && !was {
		phoneMade()
	}
}

// a network change or the app to the front
func phoneMade() {
	// a wake it came out of is seen first, so the event counts after it
	wakeCheck()
	phoneEv.Lock()
	phoneEv.at = time.Now()
	if phoneEv.ch != nil {
		close(phoneEv.ch)
	}
	phoneEv.ch = make(chan struct{})
	phoneEv.Unlock()
	paceRaiseOpen()
}

// tor woke from its sleep: the app in front asked, or a check-in that a
// push or the job began. only the first is the phone's own
func kickForTorBack() { kickRelaysAs(appFront.Load()) }

// closed at the next phoneMade
func phoneChan() <-chan struct{} {
	phoneEv.Lock()
	defer phoneEv.Unlock()
	if phoneEv.ch == nil {
		phoneEv.ch = make(chan struct{})
	}
	return phoneEv.ch
}

// the last one, if it came at or after from; zero for none
func phoneMadeAfter(from time.Time) time.Time {
	phoneEv.Lock()
	defer phoneEv.Unlock()
	if phoneEv.at.IsZero() || phoneEv.at.Before(from) {
		return time.Time{}
	}
	return phoneEv.at
}

// the longest turn the first-contact listener waits on our own relays at a
// kick after the start (at the start it goes at once): a
// card scanned then is heard there within this, not after up to the whole
// spread. its own socket on its own lane, drawn apart from every batch
var fcOwnSpread = 20 * time.Second

// the longest turn a socket on our relays waits at the start, past the ones
// that go at once there
var ownStartSpread = 15 * time.Second

// the free turn on our relays at the start, when no first batch takes it
var ownFirst struct {
	sync.Mutex
	kick chan struct{}
}

// true for the first caller under kc, if the start has no first batch
func takeOwnFirstTurn(kc chan struct{}) bool {
	ownFirst.Lock()
	defer ownFirst.Unlock()
	if ownFirst.kick == kc {
		return false
	}
	ownFirst.kick = kc
	return !startFirstHolds(kc)
}

// the spread a socket's turn is drawn over at a start or kick
func spreadFor(lane string, own bool) time.Duration {
	if lane == laneFirstContact && own {
		return min(fcOwnSpread, subSpread)
	}
	return subSpread
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
	// the runner's lane
	lane string
	// the wake it last had a turn in, see takeWake
	wake int64
	// closed once the socket it shares is up, nil for a socket of its own:
	// then its turn is over, and it does not take the first one
	ready func() <-chan struct{}
	// the socket it shares, nil for one of its own: the socket's turn is
	// drawn once for all of its addresses (sharedDelay)
	batch *hubKey
	// the longest turn, 0 for subSpread
	spread time.Duration
	// the last take began its turn under the start, a kick a network
	// change or the app in front made, or a wake one of those came after.
	// a redial after a drop, a check-in or drain kick and a push wake are
	// not: a server can cause them at will, so those take no rank
	// (dialpace.go) and the open chat waits its turn
	made bool
	// when its socket last came up and last went down, zero for never
	upAt, downAt time.Time
}

func later(a, b time.Time) time.Time {
	if a.After(b) {
		return a
	}
	return b
}

// its socket went down: a relay's drop, a dead ping, a probe unanswered
func (t *subTurn) lost() { t.downAt = time.Now() }

// down since it was last up. one that came up and ended by a way that did
// not say so counts as up: it takes no rank
func (t *subTurn) downNow() bool {
	return t.upAt.IsZero() || !t.downAt.Before(t.upAt)
}

// its socket was down already at ev, a zero ev being none. a socket a
// relay drops after the event was up at it, or dialling and up soon after:
// its redial must not name the open chat, however soon it comes
func (t *subTurn) downBefore(ev time.Time) bool {
	return !ev.IsZero() && t.downNow() && !t.downAt.After(ev)
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
	t.made = false
	// before the look, so an event between the two still ends the wait
	pc := phoneChan()
	kc := kickChan()
	if n, w, ok := wakeNow(); ok {
		return t.takeWake(ctx, kc, n, w, pc)
	}
	if t.kick == kc {
		return ctx.Err() == nil
	}
	// under a phone's kick only if the socket was down when it came: one
	// that was dialling, in line or catching up then never took it, and a
	// relay could drop it later at a time of its own choosing
	t.made = t.downNow() && kickMadeSince(kc, t.downAt) || t.kick == nil && startKickPeek(kc)
	again := t.kick != nil && !t.up && !t.free
	first := t.kick == nil && t.fresh.holds(kc, autoNow())
	t.kick = kc
	t.free = first
	if again || first || t.made && isFirstTag(t.tag) {
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
		// ours at the start: a short turn, and the free one is left to the rest
		if t.own && isStartKick(kc) {
			if t.lane == laneFirstContact || takeOwnFirstTurn(kc) {
				return 0
			}
			return spreadDelay(min(ownStartSpread, subSpread), now)
		}
		if takeFirstTurn(kc) {
			return 0
		}
		if t.spread > 0 {
			return spreadDelay(t.spread, now)
		}
		return turnDelay(now)
	})
	if d <= 0 {
		return ctx.Err() == nil
	}
	return t.wait(ctx, d, up, pc)
}

// waits out a turn of d. a network change or the app coming to the front
// meanwhile ends the open chat's, and its dial ranks then
func (t *subTurn) wait(ctx context.Context, d time.Duration, up, pc <-chan struct{}) bool {
	tm := time.NewTimer(d)
	defer tm.Stop()
	for {
		select {
		case <-tm.C:
			return true
		case <-up:
			return ctx.Err() == nil
		case <-pc:
			if isFirstTag(t.tag) {
				t.made = true
				return ctx.Err() == nil
			}
			pc = phoneChan()
		case <-ctx.Done():
			return false
		}
	}
}

// after a wake every redial takes a turn, with or without a kick: the
// sockets the sleep killed find out at once or one ping at a time, and
// either way they would redial together. one turn per wake, and one more
// once it got through, as a socket that dies again after that does. ours
// before the public relays, the first of ours at once
func (t *subTurn) takeWake(ctx context.Context, kc chan struct{}, n int64, w wakeTurns, pc <-chan struct{}) bool {
	now := autoNow()
	first := t.kick == nil && t.fresh.holds(kc, now)
	had := t.wake == n
	newKick := t.kick != kc
	t.kick, t.wake, t.free = kc, n, first
	// the wake's own turn, if the app came to the front or the network
	// changed since the wake (a push wakes the phone too) while this
	// socket was down, or under a kick one of those made after the wake
	// that this socket did not answer live. the one more after a socket
	// that got through died again is a drop's
	seen := wakeSeenAt(n)
	t.made = !had && (t.downBefore(phoneMadeAfter(seen)) ||
		newKick && t.downNow() && kickMadeSince(kc, later(seen, t.downAt)))
	// a retry after a failed turn goes at its own backoff's pace
	if (had && !t.up) || first || t.made && isFirstTag(t.tag) {
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
	return t.wait(ctx, d, up, pc)
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
		t.up, t.upAt = true, time.Now()
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
