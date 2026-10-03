// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what the poll hands over is remembered as seen only once the app says it
// kept it. what it could not keep comes again, a batch never confirmed comes
// again, and after a process death the next connection fetches it again.

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"
)

func pollAckReset(t *testing.T) *seenIDs {
	t.Helper()
	pollHoldReset(t)
	return loadSeen("")
}

// lines with ids the set has claimed, as take() leaves them
func pollAckPut(t *testing.T, set *seenIDs, bodies ...string) map[string]inboxDone {
	t.Helper()
	out := map[string]inboxDone{}
	nostrMu.Lock()
	defer nostrMu.Unlock()
	for _, b := range bodies {
		id := randomID(t)
		if !set.claim(id) {
			t.Fatal("claim")
		}
		d := inboxDone{set: set, id: id}
		nostrInbox = append(nostrInbox, "x-alice|"+b)
		nostrInboxDone = append(nostrInboxDone, d)
		out[b] = d
	}
	return out
}

func pollRaw(t *testing.T) pollOut {
	t.Helper()
	raw := nostrPollAt(time.Now())
	var b pollOut
	if raw == "" {
		return b
	}
	if err := json.Unmarshal([]byte(raw), &b); err != nil {
		t.Fatal(err)
	}
	return b
}

func bodies(b pollOut) string {
	var s []string
	for _, e := range b.M {
		s = append(s, e.C)
	}
	return strings.Join(s, ",")
}

func TestOnlyWhatTheAppKeptIsSeen(t *testing.T) {
	set := pollAckReset(t)
	ids := pollAckPut(t, set, "a", "b", "c")
	b := pollRaw(t)
	if bodies(b) != "a,b,c" {
		t.Fatalf("first poll %q", bodies(b))
	}
	for _, d := range ids {
		if set.handed(d.id) {
			t.Fatal("seen before the app kept it")
		}
	}
	// the app kept a and c, b threw
	if r := nostrAck(b.K, "[1]"); r != "ok" {
		t.Fatal(r)
	}
	if !set.handed(ids["a"].id) || !set.handed(ids["c"].id) || set.handed(ids["b"].id) {
		t.Fatal("seen does not follow what the app kept")
	}
	again := pollRaw(t)
	if bodies(again) != "b" {
		t.Fatalf("the next poll brought %q, want b alone", bodies(again))
	}
	nostrAck(again.K, "")
	if !set.handed(ids["b"].id) {
		t.Fatal("b kept and not seen")
	}
	if got := pollRaw(t); got.K != "" {
		t.Fatalf("handed over again: %q", bodies(got))
	}
}

func TestABatchNeverConfirmedComesAgain(t *testing.T) {
	set := pollAckReset(t)
	pollAckPut(t, set, "a", "b")
	first := pollRaw(t)
	pollAckPut(t, set, "c")
	// the app died in the middle and polls again
	second := pollRaw(t)
	if bodies(second) != "a,b,c" {
		t.Fatalf("after no ack the poll brought %q", bodies(second))
	}
	// the old token is gone: its late ack changes nothing
	if r := nostrAck(first.K, ""); r != "ok" {
		t.Fatal(r)
	}
	nostrAck(second.K, "")
	if got := pollRaw(t); got.K != "" {
		t.Fatalf("handed over again: %q", bodies(got))
	}
}

func TestALineNeverKeptStopsComing(t *testing.T) {
	set := pollAckReset(t)
	ids := pollAckPut(t, set, "bad", "good")
	b := pollRaw(t)
	nostrAck(b.K, "[0]")
	for i := 1; i < pollMaxTries; i++ {
		b = pollRaw(t)
		if i < pollMaxTries-1 && bodies(b) != "bad" {
			t.Fatalf("try %d brought %q", i, bodies(b))
		}
		if b.K != "" {
			nostrAck(b.K, "[0]")
		}
	}
	if got := pollRaw(t); got.K != "" {
		t.Fatalf("still offered after %d tries: %q", pollMaxTries, bodies(got))
	}
	// left for the next process, which fetches it again
	if set.handed(ids["bad"].id) {
		t.Fatal("a line the app never kept was remembered as seen")
	}
	if !set.handed(ids["good"].id) {
		t.Fatal("the line kept was not seen")
	}
	// a copy fetched again, from a reconnect or another relay, is taken
	if !set.claim(ids["bad"].id) {
		t.Fatal("a copy of the line given up on is refused for the rest of the process")
	}
}

