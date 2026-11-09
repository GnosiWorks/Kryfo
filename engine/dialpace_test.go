// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"fmt"
	"maps"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"
)

// the pace as the app has it, an empty line, put back after
func paceForTest(t *testing.T) {
	t.Helper()
	paceWith(t, 260*time.Millisecond, 80*time.Millisecond)
}

func paceWith(t *testing.T, gap, jitter time.Duration) {
	t.Helper()
	oldGap, oldJitter := paceGap.Load(), paceJitter.Load()
	reset := func() {
		dialPace.Lock()
		dialPace.q, dialPace.next, dialPace.sent = nil, time.Time{}, nil
		if dialPace.timer != nil {
			dialPace.timer.Stop()
			dialPace.timer = nil
		}
		dialPace.Unlock()
	}
	reset()
	paceGap.Store(int64(gap))
	paceJitter.Store(int64(jitter))
	t.Cleanup(func() {
		paceGap.Store(oldGap)
		paceJitter.Store(oldJitter)
		reset()
	})
}

// a lane of the everyday batches, dialled in the clear in fast mode
const paceLane = "everyday:0:0"

func paceStore(t *testing.T) string {
	t.Helper()
	a := newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, nil, a)
	return a.url()
}

// when each ticket got its place, by its index
func paceGrants(t *testing.T, ts []*paceTicket) []time.Time {
	t.Helper()
	out := make([]time.Time, len(ts))
	var wg sync.WaitGroup
	for i, tk := range ts {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := tk.wait(context.Background()); err != nil {
				t.Errorf("ticket %d: %v", i, err)
			}
			out[i] = tk.at
		}()
	}
	wg.Wait()
	return out
}

func TestPaceSpreadsDialsWithJitter(t *testing.T) {
	u := paceStore(t)
	gap, jitter := 20*time.Millisecond, 10*time.Millisecond
	paceWith(t, gap, jitter)
	var ts []*paceTicket
	for range 30 {
		ts = append(ts, paceJoin(paceLane, u, paceRest))
	}
	at := paceGrants(t, ts)
	// in line they come in the order they joined
	for i := 1; i < len(at); i++ {
		if d := at[i].Sub(at[i-1]); d < gap-2*time.Millisecond {
			t.Fatalf("places %d and %d came %v apart, want at least %v", i-1, i, d, gap)
		}
	}
	// the gaps are not one beat
	seen := map[time.Duration]bool{}
	for i := 1; i < len(at); i++ {
		seen[at[i].Sub(at[i-1]).Round(2*time.Millisecond)] = true
	}
	if len(seen) < 3 {
		t.Fatalf("the gaps are all alike: %v", seen)
	}
	if most := paceMost(at, 4*gap); most > 4 {
		t.Fatalf("%d places within four gaps, want at most 4", most)
	}
}

func TestPaceTakesTheBestRankFirst(t *testing.T) {
	u := paceStore(t)
	paceWith(t, 15*time.Millisecond, 0)
	var ts []*paceTicket
	for range 6 {
		ts = append(ts, paceJoin(paceLane, u, paceRest))
	}
	top := paceJoin(paceLane, u, paceTop)
	first := paceJoin(paceLane, u, paceFirst)
	raised := ts[5]
	raised.raise(paceFirst)
	at := paceGrants(t, append(ts, top, first))
	// the first rest went at once, as the line was empty; then the one moved
	// up and the open chat's in the order they came, the start's first
	// batch, the rest in order
	order := []int{0, 5, 7, 6, 1, 2, 3, 4}
	for i := 1; i < len(order); i++ {
		if !at[order[i-1]].Before(at[order[i]]) {
			t.Fatalf("ticket %d had its place before %d, want the order %v", order[i], order[i-1], order)
		}
	}
}

