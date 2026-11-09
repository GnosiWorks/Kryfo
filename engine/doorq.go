// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the onion door's queue. every send to a peer's onion took its own dial at
// once, so a pass after the route came back (an outbox, a group, receipts)
// put a dial per contact on tor together. tor builds at most 32 circuits at
// a time for streams (MaxClientCircuitsPending), and an offline onion holds
// one while tor walks the hsdirs, so the open chat's line waited behind
// every offline contact, and the relay sockets' own circuits with it.
//
// now a dial takes a slot first. at most doorDialsMost dial at once and
// doorOpenMost door streams are open, dials included, one of each kept for
// the open chat. a line waits for a slot in order: the open chat, then
// messages, then the rest, and a line that waited moves up, so nothing
// waits for ever. a line that gets no slot in its budget fails at once and
// goes by the relay copy that races it, as a dial that failed did.
//
// new dials are paced: a burst of four, then one each half second with
// jitter, the open chat's apart. a dial is a socks stream, carried on tor's
// guard connection, so the pace spares tor's circuit builds rather than the
// phone's tcp.
//
// an onion whose dial failed while the route carried rests: no dial until
// its backoff ends, 30 s doubling to 30 min, jittered. a line to it fails at
// once. their message, opening their chat, or a dial that worked ends it.

import (
	"context"
	"errors"
	"math/rand/v2"
	"sync"
	"time"
)

// what a line is, for its place in the queue
const (
	doorOpenChat = 0 // the chat on screen
	doorMessage  = 1 // a message, new or unsent
	doorRest     = 2 // receipts, edits, controls and the like
)

var (
	// an onion dial holds one to three of tor's 32 pending circuits: eight
	// leave most of them to the relay sockets
	doorDialsMost = 8
	doorOpenMost  = 12
	// a line that waited this long moves up one place
	doorAge = 3 * time.Second
	// an onion that answered lately is likely there again: it goes first
	// among its place
	doorKnownFor   = 6 * time.Hour
	doorKnownAhead = 2 * time.Second
	// a dial gets this long at most, whatever its line's budget
	doorDialMost = 15 * time.Second
	// a line leaves the queue with this much of its budget still left, so
	// a dial it gets has time to finish
	doorDialLeast = 4 * time.Second
	// an onion's rest after its nth failed dial in a row
	doorRestFirst = 30 * time.Second
	doorRestMost  = 30 * time.Minute
	// new dials at most this often after a burst of doorPaceBurst, each
	// put off by up to half a gap more, so a herd comes out as a trickle
	doorPaceGap   = 500 * time.Millisecond
	doorPaceBurst = 4
)

var (
	errDoorBusy    = errors.New("door queue full in the line's time")
	errDoorResting = errors.New("onion resting after failed dials")
)

type doorWaiter struct {
	onion string
	pri   int
	since time.Time
	grant chan struct{}
	given bool // under doorQMu
}

type doorPeer struct {
	fails int
	until time.Time
	// the last sign they were up: a dial that worked or a frame from them
	upAt time.Time
	// the last dial to them that worked
	dialUpAt time.Time
}

var (
	doorQMu     sync.Mutex
	doorDialing int
	doorOpen    int
	doorWaiters []*doorWaiter
	doorPeers   = map[string]*doorPeer{}
	doorFocused string
	// waiters raised to the open chat's place, by onion: their dial skips
	// the pace too
	doorRaisedOpen = map[string]bool{}
	// the last dial that worked, to which onion and in which route generation:
	// only then does a failed dial say something of its peer
	doorOKAt    time.Time
	doorOKOnion string
	doorOKGen   int64 = -1
	// the most at once since the last reset, for the transport page and tests
	doorDialPeak, doorOpenPeak int
)

// a dial's slot and its stream's slot, each given back once
type doorSlot struct {
	dialOnce, openOnce sync.Once
}

func (sl *doorSlot) dialDone() {
	if sl == nil {
		return
	}
	sl.dialOnce.Do(func() {
		doorQMu.Lock()
		doorDialing--
		doorPump()
		doorQMu.Unlock()
	})
}

func (sl *doorSlot) closed() {
	if sl == nil {
		return
	}
	sl.dialDone()
	sl.openOnce.Do(func() {
		doorQMu.Lock()
		doorOpen--
		doorPump()
		doorQMu.Unlock()
	})
}

// the place a waiter takes now: lower goes first
func doorRank(w *doorWaiter, now time.Time) time.Duration {
	r := time.Duration(w.pri)*doorAge - now.Sub(w.since)
	if p := doorPeers[w.onion]; p != nil && !p.upAt.IsZero() && now.Sub(p.upAt) < doorKnownFor {
		r -= doorKnownAhead
	}
	return r
}

