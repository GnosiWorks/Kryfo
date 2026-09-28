// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bufio"
	"crypto/rand"
	"encoding/base64"
	"io"
	"log"
	"net"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cretz/bine/tor"
)

// a line the door takes: a whisper message of n random bytes
func doorLine(t *testing.T, n int) string {
	t.Helper()
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		t.Fatal(err)
	}
	b[0] = 2
	return base64.StdEncoding.EncodeToString(b)
}

// a door on a local port that counts its streams. serve is the handler: the
// engine's own, or one from before streams were kept.
type testDoor struct {
	ln      net.Listener
	streams int32
}

func newTestDoor(t *testing.T, serve func(net.Conn)) *testDoor {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	d := &testDoor{ln: ln}
	t.Cleanup(func() { ln.Close() })
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			atomic.AddInt32(&d.streams, 1)
			go serve(c)
		}
	}()
	return d
}

func (d *testDoor) count() int { return int(atomic.LoadInt32(&d.streams)) }

// an older door: one line, the ack, closed
func oldDoor(conn net.Conn) {
	defer conn.Close()
	conn.SetReadDeadline(time.Now().Add(10 * time.Second))
	r := bufio.NewReader(io.LimitReader(conn, inboxMaxLine+2))
	if _, err := r.ReadString('\n'); err != nil {
		return
	}
	conn.Write([]byte(doorAck))
}

// the engine pointed at the socks stand-in, with onions routed to doors
func doorSetup(t *testing.T, socks *socksStandIn, doors map[string]*testDoor) *tor.Tor {
	t.Helper()
	useStandIns(t, modePrivate, socks)
	for onion, d := range doors {
		socks.route[onion] = d.ln.Addr().String()
	}
	mu.Lock()
	inboxDrained()
	inbox = inbox[:0]
	inboxTokens = inboxBurst
	tn := torNode
	mu.Unlock()
	t.Cleanup(func() {
		doorCloseAll()
		doorMu.Lock()
		doorSingle = map[string]time.Time{}
		doorMu.Unlock()
		mu.Lock()
		inboxDrained()
		inbox = inbox[:0]
		mu.Unlock()
	})
	return tn
}

// sends every line, n at a time, and fails on any that was not acked
func sendAll(t *testing.T, tn *tor.Tor, onion string, lines []string, n int, one bool) {
	t.Helper()
	var wg sync.WaitGroup
	var next int32 = -1
	var failed int32
	for w := 0; w < n; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				i := int(atomic.AddInt32(&next, 1))
				if i >= len(lines) {
					return
				}
				var err error
				if one {
					err = sendOneLine(t.Context(), tn, onion, lines[i])
				} else {
					err = sendTo(tn, onion, lines[i])
				}
				if err != nil {
					atomic.AddInt32(&failed, 1)
					t.Logf("line %d: %v", i, err)
				}
			}
		}()
	}
	wg.Wait()
	if failed > 0 {
		t.Fatalf("%d of %d lines not acked", failed, len(lines))
	}
}

func doorInboxLen() int {
	mu.Lock()
	defer mu.Unlock()
	return len(inbox)
}

// lines to one onion share a stream; lines to another onion get their own
func TestDoorStreamPerOnion(t *testing.T) {
	socks := newSocksStandIn(t)
	a := newTestDoor(t, handleConn)
	b := newTestDoor(t, handleConn)
	tn := doorSetup(t, socks, map[string]*testDoor{"aaaa.onion": a, "bbbb.onion": b})
	var la, lb []string
	for i := 0; i < 20; i++ {
		la = append(la, doorLine(t, 2000))
		lb = append(lb, doorLine(t, 2000))
	}
	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); sendAll(t, tn, "aaaa.onion", la, 5, false) }()
	go func() { defer wg.Done(); sendAll(t, tn, "bbbb.onion", lb, 5, false) }()
	wg.Wait()
	if n := doorInboxLen(); n != 40 {
		t.Fatalf("inbox has %d lines, want 40", n)
	}
	if a.count() != 1 || b.count() != 1 {
		t.Fatalf("streams: %d to a, %d to b, want one each", a.count(), b.count())
	}
}

// an older door takes one line per stream. the sender notices at the
// first stream and goes back to a stream per line, and nothing is lost.
func TestOlderDoorGetsALinePerStream(t *testing.T) {
	socks := newSocksStandIn(t)
	d := newTestDoor(t, oldDoor)
	tn := doorSetup(t, socks, map[string]*testDoor{"old.onion": d})
	var lines []string
	for i := 0; i < 15; i++ {
		lines = append(lines, doorLine(t, 2000))
	}
	sendAll(t, tn, "old.onion", lines, 5, false)
	if !doorOneLineOnly("old.onion") {
		t.Fatal("the old door was not noticed")
	}
	// one stream per line, plus the lines that were waiting on the first
	if d.count() < 15 || d.count() > 15+5 {
		t.Fatalf("%d streams for 15 lines", d.count())
	}
}

