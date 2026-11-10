// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"errors"
	"io"
	"log"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cretz/bine/tor"
)

// the engine on a socks port that acts as tor does towards onions, the
// route carrying, the queue fresh
func doorqSetup(t *testing.T, pending int) (*onionTor, *tor.Tor) {
	t.Helper()
	log.SetOutput(io.Discard)
	t.Cleanup(func() { log.SetOutput(os.Stderr) })
	useStandIns(t, modePrivate, nil)
	statusForTest(t, "reachable")
	routeNoteOK()
	o := newOnionTor(t, pending)
	atomic.StoreInt32(&pinnedSocks, int32(o.port()))
	o.door = ackDoor(t)
	doorQueueReset()
	t.Cleanup(func() {
		doorCloseAll()
		doorQueueReset()
		doorMu.Lock()
		doorSingle = map[string]time.Time{}
		doorMu.Unlock()
	})
	return o, torNode
}

// one onion's dial works, so tor is shown to reach onions and a failed
// dial after it says something of its peer
func proveDoors(t *testing.T, o *onionTor, tn *tor.Tor) {
	t.Helper()
	ok := fakeOnion(90000)
	setPlan(o, ok, onionPlan{build: 20 * time.Millisecond})
	if err := sendToAs(tn, ok, doorLine(t, 300), doorMessage); err != nil {
		t.Fatalf("a reachable onion: %v", err)
	}
}

func setPlan(o *onionTor, onion string, p onionPlan) {
	o.mu.Lock()
	o.plan[onion] = p
	o.mu.Unlock()
}

func doorqVar[T any](t *testing.T, v *T, to T) {
	old := *v
	*v = to
	t.Cleanup(func() { *v = old })
}