func TestPaceLeavesNoOneBehindAGoneWaiter(t *testing.T) {
	u := paceStore(t)
	paceWith(t, 15*time.Millisecond, 5*time.Millisecond)
	ts := []*paceTicket{paceJoin(paceLane, u, paceRest), paceJoin(paceLane, u, paceRest), paceJoin(paceLane, u, paceRest)}
	ctx, cancel := context.WithCancel(context.Background())
	gone := paceJoin(paceLane, u, paceFirst)
	cancel()
	if err := gone.wait(ctx); err == nil {
		t.Fatal("a waiter whose wait ended got through")
	}
	// a place handed out and never used holds nothing either: the dial runs
	// on its own
	start := time.Now()
	paceGrants(t, ts)
	if d := time.Since(start); d > time.Second {
		t.Fatalf("the line took %v for three places", d)
	}
	dialPace.Lock()
	left := len(dialPace.q)
	dialPace.Unlock()
	if left != 0 {
		t.Fatalf("%d tickets still in line", left)
	}
}

func TestPaceSendGoesAtOnceAndTheLineWaits(t *testing.T) {
	u := paceStore(t)
	gap := 40 * time.Millisecond
	paceWith(t, gap, 0)
	sent := time.Now()
	paceCount(laneEveryday, u)
	at := paceGrants(t, []*paceTicket{paceJoin(paceLane, u, paceFirst)})
	if d := at[0].Sub(sent); d < gap-2*time.Millisecond {
		t.Fatalf("a socket in line dialled %v after a send, want a gap of %v", d, gap)
	}
}

func TestPaceOnlyForTheClear(t *testing.T) {
	u := paceStore(t)
	paceForTest(t)
	if paceJoin(paceLane, u, paceRest) == nil {
		t.Fatal("a batch socket to our store in fast mode took no place")
	}
	// the second store by the app's name: in the clear for everyday lanes
	if paceJoin(paceLane, "wss://relay2.kryfo.app", paceRest) == nil {
		t.Fatal("a batch socket to our second store in fast mode took no place")
	}
	if paceJoin(laneHidden, "wss://relay2.kryfo.app", paceRest) != nil {
		t.Fatal("a hidden chat's socket goes through tor and needs no place")
	}
	if paceJoin(paceLane, "wss://nos.lol", paceRest) != nil {
		t.Fatal("a public relay goes through tor in fast mode and needs no place")
	}
	transportMode.Store(modePrivate)
	if paceJoin(paceLane, u, paceRest) != nil {
		t.Fatal("in private mode every socket goes through tor and needs no place")
	}
}

// every batch socket to both stores dropped at once: they come back at most
// four a second, the open chat's batch near the front, and what came in
// meanwhile is caught up
func TestFastRedialsArePaced(t *testing.T) {
	paceForTest(t)
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, nil, a, b)
	old := secondRelayHost.get()
	secondRelayHost.put(strings.TrimPrefix(b.url(), "ws://"))
	t.Cleanup(func() {
		runnersGone(t)
		secondRelayHost.put(old)
	})
	statusForTest(t, "reachable")
	routeNoteOK()
	freshInbox(t)
	freshBatches(t)
	freshStart(t)
	const n = 48
	var peers []xid
	var tags []string
	want := map[string]bool{}
	for range n {
		x := newXid(t)
		peers = append(peers, x)
		tags = append(tags, hex.EncodeToString(x.pub[:]))
		want[mustRcv(t, x)] = true
	}
	var from time.Time
	all := func() bool {
		for _, r := range []*relayStandIn{a, b} {
			l := listenSince(r, from)
			for w := range want {
				if !l[w] {
					return false
				}
			}
		}
		return true
	}
	for _, h := range tags {
		if r := nostrSubscribeAs(mainIdent, h, false, false); r != "ok" {
			t.Fatal(r)
		}
	}
	waitFor(t, "every address listening", time.Minute, all)
	fsSettle([]*relayStandIn{a, b}, 2*time.Second, 30*time.Second)
	open := n - 1
	openAddr := mustRcv(t, peers[open])
	firstTag.Store(tags[open])
	defer firstTag.Store("")
	// the ranks the places after the drop went by
	var rankMu sync.Mutex
	ranks := map[int]int{}
	dialPace.Lock()
	paceGrantHook = func(tk *paceTicket) {
		rankMu.Lock()
		ranks[tk.rank]++
		rankMu.Unlock()
	}
	dialPace.Unlock()
	t.Cleanup(func() {
		dialPace.Lock()
		paceGrantHook = nil
		dialPace.Unlock()
	})
	drop := time.Now()
	from = drop
	a.dropAll()
	b.dropAll()
	for i := 0; i < n; i += 8 {
		a.store(wrapTo(t, peers[i], myXPub, "while down "+tags[i][:8]))
	}
	waitFor(t, "every address listening again", 40*time.Second, all)
	back := time.Since(drop)
	var ts []time.Time
	var conns []siConn
	for _, r := range []*relayStandIn{a, b} {
		for _, c := range fsSince(r.snapshot(), drop) {
			ts = append(ts, c.opened)
			conns = append(conns, c)
		}
	}
	if most := paceMost(ts, time.Second); most > 4 {
		t.Fatalf("%d new connections in one second after the drop, want at most 4", most)
	}
	// 6 batches on each store
	if len(ts) < 12 || back > 15*time.Second {
		t.Fatalf("%d new connections, every address back after %v", len(ts), back)
	}
	var seen []string
	sort.Slice(conns, func(i, j int) bool { return conns[i].opened.Before(conns[j].opened) })
	for _, c := range conns {
		seen = append(seen, fmt.Sprintf("%v:%d:%v", c.opened.Sub(drop).Round(10*time.Millisecond), len(c.addrs), c.addrs[openAddr]))
	}
	t.Logf("sockets after the drop, back after %v: %v", back.Round(100*time.Millisecond), seen)
	// the relays dropped them: no place went by the open chat or a chat
	// written to, or the order would name it
	rankMu.Lock()
	got := maps.Clone(ranks)
	rankMu.Unlock()
	if got[paceAny] == 0 || len(got) != 1 {
		t.Fatalf("places after a relay's drop by rank %v, want only %d (no rank)", got, paceAny)
	}
	for i := 0; i < n; i += 8 {
		body := "while down " + tags[i][:8]
		waitFor(t, body, 20*time.Second, func() bool { return inboxHas(tags[i] + "|" + body) })
	}
}

