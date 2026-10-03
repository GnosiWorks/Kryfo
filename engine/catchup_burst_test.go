// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a contact sends ten texts while this phone is off. each wrap is stamped up
// to ten hours back, so on our relay they lie scattered through everything
// else the address got in that window, most of it already taken before:
// the slices of files sent that evening. the walk that brings them back
// takes longer than a check-in may wait, and the socket it runs on stays up.

import (
	"context"
	"encoding/hex"
	"math/rand/v2"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

type offRun struct {
	t     *testing.T
	relay *relayStandIn
	peer  xid
	tag   string
	rcv   string
	texts []string
	// the poll each text first came in, by its body, and how often
	polls map[string]int
	seen  map[string]int
	n     int
}

// old: wraps the app took before, as on the phone; texts: sent while it
// was off
func newOffRun(t *testing.T, old, texts int) *offRun {
	b := &offRun{t: t, relay: newRelayStandIn(t, 0), polls: map[string]int{}, seen: map[string]int{}}
	useStandIns(t, modeFast, nil, b.relay)
	freshInbox(t)
	b.peer = newXid(t)
	b.tag = hex.EncodeToString(b.peer.pub[:])
	b.rcv = mustRcv(t, b.peer)
	forgetCatchup(catchupKey(b.relay.url(), b.rcv))
	t.Cleanup(func() { forgetCatchup(catchupKey(b.relay.url(), b.rcv)) })
	now := time.Now()
	r := rand.New(rand.NewPCG(7, 11))
	back := func() time.Duration { return time.Duration(r.Int64N(int64(10 * time.Hour))) }
	var ids []string
	for i := 0; i < old; i++ {
		ev := wrapToAt(t, b.peer, myXPub, "slice "+strconv.Itoa(i), now.Add(-time.Hour-back()))
		ids = append(ids, ev.ID.Hex())
		b.relay.store(ev)
	}
	seenPath, lastPath := addressFiles(b.rcv)
	if err := os.WriteFile(seenPath, []byte(strings.Join(ids, "\n")+"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	// the phone was stopped a minute ago, caught up
	if err := os.WriteFile(lastPath, []byte(strconv.FormatInt(now.Add(-time.Minute).Unix(), 10)), 0600); err != nil {
		t.Fatal(err)
	}
	for i := 1; i <= texts; i++ {
		body := "text " + strconv.Itoa(i)
		b.texts = append(b.texts, body)
		b.relay.store(wrapToAt(t, b.peer, myXPub, body, now.Add(-back())))
	}
	return b
}

func (b *offRun) poll() {
	entries := pollEntries(b.t)
	if len(entries) == 0 {
		return
	}
	b.n++
	for _, e := range entries {
		if e.T != b.tag {
			continue
		}
		if _, ok := b.polls[e.C]; !ok {
			b.polls[e.C] = b.n
		}
		b.seen[e.C]++
	}
}

func (b *offRun) missing() []string {
	var out []string
	for _, s := range b.texts {
		if b.seen[s] == 0 {
			out = append(out, s)
		}
	}
	return out
}

// every text once and, when onePoll, all of them in one poll, so the app
// opens them in the order they were sent
func (b *offRun) check(within time.Duration, onePoll bool) {
	t := b.t
	end := time.Now().Add(within)
	for time.Now().Before(end) && len(b.missing()) > 0 {
		b.poll()
		time.Sleep(100 * time.Millisecond)
	}
	if m := b.missing(); len(m) > 0 {
		t.Fatalf("%d of %d texts never came within %s: %v", len(m), len(b.texts), within, m)
	}
	// a second copy would come in a later poll
	time.Sleep(500 * time.Millisecond)
	b.poll()
	first := b.polls[b.texts[0]]
	for _, s := range b.texts {
		if b.seen[s] != 1 {
			t.Fatalf("%q came %d times", s, b.seen[s])
		}
		if onePoll && b.polls[s] != first {
			t.Fatalf("%q came in poll %d, %q in poll %d: the app cannot put them in order",
				s, b.polls[s], b.texts[0], first)
		}
	}
	for s := range b.seen {
		if strings.HasPrefix(s, "slice ") {
			t.Fatalf("%q was handed over again", s)
		}
	}
}

// under catchupMu, which catchupCapFor reads it under
func withCap(t *testing.T, d time.Duration) {
	catchupMu.Lock()
	old := catchupCap
	catchupCap = d
	catchupMu.Unlock()
	t.Cleanup(func() {
		catchupMu.Lock()
		catchupCap = old
		catchupMu.Unlock()
	})
}

// the cap ends the check-in's wait part way through the walk. the walk goes
// on: the texts below where it was are not left until the socket drops,
// which on a healthy one is not for a long time
func TestBurstToAStoppedPhoneArrivesWhole(t *testing.T) {
	withCap(t, time.Second)
	b := newOffRun(t, 600, 10)
	b.relay.mu.Lock()
	b.relay.reqDelay = 300 * time.Millisecond
	b.relay.mu.Unlock()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, b.tag, b.peer.pub, b.rcv)
	b.check(12*time.Second, true)
	if c := b.relay.snapshot(); len(c) != 1 {
		t.Fatalf("the relay saw %d connections, the walk should not need another", len(c))
	}
}

// the cap comes while the first answer is still on its way: the walk it
// would start must still run
func TestBurstArrivesWhenTheCapCutsTheFirstAnswer(t *testing.T) {
	withCap(t, 200*time.Millisecond)
	b := newOffRun(t, 400, 10)
	b.relay.mu.Lock()
	b.relay.reqDelay = 600 * time.Millisecond
	b.relay.mu.Unlock()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, b.tag, b.peer.pub, b.rcv)
	b.check(12*time.Second, true)
}

// what a check-in sees is unchanged: the walk past the cap counts as dropped
// and no longer as active, so the job can stop tor
func TestWalkPastTheCapIsNotActive(t *testing.T) {
	withCap(t, 300*time.Millisecond)
	b := newOffRun(t, 600, 1)
	b.relay.mu.Lock()
	b.relay.reqDelay = 400 * time.Millisecond
	b.relay.mu.Unlock()
	before := atomic.LoadInt32(&catchupActive)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, b.tag, b.peer.pub, b.rcv)
	ck := catchupKey(b.relay.url(), b.rcv)
	waitFor(t, "the cap", 5*time.Second, func() bool {
		catchupMu.Lock()
		r, ok := catchupLast[ck]
		catchupMu.Unlock()
		return ok && r.Dropped
	})
	if a := atomic.LoadInt32(&catchupActive); a != before {
		t.Fatalf("%d walks still count as active past the cap", a-before)
	}
	waitFor(t, "the walk going on", 5*time.Second, func() bool {
		c := b.relay.snapshot()
		return len(c) == 1 && len(c[0].reqs) >= 4
	})
}