func waitQueueEmpty(t *testing.T) {
	t.Helper()
	until := time.Now().Add(5 * time.Second)
	for time.Now().Before(until) {
		d, o, w, _ := doorQueueNow()
		if d == 0 && o == 0 && w == 0 {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	d, o, w, _ := doorQueueNow()
	t.Fatalf("queue not empty: %d dialing, %d open, %d waiting", d, o, w)
}

// a herd of sends never has more dials or streams out than the caps
func TestDoorQueueCapsDialsAndStreams(t *testing.T) {
	doorqVar(t, &doorPaceGap, 10*time.Millisecond)
	o, tn := doorqSetup(t, 32)
	var wg sync.WaitGroup
	for i := 0; i < 60; i++ {
		on := fakeOnion(i)
		if i%3 == 0 {
			setPlan(o, on, onionPlan{build: 300 * time.Millisecond})
		} else {
			setPlan(o, on, onionPlan{build: 600 * time.Millisecond, fail: true})
		}
		wg.Add(1)
		go func() {
			defer wg.Done()
			sendToAs(tn, on, doorLine(t, 300), doorRest)
		}()
	}
	wg.Wait()
	if n := int(atomic.LoadInt32(&o.maxLive)); n > doorOpenMost {
		t.Fatalf("%d socks streams at once, cap %d", n, doorOpenMost)
	}
	doorQMu.Lock()
	dp, op := doorDialPeak, doorOpenPeak
	doorQMu.Unlock()
	// the open chat's slot stays free for it
	if dp > doorDialsMost-1 || op > doorOpenMost-1 {
		t.Fatalf("peaks %d dials %d open, want at most %d and %d", dp, op, doorDialsMost-1, doorOpenMost-1)
	}
	if dp < 2 {
		t.Fatalf("dial peak %d: the queue ran one at a time", dp)
	}
	doorCloseAll()
	waitQueueEmpty(t)
}

// the open chat's line goes while every other slot hangs on stuck onions
func TestOpenChatGoesPastStuckOnes(t *testing.T) {
	doorqVar(t, &doorDialMost, 3*time.Second)
	o, tn := doorqSetup(t, 32)
	open := fakeOnion(999)
	setPlan(o, open, onionPlan{build: 200 * time.Millisecond})
	doorFocus(open)
	var wg sync.WaitGroup
	for i := 0; i < 40; i++ {
		on := fakeOnion(i)
		setPlan(o, on, onionPlan{stuck: true})
		wg.Add(1)
		go func() {
			defer wg.Done()
			sendToAs(tn, on, doorLine(t, 300), doorMessage)
		}()
	}
	time.Sleep(300 * time.Millisecond)
	start := time.Now()
	if err := sendTo(tn, open, doorLine(t, 300)); err != nil {
		t.Fatalf("open chat: %v", err)
	}
	if d := time.Since(start); d > 2*time.Second {
		t.Fatalf("open chat took %v behind stuck dials", d)
	}
	wg.Wait()
}

// a dial that hangs is cut at its own deadline, gives its slot back, and
// its onion rests; the lines behind it are not held
func TestStuckDialIsCutAndRests(t *testing.T) {
	doorqVar(t, &doorDialMost, time.Second)
	o, tn := doorqSetup(t, 32)
	proveDoors(t, o, tn)
	stuck := fakeOnion(1)
	setPlan(o, stuck, onionPlan{stuck: true})
	start := time.Now()
	err := sendToAs(tn, stuck, doorLine(t, 300), doorMessage)
	if err == nil || time.Since(start) > 3*time.Second {
		t.Fatalf("stuck dial: %v after %v", err, time.Since(start))
	}
	waitQueueEmpty(t)
	if doorResting(stuck) == 0 {
		t.Fatal("a cut dial with the route carrying should rest the onion")
	}
	start = time.Now()
	if err := sendToAs(tn, stuck, doorLine(t, 300), doorMessage); !errors.Is(err, errDoorResting) {
		t.Fatalf("resting onion: %v", err)
	}
	if time.Since(start) > 100*time.Millisecond || o.dialsTo([]string{stuck}, false) != 1 {
		t.Fatalf("resting onion was dialled again (%d dials)", o.dialsTo([]string{stuck}, false))
	}
}

// an offline onion rests longer each time; their message or their chat
// opened ends the rest at once
func TestOfflineOnionBacksOffAndWakes(t *testing.T) {
	o, tn := doorqSetup(t, 32)
	proveDoors(t, o, tn)
	off := fakeOnion(2)
	setPlan(o, off, onionPlan{build: 50 * time.Millisecond, fail: true})
	if err := sendTo(tn, off, doorLine(t, 300)); err == nil {
		t.Fatal("offline onion took a line")
	}
	first := doorResting(off)
	if first < doorRestFirst/2-time.Second || first > doorRestFirst {
		t.Fatalf("first rest %v, want %v to %v", first, doorRestFirst/2, doorRestFirst)
	}
	doorAwake(off)
	if doorResting(off) != 0 {
		t.Fatal("a message from them should end the rest")
	}
	// the failures in a row are forgotten too: the next rest is a first one
	sendTo(tn, off, doorLine(t, 300))
	if r := doorResting(off); r > doorRestFirst {
		t.Fatalf("rest after a wake %v, want a first one", r)
	}
	// opening their chat dials at once, rest or not
	doorQMu.Lock()
	doorPeers[off].fails = 5
	doorPeers[off].until = time.Now().Add(time.Hour)
	doorQMu.Unlock()
	doorFocus(off)
	setPlan(o, off, onionPlan{build: 50 * time.Millisecond})
	if err := sendTo(tn, off, doorLine(t, 300)); err != nil {
		t.Fatalf("open chat to a resting onion: %v", err)
	}
	if doorResting(off) != 0 {
		t.Fatal("a dial that worked should end the rest")
	}
}

func TestDoorRestGrowsWithJitter(t *testing.T) {
	seen := map[time.Duration]bool{}
	for n := 1; n <= 12; n++ {
		want := doorRestFirst << (n - 1)
		if want > doorRestMost || want <= 0 {
			want = doorRestMost
		}
		for i := 0; i < 50; i++ {
			d := doorRestFor(n)
			if d < want/2 || d > want {
				t.Fatalf("rest %d: %v outside %v..%v", n, d, want/2, want)
			}
			seen[d] = true
		}
	}
	if len(seen) < 100 {
		t.Fatalf("only %d distinct rests: no jitter", len(seen))
	}
}

// a tor that fails every dial says nothing of the peers: no rest while the
// route does not carry
func TestNoRestWhileTheRouteIsDown(t *testing.T) {
	o, tn := doorqSetup(t, 32)
	statusForTest(t, "starting")
	off := fakeOnion(3)
	setPlan(o, off, onionPlan{build: 50 * time.Millisecond, fail: true})
	sendTo(tn, off, doorLine(t, 300))
	if doorResting(off) != 0 {
		t.Fatal("a dial through a tor that is not up rested the onion")
	}
}

// a line of the rest waits behind messages for a while, then moves up: a
// steady stream of messages never keeps it out
func TestRestLineIsNotStarved(t *testing.T) {
	doorqVar(t, &doorDialsMost, 2)
	doorqVar(t, &doorOpenMost, 3)
	doorqVar(t, &doorPaceGap, 10*time.Millisecond)
	o, tn := doorqSetup(t, 32)
	rest := fakeOnion(500)
	setPlan(o, rest, onionPlan{build: 100 * time.Millisecond})
	stop := make(chan struct{})
	var wg sync.WaitGroup
	for w := 0; w < 8; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := 0; ; i++ {
				select {
				case <-stop:
					return
				default:
				}
				on := fakeOnion(1000 + w*1000 + i)
				setPlan(o, on, onionPlan{build: 300 * time.Millisecond, fail: true})
				sendToAs(tn, on, doorLine(t, 300), doorMessage)
			}
		}()
	}
	time.Sleep(500 * time.Millisecond)
	start := time.Now()
	err := sendToAs(tn, rest, doorLine(t, 300), doorRest)
	took := time.Since(start)
	close(stop)
	wg.Wait()
	if err != nil {
		t.Fatalf("rest line under a stream of messages: %v after %v", err, took)
	}
	if took > 3*doorAge {
		t.Fatalf("rest line waited %v", took)
	}
}

