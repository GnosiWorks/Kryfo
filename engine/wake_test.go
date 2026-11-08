// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"sort"
	"sync/atomic"
	"testing"
	"time"
)

// the boot clock runs ahead by what a sleep adds, the monotonic one does
// not. returns the sleep
func fakeSleep(t *testing.T) func(time.Duration) {
	t.Helper()
	var ahead atomic.Int64
	t.Cleanup(wakeReset)
	setOwnClock(t, func() time.Duration { return bootClock() + time.Duration(ahead.Load()) })
	wakeReset()
	wakeCheck()
	return func(d time.Duration) { ahead.Add(int64(d)) }
}

// a clock of the test's own in place of the boot clock, the real one back after
func setOwnClock(t *testing.T, f func() time.Duration) {
	t.Helper()
	old := ownClockFn.Swap(&f)
	t.Cleanup(func() { ownClockFn.Store(old) })
}

// the runners' context, ended and waited out before the stand-ins' cleanup
// puts the data dir back under them
func lanesCtx(t *testing.T) context.Context {
	t.Helper()
	before := ownSockets.Load() + pubSockets.Load()
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(func() {
		cancel()
		end := time.Now().Add(10 * time.Second)
		for ownSockets.Load()+pubSockets.Load() > before && time.Now().Before(end) {
			time.Sleep(20 * time.Millisecond)
		}
		// the last file writes after a socket's goroutine has counted out
		time.Sleep(100 * time.Millisecond)
	})
	return ctx
}

// the room each socket gets at a wake, and the grace after it
func setWakeGap(t *testing.T, gap, grace time.Duration) {
	t.Helper()
	oldGap, oldGrace := wakeGap, wakeGraceExtra
	wakeGap, wakeGraceExtra = gap, grace
	t.Cleanup(func() { wakeGap, wakeGraceExtra = oldGap, oldGrace })
}

// when each address dialled the relay again after from, sorted
func redials(r *relayStandIn, from time.Time, addrs []string) []time.Duration {
	first := map[string]time.Duration{}
	for _, c := range r.snapshot() {
		if c.opened.Before(from) || len(c.reqs) == 0 {
			continue
		}
		for _, a := range addrs {
			if !c.addrs[a] {
				continue
			}
			if d, ok := first[a]; !ok || c.opened.Sub(from) < d {
				first[a] = c.opened.Sub(from)
			}
		}
	}
	var out []time.Duration
	for _, d := range first {
		out = append(out, d)
	}
	sort.Slice(out, func(i, j int) bool { return out[i] < out[j] })
	return out
}

// the most dials under way at once, each taking took from its start
func mostAtOnce(starts []time.Duration, took time.Duration) int {
	most := 0
	for i, s := range starts {
		n := 0
		for _, o := range starts[i:] {
			if o-s < took {
				n++
			}
		}
		most = max(most, n)
	}
	return most
}

func TestAWakeIsTheBootClockRunningAhead(t *testing.T) {
	sleep := fakeSleep(t)
	if wakeCheck() {
		t.Fatal("a wake with no sleep")
	}
	sleep(30 * time.Second)
	if wakeCheck() {
		t.Fatal("half a minute asleep was taken for a wake")
	}
	// sockets live through a suspend of a couple of minutes
	sleep(2 * time.Minute)
	if wakeCheck() {
		t.Fatal("two minutes asleep was taken for a wake")
	}
	if _, _, ok := wakeNow(); ok {
		t.Fatal("turns with no wake")
	}
	sleep(2 * time.Hour)
	if !wakeCheck() {
		t.Fatal("two hours asleep went unseen")
	}
	if wakeCheck() {
		t.Fatal("one sleep was seen twice")
	}
	if _, _, ok := wakeNow(); !ok {
		t.Fatal("no turns after the wake")
	}
	// a clock put back is no sleep, nor is the look after it
	sleep(-3 * time.Hour)
	if wakeCheck() || wakeCheck() {
		t.Fatal("a clock put back was taken for a wake")
	}
}

