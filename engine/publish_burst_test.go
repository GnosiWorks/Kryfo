// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"encoding/hex"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// a file sent the way media_send.dart sends it: slices wrapped one by one,
// a few in flight, each done at its first relay's ok. through the socks
// stand-in with tor's costs. slow, so only on request:
//
//	HALO_RELAY_MEASURE=1 go test -run TestMeasurePublishBurst -v -timeout 30m .
//
// HALO_PUB_INFLIGHT (5), HALO_PUB_SLICES (150), HALO_PUB_RATE (bytes a
// second per circuit, none by default) and HALO_PUB_RTT (1.2s) change it.
func TestMeasurePublishBurst(t *testing.T) {
	if os.Getenv("HALO_RELAY_MEASURE") == "" {
		t.Skip("HALO_RELAY_MEASURE not set")
	}
	num := func(k string, def int) int {
		if v, err := strconv.Atoi(os.Getenv(k)); err == nil {
			return v
		}
		return def
	}
	inflight := num("HALO_PUB_INFLIGHT", 5)
	slices := num("HALO_PUB_SLICES", 150)
	rate := num("HALO_PUB_RATE", 0)
	rtt := 1200 * time.Millisecond
	if d, err := time.ParseDuration(os.Getenv("HALO_PUB_RTT")); err == nil {
		rtt = d
	}
	r := measureBurst(t, burstRun{inflight: inflight, slices: slices, rate: rate, rtt: rtt})
	t.Logf("%d slices, %d in flight, rtt %s, rate %d B/s: %s", slices, inflight, rtt, rate, r)
}

type burstRun struct {
	inflight, slices, rate int
	rtt                    time.Duration
}

type burstResult struct {
	elapsed  time.Duration // until the last slice had its first ok
	landed   time.Duration // until every relay held every slice
	sockets  int           // websockets the relays saw
	streams  int           // socks streams opened
	failures int           // sends that came back with an error
	wrapB    int
}

func (r burstResult) String() string {
	return "all sent in " + r.elapsed.Round(100*time.Millisecond).String() +
		", on every relay in " + r.landed.Round(100*time.Millisecond).String() +
		", " + strconv.Itoa(r.sockets) + " sockets, " + strconv.Itoa(r.streams) +
		" socks streams, " + strconv.Itoa(r.failures) + " failed sends, wrap " +
		strconv.Itoa(r.wrapB/1024) + " KB"
}

// six relays like private mode: our onion relay (no tls) and five over tls
func measureBurst(t *testing.T, run burstRun) burstResult {
	var logTo io.Writer = io.Discard
	if p := os.Getenv("HALO_PUB_LOG"); p != "" {
		if f, err := os.Create(p); err == nil {
			defer f.Close()
			logTo = f
		}
	}
	log.SetOutput(logTo)
	defer log.SetOutput(os.Stderr)
	socks := newSocksStandIn(t)
	socks.connectDelay = run.rtt
	socks.lag = run.rtt / 2
	socks.rate = run.rate
	var relays []*relayStandIn
	for i := 0; i < 6; i++ {
		r := newRelayStandIn(t, 0)
		if i > 0 {
			r.upgradeDelay = run.rtt
		}
		relays = append(relays, r)
	}
	useStandIns(t, modePrivate, socks, relays...)
	peer := newXid(t)
	peerHex := hex.EncodeToString(peer.pub[:])
	// a 12 KB slice is 16 KB of base64 in the message, and signal's
	// ciphertext of that in base64 again
	msg := strings.Repeat("Q", 22000)

	var next, failures int32
	start := time.Now()
	var wg sync.WaitGroup
	for w := 0; w < run.inflight; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				i := atomic.AddInt32(&next, 1)
				if int(i) > run.slices {
					return
				}
				// dart tries a slice again when it fails
				for attempt := 0; attempt < 3; attempt++ {
					if nostrSend(peerHex, msg) == "ok" {
						break
					}
					atomic.AddInt32(&failures, 1)
				}
			}
		}()
	}
	wg.Wait()
	res := burstResult{elapsed: time.Since(start), failures: int(failures)}
	t.Logf("sends done after %s", res.elapsed.Round(100*time.Millisecond))
	counts := func() (min int, all []int) {
		min = run.slices
		for _, r := range relays {
			r.mu.Lock()
			n := r.accepted
			r.mu.Unlock()
			all = append(all, n)
			if n < min {
				min = n
			}
		}
		return
	}
	for end := time.Now().Add(2 * time.Minute); time.Now().Before(end); time.Sleep(100 * time.Millisecond) {
		if m, _ := counts(); m >= run.slices {
			break
		}
	}
	if m, all := counts(); m < run.slices {
		t.Logf("after %s the relays hold %v of %d", time.Since(start).Round(time.Second), all, run.slices)
	}
	res.landed = time.Since(start)
	for _, r := range relays {
		res.sockets += len(r.snapshot())
	}
	res.streams = socks.count()
	gw, err := nip17Wrap(peer.pub, msg)
	if err == nil {
		res.wrapB = len(gw.String())
	}
	return res
}
