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

// a linked device's tor: a client, no onion of its own. no tor here: a
// fake control port for the engine's own connection and a fake onion
// connection, the one tor adds and drops a service on

// the onion connection as tor answers it: in order, every command taken. a
// quiet one reads and holds its answers until it speaks again, as a control
// port that stopped answering and came back does
type bineSide struct {
	mu      sync.Mutex
	c       net.Conn
	quiet   bool
	pending int
	cmds    []string
}

func (b *bineSide) serve() {
	r := bufio.NewReader(b.c)
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return
		}
		b.mu.Lock()
		b.cmds = append(b.cmds, strings.TrimSpace(line))
		if b.quiet {
			b.pending++
			b.mu.Unlock()
			continue
		}
		b.mu.Unlock()
		fmt.Fprint(b.c, "250 OK\r\n")
	}
}

func (b *bineSide) speak() {
	b.mu.Lock()
	n := b.pending
	b.quiet, b.pending = false, 0
	b.mu.Unlock()
	for i := 0; i < n; i++ {
		fmt.Fprint(b.c, "250 OK\r\n")
	}
}

func (b *bineSide) sent() []string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return append([]string(nil), b.cmds...)
}

// a tor of this process with a published onion, made a client later: a
// control port for the engine's connection, the onion connection served by
// b, the service's local listener open
func clientRig(t *testing.T, quiet bool) (*tor.Tor, *bineSide, net.Listener) {
	t.Helper()
	f := newFakeControl(t, 100)
	n := fakeTor(t, f.port())
	a, c := net.Pipe()
	t.Cleanup(func() { a.Close(); c.Close() })
	b := &bineSide{c: c, quiet: quiet}
	go b.serve()
	onionMu.Lock()
	onionConn, onionSock, onionPort = control.NewConn(textproto.NewConn(a)), a, n.ControlPort
	onionMu.Unlock()
	t.Cleanup(onionReset)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	t.Cleanup(func() { ln.Close() })
	o := &tor.OnionService{ID: "fakeonionid", LocalListener: ln, Tor: n}
	mu.Lock()
	listener, myAddr = o, "fakeonionid.onion"
	mu.Unlock()
	resetRoute(t, "reachable", 100)
	publishedOnce.Store(true)
	t.Cleanup(func() {
		torClient.Store(false)
		mu.Lock()
		listener = nil
		mu.Unlock()
	})
	return n, b, ln
}

func listenerClosed(ln net.Listener) bool {
	c, err := net.DialTimeout("tcp", ln.Addr().String(), 300*time.Millisecond)
	if err != nil {
		return true
	}
	c.Close()
	return false
}

// a link in a process whose tor published the new device's onion: the onion
// goes on the onion connection, which added it, nothing more comes in, and the
// status says what a client's tor is. the same tor stays
func TestALinkTakesTheDevicesOnionDown(t *testing.T) {
	n, b, ln := clientRig(t, false)
	if r := torClientOn(); r != "ok" {
		t.Fatalf("made a client: %q", r)
	}
	if got := b.sent(); len(got) != 1 || got[0] != "DEL_ONION fakeonionid" {
		t.Fatalf("the onion connection got %q, want the onion's DEL_ONION alone", got)
	}
	if !listenerClosed(ln) {
		t.Fatal("the onion's local listener still takes connections")
	}
	mu.Lock()
	addr, l, same := myAddr, listener, torNode == n
	mu.Unlock()
	if addr != "" || l != nil {
		t.Fatalf("address %q and listener %v kept", addr, l)
	}
	if !same {
		t.Fatal("the tor was replaced")
	}
	if st := statusNow(); st != "bootstrapped" {
		t.Fatalf("status %q, want bootstrapped", st)
	}
	if publishedOnce.Load() {
		t.Fatal("still published once")
	}
	if line := statusLine(); !strings.HasPrefix(line, "bootstrapped|") {
		t.Fatalf("status line %q", line)
	}
	if directOpen() {
		t.Fatal("the direct route is open with no onion")
	}
	// a start from here on hands back the client, on the same tor
	if r := startListener(t.TempDir()); r != torClientAddr {
		t.Fatalf("start on a client: %q", r)
	}
	if len(b.sent()) != 1 {
		t.Fatalf("a start sent more: %q", b.sent())
	}
	mu.Lock()
	same = torNode == n
	mu.Unlock()
	if !same {
		t.Fatal("a start on a client made another tor")
	}
}

// the control port stops answering the take-down: the call comes back on
// its deadline, the address is forgotten and nothing comes in meanwhile.
// the onion connection is closed, which takes the service down with it, so
// the next start has nothing left to wait on
func TestAQuietControlPortCannotHoldTheTakeDown(t *testing.T) {
	setCtrlDeadline(t, 300*time.Millisecond)
	n, b, ln := clientRig(t, true)
	t0 := time.Now()
	r := torClientOn()
	if !strings.HasPrefix(r, "error: control port timeout") {
		t.Fatalf("a quiet control port gave %q", r)
	}
	if took := time.Since(t0); took > 2*time.Second {
		t.Fatalf("the take-down waited %s", took)
	}
	if !listenerClosed(ln) {
		t.Fatal("the onion's local listener still takes connections")
	}
	mu.Lock()
	addr, kept := myAddr, listener != nil
	mu.Unlock()
	if addr != "" || !kept {
		t.Fatalf("address %q, listener kept %v: want no address, the service kept to retry", addr, kept)
	}
	if st := statusNow(); st != "bootstrapped" {
		t.Fatalf("status %q, want bootstrapped", st)
	}
	onionMu.Lock()
	closed := onionConn == nil
	onionMu.Unlock()
	if !closed {
		t.Fatal("the onion connection, and the service on it, outlived the timeout")
	}
	if r := startListener(t.TempDir()); r != torClientAddr {
		t.Fatalf("a start after the take-down timed out: %q", r)
	}
	mu.Lock()
	kept, same := listener != nil, torNode == n
	mu.Unlock()
	if kept || !same {
		t.Fatalf("listener kept %v, same tor %v", kept, same)
	}
	if got := b.sent(); len(got) != 1 || got[0] != "DEL_ONION fakeonionid" {
		t.Fatalf("the onion connection got %q", got)
	}
}

