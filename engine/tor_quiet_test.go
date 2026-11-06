// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !windows

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

// a control port that stops answering at one step of the way: the start,
// the onion add, a bounce, a wake. no tor here: a fake control port, bine's
// connection dialled to it, tor's own start stood in for

// answers as tor does until a command starting with quietAt comes: from
// then on every command on every connection, a new one's handshake too, is
// read and never answered, until speak. it keeps the connections an
// ADD_ONION came in on, the ones tor would hold a service on
type quietPort struct {
	ln      net.Listener
	quietAt atomic.Value
	quiet   atomic.Bool
	// commands starting with this one alone go unanswered
	mute atomic.Value
	mu   sync.Mutex
	cmds []string
	held map[net.Conn]bool
	adds int
	// the connections subscribed to HS_DESC
	hs map[net.Conn]bool
}

func newQuietPort(t *testing.T, at string) *quietPort {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	q := &quietPort{ln: ln, held: map[net.Conn]bool{}, hs: map[net.Conn]bool{}}
	q.quietAt.Store(at)
	q.mute.Store("")
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go q.handle(c)
		}
	}()
	t.Cleanup(func() { _ = ln.Close() })
	return q
}

func (q *quietPort) port() int { return q.ln.Addr().(*net.TCPAddr).Port }

func (q *quietPort) speak() {
	q.quietAt.Store("")
	q.mute.Store("")
	q.quiet.Store(false)
}

// tor answers again, all but commands starting with cmd
func (q *quietPort) speakBut(cmd string) {
	q.mute.Store(cmd)
	q.quietAt.Store("")
	q.quiet.Store(false)
}

func (q *quietPort) goQuietAt(at string) { q.quietAt.Store(at) }

func (q *quietPort) handle(c net.Conn) {
	defer func() {
		q.mu.Lock()
		delete(q.held, c)
		delete(q.hs, c)
		q.mu.Unlock()
		c.Close()
	}()
	r := bufio.NewReader(c)
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return
		}
		cmd := strings.ToUpper(strings.TrimSpace(line))
		if at := q.quietAt.Load().(string); at != "" && strings.HasPrefix(cmd, at) {
			q.quiet.Store(true)
		}
		q.mu.Lock()
		q.cmds = append(q.cmds, cmd)
		switch {
		case strings.HasPrefix(cmd, "ADD_ONION"):
			q.adds++
			q.held[c] = true
		case strings.HasPrefix(cmd, "DEL_ONION"):
			delete(q.held, c)
		}
		q.mu.Unlock()
		if q.quiet.Load() {
			continue
		}
		if m := q.mute.Load().(string); m != "" && strings.HasPrefix(cmd, m) {
			continue
		}
		if strings.HasPrefix(cmd, "SETEVENTS") {
			q.mu.Lock()
			if strings.Contains(cmd, "HS_DESC") {
				q.hs[c] = true
			} else {
				delete(q.hs, c)
			}
			q.mu.Unlock()
		}
		switch {
		case strings.HasPrefix(cmd, "PROTOCOLINFO"):
			fmt.Fprint(c, "250-PROTOCOLINFO 1\r\n250-AUTH METHODS=NULL\r\n250-VERSION Tor=\"0.4.9.15\"\r\n250 OK\r\n")
		case strings.HasPrefix(cmd, "GETINFO STATUS/BOOTSTRAP-PHASE"):
			fmt.Fprint(c, "250-status/bootstrap-phase=NOTICE BOOTSTRAP PROGRESS=100 TAG=done SUMMARY=\"Done\"\r\n250 OK\r\n")
		case strings.HasPrefix(cmd, "GETINFO STATUS/CIRCUIT-ESTABLISHED"):
			fmt.Fprint(c, "250-status/circuit-established=1\r\n250 OK\r\n")
		case strings.HasPrefix(cmd, "ADD_ONION"):
			fmt.Fprintf(c, "250-ServiceID=%s\r\n250 OK\r\n", strings.Repeat("q", 56))
		default:
			fmt.Fprint(c, "250 OK\r\n")
		}
	}
}

