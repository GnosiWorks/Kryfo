// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"bufio"
	"fmt"
	"net"
	"net/textproto"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// the ways a send waited on tor for ten minutes and more. no tor here: a
// fake control port, a status and a clock.

// a control port that answers the handshake, reports a bootstrap
// percentage, and takes everything else with an ok
type fakeControl struct {
	ln  net.Listener
	pct atomic.Int32
	// how long a bridge command takes to answer, nanoseconds
	slow atomic.Int64
	// how many times the bootstrap phase was asked for
	polls atomic.Int64
	// what status/circuit-established says
	circ atomic.Int32
	mu   sync.Mutex
	cmds []string
}

// the setconf and resetconf lines it was sent, in order
func (f *fakeControl) sent() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.cmds...)
}

func newFakeControl(t *testing.T, pct int) *fakeControl {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	f := &fakeControl{ln: ln}
	f.pct.Store(int32(pct))
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go f.handle(c)
		}
	}()
	t.Cleanup(func() { _ = ln.Close() })
	return f
}

func (f *fakeControl) handle(c net.Conn) {
	defer c.Close()
	r := bufio.NewReader(c)
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return
		}
		cmd := strings.ToUpper(strings.TrimSpace(line))
		switch {
		case strings.HasPrefix(cmd, "PROTOCOLINFO"):
			fmt.Fprint(c, "250-PROTOCOLINFO 1\r\n250-AUTH METHODS=NULL\r\n250-VERSION Tor=\"0.4.9.5\"\r\n250 OK\r\n")
		case strings.HasPrefix(cmd, "GETINFO STATUS/CIRCUIT-ESTABLISHED"):
			fmt.Fprintf(c, "250-status/circuit-established=%d\r\n250 OK\r\n", f.circ.Load())
		case strings.HasPrefix(cmd, "GETINFO STATUS/BOOTSTRAP-PHASE"):
			f.polls.Add(1)
			fmt.Fprintf(c, "250-status/bootstrap-phase=NOTICE BOOTSTRAP PROGRESS=%d TAG=x SUMMARY=\"x\"\r\n250 OK\r\n", f.pct.Load())
		default:
			if strings.HasPrefix(cmd, "SETCONF") || strings.HasPrefix(cmd, "RESETCONF") {
				f.mu.Lock()
				f.cmds = append(f.cmds, cmd)
				f.mu.Unlock()
			}
			if strings.Contains(cmd, "BRIDGE") {
				time.Sleep(time.Duration(f.slow.Load()))
			}
			fmt.Fprint(c, "250 OK\r\n")
		}
	}
}

func (f *fakeControl) port() int { return f.ln.Addr().(*net.TCPAddr).Port }

// a tor of this process as far as the engine can tell: a control port to
// dial, a control connection, an address and a data dir
func fakeTor(t *testing.T, port int) *tor.Tor {
	t.Helper()
	a, b := net.Pipe()
	t.Cleanup(func() { a.Close(); b.Close() })
	n := &tor.Tor{ControlPort: port, Control: control.NewConn(textproto.NewConn(a))}
	mu.Lock()
	torNode, myAddr, savedDataDir = n, "fake.onion", t.TempDir()
	mu.Unlock()
	ctrlReset()
	t.Cleanup(func() {
		mu.Lock()
		torNode, myAddr, savedDataDir = nil, "", ""
		mu.Unlock()
		ctrlReset()
		atomic.StoreInt32(&torRestarting, 0)
		atomic.StoreInt32(&reconnectRunning, 0)
		atomic.StoreInt64(&reconnectSince, 0)
		atomic.StoreInt64(&lastTorRestart, 0)
	})
	return n
}