// a start on a client while tor is asleep is refused as a phone's is, and a
// tor that ran in this process with no address of ours is never started
// again
func TestAClientStartNeverMakesASecondTor(t *testing.T) {
	f := newFakeControl(t, 100)
	n := fakeTor(t, f.port())
	mu.Lock()
	myAddr = ""
	mu.Unlock()
	torClient.Store(true)
	t.Cleanup(func() { torClient.Store(false) })
	resetRoute(t, "bootstrapped", 100)
	for i := 0; i < 3; i++ {
		if r := startListener(t.TempDir()); r != torClientAddr {
			t.Fatalf("start %d: %q", i, r)
		}
	}
	atomic.StoreInt32(&torPaused, 1)
	r := startListener(t.TempDir())
	atomic.StoreInt32(&torPaused, 0)
	if !strings.HasPrefix(r, "error: tor is stopped") {
		t.Fatalf("a start while asleep: %q", r)
	}
	mu.Lock()
	same := torNode == n
	mu.Unlock()
	if !same {
		t.Fatal("another tor")
	}
}

// at 100% a client is bootstrapped, never publishing: no publish clock
// starts, and the watch that brings an off tor back counts it as up
func TestAClientAtFullBootstrapIsBootstrapped(t *testing.T) {
	oldP, oldS, oldF := bootPoll, bootPollSlow, bootFast
	defer func() { bootPoll, bootPollSlow, bootFast = oldP, oldS, oldF }()
	bootPoll, bootPollSlow, bootFast = time.Millisecond, time.Millisecond, 0
	f := newFakeControl(t, 100)
	n := fakeTor(t, f.port())
	mu.Lock()
	myAddr = ""
	mu.Unlock()
	notePublished()
	if torUp() {
		t.Fatal("a phone's tor with no address counted as up")
	}
	torClient.Store(true)
	t.Cleanup(func() { torClient.Store(false) })
	resetRoute(t, "starting", 0)
	done := make(chan struct{})
	go func() { watchBootstrap(n); close(done) }()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("the watcher never saw 100%")
	}
	if st := statusNow(); st != "bootstrapped" {
		t.Fatalf("status %q at 100%%, want bootstrapped", st)
	}
	txMu.RLock()
	since := pubSince
	txMu.RUnlock()
	if !since.IsZero() {
		t.Fatal("a client started the publish clock")
	}
	if !torUp() {
		t.Fatal("a client's tor is not up for the watch")
	}
	// a relay through tor while it said starting: up, as a client
	resetRoute(t, "starting", 0)
	routeBump()
	routeNoteOK()
	if st := statusNow(); st != "bootstrapped" {
		t.Fatalf("status %q after a relay connected, want bootstrapped", st)
	}
	if !routeOK() {
		t.Fatal("a client cannot send although a relay connected through tor")
	}
}

// a client's tor watches no publish, after a start, a wake or a bounce
func TestAClientWatchesNoPublish(t *testing.T) {
	f := newFakeControl(t, 100)
	n := fakeTor(t, f.port())
	torClient.Store(true)
	t.Cleanup(func() { torClient.Store(false) })
	resetRoute(t, "bootstrapped", 100)
	goWatchPublished(n, "abcdefghijklmnop")
	if atomic.LoadInt32(&publishWatching) != 0 {
		t.Fatal("a publish watcher on a client")
	}
}

// with the switch off a phone's start is as it was: its address back, no
// take-down, the publishing status at 100%
func TestAPhoneStartIsAsItWas(t *testing.T) {
	_, b, ln := clientRig(t, false)
	torClient.Store(false)
	if r := startListener(t.TempDir()); r != "fakeonionid.onion" {
		t.Fatalf("a phone's start gave %q", r)
	}
	if len(b.sent()) != 0 || listenerClosed(ln) {
		t.Fatalf("a phone's onion was touched: %q", b.sent())
	}
	if upStatus() != "publishing" || !torUp() {
		t.Fatal("a phone at 100% is not publishing and up")
	}
}

// made a client while a start holds the lock, after that start looked: the
// call does not wait, and the onion goes as soon as the start lets go
func TestAStartUnderWayStillLosesItsOnion(t *testing.T) {
	_, b, ln := clientRig(t, false)
	startMu.Lock()
	t0 := time.Now()
	r := torClientOn()
	if took := time.Since(t0); r != "ok" || took > time.Second {
		startMu.Unlock()
		t.Fatalf("made a client with a start under way: %q after %s", r, took)
	}
	if len(b.sent()) != 0 {
		startMu.Unlock()
		t.Fatalf("the onion went under the start's lock: %q", b.sent())
	}
	startMu.Unlock()
	waitFor(t, "the onion to go", 2*time.Second, func() bool {
		mu.Lock()
		defer mu.Unlock()
		return listener == nil
	})
	if got := b.sent(); len(got) != 1 || got[0] != "DEL_ONION fakeonionid" {
		t.Fatalf("the onion connection got %q", got)
	}
	if !listenerClosed(ln) {
		t.Fatal("the onion's local listener still takes connections")
	}
}
