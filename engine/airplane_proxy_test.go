// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

package main

import (
	"encoding/binary"
	"io"
	"net"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// a socks5 proxy tor is pointed at with Socks5Proxy, so a test can take the
// whole network away and give it back. down is airplane mode as android
// does it: every open connection is torn down and every new one refused at
// once with "network unreachable".
type airplane struct {
	ln   net.Listener
	down atomic.Bool
	// a network that takes connections and carries nothing, as a captive
	// portal or a dead in-flight wifi does
	hole  atomic.Bool
	mu    sync.Mutex
	live  map[net.Conn]bool
	dials atomic.Int64
	fails atomic.Int64
}

func newAirplane(t *testing.T) *airplane {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	a := &airplane{ln: ln, live: map[net.Conn]bool{}}
	go a.serve()
	t.Cleanup(func() { _ = ln.Close() })
	return a
}

func (a *airplane) addr() string { return a.ln.Addr().String() }

// a network that swallows everything, on or off
func (a *airplane) blackhole(on bool) {
	a.hole.Store(on)
	if on {
		a.cut(true)
		a.down.Store(false)
	}
}

// airplane mode on or off
func (a *airplane) cut(on bool) {
	a.down.Store(on)
	if !on {
		return
	}
	a.mu.Lock()
	for c := range a.live {
		_ = c.Close()
	}
	a.live = map[net.Conn]bool{}
	a.mu.Unlock()
}

func (a *airplane) track(c net.Conn) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.down.Load() {
		return false
	}
	a.live[c] = true
	return true
}

func (a *airplane) forget(c net.Conn) {
	a.mu.Lock()
	delete(a.live, c)
	a.mu.Unlock()
}

func (a *airplane) serve() {
	for {
		c, err := a.ln.Accept()
		if err != nil {
			return
		}
		go a.handle(c)
	}
}

func (a *airplane) handle(c net.Conn) {
	defer c.Close()
	_ = c.SetDeadline(time.Now().Add(10 * time.Second))
	hdr := make([]byte, 2)
	if _, err := io.ReadFull(c, hdr); err != nil || hdr[0] != 5 {
		return
	}
	if _, err := io.ReadFull(c, make([]byte, hdr[1])); err != nil {
		return
	}
	if _, err := c.Write([]byte{5, 0}); err != nil {
		return
	}
	req := make([]byte, 4)
	if _, err := io.ReadFull(c, req); err != nil || req[1] != 1 {
		return
	}
	var host string
	switch req[3] {
	case 1:
		b := make([]byte, 4)
		if _, err := io.ReadFull(c, b); err != nil {
			return
		}
		host = net.IP(b).String()
	case 4:
		b := make([]byte, 16)
		if _, err := io.ReadFull(c, b); err != nil {
			return
		}
		host = net.IP(b).String()
	case 3:
		n := make([]byte, 1)
		if _, err := io.ReadFull(c, n); err != nil {
			return
		}
		b := make([]byte, n[0])
		if _, err := io.ReadFull(c, b); err != nil {
			return
		}
		host = string(b)
	default:
		return
	}
	pb := make([]byte, 2)
	if _, err := io.ReadFull(c, pb); err != nil {
		return
	}
	target := net.JoinHostPort(host, strconv.Itoa(int(binary.BigEndian.Uint16(pb))))
	a.dials.Add(1)
	if a.hole.Load() {
		_ = c.SetDeadline(time.Time{})
		_, _ = io.Copy(io.Discard, c)
		return
	}
	reply := func(code byte) {
		_, _ = c.Write([]byte{5, code, 0, 1, 0, 0, 0, 0, 0, 0})
	}
	if a.down.Load() {
		a.fails.Add(1)
		reply(3)
		return
	}
	up, err := net.DialTimeout("tcp", target, 10*time.Second)
	if err != nil {
		a.fails.Add(1)
		reply(5)
		return
	}
	defer up.Close()
	if !a.track(c) {
		a.fails.Add(1)
		reply(3)
		return
	}
	defer a.forget(c)
	a.mu.Lock()
	a.live[up] = true
	a.mu.Unlock()
	defer a.forget(up)
	reply(0)
	_ = c.SetDeadline(time.Time{})
	done := make(chan struct{}, 2)
	go func() { _, _ = io.Copy(up, c); done <- struct{}{} }()
	go func() { _, _ = io.Copy(c, up); done <- struct{}{} }()
	<-done
}
