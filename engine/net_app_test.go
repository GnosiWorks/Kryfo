// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// the app's two network handlers, connectivity and android's watch, as
// the app runs them: what the engine hears and in which order
type appModel struct {
	online, connSeen bool
	watchOn          *bool
	lastKinds        string
}

func newAppModel(kinds string) *appModel {
	return &appModel{online: true, connSeen: true, lastKinds: kinds}
}

func (a *appModel) conn(kinds string) {
	seen := kinds != "none"
	connectivitySaw(seen)
	flip := 0
	if !(seen == a.connSeen && kinds == a.lastKinds) {
		if seen {
			flip = 1
		} else {
			flip = -1
		}
	}
	a.connSeen, a.lastKinds = seen, kinds
	if flip == 1 {
		networkChangedTo(true) // networkMoved
	}
	if flip == -1 {
		networkChangedTo(false)
	}
	on := seen
	if a.watchOn != nil {
		on = *a.watchOn
	}
	a.online = on
}

func (a *appModel) watch(kind string) {
	on := kind != "none"
	js := `{"on":false,"kind":"other"}`
	if on {
		js = `{"on":true,"validated":true,"kind":"` + kind + `"}`
	}
	networkDetail(js)
	a.watchOn = &on
	if on == a.online {
		return
	}
	if on {
		networkChangedTo(true) // networkMoved
	}
	a.online = on
}

func lastNetCmd(cmds []string) string {
	last := ""
	for _, c := range cmds {
		if strings.Contains(c, "DISABLENETWORK") {
			last = c
		}
	}
	return last
}

// connectivity said none and then fell silent, the watch says on and then
// none again: both say none, yet the engine has connectivity seeing a network
func TestAWatchAloneOnLeavesNoDispute(t *testing.T) {
	f := offlineRig(t)
	keepNetDetail(t)
	a := newAppModel("wifi")
	a.watch("wifi")
	a.conn("none")
	a.watch("none")
	if !waitUntil(3*time.Second, func() bool { return torParked.Load() }) {
		t.Fatal("not parked")
	}
	// the watch sees a network connectivity does not report, then loses it
	a.watch("wifi")
	waitUntil(2*time.Second, func() bool { return !torParked.Load() })
	a.watch("none")
	if !waitUntil(3*time.Second, func() bool { return torParked.Load() }) {
		t.Fatalf("not parked again: %v", f.sent())
	}
	t.Logf("connSaid=%d (1 on, 2 off) disputed=%v", connSaid.Load(), netDisputed())
	if netDisputed() {
		t.Error("both calls say none, the engine calls it a dispute")
	}
	if netValveDue(time.Now().Add(11 * time.Minute)) {
		t.Error("both calls say none, the valve is due after 10 min")
	}
	if r := reconnectNow(); r == "ok" && netValveOpen.Load() {
		t.Error("fix connection opened the valve with both calls saying none")
	}
	waitUntil(5*time.Second, func() bool { return !netValveOpen.Load() })
}

// a valve proof, then the person really goes offline: the watch repeats the
// none the proof disproved, connectivity says none
func TestBothNoneAfterAProofGetsNoValve(t *testing.T) {
	offlineRig(t)
	keepNetDetail(t)
	networkDetail(`{"on":false,"kind":"other"}`)
	connectivitySaw(true)
	// as valveTryTor does on a proof
	netDisprove()
	setOffline(false)
	// airplane: the same none from the watch, none from connectivity
	networkDetail(`{"on":false,"kind":"other"}`)
	connectivitySaw(false)
	networkChangedTo(false)
	if !waitUntil(3*time.Second, func() bool { return torParked.Load() }) {
		t.Fatal("not parked")
	}
	if netValveDue(time.Now().Add(11 * time.Minute)) {
		t.Error("both calls say none after a proof, the valve is due after 10 min")
	}
}

// automatic proved direct on wifi; wifi goes, connectivity sees mobile
// before the watch does, and the park is still under way when the watch
// says cellular
func TestAHandoverDropsTheDirectStep(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	f := overlapRig(t)
	keepNetDetail(t)
	quietBounce(t)
	torParked.Store(false)
	t.Cleanup(func() { torParked.Store(false); setOffline(false) })
	autoMu.Lock()
	bmMode, bmOpts = bmAuto, modeOpts{Consent: "no"}
	autoMu.Unlock()
	setNetInfo(wifi())
	time.Sleep(300 * time.Millisecond)
	autoDirectOK.Store(true)
	before := len(f.sent())
	setNetInfo(netInfo{On: false, Kind: "other"})
	time.Sleep(30 * time.Millisecond)
	connectivitySaw(true)
	networkChangedTo(true)
	setNetInfo(netInfo{On: true, Validated: true, Kind: "cellular"})
	waitUntil(5*time.Second, func() bool { return atomic.LoadInt32(&torRestarting) == 0 })
	time.Sleep(500 * time.Millisecond)
	sent := f.sent()[before:]
	t.Logf("autoDirectOK=%v hold=%q last=%q sent=%v", autoDirectOK.Load(), networkHold(), lastNetCmd(sent), sent)
	if autoDirectOK.Load() && strings.Contains(lastNetCmd(sent), "=0") {
		t.Error("tor back on cellular by the direct step proved on wifi")
	}
}

