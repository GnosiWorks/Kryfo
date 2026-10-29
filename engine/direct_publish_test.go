// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"net"
	"net/textproto"
	"strings"
	"testing"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

func statusForTest(t *testing.T, s string) {
	t.Helper()
	statusMu.Lock()
	old := torStatus
	torStatus = s
	statusMu.Unlock()
	t.Cleanup(func() {
		statusMu.Lock()
		torStatus = old
		statusMu.Unlock()
	})
}

// before our onion is published a direct send answers at once and dials
// nothing, so the app takes the relays without waiting on the publish
func TestDirectRouteWaitsForThePublish(t *testing.T) {
	socks := newSocksStandIn(t)
	d := newTestDoor(t, handleConn)
	doorSetup(t, socks, map[string]*testDoor{"aaaa.onion": d})
	for _, st := range []string{"starting", "bootstrapped", "publishing"} {
		statusForTest(t, st)
		began := time.Now()
		if r := sendDirect("aaaa.onion", doorLine(t, 64)); r != errNotPublished {
			t.Fatalf("%s: %q, want %q", st, r, errNotPublished)
		}
		if took := time.Since(began); took > 200*time.Millisecond {
			t.Fatalf("%s: the answer took %s", st, took)
		}
		if n := d.count(); n != 0 {
			t.Fatalf("%s: %d streams reached the door", st, n)
		}
	}
	statusForTest(t, "reachable")
	if r := sendDirect("aaaa.onion", doorLine(t, 64)); r != "ok" {
		t.Fatalf("published: %q", r)
	}
	if n := d.count(); n != 1 {
		t.Fatalf("published: %d streams, want 1", n)
	}
}

// no tor at all still says so, published or not
func TestDirectRouteWithNoTor(t *testing.T) {
	mu.Lock()
	old := torNode
	torNode = nil
	mu.Unlock()
	defer func() {
		mu.Lock()
		torNode = old
		mu.Unlock()
	}()
	statusForTest(t, "reachable")
	if r := sendDirect("aaaa.onion", "x"); r != "error: tor not started" {
		t.Fatalf("%q", r)
	}
}

// a tor of its own for the publish watcher, apart from the stand-ins
func watcherTor(t *testing.T) *tor.Tor {
	t.Helper()
	eventReset()
	a, b := net.Pipe()
	t.Cleanup(func() { a.Close(); b.Close() })
	return &tor.Tor{Control: control.NewConn(textproto.NewConn(a))}
}

func uploads(ch chan control.Event, onion string, n int) {
	for i := 0; i < n; i++ {
		ch <- &control.HSDescEvent{Action: "UPLOAD", Address: onion, HSDir: fmt.Sprintf("$%d", i)}
	}
}

func publishedForTest(t *testing.T) {
	t.Helper()
	t.Cleanup(func() {
		publishedOnce.Store(false)
		txMu.Lock()
		pubSince = time.Time{}
		txMu.Unlock()
	})
}

// published once, then a bounce: tor keeps its descriptor and does not
// upload again for an hour or two. direct goes as soon as tor is back
func TestDirectRouteAfterABounce(t *testing.T) {
	socks := newSocksStandIn(t)
	d := newTestDoor(t, handleConn)
	doorSetup(t, socks, map[string]*testDoor{"aaaa.onion": d})
	publishedForTest(t)
	statusForTest(t, "publishing")
	ch := make(chan control.Event, 16)
	done := make(chan struct{})
	go func() { watchPublishedOn(watcherTor(t), ch, true, "pubonion"); close(done) }()
	uploads(ch, "pubonion", 3)
	<-done
	if st := torStatusNow(); st != "reachable" {
		t.Fatalf("status %q after the uploads", st)
	}
	// the bounce: starting, then tor up again, and no upload
	setStatus("starting")
	if r := sendDirect("aaaa.onion", doorLine(t, 64)); r != errNotPublished {
		t.Fatalf("while tor is down: %q", r)
	}
	setStatus("publishing")
	if r := sendDirect("aaaa.onion", doorLine(t, 64)); r != "ok" {
		t.Fatalf("after the bounce: %q", r)
	}
	if n := d.count(); n != 1 {
		t.Fatalf("%d streams, want 1", n)
	}
	// and the app reads the address as up, not publishing for hours
	if l := statusLine(); !strings.HasPrefix(l, "reachable|") {
		t.Fatalf("status line %q", l)
	}
	// the transport page too, though the bounce zeroes the uploads
	if v := transportSnapshot(); !v.PublishedOnce {
		t.Fatalf("transport state not published: %+v", v)
	}
}

// no upload is ever heard of (the subscription failed): direct still joins
// once the publish has run past its cap
func TestDirectRouteWhenNoUploadIsHeard(t *testing.T) {
	socks := newSocksStandIn(t)
	d := newTestDoor(t, handleConn)
	doorSetup(t, socks, map[string]*testDoor{"aaaa.onion": d})
	publishedForTest(t)
	statusForTest(t, "publishing")
	txMu.Lock()
	pubSince = time.Now()
	txMu.Unlock()
	if r := sendDirect("aaaa.onion", doorLine(t, 64)); r != errNotPublished {
		t.Fatalf("just started: %q", r)
	}
	txMu.Lock()
	pubSince = time.Now().Add(-directAfter - time.Second)
	txMu.Unlock()
	if r := sendDirect("aaaa.onion", doorLine(t, 64)); r != "ok" {
		t.Fatalf("past the cap: %q", r)
	}
	// the address is not claimed up: only the route is let through
	if l := statusLine(); !strings.HasPrefix(l, "publishing|") {
		t.Fatalf("status line %q", l)
	}
}

// uploads seen while the status still says starting: once 100% is read the
// status goes on to reachable instead of standing at publishing
func TestUploadsBeforeTheHundredPercent(t *testing.T) {
	old := publishSettle
	publishSettle = 10 * time.Millisecond
	defer func() { publishSettle = old }()
	publishedForTest(t)
	resetRoute(t, "starting", 60)
	ch := make(chan control.Event, 16)
	done := make(chan struct{})
	go func() { watchPublishedOn(watcherTor(t), ch, true, "early"); close(done) }()
	uploads(ch, "early", 3)
	time.Sleep(100 * time.Millisecond)
	if st := torStatusNow(); st != "starting" {
		t.Fatalf("status %q before 100%%", st)
	}
	setStatus("publishing")
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("the watcher never let go")
	}
	if st := torStatusNow(); st != "reachable" {
		t.Fatalf("status %q, want reachable", st)
	}
}