func TestBadAcksLeaveTheBatch(t *testing.T) {
	set := pollAckReset(t)
	pollAckPut(t, set, "a")
	b := pollRaw(t)
	if r := nostrAck("nope", ""); !strings.HasPrefix(r, "error") {
		t.Fatalf("a bad token: %q", r)
	}
	if r := nostrAck(b.K, "{"); !strings.HasPrefix(r, "error") {
		t.Fatalf("a bad list: %q", r)
	}
	if got := pollRaw(t); bodies(got) != "a" {
		t.Fatalf("after bad acks the poll brought %q", bodies(got))
	}
}

// the process dies after a poll and before the app kept it: the next
// process's connection fetches it again. once kept, it does not
func TestADeathBeforeTheAckFetchesAgain(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	t.Cleanup(func() {
		nostrMu.Lock()
		clear(pollInflight)
		nostrMu.Unlock()
	})
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	ck := catchupKey(relay.url(), rcv)
	forgetCatchup(ck)
	t.Cleanup(func() { forgetCatchup(ck) })
	relay.store(wrapToAt(t, peer, myXPub, "text", time.Now().Add(-time.Hour)))

	// a process: a runner, a poll, then gone with nothing confirmed
	run := func(ack bool) bool {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
		got := false
		end := time.Now().Add(3 * time.Second)
		for time.Now().Before(end) && !got {
			raw := nostrPollAt(time.Now())
			if raw != "" {
				var b pollOut
				if err := json.Unmarshal([]byte(raw), &b); err != nil {
					t.Fatal(err)
				}
				for _, e := range b.M {
					got = got || (e.T == tag && e.C == "text")
				}
				if ack {
					nostrAck(b.K, "")
				}
			}
			time.Sleep(50 * time.Millisecond)
		}
		cancel()
		time.Sleep(200 * time.Millisecond)
		// what a process keeps in memory goes with it
		nostrMu.Lock()
		nostrInbox, nostrInboxDone = nil, nil
		clear(pollInflight)
		nostrMu.Unlock()
		forgetCatchup(ck)
		return got
	}
	if !run(false) {
		t.Fatal("the first process never got the text")
	}
	if !run(true) {
		t.Fatal("the text taken and never kept did not come again")
	}
	if run(true) {
		t.Fatal("the text kept came again in the next process")
	}
}

// days off, a text from the start of them and one from now in the same
// answer. the process dies before the app kept them: the next one asks from
// far enough back for the old one, and once both are kept the file moves up
func TestADeathBeforeTheAckFetchesADaysOldTextAgain(t *testing.T) {
	relay := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, relay)
	freshInbox(t)
	t.Cleanup(func() {
		nostrMu.Lock()
		clear(pollInflight)
		nostrMu.Unlock()
	})
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	ck := catchupKey(relay.url(), rcv)
	forgetCatchup(ck)
	t.Cleanup(func() { forgetCatchup(ck) })
	now := time.Now()
	relay.store(wrapToAt(t, peer, myXPub, "old", now.Add(-72*time.Hour)))
	relay.store(wrapToAt(t, peer, myXPub, "new", now.Add(-time.Minute)))
	_, lastPath := addressFiles(rcv)

	run := func(ack bool) map[string]bool {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
		got := map[string]bool{}
		end := time.Now().Add(3 * time.Second)
		for time.Now().Before(end) && !(got["old"] && got["new"]) {
			if b := pollRaw(t); b.K != "" {
				for _, e := range b.M {
					if e.T == tag {
						got[e.C] = true
					}
				}
				if ack {
					nostrAck(b.K, "")
				}
			}
			time.Sleep(50 * time.Millisecond)
		}
		cancel()
		time.Sleep(200 * time.Millisecond)
		nostrMu.Lock()
		nostrInbox, nostrInboxDone = nil, nil
		clear(pollInflight)
		nostrMu.Unlock()
		forgetCatchup(ck)
		return got
	}
	if got := run(false); !got["old"] || !got["new"] {
		t.Fatalf("the first process got %v", got)
	}
	if got := run(true); !got["old"] {
		t.Fatalf("after the death the old text did not come again, the next process got %v", got)
	}
	b, err := os.ReadFile(lastPath)
	if err != nil {
		t.Fatal(err)
	}
	if v, _ := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64); v < now.Add(-time.Minute).Unix() {
		t.Fatalf("both kept and the file stays %s back", now.Sub(time.Unix(v, 0)).Round(time.Minute))
	}
	if got := run(true); len(got) > 0 {
		t.Fatalf("texts kept came again: %v", got)
	}
}