// the sender lets a quiet stream go, and the next line dials a new one
func TestDoorStreamClosesWhenQuiet(t *testing.T) {
	old := doorKeep
	doorKeep = 200 * time.Millisecond
	defer func() { doorKeep = old }()
	socks := newSocksStandIn(t)
	d := newTestDoor(t, handleConn)
	tn := doorSetup(t, socks, map[string]*testDoor{"q.onion": d})
	sendAll(t, tn, "q.onion", []string{doorLine(t, 500), doorLine(t, 500)}, 2, false)
	waitFor(t, "the quiet stream let go", 5*time.Second, func() bool {
		doorMu.Lock()
		defer doorMu.Unlock()
		return len(doorStreams) == 0
	})
	sendAll(t, tn, "q.onion", []string{doorLine(t, 500)}, 1, false)
	if d.count() != 2 {
		t.Fatalf("%d streams, want two", d.count())
	}
}

// the door lets a stream go once no line has come for doorNextLine, and a
// sender that kept it longer still gets its line through on a new one
func TestDoorClosesAQuietStream(t *testing.T) {
	oldNext, oldKeep := doorNextLine, doorKeep
	doorNextLine, doorKeep = 200*time.Millisecond, time.Minute
	defer func() { doorNextLine, doorKeep = oldNext, oldKeep }()
	socks := newSocksStandIn(t)
	d := newTestDoor(t, handleConn)
	tn := doorSetup(t, socks, map[string]*testDoor{"n.onion": d})
	sendAll(t, tn, "n.onion", []string{doorLine(t, 500)}, 1, false)
	time.Sleep(600 * time.Millisecond)
	sendAll(t, tn, "n.onion", []string{doorLine(t, 500)}, 1, false)
	if n := doorInboxLen(); n != 2 {
		t.Fatalf("inbox has %d, want 2", n)
	}
	if d.count() != 2 {
		t.Fatalf("%d streams, want two", d.count())
	}
}

// a line past the limit still shuts the stream, whatever came before it
func TestDoorStreamRefusesAnOversizeLine(t *testing.T) {
	d := newTestDoor(t, handleConn)
	mu.Lock()
	inboxDrained()
	inbox = inbox[:0]
	inboxTokens = inboxBurst
	mu.Unlock()
	c, err := net.Dial("tcp", d.ln.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	c.SetDeadline(time.Now().Add(5 * time.Second))
	r := bufio.NewReader(c)
	c.Write([]byte(doorLine(t, 300) + "\n"))
	if s, _ := r.ReadString('\n'); s != doorAck {
		t.Fatalf("first line: %q", s)
	}
	go c.Write(append([]byte(doorLine(t, inboxMaxLine)), '\n'))
	if s, err := r.ReadString('\n'); err == nil {
		t.Fatalf("an oversize line was answered: %q", s)
	}
	mu.Lock()
	inboxDrained()
	inbox = inbox[:0]
	mu.Unlock()
}

// a file's slices to a peer's onion, a stream per line and on a kept stream,
// through the socks stand-in with tor's costs. slow, so only on request:
//
//	HALO_RELAY_MEASURE=1 go test -run TestMeasureDoorBurst -v -timeout 30m .
func TestMeasureDoorBurst(t *testing.T) {
	if os.Getenv("HALO_RELAY_MEASURE") == "" {
		t.Skip("HALO_RELAY_MEASURE not set")
	}
	slices, inflight := 150, 5
	if v, err := strconv.Atoi(os.Getenv("HALO_PUB_INFLIGHT")); err == nil {
		inflight = v
	}
	log.SetOutput(io.Discard)
	defer log.SetOutput(os.Stderr)
	for _, one := range []bool{true, false} {
		socks := newSocksStandIn(t)
		socks.connectDelay = 1200 * time.Millisecond
		socks.lag = 600 * time.Millisecond
		d := newTestDoor(t, handleConn)
		tn := doorSetup(t, socks, map[string]*testDoor{"peer.onion": d})
		var lines []string
		for i := 0; i < slices; i++ {
			// signal's ciphertext of a 16 KB base64 slice, in base64
			lines = append(lines, doorLine(t, 16500))
		}
		start := time.Now()
		sendAll(t, tn, "peer.onion", lines, inflight, one)
		how := "kept stream"
		if one {
			how = "a stream per line"
		}
		t.Logf("%s: %d slices, %d in flight, rtt 1.2s: %s, %d streams",
			how, slices, inflight, time.Since(start).Round(100*time.Millisecond), d.count())
		mu.Lock()
		inboxDrained()
		inbox = inbox[:0]
		mu.Unlock()
	}
}
