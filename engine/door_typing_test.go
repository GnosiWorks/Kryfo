// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"log"
	"net"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// a door that acks every line and says nothing, so only the sender's side
// is in the log
func quietDoor(conn net.Conn) {
	defer conn.Close()
	r := bufio.NewReader(conn)
	for {
		if _, err := r.ReadString('\n'); err != nil {
			return
		}
		conn.Write([]byte(doorAck))
	}
}

// a door that reads lines and never acks one
func muteDoor(conn net.Conn) {
	defer conn.Close()
	r := bufio.NewReader(conn)
	for {
		if _, err := r.ReadString('\n'); err != nil {
			return
		}
	}
}

func socksStreams(s *socksStandIn) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.streams
}

// off the private route a typing line goes nowhere: no dial, no stream
func TestTypingLineOnlyOnOnion(t *testing.T) {
	for _, mode := range []string{modeBalanced, modeFast} {
		socks := newSocksStandIn(t)
		d := newTestDoor(t, handleConn)
		tn := doorSetup(t, socks, map[string]*testDoor{"t.onion": d})
		transportMode.Store(mode)
		if err := sendTyping(tn, "t.onion", doorLine(t, 900)); err != errTypingRoute {
			t.Fatalf("%s: %v, want the route refusal", mode, err)
		}
		if n := socksStreams(socks); n != 0 || d.count() != 0 {
			t.Fatalf("%s: %d socks streams, %d door streams", mode, n, d.count())
		}
	}
}

// only a short whisper line to an onion: an opener, json, a long line or a
// host that is not an onion is refused before any dial
func TestTypingLineShape(t *testing.T) {
	socks := newSocksStandIn(t)
	d := newTestDoor(t, handleConn)
	tn := doorSetup(t, socks, map[string]*testDoor{"t.onion": d})
	prekey := make([]byte, 900)
	prekey[0] = 3
	cases := map[string][2]string{
		"opener":    {"t.onion", base64.StdEncoding.EncodeToString(prekey)},
		"json":      {"t.onion", `{"ty":1}`},
		"long":      {"t.onion", doorLine(t, typingLineMost)},
		"clearnet":  {"relay.kryfo.app", doorLine(t, 900)},
		"with port": {"t.onion:443", doorLine(t, 900)},
	}
	for name, c := range cases {
		if err := sendTyping(tn, c[0], c[1]); err == nil {
			t.Fatalf("%s: sent", name)
		}
	}
	if n := socksStreams(socks); n != 0 {
		t.Fatalf("%d streams for refused lines", n)
	}
}

// a door that never acks: the call gives up inside its budget, on the one
// stream it dialled, and dials no other
func TestTypingLineGivesUpInBudget(t *testing.T) {
	old := typingBudget
	typingBudget = 400 * time.Millisecond
	defer func() { typingBudget = old }()
	socks := newSocksStandIn(t)
	d := newTestDoor(t, muteDoor)
	tn := doorSetup(t, socks, map[string]*testDoor{"m.onion": d})
	start := time.Now()
	err := sendTyping(tn, "m.onion", doorLine(t, 900))
	took := time.Since(start)
	if err == nil {
		t.Fatal("a line nobody acked counts as sent")
	}
	if took > typingBudget+300*time.Millisecond {
		t.Fatalf("took %s on a %s budget", took, typingBudget)
	}
	time.Sleep(300 * time.Millisecond)
	if d.count() != 1 || socksStreams(socks) != 1 {
		t.Fatalf("%d door streams, %d socks streams, want one", d.count(), socksStreams(socks))
	}
}

// a typing line right after a text to the same onion rides its stream
func TestTypingLineUsesKeptStream(t *testing.T) {
	socks := newSocksStandIn(t)
	d := newTestDoor(t, handleConn)
	tn := doorSetup(t, socks, map[string]*testDoor{"k.onion": d})
	sendAll(t, tn, "k.onion", []string{doorLine(t, 2000)}, 1, false)
	if err := sendTyping(tn, "k.onion", doorLine(t, 900)); err != nil {
		t.Fatal(err)
	}
	if d.count() != 1 {
		t.Fatalf("%d streams, want the kept one", d.count())
	}
	if n := doorInboxLen(); n != 2 {
		t.Fatalf("inbox has %d, want 2", n)
	}
}

