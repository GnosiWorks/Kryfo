// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// two reconnects never touch tor at once. one that is replaced stops at its
// next step: no bridge config on a live tor, no "off", no late network off
// after the one that replaced it has brought the network back. the times are
// a tenth of the phone's: a 30s bridge reconnect is 300ms here

type stepAt struct {
	owner int64
	step  string
}

type stepLog struct {
	mu    sync.Mutex
	steps []stepAt
}

func watchSteps(t *testing.T) *stepLog {
	l := &stepLog{}
	reconnectStepHook = func(owner int64, step string) {
		l.mu.Lock()
		l.steps = append(l.steps, stepAt{owner, step})
		l.mu.Unlock()
	}
	t.Cleanup(func() { reconnectStepHook = nil })
	return l
}

// no step of an older reconnect once a newer one has taken its first
func (l *stepLog) check(t *testing.T) {
	t.Helper()
	l.mu.Lock()
	defer l.mu.Unlock()
	var newest int64
	for _, s := range l.steps {
		if s.owner < newest {
			t.Fatalf("reconnect %d took %q after reconnect %d had begun: %v",
				s.owner, s.step, newest, l.steps)
		}
		newest = s.owner
	}
}

// the last thing tor was told about its network is to be on it, and only
// the last reconnect told it anything after another had begun
func endsOnTheNetwork(t *testing.T, f *fakeControl) {
	t.Helper()
	var last string
	for _, c := range f.sent() {
		if strings.Contains(c, "DISABLENETWORK") {
			last = c
		}
	}
	if !strings.Contains(last, "DISABLENETWORK=0") {
		t.Fatalf("tor was left with %q: %v", last, f.sent())
	}
}

func overlapRig(t *testing.T) *fakeControl {
	t.Helper()
	f := newFakeControl(t, 100)
	// the bridge config is the slow part: two commands at 150ms
	f.slow.Store(int64(150 * time.Millisecond))
	fakeTor(t, f.port())
	resetRoute(t, "publishing", 100)
	return f
}

// a bridge change, then two network changes 2s and 4s into it on the phone
func TestNetworkChangesDuringABridgeReconnect(t *testing.T) {
	f := overlapRig(t)
	l := watchSteps(t)
	var wg sync.WaitGroup
	results := make([]string, 3)
	run := func(i int, after time.Duration, fn func() string) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			time.Sleep(after)
			results[i] = fn()
		}()
	}
	run(0, 0, reconnectNow)
	run(1, 650*time.Millisecond, netReconnect)
	run(2, 850*time.Millisecond, netReconnect)
	wg.Wait()
	l.check(t)
	if results[2] != "ok" {
		t.Fatalf("the last change's reconnect: %v", results)
	}
	if results[0] != "ok" && results[0] != "error: superseded" {
		t.Fatalf("the bridge reconnect: %v", results)
	}
	endsOnTheNetwork(t, f)
	if st := statusNow(); st == "off" {
		t.Fatal("a replaced reconnect left the status off")
	}
	if atomic.LoadInt32(&torRestarting) != 0 || atomic.LoadInt32(&bounceOff) != 0 {
		t.Fatal("the slot or the bounce flag stayed set")
	}
}

// two bridge changes in quick succession, as two saves on the bridges
// screen: the second replaces the first, which stops where it is
func TestTwoQuickBridgeChanges(t *testing.T) {
	f := overlapRig(t)
	l := watchSteps(t)
	first := make(chan string, 1)
	go func() { first <- reconnectNow() }()
	time.Sleep(600 * time.Millisecond) // inside its bridge config
	second := reconnectNow()
	r1 := <-first
	l.check(t)
	if second != "ok" || r1 != "error: superseded" {
		t.Fatalf("first %q, second %q", r1, second)
	}
	endsOnTheNetwork(t, f)
	// and the second's commands came after everything the first sent
	sent := f.sent()
	offs := 0
	for _, c := range sent {
		if strings.Contains(c, "DISABLENETWORK=1") {
			offs++
		}
	}
	if offs != 2 {
		t.Fatalf("want each reconnect to take tor off once: %v", sent)
	}
}

// put to sleep while the reconnect ran: it must not bring tor back
func TestReconnectLeavesASleepingTorAsleep(t *testing.T) {
	f := overlapRig(t)
	f.slow.Store(0)
	reconnectStepHook = func(_ int64, step string) {
		if step == "network on" {
			atomic.StoreInt32(&torPaused, 1)
		}
	}
	defer func() { reconnectStepHook = nil; atomic.StoreInt32(&torPaused, 0) }()
	if r := reconnectNow(); r != "error: tor is asleep" {
		t.Fatalf("got %q", r)
	}
	for _, c := range f.sent() {
		if strings.Contains(c, "DISABLENETWORK=0") {
			t.Fatalf("a sleeping tor was woken: %v", f.sent())
		}
	}
}

// three claims at once: each run gets its own done channel and closes only
// that one. a run that read the slot after another claim took the next
// run's channel, closed it under it, and the next run closed it again
func TestThreeClaimsEachCloseTheirOwn(t *testing.T) {
	for round := 0; round < 500; round++ {
		var wg sync.WaitGroup
		seen := make(chan chan struct{}, 3)
		for i := 0; i < 3; i++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				me, prev, done, why := reconnectClaim(true)
				if why != "" || done == nil {
					t.Errorf("claim: %q", why)
					return
				}
				seen <- done
				if prev != nil {
					select {
					case <-prev:
					case <-time.After(2 * time.Second):
						t.Errorf("round %d: waited on a run that was not the one before", round)
					}
				}
				reconnectRelease(me, done)
			}()
		}
		wg.Wait()
		close(seen)
		got := map[chan struct{}]bool{}
		for c := range seen {
			if got[c] {
				t.Fatalf("round %d: two runs were handed one channel", round)
			}
			got[c] = true
		}
		if t.Failed() {
			return
		}
	}
	if atomic.LoadInt32(&torRestarting) != 0 {
		t.Fatal("the slot stayed taken")
	}
}

// the same through the whole reconnect: three forced at once, round after
// round, never a panic and never a minute's wait on someone else's channel
func TestThreeForcedReconnectsAtOnce(t *testing.T) {
	f := overlapRig(t)
	f.slow.Store(0)
	old, oldWait := bounceSettle, supersedeWait
	bounceSettle, supersedeWait = time.Millisecond, 5*time.Second
	defer func() { bounceSettle, supersedeWait = old, oldWait }()
	for round := 0; round < 30; round++ {
		began := time.Now()
		var wg sync.WaitGroup
		for i := 0; i < 3; i++ {
			wg.Add(1)
			go func() { defer wg.Done(); reconnectNow() }()
		}
		wg.Wait()
		if d := time.Since(began); d > 4*time.Second {
			t.Fatalf("round %d took %s: a run waited on a channel not its own", round, d)
		}
	}
	endsOnTheNetwork(t, f)
}