// how many ADD_ONIONs came, and on how many open connections a service
// would be up
func (q *quietPort) services() (adds, live int) {
	q.mu.Lock()
	defer q.mu.Unlock()
	return q.adds, len(q.held)
}

// tor says it uploaded addr's descriptor, to every HS_DESC subscriber.
// how many heard it
func (q *quietPort) uploaded(addr string) int {
	q.mu.Lock()
	defer q.mu.Unlock()
	for c := range q.hs {
		fmt.Fprintf(c, "650 HS_DESC UPLOADED %s UNKNOWN $AAAA\r\n", addr)
	}
	return len(q.hs)
}

func (q *quietPort) saw(prefix string) int {
	q.mu.Lock()
	defer q.mu.Unlock()
	n := 0
	for _, c := range q.cmds {
		if strings.HasPrefix(c, prefix) {
			n++
		}
	}
	return n
}

// a process with no tor yet whose start makes one on q, with bine's own
// connection dialled to it as bine does. the watchers stay off: their
// slots are taken. the retry waits are short
func quietRig(t *testing.T, q *quietPort) (*tor.Tor, *int) {
	t.Helper()
	setCtrlDeadline(t, 200*time.Millisecond)
	n := fakeTor(t, q.port())
	tc, err := textproto.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", q.port()))
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	t.Cleanup(func() { tc.Close() })
	n.Control = control.NewConn(tc)
	mu.Lock()
	torNode, myAddr = nil, ""
	mu.Unlock()
	resetRoute(t, "starting", 0)
	pin, off := atomic.LoadInt32(&pinnedSocks), torNetOff.Load()
	first, most := onionRetryFirst, onionRetryMax
	onionRetryFirst, onionRetryMax = 100*time.Millisecond, 200*time.Millisecond
	waitFor(t, "the watcher slots", 5*time.Second, func() bool {
		return atomic.CompareAndSwapInt32(&bootstrapWatching, 0, 1)
	})
	waitFor(t, "the watcher slots", 5*time.Second, func() bool {
		return atomic.CompareAndSwapInt32(&publishWatching, 0, 1)
	})
	t.Cleanup(func() {
		mu.Lock()
		l, _ := listener.(*tor.OnionService)
		listener, torNode, myAddr = nil, nil, ""
		mu.Unlock()
		if l != nil && l.LocalListener != nil {
			l.LocalListener.Close()
		}
		torGoneNow()
		waitFor(t, "the onion retry to let go", 5*time.Second, func() bool {
			return !onionRetrying.Load()
		})
		onionRetryFirst, onionRetryMax = first, most
		atomic.StoreInt32(&bootstrapWatching, 0)
		atomic.StoreInt32(&publishWatching, 0)
		eventReset()
		onionReset()
		atomic.StoreInt32(&pinnedSocks, pin)
		torNetOff.Store(off)
		nostrResetClient()
	})
	return n, standInStart(t, n)
}

// a start, which must come back within limit
func startWithin(t *testing.T, dir string, limit time.Duration) string {
	t.Helper()
	done := make(chan string, 1)
	t0 := time.Now()
	go func() { done <- startListener(dir) }()
	select {
	case r := <-done:
		t.Logf("start came back in %s: %q", time.Since(t0).Round(time.Millisecond), r)
		return r
	case <-time.After(limit):
		t.Fatalf("a start still held after %s", limit)
	}
	return ""
}

func addrNow() string {
	mu.Lock()
	defer mu.Unlock()
	return myAddr
}

var quietOnion = strings.Repeat("q", 56) + ".onion"