// a waiter may take a slot when one is free for its place: the last dial
// and the last stream are the open chat's
func doorRoomFor(pri int) bool {
	dials, open := doorDialsMost, doorOpenMost
	if pri != doorOpenChat {
		dials, open = dials-1, open-1
	}
	return doorDialing < dials && doorOpen < open
}

// hands out free slots, best placed waiter first. under doorQMu
func doorPump() {
	now := time.Now()
	for len(doorWaiters) > 0 {
		best := -1
		for i, w := range doorWaiters {
			if !doorRoomFor(w.pri) {
				continue
			}
			if best < 0 || doorRank(w, now) < doorRank(doorWaiters[best], now) {
				best = i
			}
		}
		if best < 0 {
			return
		}
		w := doorWaiters[best]
		doorWaiters = append(doorWaiters[:best], doorWaiters[best+1:]...)
		doorTake()
		w.given = true
		close(w.grant)
	}
}

// under doorQMu
func doorTake() {
	doorDialing++
	doorOpen++
	doorDialPeak = max(doorDialPeak, doorDialing)
	doorOpenPeak = max(doorOpenPeak, doorOpen)
}

// a line of place pri joined onion's stream while it waits for its dial:
// the waiter for that dial moves up to the line's place, so a reply in the
// open chat never waits behind a receipt queued before it
func doorRaise(onion string, pri int) {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	if pri == doorOpenChat {
		doorRaisedOpen[onion] = true
	}
	for _, w := range doorWaiters {
		if w.onion == onion && pri < w.pri {
			w.pri = pri
		}
	}
	doorPump()
}

// the dial's own place now: raised while it waited, or the open chat's for
// what is not the rest. a receipt to the open chat keeps the rest's place,
// so its timing does not tell the peer their chat is open here
func doorPlaceNow(onion string, pri int) int {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	return doorPlaceOf(onion, pri)
}

// under doorQMu
func doorPlaceOf(onion string, pri int) int {
	if doorRaisedOpen[onion] || onion == doorFocused && pri != doorRest {
		return doorOpenChat
	}
	return pri
}

// a slot for a dial to onion, or errDoorBusy once ctx has too little left
// for a dial. an open chat's line only waits for the open chat's slot
func doorSlotFor(ctx context.Context, onion string, pri int) (*doorSlot, error) {
	w := &doorWaiter{onion: onion, since: time.Now(), grant: make(chan struct{})}
	doorQMu.Lock()
	w.pri = doorPlaceOf(onion, pri)
	doorWaiters = append(doorWaiters, w)
	doorPump()
	given := w.given
	doorQMu.Unlock()
	if given {
		return &doorSlot{}, nil
	}
	// a stream that only waits out its keep gives way to a line that waits
	doorGiveWay()
	wait := ctx
	if d, ok := ctx.Deadline(); ok {
		var cancel context.CancelFunc
		wait, cancel = context.WithDeadline(ctx, d.Add(-doorDialLeast))
		defer cancel()
	}
	select {
	case <-w.grant:
		return &doorSlot{}, nil
	case <-wait.Done():
	}
	doorQMu.Lock()
	defer doorQMu.Unlock()
	if w.given {
		// given as the wait ran out: handed on
		doorDialing--
		doorOpen--
		doorPump()
		return nil, errDoorBusy
	}
	for i, x := range doorWaiters {
		if x == w {
			doorWaiters = append(doorWaiters[:i], doorWaiters[i+1:]...)
			break
		}
	}
	return nil, errDoorBusy
}

// lines wait while the streams are full
func doorRoomWanted() bool {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	return len(doorWaiters) > 0 && doorOpen >= doorOpenMost-1
}

var (
	doorPaceMu   sync.Mutex
	doorPaceNext time.Time
)

// how long a dial waits for its turn: none inside the burst, then one gap
// apart, jittered. the open chat's dial, and one to an onion that answered
// a moment ago (an older door takes a stream per line), never wait
func doorPaceFor(onion string, pri int) time.Duration {
	if pri == doorOpenChat || doorJustUp(onion) {
		return 0
	}
	doorPaceMu.Lock()
	defer doorPaceMu.Unlock()
	now := time.Now()
	if floor := now.Add(-time.Duration(doorPaceBurst) * doorPaceGap); doorPaceNext.Before(floor) {
		doorPaceNext = floor
	}
	doorPaceNext = doorPaceNext.Add(doorPaceGap)
	wait := doorPaceNext.Sub(now)
	if wait <= 0 {
		return 0
	}
	return wait + rand.N(doorPaceGap/2)
}

// waits out a dial's turn, or false when ctx ends first. a dial raised to
// the open chat's place while it waits goes at once
func doorPace(ctx context.Context, onion string, pri int) bool {
	d := doorPaceFor(onion, pri)
	if d <= 0 {
		return true
	}
	end := time.NewTimer(d)
	defer end.Stop()
	look := time.NewTicker(100 * time.Millisecond)
	defer look.Stop()
	for {
		select {
		case <-end.C:
			return true
		case <-look.C:
			if doorPlaceNow(onion, pri) == doorOpenChat {
				return true
			}
		case <-ctx.Done():
			return false
		}
	}
}

