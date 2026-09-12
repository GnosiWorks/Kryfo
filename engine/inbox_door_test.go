// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bufio"
	"encoding/base64"
	"net"
	"strings"
	"sync"
	"testing"
	"time"
)

// the door itself, on a local socket: the same accept loop and handler the
// onion listener runs, minus tor. junk, repeats, floods and one honest line.
func knock(t *testing.T, addr, line string) string {
	c, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	c.SetDeadline(time.Now().Add(3 * time.Second))
	if _, err := c.Write([]byte(line + "\n")); err != nil {
		return "write failed"
	}
	reply, err := bufio.NewReader(c).ReadString('\n')
	if err != nil {
		return "closed"
	}
	return strings.TrimSpace(reply)
}

func TestDoor(t *testing.T) {
	mu.Lock()
	inboxDrained()
	mu.Unlock()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	go acceptLoop(l)
	addr := l.Addr().String()

	if r := knock(t, addr, wire(3, 200)); r != "ack" {
		t.Fatalf("an honest opener should be acked, got %q", r)
	}
	if r := knock(t, addr, wire(3, 200)); r != "closed" {
		t.Fatalf("the same line again should be shut without ack, got %q", r)
	}
	if r := knock(t, addr, `{"halo_ctl":"bundle"}`); r != "closed" {
		t.Fatalf("json should be shut without ack, got %q", r)
	}
	if r := knock(t, addr, strings.Repeat("A", 300*1024)); r != "closed" {
		t.Fatalf("an oversize line should be shut without ack, got %q", r)
	}
	mu.Lock()
	n := len(inbox)
	mu.Unlock()
	if n != 1 {
		t.Fatalf("only the honest line should wait, inbox has %d", n)
	}

	// a flood: forty connections at once, each holding its line back for a
	// moment. at most eight are inside; the rest are shut at the door.
	var wg sync.WaitGroup
	var acked, shut int
	var cm sync.Mutex
	for i := 0; i < 40; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			c, err := net.Dial("tcp", addr)
			if err != nil {
				return
			}
			defer c.Close()
			time.Sleep(300 * time.Millisecond)
			c.SetDeadline(time.Now().Add(3 * time.Second))
			c.Write([]byte(wire(2, 100+i) + "\n"))
			reply, err := bufio.NewReader(c).ReadString('\n')
			cm.Lock()
			if err == nil && strings.TrimSpace(reply) == "ack" {
				acked++
			} else {
				shut++
			}
			cm.Unlock()
		}(i)
	}
	wg.Wait()
	if acked > inboxMaxConns || shut < 40-inboxMaxConns {
		t.Fatalf("flood: %d acked, %d shut; at most %d may be inside at once", acked, shut, inboxMaxConns)
	}
	if acked == 0 {
		t.Fatal("the door should still serve the ones inside")
	}
	mu.Lock()
	inboxDrained()
	mu.Unlock()
}

var _ = base64.StdEncoding