// quiet from tor's first word: the start comes back on its deadlines with
// tor kept, and once tor answers the onion goes up on that same tor
func TestAQuietStartHoldsNoLaterStart(t *testing.T) {
	q := newQuietPort(t, "PROTOCOLINFO")
	n, calls := quietRig(t, q)
	dir := t.TempDir()
	r := startWithin(t, dir, 5*time.Second)
	if !strings.HasPrefix(r, "error: listen:") {
		t.Fatalf("a quiet start: %q", r)
	}
	mu.Lock()
	kept := torNode == n
	mu.Unlock()
	if !kept || *calls != 1 {
		t.Fatalf("tor kept %v, started %d times", kept, *calls)
	}
	if !torUp() {
		t.Fatal("a tor waiting on its onion is not counted as up, so an off one is never rescued")
	}
	// a later start (a wake, the watchdog) is not held either
	if r := startWithin(t, dir, 5*time.Second); !strings.HasPrefix(r, "error:") {
		t.Fatalf("a second start on a quiet tor: %q", r)
	}
	q.speak()
	waitFor(t, "the onion on the same tor", 5*time.Second, func() bool {
		return addrNow() == quietOnion
	})
	if *calls != 1 {
		t.Fatalf("tor started %d times", *calls)
	}
	if adds, live := q.services(); live != 1 {
		t.Fatalf("%d adds, %d services up", adds, live)
	}
	if r := startWithin(t, dir, time.Second); r != quietOnion {
		t.Fatalf("the start after: %q", r)
	}
}

// quiet at the onion add: tor runs on without it, the status says the
// address is still on its way, the add goes again on the same tor and only
// one service is ever up
func TestAQuietOnionAddRunsWithoutItAndRetries(t *testing.T) {
	oldP := bootPoll
	bootPoll = time.Millisecond
	t.Cleanup(func() { bootPoll = oldP })
	q := newQuietPort(t, "ADD_ONION")
	n, calls := quietRig(t, q)
	dir := t.TempDir()
	r := startWithin(t, dir, 5*time.Second)
	if !strings.HasPrefix(r, "error: listen: control port timeout on ADD_ONION") {
		t.Fatalf("a quiet add: %q", r)
	}
	// the add's connection went, and with it what tor may have added
	if adds, live := q.services(); adds != 1 || live != 0 {
		t.Fatalf("%d adds, %d services up after the timeout", adds, live)
	}
	if !torUp() || addrNow() != "" {
		t.Fatalf("up %v, address %q", torUp(), addrNow())
	}
	// tor at 100% with no address: publishing, never reachable
	q.speakBut("ADD_ONION")
	done := make(chan struct{})
	go func() { watchBootstrap(n); close(done) }()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("the watcher never saw 100%")
	}
	if line := statusLine(); !strings.HasPrefix(line, "publishing|100|") {
		t.Fatalf("status line %q while the onion waits", line)
	}
	q.speak()
	waitFor(t, "the onion on the same tor", 5*time.Second, func() bool {
		return addrNow() == quietOnion
	})
	if adds, live := q.services(); adds < 2 || live != 1 {
		t.Fatalf("%d adds, %d services up", adds, live)
	}
	if *calls != 1 {
		t.Fatalf("tor started %d times", *calls)
	}
	mu.Lock()
	same := torNode == n
	mu.Unlock()
	if !same {
		t.Fatal("another tor")
	}
	// up: no more tries
	time.Sleep(400 * time.Millisecond)
	if adds, live := q.services(); live != 1 || onionRetrying.Load() {
		t.Fatalf("%d adds, %d up, still retrying %v", adds, live, onionRetrying.Load())
	}
}

// the HS_DESC subscription never answered: the start is not held by it and
// the onion still goes up
func TestAQuietSubscriptionHoldsNoStart(t *testing.T) {
	q := newQuietPort(t, "")
	q.speakBut("SETEVENTS")
	_, calls := quietRig(t, q)
	if r := startWithin(t, t.TempDir(), 5*time.Second); r != quietOnion {
		t.Fatalf("a start: %q", r)
	}
	if q.saw("SETEVENTS") == 0 || *calls != 1 {
		t.Fatalf("%d subscriptions, %d starts", q.saw("SETEVENTS"), *calls)
	}
}

