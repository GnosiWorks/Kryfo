// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"fmt"
	"slices"
	"testing"
	"time"
)

// the open chat's address goes first (no turn, a ranked redial) only after
// an event no server can cause: the app to the front, a network change

const openTag = "peer-on-screen"

func openChatOn(t *testing.T) {
	t.Helper()
	old := subSpread
	subSpread = time.Hour
	firstTag.Store(openTag)
	appFront.Store(false)
	t.Cleanup(func() {
		runnersGone(t)
		subSpread = old
		firstTag.Store("")
		appFront.Store(false)
	})
}

// true when tn's take went within d, not at a turn an hour long
func takeWithin(tn *subTurn, d time.Duration) bool {
	ctx, cancel := context.WithTimeout(context.Background(), d)
	defer cancel()
	ok := tn.take(ctx)
	tn.done()
	return ok
}

// the open chat's runner, its socket up after a kick the phone made
func openRunner(t *testing.T) *subTurn {
	t.Helper()
	tn := &subTurn{tag: openTag, lane: paceLane}
	kickRelaysMade()
	if !takeWithin(tn, 200*time.Millisecond) {
		t.Fatal("the open chat waited a turn under the phone's own kick")
	}
	tn.dialed(true)
	return tn
}

func rankOf(tn *subTurn) int { return paceRankFor(tn.tag, tn.lane, tn.made) }

// takes tn's turn: whether it ranked for what the test did. a phone event
// after its socket went down, from outside the test (a network worker an
// earlier test left), would be a reason of its own: then false
func rankedOnItsOwn(tn *subTurn) bool {
	takeWithin(tn, 200*time.Millisecond)
	if !phoneMadeAfter(tn.downAt).IsZero() || kickMadeSince(kickChan(), tn.downAt) {
		return false
	}
	return tn.made
}

func TestServerEventsGiveTheOpenChatNoPriority(t *testing.T) {
	openChatOn(t)
	cases := []struct {
		name  string
		event func()
	}{
		{"check-in or drain kick", nostrKick},
		{"route rescue kick", kickRelays},
		{"tor back for a check-in", kickForTorBack},
		{"kick right after the phone's own", func() { kickRelaysMade(); kickRelays() }},
	}
	for _, c := range cases {
		tn := openRunner(t)
		c.event()
		spendFirstTurn()
		if takeWithin(tn, 200*time.Millisecond) {
			t.Fatalf("%s: the open chat asked with no turn", c.name)
		}
		if tn.made || rankOf(tn) != paceAny {
			t.Fatalf("%s: the open chat's dial ranks %d, want %d", c.name, rankOf(tn), paceAny)
		}
	}
	// a relay's drop: the redial goes at once as every one does, unranked
	tn := openRunner(t)
	if !takeWithin(tn, 200*time.Millisecond) || tn.made || rankOf(tn) != paceAny {
		t.Fatalf("a redial after a drop ranks %d, want %d", rankOf(tn), paceAny)
	}
}

func TestAPushWakeGivesTheOpenChatNoPriority(t *testing.T) {
	openChatOn(t)
	// a big inbox: the wake's turns are minutes wide
	countSockets(t, 0, 4000)
	sleep := fakeSleep(t)
	tn := openRunner(t)
	sleep(10 * time.Minute)
	if takeWithin(tn, 200*time.Millisecond) {
		t.Fatal("the open chat asked with no turn after a wake nobody looked at")
	}
	if tn.made || rankOf(tn) != paceAny {
		t.Fatalf("the open chat's dial in a push wake ranks %d, want %d", rankOf(tn), paceAny)
	}
	// down at a network change's kick before the sleep: that kick is no
	// reason to rank in the push wake after it
	wakeReset()
	wakeCheck()
	tn = openRunner(t)
	tn.lost()
	kickRelaysMade()
	sleep(10 * time.Minute)
	if takeWithin(tn, 200*time.Millisecond) || tn.made {
		t.Fatal("a phone's kick from before the sleep ranked the open chat in a push wake")
	}
	// a check-in's kick in a wake changes nothing
	wakeReset()
	wakeCheck()
	tn = openRunner(t)
	sleep(10 * time.Minute)
	nostrKick()
	if takeWithin(tn, 200*time.Millisecond) || tn.made {
		t.Fatal("the open chat went first at a check-in's wake")
	}
}

