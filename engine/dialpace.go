// SPDX-License-Identifier: GPL-3.0-or-later
package main

// new tcp to a relay, paced. in fast mode our stores' batch sockets are
// direct, and after a drop or at the start they would all redial in one
// second, about one per eight contacts on each store: a burst a home
// router's flood guard may throttle. so a direct socket takes a place first:
// at once when the line is empty and the last went a gap ago, else best rank
// first. a place only starts a dial, so a stuck one holds nothing back. a
// send takes no place, the next one waits a gap after it. dials through tor
// add no tcp and pass.

import (
	"context"
	mrand "math/rand/v2"
	"slices"
	"sync"
	"sync/atomic"
	"time"
)

// 260 ms plus up to 80: about 3.3 a second, at most 4 in any second, no
// fixed beat. 38 sockets for 150 contacts on our two stores are out in
// ~12 s, 68 for 271 in ~20 s. 0 in the tests that do not measure it
var paceGap, paceJitter = newDur(260 * time.Millisecond), newDur(80 * time.Millisecond)

func newDur(d time.Duration) *atomic.Int64 {
	var v atomic.Int64
	v.Store(int64(d))
	return &v
}

// a place's rank, best first
const (
	// the open chat's batch, a batch written to lately
	paceFirst = iota
	// the start's first batch, the chats on top of the list
	paceTop
	paceRest
	// a redial after a drop the phone did not make: the relay can drop an
	// ip's sockets at will, so these take no rank and go in a drawn order,
	// or the open chat's batch coming back first would name it
	paceAny
)

// how long a chat written to counts as waiting for an answer: its batch
// goes first
var paceSentFor = 10 * time.Minute

type paceTicket struct {
	rank int
	seq  uint64
	// closed once its place came, at at
	ok chan struct{}
	at time.Time
}

var dialPace struct {
	sync.Mutex
	q []*paceTicket
	// no place before this
	next  time.Time
	seq   uint64
	timer *time.Timer
	// batch lanes written to, until when they go first
	sent map[string]time.Time
}

// a direct dial to relay u on lane takes a place
func paceNeeded(lane, u string) bool {
	return paceGap.Load() > 0 && !relayOverTor(lane, u)
}

// a ticket in line, or nil when the dial needs no place
func paceJoin(lane, u string, rank int) *paceTicket {
	if !paceNeeded(lane, u) {
		return nil
	}
	dialPace.Lock()
	defer dialPace.Unlock()
	dialPace.seq++
	t := &paceTicket{rank: rank, seq: dialPace.seq, ok: make(chan struct{})}
	dialPace.q = append(dialPace.q, t)
	paceRunLocked()
	return t
}

// waits for t's place. a nil ticket has it. an error once ctx ends first:
// t has left the line then
func (t *paceTicket) wait(ctx context.Context) error {
	if t == nil {
		return nil
	}
	select {
	case <-t.ok:
		return nil
	case <-ctx.Done():
	}
	dialPace.Lock()
	defer dialPace.Unlock()
	if isClosed(t.ok) {
		// the place came with the end: it is used, the dial is not made
		return ctx.Err()
	}
	dialPace.q = slices.DeleteFunc(dialPace.q, func(x *paceTicket) bool { return x == t })
	return ctx.Err()
}

// t moves up to rank, if that is better and it still waits
func (t *paceTicket) raise(rank int) {
	if t == nil {
		return
	}
	dialPace.Lock()
	defer dialPace.Unlock()
	if rank < t.rank {
		t.rank = rank
	}
}

// a dial that took no place went now: the next place waits a gap after it
func paceCount(lane, u string) {
	if !paceNeeded(lane, u) {
		return
	}
	dialPace.Lock()
	defer dialPace.Unlock()
	if next := time.Now().Add(paceDraw()); next.After(dialPace.next) {
		dialPace.next = next
	}
	paceRunLocked()
}

func paceDraw() time.Duration {
	d := time.Duration(paceGap.Load())
	if j := paceJitter.Load(); j > 0 {
		d += time.Duration(mrand.Int64N(j))
	}
	return d
}

// under dialPace: the best ticket gets its place if its time came, else a
// timer is set for then
func paceRunLocked() {
	if len(dialPace.q) == 0 {
		return
	}
	now := time.Now()
	if wait := dialPace.next.Sub(now); wait > 0 {
		if dialPace.timer == nil {
			dialPace.timer = time.AfterFunc(wait, func() {
				dialPace.Lock()
				defer dialPace.Unlock()
				dialPace.timer = nil
				paceRunLocked()
			})
		}
		return
	}
	best := 0
	for i, t := range dialPace.q {
		b := dialPace.q[best]
		if t.rank < b.rank || (t.rank == b.rank && t.seq < b.seq) {
			best = i
		}
	}
	if dialPace.q[best].rank == paceAny {
		// one drawn from them, not the first to come
		var drawn []int
		for i, t := range dialPace.q {
			if t.rank == paceAny {
				drawn = append(drawn, i)
			}
		}
		best = drawn[mrand.IntN(len(drawn))]
	}
	t := dialPace.q[best]
	dialPace.q = slices.Delete(dialPace.q, best, best+1)
	t.at = now
	if h := paceGrantHook; h != nil {
		h(t)
	}
	close(t.ok)
	dialPace.next = now.Add(paceDraw())
	paceRunLocked()
}

// pair c was written to: its batch goes first for a while, the answer
// comes in there
func paceNoteSent(c convPair) {
	if c.dev != nil {
		return
	}
	_, rcvPk, err := c.rcvAddress()
	if err != nil {
		return
	}
	set := contactSet(c.ident)
	n, ok := batchFind(set, rcvPk)
	if !ok {
		return
	}
	lane := batchLane(set, n)
	dialPace.Lock()
	defer dialPace.Unlock()
	if dialPace.sent == nil || len(dialPace.sent) > 1024 {
		dialPace.sent = map[string]time.Time{}
	}
	dialPace.sent[lane] = time.Now().Add(paceSentFor)
}

func paceSentLately(lane string) bool {
	dialPace.Lock()
	defer dialPace.Unlock()
	until, ok := dialPace.sent[lane]
	return ok && time.Now().Before(until)
}

// the lane the open chat's address listens on, "" for none: its batch
// goes first whichever of its addresses dials it
func paceOpenLane() string {
	f, _ := firstTag.Load().(string)
	if f == "" {
		return ""
	}
	knockNotesMu.Lock()
	defer knockNotesMu.Unlock()
	return knockNotes[f].lane
}

// called with each place given, under dialPace. for the tests
var paceGrantHook func(*paceTicket)

// the rank of a runner's socket: tag its peer, lane its batch's or own.
// made: its turn came from a kick, wake or start the phone made itself
func paceRankFor(tag, lane string, made bool) int {
	if !made {
		return paceAny
	}
	switch {
	case isFirstTag(tag), lane == paceOpenLane(), paceSentLately(lane):
		return paceFirst
	case lane == startFirstLane():
		return paceTop
	}
	return paceRest
}