// a kept stream with nothing on it closes for a line that waits
func TestIdleStreamGivesWay(t *testing.T) {
	doorqVar(t, &doorOpenMost, 2)
	doorqVar(t, &doorKeep, 30*time.Second)
	o, tn := doorqSetup(t, 32)
	a, b := fakeOnion(10), fakeOnion(11)
	setPlan(o, a, onionPlan{build: 50 * time.Millisecond})
	setPlan(o, b, onionPlan{build: 50 * time.Millisecond})
	if err := sendTo(tn, a, doorLine(t, 300)); err != nil {
		t.Fatal(err)
	}
	start := time.Now()
	if err := sendTo(tn, b, doorLine(t, 300)); err != nil {
		t.Fatal(err)
	}
	if d := time.Since(start); d > time.Second {
		t.Fatalf("waited %v behind an idle stream", d)
	}
}

// a line that gets no slot in its budget fails at once and leaves the
// queue: nothing is left waiting
func TestQueuedLineLeavesInTime(t *testing.T) {
	doorqVar(t, &doorDialsMost, 2)
	doorqVar(t, &doorDialLeast, doorLineBudget-time.Second)
	doorqVar(t, &doorDialMost, 3*time.Second)
	o, tn := doorqSetup(t, 32)
	hang := fakeOnion(20)
	setPlan(o, hang, onionPlan{stuck: true})
	var wg sync.WaitGroup
	wg.Add(1)
	defer wg.Wait()
	go func() { defer wg.Done(); sendToAs(tn, hang, doorLine(t, 300), doorMessage) }()
	time.Sleep(200 * time.Millisecond)
	next := fakeOnion(21)
	setPlan(o, next, onionPlan{build: 50 * time.Millisecond})
	start := time.Now()
	err := sendToAs(tn, next, doorLine(t, 300), doorMessage)
	if !errors.Is(err, errDoorBusy) || time.Since(start) > 2*time.Second {
		t.Fatalf("queued line: %v after %v", err, time.Since(start))
	}
	if _, _, w, _ := doorQueueNow(); w != 0 {
		t.Fatalf("%d lines left waiting", w)
	}
	if o.dialsTo([]string{next}, false) != 0 {
		t.Fatal("a line that left the queue was dialled")
	}
}

