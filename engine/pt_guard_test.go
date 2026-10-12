// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what keeps the transport listeners from being used or read by anything
// but tor, and what keeps one bad connection from taking the rest down

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"strings"
	"syscall"
	"testing"
	"time"

	pt "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/goptlib"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/base"
	sf "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/client/lib"
)

// reads until the far end closes: no reply byte may come first
func expectNoReply(t *testing.T, c net.Conn) {
	t.Helper()
	expectClosedWithin(t, c, 5*time.Second)
}

func expectClosedWithin(t *testing.T, c net.Conn, d time.Duration) {
	t.Helper()
	c.SetReadDeadline(time.Now().Add(d))
	b := make([]byte, 1)
	n, err := c.Read(b)
	if n != 0 || !errors.Is(err, io.EOF) && !errors.Is(err, io.ErrClosedPipe) {
		t.Fatalf("got %d bytes, %v", n, err)
	}
}

// without tor's token a configured bridge and anything else look the same:
// the connection closes with no reply, and nothing is dialled
func TestNoTokenNoAnswer(t *testing.T) {
	bridge, toBridge := knocks(t)
	cert := randomCert()
	useBridges(t, true, fmt.Sprintf("obfs4 %s %s cert=%s iat-mode=0", bridge.Addr(), testFP, cert))
	args := "cert=" + cert + ";iat-mode=0"
	for _, target := range []string{bridge.Addr().String(), "127.0.0.1:9"} {
		expectNoReply(t, socksSendAs(t, "obfs4", nil, target, args))
		expectNoReply(t, socksSendAs(t, "obfs4", nil, target, args+";kryfo=0123456789abcdef0123456789abcdef"))
	}
	select {
	case <-toBridge:
		t.Fatal("dialled without the token")
	case <-time.After(500 * time.Millisecond):
	}
	if !strings.Contains(strings.Join(torBridgeLines(), "\n"), ptTokenArg+"="+ptToken) {
		t.Fatal("tor's lines carry no token")
	}
}

func TestNormaliseDropsOldTokens(t *testing.T) {
	got, _ := normaliseBridgeLine(tbObfs4 + " kryfo=00ff")
	if got != tbObfs4 {
		t.Fatalf("%q", got)
	}
}

// tor's side of the socks5 exchange over a real connection, with the token
func torConnect(t *testing.T, addr, target string) (net.Conn, byte) {
	t.Helper()
	c, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatal(err)
	}
	c.SetDeadline(time.Now().Add(10 * time.Second))
	args := ptTokenArg + "=" + ptToken
	host, port, _ := net.SplitHostPort(target)
	var p int
	fmt.Sscanf(port, "%d", &p)
	req := append(append([]byte{5, 1, 0, 1}, net.ParseIP(host).To4()...), byte(p>>8), byte(p))
	b := make([]byte, 10)
	for _, out := range [][]byte{{5, 1, 2}, append(append(append([]byte{1, byte(len(args))}, args...), 1), 0)} {
		if _, err := c.Write(out); err != nil {
			t.Fatal(err)
		}
		if _, err := io.ReadFull(c, b[:2]); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := c.Write(req); err != nil {
		t.Fatal(err)
	}
	if _, err := io.ReadFull(c, b); err != nil {
		return c, 0xff
	}
	return c, b[1]
}

func listenOn(t *testing.T, name string) (*ptListen, string) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	f, _ := ptClientFactory(name)
	r := newPTListen(name, ln, f)
	go r.accept()
	return r, ln.Addr().String()
}

// idle connections without the token, more than any cap, cannot keep tor
// out, are not counted as tor's, and go away on their own
func TestIdleForeignConnsCannotStarveTor(t *testing.T) {
	bridge, toBridge := knocks(t)
	useBridges(t, true, fmt.Sprintf("obfs4 %s %s cert=%s iat-mode=0", bridge.Addr(), testFP, randomCert()))
	r, addr := listenOn(t, "obfs4")
	var idle []net.Conn
	defer func() {
		for _, c := range idle {
			c.Close()
		}
	}()
	for i := 0; i < 24; i++ {
		c, err := net.Dial("tcp", addr)
		if err != nil {
			t.Fatal(err)
		}
		idle = append(idle, c)
	}
	time.Sleep(200 * time.Millisecond)
	c, _ := torConnect(t, addr, bridge.Addr().String())
	defer c.Close()
	select {
	case <-toBridge:
	case <-time.After(5 * time.Second):
		t.Fatal("tor's connection did not get through")
	}
	if n := r.requests.Load(); n != 1 {
		t.Fatalf("%d requests counted, want tor's one", n)
	}
	// the handshake's own deadline is 5s, the pool's is shorter
	for _, ic := range idle {
		expectClosedWithin(t, ic, 3*time.Second)
	}
}