// a tor up with its onion, then quiet at a bounce: the bounce comes back,
// the service stays, and a start after it is not held
func TestAQuietBounceHoldsNoStart(t *testing.T) {
	q := newQuietPort(t, "")
	_, calls := quietRig(t, q)
	dir := t.TempDir()
	if r := startWithin(t, dir, 5*time.Second); r != quietOnion {
		t.Fatalf("the start: %q", r)
	}
	q.goQuietAt("SETCONF DISABLENETWORK")
	atomic.StoreInt64(&lastTorRestart, 0)
	sent := q.saw("SETCONF DISABLENETWORK")
	done := make(chan string, 1)
	go func() { done <- reconnectTor() }()
	select {
	case r := <-done:
		if !strings.HasPrefix(r, "error: control port timeout") || q.saw("SETCONF DISABLENETWORK") == sent {
			t.Fatalf("a quiet bounce: %q", r)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("a quiet bounce never came back")
	}
	if r := startWithin(t, dir, 2*time.Second); r != quietOnion {
		t.Fatalf("a start after the bounce: %q", r)
	}
	if _, live := q.services(); live != 1 {
		t.Fatalf("%d services up after a bounce", live)
	}
	if *calls != 1 {
		t.Fatalf("tor started %d times", *calls)
	}
}

// asleep, then quiet at the wake: the wake comes back refused, a start is
// not held, and the wake goes once tor answers
func TestAQuietWakeHoldsNoStart(t *testing.T) {
	q := newQuietPort(t, "")
	_, calls := quietRig(t, q)
	dir := t.TempDir()
	if r := startWithin(t, dir, 5*time.Second); r != quietOnion {
		t.Fatalf("the start: %q", r)
	}
	keepNetOn(t)
	if r := torStop(); r != "ok" {
		t.Fatalf("sleep: %q", r)
	}
	t.Cleanup(func() { atomic.StoreInt32(&torPaused, 0) })
	q.goQuietAt("SETCONF")
	done := make(chan string, 1)
	go func() { done <- torResume() }()
	select {
	case r := <-done:
		if !strings.HasPrefix(r, "error: control port timeout") {
			t.Fatalf("a quiet wake: %q", r)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("a quiet wake never came back")
	}
	if r := startWithin(t, dir, 2*time.Second); r != quietOnion {
		t.Fatalf("a start after the wake: %q", r)
	}
	q.speak()
	if r := torResume(); strings.HasPrefix(r, "error:") {
		t.Fatalf("the wake once tor answers: %q", r)
	}
	if _, live := q.services(); live != 1 {
		t.Fatalf("%d services up", live)
	}
	if *calls != 1 {
		t.Fatalf("tor started %d times", *calls)
	}
}

// the HS_DESC subscription of a start ran out, or its event connection went
// later (a SETEVENTS that ran out elsewhere closes it): the watch subscribes
// again and the onion that is up turns reachable
func TestAQuietSubscriptionIsMadeAgain(t *testing.T) {
	setCtrlDeadline(t, 200*time.Millisecond)
	hsdirWaitNs.Store(int64(300 * time.Millisecond))
	t.Cleanup(func() { hsdirWaitNs.Store(0) })
	// no other test's watch starts meanwhile
	waitFor(t, "the watcher slot", 5*time.Second, func() bool {
		return atomic.CompareAndSwapInt32(&publishWatching, 0, 1)
	})
	t.Cleanup(func() { atomic.StoreInt32(&publishWatching, 0) })
	q := newQuietPort(t, "")
	n := fakeTor(t, q.port())
	t.Cleanup(eventReset)
	onion := strings.Repeat("r", 56)
	for _, later := range []bool{false, true} {
		publishedForTest(t)
		statusForTest(t, "publishing")
		eventReset()
		if later {
			q.speak()
		} else {
			q.speakBut("SETEVENTS")
		}
		hsCh, subbed := listenForUploads(n)
		if subbed != later {
			t.Fatalf("later %v: subscribed %v", later, subbed)
		}
		if !later {
			q.speak()
		}
		done := make(chan struct{})
		go func() { watchPublishedOn(n, hsCh, subbed, onion); close(done) }()
		if later {
			// mid-watch the shared connection goes, as an observer's
			// timeout drops it
			time.Sleep(100 * time.Millisecond)
			eventReset()
		}
		// the watch unsubscribes as it ends, so the upload is said until
		// someone heard it
		heard := false
		waitFor(t, "a subscription that hears", 5*time.Second, func() bool {
			if !heard {
				heard = q.uploaded(onion) > 0
			}
			return heard && torStatusNow() == "reachable"
		})
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			t.Fatal("the watch never ended")
		}
		if _, known := uploadSubs.Load(hsCh); known {
			t.Fatalf("later %v: the subscription outlived its watch", later)
		}
	}
}
