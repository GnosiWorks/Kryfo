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
	c.SetReadDeadline(time.Now().Add(5 * time.Second))
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

func TestListenerCapsConnections(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	f, _ := ptClientFactory("obfs4")
	r := newPTListen("obfs4", ln, f)
	stopped := make(chan struct{})
	go func() { r.accept(); close(stopped) }()
	var held []net.Conn
	defer func() {
		for _, c := range held {
			c.Close()
		}
	}()
	for i := 0; i < ptMaxConns; i++ {
		c, err := net.Dial("tcp", ln.Addr().String())
		if err != nil {
			t.Fatal(err)
		}
		held = append(held, c)
	}
	deadline := time.Now().Add(5 * time.Second)
	for len(r.slots) < ptMaxConns && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	extra, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer extra.Close()
	expectNoReply(t, extra)
	ln.Close()
	select {
	case <-stopped:
	case <-time.After(5 * time.Second):
		t.Fatal("accept outlived its listener")
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
	setBridges(tbObfs4, true)
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

// the fork logs nothing: its lines would carry the broker, fronts and stun
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
	if out := buf.String(); out != "" {
		t.Fatalf("logged:\n%s", out)
	}
}
