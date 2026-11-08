// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bufio"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net"
	"os"
	"sort"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cretz/bine/tor"
)

// a socks port that behaves like tor towards onions: every stream takes one
// of tor's pending circuits (MaxClientCircuitsPending, 32 by default) while
// it is built, and a stream past them waits for one. an offline onion holds
// its circuit while tor walks the hsdirs and then fails, a stuck one holds
// it until the client gives up.
type onionTor struct {
	ln      net.Listener
	pending chan struct{}

	mu   sync.Mutex
	plan map[string]onionPlan
	door string // where every reachable onion lands

	live, maxLive int32       // client streams open now, and the most at once
	wait, maxWait int32       // streams waiting for a pending circuit
	opened        []time.Time // every stream asked, when
	dials         map[string]int
	dialsSince    map[string]int
	clients       map[net.Conn]bool
	serving       sync.WaitGroup
}

type onionPlan struct {
	build time.Duration // circuit build until the connected cell or the failure
	fail  bool
	stuck bool
}

func newOnionTor(t *testing.T, pending int) *onionTor {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	o := &onionTor{ln: ln, pending: make(chan struct{}, pending), plan: map[string]onionPlan{},
		dials: map[string]int{}, dialsSince: map[string]int{}, clients: map[net.Conn]bool{}}
	o.serving.Add(1)
	go func() {
		defer o.serving.Done()
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			o.serving.Add(1)
			go func() { defer o.serving.Done(); o.serve(c) }()
		}
	}()
	t.Cleanup(func() {
		ln.Close()
		o.mu.Lock()
		for c := range o.clients {
			c.Close()
		}
		o.mu.Unlock()
		o.serving.Wait()
	})
	return o
}

func (o *onionTor) port() int { return o.ln.Addr().(*net.TCPAddr).Port }

func bump(n, most *int32) {
	v := atomic.AddInt32(n, 1)
	for {
		m := atomic.LoadInt32(most)
		if v <= m || atomic.CompareAndSwapInt32(most, m, v) {
			return
		}
	}
}

func (o *onionTor) serve(c net.Conn) {
	bump(&o.live, &o.maxLive)
	o.mu.Lock()
	o.clients[c] = true
	o.mu.Unlock()
	defer func() {
		atomic.AddInt32(&o.live, -1)
		o.mu.Lock()
		delete(o.clients, c)
		o.mu.Unlock()
		c.Close()
	}()
	br := bufio.NewReader(c)
	read := func(n int) []byte {
		b := make([]byte, n)
		if _, err := io.ReadFull(br, b); err != nil {
			return nil
		}
		return b
	}
	h := read(2)
	if h == nil || h[0] != 5 {
		return
	}
	methods := read(int(h[1]))
	auth := false
	for _, m := range methods {
		auth = auth || m == 2
	}
	if auth {
		c.Write([]byte{5, 2})
		v := read(2)
		if v == nil {
			return
		}
		read(int(v[1]))
		pl := read(1)
		if pl == nil {
			return
		}
		read(int(pl[0]))
		c.Write([]byte{1, 0})
	} else {
		c.Write([]byte{5, 0})
	}
	req := read(4)
	if req == nil || req[3] != 3 {
		return
	}
	l := read(1)
	host := string(read(int(l[0])))
	if read(2) == nil {
		return
	}
	o.mu.Lock()
	p, door := o.plan[host], o.door
	o.opened = append(o.opened, time.Now())
	o.dials[host]++
	o.dialsSince[host]++
	o.mu.Unlock()
	// the client may give up while it waits: tor then drops the stream
	gone := make(chan struct{})
	first := make(chan []byte, 1)
	go func() {
		b := make([]byte, 4096)
		n, err := br.Read(b)
		if n > 0 {
			first <- b[:n]
			return
		}
		if err != nil {
			close(gone)
		}
	}()
	bump(&o.wait, &o.maxWait)
	select {
	case o.pending <- struct{}{}:
		atomic.AddInt32(&o.wait, -1)
	case <-gone:
		atomic.AddInt32(&o.wait, -1)
		return
	}
	free := func() { <-o.pending }
	if p.stuck {
		<-gone
		free()
		return
	}
	select {
	case <-time.After(p.build):
	case <-gone:
		free()
		return
	}
	free()
	if p.fail {
		// tor's reply for an onion it could not reach
		c.Write([]byte{5, 4, 0, 1, 0, 0, 0, 0, 0, 0})
		return
	}
	out, err := net.Dial("tcp", door)
	if err != nil {
		c.Write([]byte{5, 5, 0, 1, 0, 0, 0, 0, 0, 0})
		return
	}
	defer out.Close()
	c.Write([]byte{5, 0, 0, 1, 0, 0, 0, 0, 0, 0})
	done := make(chan struct{}, 2)
	go func() { io.Copy(c, out); done <- struct{}{} }()
	select {
	case b := <-first:
		out.Write(b)
	case <-gone:
		return
	case <-done:
		return
	}
	go func() { io.Copy(out, br); done <- struct{}{} }()
	<-done
}

