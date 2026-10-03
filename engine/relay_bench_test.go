// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// a relay that turns every socket away, the way a rate limit does
type refuserStandIn struct {
	srv *httptest.Server
	n   atomic.Int32
}

func newRefuserStandIn(t *testing.T) *refuserStandIn {
	r := &refuserStandIn{}
	r.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		r.n.Add(1)
		http.Error(w, "slow down", http.StatusTooManyRequests)
	}))
	t.Cleanup(r.srv.Close)
	return r
}

func (r *refuserStandIn) url() string { return "ws" + strings.TrimPrefix(r.srv.URL, "http") }

func benchLeft(u string) time.Duration {
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	till, ok := relayCoolTill[u]
	if !ok {
		return 0
	}
	if d := time.Until(till); d > 0 {
		return d
	}
	return 0
}

func failsOf(u string) int {
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	return relayFails[u]
}

func setFailBurst(t *testing.T, d time.Duration) {
	old := relayFailBurst
	relayFailBurst = d
	t.Cleanup(func() { relayFailBurst = old })
}

// thirty subscriptions turned away by one relay in the same moment are one
// failure: the relay is not benched, and each runner tries again at its
// usual pace rather than minutes later
func TestABurstOfRefusalsBenchesARelayAtMostOnce(t *testing.T) {
	own := newRelayStandIn(t, 0)
	pub := newRefuserStandIn(t)
	useStandIns(t, modeBalanced, nil, own)
	setRelays([]string{own.url(), pub.url()})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	for i := 0; i < 30; i++ {
		p := newXid(t)
		_, rcv, err := nip17RcvAddress(p.pub)
		if err != nil {
			t.Fatal(err)
		}
		go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), p.pub, rcv)
	}
	waitFor(t, "every socket turned away", 5*time.Second, func() bool { return pub.n.Load() >= 30 })
	time.Sleep(200 * time.Millisecond)

	if n := failsOf(pub.url()); n > 1 {
		t.Fatalf("one burst counted as %d failures", n)
	}
	if d := benchLeft(pub.url()); d > 0 {
		t.Fatalf("benched for %s after one burst", d.Round(time.Second))
	}
	if d := relayRetryAfter(pub.url(), 10*time.Second, false); d != 10*time.Second {
		t.Fatalf("runners wait %s, not their usual 10s", d)
	}
}

// attempts that began together count once however their failures spread:
// a dial that times out late was under way when the first one was counted.
// one begun after that count is a new failure.
func TestFailuresOfAttemptsBegunTogetherCountOnce(t *testing.T) {
	pub := newRefuserStandIn(t)
	useStandIns(t, modeBalanced, nil)
	setRelays([]string{"ws://own.invalid", pub.url()})
	u := pub.url()

	// failing a moment apart, each begun just before it failed
	for i := 0; i < 30; i++ {
		relayFailed(u, time.Now())
	}
	if n := failsOf(u); n != 1 {
		t.Fatalf("failures a moment apart counted as %d", n)
	}

	// begun together, failing far apart
	relayClearBenches()
	setFailBurst(t, 20*time.Millisecond)
	began := time.Now()
	relayFailed(u, began)
	for i := 0; i < 5; i++ {
		time.Sleep(40 * time.Millisecond)
		relayFailed(u, began)
	}
	if n := failsOf(u); n != 1 {
		t.Fatalf("attempts begun together counted as %d", n)
	}
	time.Sleep(40 * time.Millisecond)
	relayFailed(u, time.Now())
	if n := failsOf(u); n != 2 {
		t.Fatalf("a later attempt counted to %d, want 2", n)
	}
}

// with no way into our relay answering, failures that keep coming one after
// another bench its entries, the onion first in the list and its clearnet
// name, for its short ceiling only. a public relay still goes to five
// minutes.
func TestOurRelayIsNeverBenchedPastItsCeiling(t *testing.T) {
	useStandIns(t, modeBalanced, nil)
	old := ownRelayHost
	ownRelayHost = "own.example"
	t.Cleanup(func() { ownRelayHost = old })
	onion := "ws://ownrelayabc.onion"
	clear := "wss://own.example"
	pub := "wss://public.example"
	setRelays([]string{onion, clear, pub})
	setFailBurst(t, 0)

	for i := 0; i < 15; i++ {
		for _, u := range []string{onion, clear, pub} {
			relayFailed(u, time.Now())
		}
		for _, u := range []string{onion, clear} {
			if d := benchLeft(u); d > ownRelayCeiling {
				t.Fatalf("%s benched for %s after %d failures", u, d.Round(time.Second), i+1)
			}
			// a runner that holds the clearnet name second in its list
			// does not know it is ours
			if d := relayRetryAfter(u, 3*time.Second, false); d > ownRelayCeiling*6/5 {
				t.Fatalf("%s retried after %s after %d failures", u, d.Round(time.Second), i+1)
			}
		}
	}
	if d := benchLeft(pub); d < 4*time.Minute {
		t.Fatalf("a public relay failing 15 times in a row is benched for %s", d.Round(time.Second))
	}
}

