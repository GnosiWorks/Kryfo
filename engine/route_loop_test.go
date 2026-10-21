// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"testing"
	"time"
)

// an hour with one live socket on our relay answering every 75 s and a
// kick 30 s after new circuits. fail is called every 10 s for the down relays
func circuitsHour(t *testing.T, fail func(now time.Time)) (circuits, bounces int) {
	t.Helper()
	t0 := time.Now()
	nextProbe := t0.Add(75 * time.Second)
	var kickProof time.Time
	for now := t0; now.Before(t0.Add(time.Hour)); now = now.Add(time.Second) {
		if now.Sub(t0)%(10*time.Second) == 0 {
			fail(now)
		}
		if !now.Before(nextProbe) || (!kickProof.IsZero() && !now.Before(kickProof)) {
			routeAliveOn(routeGeneration(), "ws://ours.onion")
			if !now.Before(nextProbe) {
				nextProbe = now.Add(75 * time.Second)
			}
			kickProof = time.Time{}
		}
		if now.Sub(t0)%(10*time.Second) != 0 {
			continue
		}
		why := routeNeedsRescue(now)
		switch {
		case why == "":
		case strings.HasPrefix(why, circuitsWhy):
			circuits++
			kickProof = now.Add(30 * time.Second)
		case strings.HasPrefix(why, probeWhy):
			kickProof = now.Add(30 * time.Second)
		default:
			bounces++
		}
	}
	return circuits, bounces
}

// two public relays down for good while our relay answers: their failures
// are their own, so nothing is done about tor at all
func TestTwoDeadRelaysMakeNoLoop(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	setRelays([]string{"ws://ours.onion", "wss://relay.kryfo.app", "wss://down1.example", "wss://down2.example"})
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	c, b := circuitsHour(t, func(time.Time) {
		routeNoteFail("wss://down1.example")
		routeNoteFail("wss://down2.example")
	})
	if c != 0 || b != 0 {
		t.Fatalf("in an hour: %d new-circuits steps, %d bounces, want none", c, b)
	}
}

// the same with the failures forced in as if those relays had answered on
// this route: new circuits come at most once in their gap
func TestNewCircuitsDoNotLoop(t *testing.T) {
	useStandIns(t, modePrivate, nil)
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	c, b := circuitsHour(t, func(now time.Time) {
		failAll(now, "wss://down1.example", "wss://down2.example")
	})
	if most := int(time.Hour/circuitsGap) + 1; c > most || b != 0 {
		t.Fatalf("in an hour: %d new-circuits steps (at most %d), %d bounces with a socket answering its probes", c, most, b)
	}
}