func (o *onionTor) dialsTo(hosts []string, since bool) int {
	o.mu.Lock()
	defer o.mu.Unlock()
	n := 0
	for _, h := range hosts {
		if since {
			n += o.dialsSince[h]
		} else {
			n += o.dials[h]
		}
	}
	return n
}

func (o *onionTor) newRound() {
	o.mu.Lock()
	o.dialsSince = map[string]int{}
	o.mu.Unlock()
	atomic.StoreInt32(&o.maxLive, atomic.LoadInt32(&o.live))
	atomic.StoreInt32(&o.maxWait, atomic.LoadInt32(&o.wait))
}

// a door that acks every line, and counts them per stream
func ackDoor(t *testing.T) string {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	var mu sync.Mutex
	conns := map[net.Conn]bool{}
	t.Cleanup(func() {
		ln.Close()
		mu.Lock()
		for c := range conns {
			c.Close()
		}
		mu.Unlock()
		wg.Wait()
	})
	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			mu.Lock()
			conns[c] = true
			mu.Unlock()
			wg.Add(1)
			go func() {
				defer wg.Done()
				r := bufio.NewReader(c)
				for {
					c.SetReadDeadline(time.Now().Add(doorNextLine))
					if _, err := r.ReadString('\n'); err != nil {
						c.Close()
						return
					}
					c.Write([]byte(doorAck))
				}
			}()
		}
	}()
	return ln.Addr().String()
}

// the field's shape: one onion per contact, most of them offline, a few
// slow or stuck, the open chat among the reachable ones
type herd struct {
	open    string
	online  []string // reachable, the open chat first
	slow    []string
	stuck   []string
	offline []string
}

func fakeOnion(i int) string { return fmt.Sprintf("%056d.onion", i) }

func newHerd(o *onionTor, n int, seed int64) herd {
	r := rand.New(rand.NewSource(seed))
	var h herd
	o.mu.Lock()
	defer o.mu.Unlock()
	for i := 0; i < n; i++ {
		on := fakeOnion(i)
		switch {
		case i < 11:
			// a rendezvous in 1-3 s
			o.plan[on] = onionPlan{build: time.Second + time.Duration(r.Intn(2000))*time.Millisecond}
			h.online = append(h.online, on)
		case i < 16:
			o.plan[on] = onionPlan{stuck: true}
			h.stuck = append(h.stuck, on)
		case i < 31:
			o.plan[on] = onionPlan{build: 8*time.Second + time.Duration(r.Intn(4000))*time.Millisecond}
			h.slow = append(h.slow, on)
		default:
			// tor walks the hsdirs for 4-10 s and gives up
			o.plan[on] = onionPlan{build: 4*time.Second + time.Duration(r.Intn(6000))*time.Millisecond, fail: true}
			h.offline = append(h.offline, on)
		}
	}
	h.open = h.online[0]
	return h
}

type herdResult struct {
	at  map[string]time.Duration
	err map[string]error
}

// every contact is sent a line at once, as an outbox pass after the route
// came back does; the open chat's own line follows a moment later
func runHerd(t *testing.T, o *onionTor, h herd, round int) herdResult {
	t.Helper()
	tn := torNode
	res := herdResult{at: map[string]time.Duration{}, err: map[string]error{}}
	var mu sync.Mutex
	var wg sync.WaitGroup
	start := time.Now()
	all := append(append(append(append([]string{}, h.online[1:]...), h.slow...), h.stuck...), h.offline...)
	rand.New(rand.NewSource(int64(round))).Shuffle(len(all), func(i, j int) { all[i], all[j] = all[j], all[i] })
	send := func(on string, open bool) {
		defer wg.Done()
		err := measureSend(tn, on, doorLine(t, 600), open)
		mu.Lock()
		res.at[on] = time.Since(start)
		res.err[on] = err
		mu.Unlock()
	}
	for _, on := range all {
		wg.Add(1)
		go send(on, false)
	}
	time.Sleep(200 * time.Millisecond)
	wg.Add(1)
	go send(h.open, true)
	wg.Wait()
	return res
}