// a public relay's failures one after another bench it as before: three
// are free, then ten seconds doubling to five minutes
func TestPublicRelayBenchScheduleUnchanged(t *testing.T) {
	useStandIns(t, modeBalanced, nil)
	pub := "wss://public.example"
	setRelays([]string{"ws://own.invalid", pub})
	setFailBurst(t, 20*time.Millisecond)

	want := []time.Duration{0, 0, 0, 10 * time.Second, 20 * time.Second, 40 * time.Second,
		80 * time.Second, 160 * time.Second, 300 * time.Second, 300 * time.Second, 300 * time.Second}
	for i, w := range want {
		time.Sleep(30 * time.Millisecond)
		relayFailed(pub, time.Now())
		got := benchLeft(pub)
		if got > w || got < w-time.Second {
			t.Fatalf("after %d failures benched for %s, want %s", i+1, got.Round(time.Second), w)
		}
		if r := relayRetryAfter(pub, 10*time.Second, false); r != max(w, 10*time.Second) {
			t.Fatalf("after %d failures retried after %s, want %s", i+1, r, max(w, 10*time.Second))
		}
	}
	relayOK(pub)
	if failsOf(pub) != 0 || benchLeft(pub) != 0 {
		t.Fatal("a success left the bench in place")
	}
}

// the sender's one way in is our relay's onion, and finding it takes longer
// than the old thirty seconds: the send waits for it and the wrap lands
func TestASendWaitsForASlowOnionDial(t *testing.T) {
	own := slowOnionOnly(t)
	peer := newXid(t)
	start := time.Now()
	res := nostrSend(hex.EncodeToString(peer.pub[:]), "hi")
	checkSlowOnionLanded(t, own, res, "ok", time.Since(start))
}

// the same for a pair code share: the sharer is told it is up
func TestAPairCodeShareWaitsForASlowOnionDial(t *testing.T) {
	own := slowOnionOnly(t)
	start := time.Now()
	res := pairCodePublish("482913", "kryfo://share?id=the-sharer")
	checkSlowOnionLanded(t, own, res, "ok", time.Since(start))
}

// private mode with our relay's onion behind a 41s dial and the only other
// relay turning every socket away
func slowOnionOnly(t *testing.T) *relayStandIn {
	t.Helper()
	if testing.Short() {
		t.Skip("waits out a 41s dial")
	}
	socks := newSocksStandIn(t)
	own := newRelayStandIn(t, 0)
	pub := newRefuserStandIn(t)
	useStandIns(t, modePrivate, socks)
	onion := "ownrelayslow.onion"
	socks.mu.Lock()
	socks.route[onion] = strings.TrimPrefix(own.url(), "ws://")
	socks.connectDelay = 41 * time.Second
	socks.mu.Unlock()
	setRelays([]string{"ws://" + onion, pub.url()})
	return own
}

func checkSlowOnionLanded(t *testing.T, own *relayStandIn, res, want string, took time.Duration) {
	t.Helper()
	if res != want {
		t.Fatalf("said %q after %s", res, took.Round(time.Second))
	}
	if took < 41*time.Second {
		t.Fatalf("landed after %s, before the dial could end", took)
	}
	own.mu.Lock()
	n := own.accepted
	own.mu.Unlock()
	if n != 1 {
		t.Fatalf("our relay took %d events", n)
	}
}

// a relay that keeps dropping fresh connections is waited out at our
// relay's short ceiling on every entry for it, whatever the runner's place
// in the list, while no other way in answers. a public relay still waits up
// to five minutes.
func TestOurRelayDroppingYoungWaitsItsCeiling(t *testing.T) {
	useStandIns(t, modeBalanced, nil)
	old := ownRelayHost
	ownRelayHost = "own.example"
	t.Cleanup(func() { ownRelayHost = old })
	onion := "ws://ownrelayabc.onion"
	clear := "wss://own.example"
	pub := "wss://public.example"
	setRelays([]string{onion, clear, pub})

	for _, u := range []string{onion, clear} {
		if d := youngDropWait(u, 5*time.Second, 10, false); d < ownRelayCeiling*4/5 || d > ownRelayCeiling*6/5 {
			t.Fatalf("%s waits %s after ten young drops", u, d)
		}
	}
	if d := youngDropWait(pub, 5*time.Second, 10, false); d != 5*time.Minute {
		t.Fatalf("a public relay waits %s after ten young drops", d)
	}
}

