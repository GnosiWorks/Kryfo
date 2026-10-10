// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the transport listeners dial a bridge tor was given and nothing else, with
// that bridge line's own arguments, and nothing at all while bridges are off

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/common/socks5"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/base"
)

// a listener that counts what reaches it
func knocks(t *testing.T) (net.Listener, chan struct{}) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	came := make(chan struct{}, 64)
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			select {
			case came <- struct{}{}:
			default:
			}
			c.Close()
		}
	}()
	return ln, came
}

// a udp socket that counts packets, for stun
func udpKnocks(t *testing.T) (net.PacketConn, *atomic.Int64) {
	t.Helper()
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { pc.Close() })
	var n atomic.Int64
	go func() {
		b := make([]byte, 2048)
		for {
			if _, _, err := pc.ReadFrom(b); err != nil {
				return
			}
			n.Add(1)
		}
	}()
	return pc, &n
}

// a socks5 request to servePTConn, as tor makes it: arguments and the
// token in the username. the client end comes back without waiting for the
// reply, and stays open until the test ends.
func socksSend(t *testing.T, transport, target, args string) net.Conn {
	t.Helper()
	if args != "" {
		args += ";"
	}
	return socksSendAs(t, transport, nil, target, args+ptTokenArg+"="+ptToken)
}

