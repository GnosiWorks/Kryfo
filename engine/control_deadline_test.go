// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"bufio"
	"fmt"
	"net"
	"runtime"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// a control port that authenticates and then stops answering: the socket
// stays open, the command goes out, and no reply ever comes back.
type deadControl struct {
	ln      net.Listener
	answer  int32 // 1 = answer commands, 0 = go quiet after auth
	handled int64
}

func newDeadControl(t *testing.T) *deadControl {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	d := &deadControl{ln: ln}
	go d.serve()
	return d
}

func (d *deadControl) port() int { return d.ln.Addr().(*net.TCPAddr).Port }

func (d *deadControl) answers(on bool) {
	var v int32
	if on {
		v = 1
	}
	atomic.StoreInt32(&d.answer, v)
}

func (d *deadControl) serve() {
	for {
		c, err := d.ln.Accept()
		if err != nil {
			return
		}
		go d.handle(c)
	}
}

func (d *deadControl) handle(c net.Conn) {
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
			fmt.Fprint(c, "250-PROTOCOLINFO 1\r\n")
			fmt.Fprint(c, "250-AUTH METHODS=NULL\r\n")
			fmt.Fprint(c, "250-VERSION Tor=\"0.4.9.5\"\r\n")
			fmt.Fprint(c, "250 OK\r\n")
		case strings.HasPrefix(cmd, "AUTHENTICATE"):
			fmt.Fprint(c, "250 OK\r\n")
		default:
			atomic.AddInt64(&d.handled, 1)
			// the whole point: a command that is never answered.
			if atomic.LoadInt32(&d.answer) == 1 {
				fmt.Fprint(c, "250 OK\r\n")
			}
		}
	}
}

func (d *deadControl) close() { _ = d.ln.Close() }

// a control port that answers the handshake and then goes silent must not
// take the engine with it: the call gives up on its own deadline, the socket
// is dropped, and the very next call works once tor is answering again.
func TestControlPortNeverAnswers(t *testing.T) {
	old := ctrlDeadline
	ctrlDeadline = 700 * time.Millisecond
	defer func() { ctrlDeadline = old; ctrlReset() }()
	ctrlReset()

	d := newDeadControl(t)
	defer d.close()
	node := &tor.Tor{ControlPort: d.port()}

	before := runtime.NumGoroutine()
	dialsBefore := ctrlDialCount()

	// 1. the wedge. it must come back, and quickly.
	started := time.Now()
	err := ctrlDo(node, "SETCONF DisableNetwork 1", func(c *control.Conn) error {
		return c.SetConf(control.KeyVals("DisableNetwork", "1")...)
	})
	took := time.Since(started)
	if err == nil {
		t.Fatal("a control port that never answers returned no error")
	}
	if !strings.Contains(err.Error(), "timeout") {
		t.Fatalf("want a timeout, got %v", err)
	}
	if took > 3*time.Second {
		t.Fatalf("giving up took %s, deadline was %s", took, ctrlDeadline)
	}
	if ctrlDialCount() != dialsBefore+1 {
		t.Fatalf("want exactly one dial, got %d", ctrlDialCount()-dialsBefore)
	}

	// 2. the socket must be gone, not kept and reused out of step.
	ctrlMu.Lock()
	dropped := ctrlConn == nil && ctrlSock == nil
	ctrlMu.Unlock()
	if !dropped {
		t.Fatal("the wedged connection was kept")
	}

	// 3. three more attempts while it is still quiet: each one gives up on
	// its own, none of them inherits the last one's state.
	for i := 0; i < 3; i++ {
		if err := ctrlDo(node, "SETCONF", func(c *control.Conn) error {
			return c.SetConf(control.KeyVals("DisableNetwork", "1")...)
		}); err == nil {
			t.Fatalf("attempt %d somehow succeeded", i+2)
		}
	}

	// 4. tor starts answering again. the next call must work, with no
	// restart of anything and no help from the caller.
	d.answers(true)
	if err := ctrlDo(node, "SETCONF DisableNetwork 0", func(c *control.Conn) error {
		return c.SetConf(control.KeyVals("DisableNetwork", "0")...)
	}); err != nil {
		t.Fatalf("the call after the wedge cleared should work, got %v", err)
	}

	// 5. and it must not have left a goroutine behind per attempt
	time.Sleep(200 * time.Millisecond)
	runtime.GC()
	after := runtime.NumGoroutine()
	if after > before+4 {
		t.Fatalf("goroutines %d -> %d, something is parked", before, after)
	}
}

// the outcome slot must never be built out of itself, or each round nests
// the last one inside it.
func TestReconnectOutcomeDoesNotNest(t *testing.T) {
	reconnectStep = atomic.Value{}
	reconnectOutcome = atomic.Value{}
	atomic.StoreInt32(&reconnectRunning, 0)

	var lengths []int
	for i := 0; i < 50; i++ {
		noteStep("network off")
		noteOutcome("error: control port timeout on DisableNetwork 1 after 10s")
		out := lastReconnectOutcome()
		lengths = append(lengths, len(out))
		if strings.Count(out, "timeout") > 1 {
			t.Fatalf("round %d nested into itself: %q", i, out)
		}
	}
	if lengths[0] != lengths[len(lengths)-1] {
		t.Fatalf("the outcome grew from %d to %d chars over 50 rounds",
			lengths[0], lengths[len(lengths)-1])
	}
}

// while a reconnect is running the screen should say so, and say where it is,
// rather than showing the outcome of the one before it.
func TestOutcomeSaysRunningWhileRunning(t *testing.T) {
	reconnectStep = atomic.Value{}
	reconnectOutcome = atomic.Value{}
	noteOutcome("ok after 500ms")
	atomic.StoreInt32(&reconnectRunning, 1)
	noteStep("network off")
	defer atomic.StoreInt32(&reconnectRunning, 0)

	got := lastReconnectOutcome()
	if !strings.Contains(got, "running") || !strings.Contains(got, "network off") {
		t.Fatalf("want a running line naming the step, got %q", got)
	}
}