// a herd of new dials comes out as a trickle: the burst, then one each gap.
// the open chat's dial and a redial to an onion that just answered skip it
func TestNewDialsArePaced(t *testing.T) {
	doorqVar(t, &doorPaceGap, 200*time.Millisecond)
	o, tn := doorqSetup(t, 32)
	var wg sync.WaitGroup
	start := time.Now()
	for i := 0; i < 20; i++ {
		on := fakeOnion(i)
		setPlan(o, on, onionPlan{build: 50 * time.Millisecond, fail: true})
		wg.Add(1)
		go func() {
			defer wg.Done()
			sendToAs(tn, on, doorLine(t, 300), doorRest)
		}()
	}
	wg.Wait()
	o.mu.Lock()
	ts := append([]time.Time{}, o.opened...)
	o.mu.Unlock()
	if len(ts) != 20 {
		t.Fatalf("%d of 20 dialled", len(ts))
	}
	// four at once, then 5 a second at most with up to half a gap more
	if p := peakIn(ts, time.Second); p > doorPaceBurst+5 {
		t.Fatalf("%d new dials in one second", p)
	}
	if d := time.Since(start); d < 16*doorPaceGap {
		t.Fatalf("20 dials in %v: not paced", d)
	}
	// the open chat goes at once, whatever the pace owes
	open := fakeOnion(100)
	setPlan(o, open, onionPlan{build: 20 * time.Millisecond})
	for i := 0; i < 10; i++ {
		doorPaceFor(fakeOnion(200+i), doorRest)
	}
	doorFocus(open)
	at := time.Now()
	if err := sendTo(tn, open, doorLine(t, 300)); err != nil || time.Since(at) > time.Second {
		t.Fatalf("open chat behind the pace: %v after %v", err, time.Since(at))
	}
	// an onion that just answered is dialled again at once
	if d := doorPaceFor(open, doorRest); d != 0 {
		t.Fatalf("a redial to an onion up a moment ago waits %v", d)
	}
}

// a receipt to x waits for a slot; x's chat opens and a reply goes: the
// reply joins the receipt's dial and takes it to the open chat's place
// (review F1)
func TestOpenChatReplyIsNotBehindAReceipt(t *testing.T) {
	doorqVar(t, &doorDialsMost, 2)
	doorqVar(t, &doorOpenMost, 3)
	doorqVar(t, &doorDialMost, 10*time.Second)
	o, tn := doorqSetup(t, 32)
	stuck := fakeOnion(1)
	setPlan(o, stuck, onionPlan{stuck: true})
	x := fakeOnion(2)
	setPlan(o, x, onionPlan{build: 100 * time.Millisecond})
	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); sendToAs(tn, stuck, doorLine(t, 300), doorMessage) }()
	time.Sleep(200 * time.Millisecond)
	go func() { defer wg.Done(); sendToAs(tn, x, doorLine(t, 300), doorRest) }()
	time.Sleep(200 * time.Millisecond)
	doorFocus(x)
	start := time.Now()
	if err := sendTo(tn, x, doorLine(t, 300)); err != nil {
		t.Fatalf("open chat line: %v", err)
	}
	if took := time.Since(start); took > 2*time.Second {
		t.Fatalf("open chat waited %v behind a receipt's queue place", took)
	}
	// a message joining a receipt's dial moves it up the same way
	y := fakeOnion(3)
	setPlan(o, y, onionPlan{build: 100 * time.Millisecond})
	doorQMu.Lock()
	w := &doorWaiter{onion: y, pri: doorRest, since: time.Now(), grant: make(chan struct{})}
	doorWaiters = append(doorWaiters, w)
	doorQMu.Unlock()
	doorRaise(y, doorMessage)
	doorQMu.Lock()
	got := w.pri
	for i, x := range doorWaiters {
		if x == w {
			doorWaiters = append(doorWaiters[:i], doorWaiters[i+1:]...)
			break
		}
	}
	if w.given {
		doorDialing--
		doorOpen--
	}
	doorQMu.Unlock()
	if got != doorMessage {
		t.Fatalf("a receipt's waiter kept place %d under a message", got)
	}
	wg.Wait()
}

