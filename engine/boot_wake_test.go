// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"testing"
	"time"
)

// tor's own word that it reached 100% is read at once, not a poll later:
// the relays and the app wait on that status
func TestBootstrapReadAsTorSaysIt(t *testing.T) {
	oldP, oldS, oldF := bootPoll, bootPollSlow, bootFast
	defer func() { bootPoll, bootPollSlow, bootFast = oldP, oldS, oldF }()
	bootPoll, bootPollSlow, bootFast = 10*time.Second, 10*time.Second, time.Hour
	eventReset()
	defer eventReset()
	f := newFakeControl(t, 50)
	n := fakeTor(t, f.port())
	resetRoute(t, "starting", 0)
	done := make(chan struct{})
	go func() { watchBootstrap(n); close(done) }()
	waitFor(t, "the first poll", 2*time.Second, func() bool { return bootPctNow() == 50 })
	waitFor(t, "the event listener", 2*time.Second, func() bool {
		f.mu.Lock()
		defer f.mu.Unlock()
		return len(f.evc) > 0
	})
	f.pct.Store(100)
	said := time.Now()
	f.emit(`STATUS_CLIENT NOTICE BOOTSTRAP PROGRESS=100 TAG=done SUMMARY="Done"`)
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		f.pct.Store(100)
		t.Fatal("100% was not read until the next poll")
	}
	if took := time.Since(said); took > time.Second {
		t.Fatalf("read %s after tor said it", took)
	}
	if st := statusNow(); st != "publishing" {
		t.Fatalf("status %q", st)
	}
	// off the list once done: no listener left on the event connection
	waitFor(t, "the listener to go", 2*time.Second, func() bool {
		f.mu.Lock()
		defer f.mu.Unlock()
		return len(f.evc) == 0
	})
}

// a warning is no step: it does not make the watcher ask
func TestBootstrapWarningsDoNotPoll(t *testing.T) {
	oldP, oldS, oldF := bootPoll, bootPollSlow, bootFast
	defer func() { bootPoll, bootPollSlow, bootFast = oldP, oldS, oldF }()
	bootPoll, bootPollSlow, bootFast = 10*time.Second, 10*time.Second, time.Hour
	eventReset()
	defer eventReset()
	f := newFakeControl(t, 50)
	n := fakeTor(t, f.port())
	resetRoute(t, "starting", 0)
	done := make(chan struct{})
	go func() { watchBootstrap(n); close(done) }()
	defer func() {
		f.pct.Store(100)
		f.emit(`STATUS_CLIENT NOTICE BOOTSTRAP PROGRESS=100 TAG=done SUMMARY="Done"`)
		<-done
	}()
	waitFor(t, "the event listener", 2*time.Second, func() bool {
		f.mu.Lock()
		defer f.mu.Unlock()
		return len(f.evc) > 0
	})
	a := f.polls.Load()
	for i := 0; i < 50; i++ {
		f.emit(`STATUS_CLIENT WARN BOOTSTRAP PROGRESS=50 TAG=conn SUMMARY="x" WARNING="x" REASON=CONNECTREFUSED COUNT=1 RECOMMENDATION=warn`)
	}
	time.Sleep(500 * time.Millisecond)
	if d := f.polls.Load() - a; d > 0 {
		t.Fatalf("%d polls for warnings", d)
	}
}
