// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
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
	// the network came back
	tn := openRunner(t)
	netBack()
	spendFirstTurn()
	if !takeWithin(tn, 200*time.Millisecond) || !tn.made || rankOf(tn) != paceFirst {
		t.Fatalf("after the network came back the open chat ranks %d (made %v), want %d at once", rankOf(tn), tn.made, paceFirst)
	}
	// tor woke because the app came to the front
	tn = openRunner(t)
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

// a wake the app came to the front in: the open chat's first redial in it
// goes first, but only soon after the front, not at a drop minutes later
func TestAWakeInFrontKeepsTheOpenChatFirst(t *testing.T) {
	openChatOn(t)
	// a big inbox: the wake's turns are minutes wide
	countSockets(t, 0, 4000)
	sleep := fakeSleep(t)
	tn := openRunner(t)
	sleep(10 * time.Minute)
	noteAppFront(true)
	if !takeWithin(tn, 200*time.Millisecond) || !tn.made || rankOf(tn) != paceFirst {
		t.Fatalf("in a wake with the app in front the open chat ranks %d (made %v), want %d at once", rankOf(tn), tn.made, paceFirst)
	}
	// the front long gone: a relay's drop in a later wake ranks nothing
	old := phoneMadeFor
	phoneMadeFor = 50 * time.Millisecond
	t.Cleanup(func() { phoneMadeFor = old })
	wakeReset()
	wakeCheck()
	tn = openRunner(t)
	sleep(10 * time.Minute)
	noteAppFront(false)
	noteAppFront(true)
	time.Sleep(100 * time.Millisecond)
	if takeWithin(tn, 200*time.Millisecond) || tn.made {
		t.Fatal("a redial long after the front went first in the wake")
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
