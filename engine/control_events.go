// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"log"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// events come over a control connection of their own. reading an event on
// bine's shared connection holds its read lock until the next byte arrives,
// which may be never, and every command behind it waits with no deadline.
// commands use control_conn.go and dialers socksport.go for the same reason.

var (
	evMu   sync.Mutex
	evConn *control.Conn
	evSock net.Conn
	evGen  int
)

// the event connection, opened on first use and pumped by its own
// goroutine. ctrlMu is not involved.
func eventConn(t *tor.Tor) (*control.Conn, error) {
	evMu.Lock()
	defer evMu.Unlock()
	if evConn != nil {
		return evConn, nil
	}
	c, nc, err := ctrlDial(t)
	if err != nil {
		return nil, err
	}
	evConn, evSock = c, nc
	evGen++
	go pumpEvents(c, evGen)
	log.Printf("halo: event connection open on 127.0.0.1:%d", t.ControlPort)
	return c, nil
}

// reads events for as long as the connection lasts and hands them to the
// listeners bine keeps per connection. HandleNextEvent returns nil without
// reading when the next line is a command reply (a SETEVENTS ack, say), so
// the loop yields a moment and the request waiting for that reply takes it.
func pumpEvents(c *control.Conn, gen int) {
	for {
		err := c.HandleNextEvent()
		if err == nil {
			time.Sleep(20 * time.Millisecond)
			continue
		}
		evMu.Lock()
		if evGen == gen {
			if evSock != nil {
				_ = evSock.Close()
			}
			evConn, evSock = nil, nil
		}
		evMu.Unlock()
		log.Printf("halo: event connection ended: %v", err)
		return
	}
}

// a SETEVENTS on event connection c, under the control deadline. the pump
// holds c's read side, so the socket cannot carry a deadline of its own: the
// call goes on a goroutine, and one that runs out closes c, which unparks
// both. the next subscriber opens a new connection
func evDo(c *control.Conn, what string, f func() error) error {
	done := make(chan error, 1)
	go func() { done <- f() }()
	select {
	case err := <-done:
		return err
	case <-time.After(ctrlDeadline()):
	}
	atomic.AddInt64(&ctrlTimeouts, 1)
	log.Printf("halo: control port did not answer %s within %s, dropping the event connection",
		what, ctrlDeadline())
	evMu.Lock()
	if evConn == c {
		if evSock != nil {
			_ = evSock.Close()
		}
		evConn, evSock = nil, nil
	}
	evMu.Unlock()
	return fmt.Errorf("control port timeout on %s", what)
}

// drops the connection, for a tor that is going away. the next subscriber
// opens a new one.
func eventReset() {
	evMu.Lock()
	defer evMu.Unlock()
	if evSock != nil {
		_ = evSock.Close()
	}
	evConn, evSock = nil, nil
}