// to a door that takes one line per stream it goes on one of its own
func TestTypingLineToAnOlderDoor(t *testing.T) {
	socks := newSocksStandIn(t)
	d := newTestDoor(t, oldDoor)
	tn := doorSetup(t, socks, map[string]*testDoor{"o.onion": d})
	doorMu.Lock()
	doorSingle["o.onion"] = time.Now().Add(time.Minute)
	doorMu.Unlock()
	if err := sendTyping(tn, "o.onion", doorLine(t, 900)); err != nil {
		t.Fatal(err)
	}
	if d.count() != 1 {
		t.Fatalf("%d streams", d.count())
	}
}

// nothing a typing line does is logged, sent or failed, and what dart hears
// of a failure never names the onion
func TestTypingLineLogsNoOnion(t *testing.T) {
	old := typingBudget
	typingBudget = 300 * time.Millisecond
	defer func() { typingBudget = old }()
	var buf bytes.Buffer
	log.SetOutput(&buf)
	defer log.SetOutput(os.Stderr)
	socks := newSocksStandIn(t)
	ok := newTestDoor(t, quietDoor)
	mute := newTestDoor(t, muteDoor)
	tn := doorSetup(t, socks, map[string]*testDoor{
		"sentto.onion": ok,
		"muteto.onion": mute,
	})
	line := doorLine(t, 900)
	if err := sendTyping(tn, "sentto.onion", line); err != nil {
		t.Fatal(err)
	}
	var whys []string
	for _, onion := range []string{"muteto.onion", "nobodyat.onion"} {
		err := sendTyping(tn, onion, doorLine(t, 900))
		if err == nil {
			t.Fatalf("%s: sent", onion)
		}
		whys = append(whys, typingWhy(err))
	}
	time.Sleep(200 * time.Millisecond)
	out := buf.String() + strings.Join(whys, "\n")
	for _, bad := range []string{"sentto", "muteto", "nobodyat", strconv.Itoa(len(line))} {
		if strings.Contains(out, bad) {
			t.Fatalf("output names %q:\n%s", bad, out)
		}
	}
}

// a door that ends each stream as the third line on it comes in, unread,
// as handleConn does when doorLife runs out under a line
type lifeDoor struct{ took int32 }

func (l *lifeDoor) serve(conn net.Conn) {
	defer conn.Close()
	r := bufio.NewReader(conn)
	for n := 0; ; n++ {
		if _, err := r.ReadString('\n'); err != nil || n == 2 {
			return
		}
		atomic.AddInt32(&l.took, 1)
		conn.Write([]byte(doorAck))
	}
}

// steady typing keeps one stream busy until the door ends it, and the line
// caught in that close still gets through, on one new stream
func TestTypingLineOutlivesTheDoorsStreamLife(t *testing.T) {
	socks := newSocksStandIn(t)
	l := &lifeDoor{}
	d := newTestDoor(t, l.serve)
	tn := doorSetup(t, socks, map[string]*testDoor{"life.onion": d})
	for i := 0; i < 5; i++ {
		if err := sendTyping(tn, "life.onion", doorLine(t, 900)); err != nil {
			t.Fatalf("line %d: %v", i, err)
		}
	}
	if n := atomic.LoadInt32(&l.took); n != 5 {
		t.Fatalf("the door took %d of 5", n)
	}
	if d.count() != 3 {
		t.Fatalf("%d streams, want 3", d.count())
	}
}

// a typing dial that runs out of its short budget leaves a text to the
// same onion, waiting on that dial, to dial again on its own budget
func TestTypingDialTimeoutSparesARealSend(t *testing.T) {
	old := typingBudget
	typingBudget = 300 * time.Millisecond
	defer func() { typingBudget = old }()
	socks := newSocksStandIn(t)
	socks.connectDelay = 600 * time.Millisecond
	d := newTestDoor(t, handleConn)
	tn := doorSetup(t, socks, map[string]*testDoor{"slow.onion": d})
	typed := make(chan error, 1)
	go func() { typed <- sendTyping(tn, "slow.onion", doorLine(t, 900)) }()
	time.Sleep(50 * time.Millisecond)
	if err := sendTo(tn, "slow.onion", doorLine(t, 2000)); err != nil {
		t.Fatalf("the text failed with the typing dial: %v", err)
	}
	if err := <-typed; err == nil {
		t.Fatal("the typing line beat its own budget")
	}
}