// the cap counts only connections that passed the token check, and grows
// with the lines
func TestConnCapFollowsLines(t *testing.T) {
	var lines []string
	for i := 0; i < 20; i++ {
		lines = append(lines, fmt.Sprintf("obfs4 192.0.2.%d:443 %s cert=%s iat-mode=0", 100+i, testFP, randomCert()))
	}
	useBridges(t, true, lines...)
	if n := ptConnLimit(); n < 2*20 {
		t.Fatalf("cap %d for 20 lines", n)
	}
	bridge, toBridge := knocks(t)
	useBridges(t, true, fmt.Sprintf("obfs4 %s %s cert=%s iat-mode=0", bridge.Addr(), testFP, randomCert()))
	r, addr := listenOn(t, "obfs4")
	r.active.Store(ptConnLimit())
	c, _ := torConnect(t, addr, bridge.Addr().String())
	c.Close()
	select {
	case <-toBridge:
		t.Fatal("dialled past the cap")
	case <-time.After(500 * time.Millisecond):
	}
	r.active.Store(0)
	c, _ = torConnect(t, addr, bridge.Addr().String())
	defer c.Close()
	select {
	case <-toBridge:
	case <-time.After(5 * time.Second):
		t.Fatal("not dialled under the cap")
	}
}

func TestTokenScrubbed(t *testing.T) {
	if out := scrubBridges("Starting tor with args --Bridge obfs4 1.2.3.4:443 kryfo=" + ptToken); strings.Contains(out, ptToken) {
		t.Fatalf("%q", out)
	}
}

func TestNetworkChangeDropsSnowflakeClients(t *testing.T) {
	oldBounce, oldQuiet, oldGap := netBounce, netQuiet, netGap
	underNetMu(func() { netBounce, netQuiet, netGap = func() {}, time.Millisecond, time.Millisecond })
	t.Cleanup(func() {
		// the debounce worker finishes before the real bounce is back
		for {
			netMu.Lock()
			busy := netWorker
			netMu.Unlock()
			if !busy {
				break
			}
			time.Sleep(5 * time.Millisecond)
		}
		underNetMu(func() { netBounce, netQuiet, netGap = oldBounce, oldQuiet, oldGap })
	})
	dropSnowflakeClients()
	if _, err := snowflakeFor(snowflakeTestConfig(t)); err != nil {
		t.Fatal(err)
	}
	networkChanged()
	sfMu.Lock()
	n := len(sfClients)
	sfMu.Unlock()
	if n != 0 {
		t.Fatalf("%d snowflake clients outlived the network", n)
	}
}

// a listener whose Accept fails a few times the way a phone out of file
// descriptors does, then hands over one connection, then is closed
type flakyListener struct {
	net.Listener
	fails int
	conn  net.Conn
}

func (l *flakyListener) Accept() (net.Conn, error) {
	if l.fails > 0 {
		l.fails--
		return nil, &net.OpError{Op: "accept", Err: syscall.EMFILE}
	}
	if c := l.conn; c != nil {
		l.conn = nil
		return c, nil
	}
	return nil, net.ErrClosed
}

func TestAcceptOutlivesErrors(t *testing.T) {
	inner, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer inner.Close()
	c, s := net.Pipe()
	defer c.Close()
	f, _ := ptClientFactory("obfs4")
	r := newPTListen("obfs4", &flakyListener{Listener: inner, fails: 5, conn: s}, f)
	stopped := make(chan struct{})
	go func() { r.accept(); close(stopped) }()
	// the connection after the errors is served: the greeting gets an answer
	c.SetDeadline(time.Now().Add(5 * time.Second))
	if _, err := c.Write([]byte{5, 1, 2}); err != nil {
		t.Fatalf("the connection after the errors was never served: %v", err)
	}
	select {
	case <-stopped:
	case <-time.After(5 * time.Second):
		t.Fatal("accept did not end on a closed listener")
	}
}

// a transport that hands back whatever conn the test gives it
type fakeFactory struct{ remote net.Conn }

func (f fakeFactory) Transport() base.Transport               { return nil }
func (f fakeFactory) ParseArgs(*pt.Args) (interface{}, error) { return nil, nil }
func (f fakeFactory) OnEvent(func(base.TransportEvent))       {}
func (f fakeFactory) Dial(_, _ string, _ base.DialFunc, _ interface{}) (net.Conn, error) {
	return f.remote, nil
}

// a conn whose Write panics, as obfs4's can
type panicConn struct{ net.Conn }

