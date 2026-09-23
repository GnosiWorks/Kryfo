// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"log"
	"net"
	"net/textproto"
	"sync"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// events come over a control connection of their own.
//
// bine hands out one connection for everything, and reading an event on it
// holds its read lock until the next byte arrives - which may be never. any
// command on that connection then waits behind the read, with no deadline.
// on 2026-09-22 a redmi sat like that for twenty hours: bine's Dialer asked
// tor for the socks address over the shared connection (and re-enabled the
// network on the way, on a tor the app had just put to sleep), those calls
// parked behind a stale event read, every torNostrClient held the client
// mutex for the thirty seconds it gave the dialer, and the resume that was
// to bring tor back waited on that mutex - "running, at network on", for
// the night, with the reconnect button answering "one already running".
//
// so nothing asks bine's connection for anything any more. commands go over
// the engine's own connection (control_conn.go), dialers are built from a
// socks address the engine already knows (socksport.go), and events are
// read here, on a connection whose read lock is nobody else's business.

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
	if t == nil || t.ControlPort == 0 {
		return nil, fmt.Errorf("no control port to dial")
	}
	nc, err := net.DialTimeout("tcp",
		fmt.Sprintf("127.0.0.1:%d", t.ControlPort), 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("dial control port: %w", err)
	}
	_ = nc.SetDeadline(time.Now().Add(ctrlDeadline))
	c := control.NewConn(textproto.NewConn(nc))
	if err := c.Authenticate(""); err != nil {
		_ = nc.Close()
		return nil, fmt.Errorf("authenticate control port: %w", err)
	}
	_ = nc.SetDeadline(time.Time{})
	evConn, evSock = c, nc
	evGen++
	go pumpEvents(c, evGen)
	log.Printf("halo: event connection open on 127.0.0.1:%d", t.ControlPort)
	return c, nil
}

// reads events for as long as the connection lasts and hands them to the
// listeners bine keeps per connection. HandleNextEvent returns nil without
// reading when the next line is a command reply rather than an event - a
// SETEVENTS acknowledgement, say - so the loop yields a moment then, and
// the request that is waiting for that reply takes it.
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