// every socket dies in a long sleep. on the wake they redialled together,
// the public relays' all in the same instant. now ours go first, the first
// at once, and the rest take turns over a window that grows with the
// sockets
func TestAWakeSpreadsTheRedials(t *testing.T) {
	setLiveCap(t, 1000, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	setWakeGap(t, 100*time.Millisecond, wakeGraceExtra)
	sleep := fakeSleep(t)
	ctx := lanesCtx(t)
	l := startLanes(t, alone(ctx), 20, 0)
	addrs := append(append([]string(nil), l.contacts...), l.fc)
	waitFor(t, "every address on both relays", 15*time.Second, func() bool {
		for _, a := range addrs {
			if openOn(own, a) != 1 || openOn(pub, a) != 1 {
				return false
			}
		}
		return true
	})
	// a dial takes a moment, as over tor
	const took = 300 * time.Millisecond
	for _, r := range []*relayStandIn{own, pub} {
		r.mu.Lock()
		r.upgradeDelay = took
		r.mu.Unlock()
	}
	sleep(2 * time.Hour)
	at := time.Now()
	own.dropAll()
	pub.dropAll()
	var ours, theirs []time.Duration
	waitFor(t, "every address back on both relays", 30*time.Second, func() bool {
		ours, theirs = redials(own, at, addrs), redials(pub, at, addrs)
		return len(ours) == len(addrs) && len(theirs) == len(addrs)
	})
	t.Logf("ours from %s to %s, the public relay from %s to %s, at most %d and %d dials at once",
		ours[0].Round(time.Millisecond), ours[len(ours)-1].Round(time.Millisecond),
		theirs[0].Round(time.Millisecond), theirs[len(theirs)-1].Round(time.Millisecond),
		mostAtOnce(ours, took), mostAtOnce(theirs, took))
	// the first of ours goes as soon as its usual pause is over
	if ours[0] > 2400*time.Millisecond+500*time.Millisecond {
		t.Fatalf("our relay's first redial came %s after the wake", ours[0])
	}
	// the public window begins somewhere in the last fifth of ours
	early := 0
	for _, d := range theirs {
		if d < ours[len(ours)-1] {
			early++
		}
	}
	if early > len(theirs)/4 || theirs[0] < ours[len(ours)/2] {
		t.Fatalf("%d public redials before ours were all back, the first at %s", early, theirs[0])
	}
	all := append(append([]time.Duration(nil), ours...), theirs...)
	sort.Slice(all, func(i, j int) bool { return all[i] < all[j] })
	// all the public relay's went in one instant before
	if n := mostAtOnce(all, took); n > 12 {
		t.Fatalf("%d of %d redials under way at once", n, len(all))
	}
}

// a small inbox is back as soon as before: its windows are a fraction of
// a second
func TestASmallInboxIsBackAtOnceAfterAWake(t *testing.T) {
	setLiveCap(t, 1000, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	sleep := fakeSleep(t)
	ctx := lanesCtx(t)
	l := startLanes(t, ctx, 2, 0)
	addrs := append(append([]string(nil), l.contacts...), l.fc)
	waitFor(t, "every address on both relays", 15*time.Second, func() bool {
		for _, a := range addrs {
			if openOn(own, a) != 1 || openOn(pub, a) != 1 {
				return false
			}
		}
		return true
	})
	sleep(2 * time.Hour)
	at := time.Now()
	own.dropAll()
	pub.dropAll()
	var ours, theirs []time.Duration
	waitFor(t, "every address back on both relays", 15*time.Second, func() bool {
		ours, theirs = redials(own, at, addrs), redials(pub, at, addrs)
		return len(ours) == len(addrs) && len(theirs) == len(addrs)
	})
	// the usual pauses after a drop are 2 s for ours, a fifth either way, and 5 s
	if last := ours[len(ours)-1]; last > 2400*time.Millisecond+time.Second {
		t.Fatalf("our relay was back for every address only %s after the wake", last)
	}
	if last := theirs[len(theirs)-1]; last > 5*time.Second+time.Second {
		t.Fatalf("the public relay was back for every address only %s after the wake", last)
	}
}

// what fails across a sleep, and in the first stretch of the wake, benches
// no relay, starts no dead spell and fires no rescue. a spell from before
// the sleep starts again from the wake, as do the three minutes the relay
// watch gives. once the stretch is over, failures count again
func TestASleepBenchesNoRelayAndRescuesNoRoute(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	relays := []string{ownOnion, "wss://pub1.example", "wss://pub2.example"}
	setRelays(relays)
	resetRoute(t, "publishing", 100)
	setFailBurst(t, 0)
	setWakeGap(t, 0, 300*time.Millisecond)
	routeNoteOK()
	for _, u := range relays {
		routeAnswered(u, -1)
	}
	sleep := fakeSleep(t)
	// failing for 50 s as the phone goes to sleep, with a dial under way
	began := time.Now()
	for i := 0; i < 3; i++ {
		for _, u := range relays {
			relayFailed(u, time.Now())
		}
	}
	routeMu.Lock()
	firstFailAt = time.Now().Add(-50 * time.Second)
	routeMu.Unlock()
	txMu.Lock()
	oldOK := lastRelayOK
	lastRelayOK = time.Now().Add(-4 * time.Minute)
	txMu.Unlock()
	t.Cleanup(func() {
		txMu.Lock()
		lastRelayOK = oldOK
		txMu.Unlock()
	})
	sleep(2 * time.Hour)
	// the wake: the dial begun before the sleep fails, so do the first redials
	for i := 0; i < 10; i++ {
		for _, u := range relays {
			relayFailed(u, began)
			relayFailed(u, time.Now())
		}
	}
	for _, u := range relays {
		if n := failsOf(u); n != 0 {
			t.Fatalf("%s: %d failures counted across a sleep", u, n)
		}
		if d := benchLeft(u); d > 0 {
			t.Fatalf("%s benched for %s after a sleep", u, d)
		}
	}
	if why := routeNeedsRescue(time.Now().Add(15 * time.Second)); why != "" {
		t.Fatalf("a rescue 15 s after the wake: %s", why)
	}
	if !routeOK() {
		t.Fatal("the route is called down 15 s after a wake")
	}
	if relaysAllDead() {
		t.Fatal("the relay watch counted from before the sleep")
	}
	// the stretch is over: a failure is a failure again
	time.Sleep(400 * time.Millisecond)
	for _, u := range relays {
		relayFailed(u, time.Now())
		if n := failsOf(u); n != 1 {
			t.Fatalf("%s: %d failures after the wake's stretch, want 1", u, n)
		}
	}
	routeMu.Lock()
	failing := len(failedSinceOK)
	routeMu.Unlock()
	if failing == 0 {
		t.Fatal("no dead spell after the wake's stretch")
	}
}

// a span of our relay failing does not carry over a sleep: a public relay
// answering first at the wake found it already two minutes long, and the
// first failure there made ours down. a real outage is still found
func TestOurRelayDownStartsAgainFromAWake(t *testing.T) {
	liveReset()
	t.Cleanup(liveReset)
	setDownRound(t, time.Minute, 10*time.Minute, 2*time.Minute)
	sleep := fakeSleep(t)
	ownRelayAnswered()
	sleep(11 * time.Minute)
	wakeCheck()
	// a failure while a public relay answered, then a sleep
	pubRelayAnswered()
	ownRelayFailed()
	if ownRelayDown() {
		t.Fatal("down on its first failure")
	}
	sleep(15 * time.Minute)
	// the wake: the exits are back before the onion circuit
	pubRelayAnswered()
	ownRelayFailed()
	if ownRelayDown() {
		t.Fatal("down at the wake's first failure, on a span from before the sleep")
	}
	// it keeps failing while the public relays answer
	for gone := time.Duration(0); gone <= 2*time.Minute+10*time.Second; gone += 5 * time.Second {
		sleep(5 * time.Second)
		pubRelayAnswered()
		ownRelayFailed()
	}
	if !ownRelayDown() {
		t.Fatal("an outage after the wake was not found")
	}
}

// the reads past the cap that came due in a sleep go at the wake, as on
// the boot clock, but over the public relays' window and not all at once
func TestReadsDueInASleepAreSpreadOverTheWake(t *testing.T) {
	setLiveCap(t, 1, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	shortTurns(t)
	setWakeGap(t, 200*time.Millisecond, wakeGraceExtra)
	sleep := fakeSleep(t)
	freshInbox(t)
	ctx := lanesCtx(t)
	l := startLanes(t, alone(ctx), 20, 0)
	waitFor(t, "every address on our relay", 15*time.Second, func() bool {
		for _, a := range l.contacts {
			if openOn(own, a) != 1 {
				return false
			}
		}
		return true
	})
	time.Sleep(time.Second)
	var capped []string
	for _, a := range l.contacts {
		if everOn(pub, a) == 0 {
			capped = append(capped, a)
		}
	}
	if len(capped) < 15 {
		t.Fatalf("%d addresses past the cap, want 19", len(capped))
	}
	const took = 300 * time.Millisecond
	pub.mu.Lock()
	pub.upgradeDelay = took
	pub.mu.Unlock()
	// two rounds asleep, then the job's knock
	sleep(2000 * time.Hour)
	at := time.Now()
	nostrKick()
	var reads []time.Duration
	waitFor(t, "every read that came due", 30*time.Second, func() bool {
		reads = redials(pub, at, capped)
		return len(reads) == len(capped)
	})
	w := wakeWindows()
	t.Logf("%d reads from %s to %s, at most %d at once, ours over %s",
		len(reads), reads[0].Round(time.Millisecond), reads[len(reads)-1].Round(time.Millisecond),
		mostAtOnce(reads, took), w.own)
	if n := mostAtOnce(reads, took); n > 12 {
		t.Fatalf("%d of %d reads under way at once", n, len(reads))
	}
	if reads[0] < w.own/2 {
		t.Fatalf("a public read %s after the wake, inside our relay's window of %s", reads[0], w.own)
	}
}

// a check-in under way, its job begun now: its turns end in 15 s
func underCheckIn(t *testing.T) {
	t.Helper()
	checkInMu.Lock()
	old := checkInUntil
	checkInUntil = time.Now().Add(checkInMax)
	checkInMu.Unlock()
	noteCheckIn(1)
	t.Cleanup(func() {
		checkInMu.Lock()
		checkInUntil = old
		checkInMu.Unlock()
		noteCheckIn(0)
	})
}

// sockets counted as a big inbox's runners would be, for the windows
func countSockets(t *testing.T, own, pub int32) {
	t.Helper()
	ownSockets.Add(own)
	pubSockets.Add(pub)
	t.Cleanup(func() {
		ownSockets.Add(-own)
		pubSockets.Add(-pub)
	})
}

// in a check-in the wake's windows shrink to its 10 s, in order. scaled
// by a product of two nanosecond counts they overflowed and every turn
// fell under a second, half of them at once
func TestACheckInWakeKeepsItsTurnsInOrder(t *testing.T) {
	underCheckIn(t)
	for _, c := range []struct{ own, pub int }{{100, 150}, {542, 1084}} {
		w := wakeTurns{time.Duration(c.own) * wakeGap, time.Duration(c.pub) * wakeGap}
		limit := checkInSpread
		ownEnd := time.Duration(float64(limit) * float64(w.own) / float64(w.own+w.pub))
		var oursHi, theirsLo, theirsHi time.Duration
		theirsLo = time.Hour
		zero := 0
		for i := 0; i < 5000; i++ {
			o, p := w.turn(true, autoNow()), w.turn(false, autoNow())
			if o < 0 || o > ownEnd {
				t.Fatalf("%d+%d: a turn of ours at %s, want within %s", c.own, c.pub, o, ownEnd)
			}
			if p <= 0 {
				zero++
			}
			oursHi, theirsLo, theirsHi = max(oursHi, o), min(theirsLo, p), max(theirsHi, p)
		}
		if zero > 0 || theirsLo < ownEnd*4/5 || theirsHi > limit {
			t.Fatalf("%d+%d: public turns from %s to %s, %d at once, want %s to %s",
				c.own, c.pub, theirsLo, theirsHi, zero, ownEnd*4/5, limit)
		}
		if oursHi < ownEnd/2 || theirsHi < limit*9/10 {
			t.Fatalf("%d+%d: turns end at %s and %s, not spread over %s", c.own, c.pub, oursHi, theirsHi, limit)
		}
	}
	// a live socket answering the job's kick in a wake takes the same turns
	countSockets(t, 542, 1084)
	sleep := fakeSleep(t)
	sleep(2 * time.Hour)
	if !wakeCheck() {
		t.Fatal("no wake")
	}
	var lo, hi time.Duration = time.Hour, 0
	for i := 0; i < 2000; i++ {
		d := kickDelayFor(false)
		lo, hi = min(lo, d), max(hi, d)
	}
	if lo < time.Second || hi > checkInSpread {
		t.Fatalf("a public kick in a check-in's wake from %s to %s", lo, hi)
	}
}

// in a check-in nothing is excused past its turns: the app stops waiting
// at 120 s, and a grace of the full windows covered all of it
func TestACheckInsGraceEndsWithItsTurns(t *testing.T) {
	underCheckIn(t)
	countSockets(t, 542, 1084)
	sleep := fakeSleep(t)
	sleep(2 * time.Hour)
	if !wakeCheck() {
		t.Fatal("no wake")
	}
	wakeMu.Lock()
	grace := wakeGraceTill.Sub(wakeAt)
	wakeMu.Unlock()
	if most := checkInTurnsBy + wakeGraceExtra + time.Second; grace > most {
		t.Fatalf("failures excused for %s after a check-in's wake, want %s at most", grace, most)
	}
}

// a refusal is the relay's own answer through a route that works: it
// counts in a wake's first stretch too
func TestARefusalCountsInAWake(t *testing.T) {
	pub := newRefuserStandIn(t)
	useStandIns(t, modeBalanced, nil)
	setRelays([]string{"ws://own.invalid", pub.url()})
	setFailBurst(t, 0)
	setWakeGap(t, 0, time.Hour)
	sleep := fakeSleep(t)
	sleep(2 * time.Hour)
	if !wakeCheck() {
		t.Fatal("no wake")
	}
	for i := 0; i < 10; i++ {
		relayRefused(pub.url(), time.Now(), nil)
	}
	if n := failsOf(pub.url()); n != 10 {
		t.Fatalf("%d of 10 refusals counted in the wake's stretch", n)
	}
}

// a phone with the screen off runs in short bursts and sleeps between
// them, so nearly every look of the route watch sees a sleep. a dead tor
// must still be rescued: one grace per route that carried, not one per
// look
func TestALightSleepStillRescuesADeadRoute(t *testing.T) {
	for _, gap := range []time.Duration{70 * time.Second, 4 * time.Minute} {
		t.Run(gap.String(), func(t *testing.T) {
			useStandIns(t, modePrivate, nil)
			relays := []string{ownOnion, "wss://pub1.example", "wss://pub2.example"}
			setRelays(relays)
			resetRoute(t, "publishing", 100)
			setFailBurst(t, 0)
			setWakeGap(t, 0, 0)
			routeNoteOK()
			for _, u := range relays {
				routeAnswered(u, -1)
			}
			sleep := fakeSleep(t)
			t0 := time.Now()
			// a route tick every 10 s of awake time, gap asleep before each
			for i := 1; i <= 60; i++ {
				sleep(gap)
				began := time.Now()
				for _, u := range relays {
					relayFailed(u, began)
				}
				if why := routeNeedsRescue(t0.Add(time.Duration(i) * 10 * time.Second)); why != "" {
					t.Logf("rescued after %d ticks: %s", i, why)
					if failsOf(ownOnion) == 0 {
						t.Fatal("no failure counted")
					}
					return
				}
			}
			t.Fatal("a dead route was never rescued with the phone sleeping between looks")
		})
	}
}

// a wake seen a moment before the check-in begins excuses no longer than
// the check-in's turns: the full windows outlasted the app's 120 s
func TestACheckInAfterTheWakeShortensTheGrace(t *testing.T) {
	countSockets(t, 542, 1084)
	sleep := fakeSleep(t)
	sleep(2 * time.Hour)
	if !wakeCheck() {
		t.Fatal("no wake")
	}
	underCheckIn(t)
	late := time.Now().Add(checkInTurnsBy + wakeGraceExtra + time.Second)
	wakeMu.Lock()
	wakeAt = wakeAt.Add(-time.Millisecond)
	wakeMu.Unlock()
	// as if that much of the check-in had gone: a failure then is counted
	oldNow := autoNow
	autoNow = func() time.Time { return oldNow().Add(late.Sub(time.Now())) }
	defer func() { autoNow = oldNow }()
	if wakeExcuses(time.Now()) {
		t.Fatal("a failure past the check-in's turns was excused by a wake seen before it")
	}
}

// our relay down while the phone sleeps in bursts of over three minutes,
// the public relays answering: each wake cut our relay's failing span, so
// the outage round never began. one cut per answer of ours
func TestOurRelayDownIsFoundThroughLightSleeps(t *testing.T) {
	liveReset()
	t.Cleanup(liveReset)
	setDownRound(t, time.Minute, 10*time.Minute, 2*time.Minute)
	sleep := fakeSleep(t)
	ownRelayAnswered()
	sleep(11 * time.Minute)
	wakeCheck()
	for i := 0; i < 10; i++ {
		pubRelayAnswered()
		ownRelayFailed()
		if ownRelayDown() {
			t.Logf("down after %d failures", i+1)
			return
		}
		sleep(200 * time.Second)
	}
	t.Fatal("our relay failing through light sleeps was never down")
}
