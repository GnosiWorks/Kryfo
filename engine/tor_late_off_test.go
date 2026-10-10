// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// a reconnect's "network off" goes out, tor takes it, and the answer comes
// after the deadline: on a slow phone tor's main loop can be busy that long.
// the reconnect gives up and says off, and tor is off the network for good:
//
//	go test -tags torconf -run TestLateNetworkOffIsRescued -v .
package main

import (
	"bufio"
	"io"
	"net"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// a control port in front of tor's that holds tor's answers back for a
// while after it passes on a DisableNetwork=1
type slowControl struct {
	ln     net.Listener
	target string
	hold   time.Duration
	on     atomic.Bool
	until  atomic.Int64
}

func newSlowControl(t *testing.T, target string, hold time.Duration) *slowControl {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	s := &slowControl{ln: ln, target: target, hold: hold}
	s.on.Store(true)
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go s.pipe(c)
		}
	}()
	t.Cleanup(func() { _ = ln.Close() })
	return s
}

func (s *slowControl) port() int { return s.ln.Addr().(*net.TCPAddr).Port }

func (s *slowControl) pipe(c net.Conn) {
	defer c.Close()
	up, err := net.Dial("tcp", s.target)
	if err != nil {
		return
	}
	defer up.Close()
	go func() {
		r := bufio.NewReader(c)
		for {
			line, err := r.ReadString('\n')
			if err != nil {
				up.Close()
				return
			}
			if s.on.Load() && strings.Contains(strings.ToUpper(line), "DISABLENETWORK=1") {
				s.until.Store(time.Now().Add(s.hold).UnixNano())
			}
			if _, err := io.WriteString(up, line); err != nil {
				return
			}
		}
	}()
	buf := make([]byte, 4096)
	for {
		n, err := up.Read(buf)
		if err != nil {
			return
		}
		if d := time.Until(time.Unix(0, s.until.Load())); d > 0 {
			time.Sleep(d)
		}
		if _, err := c.Write(buf[:n]); err != nil {
			return
		}
	}
}

func TestLateNetworkOffIsRescued(t *testing.T) {
	dir := t.TempDir()
	if addr := startListener(dir); strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	if pct, took := waitBoot(4 * time.Minute); pct < 100 {
		t.Skipf("tor only reached %d%% here", pct)
	} else {
		t.Logf("cold start: 100%% in %s", took.Round(time.Millisecond))
	}
	startRunners(t, 3)
	up := time.Now()
	for time.Since(up) < 2*time.Minute && !routeOK() {
		time.Sleep(time.Second)
	}
	if !routeOK() {
		t.Skipf("the route never came up: %s", routeLine())
	}

	n := node(t)
	real := n.ControlPort
	slow := newSlowControl(t, "127.0.0.1:"+strconv.Itoa(real), 3*time.Second)
	old := ctrlDeadline
	ctrlDeadline = time.Second
	defer func() { ctrlDeadline = old; n.ControlPort = real; ctrlReset(); eventReset() }()
	n.ControlPort = slow.port()
	ctrlReset()
	eventReset()

	// a network change: the bounce's first command is answered too late
	r := reconnectTor()
	t.Logf("reconnect: %s, %s", r, routeLine())
	if !strings.HasPrefix(r, "error:") {
		t.Skipf("the late answer did not time out: %s", r)
	}
	time.Sleep(4 * time.Second)
	if v := conf(t, "DisableNetwork")["DisableNetwork"]; v != "1" {
		t.Fatalf("tor did not take the late command: DisableNetwork=%s", v)
	}
	t.Logf("tor took the command after the deadline: off the network, status %s", status())

	// the phone is fast again. the engine has to notice on its own
	slow.on.Store(false)
	gave := time.Now()
	for time.Since(gave) < 3*time.Minute {
		time.Sleep(5 * time.Second)
		dn := conf(t, "DisableNetwork")["DisableNetwork"]
		t.Logf("%s later: DisableNetwork=%s, %s", time.Since(gave).Round(time.Second), dn, routeLine())
		if dn == "0" && routeOK() {
			return
		}
	}
	t.Fatalf("tor still off the network or unusable %s after the reconnect gave up: %s",
		time.Since(gave).Round(time.Second), routeLine())
}
