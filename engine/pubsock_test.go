// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"sync"
	"testing"
	"time"

	"fiatjaf.com/nostr"
)

// publishes the wraps n at a time, the way media_send.dart does, and fails
// on any that no relay took
func publishAll(t *testing.T, lane string, evs []nostr.Event, n int) {
	t.Helper()
	var wg sync.WaitGroup
	ch := make(chan nostr.Event)
	fails := make(chan string, len(evs))
	for w := 0; w < n; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for ev := range ch {
				ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
				if nostrPublishMulti(ctx, lane, ev) == 0 {
					fails <- ev.ID.Hex()
				}
				cancel()
			}
		}()
	}
	for _, ev := range evs {
		ch <- ev
	}
	close(ch)
	wg.Wait()
	close(fails)
	for id := range fails {
		t.Errorf("%s: no relay took it", id[:12])
	}
}

func wrapsTo(t *testing.T, from xid, to [32]byte, n int) ([]nostr.Event, string) {
	t.Helper()
	var evs []nostr.Event
	for i := 0; i < n; i++ {
		evs = append(evs, wrapTo(t, from, to, "slice"))
	}
	return evs, wrapAddr(evs[0])
}

// waits until every relay holds n events
func waitAccepted(t *testing.T, n int, relays ...*relayStandIn) {
	t.Helper()
	waitFor(t, "every relay has every wrap", 20*time.Second, func() bool {
		for _, r := range relays {
			r.mu.Lock()
			got := r.accepted
			r.mu.Unlock()
			if got < n {
				return false
			}
		}
		return true
	})
}

// a burst to one address goes out on one socket per relay. a burst to
// another address, or on another lane, never shares it, and no publish
// socket is a subscription socket.
func TestPublishSocketPerRecipientAndLane(t *testing.T) {
	socks := newSocksStandIn(t)
	a := newRelayStandIn(t, 0)
	b := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, a, b)
	me, err := myXid()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	l := startLanes(t, ctx, 1, 1)

	toA, addrA := wrapsTo(t, me, newXid(t).pub, 12)
	toB, addrB := wrapsTo(t, me, newXid(t).pub, 12)
	rk := l.roomKeys[0]
	room := roomLane(hex.EncodeToString(rk.pub[:]))
	toC, addrC := wrapsTo(t, rk, newXid(t).pub, 6)
	// the same address from another lane: never the everyday socket
	toA2, _ := wrapsTo(t, me, newXid(t).pub, 1)
	toA2[0] = toA[0]

	var wg sync.WaitGroup
	for _, job := range []struct {
		lane string
		evs  []nostr.Event
	}{{laneEveryday, toA}, {laneEveryday, toB}, {room, toC}} {
		wg.Add(1)
		go func(lane string, evs []nostr.Event) {
			defer wg.Done()
			publishAll(t, lane, evs, 5)
		}(job.lane, job.evs)
	}
	wg.Wait()
	waitAccepted(t, 30, a, b)
	publishAll(t, "room:other", toA2, 1)
	waitAccepted(t, 31, a, b)

	for name, r := range map[string]*relayStandIn{"a": a, "b": b} {
		per := map[string]int{}
		laneOf := map[string]string{}
		for _, c := range r.snapshot() {
			if len(c.published) == 0 {
				continue
			}
			if len(c.subIDs) > 0 {
				t.Errorf("relay %s: a subscription socket published", name)
			}
			if len(c.published) != 1 {
				t.Fatalf("relay %s: one socket published to %d addresses", name, len(c.published))
			}
			n, ok := socks.nameOf(c.remote)
			if !ok || n == "" {
				t.Fatalf("relay %s: a publish went out without a socks name", name)
			}
			for addr := range c.published {
				per[addr]++
				laneOf[addr+" "+n] = addr
			}
		}
		if per[addrA] != 2 || per[addrB] != 1 || per[addrC] != 1 {
			t.Errorf("relay %s: sockets per address a=%d (want 2: everyday and the other lane) b=%d c=%d, want one each",
				name, per[addrA], per[addrB], per[addrC])
		}
		everyday, roomName := laneName(laneEveryday), laneName(room)
		if laneOf[addrA+" "+everyday] == "" || laneOf[addrB+" "+everyday] == "" {
			t.Errorf("relay %s: an everyday burst did not go under the everyday name", name)
		}
		if laneOf[addrC+" "+roomName] == "" {
			t.Errorf("relay %s: the room's burst did not go under the room's name", name)
		}
		if laneOf[addrA+" "+laneName("room:other")] == "" {
			t.Errorf("relay %s: the other lane's wrap did not go under its own name", name)
		}
	}
}

// the socket goes once the burst has been quiet for pubIdle, and the next
// wrap to the same address dials a new one
func TestPublishSocketClosesWhenIdle(t *testing.T) {
	old := pubIdle
	pubIdle = 300 * time.Millisecond
	defer func() { pubIdle = old }()
	socks := newSocksStandIn(t)
	r := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, r)
	me, _ := myXid()
	evs, _ := wrapsTo(t, me, newXid(t).pub, 4)

	publishAll(t, laneEveryday, evs[:3], 3)
	waitAccepted(t, 3, r)
	waitFor(t, "the quiet socket closed", 5*time.Second, func() bool {
		cs := r.snapshot()
		return len(cs) == 1 && !cs[0].closed.IsZero()
	})
	publishAll(t, laneEveryday, evs[3:], 1)
	waitAccepted(t, 4, r)
	if n := len(r.snapshot()); n != 2 {
		t.Fatalf("%d sockets, want the first and one new", n)
	}
}