func (panicConn) Write([]byte) (int, error) { panic("write") }

func serveFake(t *testing.T, remote net.Conn) (net.Conn, chan struct{}) {
	t.Helper()
	useBridges(t, true, "obfs4 192.0.2.60:443 "+testFP+" cert="+randomCert()+" iat-mode=0")
	done := make(chan struct{})
	c, s := net.Pipe()
	t.Cleanup(func() { c.Close() })
	go func() {
		defer close(done)
		servePTConn(s, "obfs4", fakeFactory{remote}, nil)
	}()
	c.SetDeadline(time.Now().Add(10 * time.Second))
	return c, done
}

// tor's side of the socks5 exchange with the token, up to a success reply
func handshake(t *testing.T, c net.Conn) {
	t.Helper()
	args := ptTokenArg + "=" + ptToken
	auth := append(append(append([]byte{1, byte(len(args))}, args...), 1), 0)
	req := []byte{5, 1, 0, 1, 192, 0, 2, 60, 1, 187}
	b := make([]byte, 10)
	for _, out := range [][]byte{{5, 1, 2}, auth} {
		if _, err := c.Write(out); err != nil {
			t.Fatal(err)
		}
		if _, err := io.ReadFull(c, b[:2]); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := c.Write(req); err != nil {
		t.Fatal(err)
	}
	if _, err := io.ReadFull(c, b); err != nil || b[1] != 0 {
		t.Fatalf("reply %v, %v", b, err)
	}
}

// a panic while copying ends that one connection, not the app
func TestCopyPanicStaysInItsConnection(t *testing.T) {
	far, near := net.Pipe()
	defer far.Close()
	c, done := serveFake(t, panicConn{near})
	handshake(t, c)
	c.Write([]byte("tor bytes"))
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("the connection never ended")
	}
}

// tor going away ends the transport side too, even when that side never
// sends eof, as a snowflake stream does not
func TestTorLeavingClosesTheTransport(t *testing.T) {
	far, near := net.Pipe()
	defer far.Close()
	c, done := serveFake(t, near)
	handshake(t, c)
	c.Close()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("still copying after tor left")
	}
	far.SetReadDeadline(time.Now().Add(2 * time.Second))
	if _, err := far.Read(make([]byte, 1)); !errors.Is(err, io.EOF) && !errors.Is(err, io.ErrClosedPipe) {
		t.Fatalf("the transport side stayed open: %v", err)
	}
}

// a server that takes the connection and never answers, as a webtunnel host
// behind a filter can
func silentServer(t *testing.T) (net.Listener, chan net.Conn) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	got := make(chan net.Conn, 4)
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			got <- c
		}
	}()
	return ln, got
}

func TestWebtunnelHandshakeTimesOut(t *testing.T) {
	old := ptDialTimeout
	ptDialTimeout = time.Second
	t.Cleanup(func() { ptDialTimeout = old })
	srv, _ := silentServer(t)
	useBridges(t, true, fmt.Sprintf("webtunnel [2001:db8::9]:443 %s url=https://%s/x", testFP, srv.Addr()))
	t0 := time.Now()
	if code := socksConnect(t, "webtunnel", "[2001:db8::9]:443", ""); code == 0 {
		t.Fatal("a silent server counted as connected")
	}
	if took := time.Since(t0); took > 5*time.Second {
		t.Fatalf("took %s", took)
	}
}

func TestDialDroppedWhenTorLeaves(t *testing.T) {
	srv, got := silentServer(t)
	useBridges(t, true, fmt.Sprintf("webtunnel [2001:db8::9]:443 %s url=https://%s/x", testFP, srv.Addr()))
	c := socksSend(t, "webtunnel", "[2001:db8::9]:443", "")
	var raw net.Conn
	select {
	case raw = <-got:
	case <-time.After(5 * time.Second):
		t.Fatal("never dialled")
	}
	defer raw.Close()
	c.Close()
	raw.SetReadDeadline(time.Now().Add(3 * time.Second))
	if _, err := io.ReadAll(raw); err != nil {
		t.Fatalf("the dial outlived tor's connection: %v", err)
	}
}

