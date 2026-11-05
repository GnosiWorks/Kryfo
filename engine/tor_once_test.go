// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !windows

package main

import (
	"bufio"
	"context"
	"fmt"
	"net"
	"net/textproto"
	"strings"
	"sync"
	"testing"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// one tor per process on a phone too: a start whose listen failed leaves
// its tor up, and the next start listens again on it. no tor here: a fake
// control port, a fake bine connection, tor's own start stood in for

// bine's connection answering ADD_ONION: no for the first [refuse], then
// a service
type addSide struct {
	mu     sync.Mutex
	refuse int
	adds   int
}

func (s *addSide) serve(c net.Conn) {
	r := bufio.NewReader(c)
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return
		}
		if !strings.HasPrefix(line, "ADD_ONION") {
			fmt.Fprint(c, "250 OK\r\n")
			continue
		}
		s.mu.Lock()
		s.adds++
		no := s.adds <= s.refuse
		s.mu.Unlock()
		if no {
			fmt.Fprint(c, "551 Failed to add onion\r\n")
			continue
		}
		fmt.Fprintf(c, "250-ServiceID=%s\r\n250 OK\r\n", strings.Repeat("a", 56))
	}
}

func (s *addSide) count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.adds
}

// tor's start stood in for: counted, and handing back n
func standInStart(t *testing.T, n *tor.Tor) *int {
	t.Helper()
	calls := 0
	was := startTor
	startTor = func(context.Context, *tor.StartConf) (*tor.Tor, error) {
		calls++
		return n, nil
	}
	t.Cleanup(func() { startTor = was })
	return &calls
}

func TestAFailedListenListensAgainOnTheSameTor(t *testing.T) {
	f := newFakeControl(t, 100)
	n := fakeTor(t, f.port())
	a, c := net.Pipe()
	t.Cleanup(func() { a.Close(); c.Close() })
	side := &addSide{refuse: 1}
	go side.serve(c)
	n.Control = control.NewConn(textproto.NewConn(a))
	mu.Lock()
	torNode, myAddr = nil, ""
	mu.Unlock()
	resetRoute(t, "starting", 0)
	t.Cleanup(func() {
		mu.Lock()
		l, _ := listener.(*tor.OnionService)
		listener = nil
		mu.Unlock()
		if l != nil && l.LocalListener != nil {
			l.LocalListener.Close()
		}
	})
	calls := standInStart(t, n)
	dir := t.TempDir()

	if r := startListener(dir); !strings.HasPrefix(r, "error: listen:") {
		t.Fatalf("the first start: %q", r)
	}
	mu.Lock()
	kept := torNode == n
	mu.Unlock()
	if *calls != 1 || !kept {
		t.Fatalf("tor started %d times, kept %v", *calls, kept)
	}
	want := strings.Repeat("a", 56) + ".onion"
	if r := startListener(dir); r != want {
		t.Fatalf("the start after: %q", r)
	}
	if *calls != 1 {
		t.Fatalf("tor started %d times in one process", *calls)
	}
	if side.count() != 2 {
		t.Fatalf("listened %d times", side.count())
	}
	mu.Lock()
	same := torNode == n
	mu.Unlock()
	if !same {
		t.Fatal("another tor")
	}
	// and from here the address it has
	if r := startListener(dir); r != want || *calls != 1 || side.count() != 2 {
		t.Fatalf("a third start: %q, %d starts, %d listens", r, *calls, side.count())
	}
}

// a start that failed twice already (bine closes each) never runs a third
// tor in the process
func TestNoThirdTorInAProcess(t *testing.T) {
	was := torLaunches.Load()
	t.Cleanup(func() { torLaunches.Store(was) })
	torLaunches.Store(2)
	mu.Lock()
	had := torNode
	torNode, myAddr = nil, ""
	mu.Unlock()
	t.Cleanup(func() { mu.Lock(); torNode = had; mu.Unlock() })
	calls := standInStart(t, nil)
	r := startListener(t.TempDir())
	if !strings.HasPrefix(r, "error: tor start:") || *calls != 0 {
		t.Fatalf("a third tor: %q, %d starts", r, *calls)
	}
}