// wifi drop, mobile up, wifi back, in several orders: tor must end on the
// network and the engine online
func TestFlapOrdersEndOnTheNetwork(t *testing.T) {
	seqs := map[string][]string{
		"conn first":         {"c:none", "w:none", "c:mobile", "w:cellular", "c:wifi", "w:wifi"},
		"watch first":        {"w:none", "c:none", "w:cellular", "c:mobile", "w:wifi", "c:wifi"},
		"no none":            {"c:mobile", "w:cellular", "c:mobile,wifi", "w:wifi"},
		"watch none conn on": {"w:none", "c:mobile", "w:cellular", "w:wifi", "c:wifi"},
		"conn ahead":         {"c:none", "c:mobile", "w:none", "w:cellular", "c:wifi", "w:wifi"},
		"watch ahead":        {"w:none", "w:cellular", "w:wifi", "c:none", "c:mobile", "c:wifi"},
		"watch last none":    {"c:none", "w:none", "c:mobile", "w:cellular", "w:none", "w:wifi", "c:wifi"},
	}
	for name, seq := range seqs {
		for _, gap := range []time.Duration{0, 40 * time.Millisecond, 400 * time.Millisecond} {
			t.Run(name+"/"+gap.String(), func(t *testing.T) {
				f := offlineRig(t)
				keepNetDetail(t)
				a := newAppModel("wifi")
				a.watch("wifi")
				connectivitySaw(true)
				for _, ev := range seq {
					if strings.HasPrefix(ev, "c:") {
						a.conn(ev[2:])
					} else {
						a.watch(ev[2:])
					}
					time.Sleep(gap)
				}
				ok := waitUntil(4*time.Second, func() bool {
					return !netOffline.Load() && !torParked.Load() && atomic.LoadInt32(&torRestarting) == 0 &&
						strings.Contains(lastNetCmd(f.sent()), "=0")
				})
				if !ok {
					t.Errorf("ended offline=%v parked=%v last=%q", netOffline.Load(), torParked.Load(), lastNetCmd(f.sent()))
				}
			})
		}
	}
}

// fix connection opened a valve try: a scheduled one waits its back-off
// after it, not the time since the network went
func TestAValveByHandCountsAsATry(t *testing.T) {
	offlineRig(t)
	keepNetDetail(t)
	oa, of := netValveAfter, netValveFor
	netValveAfter, netValveFor = time.Minute, 300*time.Millisecond
	t.Cleanup(func() { netValveAfter, netValveFor = oa, of })
	networkDetail(`{"on":false,"kind":"other"}`)
	connectivitySaw(true)
	if !waitUntil(3*time.Second, func() bool { return torParked.Load() }) {
		t.Fatal("not parked")
	}
	now := time.Now()
	if r := reconnectNow(); r != "ok" {
		t.Fatalf("reconnect by hand: %q", r)
	}
	if !waitUntil(5*time.Second, func() bool { return !netValveOpen.Load() && torParked.Load() }) {
		t.Fatal("the try did not end parked")
	}
	if netValveDue(now.Add(70 * time.Second)) {
		t.Fatal("a scheduled try right after the one by hand")
	}
	if !netValveDue(now.Add(3 * time.Minute)) {
		t.Fatal("no scheduled try after the back-off")
	}
}

// tor put to sleep after a reconnect looked and before its DisableNetwork 0:
// it stays asleep
func TestASleepBeforeTheNetworkOnHolds(t *testing.T) {
	resetAuto(t)
	t.Cleanup(func() { resetAuto(t) })
	f := overlapRig(t)
	f.slow.Store(0)
	release := make(chan struct{})
	locked := make(chan struct{})
	var once sync.Once
	reconnectStepHook = func(_ int64, name string) {
		if name != "network on" {
			return
		}
		once.Do(func() {
			go func() {
				ctrlMu.Lock()
				close(locked)
				<-release
				ctrlMu.Unlock()
			}()
			<-locked
		})
	}
	t.Cleanup(func() { reconnectStepHook = nil })
	before := len(f.sent())
	done := make(chan string, 1)
	go func() { done <- reconnectNow() }()
	<-locked
	time.Sleep(100 * time.Millisecond)
	atomicPaused(t)
	close(release)
	if r := <-done; r != "error: tor is asleep" {
		t.Fatalf("reconnect: %q", r)
	}
	if netOnIn(sentAfter(f, before)) {
		t.Fatalf("tor woke for a reconnect after it was put to sleep: %v", f.sent())
	}
}
