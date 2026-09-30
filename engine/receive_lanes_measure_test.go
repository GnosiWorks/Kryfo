// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net"
	"net/textproto"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
	"golang.org/x/crypto/curve25519"
)

// the app's private-mode relay list, our own onion relay first
const measureRelays = "ws://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion," +
	"wss://relay.kryfo.app,wss://nos.lol,wss://relay.primal.net,wss://nostr.mom,wss://nostr.oxtr.dev"

// what spreading the receive addresses over circuits costs. starts the
// real tor, listens on fresh addresses nobody uses on the app's relays, and
// reports how long until every relay answered for each of them, how many
// circuits tor built, and what tor read and wrote while they sat idle. it
// subscribes and publishes nothing. one mode per process, as tor survives
// only one close:
//
//	HALO_LANES_MEASURE=1 HALO_LANES_MODE=4 go test -run TestMeasureReceiveLanes -v -timeout 3h .
//
// HALO_LANES_MODE is unset for the app's own lanes, 1 (every address on one
// lane, as before), a number of lanes to spread the addresses over by a hash,
// or each (a lane per address). HALO_LANES_ADDRS (30), HALO_LANES_MINUTES idle (60),
// HALO_LANES_SETTLE minutes to wait for the first answers (10) and
// HALO_LANES_LOG (a file for the engine log) change it.
func TestMeasureReceiveLanes(t *testing.T) {
	if os.Getenv("HALO_LANES_MEASURE") == "" {
		t.Skip("HALO_LANES_MEASURE not set")
	}
	num := func(k string, def int) int {
		if v, err := strconv.Atoi(os.Getenv(k)); err == nil {
			return v
		}
		return def
	}
	mode := os.Getenv("HALO_LANES_MODE")
	addrs := num("HALO_LANES_ADDRS", 30)
	idleFor := time.Duration(num("HALO_LANES_MINUTES", 60)) * time.Minute
	settle := time.Duration(num("HALO_LANES_SETTLE", 10)) * time.Minute

	oldLane := receiveLane
	defer func() { receiveLane = oldLane }()
	switch mode {
	case "":
		mode = "app"
	case "1":
		receiveLane = func(string) string { return laneEveryday }
	case "each":
		receiveLane = func(rcvPk string) string { return laneEveryday + ":" + rcvPk }
	default:
		n, err := strconv.Atoi(mode)
		if err != nil || n < 2 {
			t.Fatalf("HALO_LANES_MODE %q: want 1, a number of lanes, or each", mode)
		}
		receiveLane = func(rcvPk string) string { return hashLane(rcvPk, n) }
	}

	var logTo io.Writer = io.Discard
	if p := os.Getenv("HALO_LANES_LOG"); p != "" {
		if f, err := os.Create(p); err == nil {
			defer f.Close()
			logTo = f
		}
	}
	log.SetOutput(logTo)
	defer log.SetOutput(os.Stderr)

	// tor writes here until the process ends, which t.TempDir's cleanup trips on
	dir, err := os.MkdirTemp("", "halo-lanes-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	t0 := time.Now()
	if a := startListener(dir); strings.HasPrefix(a, "error:") {
		t.Fatalf("start: %s", a)
	}
	mu.Lock()
	tn := torNode
	mu.Unlock()
	circ := watchCircuits(t, tn)
	if !torAtFull(tn, 5*time.Minute) {
		t.Skip("tor did not bootstrap within 5 minutes here")
	}
	bootAt := time.Now()
	rd0, wr0 := torTraffic(t, tn)
	built0 := circ.builtCount()
	gen0 := routeGeneration()
	t.Logf("tor at 100%% after %s", bootAt.Sub(t0).Round(100*time.Millisecond))

	mu.Lock()
	if _, err := rand.Read(myXPriv[:]); err != nil {
		mu.Unlock()
		t.Fatal(err)
	}
	curve25519.ScalarBaseMult(&myXPub, &myXPriv)
	mu.Unlock()
	relays := strings.Split(measureRelays, ",")
	nostrMu.Lock()
	nostrRelays = relays
	nostrMu.Unlock()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	starts0 := atomic.LoadInt64(&catchupStarted)
	var rcvs []string
	lanes := map[string]bool{}
	for i := 0; i < addrs; i++ {
		var peer, peerPriv [32]byte
		if _, err := rand.Read(peerPriv[:]); err != nil {
			t.Fatal(err)
		}
		curve25519.ScalarBaseMult(&peer, &peerPriv)
		_, rcv, err := nip17RcvAddress(peer)
		if err != nil {
			t.Fatal(err)
		}
		rcvs = append(rcvs, rcv)
		lanes[receiveLane(rcv)] = true
		go nostrSubscribeRunner(ctx, hex.EncodeToString(peer[:]), peer, rcv)
	}

	// a subscription is settled once the catch-up of its latest connection
	// has ended: an eose, the cap, or the relay closing it. the window closes
	// when all are settled and nothing has reconnected for 15s.
	type subState struct {
		lastStart time.Time
		done      catchupRun
		hasDone   bool
	}
	st := map[string]*subState{}
	for _, u := range relays {
		for _, r := range rcvs {
			st[catchupKey(u, r)] = &subState{}
		}
	}
	isSettled := func(s *subState) bool { return s.hasDone && s.done.At.After(s.lastStart) }
	lastMove := time.Now()
	for {
		moved := false
		catchupMu.Lock()
		for k, s := range st {
			if f, ok := catchupFrom[k]; ok && f.After(s.lastStart) {
				s.lastStart, moved = f, true
			}
			if r, ok := catchupLast[k]; ok && (!s.hasDone || r.At.After(s.done.At)) {
				s.done, s.hasDone, moved = r, true, true
			}
		}
		catchupMu.Unlock()
		now := time.Now()
		if moved {
			lastMove = now
		}
		n := 0
		for _, s := range st {
			if isSettled(s) {
				n++
			}
		}
		if n == len(st) && now.Sub(lastMove) >= 15*time.Second {
			break
		}
		if now.Sub(bootAt) >= settle {
			break
		}
		time.Sleep(200 * time.Millisecond)
	}
	startEnd := time.Now()
	rd1, wr1 := torTraffic(t, tn)
	built1 := circ.builtCount()
	open1, purposes1, names1 := circuitsOpen(t, tn)
	starts1 := atomic.LoadInt64(&catchupStarted)

	listening, capped, trying := 0, 0, 0
	var allBy time.Duration
	for _, u := range relays {
		var took []time.Duration
		var conn []int
		c, tr := 0, 0
		for _, r := range rcvs {
			s := st[catchupKey(u, r)]
			switch {
			case !isSettled(s):
				tr++
			case s.done.Dropped:
				c++
			default:
				took = append(took, s.done.At.Sub(bootAt))
				conn = append(conn, s.done.ConnectMs)
			}
		}
		listening += len(took)
		capped += c
		trying += tr
		sort.Slice(took, func(i, j int) bool { return took[i] < took[j] })
		sort.Ints(conn)
		line := fmt.Sprintf("%-20s eose %d/%d", relayHost(u), len(took), addrs)
		if len(took) > 0 {
			last := took[len(took)-1]
			if last > allBy {
				allBy = last
			}
			line += fmt.Sprintf(", first %s, median %s, last %s, connect median %dms",
				secs(took[0]), secs(took[len(took)/2]), secs(last), conn[len(conn)/2])
		}
		if c > 0 {
			line += fmt.Sprintf(", %d capped before eose", c)
		}
		if tr > 0 {
			line += fmt.Sprintf(", %d still trying", tr)
		}
		t.Log(line)
	}
	t.Logf("start: %d circuits built, %d open (%s), %d socks names on them, %s read %s written, %d subscribes for %d subscriptions",
		built1-built0, open1, purposes1, names1, mb(rd1-rd0), mb(wr1-wr0), starts1-starts0, len(st))

	idleEnd := startEnd.Add(idleFor)
	for time.Now().Before(idleEnd) {
		wait := 10 * time.Minute
		if rem := time.Until(idleEnd); rem < wait {
			wait = rem
		}
		time.Sleep(wait)
		rd, wr := torTraffic(t, tn)
		t.Logf("idle %s: %s read %s written, %d circuits built",
			time.Since(startEnd).Round(time.Minute), mb(rd-rd1), mb(wr-wr1), circ.builtCount()-built1)
	}
	idle := time.Since(startEnd)
	rd2, wr2 := torTraffic(t, tn)
	built2 := circ.builtCount()
	open2, purposes2, names2 := circuitsOpen(t, tn)
	starts2 := atomic.LoadInt64(&catchupStarted)
	perHour := func(b int64) int64 { return int64(float64(b) * float64(time.Hour) / float64(idle)) }
	t.Logf("idle end: %d circuits open (%s), %d socks names on them", open2, purposes2, names2)

	all := "not all"
	if listening == len(st) {
		all = "all by " + secs(allBy)
	}
	t.Logf("SUMMARY mode=%s addresses=%d lanes=%d relays=%d | tor up in %s | eose %d/%d, %s after tor was up, capped %d, still trying %d | circuits built %d at start, %d over %s idle, %d open at the end | start %s read %s written | per idle hour %s read %s written, %d resubscribes | tor bounced %d times",
		mode, addrs, len(lanes), len(relays), secs(bootAt.Sub(t0)),
		listening, len(st), all, capped, trying,
		built1-built0, built2-built1, idle.Round(time.Minute), open2,
		mb(rd1-rd0), mb(wr1-wr0),
		mb(perHour(rd2-rd1)), mb(perHour(wr2-wr1)), starts2-starts1,
		routeGeneration()-gen0)
}

// polls tor itself: the engine's watcher only looks every two seconds
func torAtFull(n *tor.Tor, limit time.Duration) bool {
	for end := time.Now().Add(limit); time.Now().Before(end); time.Sleep(250 * time.Millisecond) {
		var kv []*control.KeyVal
		err := ctrlDo(n, "GETINFO bootstrap-phase", func(c *control.Conn) error {
			var e error
			kv, e = c.GetInfo("status/bootstrap-phase")
			return e
		})
		if err == nil && len(kv) > 0 && parseBootstrapPct(kv[0].Val) >= 100 {
			return true
		}
	}
	return false
}

// bytes tor has read and written on the network since it started
func torTraffic(t *testing.T, n *tor.Tor) (rd, wr int64) {
	t.Helper()
	var kv []*control.KeyVal
	var err error
	for try := 0; try < 3; try++ {
		err = ctrlDo(n, "GETINFO traffic", func(c *control.Conn) error {
			var e error
			kv, e = c.GetInfo("traffic/read", "traffic/written")
			return e
		})
		if err == nil {
			break
		}
		time.Sleep(time.Second)
	}
	if err != nil {
		t.Fatalf("traffic counters: %v", err)
	}
	for _, x := range kv {
		v, _ := strconv.ParseInt(x.Val, 10, 64)
		switch x.Key {
		case "traffic/read":
			rd = v
		case "traffic/written":
			wr = v
		}
	}
	return rd, wr
}

// the built circuits tor holds now, by purpose, and how many socks names
// they carry between them
func circuitsOpen(t *testing.T, n *tor.Tor) (open int, purposes string, names int) {
	t.Helper()
	var kv []*control.KeyVal
	err := ctrlDo(n, "GETINFO circuit-status", func(c *control.Conn) error {
		var e error
		kv, e = c.GetInfo("circuit-status")
		return e
	})
	if err != nil {
		t.Logf("circuit-status: %v", err)
		return 0, "", 0
	}
	by := map[string]int{}
	seen := map[string]bool{}
	for _, x := range kv {
		for _, line := range strings.Split(x.Val, "\n") {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			ce := control.ParseCircuitEvent(line)
			if ce.Status != "BUILT" {
				continue
			}
			open++
			by[ce.Purpose]++
			if ce.SocksUsername != "" {
				seen[ce.SocksUsername] = true
			}
		}
	}
	var parts []string
	for p, c := range by {
		parts = append(parts, fmt.Sprintf("%s %d", strings.ToLower(p), c))
	}
	sort.Strings(parts)
	return open, strings.Join(parts, ", "), len(seen)
}

// counts circuits from tor's own events, on a control connection of the
// test's own so the engine's two are left as they are
type circuitWatch struct {
	mu    sync.Mutex
	built int
}

func (w *circuitWatch) builtCount() int {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.built
}

func watchCircuits(t *testing.T, n *tor.Tor) *circuitWatch {
	t.Helper()
	nc, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", n.ControlPort), 5*time.Second)
	if err != nil {
		t.Fatalf("dial control port: %v", err)
	}
	t.Cleanup(func() { nc.Close() })
	c := control.NewConn(textproto.NewConn(nc))
	if err := c.Authenticate(""); err != nil {
		t.Fatalf("authenticate control port: %v", err)
	}
	ch := make(chan control.Event, 1024)
	if err := c.AddEventListener(ch, control.EventCodeCircuit); err != nil {
		t.Fatalf("circuit events: %v", err)
	}
	w := &circuitWatch{}
	// nothing else is sent on this connection, so every line is an event
	go func() {
		for c.HandleNextEvent() == nil {
		}
	}()
	go func() {
		for ev := range ch {
			if ce, ok := ev.(*control.CircuitEvent); ok && ce.Status == "BUILT" {
				w.mu.Lock()
				w.built++
				w.mu.Unlock()
			}
		}
	}()
	return w
}

func relayHost(u string) string {
	p, err := url.Parse(u)
	if err != nil {
		return u
	}
	h := p.Host
	if strings.HasSuffix(h, ".onion") && len(h) > 14 {
		h = h[:8] + ".onion"
	}
	return h
}

func secs(d time.Duration) string { return fmt.Sprintf("%.1fs", d.Seconds()) }

func mb(b int64) string { return fmt.Sprintf("%.2f MB", float64(b)/1e6) }
