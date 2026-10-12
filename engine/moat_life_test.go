// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what a moat call leaves behind, the decoy during a call, the refresh's
// back-off, what the store keeps, and lines moat must not get through

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// a front that takes the tcp connection and then says nothing. counts the
// connections it got and how many are still open.
type stallFront struct {
	ln     net.Listener
	got    atomic.Int64
	open   atomic.Int64
	mu     sync.Mutex
	conns  []net.Conn
	closed chan struct{}
}

func newStallFront(t *testing.T) *stallFront {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	f := &stallFront{ln: ln, closed: make(chan struct{})}
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			f.got.Add(1)
			f.open.Add(1)
			f.mu.Lock()
			f.conns = append(f.conns, c)
			f.mu.Unlock()
			go func() {
				// a read ends when the other side closes
				_, _ = c.Read(make([]byte, 64<<10))
				for {
					if _, err := c.Read(make([]byte, 64<<10)); err != nil {
						break
					}
				}
				f.open.Add(-1)
			}()
		}
	}()
	t.Cleanup(func() {
		ln.Close()
		f.mu.Lock()
		for _, c := range f.conns {
			c.Close()
		}
		f.mu.Unlock()
	})
	return f
}

// moat through meek to a front that stalls. https, so meek's own tls
// handshake is what hangs.
func useStallFront(t *testing.T) *stallFront {
	t.Helper()
	useMoatStandIns(t)
	f := newStallFront(t)
	moatTargets = "https://reflector.example|" + f.ln.Addr().String()
	old := moatTimeout
	moatTimeout = 1500 * time.Millisecond
	t.Cleanup(func() { moatTimeout = old })
	return f
}

// waits for the goroutine count to come back down to base
func settleGoroutines(base int) int {
	n := runtime.NumGoroutine()
	for i := 0; i < 50 && n > base; i++ {
		time.Sleep(50 * time.Millisecond)
		n = runtime.NumGoroutine()
	}
	return n
}

func TestMoatLeavesNothingRunning(t *testing.T) {
	f := useStallFront(t)
	// a dialer that does not watch the call's context, so the call's own
	// guard is what stops meek's retries
	meekNetDial = func(_ context.Context, n, a string) (net.Conn, error) {
		return net.DialTimeout(n, a, 5*time.Second)
	}
	// one call first, so lazily started runtime goroutines are counted
	_, _, _ = moatDo(moatOpts{Consent: true}, "POST", "/circumvention/settings", map[string]any{})
	time.Sleep(300 * time.Millisecond)
	base := runtime.NumGoroutine()
	got := f.got.Load()

	t0 := time.Now()
	_, _, err := moatDo(moatOpts{Consent: true}, "POST", "/circumvention/settings", map[string]any{})
	if !errors.Is(err, errMoatUnreachable) {
		t.Fatalf("stalled front: %v", err)
	}
	if d := time.Since(t0); d > moatTimeout+time.Second {
		t.Errorf("the call took %v", d)
	}
	if f.got.Load() == got {
		t.Fatal("the front was never dialled, the test proves nothing")
	}
	after := f.got.Load()
	time.Sleep(time.Second)
	if n := f.got.Load(); n != after {
		t.Errorf("meek dialled the front %d more times after the call ended", n-after)
	}
	if n := f.open.Load(); n != 0 {
		t.Errorf("%d connections to the front still open", n)
	}
	if n := settleGoroutines(base); n > base {
		t.Errorf("%d goroutines outlived the call", n-base)
	}
}

