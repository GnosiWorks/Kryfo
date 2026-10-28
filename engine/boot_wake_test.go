// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"testing"
	"time"
)

func bootPollsForTest(t *testing.T, poll, slow, end time.Duration, endFor time.Duration) {
	t.Helper()
	oldP, oldS, oldF, oldE, oldEF := bootPoll, bootPollSlow, bootFast, bootPollEnd, bootEndFor
	t.Cleanup(func() {
		bootPoll, bootPollSlow, bootFast, bootPollEnd, bootEndFor = oldP, oldS, oldF, oldE, oldEF
	})
	bootPoll, bootPollSlow, bootFast, bootPollEnd, bootEndFor = poll, slow, time.Hour, end, endFor
}

// near its end tor is asked often, so 100% is read as it happens and not a
// poll later: the relays and the app wait on that status
func TestBootstrapEndReadAsItHappens(t *testing.T) {
	bootPollsForTest(t, 10*time.Second, 10*time.Second, 20*time.Millisecond, time.Minute)
	f := newFakeControl(t, 80)
	n := fakeTor(t, f.port())
	resetRoute(t, "starting", 0)
	done := make(chan struct{})
	go func() { watchBootstrap(n); close(done) }()
	waitFor(t, "the first poll", 2*time.Second, func() bool { return bootPctNow() == 80 })
	f.pct.Store(100)
	said := time.Now()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("100% was not read until the next poll")
	}
	if took := time.Since(said); took > 500*time.Millisecond {
		t.Fatalf("read %s after tor got there", took)
	}
	if st := statusNow(); st != "publishing" {
		t.Fatalf("status %q", st)
	}
}

// early on, and once tor has sat near the end a while, the usual poll
func TestBootstrapFastOnlyNearTheEnd(t *testing.T) {
	bootPollsForTest(t, time.Second, time.Second, 20*time.Millisecond, 300*time.Millisecond)
	f := newFakeControl(t, 40)
	n := fakeTor(t, f.port())
	resetRoute(t, "starting", 0)
	done := make(chan struct{})
	go func() { watchBootstrap(n); close(done) }()
	defer func() { f.pct.Store(100); <-done }()
	waitFor(t, "the first poll", 2*time.Second, func() bool { return bootPctNow() == 40 })
	a := f.polls.Load()
	time.Sleep(500 * time.Millisecond)
	if d := f.polls.Load() - a; d > 1 {
		t.Fatalf("%d polls in half a second at 40%%", d)
	}
	f.pct.Store(90)
	waitFor(t, "90%", 2*time.Second, func() bool { return bootPctNow() == 90 })
	a = f.polls.Load()
	time.Sleep(200 * time.Millisecond)
	if d := f.polls.Load() - a; d < 4 {
		t.Fatalf("%d polls in 200ms near the end", d)
	}
	// held there past bootEndFor: back to the usual pace
	time.Sleep(300 * time.Millisecond)
	a = f.polls.Load()
	time.Sleep(500 * time.Millisecond)
	if d := f.polls.Load() - a; d > 1 {
		t.Fatalf("%d polls in half a second held at 90%%", d)
	}
}
