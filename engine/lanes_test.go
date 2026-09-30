// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

// an https service of ours as tor reaches it: answers yes to everything and
// remembers where each request came from
type serviceStandIn struct {
	srv *httptest.Server
	mu  sync.Mutex
	rem []string
}

func newServiceStandIn(t *testing.T) *serviceStandIn {
	s := &serviceStandIn{}
	s.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		s.mu.Lock()
		s.rem = append(s.rem, r.RemoteAddr)
		s.mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"ok":true,"free":true,"results":[]}`))
	}))
	t.Cleanup(s.srv.Close)
	return s
}

func (s *serviceStandIn) remotes() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]string(nil), s.rem...)
}

// the ids a connection sends start at 1 on every connection, so no relay can
// line up two connections by where a shared counter had got to.
func TestSubscriptionIDsPerConnection(t *testing.T) {
	a := newRelayStandIn(t, 0)
	b := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, a, b)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	l := startLanes(t, ctx, 3, 1)
	subs := l.subs()
	listening := func(conns []siConn) int {
		n := 0
		for _, c := range conns {
			if c.closed.IsZero() && len(c.subIDs) > 0 {
				n++
			}
		}
		return n
	}
	for _, r := range []*relayStandIn{a, b} {
		waitFor(t, "every subscription connected", 15*time.Second, func() bool {
			return listening(r.snapshot()) == subs
		})
	}
	// a kick makes every live socket ask its relay a question first, which
	// is a second request on the same connection. the spread is cut short
	// here, what it does is tested on its own
	oldSpread := kickSpread
	kickSpread = time.Second
	defer func() { kickSpread = oldSpread }()
	kickRelays()
	for _, r := range []*relayStandIn{a, b} {
		waitFor(t, "every socket asked", 15*time.Second, func() bool {
			for _, c := range r.snapshot() {
				if c.closed.IsZero() && len(c.subIDs) < 2 {
					return false
				}
			}
			return true
		})
	}
	// the relay drops everyone, and every runner comes back on a new connection
	before := len(a.snapshot())
	a.dropAll()
	waitFor(t, "every subscription back", 20*time.Second, func() bool {
		return listening(a.snapshot()[before:]) == subs
	})

	for name, r := range map[string]*relayStandIn{"a": a, "b": b} {
		conns := r.snapshot()
		if len(conns) < subs {
			t.Fatalf("relay %s saw %d connections for %d subscriptions", name, len(conns), subs)
		}
		for i, c := range conns {
			if len(c.subIDs) == 0 {
				continue
			}
			if c.subIDs[0] != "1:" {
				t.Errorf("relay %s connection %d opened with id %q, want 1:", name, i, c.subIDs[0])
			}
			got := append([]string(nil), c.subIDs...)
			sort.Slice(got, func(x, y int) bool {
				nx, _ := strconv.Atoi(strings.TrimSuffix(got[x], ":"))
				ny, _ := strconv.Atoi(strings.TrimSuffix(got[y], ":"))
				return nx < ny
			})
			for j, id := range got {
				if want := strconv.Itoa(j+1) + ":"; id != want {
					t.Errorf("relay %s connection %d sent ids %v, want 1: to %d: with none skipped",
						name, i, c.subIDs, len(got))
					break
				}
			}
		}
	}
}

// every lane dials under its own socks name: the main identity's contacts
// listen on a few lanes by a hash of the address, its first-contact address
// on one of its own and its sends go on another, each room has its own, a
// pair code has its own, the registry, search and badge calls share one of
// their own, and nothing reaches a relay or a service without one.
func TestLanesDialUnderTheirOwnSocksName(t *testing.T) {
	socks := newSocksStandIn(t)
	a := newRelayStandIn(t, 0)
	b := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, a, b)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	l := startLanes(t, ctx, 2, 2)
	subs := l.subs()
	for _, r := range []*relayStandIn{a, b} {
		waitFor(t, "every subscription connected", 15*time.Second, func() bool {
			n := 0
			for _, c := range r.snapshot() {
				if len(c.subIDs) > 0 {
					n++
				}
			}
			return n == subs
		})
	}

	// one send of each kind, as the exports make them
	friend := newXid(t)
	me, err := myXid()
	if err != nil {
		t.Fatal(err)
	}
	ev := wrapTo(t, me, friend.pub, "hi")
	everydaySent := ev.Tags.Find("p")[1]
	if nostrPublishMulti(ctx, laneEveryday, ev) == 0 {
		t.Fatal("everyday send not accepted")
	}
	member := newXid(t)
	rk := l.roomKeys[0]
	gw, err := nip17WrapAs(rk, member.pub, "hi room")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := publishWrap(roomLane(hex.EncodeToString(rk.pub[:])), gw); err != nil {
		t.Fatal(err)
	}
	roomSent := gw.Tags.Find("p")[1]
	_, pairPk, err := pairCodeKeys("482913")
	if err != nil {
		t.Fatal(err)
	}
	qctx, qcancel := context.WithTimeout(ctx, 2*time.Second)
	pairCodeQuery(qctx, pairPk)
	qcancel()
	waitFor(t, "both sends on both relays", 15*time.Second, func() bool {
		for _, r := range []*relayStandIn{a, b} {
			conns := r.snapshot()
			if len(connsOn(conns, []string{everydaySent})) == 0 ||
				len(connsOn(conns, []string{roomSent})) == 0 ||
				len(connsOn(conns, []string{pairPk})) == 0 {
				return false
			}
		}
		return true
	})

	lanes := map[string][]string{
		"sends":         {everydaySent},
		"first contact": {l.fc},
		"room 1":        append(append([]string(nil), l.rooms[0]...), roomSent),
		"room 2":        l.rooms[1],
		"pair":          {pairPk},
	}
	for _, a := range l.contacts {
		k := "contacts on " + receiveLane(a)
		lanes[k] = append(lanes[k], a)
	}
	nameOfLane := map[string]string{}
	laneOfName := map[string]string{}
	seen := 0
	for _, r := range []*relayStandIn{a, b} {
		conns := r.snapshot()
		for lane, addrs := range lanes {
			for _, c := range connsOn(conns, addrs) {
				seen++
				n, ok := socks.nameOf(c.remote)
				if !ok {
					t.Fatalf("%s reached the relay without going through socks", lane)
				}
				if n == "" {
					t.Fatalf("%s went through socks without a name, sharing circuits with anything else unnamed", lane)
				}
				if prev, ok := nameOfLane[lane]; ok && prev != n {
					t.Errorf("%s dialled under two names, so it is split over circuits", lane)
				}
				nameOfLane[lane] = n
				if other, ok := laneOfName[n]; ok && other != lane {
					t.Fatalf("%s and %s dialled under one socks name and can share a circuit", lane, other)
				}
				laneOfName[n] = lane
			}
		}
		for _, c := range conns {
			if _, ok := socks.nameOf(c.remote); !ok {
				t.Fatalf("a connection reached the relay without going through socks")
			}
		}
	}
	if len(nameOfLane) != len(lanes) {
		t.Fatalf("names for %d lanes, want %d: %v", len(nameOfLane), len(lanes), nameOfLane)
	}
	total := len(a.snapshot()) + len(b.snapshot())
	if seen != total {
		t.Fatalf("%d of %d connections belong to a lane", seen, total)
	}
	for lane, n := range nameOfLane {
		if strings.Contains(n, "room") || strings.Contains(n, "pair") || strings.Contains(n, "everyday") ||
			strings.Contains(n, "first") {
			t.Errorf("%s's socks name says what it is: %q", lane, n)
		}
	}

	// the registry, people search and the badge service, as the app calls them
	svc := newServiceStandIn(t)
	oldBase := handleBase
	handleBase = svc.srv.URL
	defer func() { handleBase = oldBase }()
	_, edPriv, _ := ed25519.GenerateKey(nil)
	mu.Lock()
	oldEd := myEdPriv
	myEdPriv = edPriv
	mu.Unlock()
	defer func() {
		mu.Lock()
		myEdPriv = oldEd
		mu.Unlock()
	}()
	for what, r := range map[string]string{
		"check":   handleCheck("wren"),
		"claim":   handleClaim("wren", "kryfo://share?id=a-b-c", ""),
		"release": handleRelease("wren"),
		"search":  torPost(svc.srv.URL+"/handle/search", `{"q":"wren"}`),
		"badge":   torGetJSON(svc.srv.URL + "/receipt?id=1"),
	} {
		if strings.HasPrefix(r, "error") {
			t.Fatalf("%s: %s", what, r)
		}
	}
	remotes := svc.remotes()
	if len(remotes) == 0 {
		t.Fatal("no call reached the service")
	}
	var svcName string
	for _, rem := range remotes {
		n, ok := socks.nameOf(rem)
		if !ok {
			t.Fatal("a service call went out without going through socks")
		}
		if n == "" {
			t.Fatal("a service call went through socks without a name")
		}
		if svcName != "" && n != svcName {
			t.Error("the service calls dialled under more than one name")
		}
		svcName = n
	}
	if lane, ok := laneOfName[svcName]; ok {
		t.Fatalf("the service calls share a socks name with %s", lane)
	}

	// a room that is gone takes its name with it
	gone := roomLane(hex.EncodeToString(l.roomKeys[1].pub[:]))
	was := laneName(gone)
	dropLane(gone)
	if laneName(gone) == was {
		t.Error("a room that was dropped kept its socks name")
	}
}

// a contact's address keeps its lane, and the addresses fill all of them
func TestReceiveLanesByHash(t *testing.T) {
	// the first four bytes of sha256, big-endian, mod 4, as measured
	for a, want := range map[string]string{
		fmt.Sprintf("%064x", 1): "everyday:0",
		fmt.Sprintf("%064x", 0): "everyday:1",
		strings.Repeat("a", 64): "everyday:2",
		fmt.Sprintf("%064x", 3): "everyday:3",
	} {
		if got := receiveLane(a); got != want {
			t.Errorf("...%s on %s, want %s", a[56:], got, want)
		}
	}
	seen := map[string]int{}
	for i := 0; i < 400; i++ {
		a := fmt.Sprintf("%064x", i)
		l := receiveLane(a)
		if receiveLane(a) != l {
			t.Fatal("an address moved lanes")
		}
		if l == laneEveryday || l == laneFirstContact || laneKind(l) != laneEveryday {
			t.Fatalf("a contact's address on lane %q", l)
		}
		seen[l]++
	}
	if len(seen) != receiveLaneCount {
		t.Fatalf("%d lanes in use, want %d: %v", len(seen), receiveLaneCount, seen)
	}
	for l, n := range seen {
		if n < 50 {
			t.Errorf("lane %s has %d of 400 addresses", l, n)
		}
	}
}

// contacts until every receive lane has one and one lane has two
func contactsOnEveryLane(t *testing.T) map[string][]xid {
	t.Helper()
	byLane := map[string][]xid{}
	two := false
	for i := 0; len(byLane) < receiveLaneCount || !two; i++ {
		if i == 1000 {
			t.Fatalf("a thousand contacts on %d receive lanes", len(byLane))
		}
		p := newXid(t)
		l := receiveLane(mustRcv(t, p))
		if n := len(byLane[l]); n == 2 || (n == 1 && two) {
			continue
		}
		byLane[l] = append(byLane[l], p)
		two = two || len(byLane[l]) == 2
	}
	return byLane
}

// the main identity on all its lanes at once: the addresses of one receive
// lane share its socks name, and no other receive lane, the first-contact
// address or a send dials under it. the first-contact address and the sends
// each have a name nothing else uses.
func TestReceiveLanesDialApart(t *testing.T) {
	socks := newSocksStandIn(t)
	r := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, r)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	groups := map[string][]string{}
	for lane, peers := range contactsOnEveryLane(t) {
		for _, p := range peers {
			rcv := mustRcv(t, p)
			groups[lane] = append(groups[lane], rcv)
			go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), p.pub, rcv)
		}
	}
	_, fcPk, err := nip17FirstContactKeys(0)
	if err != nil {
		t.Fatal(err)
	}
	var zero [32]byte
	go nostrSubscribeRunnerMode(ctx, "firstcontact", zero, fcPk, true, 0)
	groups[laneFirstContact] = []string{fcPk}
	subs := 0
	for _, addrs := range groups {
		subs += len(addrs)
	}
	waitFor(t, "every subscription connected", 15*time.Second, func() bool {
		n := 0
		for _, c := range r.snapshot() {
			if len(c.subIDs) > 0 {
				n++
			}
		}
		return n == subs
	})

	// through the app's own send paths, so their lane choice is what is checked
	peer := newXid(t)
	peerHex := hex.EncodeToString(peer.pub[:])
	if res := nostrSend(peerHex, "hi"); res != "ok" {
		t.Fatalf("send: %s", res)
	}
	_, sent, err := nip17DeriveRole(peer.pub, nip17RcvInfo, peerHex)
	if err != nil {
		t.Fatal(err)
	}
	stranger := newXid(t)
	_, strangerFc, err := fcKeysFrom(stranger.priv, 0)
	if err != nil {
		t.Fatal(err)
	}
	if res := nostrSendFirstContact(hex.EncodeToString(stranger.pub[:]), strangerFc, "hi"); res != "ok" {
		t.Fatalf("first-contact send: %s", res)
	}
	waitFor(t, "the sends on the relay", 15*time.Second, func() bool {
		c := r.snapshot()
		return len(connsOn(c, []string{sent})) > 0 && len(connsOn(c, []string{strangerFc})) > 0
	})
	groups[laneEveryday] = []string{sent, strangerFc}

	conns := r.snapshot()
	laneOf := map[string]string{}
	seen := 0
	for lane, addrs := range groups {
		for _, a := range addrs {
			on := connsOn(conns, []string{a})
			if len(on) == 0 {
				t.Fatalf("an address of %s never reached the relay", lane)
			}
			for _, c := range on {
				seen++
				n, ok := socks.nameOf(c.remote)
				if !ok || n == "" {
					t.Fatalf("%s reached the relay without a socks name", lane)
				}
				if n != laneName(lane) {
					t.Errorf("%s dialled under a name that is not its own", lane)
				}
				if other, ok := laneOf[n]; ok && other != lane {
					t.Fatalf("%s and %s dialled under one socks name and can share a circuit", lane, other)
				}
				laneOf[n] = lane
			}
		}
	}
	if want := receiveLaneCount + 2; len(laneOf) != want {
		t.Fatalf("%d socks names for the main identity, want %d: %v", len(laneOf), want, laneOf)
	}
	if seen != len(conns) {
		t.Fatalf("%d of %d connections belong to the main identity's lanes", seen, len(conns))
	}
}

func TestSubscribeOptionsByMode(t *testing.T) {
	old := currentMode()
	defer transportMode.Store(old)
	for _, m := range []string{modeBalanced, modeFast} {
		transportMode.Store(m)
		if o := subscribeRelayOptions(); o.PingInterval != 0 || o.PongTimeout != 0 {
			t.Errorf("%s mode changed the library's ping: %s / %s", m, o.PingInterval, o.PongTimeout)
		}
	}
	transportMode.Store(modePrivate)
	o := subscribeRelayOptions()
	if o.PingInterval != 90*time.Second || o.PongTimeout != 20*time.Second {
		t.Errorf("private mode pings every %s with %s for the pong, want 90s and 20s", o.PingInterval, o.PongTimeout)
	}
}

// a relay whose pong takes 1.2s, the way an onion relay's often does. the
// ping and pong wait are scaled down here; the real ones are checked above.
func slowPongRun(t *testing.T, interval, pongWait time.Duration, until func(conns []siConn) bool) (conns []siConn, resent int) {
	t.Helper()
	oldI, oldW := torPingInterval, torPongTimeout
	torPingInterval, torPongTimeout = interval, pongWait
	t.Cleanup(func() { torPingInterval, torPongTimeout = oldI, oldW })
	socks := newSocksStandIn(t)
	r := newRelayStandIn(t, 1200*time.Millisecond)
	useStandIns(t, modePrivate, socks, r)
	peer := newXid(t)
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 5; i++ {
		r.store(wrapTo(t, peer, myXPub, fmt.Sprintf("stored %d", i)))
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, rcv)
	waitFor(t, "pings at the set interval", 30*time.Second, func() bool { return until(r.snapshot()) })
	r.mu.Lock()
	resent = r.resent
	r.mu.Unlock()
	return r.snapshot(), resent
}

func mustRcv(t *testing.T, peer xid) string {
	t.Helper()
	_, rcv, err := nip17RcvAddress(peer.pub)
	if err != nil {
		t.Fatal(err)
	}
	return rcv
}

func pings(conns []siConn) int {
	n := 0
	for _, c := range conns {
		n += len(c.pings)
	}
	return n
}

func TestSlowPongKeepsTheSocket(t *testing.T) {
	conns, resent := slowPongRun(t, time.Second, 3*time.Second, func(c []siConn) bool { return pings(c) >= 5 })
	if len(conns) != 1 || !conns[0].closed.IsZero() {
		t.Fatalf("%d connections, want the first one still open", len(conns))
	}
	if len(conns[0].subIDs) != 1 || resent != 5 {
		t.Fatalf("%d requests and %d stored events sent, want the one window once", len(conns[0].subIDs), resent)
	}
	p := conns[0].pings
	for i := 1; i < len(p); i++ {
		if gap := p[i].Sub(p[i-1]); gap < 900*time.Millisecond || gap > 3*time.Second {
			t.Errorf("ping %d came %s after the one before, want the set interval", i, gap)
		}
	}
}

// the same relay with a pong wait shorter than its pong: three late pongs
// close the socket and the window is fetched again. this is what 800ms did
// over tor.
func TestShortPongWaitClosesTheSocket(t *testing.T) {
	conns, resent := slowPongRun(t, time.Second, 500*time.Millisecond, func(c []siConn) bool {
		n := 0
		for _, x := range c {
			n += len(x.subIDs)
		}
		return n >= 2
	})
	if len(conns) < 2 || conns[0].closed.IsZero() {
		t.Fatalf("%d connections, want the first closed and a second", len(conns))
	}
	if resent <= 5 {
		t.Fatalf("%d stored events sent, want the window sent again", resent)
	}
}

// balanced and fast have no tor: one client for every lane, as before, and
// nothing goes near the socks port even when one is there.
func TestDirectModesUnchanged(t *testing.T) {
	for _, m := range []string{modeBalanced, modeFast} {
		t.Run(m, func(t *testing.T) {
			socks := newSocksStandIn(t)
			r := newRelayStandIn(t, 0)
			useStandIns(t, m, socks, r)
			c1, err := torNostrClientFor(laneEveryday)
			if err != nil {
				t.Fatal(err)
			}
			for _, lane := range append(mainLanes(), roomLane("ab"), pairLane("cd"), laneServices) {
				c, err := torNostrClientFor(lane)
				if err != nil {
					t.Fatal(err)
				}
				if c != c1 {
					t.Fatalf("%s got its own client without tor", laneKind(lane))
				}
			}
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			l := startLanes(t, ctx, 1, 1)
			waitFor(t, "connected", 15*time.Second, func() bool {
				n := 0
				for _, c := range r.snapshot() {
					if len(c.subIDs) > 0 {
						n++
					}
				}
				return n == l.subs()
			})
			if n := socks.count(); n != 0 {
				t.Fatalf("%d streams went through socks in %s mode", n, m)
			}
		})
	}
}

// before and after, with the real intervals. slow, so only on request:
//
//	HALO_RELAY_MEASURE=1 go test -run TestMeasureKeepalive -v -timeout 20m .
func TestMeasureKeepalive(t *testing.T) {
	if os.Getenv("HALO_RELAY_MEASURE") == "" {
		t.Skip("HALO_RELAY_MEASURE not set")
	}
	window := 190 * time.Second
	if v := os.Getenv("HALO_RELAY_WINDOW"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			window = d
		}
	}
	for _, run := range []struct {
		name string
		mode string
	}{
		{"before (library defaults)", modeFast},
		{"after (private mode)", modePrivate},
	} {
		t.Run(run.mode, func(t *testing.T) {
			var socks *socksStandIn
			if run.mode == modePrivate {
				socks = newSocksStandIn(t)
			}
			quick := newRelayStandIn(t, 0)
			slow := newRelayStandIn(t, 1200*time.Millisecond)
			useStandIns(t, run.mode, socks, quick, slow)
			// ten media-sized slices from one contact, what a reconnect fetches again
			me := myXPub
			peer := newXid(t)
			for i := 0; i < 10; i++ {
				ev := wrapTo(t, peer, me, strings.Repeat("m", 12000))
				quick.store(ev)
				slow.store(ev)
			}
			ctx, cancel := context.WithCancel(context.Background())
			go nostrSubscribeRunner(ctx, hex.EncodeToString(peer.pub[:]), peer.pub, mustRcv(t, peer))
			l := startLanes(t, ctx, 3, 1)
			time.Sleep(window)
			cancel()
			subs := l.subs() + 1
			for name, r := range map[string]*relayStandIn{"pong at once": quick, "pong after 1.2s": slow} {
				conns := r.snapshot()
				var gaps []time.Duration
				reqs := 0
				for _, c := range conns {
					reqs += len(c.subIDs)
					for i := 1; i < len(c.pings); i++ {
						gaps = append(gaps, c.pings[i].Sub(c.pings[i-1]))
					}
				}
				var mean time.Duration
				for _, g := range gaps {
					mean += g
				}
				if len(gaps) > 0 {
					mean /= time.Duration(len(gaps))
				}
				r.mu.Lock()
				resent, resentB := r.resent, r.resentB
				r.mu.Unlock()
				t.Logf("%s, %s, %d subscriptions over %s: %d sockets opened, %d pings (%.1f per socket per hour, mean gap %s), %d requests, %d stored events sent (%d KB)",
					run.name, name, subs, window, len(conns), pings(conns),
					float64(pings(conns))/float64(subs)/window.Hours(), mean.Round(100*time.Millisecond),
					reqs, resent, resentB/1024)
			}
		})
	}
}

// a new first-contact address, after a reset of the invite, listens under a
// socks name the old one never used
func TestNewFirstContactAddressGetsANewCircuit(t *testing.T) {
	socks := newSocksStandIn(t)
	r := newRelayStandIn(t, 0)
	useStandIns(t, modePrivate, socks, r)
	t.Cleanup(func() {
		nostrMu.Lock()
		if cancel, ok := nostrSubs["firstcontact"]; ok {
			cancel()
			delete(nostrSubs, "firstcontact")
		}
		nostrMu.Unlock()
	})

	nameFor := func(counter int) string {
		t.Helper()
		if err := subscribeFirstContact(counter); err != nil {
			t.Fatal(err)
		}
		_, fcPk, err := nip17FirstContactKeys(counter)
		if err != nil {
			t.Fatal(err)
		}
		var name string
		waitFor(t, "the first-contact address on the relay", 15*time.Second, func() bool {
			for _, c := range connsOn(r.snapshot(), []string{fcPk}) {
				if n, ok := socks.nameOf(c.remote); ok && n != "" {
					name = n
					return true
				}
			}
			return false
		})
		return name
	}
	before := nameFor(0)
	after := nameFor(1)
	if before == after {
		t.Fatal("the new first-contact address dialled under the old one's socks name")
	}
	if after != laneName(laneFirstContact) {
		t.Error("the new first-contact address is not on the first-contact lane")
	}
}