// a publish tries our relay's clearnet name even while it sits out a bench:
// with the onion first in the list turning it away, it is the way in
func TestAPublishTriesOurRelayWhileItIsBenched(t *testing.T) {
	first := newRefuserStandIn(t)
	clear := newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, nil)
	old := ownRelayHost
	ownRelayHost = strings.TrimPrefix(clear.url(), "ws://")
	t.Cleanup(func() { ownRelayHost = old })
	setRelays([]string{first.url(), clear.url()})
	relayHealthMu.Lock()
	relayFails[clear.url()] = 6
	relayCoolTill[clear.url()] = time.Now().Add(ownRelayCeiling)
	relayHealthMu.Unlock()

	me, err := myXid()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if n := nostrPublishMulti(ctx, laneEveryday, wrapTo(t, me, newXid(t).pub, "hi")); n == 0 {
		t.Fatal("the wrap went nowhere")
	}
}

// the clearnet name keeps failing over tor while the onion answers: nothing
// waits on the clearnet name, so it backs off to minutes like any relay.
// once the onion has not answered for a while it is back to seconds.
func TestOurClearnetNameBacksOffWhileTheOnionAnswers(t *testing.T) {
	onion := newRelayStandIn(t, 0)
	clear := newRefuserStandIn(t)
	useStandIns(t, modeBalanced, nil)
	old := ownRelayHost
	ownRelayHost = strings.TrimPrefix(clear.url(), "ws://")
	t.Cleanup(func() { ownRelayHost = old })
	setRelays([]string{onion.url(), clear.url()})

	ctx, cancel := context.WithCancel(context.Background())
	p := newXid(t)
	_, rcv, err := nip17RcvAddress(p.pub)
	if err != nil {
		t.Fatal(err)
	}
	go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), p.pub, rcv)
	waitFor(t, "the onion listening", 5*time.Second, func() bool {
		for _, c := range onion.snapshot() {
			if len(c.reqs) > 0 {
				return true
			}
		}
		return false
	})
	waitFor(t, "the clearnet name turned away", 5*time.Second, func() bool { return clear.n.Load() > 0 })
	cancel()

	setFailBurst(t, 0)
	for i := 0; i < 12; i++ {
		relayFailed(clear.url(), time.Now())
	}
	if d := benchLeft(clear.url()); d < 4*time.Minute {
		t.Fatalf("benched for %s while the onion answers", d.Round(time.Second))
	}
	if d := relayRetryAfter(clear.url(), 10*time.Second, false); d < 4*time.Minute {
		t.Fatalf("retried after %s while the onion answers", d.Round(time.Second))
	}
	if d := youngDropWait(clear.url(), 5*time.Second, 10, false); d < 4*time.Minute {
		t.Fatalf("young drops waited %s while the onion answers", d.Round(time.Second))
	}

	relayHealthMu.Lock()
	relayUpAt[onion.url()] = time.Now().Add(-ownUpRecent - time.Second)
	relayHealthMu.Unlock()
	if d := relayRetryAfter(clear.url(), 10*time.Second, false); d > ownRelayCeiling*6/5 {
		t.Fatalf("retried after %s with the onion long silent", d.Round(time.Second))
	}
}

// our relay's waits are spread a fifth either way, so its runners do not
// redial in step. a public relay's are not
func TestOurRelayWaitsAreSpread(t *testing.T) {
	useStandIns(t, modeBalanced, nil)
	onion := "ws://ownrelayabc.onion"
	pub := "wss://public.example"
	setRelays([]string{onion, pub})
	setFailBurst(t, 0)
	for i := 0; i < 15; i++ {
		relayFailed(onion, time.Now())
		relayFailed(pub, time.Now())
	}
	lo, hi := ownRelayCeiling*4/5, ownRelayCeiling*6/5
	retry := map[time.Duration]bool{}
	young := map[time.Duration]bool{}
	for i := 0; i < 200; i++ {
		r := relayRetryAfter(onion, 3*time.Second, true)
		y := youngDropWait(onion, 2*time.Second, 10, true)
		for _, d := range []time.Duration{r, y} {
			if d < lo || d > hi {
				t.Fatalf("a wait of %s, outside %s to %s", d, lo, hi)
			}
		}
		retry[r], young[y] = true, true
	}
	if len(retry) < 20 || len(young) < 20 {
		t.Fatalf("waits not spread: %d and %d distinct of 200", len(retry), len(young))
	}
	if d := relayRetryAfter(pub, 10*time.Second, false); d != 5*time.Minute {
		t.Fatalf("a public relay waits %s", d)
	}
	if d := youngDropWait(pub, 5*time.Second, 10, false); d != 5*time.Minute {
		t.Fatalf("a public relay waits %s after young drops", d)
	}
}