// a relay that drops the kept socket costs the next wrap nothing: it goes
// out on a new one
func TestPublishSocketRedialsAfterDrop(t *testing.T) {
	socks := newSocksStandIn(t)
	r := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, r)
	me, _ := myXid()
	evs, _ := wrapsTo(t, me, newXid(t).pub, 6)

	publishAll(t, laneEveryday, evs[:3], 3)
	waitAccepted(t, 3, r)
	r.dropAll()
	waitFor(t, "the socket noticed", 5*time.Second, func() bool {
		pubMu.Lock()
		defer pubMu.Unlock()
		for _, s := range pubSocks {
			if s.r != nil && s.r.IsConnected() {
				return false
			}
		}
		return true
	})
	publishAll(t, laneEveryday, evs[3:], 3)
	waitAccepted(t, 6, r)
	if n := len(r.snapshot()); n != 2 {
		t.Fatalf("%d sockets, want the dropped one and one new", n)
	}
}

// a kept socket that stops answering, the way a dead circuit does, is let
// go, and the wrap goes out on a new one
func TestPublishSocketThatGoesQuietIsReplaced(t *testing.T) {
	old := pubQuiet
	pubQuiet = 400 * time.Millisecond
	defer func() { pubQuiet = old }()
	socks := newSocksStandIn(t)
	r := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, r)
	me, _ := myXid()
	evs, _ := wrapsTo(t, me, newXid(t).pub, 4)

	publishAll(t, laneEveryday, evs[:2], 2)
	waitAccepted(t, 2, r)
	r.muteAll()
	start := time.Now()
	publishAll(t, laneEveryday, evs[2:], 2)
	waitAccepted(t, 4, r)
	if d := time.Since(start); d > 5*time.Second {
		t.Fatalf("the quiet socket held the wraps for %s", d)
	}
	cs := r.snapshot()
	if len(cs) != 2 {
		t.Fatalf("%d sockets, want the quiet one and one new", len(cs))
	}
	waitFor(t, "the quiet socket closed", 5*time.Second, func() bool {
		return !r.snapshot()[0].closed.IsZero()
	})
}

// a socket that sat idle longer than pubQuiet is not taken for a dead one
// when the next burst starts on it
func TestIdleSocketIsNotQuiet(t *testing.T) {
	oldQ, oldI := pubQuiet, pubIdle
	pubQuiet, pubIdle = 200*time.Millisecond, time.Minute
	defer func() { pubQuiet, pubIdle = oldQ, oldI }()
	socks := newSocksStandIn(t)
	socks.lag = 60 * time.Millisecond
	r := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, r)
	me, _ := myXid()
	evs, _ := wrapsTo(t, me, newXid(t).pub, 2)
	publishAll(t, laneEveryday, evs[:1], 1)
	time.Sleep(500 * time.Millisecond)
	publishAll(t, laneEveryday, evs[1:], 1)
	waitAccepted(t, 2, r)
	if n := len(r.snapshot()); n != 1 {
		t.Fatalf("%d sockets, want the idle one kept", n)
	}
}

// a mode change or a tor bounce closes every kept socket, and a room that is
// gone closes its own and nobody else's
func TestPublishSocketsGoWithTheirRoute(t *testing.T) {
	socks := newSocksStandIn(t)
	r := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, r)
	me, _ := myXid()
	evs, addr := wrapsTo(t, me, newXid(t).pub, 2)
	rk := newXid(t)
	room := roomLane(hex.EncodeToString(rk.pub[:]))
	roomEvs, roomAddr := wrapsTo(t, rk, newXid(t).pub, 2)

	publishAll(t, laneEveryday, evs, 2)
	publishAll(t, room, roomEvs, 2)
	waitAccepted(t, 4, r)
	closedOn := func(a string) bool {
		for _, c := range r.snapshot() {
			if c.published[a] {
				return !c.closed.IsZero()
			}
		}
		return false
	}
	dropLane(room)
	waitFor(t, "the room's socket closed", 5*time.Second, func() bool { return closedOn(roomAddr) })
	if closedOn(addr) {
		t.Fatal("dropping a room closed the everyday socket")
	}
	nostrResetClient()
	waitFor(t, "the everyday socket closed", 5*time.Second, func() bool { return closedOn(addr) })
}

// a wrap that names no single recipient gets a socket of its own
func TestWrapAddr(t *testing.T) {
	one := nostr.Event{Tags: nostr.Tags{{"p", "aa"}, {"expiration", "1"}}}
	two := nostr.Event{Tags: nostr.Tags{{"p", "aa"}, {"p", "bb"}}}
	if wrapAddr(one) != "aa" || wrapAddr(two) != "" || wrapAddr(nostr.Event{}) != "" {
		t.Fatal("wrapAddr")
	}
}

// a wrap whose own time runs out while it waits behind others leaves the
// socket to the rest of the burst
func TestWrapOutOfTimeKeepsTheSocket(t *testing.T) {
	socks := newSocksStandIn(t)
	socks.lag = 300 * time.Millisecond
	r := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, r)
	me, _ := myXid()
	evs, _ := wrapsTo(t, me, newXid(t).pub, 2)
	publishAll(t, laneEveryday, evs[:1], 1)
	client, err := torNostrClientFor(laneEveryday)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	if publishTo(ctx, laneEveryday, r.url(), client, evs[1]) == nil {
		t.Fatal("a wrap with 100ms had its ok over a 600ms round trip")
	}
	publishAll(t, laneEveryday, evs[1:], 1)
	if n := len(r.snapshot()); n != 1 {
		t.Fatalf("%d sockets, want the one kept", n)
	}
}