// a reconnect whose control command timed out says off and returns. tor may
// still take the command after that, and then it is off the network with
// nobody to bring it back: the watch left off to the app, and the app's
// watchdog only does first starts. off is rescued now.
func TestHalfDoneReconnectIsRescued(t *testing.T) {
	old := ctrlDeadline
	ctrlDeadline = 300 * time.Millisecond
	defer func() { ctrlDeadline = old }()
	d := newDeadControl(t)
	defer d.close()
	fakeTor(t, d.port())
	resetRoute(t, "publishing", 100)
	routeNoteOK()

	if r := reconnectTor(); !strings.HasPrefix(r, "error:") {
		t.Fatalf("a control port that never answers reconnected: %s", r)
	}
	if st := statusNow(); st != "off" {
		t.Fatalf("status %q after the reconnect gave up, want off", st)
	}
	t0 := time.Now()
	routeNeedsRescue(t0)
	if why := routeNeedsRescue(t0.Add(5 * time.Second)); why != "" {
		t.Fatalf("rescued an off tor after 5s: %s", why)
	}
	if why := routeNeedsRescue(t0.Add(20 * time.Second)); why == "" {
		t.Fatal("tor off with nobody asking for it, and no rescue after 20s")
	}
	// and not every tick after that: the gap applies
	if why := routeNeedsRescue(t0.Add(30 * time.Second)); why != "" {
		t.Fatalf("rescued again 10s later: %s", why)
	}
	// asleep on purpose is never rescued
	resetRoute(t, "off", 0)
	atomic.StoreInt32(&torPaused, 1)
	defer atomic.StoreInt32(&torPaused, 0)
	routeNeedsRescue(t0)
	if why := routeNeedsRescue(t0.Add(time.Hour)); why != "" {
		t.Fatalf("rescued a tor asleep on purpose: %s", why)
	}
}

// the same half-done reconnect, when tor did come back: relays connect
// through it while the status says off, and the app refuses every send.
// the status follows the relays, as it does for starting
func TestRelayThroughTorCorrectsOff(t *testing.T) {
	resetRoute(t, "off", 0)
	routeBump()
	routeNoteOK()
	if st, pct := statusNow(), bootPctNow(); st != "publishing" || pct != 100 {
		t.Fatalf("status %q %d%% after a relay connected through tor, want publishing 100%%", st, pct)
	}
	if !routeOK() {
		t.Fatal("cannot send although a relay connected through tor")
	}
	// tor put to sleep says off and means it
	resetRoute(t, "off", 0)
	atomic.StoreInt32(&torPaused, 1)
	defer atomic.StoreInt32(&torPaused, 0)
	routeNoteOK()
	if st := statusNow(); st != "off" {
		t.Fatalf("a sleeping tor was called up: %q", st)
	}
}

// a flight: every rescue in the air brings nothing back, so the gap between
// them grows to fifteen minutes. on the ground the network is new, and the
// first rescue must not wait out the gap the flight built up
func TestLandingIsNotHeldByTheFlightsBackoff(t *testing.T) {
	oldQ, oldB := netQuiet, netBounce
	defer func() { netQuiet, netBounce = oldQ, oldB }()
	netQuiet = 10 * time.Millisecond
	netBounce = func() {}
	resetRoute(t, "publishing", 100)
	routeNoteOK()
	now := time.Now()
	failAll(now.Add(-time.Hour), "wss://a", "wss://b", "wss://c")
	routeMu.Lock()
	rescues, lastRescue = 5, now.Add(-2*time.Minute)
	routeMu.Unlock()
	if why := routeNeedsRescue(now); why != "" {
		t.Fatalf("the flight's back-off did not hold in the air: %s", why)
	}

	networkChanged()
	time.Sleep(50 * time.Millisecond)
	landed := time.Now()
	failAll(landed, "wss://a", "wss://b")
	if why := routeNeedsRescue(landed.Add(deadFor + time.Second)); why == "" {
		t.Fatal("relays dead for a minute after landing and no rescue: the flight's back-off held it")
	}
}

// a reconnect stuck for minutes holds the slot, and every later one, the
// button's included, said "one already running" until five minutes had
// passed. the watch never got that far: it skips while one runs
func TestStuckReconnectTakenOver(t *testing.T) {
	f := newFakeControl(t, 100)
	f.slow.Store(int64(600 * time.Millisecond))
	fakeTor(t, f.port())
	resetRoute(t, "publishing", 100)
	old := stuckAfter
	stuckAfter = 200 * time.Millisecond
	defer func() { stuckAfter = old }()

	first := make(chan string, 1)
	go func() { first <- reconnectNow() }()
	time.Sleep(50 * time.Millisecond)
	if r := reconnectTor(); r != "error: one already running" {
		t.Fatalf("a watchdog got past a reconnect that runs fine: %s", r)
	}
	time.Sleep(250 * time.Millisecond)
	atomic.StoreInt64(&lastTorRestart, 0)
	if r := reconnectTor(); r != "ok" {
		t.Fatalf("a reconnect stuck past the limit was not taken over: %s", r)
	}
	if r := <-first; r != "error: superseded" {
		t.Fatalf("the replaced reconnect said %q", r)
	}

	// by hand it goes at once, however recent the running one
	go func() { first <- reconnectTor() }()
	time.Sleep(50 * time.Millisecond)
	if r := reconnectNow(); r != "ok" {
		t.Fatalf("the button did not take over: %s", r)
	}
	<-first
	if atomic.LoadInt32(&torRestarting) != 0 {
		t.Fatal("the flag stayed set after the reconnect that took over")
	}
}