func TestPhoneEventsKeepTheOpenChatFirst(t *testing.T) {
	openChatOn(t)
	// the network came back, the socket down since it went
	tn := openRunner(t)
	tn.lost()
	netBack()
	spendFirstTurn()
	if !takeWithin(tn, 200*time.Millisecond) || !tn.made || rankOf(tn) != paceFirst {
		t.Fatalf("after the network came back the open chat ranks %d (made %v), want %d at once", rankOf(tn), tn.made, paceFirst)
	}
	// tor woke because the app came to the front, the socket down in its sleep
	tn = openRunner(t)
	tn.lost()
	noteAppFront(true)
	kickForTorBack()
	spendFirstTurn()
	if !takeWithin(tn, 200*time.Millisecond) || !tn.made || rankOf(tn) != paceFirst {
		t.Fatalf("at the front's tor wake the open chat ranks %d (made %v), want %d at once", rankOf(tn), tn.made, paceFirst)
	}
	// another chat's address still waits its turn under it
	other := &subTurn{tag: "someone-else", lane: "everyday:9:9"}
	other.kick = kickChan()
	other.up = true
	kickRelaysMade()
	spendFirstTurn()
	if takeWithin(other, 200*time.Millisecond) {
		t.Fatal("another chat asked with no turn under the phone's kick")
	}
}

// the open chat waits its turn under a server's kick; the app coming to
// the front or a network change ends that wait, another chat's goes on
func TestAPhoneEventEndsTheOpenChatsWait(t *testing.T) {
	events := []struct {
		name  string
		event func()
	}{
		{"app to the front", func() { noteAppFront(true) }},
		{"network change", networkChanged},
	}
	for _, e := range events {
		openChatOn(t)
		rigFlips(t, 10*time.Millisecond, 20*time.Millisecond, 50*time.Millisecond)
		tn := openRunner(t)
		other := &subTurn{tag: "someone-else", lane: "everyday:9:9", kick: kickChan(), up: true}
		nostrKick()
		spendFirstTurn()
		type res struct {
			ok   bool
			took time.Duration
		}
		got, gotOther := make(chan res, 1), make(chan res, 1)
		start := time.Now()
		go func() { ok := takeWithin(tn, 3*time.Second); got <- res{ok, time.Since(start)} }()
		go func() { ok := takeWithin(other, 600*time.Millisecond); gotOther <- res{ok, time.Since(start)} }()
		time.Sleep(150 * time.Millisecond)
		select {
		case r := <-got:
			t.Fatalf("%s: the open chat went before the event (%v)", e.name, r.took)
		default:
		}
		e.event()
		r := <-got
		if !r.ok || r.took > time.Second || !tn.made || rankOf(tn) != paceFirst {
			t.Fatalf("%s: the open chat went after %v (ok %v), ranks %d, want at once and %d", e.name, r.took, r.ok, rankOf(tn), paceFirst)
		}
		// one that went before the event had the free first turn, after a
		// kick from the route watch: not this event's doing
		if o := <-gotOther; o.ok && o.took >= 140*time.Millisecond {
			t.Fatalf("%s: another chat's wait ended too, after %v", e.name, o.took)
		}
		appFront.Store(false)
	}
}

// a wake the app came to the front in, or the network changed in: the open
// chat's first redial ranks if its socket was down already at the event, or
// it did not answer that event's kick live. a socket that was up at the
// event and dropped after it does not, however soon the drop comes
func TestAWakeRanksOnlySocketsDownAtThePhonesEvent(t *testing.T) {
	openChatOn(t)
	// a big inbox: the wake's turns are minutes wide
	countSockets(t, 0, 4000)
	sleep := fakeSleep(t)
	asleep := func() *subTurn {
		wakeReset()
		wakeCheck()
		tn := openRunner(t)
		sleep(10 * time.Minute)
		// a runner sees the wake
		wakeCheck()
		return tn
	}
	front := func() {
		noteAppFront(false)
		noteAppFront(true)
	}
	// found dead on the wake, then the app came to the front
	tn := asleep()
	tn.lost()
	time.Sleep(time.Millisecond)
	front()
	if !takeWithin(tn, 200*time.Millisecond) || !tn.made || rankOf(tn) != paceFirst {
		t.Fatalf("a socket down before the front ranks %d (made %v), want %d at once", rankOf(tn), tn.made, paceFirst)
	}
	// up at the front, dropped by the relay right after it
	tn = asleep()
	front()
	time.Sleep(time.Millisecond)
	tn.lost()
	if rankedOnItsOwn(tn) {
		t.Fatal("a socket the relay dropped after the front went first in the wake")
	}
	// down at a network change's kick after the wake
	tn = asleep()
	tn.lost()
	kickRelaysMade()
	if !takeWithin(tn, 200*time.Millisecond) || !tn.made || rankOf(tn) != paceFirst {
		t.Fatalf("a socket down at the phone's kick in a wake ranks %d (made %v), want %d at once", rankOf(tn), tn.made, paceFirst)
	}
	// answered that kick live, dropped after it
	tn = asleep()
	kickRelaysMade()
	tn.skip()
	tn.lost()
	if rankedOnItsOwn(tn) {
		t.Fatal("a socket that answered the phone's kick live went first after a drop")
	}
	// up, catching up when that kick came and so never answering it, then
	// dropped after it
	tn = asleep()
	kickRelaysMade()
	time.Sleep(time.Millisecond)
	tn.lost()
	if rankedOnItsOwn(tn) {
		t.Fatal("a socket up at the phone's kick in a wake went first after a later drop")
	}
}