// a socket the relay dropped redials with no rank; one under the phone's
// own kick or start keeps it
func TestPaceRedialAfterADropTakesNoRank(t *testing.T) {
	firstTag.Store("peer")
	t.Cleanup(func() { firstTag.Store("") })
	tu := subTurn{tag: "peer", lane: paceLane}
	defer tu.done()
	ctx := context.Background()
	if !tu.take(ctx) || paceRankFor(tu.tag, tu.lane, tu.made) != paceFirst {
		t.Fatalf("the start's dial of the open chat ranks %d, want %d", paceRankFor(tu.tag, tu.lane, tu.made), paceFirst)
	}
	tu.dialed(true)
	// the socket died under the same kick: the relay may have closed it
	if !tu.take(ctx) || paceRankFor(tu.tag, tu.lane, tu.made) != paceAny {
		t.Fatalf("a redial after a drop ranks %d, want %d", paceRankFor(tu.tag, tu.lane, tu.made), paceAny)
	}
	tu.dialed(true)
	kickRelays()
	if !tu.take(ctx) || paceRankFor(tu.tag, tu.lane, tu.made) != paceFirst {
		t.Fatalf("a redial at the phone's kick ranks %d, want %d", paceRankFor(tu.tag, tu.lane, tu.made), paceFirst)
	}
}

// redials with no rank go in a drawn order, not the order they came
func TestPaceDrawsTheOrderOfRedials(t *testing.T) {
	u := paceStore(t)
	paceWith(t, 3*time.Millisecond, 0)
	var ts []*paceTicket
	for range 12 {
		ts = append(ts, paceJoin(paceLane, u, paceAny))
	}
	first := paceJoin(paceLane, u, paceRest)
	at := paceGrants(t, append(ts, first))
	// the first went at once into the empty line, a ranked one next
	for i := 1; i < len(ts); i++ {
		if !at[12].Before(at[i]) {
			t.Fatalf("a ranked socket went after redial %d", i)
		}
	}
	inOrder := true
	for i := 2; i < len(ts); i++ {
		if at[i].Before(at[i-1]) {
			inOrder = false
		}
	}
	if inOrder {
		t.Fatal("eleven redials had their places in the order they came")
	}
}