// with no onion dial working on this tor lately, a failed dial rests
// nobody: in fast mode routeOK is true whatever tor does (review F2)
func TestNoRestUntilAnotherOnionAnswers(t *testing.T) {
	doorqVar(t, &doorDialMost, time.Second)
	o, tn := doorqSetup(t, 32)
	transportMode.Store(modeFast)
	off := fakeOnion(4)
	setPlan(o, off, onionPlan{build: 50 * time.Millisecond, fail: true})
	sendTo(tn, off, doorLine(t, 300))
	if doorResting(off) != 0 {
		t.Fatal("rested with no onion dial working on this tor")
	}
	proveDoors(t, o, tn)
	sendTo(tn, off, doorLine(t, 300))
	if doorResting(off) == 0 {
		t.Fatal("not rested after another onion answered")
	}
	// an answer from long ago proves nothing now
	doorAwake(off)
	doorQMu.Lock()
	doorOKAt = time.Now().Add(-doorOKFor - time.Second)
	doorQMu.Unlock()
	sendTo(tn, off, doorLine(t, 300))
	if doorResting(off) != 0 {
		t.Fatal("rested on an old answer")
	}
}

// the open chat's onion collects no rest while it is open (review F4)
func TestOpenChatNeverRests(t *testing.T) {
	o, tn := doorqSetup(t, 32)
	proveDoors(t, o, tn)
	off := fakeOnion(5)
	setPlan(o, off, onionPlan{build: 50 * time.Millisecond, fail: true})
	doorFocus(off)
	for i := 0; i < 3; i++ {
		sendTo(tn, off, doorLine(t, 300))
	}
	doorFocus("")
	if r := doorResting(off); r != 0 {
		t.Fatalf("the open chat's onion rests %v after it closed", r)
	}
}

// a contact who wrote still waits for the pace: only a dial that worked
// skips it (review F5)
func TestAWordFromThemDoesNotSkipThePace(t *testing.T) {
	doorqVar(t, &doorPaceGap, time.Second)
	doorqSetup(t, 32)
	for i := 0; i < doorPaceBurst+2; i++ {
		doorPaceFor(fakeOnion(300+i), doorRest)
	}
	wrote := fakeOnion(6)
	doorAwake(wrote)
	if d := doorPaceFor(wrote, doorRest); d == 0 {
		t.Fatal("a contact who wrote skipped the pace")
	}
}

// a receipt to the open chat keeps the rest's place, so its timing does not
// tell the peer their chat is open; a message or typing takes the open
// chat's
func TestReceiptToTheOpenChatKeepsItsPlace(t *testing.T) {
	doorqSetup(t, 32)
	x := fakeOnion(7)
	doorFocus(x)
	if p := doorPlaceNow(x, doorRest); p != doorRest {
		t.Fatalf("a receipt to the open chat took place %d", p)
	}
	if p := doorPlaceNow(x, doorMessage); p != doorOpenChat {
		t.Fatalf("a message to the open chat took place %d", p)
	}
	if p := doorPlaceNow(fakeOnion(8), doorMessage); p != doorMessage {
		t.Fatalf("a message elsewhere took place %d", p)
	}
}

// a raise with no dial under way to its onion is let go: it would lift the
// next dial there, a receipt among them, to the open chat's place
func TestRaiseWithNoDialGoesStale(t *testing.T) {
	doorqSetup(t, 32)
	x := fakeOnion(9)
	doorRaise(x, doorOpenChat)
	if p := doorPlaceNow(x, doorRest); p != doorRest {
		t.Fatalf("a receipt took place %d from a raise with no dial", p)
	}
	// while a dial is under way the raise holds, and goes with it
	doorQMu.Lock()
	doorDialsTo[x]++
	doorQMu.Unlock()
	doorRaise(x, doorOpenChat)
	if p := doorPlaceNow(x, doorRest); p != doorOpenChat {
		t.Fatalf("a raised dial took place %d", p)
	}
	doorQMu.Lock()
	delete(doorDialsTo, x)
	delete(doorRaisedOpen, x)
	doorQMu.Unlock()
}