// a runner's first ask is the start's only while the process is young: one
// made hours later in a process never kicked since is no start
func TestTheStartRanksOnlyAtTheStart(t *testing.T) {
	openChatOn(t)
	oldStart, oldFor := procStart, startMadeFor
	// a kick of no one's: the start's own
	kickRelays()
	startFirst.Lock()
	oldKick := startFirst.kick
	startFirst.kick = kickChan()
	startFirst.Unlock()
	t.Cleanup(func() {
		procStart, startMadeFor = oldStart, oldFor
		startFirst.Lock()
		startFirst.kick = oldKick
		startFirst.Unlock()
	})
	startMadeFor = 15 * time.Minute
	spendFirstTurn()
	procStart = ownClock()
	tn := &subTurn{tag: openTag, lane: paceLane}
	if !takeWithin(tn, 200*time.Millisecond) || !tn.made {
		t.Fatal("the open chat waited a turn at the start")
	}
	procStart = ownClock() - time.Hour
	tn = &subTurn{tag: openTag, lane: paceLane}
	if takeWithin(tn, 200*time.Millisecond) || tn.made {
		t.Fatal("a runner made an hour into the process asked as the start's")
	}
	// the start is timed by the boot clock: an hour on it ends the start
	// whatever the wall clock says, and a wall clock set back opens nothing
	var ahead time.Duration
	setOwnClock(t, func() time.Duration { return bootClock() + ahead })
	procStart = ownClock()
	if !startKickPeek(kickChan()) {
		t.Fatal("no start just after the process began")
	}
	ahead = time.Hour
	if startKickPeek(kickChan()) {
		t.Fatal("still the start an hour on by the boot clock")
	}
}

// a phone's kick that came while the socket was dialling or catching up was
// never taken by it: a relay's drop later must not rank its redial
func TestAKickWhileUpRanksNoLaterDrop(t *testing.T) {
	openChatOn(t)
	// down, redialling under a kick of no one's; the phone's kick lands
	// during the dial, the dial gets through, and the relay drops it later
	tn := openRunner(t)
	tn.lost()
	kickRelays()
	spendFirstTurn()
	takeWithin(tn, 50*time.Millisecond)
	kickRelaysMade()
	tn.dialed(true)
	time.Sleep(time.Millisecond)
	tn.lost()
	spendFirstTurn()
	if rankedOnItsOwn(tn) {
		t.Fatal("a drop after a phone's kick that came mid-dial ranked the open chat")
	}
	// up and catching up when the kick came, dropped after it
	tn = openRunner(t)
	kickRelaysMade()
	time.Sleep(time.Millisecond)
	tn.lost()
	spendFirstTurn()
	if rankedOnItsOwn(tn) {
		t.Fatal("a drop after a phone's kick that came while up ranked the open chat")
	}
	// up when the kick came and gone by a way that said nothing: no rank
	tn = openRunner(t)
	kickRelaysMade()
	spendFirstTurn()
	if takeWithin(tn, 200*time.Millisecond) || tn.made {
		t.Fatal("a socket up at the phone's kick ranked its redial")
	}
	// down when the kick came: it ranks
	tn = openRunner(t)
	tn.lost()
	kickRelaysMade()
	spendFirstTurn()
	if !takeWithin(tn, 200*time.Millisecond) || !tn.made || rankOf(tn) != paceFirst {
		t.Fatalf("a socket down at the phone's kick ranks %d (made %v), want %d", rankOf(tn), tn.made, paceFirst)
	}
}