func pct(ds []time.Duration, p float64) time.Duration {
	if len(ds) == 0 {
		return 0
	}
	sort.Slice(ds, func(i, j int) bool { return ds[i] < ds[j] })
	return ds[int(float64(len(ds)-1)*p)]
}

func herdLine(t *testing.T, name string, o *onionTor, h herd, r herdResult) (openAt time.Duration, onlineOK int) {
	var onAt []time.Duration
	for _, on := range h.online {
		if r.err[on] == nil {
			onlineOK++
			onAt = append(onAt, r.at[on])
		}
	}
	slowOK := 0
	for _, on := range h.slow {
		if r.err[on] == nil {
			slowOK++
		}
	}
	var lastFail time.Duration
	for _, on := range append(append([]string{}, h.stuck...), h.offline...) {
		if r.at[on] > lastFail {
			lastFail = r.at[on]
		}
	}
	openAt = r.at[h.open] - 200*time.Millisecond
	t.Logf("%s: open chat %v (%v), online %d/%d (p50 %v, max %v), slow %d/%d, "+
		"offline/stuck all back by %v, socks streams most at once %d, waiting for a circuit most %d, "+
		"dials to offline+stuck this round %d",
		name, openAt.Round(10*time.Millisecond), r.err[h.open], onlineOK, len(h.online),
		pct(onAt, 0.5).Round(10*time.Millisecond), pct(onAt, 1).Round(10*time.Millisecond),
		slowOK, len(h.slow), lastFail.Round(10*time.Millisecond),
		atomic.LoadInt32(&o.maxLive), atomic.LoadInt32(&o.maxWait),
		o.dialsTo(append(append([]string{}, h.offline...), h.stuck...), true))
	if d, op := measurePeaks(); d >= 0 {
		t.Logf("  engine peaks: %d dials, %d streams", d, op)
	}
	return openAt, onlineOK
}

// the redmi's shape (271 listened addresses on the developer identity, the
// most recent count read off its transport page) against tor's pending
// circuit cap. KRYFO_DOOR_N sets another count.
func TestMeasureDoorHerd(t *testing.T) {
	if os.Getenv("HALO_DOOR_MEASURE") == "" {
		t.Skip("HALO_DOOR_MEASURE not set")
	}
	n := 271
	if v, err := strconv.Atoi(os.Getenv("KRYFO_DOOR_N")); err == nil && v > 40 {
		n = v
	}
	log.SetOutput(io.Discard)
	defer log.SetOutput(os.Stderr)
	useStandIns(t, modePrivate, nil)
	statusForTest(t, "reachable")
	routeNoteOK()
	o := newOnionTor(t, 32)
	atomic.StoreInt32(&pinnedSocks, int32(o.port()))
	o.door = ackDoor(t)
	t.Cleanup(func() { doorCloseAll(); measureReset() })
	h := newHerd(o, n, 1)
	measureOpen(h.open)
	// KRYFO_DOOR_WROTE: every other online contact wrote lately, as the
	// ones people talk to do
	if os.Getenv("KRYFO_DOOR_WROTE") != "" {
		for i, on := range h.online {
			if i%2 == 1 {
				measureWrote(on)
			}
		}
	}
	rounds := 8
	if v, err := strconv.Atoi(os.Getenv("KRYFO_DOOR_ROUNDS")); err == nil && v > 0 {
		rounds = v
	}
	// rounds as the outbox's passes come: the same lines again, 5 s after
	// the last one ended. which online and slow contacts the door reached
	// so far, and the dials it spent on offline and stuck ones
	reached := map[string]bool{}
	allBy := 0
	for r := 1; r <= rounds; r++ {
		o.newRound()
		res := runHerd(t, o, h, r)
		herdLine(t, fmt.Sprintf("n=%d round %d", n, r), o, h, res)
		for _, on := range append(append([]string{}, h.online...), h.slow...) {
			if res.err[on] == nil {
				reached[on] = true
			}
		}
		if allBy == 0 && len(reached) == len(h.online)+len(h.slow) {
			allBy = r
		}
		t.Logf("  so far: %d of %d online+slow reached by the door, %d dials to offline+stuck in all",
			len(reached), len(h.online)+len(h.slow),
			o.dialsTo(append(append([]string{}, h.offline...), h.stuck...), false))
		time.Sleep(5 * time.Second)
	}
	t.Logf("every online and slow contact reached by round %d (0: not in %d rounds)", allBy, rounds)
}

// the open chat's line in its own place, every other one with the rest
func measureSend(tn *tor.Tor, onion, line string, open bool) error {
	if open {
		return sendToAs(tn, onion, line, doorOpenChat)
	}
	return sendToAs(tn, onion, line, doorRest)
}

