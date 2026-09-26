// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"errors"
	"fmt"
	"log"
	"net"
	"net/textproto"
	"sync"
	"sync/atomic"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// tor's control port answers in about a millisecond when it is well, and
// never when it is not. bine gives no way to bound that: control.Conn hides
// its socket, and every call parks in ReadResponse until an answer arrives.
//
// so the engine dials the control port itself and keeps the net.Conn. a
// deadline on that socket turns a wedge into an error the caller can act on,
// and a socket that timed out is closed, which unparks whatever is reading
// it, and replaced on the next call. tor itself is never closed: 0.4.9.5
// survives exactly one shutdown per process and aborts on the second.

var (
	// held only for the length of one call, and every call carries a
	// deadline, so the wait on it is bounded. never taken with startMu held.
	ctrlMu   sync.Mutex
	ctrlConn *control.Conn
	ctrlSock net.Conn

	// how many times a call has been given up on. the test reads it, and
	// "stuck" on the transport screen is worth a look when it climbs.
	ctrlTimeouts int64
	ctrlDials    int64
)

// how long any one control command may take: far past anything healthy and
// still short enough that a watchdog is not left hanging. a var so the test
// that wedges a control port need not wait ten seconds a time.
var ctrlDeadline = 10 * time.Second

func ctrlTimeoutCount() int64 { return atomic.LoadInt64(&ctrlTimeouts) }
func ctrlDialCount() int64    { return atomic.LoadInt64(&ctrlDials) }

// dials and authenticates a fresh control connection. ctrlMu must be held.
func ctrlOpen(t *tor.Tor) error {
	if t == nil {
		return fmt.Errorf("no tor")
	}
	if t.ControlPort == 0 {
		return fmt.Errorf("no control port to dial")
	}
	nc, err := net.DialTimeout("tcp",
		fmt.Sprintf("127.0.0.1:%d", t.ControlPort), 5*time.Second)
	if err != nil {
		return fmt.Errorf("dial control port: %w", err)
	}
	// the handshake gets a deadline too. a tor that will not talk at all
	// must not turn into a permanent dial.
	_ = nc.SetDeadline(time.Now().Add(ctrlDeadline))
	c := control.NewConn(textproto.NewConn(nc))
	if err := c.Authenticate(""); err != nil {
		_ = nc.Close()
		return fmt.Errorf("authenticate control port: %w", err)
	}
	_ = nc.SetDeadline(time.Time{})
	ctrlConn, ctrlSock = c, nc
	atomic.AddInt64(&ctrlDials, 1)
	log.Printf("halo: control connection open on 127.0.0.1:%d", t.ControlPort)
	return nil
}

// closes the socket and forgets it. ctrlMu must be held. closing is the point:
// it is what unparks a read that tor is never going to answer.
func ctrlDrop() {
	if ctrlSock != nil {
		_ = ctrlSock.Close()
	}
	ctrlConn, ctrlSock = nil, nil
}

// drops the connection from outside, for a tor that is going away.
func ctrlReset() {
	ctrlMu.Lock()
	defer ctrlMu.Unlock()
	ctrlDrop()
}

func isTimeout(err error) bool {
	var ne net.Error
	if errors.As(err, &ne) {
		return ne.Timeout()
	}
	return false
}

// runs one control command against a connection the engine owns, under a
// deadline. on a timeout the connection is dropped: the textproto exchange is
// out of step once a reply is late, so it cannot be reused.
//
// "what" names the command for the log and for the reconnect record.
func ctrlDo(t *tor.Tor, what string, f func(*control.Conn) error) error {
	ctrlMu.Lock()
	defer ctrlMu.Unlock()

	if ctrlConn == nil {
		if err := ctrlOpen(t); err != nil {
			// no connection of our own: fall back to bine's, but never
			// block on it. the caller gets its deadline either way.
			return ctrlFallback(t, what, f)
		}
	}
	_ = ctrlSock.SetDeadline(time.Now().Add(ctrlDeadline))
	err := f(ctrlConn)
	if err == nil {
		_ = ctrlSock.SetDeadline(time.Time{})
		return nil
	}
	if isTimeout(err) {
		atomic.AddInt64(&ctrlTimeouts, 1)
		log.Printf("halo: control port did not answer %s within %s - dropping the connection",
			what, ctrlDeadline)
		ctrlDrop()
		return fmt.Errorf("control port timeout on %s", what)
	}
	// tor saying no is not the socket being broken: a 5xx reply comes back
	// as a textproto error and the exchange is still in step. anything else
	// is i/o, and the connection cannot be trusted after it.
	var te *textproto.Error
	if errors.As(err, &te) {
		_ = ctrlSock.SetDeadline(time.Time{})
		return err
	}
	log.Printf("halo: control connection broke on %s: %v", what, err)
	ctrlDrop()
	return err
}

// used only when we could not get a connection of our own, as an embedded
// control connection has no port to dial. bine's Conn cannot be given a
// deadline, so the call goes on its own goroutine and the caller leaves
// without it. that goroutine may stay parked; it holds nothing but itself.
func ctrlFallback(t *tor.Tor, what string, f func(*control.Conn) error) error {
	if t == nil || t.Control == nil {
		return fmt.Errorf("no control connection")
	}
	done := make(chan error, 1)
	go func() { done <- f(t.Control) }()
	select {
	case err := <-done:
		return err
	case <-time.After(ctrlDeadline):
		atomic.AddInt64(&ctrlTimeouts, 1)
		log.Printf("halo: control port did not answer %s within %s (no socket of our own to close)",
			what, ctrlDeadline)
		return fmt.Errorf("control port timeout on %s", what)
	}
}