// the one that was taken over finishes later and must not clear the flag
// of the one that took it
func TestTakenOverReconnectLeavesTheFlag(t *testing.T) {
	old := ctrlDeadline
	ctrlDeadline = 400 * time.Millisecond
	defer func() { ctrlDeadline = old }()
	d := newDeadControl(t)
	defer d.close()
	fakeTor(t, d.port())
	resetRoute(t, "publishing", 100)

	first := make(chan string)
	go func() { first <- reconnectNow() }()
	time.Sleep(100 * time.Millisecond)
	second := make(chan string)
	go func() { second <- reconnectNow() }()
	<-first
	if atomic.LoadInt32(&torRestarting) != 1 {
		<-second
		t.Fatal("the reconnect that was taken over cleared the running flag")
	}
	<-second
}

// after a long spell with no network the bootstrap watcher gave up at ten
// minutes, and tor reaching 100% later was never read
func TestBootstrapWatchNeverGivesUp(t *testing.T) {
	oldP, oldS, oldF := bootPoll, bootPollSlow, bootFast
	defer func() { bootPoll, bootPollSlow, bootFast = oldP, oldS, oldF }()
	bootPoll, bootPollSlow, bootFast = time.Millisecond, time.Millisecond, 0
	f := newFakeControl(t, 50)
	n := fakeTor(t, f.port())
	resetRoute(t, "starting", 0)

	done := make(chan struct{})
	go func() { watchBootstrap(n); close(done) }()
	// far more polls than the watcher used to allow
	time.Sleep(1500 * time.Millisecond)
	if bootPctNow() != 50 {
		t.Fatalf("watcher read %d%%, want 50%%", bootPctNow())
	}
	f.pct.Store(100)
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("the watcher never saw 100%")
	}
	if st := statusNow(); st != "publishing" {
		t.Fatalf("status %q once tor reached 100%%, want publishing", st)
	}
}

func bootPctNow() int {
	statusMu.RLock()
	defer statusMu.RUnlock()
	return bootstrapPct
}

func statusNow() string {
	statusMu.RLock()
	defer statusMu.RUnlock()
	return torStatus
}

// a bounce puts the percentage to 0 and tor says the same number as
// before: the watcher has to write it back, not take it for old news
func TestBootstrapWatchAfterABounce(t *testing.T) {
	oldP, oldS, oldF := bootPoll, bootPollSlow, bootFast
	defer func() { bootPoll, bootPollSlow, bootFast = oldP, oldS, oldF }()
	bootPoll, bootPollSlow, bootFast = 5*time.Millisecond, 5*time.Millisecond, time.Hour
	f := newFakeControl(t, 50)
	n := fakeTor(t, f.port())
	resetRoute(t, "starting", 0)
	go watchBootstrap(n)
	defer f.pct.Store(100)
	time.Sleep(100 * time.Millisecond)
	statusMu.Lock()
	bootstrapPct = 0
	statusMu.Unlock()
	routeBump()
	time.Sleep(200 * time.Millisecond)
	if p := bootPctNow(); p != 50 {
		t.Fatalf("after the bounce the watcher shows %d%%, tor says 50%%", p)
	}
}

// with no network there is nothing to climb, so it asks far less often
func TestBootstrapWatchSlowsOffline(t *testing.T) {
	oldP, oldS, oldF := bootPoll, bootPollSlow, bootFast
	defer func() {
		bootPoll, bootPollSlow, bootFast = oldP, oldS, oldF
		netOffline.Store(false)
	}()
	bootPoll, bootPollSlow, bootFast = 5*time.Millisecond, 200*time.Millisecond, time.Hour
	f := newFakeControl(t, 50)
	n := fakeTor(t, f.port())
	resetRoute(t, "starting", 0)
	go watchBootstrap(n)
	defer f.pct.Store(100)
	time.Sleep(50 * time.Millisecond)
	netOffline.Store(true)
	time.Sleep(250 * time.Millisecond)
	a := f.polls.Load()
	time.Sleep(500 * time.Millisecond)
	offline := f.polls.Load() - a
	if offline > 4 {
		t.Fatalf("%d polls in half a second with no network", offline)
	}
}