// the same with exactly these arguments and, if given, this factory
func socksSendAs(t *testing.T, transport string, factory base.ClientFactory, target, args string) net.Conn {
	t.Helper()
	if factory == nil {
		var err error
		if factory, err = ptClientFactory(transport); err != nil {
			t.Fatal(err)
		}
	}
	c, s := net.Pipe()
	t.Cleanup(func() { c.Close() })
	go servePTConn(s, transport, factory, nil)
	c.SetDeadline(time.Now().Add(30 * time.Second))
	user, pass := args, "\x00"
	if len(user) > 255 {
		user, pass = args[:255], args[255:]
	}
	host, port, _ := net.SplitHostPort(target)
	var p int
	fmt.Sscanf(port, "%d", &p)
	req := []byte{5, 1, 0}
	if ip := net.ParseIP(host); ip.To4() != nil {
		req = append(append(req, 1), ip.To4()...)
	} else {
		req = append(append(req, 4), ip.To16()...)
	}
	req = append(req, byte(p>>8), byte(p))
	auth := append(append(append([]byte{1, byte(len(user))}, user...), byte(len(pass))), pass...)
	b := make([]byte, 2)
	for _, out := range [][]byte{{5, 1, 2}, auth} {
		if _, err := c.Write(out); err != nil {
			t.Fatal(err)
		}
		if _, err := io.ReadFull(c, b); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := c.Write(req); err != nil {
		t.Fatal(err)
	}
	return c
}

// the same, waiting for the reply code
func socksConnect(t *testing.T, transport, target, args string) byte {
	t.Helper()
	c := socksSend(t, transport, target, args)
	b := make([]byte, 10)
	if _, err := io.ReadFull(c, b); err != nil {
		t.Fatal(err)
	}
	return b[1]
}

// sets the active lines for one test and puts the old ones back after
func useBridges(t *testing.T, on bool, lines ...string) {
	t.Helper()
	bridgeMu.Lock()
	oldList, oldOn, oldFails := bridgeList, bridgeOn, bridgeFails
	bridgeList, bridgeOn, bridgeFails = lines, on, map[string]bridgeFail{}
	bridgeMu.Unlock()
	t.Cleanup(func() {
		bridgeMu.Lock()
		bridgeList, bridgeOn, bridgeFails = oldList, oldOn, oldFails
		bridgeMu.Unlock()
	})
}

func randomCert() string {
	raw := make([]byte, 52)
	rand.Read(raw)
	return strings.TrimSuffix(base64.StdEncoding.EncodeToString(raw), "==")
}

const testFP = "0123456789ABCDEF0123456789ABCDEF01234567"

func TestPTListenerDialsOnlyConfiguredBridges(t *testing.T) {
	bridge, toBridge := knocks(t)
	other, toOther := knocks(t)
	cert := randomCert()
	useBridges(t, true, fmt.Sprintf("obfs4 %s %s cert=%s iat-mode=0", bridge.Addr(), testFP, cert))
	args := "cert=" + cert + ";iat-mode=0"

	if code := socksConnect(t, "obfs4", other.Addr().String(), args); code != byte(socks5.ReplyConnectionNotAllowed) {
		t.Fatalf("another address answered %d", code)
	}
	// the right address through another transport's listener
	if code := socksConnect(t, "webtunnel", bridge.Addr().String(), args); code != byte(socks5.ReplyConnectionNotAllowed) {
		t.Fatalf("the obfs4 bridge answered on the webtunnel listener: %d", code)
	}
	socksConnect(t, "obfs4", bridge.Addr().String(), args)
	select {
	case <-toBridge:
	case <-time.After(10 * time.Second):
		t.Fatal("the bridge was never dialled")
	}
	select {
	case <-toOther:
		t.Fatal("an address that is no bridge was dialled")
	default:
	}

	// bridges off: not even the bridge
	bridgeMu.Lock()
	bridgeOn = false
	bridgeMu.Unlock()
	if code := socksConnect(t, "obfs4", bridge.Addr().String(), args); code != byte(socks5.ReplyConnectionNotAllowed) {
		t.Fatalf("with bridges off the bridge answered %d", code)
	}
}

// any app on the phone can reach the listeners. one that sends its own
// url, front or ice in the handshake must get the configured ones dialled,
// never its own.
func TestForeignClientCannotSteerWebtunnel(t *testing.T) {
	ours, toOurs := knocks(t)
	theirs, toTheirs := knocks(t)
	useBridges(t, true, fmt.Sprintf(
		"webtunnel [2001:db8::7]:443 %s url=https://%s/path ver=0.0.1", testFP, ours.Addr()))

	args := fmt.Sprintf("url=https://%s/;addr=%s;servername=evil.example", theirs.Addr(), theirs.Addr())
	// a target that is no line
	if code := socksConnect(t, "webtunnel", "[2001:db8::8]:443", args); code != byte(socks5.ReplyConnectionNotAllowed) {
		t.Fatalf("a foreign target answered %d", code)
	}
	socksConnect(t, "webtunnel", "[2001:db8::7]:443", args)
	select {
	case <-toOurs:
	case <-time.After(10 * time.Second):
		t.Fatal("the line's own url was never dialled")
	}
	select {
	case <-toTheirs:
		t.Fatal("the url from the handshake was dialled")
	case <-time.After(time.Second):
	}
}

func TestForeignClientCannotSteerSnowflake(t *testing.T) {
	ourFront, toOurFront := knocks(t)
	theirFront, toTheirFront := knocks(t)
	ourStun, toOurStun := udpKnocks(t)
	theirStun, toTheirStun := udpKnocks(t)
	useBridges(t, true, fmt.Sprintf(
		"snowflake 192.0.2.3:80 %s fingerprint=%s url=https://broker.invalid/ front=%s ice=stun:%s",
		testFP, testFP, ourFront.Addr(), ourStun.LocalAddr()))

	args := fmt.Sprintf("fingerprint=%s;url=https://evil.invalid/;front=%s;ice=stun:%s",
		testFP, theirFront.Addr(), theirStun.LocalAddr())
	if code := socksConnect(t, "snowflake", "192.0.2.9:80", args); code != byte(socks5.ReplyConnectionNotAllowed) {
		t.Fatalf("a foreign placeholder answered %d", code)
	}
	socksSend(t, "snowflake", "192.0.2.3:80", args)
	deadline := time.Now().Add(20 * time.Second)
	used := false
	for !used && time.Now().Before(deadline) {
		select {
		case <-toOurFront:
			used = true
		default:
			used = toOurStun.Load() > 0
			time.Sleep(100 * time.Millisecond)
		}
	}
	if !used {
		t.Fatal("neither the line's front nor its stun server was used")
	}
	time.Sleep(2 * time.Second)
	select {
	case <-toTheirFront:
		t.Fatal("the handshake's front was dialled")
	default:
	}
	if n := toTheirStun.Load(); n != 0 {
		t.Fatalf("the handshake's stun server got %d packets", n)
	}
}

func TestListenersOnePerTransport(t *testing.T) {
	if err := startPTListeners(); err != nil {
		t.Fatal(err)
	}
	first := ptPlugins()
	if len(first) != 3 {
		t.Fatalf("plugins: %q", first)
	}
	ports := map[int]bool{}
	for i, n := range ptNames {
		r := ptReg(n)
		if r == nil || ports[r.port] {
			t.Fatalf("%s: no listener of its own", n)
		}
		ports[r.port] = true
		if want := fmt.Sprintf("%s socks5 127.0.0.1:%d", n, r.port); first[i] != want {
			t.Errorf("plugin %d is %q, want %q", i, first[i], want)
		}
	}
	if ptReg("meek_lite") != nil {
		t.Error("meek_lite has a listener")
	}
	for i := 0; i < 10; i++ {
		if err := startPTListeners(); err != nil {
			t.Fatal(err)
		}
	}
	if again := ptPlugins(); strings.Join(again, ",") != strings.Join(first, ",") {
		t.Fatalf("ports moved: %q -> %q", first, again)
	}
}

const (
	tbSnowflake2  = "snowflake 192.0.2.4:80 8838024498816A039FCBBAB14E6F40A0843051FA fingerprint=8838024498816A039FCBBAB14E6F40A0843051FA url=https://1098762253.rsc.cdn77.org/ fronts=app.datapacket.com,www.datapacket.com ice=stun:stun.epygi.com:3478,stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,stun:stun.mixvoip.com:3478,stun:stun.telnyx.com:3478,stun:stun.hot-chilli.net:3478,stun:stun.fitauto.ru:3478,stun:stun.m-online.net:3478 utls-imitate=hellorandomizedalpn"
	testWebtunnel = "webtunnel [2001:db8::1]:443 " + testFP + " url=https://example.com/a1b2c3 ver=0.0.1 servername=www.example.org utls=hellorandomizednoalpn"
)

func TestBridgeLineChecks(t *testing.T) {
	cert := randomCert()
	long := tbSnowflake + strings.Repeat(",stun:stun.example.net:3478", 12)
	for _, c := range []struct {
		line string
		ok   bool
	}{
		{tbObfs4, true},
		{"OBFS4 1.2.3.4:443 " + testFP + " cert=" + cert + " iat-mode=1", true},
		{"obfs4 1.2.3.4:443 " + testFP + " iat-mode=0", false},
		{"obfs4 1.2.3.4:443 " + testFP + " cert=" + cert, false},
		{"obfs4 1.2.3.4:443 " + testFP + " cert=" + cert + " iat-mode=7", false},
		{"obfs4 1.2.3.4:443 " + testFP + " cert=abc iat-mode=0", false},
		{"obfs4 1.2.3.4 " + testFP + " cert=" + cert + " iat-mode=0", false},
		{"obfs4 1.2.3.4:99999 " + testFP + " cert=" + cert + " iat-mode=0", false},
		{"obfs4 1.2.3.4:443 NOTHEX cert=" + cert + " iat-mode=0", false},
		{testWebtunnel, true},
		{"webtunnel 1.2.3.4:443 " + testFP + " url=https://example.com/x", true},
		{"webtunnel 2001:db8::1:443 " + testFP + " url=https://example.com/x", false},
		{"webtunnel [2001:db8::1]:443 url=https://example.com/x", false},
		{"webtunnel [2001:db8::1]:443 " + testFP + " url=http://example.com/x", false},
		{"webtunnel [2001:db8::1]:443 " + testFP + " ver=0.0.1", false},
		{"obfs4 bridge.example.net:443 " + testFP + " cert=" + cert + " iat-mode=0", false},
		{"webtunnel example.net:443 " + testFP + " url=https://example.com/x", false},
		{tbSnowflake, true},
		{tbSnowflake2, true},
		{strings.Replace(tbSnowflake, " ice=", " x=", 1), true},
		{strings.Replace(tbSnowflake, " fingerprint=", " fp=", 1), false},
		{strings.Replace(tbSnowflake, "fingerprint=2B28", "fingerprint=3B28", 1), false},
		{strings.Replace(tbSnowflake, " 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint", " fingerprint", 1), false},
		{strings.Replace(tbSnowflake, "url=https://", "url=http://", 1), false},
		{strings.Replace(tbSnowflake, " fronts=app.datapacket.com,www.datapacket.com", "", 1), false},
		{strings.Replace(tbSnowflake, " fronts=", " front=", 1), true},
		{strings.Replace(tbSnowflake, "hellorandomizedalpn", "hellobogus", 1), false},
		{tbSnowflake + " max=3", true},
		{tbSnowflake + " max=4", false},
		{strings.Replace(tbSnowflake, "stun:", "turn:", -1), false},
		{strings.Replace(tbSnowflake, " url=https://1098762253.rsc.cdn77.org/", "", 1), false},
		{tbSnowflake + " sqsqueue=https://sqs.us-east-1.amazonaws.com/1/q", false},
		{tbSnowflake + " ampcache=https://cdn.ampproject.org/", false},
		{long, false},
		{"meek_lite 192.0.2.20:80 url=https://1603026938.rsc.cdn77.org front=www.phpmyadmin.net", false},
		{"obfs3 1.2.3.4:443 " + testFP, false},
		{"1.2.3.4:443 " + testFP, false},
		{"", false},
		{"obfs4", false},
	} {
		if _, err := checkBridgeLine(c.line); (err == nil) != c.ok {
			t.Errorf("%q: ok=%v, err=%v", c.line, c.ok, err)
		}
	}
	if _, err := checkBridgeLine(long); err != errLineLong {
		t.Errorf("a long line: %v", err)
	}
	// fits on its own, not with the token tor gets on every line
	plain := "obfs4 1.2.3.4:443 " + testFP + " cert=" + cert + " iat-mode=0"
	pad := ptArgsMax - ptArgsLen(mustParse(t, plain).kv) - 1 - len("x=")
	nearly := plain + " x=" + strings.Repeat("a", pad)
	if n := ptArgsLen(mustParse(t, nearly).kv); n != ptArgsMax {
		t.Fatalf("padding came to %d", n)
	}
	if _, err := checkBridgeLine(nearly); err != errLineLong {
		t.Errorf("the token was not counted: %v", err)
	}
	if n := ptArgsLen(mustParse(t, tbSnowflake).kv); n > ptArgsMax {
		t.Errorf("tor browser's snowflake line is %d bytes of arguments", n)
	}
}

func mustParse(t *testing.T, s string) bridgeLine {
	t.Helper()
	b, err := parseBridgeLine(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestPTArgsLenCountsEscapes(t *testing.T) {
	if n := ptArgsLen([]string{"a=b", `c=d;e\f`}); n != 3+1+9 {
		t.Fatalf("%d", n)
	}
}

func TestSortBridgeLines(t *testing.T) {
	cert := randomCert()
	dup := "obfs4 [2001:DB8::1]:443 " + testFP + " cert=" + cert + " iat-mode=0"
	good, bad, _ := sortBridgeLines(strings.Join([]string{
		tbObfs4, "", "  ", tbSnowflake, tbSnowflake2, testWebtunnel,
		"obfs4 [2001:db8::1]:443 " + testFP + " cert=" + cert + " iat-mode=0",
		dup, "nonsense",
	}, "\n"))
	if len(good) != 5 || len(bad) != 2 || bad[0] != dup {
		t.Fatalf("good %d %q, bad %q", len(good), good, bad)
	}
}

// logs never carry a bridge's address, whatever happens to it
func TestBridgeLogsCarryNoAddress(t *testing.T) {
	var buf bytes.Buffer
	old := log.Writer()
	log.SetOutput(&buf)
	t.Cleanup(func() { log.SetOutput(old) })
	dead, _ := net.Listen("tcp", "127.0.0.1:0")
	addr := dead.Addr().String()
	dead.Close()
	cert := randomCert()
	useBridges(t, true, fmt.Sprintf("obfs4 %s %s cert=%s iat-mode=0", addr, testFP, cert))
	for i := 0; i < bridgeDeadAfter+1; i++ {
		socksConnect(t, "obfs4", addr, "cert="+cert+";iat-mode=0")
	}
	socksConnect(t, "obfs4", "127.0.0.1:1", "a=b")
	_, port, _ := net.SplitHostPort(addr)
	if out := buf.String(); out == "" || strings.Contains(out, addr) || strings.Contains(out, ":"+port) {
		t.Fatalf("logs:\n%s", out)
	}
}

func TestBridgeAddressesCompareWhateverTheirSpelling(t *testing.T) {
	for _, c := range [][2]string{
		{"1.2.3.4:443", "1.2.3.4:443"},
		{"[2001:DB8::1]:443", "[2001:db8::1]:443"},
		{"[2001:db8:0::1]:443", "[2001:db8::1]:443"},
	} {
		if bridgeAddrKey(c[0]) != bridgeAddrKey(c[1]) {
			t.Errorf("%s and %s differ", c[0], c[1])
		}
	}
	if bridgeAddrKey("1.2.3.4") != "" || bridgeAddrKey("") != "" {
		t.Error("an address without a port has a key")
	}
}

// tor's own log lines name bridges by address and fingerprint
func TestTorLogLinesLoseBridgeAddresses(t *testing.T) {
	var buf bytes.Buffer
	old := log.Writer()
	log.SetOutput(&buf)
	t.Cleanup(func() { log.SetOutput(old) })
	useBridges(t, true, tbObfs4, testWebtunnel, tbSnowflake)
	noteBridgeSecrets(bridgeLines())
	g := &gatedWriter{on: 1}
	g.Write([]byte("[warn] Proxy Client: unable to connect OR connection (handshaking (proxy)) " +
		"with 37.218.245.14:38224 ID=<none> RSA_ID=D9A82D2F9C2F65A18407B1D2B764F130847F8B5D\n"))
	g.Write([]byte("[notice] new bridge descriptor at [2001:db8::1]:443 for " + testFP + " via example.com\n"))
	g.Write([]byte("rendezvous through www.datapacket.com, stun stun.telnyx.com:3478\n"))
	out := buf.String()
	for _, w := range []string{"37.218.245.14", "D9A82D2F9C2F65A18407B1D2B764F130847F8B5D", "2001:db8::1",
		testFP, "example.com", "www.datapacket.com", "stun.telnyx.com"} {
		if strings.Contains(out, w) {
			t.Errorf("%q in %q", w, out)
		}
	}
	if !strings.Contains(out, "unable to connect") {
		t.Fatalf("the line itself is gone: %q", out)
	}
}

// lines saved by 0.5.0: no iat-mode, a transport in capitals, no
// fingerprint. they load, come out the way tor and lyrebird read them, and
// the listener dials them.
func TestStoredLinesFrom050SurviveBoot(t *testing.T) {
	useBridges(t, false)
	bridge, toBridge := knocks(t)
	cert := randomCert()
	stored := strings.Join([]string{
		fmt.Sprintf("obfs4 %s %s cert=%s", bridge.Addr(), testFP, cert),
		"OBFS4 192.0.2.50:443 cert=" + randomCert() + " iat-mode=1",
		tbObfs4,
	}, "\n")
	if r := setBridges(stored, true); r != "ok: 3 bridges" {
		t.Fatalf("boot: %s", r)
	}
	if got := bridgeLineChecks(); got != `[{"i":0,"state":"fixed"},{"i":1,"state":"fixed"},{"i":2,"state":"ok"}]` {
		t.Fatalf("checks: %s", got)
	}
	lines := bridgeLines()
	if !strings.HasSuffix(lines[0], " iat-mode=0") || !strings.HasPrefix(lines[1], "obfs4 ") || lines[2] != tbObfs4 {
		t.Fatalf("lines: %q", lines)
	}
	socksConnect(t, "obfs4", bridge.Addr().String(), "x=y")
	select {
	case <-toBridge:
	case <-time.After(10 * time.Second):
		t.Fatal("a stored 0.5.0 line was never dialled")
	}
}

// a stored line that cannot be used is kept and marked, by its place in
// the list, without its contents in the reason
func TestBrokenStoredLineKeptAndMarked(t *testing.T) {
	useBridges(t, false)
	stored := strings.Join([]string{
		tbObfs4,
		"obfs4 198.51.100.7:443 cert=tooshort iat-mode=0",
		"",
		"webtunnel 198.51.100.8:443 " + testFP + " url=http://plain.example/x",
		"nonsense",
		"obfs4 bridge.example.net:443 cert=" + randomCert() + " iat-mode=0",
	}, "\n")
	if r := setBridges(stored, true); r != "ok: 1 accepted, 4 not understood" {
		t.Fatalf("boot: %s", r)
	}
	if !bridgesEnabled() || len(bridgeLines()) != 1 {
		t.Fatalf("the good line was not kept on: %q", bridgeLines())
	}
	var checks []lineCheck
	if err := json.Unmarshal([]byte(bridgeLineChecks()), &checks); err != nil {
		t.Fatal(err)
	}
	if len(checks) != 5 || checks[0].State != "ok" {
		t.Fatalf("checks: %+v", checks)
	}
	for _, c := range checks[1:] {
		if c.State != "broken" || c.Why == "" {
			t.Fatalf("line %d: %+v", c.I, c)
		}
		for _, w := range []string{"198.51.100", "tooshort", "plain.example", "bridge.example"} {
			if strings.Contains(c.Why, w) {
				t.Fatalf("line %d's reason quotes it: %q", c.I, c.Why)
			}
		}
	}
	t.Logf("%+v", checks)
}