func TestBridgeFailsResetAndFade(t *testing.T) {
	useBridges(t, true)
	key := "obfs4 192.0.2.61:443"
	refused := &net.OpError{Op: "dial", Err: syscall.ECONNRESET}
	for i := 0; i < bridgeDeadAfter; i++ {
		noteBridgeFail(key, refused)
	}
	if !bridgeIsDead(key) {
		t.Fatal("four failures in a row did not count")
	}
	setBridgeLines(tbObfs4, true)
	if bridgeIsDead(key) {
		t.Fatal("new lines kept the old failures")
	}
	for i := 0; i < 2*bridgeDeadAfter; i++ {
		noteBridgeFail(key, &net.OpError{Op: "dial", Err: syscall.ENETUNREACH})
	}
	if bridgeIsDead(key) {
		t.Fatal("no network counted against the bridge")
	}
	old := bridgeDeadFor
	bridgeDeadFor = 50 * time.Millisecond
	t.Cleanup(func() { bridgeDeadFor = old })
	for i := 0; i < bridgeDeadAfter; i++ {
		noteBridgeFail(key, refused)
	}
	time.Sleep(100 * time.Millisecond)
	if bridgeIsDead(key) {
		t.Fatal("the mark never faded")
	}
}

func snowflakeTestConfig(t *testing.T) sf.ClientConfig {
	f, _ := ptClientFactory("snowflake")
	front := closedAddr(t)
	got, err := f.ParseArgs(lineArgs(fmt.Sprintf(
		"snowflake 192.0.2.3:80 %s fingerprint=%s url=https://broker.invalid/ front=%s ice=stun:%s",
		testFP, testFP, front, front)))
	if err != nil {
		t.Fatal(err)
	}
	return got.(sf.ClientConfig)
}

func closedAddr(t *testing.T) string {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	a := ln.Addr().String()
	ln.Close()
	return a
}

func TestSnowflakeOneClientPerLine(t *testing.T) {
	dropSnowflakeClients()
	c := snowflakeTestConfig(t)
	f, _ := ptClientFactory("snowflake")
	n0 := sfMade.Load()
	for i := 0; i < 3; i++ {
		conn, err := f.Dial("tcp", "192.0.2.3:80", nil, c)
		if err != nil {
			t.Fatal(err)
		}
		conn.Close()
	}
	if n := sfMade.Load() - n0; n != 1 {
		t.Fatalf("%d clients for one line", n)
	}
	dropSnowflakeClients()
}

// the fork logs nothing: its lines would carry the broker, fronts and stun.
// the engine's own lines say which phase snowflake is in, no more.
func TestSnowflakeLogsNothing(t *testing.T) {
	var buf bytes.Buffer
	old := log.Writer()
	log.SetOutput(&buf)
	t.Cleanup(func() { log.SetOutput(old) })
	dropSnowflakeClients()
	c := snowflakeTestConfig(t)
	f, _ := ptClientFactory("snowflake")
	conn, err := f.Dial("tcp", "192.0.2.3:80", nil, c)
	if err != nil {
		t.Fatal(err)
	}
	time.Sleep(2 * time.Second)
	conn.Close()
	dropSnowflakeClients()
	log.SetOutput(old)
	// the engine's own event lines name a phase and nothing else
	for _, ln := range strings.Split(strings.TrimSpace(buf.String()), "\n") {
		if ln == "" {
			continue
		}
		if i := strings.Index(ln, "snowflake: "); i < 0 || strings.ContainsAny(ln[i+len("snowflake: "):], " :./") {
			t.Fatalf("logged: %q", ln)
		}
	}
}

// snowflake's events reach the engine: a broker that cannot be reached
// shows as a failed rendezvous, with nothing about it in the log line
func TestSnowflakeEventsArrive(t *testing.T) {
	front, _ := knocks(t)
	f, _ := ptClientFactory("snowflake")
	got, err := f.ParseArgs(lineArgs(fmt.Sprintf(
		"snowflake 192.0.2.3:80 %s fingerprint=%s url=https://broker.invalid/ front=%s ice=stun:%s",
		testFP, testFP, front.Addr(), closedAddr(t))))
	if err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	old := log.Writer()
	log.SetOutput(&buf)
	t.Cleanup(func() { log.SetOutput(old) })
	dropSnowflakeClients()
	_, _, before := snowflakeStatus()
	conn, err := f.Dial("tcp", "192.0.2.3:80", nil, got)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	deadline := time.Now().Add(20 * time.Second)
	for time.Now().Before(deadline) {
		if _, _, now := snowflakeStatus(); now["broker_failed"] > before["broker_failed"] {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	phase, at, now := snowflakeStatus()
	if now["broker_failed"] <= before["broker_failed"] || time.Since(at) > time.Minute {
		t.Fatalf("no failed rendezvous seen: %q %v", phase, now)
	}
	log.SetOutput(old)
	if out := buf.String(); strings.Contains(out, front.Addr().String()) || !strings.Contains(out, "snowflake: broker_failed") {
		t.Fatalf("log:\n%s", out)
	}
	dropSnowflakeClients()
}
