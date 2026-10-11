// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"errors"
	"net"
	"strings"
	"testing"
	"time"
)

// the transport listeners will not start. tor then never goes out without
// the bridges it was given: a picked bridge waits off the network for a
// retry, an automatic step fails at once and the pass moves on, and only
// direct, picked or automatic's own step, goes on the network

// listeners that will not start, until the returned func lets them
func ptListenersFail(t *testing.T) (let func()) {
	t.Helper()
	ptMu.Lock()
	old := ptRegs
	ptRegs = nil
	ptMu.Unlock()
	oldListen := ptListenLocal
	ptListenLocal = func() (net.Listener, error) { return nil, errors.New("too many open files") }
	t.Cleanup(func() {
		ptListenLocal = oldListen
		ptMu.Lock()
		for _, r := range ptRegs {
			r.ln.Close()
		}
		ptRegs = old
		ptMu.Unlock()
		ptDown.Store(false)
	})
	return func() { ptListenLocal = oldListen }
}

func sentNetworkOn(f *fakeControl) bool {
	for _, c := range f.sent() {
		if strings.Contains(c, "DISABLENETWORK=0") {
			return true
		}
	}
	return false
}

func TestPickedBridgeWithoutListenersStaysOff(t *testing.T) {
	webtunnel := "webtunnel [2001:db8::1]:443 " + testFP + " url=https://example.com/a1b2c3 ver=0.0.1"
	for _, c := range []struct{ mode, opts string }{
		{bmOwn, `{"lines":["` + tbObfs4 + `"]}`},
		{bmMoat, `{"lines":["` + tbObfs4 + `"]}`},
		{bmWebtunnel, `{"lines":["` + webtunnel + `"]}`},
		{bmSnowflake, ``},
	} {
		t.Run(c.mode, func(t *testing.T) {
			resetAuto(t)
			t.Cleanup(func() { resetAuto(t) })
			let := ptListenersFail(t)
			// picked before tor runs, as the boot restore does
			if r := setBridgeMode(c.mode, c.opts); r != "ok" {
				t.Fatalf("mode: %q", r)
			}
			if args := strings.Join(torArgs(), " "); strings.Contains(args, "UseBridges") {
				t.Fatalf("bridge args without listeners: %s", args)
			}
			if why := networkHold(); why != errPTDown {
				t.Fatalf("hold: %q", why)
			}
			f := overlapRig(t)
			f.slow.Store(0)
			if r := reconnectNow(); r != errPTDown {
				t.Fatalf("reconnect: %q", r)
			}
			if r := torResume(); r != errPTDown {
				t.Fatalf("wake: %q", r)
			}
			if sentNetworkOn(f) {
				t.Fatalf("tor went out without its bridges: %v", f.sent())
			}
			if v := bridgeStatus(); v.ErrorCode != codePTDown || v.Phase != "trying" {
				t.Fatalf("status: %+v", v)
			}
			// the one button: the listeners come up and tor goes out
			let()
			bridgeRetry()
			deadline := time.Now().Add(5 * time.Second)
			for !sentNetworkOn(f) && time.Now().Before(deadline) {
				time.Sleep(20 * time.Millisecond)
			}
			endsOnTheNetwork(t, f)
			if ptDown.Load() {
				t.Fatal("still down after the retry")
			}
		})
	}
}

func TestDirectNeedsNoListeners(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	ptListenersFail(t)
	ptDown.Store(true)
	if r := setBridgeMode(bmDirect, ""); r != "ok" {
		t.Fatalf("mode: %q", r)
	}
	f := overlapRig(t)
	f.slow.Store(0)
	if r := reconnectNow(); r != "ok" {
		t.Fatalf("reconnect: %q", r)
	}
	endsOnTheNetwork(t, f)
}

// automatic's bridge step, applied for real, fails without a network on
func TestAutoBridgeStepWithoutListenersFails(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	ptListenersFail(t)
	f := overlapRig(t)
	f.slow.Store(0)
	autoMu.Lock()
	bmMode = bmAuto
	autoMu.Unlock()
	useLines([]string{tbObfs4})
	if r := liveWorld().apply(autoStep{Method: "obfs4", Source: "builtin"}); r == "ok" {
		t.Fatal("a bridge step without listeners was applied")
	}
	if sentNetworkOn(f) {
		t.Fatalf("tor went out without its bridges: %v", f.sent())
	}
}

// tor came up without the step's bridges: the step puts them in place by a
// bounce of its own, and when that fails it fails at once, so the pass,
// which has counted it, moves on
func TestAutoPassSkipsAStepWithoutListeners(t *testing.T) {
	fa := useFakeAuto(t, wifi())
	ptListenersFail(t)
	fa.started = false
	fa.at(time.Second, func() { fa.started = true })
	fa.applyErr["obfs4"] = errPTDown
	p := passCtx{gen: autoGen(), epoch: netEpoch.Load(), valid: autoValidFlips.Load()}
	s := autoStep{Method: "obfs4", Source: "builtin", Lines: builtinLines("obfs4")}
	t0 := fa.now
	if v := runAttempt(p, s, true); v != seenFailed {
		t.Fatalf("got %q", v)
	}
	if took := fa.now.Sub(t0); took > 5*time.Second {
		t.Fatalf("took %v to give up", took)
	}
	if len(fa.applied) != 1 || fa.applied[0] != "obfs4/builtin" {
		t.Fatalf("held tor not bounced: %v", fa.applied)
	}
}