// a page that never comes, on a socket that goes on answering probes. the
// walk stops at its mark, and only a new connection carries on from there
func TestBurstArrivesPastAPageThatNeverCame(t *testing.T) {
	withPageQuiet(t, 300*time.Millisecond)
	b := newOffRun(t, 600, 10)
	b.relay.mu.Lock()
	b.relay.stallAt = 3
	b.relay.mu.Unlock()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, b.tag, b.peer.pub, b.rcv)
	// the hold ends with the connection, so the two connections' parts
	// go over apart
	b.check(12*time.Second, false)
	if c := b.relay.snapshot(); len(c) < 2 || len(c[1].reqs) == 0 {
		t.Fatal("no new connection carried the walk on")
	}
}

func withPageQuiet(t *testing.T, d time.Duration) {
	old := pageQuietSet.Swap(int64(d))
	t.Cleanup(func() { pageQuietSet.Store(old) })
}

func walking(tag string) int {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	return walkingTags[tag]
}

// a first answer that never comes on one relay holds nothing back for long:
// the other relay's text goes over once the stalled one has brought nothing
// for a quiet spell, not when the poll's hold runs out
func TestAFirstAnswerThatNeverComesHoldsNothing(t *testing.T) {
	withPageQuiet(t, 300*time.Millisecond)
	ours, other := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, ours, other)
	freshInbox(t)
	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	keys := []string{catchupKey(ours.url(), rcv), catchupKey(other.url(), rcv)}
	forgetCatchup(keys...)
	t.Cleanup(func() { forgetCatchup(keys...) })
	ours.mu.Lock()
	ours.stallAt = 1
	ours.mu.Unlock()
	other.store(wrapToAt(t, peer, myXPub, "text", time.Now().Add(-time.Hour)))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, tag, peer.pub, rcv)
	got := false
	end := time.Now().Add(4 * time.Second)
	for time.Now().Before(end) && !got {
		for _, e := range pollEntries(t) {
			got = got || e.C == "text"
		}
		time.Sleep(50 * time.Millisecond)
	}
	if !got {
		t.Fatalf("the text was held behind a first answer that never came (%d walks counted)", walking(tag))
	}
}

// a contact writes while a long walk of theirs is under way: what is held
// for them goes over with the live text, in the order it came, and the walk
// goes on
func TestALiveTextTakesTheHeldOnesWithIt(t *testing.T) {
	b := newOffRun(t, 600, 10)
	b.relay.mu.Lock()
	b.relay.reqDelay = 500 * time.Millisecond
	b.relay.mu.Unlock()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, b.tag, b.peer.pub, b.rcv)
	waitFor(t, "texts held during the walk", 10*time.Second, func() bool {
		return inboxLen() > 0 && walking(b.tag) > 0
	})
	if raw := nostrPoll(); raw != "" {
		t.Fatalf("handed over during the walk before anything live: %s", raw)
	}
	held := inboxLen()
	b.relay.pushLive(wrapToAt(t, b.peer, myXPub, "live", time.Now().Add(-9*time.Hour)))
	var batch []pollEntry
	waitFor(t, "the live text", 2*time.Second, func() bool {
		batch = pollEntries(t)
		return len(batch) > 0
	})
	if walking(b.tag) == 0 {
		t.Fatal("the walk was over already, so this proves nothing")
	}
	if len(batch) < held+1 || batch[len(batch)-1].C != "live" {
		var got []string
		for _, e := range batch {
			got = append(got, e.C)
		}
		t.Fatalf("the batch with the live text: %v, want the %d held first and live last", got, held)
	}
}

// a page that is never answered, with the walk not one page past where it
// began: the socket stays, rather than being redialled for ever
func TestAPageNeverAnsweredKeepsTheSocket(t *testing.T) {
	withPageQuiet(t, 300*time.Millisecond)
	b := newOffRun(t, 600, 1)
	b.relay.mu.Lock()
	b.relay.stallAt, b.relay.stallAll = 2, true
	b.relay.mu.Unlock()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, b.tag, b.peer.pub, b.rcv)
	waitFor(t, "the first page asked", 5*time.Second, func() bool {
		c := b.relay.snapshot()
		return len(c) > 0 && len(c[0].reqs) >= 2
	})
	time.Sleep(4 * time.Second)
	if c := b.relay.snapshot(); len(c) != 1 {
		t.Fatalf("the relay saw %d connections for a page it never answers", len(c))
	}
}