// kept streams with no line on them close while lines wait for a slot
func doorGiveWay() {
	if !doorRoomWanted() {
		return
	}
	doorMu.Lock()
	var idle []*doorStream
	for _, s := range doorStreams {
		// conn is written before ready closes, without s.mu
		select {
		case <-s.ready:
		default:
			continue
		}
		s.mu.Lock()
		if s.busy == 0 && s.err == nil && s.conn != nil {
			idle = append(idle, s)
		}
		s.mu.Unlock()
	}
	doorMu.Unlock()
	for _, s := range idle {
		s.mu.Lock()
		still := s.busy == 0
		s.mu.Unlock()
		if still {
			s.fail(errors.New("gave way to a waiting line"), false)
		}
	}
}

// a dial to onion worked within the last minute
func doorJustUp(onion string) bool {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	p := doorPeers[onion]
	return p != nil && p.fails == 0 && !p.dialUpAt.IsZero() && time.Since(p.dialUpAt) < time.Minute
}

// how long onion still rests, zero when it may be dialled
func doorResting(onion string) time.Duration {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	p := doorPeers[onion]
	if p == nil || p.until.IsZero() {
		return 0
	}
	return max(0, time.Until(p.until))
}

// a dial to onion worked: whatever it rested for is over
func doorDialOK(onion string) {
	gen := routeGeneration()
	doorQMu.Lock()
	defer doorQMu.Unlock()
	p := doorPeer0(onion)
	now := time.Now()
	p.fails, p.until, p.upAt, p.dialUpAt = 0, time.Time{}, now, now
	doorOKAt, doorOKOnion, doorOKGen = now, onion, gen
}

// how lately another onion's dial must have worked, on the same tor, for a
// failed dial to say something of its peer
var doorOKFor = 2 * time.Minute

// a dial to onion failed. it is the onion's only while the route carried,
// through the same tor it began on, and another onion's dial worked on that
// tor lately: a tor that stalls under every dial, or a route that only the
// relays prove (fast and relay modes), says nothing of the peers. the open
// chat's onion never rests
func doorDialFailed(onion string, gen int64) {
	if !routeOK() || routeGeneration() != gen {
		return
	}
	doorQMu.Lock()
	defer doorQMu.Unlock()
	if onion == doorFocused || doorOKGen != gen || doorOKOnion == onion || time.Since(doorOKAt) > doorOKFor {
		return
	}
	p := doorPeer0(onion)
	p.fails++
	p.until = time.Now().Add(doorRestFor(p.fails))
}

// under doorQMu
func doorPeer0(onion string) *doorPeer {
	p := doorPeers[onion]
	if p == nil {
		// one map entry per onion dialled, never more than the contacts
		if len(doorPeers) > 4096 {
			doorPeers = map[string]*doorPeer{}
		}
		p = &doorPeer{}
		doorPeers[onion] = p
	}
	return p
}

// the rest after the nth failure in a row: doubling, capped, and drawn from
// its upper half so tries to many offline onions never line up in time
func doorRestFor(n int) time.Duration {
	d := doorRestFirst
	for i := 1; i < n && d < doorRestMost; i++ {
		d *= 2
	}
	d = min(d, doorRestMost)
	return d/2 + rand.N(d/2+1)
}

// the peer showed up (a frame from them): the next line dials at once, and
// ahead of onions not heard of lately
func doorAwake(onion string) {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	p := doorPeer0(onion)
	p.fails, p.until, p.upAt = 0, time.Time{}, time.Now()
}

// the chat on screen, "" for none. its lines go first and never rest
func doorFocus(onion string) {
	doorQMu.Lock()
	doorFocused = onion
	if p := doorPeers[onion]; p != nil {
		p.fails, p.until = 0, time.Time{}
	}
	doorQMu.Unlock()
}

func doorFocusNow() string {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	return doorFocused
}

// the queue now, for tests: dials, open streams, waiting lines, onions
// resting
func doorQueueNow() (dialing, open, waiting, resting int) {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	now := time.Now()
	for _, p := range doorPeers {
		if p.until.After(now) {
			resting++
		}
	}
	return doorDialing, doorOpen, len(doorWaiters), resting
}

// everything back to a fresh start: the onions' rests, the peaks, the focus
func doorQueueReset() {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	doorPeers = map[string]*doorPeer{}
	doorFocused = ""
	doorRaisedOpen = map[string]bool{}
	doorOKAt, doorOKOnion, doorOKGen = time.Time{}, "", -1
	doorPaceMu.Lock()
	doorPaceNext = time.Time{}
	doorPaceMu.Unlock()
	doorDialPeak, doorOpenPeak = doorDialing, doorOpen
}