// the open chat's batch still in line moves up at the app's front
func TestAPhoneEventRaisesTheOpenChatsPlace(t *testing.T) {
	u := paceStore(t)
	paceWith(t, 40*time.Millisecond, 0)
	const openLane = "everyday:0:7"
	noteKnockTarget(openTag, knockTarget{lane: openLane})
	firstTag.Store(openTag)
	appFront.Store(false)
	t.Cleanup(func() {
		firstTag.Store("")
		appFront.Store(false)
		knockNotesMu.Lock()
		delete(knockNotes, openTag)
		knockNotesMu.Unlock()
	})
	lead := paceJoin(paceLane, u, paceAny)
	var rest []*paceTicket
	for range 12 {
		rest = append(rest, paceJoin(paceLane, u, paceAny))
	}
	open := paceJoin(openLane, u, paceAny)
	if err := lead.wait(context.Background()); err != nil {
		t.Fatal(err)
	}
	noteAppFront(true)
	dialPace.Lock()
	rank := open.rank
	dialPace.Unlock()
	if rank != paceFirst {
		t.Fatalf("the open chat's batch in line ranks %d after the front, want %d", rank, paceFirst)
	}
	at := paceGrants(t, append([]*paceTicket{open}, rest...))
	for i, a := range at[1:] {
		if !at[0].Before(a) {
			t.Fatalf("the open chat's batch got its place after redial %d", i)
		}
	}
}

// private mode with automatic bridges: a network change's reconnect is
// automatic's pass, and only the first reconnect of a pass a network change
// started gives the open chat no turn
func TestAutomaticsPassForANetworkMarksItsKick(t *testing.T) {
	f := useFakeAuto(t, wifi())
	var got []string
	runLoop(t, f, func(n int, why string) string {
		// the last pass reconnects nothing: its mark goes with it
		if n == 3 {
			got = append(got, why)
			stopLoop()
			return seenOK
		}
		got = append(got, fmt.Sprintf("%s:%v:%v", why, reconnectMade(whyAuto), reconnectMade(whyAuto)))
		netEpoch.Add(1)
		return passInterrupted
	})
	if want := []string{"start:false:false", "network:true:false", "network"}; !slices.Equal(got, want) {
		t.Fatalf("passes and their reconnects %v, want %v", got, want)
	}
	if reconnectMade(whyAuto) || reconnectMade(whyRelays) || !reconnectMade(whyNetwork) {
		t.Fatal("a reconnect outside a network pass gave the open chat no turn")
	}
}

// the runners themselves: sockets up at the app's front and dropped by the
// relay after it redial at their wake turns, the open chat's too
func TestARelaysDropAfterTheFrontNamesNoChat(t *testing.T) {
	setLiveCap(t, 1000, 1000*time.Hour)
	own := newRelayStandIn(t, 0)
	pub := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, own, pub)
	// a big inbox: the public relay's wake turns begin past 20 s
	countSockets(t, 4000, 4000)
	appFront.Store(false)
	t.Cleanup(func() {
		firstTag.Store("")
		appFront.Store(false)
	})
	sleep := fakeSleep(t)
	ctx := lanesCtx(t)
	l := startLanes(t, alone(ctx), 3, 0)
	open := l.contacts[0]
	firstTag.Store(hex.EncodeToString(l.peers[0].pub[:]))
	waitFor(t, "every address on both relays", 15*time.Second, func() bool {
		for _, a := range append(append([]string(nil), l.contacts...), l.fc) {
			if openOn(own, a) != 1 || openOn(pub, a) != 1 {
				return false
			}
		}
		return true
	})
	sleep(2 * time.Hour)
	noteAppFront(true)
	at := time.Now()
	own.dropAll()
	pub.dropAll()
	// a drop's own pause on the public relay is 5 s: a redial with no turn
	// would be back well inside this
	time.Sleep(10 * time.Second)
	if back := redials(pub, at, []string{open}); len(back) != 0 {
		t.Fatalf("the open chat's address was back on the public relay %s after a drop that followed the front", back[0])
	}
}
