// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"sort"
	"strconv"
	"sync"
	"testing"
	"time"
)

func batchLaneForTest(i int) string { return laneEveryday + ":t:" + strconv.Itoa(i) }

// the brake on, at its real gap, for one test
func brakeOn(t *testing.T) {
	t.Helper()
	oldGap, oldJit := torBrakeGap.Load(), torBrakeJitter.Load()
	torBrakeGap.Store(int64(250 * time.Millisecond))
	torBrakeJitter.Store(int64(250 * time.Millisecond))
	torBrakeClear()
	t.Cleanup(func() {
		torBrakeGap.Store(oldGap)
		torBrakeJitter.Store(oldJit)
		torBrakeClear()
	})
}

// a few losses are no wave; past torWaveFrom each dial through tor gets a
// slot of its own, a gap apart, the open chat's at once, direct dials never
func TestTorBrakeSpreadsAWave(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	brakeOn(t)
	own := "wss://relay.kryfo.app"
	setRelays([]string{own, "wss://relay2.kryfo.app"})
	clearTestHosts.Clear()
	for i := 0; i < torWaveFrom-1; i++ {
		noteTorLoss(batchLaneForTest(i), own)
	}
	if tk := paceJoin(laneEveryday, own, paceRest); tk != nil {
		t.Fatal("a brake before a wave")
	}
	noteTorLoss(batchLaneForTest(torWaveFrom), own)
	// the same socket lost twice is one loss
	noteTorLoss(batchLaneForTest(torWaveFrom), own)
	if tk := paceJoin(laneEveryday, own, paceFirst); tk != nil {
		t.Fatal("the open chat's batch waits out a wave")
	}
	const n = 10
	var mu sync.Mutex
	var at []time.Time
	var wg sync.WaitGroup
	start := time.Now()
	for i := 0; i < n; i++ {
		tk := paceJoin(batchLaneForTest(100+i), own, paceRest)
		if tk == nil {
			t.Fatal("no slot in a wave")
		}
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := tk.wait(context.Background()); err != nil {
				t.Error(err)
			}
			mu.Lock()
			at = append(at, tk.placeAt())
			mu.Unlock()
		}()
	}
	// one more joins and the open chat lifts it
	late := paceJoin(batchLaneForTest(200), own, paceRest)
	late.raise(paceFirst)
	if err := late.wait(context.Background()); err != nil || time.Since(start) > 100*time.Millisecond {
		t.Fatalf("the open chat raised in a wave waited %s (%v)", time.Since(start), err)
	}
	wg.Wait()
	sort.Slice(at, func(i, j int) bool { return at[i].Before(at[j]) })
	for i := 1; i < len(at); i++ {
		if gap := at[i].Sub(at[i-1]); gap < 230*time.Millisecond {
			t.Fatalf("dials %d and %d only %s apart", i-1, i, gap)
		}
	}
	if span := at[n-1].Sub(at[0]); span < (n-1)*250*time.Millisecond || span > (n-1)*520*time.Millisecond {
		t.Fatalf("%d dials over %s", n, span)
	}
	// direct dials are the pace line's, never the brake's
	transportMode.Store(modeBalanced)
	if tk := torBrakeJoin(laneEveryday, own, paceRest); tk != nil {
		t.Fatal("a direct dial braked")
	}
	transportMode.Store(modePrivate)
	// a wake, a new network, a mode switch end the wave
	relayClearBenches()
	if tk := paceJoin(laneEveryday, own, paceRest); tk != nil {
		t.Fatal("the wave outlived a bench clear")
	}
}

// the losses age out: a wave over is no brake
func TestTorBrakeEndsWithTheLosses(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	brakeOn(t)
	own := "wss://relay.kryfo.app"
	setRelays([]string{own})
	clearTestHosts.Clear()
	old := torWaveFor
	torWaveFor = 300 * time.Millisecond
	t.Cleanup(func() { torWaveFor = old })
	for i := 0; i < torWaveFrom; i++ {
		noteTorLoss(batchLaneForTest(i), own)
	}
	if tk := paceJoin(laneEveryday, own, paceRest); tk == nil {
		t.Fatal("no brake in a wave")
	} else {
		tk.wait(context.Background())
	}
	time.Sleep(350 * time.Millisecond)
	if tk := paceJoin(laneEveryday, own, paceRest); tk != nil {
		t.Fatal("the brake held after the losses aged out")
	}
}

// private, twelve sockets through tor cut at once, as a guard jam does:
// they all come back, spread out, never all in one second
func TestTorCutRedialsSpreadOut(t *testing.T) {
	socks := newSocksStandIn(t)
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, relay)
	brakeOn(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	const n = 12
	var rcvs []string
	for i := 0; i < n; i++ {
		peer := newXid(t)
		rcv := mustRcv(t, peer)
		rcvs = append(rcvs, rcv)
		go nostrSubscribeRunner(alone(ctx), hex.EncodeToString(peer.pub[:]), mainPair(peer.pub), rcv)
	}
	waitFor(t, "every socket up", 30*time.Second, func() bool {
		catchupMu.Lock()
		defer catchupMu.Unlock()
		for _, r := range rcvs {
			if _, done := catchupLast[catchupKey(relay.url(), r)]; !done {
				return false
			}
		}
		return true
	})
	cut := time.Now()
	socks.cut()
	var back []time.Time
	waitFor(t, "every socket back", 40*time.Second, func() bool {
		back = back[:0]
		for _, c := range relay.snapshot() {
			if c.opened.After(cut) && len(c.reqs) > 0 {
				back = append(back, c.opened)
			}
		}
		return len(back) >= n
	})
	sort.Slice(back, func(i, j int) bool { return back[i].Before(back[j]) })
	if span := back[n-1].Sub(back[0]); span < (n-1)*200*time.Millisecond {
		t.Fatalf("%d redials within %s: a wave", n, span)
	}
	for i := 4; i < len(back); i++ {
		if back[i].Sub(back[i-4]) < 800*time.Millisecond {
			t.Fatalf("five redials within 800 ms: %v", back[i-4:i+1])
		}
	}
}
