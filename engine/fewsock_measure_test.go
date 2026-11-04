// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what n subscriptions cost the relays: sockets, reqs by kind, the most
// addresses one req names, what relay-live's per-socket budget (10/s, burst
// 200; 2/s, burst 100 before 0.6) would refuse, and whether every stored
// wrap still comes in. one in ten chats is hidden, at least one. at the
// start, after a kick, and after every socket was dropped at once. slow, so
// only on request:
//
//	HALO_RELAY_MEASURE=1 go test -run TestMeasureSockets -v -timeout 30m . | grep '^FS'
//
// FS_N (3,15,20,50) and FS_SPREAD (3s, the turns' width) change it.

import (
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"
)

type fsBucket struct {
	tokens, max, perSec float64
	last                time.Time
}

func (b *fsBucket) take(now time.Time) bool {
	b.tokens += now.Sub(b.last).Seconds() * b.perSec
	if b.tokens > b.max {
		b.tokens = b.max
	}
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

type fsCount struct {
	conns, reqs, stored, live, pages, ids, probes, maxPerConn, maxAddrs, refused, refusedOld int
}

func fsTally(conns []siConn) fsCount {
	var s fsCount
	s.conns = len(conns)
	for _, c := range conns {
		s.reqs += len(c.reqs)
		s.maxPerConn = max(s.maxPerConn, len(c.reqs))
		// relay-live makes a fresh budget per websocket
		b := &fsBucket{tokens: 200, max: 200, perSec: 10, last: c.opened}
		old := &fsBucket{tokens: 100, max: 100, perSec: 2, last: c.opened}
		for _, r := range c.reqs {
			f := r.filter
			s.maxAddrs = max(s.maxAddrs, len(f.Tags["p"]))
			switch {
			case f.LimitZero && f.Since != 0:
				s.probes++
			case f.LimitZero:
				s.live++
			case len(f.IDs) > 0:
				s.ids++
			case f.Until != 0:
				s.pages++
			default:
				s.stored++
			}
			if !b.take(r.at) {
				s.refused++
			}
			if !old.take(r.at) {
				s.refusedOld++
			}
		}
	}
	return s
}

func fsOpen(conns []siConn) int {
	n := 0
	for _, c := range conns {
		if c.closed.IsZero() {
			n++
		}
	}
	return n
}

func fsSince(conns []siConn, at time.Time) []siConn {
	var out []siConn
	for _, c := range conns {
		if !c.opened.Before(at) {
			out = append(out, c)
		}
	}
	return out
}

// no new req on any relay for quiet
func fsSettle(rs []*relayStandIn, quiet, most time.Duration) {
	end := time.Now().Add(most)
	last, stable := -1, time.Now()
	for time.Now().Before(end) {
		n := 0
		for _, r := range rs {
			for _, c := range r.snapshot() {
				n += len(c.reqs)
			}
		}
		if n != last {
			last, stable = n, time.Now()
		} else if time.Since(stable) >= quiet {
			return
		}
		time.Sleep(200 * time.Millisecond)
	}
}

// the inbox lines for each tag, by body
func fsInbox() map[string]map[string]bool {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	out := map[string]map[string]bool{}
	for _, l := range nostrInbox {
		tag, body, _ := strings.Cut(l, "|")
		if out[tag] == nil {
			out[tag] = map[string]bool{}
		}
		out[tag][body] = true
	}
	return out
}

func TestMeasureSockets(t *testing.T) {
	if os.Getenv("HALO_RELAY_MEASURE") == "" {
		t.Skip("HALO_RELAY_MEASURE not set")
	}
	ns := []int{3, 15, 20, 50}
	if s := os.Getenv("FS_N"); s != "" {
		ns = nil
		for _, v := range strings.Split(s, ",") {
			n, _ := strconv.Atoi(v)
			ns = append(ns, n)
		}
	}
	spread := 3 * time.Second
	if s := os.Getenv("FS_SPREAD"); s != "" {
		spread, _ = time.ParseDuration(s)
	}
	for _, n := range ns {
		t.Run(strconv.Itoa(n), func(t *testing.T) {
			oldSpread, oldKick := subSpread, kickSpread
			subSpread, kickSpread = spread, spread
			t.Cleanup(func() { subSpread, kickSpread = oldSpread, oldKick })
			own, pub := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
			useStandIns(t, modeFast, nil, own, pub)
			freshInbox(t)
			freshBatches(t)
			type peerRow struct {
				hex string
				x   xid
				rcv string
			}
			var peers []peerRow
			var rcvs []string
			want := map[string]map[string]bool{}
			now := time.Now()
			for i := 0; i < n; i++ {
				p := newXid(t)
				row := peerRow{hex.EncodeToString(p.pub[:]), p, mustRcv(t, p)}
				peers = append(peers, row)
				rcvs = append(rcvs, row.rcv)
				want[row.hex] = map[string]bool{}
				// every tenth contact sent a photo: 250 slices on both relays,
				// the rest one line
				k := 1
				if i%10 == 0 {
					k = 250
				}
				for j := 0; j < k; j++ {
					body := "slice " + strconv.Itoa(j)
					ev := wrapToAt(t, p, myXPub, body, now.Add(-time.Duration(j)*time.Second))
					own.store(ev)
					pub.store(ev)
					want[row.hex][body] = true
				}
			}
			t.Cleanup(func() {
				nostrMu.Lock()
				for _, p := range peers {
					if c, ok := nostrSubs[p.hex]; ok {
						c()
						delete(nostrSubs, p.hex)
					}
				}
				nostrMu.Unlock()
			})
			allIn := func() bool {
				got := fsInbox()
				for tag, bodies := range want {
					for b := range bodies {
						if !got[tag][b] {
							return false
						}
					}
				}
				return true
			}
			// past the public cap an address reads the public relay now and
			// then, so only ours has them all live
			listening := func() bool {
				a := own.listening()
				for _, p := range rcvs {
					if a[p] == 0 {
						return false
					}
				}
				return true
			}
			pubLive := func() int {
				b, k := pub.listening(), 0
				for _, p := range rcvs {
					if b[p] > 0 {
						k++
					}
				}
				return k
			}
			wait := func(what string, from time.Time, cond func() bool) time.Duration {
				end := time.Now().Add(spread + 3*time.Minute)
				for time.Now().Before(end) {
					if cond() {
						return time.Since(from)
					}
					time.Sleep(50 * time.Millisecond)
				}
				t.Fatalf("n=%d: %s not after %s", n, what, time.Since(from))
				return 0
			}
			// one in ten hidden, at least one: the last ones
			hidden := map[string]bool{}
			for i := 0; i < max(1, n/10); i++ {
				hidden[peers[n-1-i].rcv] = true
			}
			start := time.Now()
			for _, p := range peers {
				if r := nostrSubscribeAs(mainIdent, p.hex, false, hidden[p.rcv]); r != "ok" {
					t.Fatal(r)
				}
			}
			heard := wait("all listening", start, listening)
			caught := wait("every stored wrap in", start, allIn)
			fsSettle([]*relayStandIn{own, pub}, 3*time.Second, 2*time.Minute)
			for _, r := range []struct {
				name string
				s    *relayStandIn
			}{{"own", own}, {"pub", pub}} {
				c := r.s.snapshot()
				s := fsTally(c)
				// open sockets that carry a hidden chat, and the most
				// addresses one socket carries
				hid, most := 0, 0
				for _, k := range c {
					if !k.closed.IsZero() {
						continue
					}
					most = max(most, len(k.addrs))
					for a := range k.addrs {
						if hidden[a] {
							hid++
							if len(k.addrs) > 1 {
								t.Fatalf("n=%d: a hidden chat shares a socket with %d others", n, len(k.addrs)-1)
							}
							break
						}
					}
				}
				fmt.Printf("FS start n=%d hidden=%d pubLive=%d relay=%s open=%d hiddenSockets=%d maxAddrsPerSocket=%d dials=%d reqs=%d stored=%d live=%d pages=%d ids=%d probes=%d maxReqsPerSocket=%d maxAddrsPerReq=%d refused=%d refusedOld=%d allListening=%s allIn=%s\n",
					n, len(hidden), pubLive(), r.name, fsOpen(c), hid, most, s.conns, s.reqs, s.stored, s.live, s.pages, s.ids, s.probes, s.maxPerConn, s.maxAddrs, s.refused, s.refusedOld,
					heard.Round(10*time.Millisecond), caught.Round(10*time.Millisecond))
			}

			// a kick: every live socket probes after its own delay
			kickAt := time.Now()
			kickRelays()
			time.Sleep(spread + 2*time.Second)
			for _, r := range []struct {
				name string
				s    *relayStandIn
			}{{"own", own}, {"pub", pub}} {
				probes, socks := 0, 0
				for _, c := range r.s.snapshot() {
					k := 0
					for _, q := range c.reqs {
						if !q.at.Before(kickAt) && q.filter.LimitZero && q.filter.Since != 0 {
							k++
						}
					}
					probes += k
					if k > 0 {
						socks++
					}
				}
				fmt.Printf("FS kick n=%d relay=%s probes=%d onSockets=%d newSockets=%d\n",
					n, r.name, probes, socks, len(fsSince(r.s.snapshot(), kickAt)))
			}

			// every socket dropped at once, as when a circuit dies. a tenth
			// of the contacts write while nobody listens
			dropAt := time.Now()
			own.dropAll()
			pub.dropAll()
			for i := 0; i < n; i += 10 {
				p := peers[i]
				for j := 0; j < 3; j++ {
					body := "while down " + strconv.Itoa(j)
					ev := wrapToAt(t, p.x, myXPub, body, time.Now().Add(-time.Duration(j)*time.Hour))
					own.store(ev)
					pub.store(ev)
					want[p.hex][body] = true
				}
			}
			heard = wait("all listening again", dropAt, listening)
			caught = wait("every wrap in again", dropAt, allIn)
			fsSettle([]*relayStandIn{own, pub}, 3*time.Second, 2*time.Minute)
			for _, r := range []struct {
				name string
				s    *relayStandIn
			}{{"own", own}, {"pub", pub}} {
				fresh := fsSince(r.s.snapshot(), dropAt)
				s := fsTally(fresh)
				fmt.Printf("FS redial n=%d relay=%s open=%d dials=%d reqs=%d stored=%d live=%d pages=%d ids=%d probes=%d maxReqsPerSocket=%d maxAddrsPerReq=%d refused=%d refusedOld=%d allListening=%s allIn=%s\n",
					n, r.name, fsOpen(fresh), s.conns, s.reqs, s.stored, s.live, s.pages, s.ids, s.probes, s.maxPerConn, s.maxAddrs, s.refused, s.refusedOld,
					heard.Round(10*time.Millisecond), caught.Round(10*time.Millisecond))
			}

			// a wrap sent live to each address reaches the inbox
			liveAt := time.Now()
			for _, p := range peers {
				body := "live"
				ev := wrapToAt(t, p.x, myXPub, body, time.Now().Add(-2*time.Hour))
				own.pushLive(ev)
				want[p.hex][body] = true
			}
			fmt.Printf("FS live n=%d allIn=%s\n", n, wait("every live wrap in", liveAt, allIn).Round(10*time.Millisecond))
		})
	}
}
