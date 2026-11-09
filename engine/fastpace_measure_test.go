// SPDX-License-Identifier: GPL-3.0-or-later
package main

// new tcp connections from the phone in fast mode: at the start, after every
// socket was dropped at once, and after a drop the app answers with a kick
// (the network came back). two stores and a public relay reached in the
// clear, n contacts. slow, so only on request:
//
//	HALO_PACE_MEASURE=1 go test -run TestMeasureFastPace -v -timeout 30m .
//
// KRYFO_PACE_N (150) changes the contact count.

import (
	"encoding/hex"
	"io"
	"log"
	"os"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"
)

// the most of ts inside any window w
func paceMost(ts []time.Time, w time.Duration) int {
	sort.Slice(ts, func(i, j int) bool { return ts[i].Before(ts[j]) })
	most, j := 0, 0
	for i := range ts {
		for ts[i].Sub(ts[j]) >= w {
			j++
		}
		most = max(most, i-j+1)
	}
	return most
}

func TestMeasureFastPace(t *testing.T) {
	if os.Getenv("HALO_PACE_MEASURE") == "" {
		t.Skip("HALO_PACE_MEASURE not set")
	}
	n := 150
	if v, err := strconv.Atoi(os.Getenv("KRYFO_PACE_N")); err == nil && v > 0 {
		n = v
	}
	log.SetOutput(io.Discard)
	defer log.SetOutput(os.Stderr)
	for _, how := range []string{"start", "drop", "drop+kick"} {
		t.Run(how, func(t *testing.T) {
			oldSpread := subSpread
			subSpread = time.Minute
			defer func() { subSpread = oldSpread }()
			paceForTest(t)
			a, b, p := newRelayStandIn(t, 0), newRelayStandIn(t, 0), newRelayStandIn(t, 0)
			useStandIns(t, modeBalanced, nil, a, b, p)
			old := secondRelayHost.get()
			secondRelayHost.put(strings.TrimPrefix(b.url(), "ws://"))
			clearTestHosts.Store(strings.ToLower(strings.TrimPrefix(p.url(), "ws://")), true)
			t.Cleanup(func() {
				runnersGone(t)
				secondRelayHost.put(old)
			})
			statusForTest(t, "reachable")
			routeNoteOK()
			freshInbox(t)
			freshBatches(t)
			freshStart(t)
			var tags []string
			want := map[string]bool{}
			for i := 0; i < n; i++ {
				x := newXid(t)
				tags = append(tags, hex.EncodeToString(x.pub[:]))
				want[mustRcv(t, x)] = true
			}
			// every address listens on both stores on a socket opened since from
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
			wait := func() {
				for until := time.Now().Add(4 * time.Minute); !all() && time.Now().Before(until); {
					time.Sleep(50 * time.Millisecond)
				}
			}
			start := time.Now()
			from = start
			for _, h := range tags {
				if r := nostrSubscribeAs(mainIdent, h, false, false); r != "ok" {
					t.Fatal(r)
				}
			}
			wait()
			back := time.Since(start)
			if how != "start" {
				fsSettle([]*relayStandIn{a, b, p}, 3*time.Second, time.Minute)
				from = time.Now()
				for _, r := range []*relayStandIn{a, b, p} {
					r.dropAll()
				}
				if how == "drop+kick" {
					time.Sleep(time.Second)
					nostrKick()
				}
				wait()
				back = time.Since(from)
			}
			if !all() {
				t.Errorf("not every address listens again after %v", back.Round(100*time.Millisecond))
			}
			time.Sleep(2 * time.Second)
			var ts []time.Time
			per := map[string]int{}
			for _, r := range []struct {
				name string
				s    *relayStandIn
			}{{"first", a}, {"second", b}, {"public", p}} {
				for _, c := range fsSince(r.s.snapshot(), from) {
					ts = append(ts, c.opened)
					per[r.name]++
				}
			}
			last := time.Duration(0)
			for _, x := range ts {
				last = max(last, x.Sub(from))
			}
			t.Logf("PACE %s n=%d: %d new tcp (first %d, second %d, public %d), most in 1 s %d, in 100 ms %d, last %v, every address listening after %v",
				how, n, len(ts), per["first"], per["second"], per["public"], paceMost(ts, time.Second), paceMost(ts, 100*time.Millisecond),
				last.Round(100*time.Millisecond), back.Round(100*time.Millisecond))
		})
	}
}

// the addresses that listen live on a socket of r opened since from
func listenSince(r *relayStandIn, from time.Time) map[string]bool {
	out := map[string]bool{}
	for _, c := range fsSince(r.snapshot(), from) {
		if !c.closed.IsZero() {
			continue
		}
		for _, q := range c.reqs {
			f := q.filter
			if c.closedIDs[q.id] || len(f.IDs) > 0 || f.Until != 0 || (f.LimitZero && f.Since != 0) {
				continue
			}
			for _, p := range f.Tags["p"] {
				out[p] = true
			}
		}
	}
	return out
}