func measureOpen(onion string) { doorFocus(onion) }

func measureReset() { doorQueueReset() }

func measureWrote(onion string) { doorAwake(onion) }

func measurePeaks() (int, int) {
	doorQMu.Lock()
	defer doorQMu.Unlock()
	return doorDialPeak, doorOpenPeak
}

// the most of times in any window of w
func peakIn(ts []time.Time, w time.Duration) int {
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

// new connections per second, as a home router's flood guard counts them.
// the door's dials are socks streams: tor carries them on its guard
// connection, no new tcp from the phone. the relay sockets after every one
// dropped at once are new tcp from the phone in fast mode, and socks
// streams on the onion route. KRYFO_DOOR_N contacts, 150 by default.
func TestMeasureConnectRate(t *testing.T) {
	if os.Getenv("HALO_DOOR_MEASURE") == "" {
		t.Skip("HALO_DOOR_MEASURE not set")
	}
	n := 150
	if v, err := strconv.Atoi(os.Getenv("KRYFO_DOOR_N")); err == nil && v > 40 {
		n = v
	}
	log.SetOutput(io.Discard)
	defer log.SetOutput(os.Stderr)
	t.Run("door", func(t *testing.T) {
		useStandIns(t, modePrivate, nil)
		statusForTest(t, "reachable")
		routeNoteOK()
		o := newOnionTor(t, 32)
		atomic.StoreInt32(&pinnedSocks, int32(o.port()))
		o.door = ackDoor(t)
		t.Cleanup(func() { doorCloseAll(); measureReset() })
		h := newHerd(o, n, 1)
		measureOpen(h.open)
		start := time.Now()
		runHerd(t, o, h, 1)
		o.mu.Lock()
		ts := append([]time.Time{}, o.opened...)
		o.mu.Unlock()
		first := 0
		for _, x := range ts {
			if x.Sub(start) < 10*time.Second {
				first++
			}
		}
		t.Logf("door n=%d: socks streams opened %d in all, %d in the first 10 s, most in 1 s %d, in 100 ms %d",
			n, len(ts), first, peakIn(ts, time.Second), peakIn(ts, 100*time.Millisecond))
	})
	for _, mode := range []string{modeFast, modePrivate} {
		t.Run("relays "+mode, func(t *testing.T) {
			own, pub := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
			var socks *socksStandIn
			if mode == modePrivate {
				socks = newSocksStandIn(t)
			}
			useStandIns(t, mode, socks, own, pub)
			statusForTest(t, "reachable")
			routeNoteOK()
			freshInbox(t)
			freshBatches(t)
			var tags []string
			want := map[string]bool{}
			for i := 0; i < n; i++ {
				p := newXid(t)
				tags = append(tags, hex.EncodeToString(p.pub[:]))
				want[mustRcv(t, p)] = true
			}
			t.Cleanup(func() {
				nostrMu.Lock()
				for _, h := range tags {
					if c, ok := nostrSubs[h]; ok {
						c()
						delete(nostrSubs, h)
					}
				}
				nostrMu.Unlock()
			})
			for _, h := range tags {
				if r := nostrSubscribeAs(mainIdent, h, false, false); r != "ok" {
					t.Fatal(r)
				}
			}
			all := func() bool {
				l := own.listening()
				for a := range want {
					if l[a] == 0 {
						return false
					}
				}
				return true
			}
			until := time.Now().Add(4 * time.Minute)
			for !all() && time.Now().Before(until) {
				time.Sleep(100 * time.Millisecond)
			}
			fsSettle([]*relayStandIn{own, pub}, 3*time.Second, time.Minute)
			drop := time.Now()
			own.dropAll()
			pub.dropAll()
			until = time.Now().Add(4 * time.Minute)
			for !all() && time.Now().Before(until) {
				time.Sleep(100 * time.Millisecond)
			}
			back := time.Since(drop)
			time.Sleep(3 * time.Second)
			for _, r := range []struct {
				name string
				s    *relayStandIn
			}{{"own", own}, {"pub", pub}} {
				var ts []time.Time
				for _, c := range fsSince(r.s.snapshot(), drop) {
					ts = append(ts, c.opened)
				}
				t.Logf("relays %s n=%d relay=%s: after a drop %d new sockets, most in 1 s %d, in 100 ms %d, all listening again after %v",
					mode, n, r.name, len(ts), peakIn(ts, time.Second), peakIn(ts, 100*time.Millisecond), back.Round(100*time.Millisecond))
			}
		})
	}
}