func TestDecoyEndsAMoatCall(t *testing.T) {
	f := useStallFront(t)
	moatTimeout = 20 * time.Second
	done := make(chan error, 1)
	t0 := time.Now()
	go func() {
		_, _, err := moatDo(moatOpts{Consent: true}, "POST", "/circumvention/settings", map[string]any{})
		done <- err
	}()
	for f.got.Load() == 0 && time.Since(t0) < 5*time.Second {
		time.Sleep(10 * time.Millisecond)
	}
	setDecoy(true)
	select {
	case err := <-done:
		if err != errMoatDecoy {
			t.Errorf("got %v, want %v", err, errMoatDecoy)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the call ran on with a decoy open")
	}
	after := f.got.Load()
	time.Sleep(500 * time.Millisecond)
	if f.got.Load() != after || f.open.Load() != 0 {
		t.Errorf("after the decoy opened: %d new dials, %d still open", f.got.Load()-after, f.open.Load())
	}
}

// a decoy opening while moat answers: the reply is neither returned nor
// cached
func TestDecoyDropsAReplyOnItsWay(t *testing.T) {
	useMoatStandIns(t)
	resetBuiltinState(t)
	moatTransport = func(via string, d *moatDials) (*http.Transport, error) {
		tr, err := moatTransportFor(via, d)
		if err != nil {
			return nil, err
		}
		inner := tr.DialTLSContext
		tr.DialTLSContext = func(ctx context.Context, n, a string) (net.Conn, error) {
			c, err := inner(ctx, n, a)
			setDecoy(true)
			return c, err
		}
		return tr, nil
	}
	r := reply(t, moatSettingsJSON(`{"consent":true,"country":"ir"}`))
	if r["error"] != "decoy" {
		t.Errorf("reply with a decoy open: %v", r)
	}
	if moatSettingsCached() != nil {
		t.Error("cached with a decoy open")
	}
	// and a reply that reaches the json step with a decoy open
	setDecoy(false)
	moatTransport = moatTransportFor
	out := withMoatOpts(`{"consent":true}`, func(moatOpts) (any, error) {
		setDecoy(true)
		return map[string]any{"lines": []string{"x"}}, nil
	})
	if strings.Contains(out, "lines") {
		t.Errorf("returned with a decoy open: %s", out)
	}
}

func TestBuiltinRefreshBacksOff(t *testing.T) {
	useMoatStandIns(t)
	resetBuiltinState(t)
	defer func() { builtinMu.Lock(); builtinFailedAt = time.Time{}; builtinMu.Unlock() }()
	tries := 0
	moatTransport = func(via string, d *moatDials) (*http.Transport, error) {
		tries++
		tr, _ := moatTransportFor(viaPlain, d)
		tr.DialContext = func(context.Context, string, string) (net.Conn, error) {
			return nil, errors.New("no route")
		}
		return tr, nil
	}
	if r := reply(t, builtinRefreshJSON(`{"consent":true}`)); r["error"] != "moat_unreachable" {
		t.Fatalf("first try: %v", r)
	}
	for _, in := range []string{`{"consent":true}`, `{"consent":true,"force":true}`} {
		if r := reply(t, builtinRefreshJSON(in)); r["skipped"] != true {
			t.Errorf("%s right after a failure: %v", in, r)
		}
	}
	if tries != 1 {
		t.Errorf("%d tries within the back-off", tries)
	}
	builtinMu.Lock()
	builtinFailedAt = time.Now().Add(-builtinRetryAfter)
	builtinMu.Unlock()
	builtinRefreshJSON(`{"consent":true}`)
	if tries != 2 {
		t.Errorf("no try once the back-off ran out")
	}
	// refused before anything went out: no back-off
	builtinMu.Lock()
	builtinFailedAt = time.Time{}
	builtinMu.Unlock()
	setDecoy(true)
	builtinRefreshJSON(`{"force":true}`)
	setDecoy(false)
	if builtinBackingOff() {
		t.Error("a refusal started the back-off")
	}
}

func TestMoatRefusesUnreviewedSnowflakeHosts(t *testing.T) {
	var w moatSettingsWire
	if err := json.Unmarshal(fixture(t, "settings-unreviewed"), &w); err != nil {
		t.Fatal(err)
	}
	lines := w.Settings[0].Bridges.BridgeStrings
	for i, ln := range lines[:3] {
		if !validBridgeLine(ln) {
			t.Fatalf("line %d is refused for another reason", i)
		}
		if moatLineOK(ln) {
			t.Errorf("line %d with a host nobody reviewed passes", i)
		}
	}
	if !moatLineOK(lines[3]) {
		t.Error("the reviewed line is refused")
	}
	out, err := readMoatSettings(fixture(t, "settings-unreviewed"), 200)
	if err != nil || len(out.Settings) != 1 || len(out.Settings[0].Lines) != 1 {
		t.Errorf("settings: %v %v", out, err)
	}
}

func TestSnowflakeBrokerMustBeHTTPS(t *testing.T) {
	sf := builtinBundled["snowflake"][0]
	for _, u := range []string{"http://1098762253.rsc.cdn77.org/", "https://", "https:///x", "ftp://1098762253.rsc.cdn77.org/"} {
		ln := strings.Replace(sf, "url=https://1098762253.rsc.cdn77.org/", "url="+u, 1)
		if validBridgeLine(ln) {
			t.Errorf("own line with broker %q passes", u)
		}
		if got := moatLines([]string{ln}, "snowflake"); len(got) != 0 {
			t.Errorf("moat line with broker %q passes", u)
		}
	}
	if !validBridgeLine(sf) {
		t.Error("the built-in line is refused")
	}
}

func TestBridgeCacheKeepsOnlyLinesInUse(t *testing.T) {
	resetBuiltinState(t)
	defer decoyState.Store(decoyUnknown)
	defer setBridgeLines("", false)
	settings, err := readMoatSettings(fixture(t, "settings-ir"), 200)
	if err != nil {
		t.Fatal(err)
	}
	cacheMoatSettings(settings.Settings)
	var obfs, wt []string
	for _, s := range settings.Settings {
		switch s.Type {
		case "obfs4":
			obfs = s.Lines
		case "webtunnel":
			wt = s.Lines
		}
	}
	if len(obfs) == 0 || len(wt) == 0 {
		t.Fatal("fixture lacks obfs4 or webtunnel")
	}
	// the old call waits for the decoy to be known closed
	setDecoy(false)
	setBridgeLines(obfs[0], true)

	setDecoy(true)
	if r := reply(t, bridgeCacheJSON()); r["error"] != "decoy" {
		t.Errorf("cache handed out in a decoy: %v", r)
	}
	decoyState.Store(decoyUnknown)
	if r := reply(t, bridgeCacheJSON()); r["error"] != "decoy" {
		t.Errorf("cache handed out before the app said: %v", r)
	}
	setDecoy(false)
	blob := bridgeCacheJSON()
	var w map[string]any
	_ = json.Unmarshal([]byte(blob), &w)
	m, _ := w["moat"].(map[string]any)
	lines, _ := m["lines"].([]any)
	if len(lines) != 1 || lines[0] != obfs[0] {
		t.Errorf("stored %v, want the one line in use", lines)
	}
	for _, bad := range []string{wt[0], "snowflake", `"country"`, `"at"`, `"settings"`} {
		if strings.Contains(blob, bad) {
			t.Errorf("the store keeps %.20s", bad)
		}
	}
	if day, _ := m["day"].(float64); int64(day) != dayOf(time.Now()) {
		t.Errorf("day %v", m["day"])
	}

	resetBuiltinState(t)
	bridgeCacheIn(blob)
	c := moatSettingsCached()
	if len(c) != 1 || c[0].Type != "obfs4" || len(c[0].Lines) != 1 {
		t.Errorf("back from the store: %v", c)
	}
	// a week old, or from the future: dropped
	for _, d := range []int64{dayOf(time.Now()) - 7, dayOf(time.Now()) + 2} {
		m["day"] = d
		b, _ := json.Marshal(w)
		resetBuiltinState(t)
		bridgeCacheIn(string(b))
		if moatSettingsCached() != nil {
			t.Errorf("day %d taken", d)
		}
	}
}

// a meek conn nobody reads from: the worker fills its queue, and once the
// conn closes it must end rather than wait for a reader forever
func TestMeekWorkerEndsWithoutReader(t *testing.T) {
	useMoatStandIns(t)
	var polls atomic.Int64
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		polls.Add(1)
		_, _ = w.Write([]byte("x"))
	}))
	defer srv.Close()
	moatTargets = "http://reflector.example|" + srv.Listener.Addr().String()
	base := runtime.NumGoroutine()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	d := &moatDials{ctx: ctx}
	c, err := meekDial(d)
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; polls.Load() < 20 && i < 200; i++ {
		time.Sleep(20 * time.Millisecond)
	}
	if polls.Load() < 17 {
		t.Fatalf("only %d polls, the queue never filled", polls.Load())
	}
	c.Close()
	d.closeAll()
	srv.CloseClientConnections()
	if n := settleGoroutines(base); n > base {
		t.Errorf("%d goroutines outlived the conn", n-base)
	}
}
