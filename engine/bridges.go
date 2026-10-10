// SPDX-License-Identifier: GPL-3.0-or-later
package main

// bridges. android will not execute a transport binary from app storage, so
// the obfs4, webtunnel and snowflake clients run inside the engine, each as
// a plain socks5 proxy on its own localhost port. tor supports that
// natively:
//
//	ClientTransportPlugin obfs4 socks5 127.0.0.1:<port>
//
// tor sends a bridge's arguments in the socks handshake. they are ignored:
// any app on the phone can reach these ports, and for webtunnel and
// snowflake the arguments say which host to dial. the listener takes the
// target address, finds the active line for it and uses that line's
// arguments, so it only ever dials what the bridge lines say.

import "C"

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	pt "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/goptlib"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/common/socks5"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/base"
)

var (
	bridgeMu   sync.RWMutex
	bridgeOn   bool
	bridgeList []string

	// when a bridge last carried a connection, and how many times each has
	// failed in a row. a list usually contains one or two that no longer
	// work, which is normal and must not look like tor being broken.
	lastBridgeOK time.Time
	bridgeFails  = map[string]int{}
)

const bridgeDeadAfter = 4

// the transports tor gets a listener for, in the order the plugin lines are
// handed over. meek_lite only reaches moat and has no listener.
var ptNames = []string{"obfs4", "webtunnel", "snowflake"}

// one local socks5 listener. ports never change within a process: tor is
// never restarted, and it keeps the plugin lines it was given.
type ptListen struct {
	name    string
	ln      net.Listener
	port    int
	factory base.ClientFactory
	// socks requests tor made here, and when the last one came, unix nanos
	requests atomic.Int64
	lastReq  atomic.Int64
}

var (
	ptMu   sync.Mutex
	ptRegs map[string]*ptListen
)

// true if any bridge worked in the last three minutes. the dialer watchdog
// checks this before blaming tor.
func bridgeWorkingRecently() bool {
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return !lastBridgeOK.IsZero() && time.Since(lastBridgeOK) < 3*time.Minute
}

func noteBridgeOK(key string) {
	bridgeMu.Lock()
	lastBridgeOK = time.Now()
	delete(bridgeFails, key)
	bridgeMu.Unlock()
}

func noteBridgeFail(key string) {
	bridgeMu.Lock()
	bridgeFails[key]++
	n := bridgeFails[key]
	bridgeMu.Unlock()
	if n == bridgeDeadAfter {
		log.Printf("bridges: a %s bridge has failed %d times, skipping it",
			strings.Fields(key)[0], n)
	}
}

// a bridge that has failed this many times in a row is not coming back this
// session. tor still has the line, but we stop wasting dials on it.
func bridgeIsDead(key string) bool {
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return bridgeFails[key] >= bridgeDeadAfter
}

// one bridge line taken apart:
//
//	obfs4 1.2.3.4:443 FINGERPRINT cert=... iat-mode=0
//	webtunnel [2001:db8::1]:443 FINGERPRINT url=https://... ver=0.0.1
//	snowflake 192.0.2.3:80 FINGERPRINT fingerprint=... url=... fronts=... ice=...
type bridgeLine struct {
	transport string
	addr      string
	fp        string
	args      pt.Args
	// the k=v fields as written, in order, for the length tor will send
	kv []string
}

var (
	errLineUnknown = errors.New("not a bridge line kryfo understands")
	errLineLong    = errors.New("arguments too long for tor")
	errLineArgs    = errors.New("arguments not usable")
)

// tor sends a line's arguments as the socks5 username and password, at
// most 255 bytes each
const ptArgsMax = 510

func parseBridgeLine(s string) (bridgeLine, error) {
	var b bridgeLine
	f := strings.Fields(strings.TrimSpace(s))
	if len(f) < 2 {
		return b, errLineUnknown
	}
	b.transport = strings.ToLower(f[0])
	known := false
	for _, n := range ptNames {
		known = known || n == b.transport
	}
	if !known {
		return b, errLineUnknown
	}
	host, port, err := net.SplitHostPort(f[1])
	if err != nil || host == "" {
		return b, fmt.Errorf("bad address")
	}
	if p, err := strconv.Atoi(port); err != nil || p < 1 || p > 65535 {
		return b, fmt.Errorf("bad port")
	}
	if strings.Contains(host, ":") && net.ParseIP(host) == nil {
		return b, fmt.Errorf("bad address")
	}
	b.addr = f[1]
	rest := f[2:]
	if len(rest) > 0 && !strings.Contains(rest[0], "=") {
		if !isFingerprint(rest[0]) {
			return b, fmt.Errorf("bad fingerprint")
		}
		b.fp = strings.ToUpper(rest[0])
		rest = rest[1:]
	}
	b.args = pt.Args{}
	for _, kv := range rest {
		k, v, ok := strings.Cut(kv, "=")
		if !ok || k == "" {
			return b, fmt.Errorf("bad argument")
		}
		b.args.Add(k, v)
		b.kv = append(b.kv, kv)
	}
	return b, nil
}

func isFingerprint(s string) bool {
	if len(s) != 40 {
		return false
	}
	for _, c := range s {
		if !strings.ContainsRune("0123456789abcdefABCDEF", c) {
			return false
		}
	}
	return true
}

// what tor puts in the socks5 username and password: k=v pairs joined by
// semicolons, with semicolons and backslashes escaped
func ptArgsLen(kv []string) int {
	n := 0
	for i, s := range kv {
		if i > 0 {
			n++
		}
		n += len(s) + strings.Count(s, ";") + strings.Count(s, `\`)
	}
	return n
}

// checks a line the way the transport will read it. the transport's own
// argument parser is the judge of its arguments, so what passes here is
// what it accepts at connect time.
func checkBridgeLine(s string) (bridgeLine, error) {
	b, err := parseBridgeLine(s)
	if err != nil {
		return b, err
	}
	if ptArgsLen(b.kv) > ptArgsMax {
		return b, errLineLong
	}
	switch b.transport {
	case "obfs4":
		if _, ok := b.args.Get("cert"); !ok {
			return b, fmt.Errorf("obfs4: no cert")
		}
	case "webtunnel":
		if b.fp == "" {
			return b, fmt.Errorf("webtunnel: no fingerprint")
		}
		u, _ := b.args.Get("url")
		if !strings.HasPrefix(strings.ToLower(u), "https://") {
			return b, fmt.Errorf("webtunnel: url is not https")
		}
	case "snowflake":
		if fp, ok := b.args.Get("fingerprint"); !ok || !isFingerprint(fp) {
			return b, fmt.Errorf("snowflake: no fingerprint")
		}
		if ice, ok := b.args.Get("ice"); ok {
			stun := false
			for _, s := range splitList(ice) {
				stun = stun || strings.HasPrefix(strings.ToLower(s), "stun:")
			}
			if !stun {
				return b, fmt.Errorf("snowflake: no stun server")
			}
		}
	}
	f, err := ptClientFactory(b.transport)
	if err != nil {
		return b, err
	}
	// the parser's own words can quote an argument, so they stay here
	if _, err := f.ParseArgs(&b.args); err != nil {
		return b, fmt.Errorf("%s: %w", b.transport, errLineArgs)
	}
	return b, nil
}

func validBridgeLine(s string) bool {
	_, err := checkBridgeLine(s)
	return err == nil
}

// what became of one line handed to HaloSetBridges, in the order given.
// a line that cannot be used is kept here with its reason, so the app can
// show it as broken instead of it quietly going missing.
type lineCheck struct {
	I     int    `json:"i"`
	State string `json:"state"` // ok, fixed or broken
	Why   string `json:"why,omitempty"`
}

var (
	lineChecksMu sync.Mutex
	lineChecks   []lineCheck
)

// fills in what an older line can safely leave out, and writes the
// transport in lower case as tor names it. lines saved by 0.5.0 have no
// iat-mode at times, and 0 is what obfs4 means without one.
func normaliseBridgeLine(s string) (string, bool) {
	b, err := parseBridgeLine(s)
	if err != nil {
		return s, false
	}
	kv := b.kv
	if _, ok := b.args.Get("iat-mode"); b.transport == "obfs4" && !ok {
		kv = append(append([]string(nil), kv...), "iat-mode=0")
	}
	f := []string{b.transport, b.addr}
	if b.fp != "" {
		f = append(f, b.fp)
	}
	out := strings.Join(append(f, kv...), " ")
	return out, out != strings.Join(strings.Fields(s), " ")
}

// splits pasted or stored text into lines tor can use and lines it cannot,
// with a check per non-empty line. a line whose transport and address
// repeat an earlier one is refused too: the listener finds a line by its
// address, and two would be ambiguous.
func sortBridgeLines(raw string) (good, bad []string, checks []lineCheck) {
	seen := map[string]bool{}
	i := 0
	for _, ln := range strings.Split(raw, "\n") {
		ln = strings.TrimSpace(ln)
		if ln == "" {
			continue
		}
		c := lineCheck{I: i, State: "ok"}
		i++
		fixed, changed := normaliseBridgeLine(ln)
		b, err := checkBridgeLine(fixed)
		switch {
		case err != nil:
			// checkBridgeLine's reasons are fixed text, no values in them
			c.State, c.Why = "broken", err.Error()
			bad = append(bad, ln)
		case seen[b.transport+" "+bridgeAddrKey(b.addr)]:
			c.State, c.Why = "broken", "repeats an earlier line"
			bad = append(bad, ln)
		default:
			seen[b.transport+" "+bridgeAddrKey(b.addr)] = true
			if changed {
				c.State = "fixed"
			}
			good = append(good, fixed)
		}
		checks = append(checks, c)
	}
	return good, bad, checks
}

// the addresses, names and fingerprints of every bridge line used in this
// process. tor's own log lines name the bridge they are about, and those
// pass through scrubBridges before they reach a log.
var (
	bridgeSecretMu sync.Mutex
	bridgeSecrets  = map[string]bool{}
)

func noteBridgeSecrets(lines []string) {
	bridgeSecretMu.Lock()
	defer bridgeSecretMu.Unlock()
	for _, ln := range lines {
		b, err := parseBridgeLine(ln)
		if err != nil {
			continue
		}
		var words []string
		if host, _, err := net.SplitHostPort(b.addr); err == nil {
			words = append(words, host)
			if ip := net.ParseIP(host); ip != nil {
				words = append(words, ip.String())
			}
		}
		words = append(words, b.fp)
		if fp, ok := b.args.Get("fingerprint"); ok {
			words = append(words, strings.ToUpper(fp))
		}
		for _, k := range []string{"url", "servername", "addr"} {
			if v, ok := b.args.Get(k); ok {
				if u, err := url.Parse(v); err == nil && u.Host != "" {
					words = append(words, u.Hostname())
				} else {
					words = append(words, v)
				}
			}
		}
		for _, w := range words {
			if len(w) >= 4 {
				bridgeSecrets[w] = true
			}
		}
	}
}

func scrubBridges(s string) string {
	noteBridgeSecrets(bridgeLines())
	bridgeSecretMu.Lock()
	defer bridgeSecretMu.Unlock()
	for w := range bridgeSecrets {
		s = strings.ReplaceAll(s, w, "[bridge]")
	}
	return s
}

// host:port the way the socks handshake gives it, so a bridge line and a
// target compare whatever brackets or case they were written with
func bridgeAddrKey(addr string) string {
	host, port, err := net.SplitHostPort(strings.TrimSpace(addr))
	if err != nil {
		return ""
	}
	if ip := net.ParseIP(host); ip != nil {
		host = ip.String()
	}
	return strings.ToLower(net.JoinHostPort(host, port))
}

// the active line of this transport whose address is target. the listener
// dials the bridges tor was given and nothing else.
func bridgeFor(transport, target string) (bridgeLine, bool) {
	want := bridgeAddrKey(target)
	if want == "" || !bridgesEnabled() {
		return bridgeLine{}, false
	}
	for _, ln := range bridgeLines() {
		b, err := parseBridgeLine(ln)
		if err == nil && b.transport == transport && bridgeAddrKey(b.addr) == want {
			return b, true
		}
	}
	return bridgeLine{}, false
}

func bridgesEnabled() bool {
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return bridgeOn && len(bridgeList) > 0
}

func bridgeLines() []string {
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return append([]string(nil), bridgeList...)
}

// every argument tor starts with. the scheduler is here rather than in
// bridgeTorArgs because that one returns nothing when bridges are off.
//
// KIST asks the kernel for each socket's unsent bytes with ioctl(SIOCOUTQNSD),
// which android's selinux refuses to an untrusted app. tor only disables KIST
// on EINVAL, so on EACCES it retries every ten milliseconds per socket, and
// each attempt writes a kernel audit line. vanilla is its fallback anyway.
func torArgs() []string {
	a := []string{"--Schedulers", "Vanilla"}
	// an explicit socks port, so a DisableNetwork bounce reopens the same one
	// and a dialer built before it keeps working. see socksport.go.
	if p := socksPin(); p != 0 {
		a = append(a, "--SocksPort", strconv.Itoa(p))
	}
	return append(a, bridgeTorArgs()...)
}

func bridgeTorArgs() []string {
	if !bridgesEnabled() {
		return nil
	}
	if err := startPTListeners(); err != nil {
		log.Printf("bridges: %v, starting direct instead", err)
		return nil
	}
	args := []string{"--UseBridges", "1"}
	for _, p := range ptPlugins() {
		args = append(args, "--ClientTransportPlugin", p)
	}
	lines := bridgeLines()
	for _, b := range lines {
		args = append(args, "--Bridge", b)
	}
	log.Printf("bridges: handing tor %d bridge lines", len(lines))
	return args
}

// the ClientTransportPlugin values for tor, one per transport. all of them
// are set whenever any bridge is on, whatever the lines' transports.
func ptPlugins() []string {
	ptMu.Lock()
	defer ptMu.Unlock()
	var out []string
	for _, n := range ptNames {
		if r := ptRegs[n]; r != nil {
			out = append(out, fmt.Sprintf("%s socks5 127.0.0.1:%d", n, r.port))
		}
	}
	return out
}

func ptReg(name string) *ptListen {
	ptMu.Lock()
	defer ptMu.Unlock()
	return ptRegs[name]
}

// brings up one local socks5 endpoint per transport. idempotent: a running
// set is kept, since tor holds the ports it was told about for the life of
// the process.
func startPTListeners() error {
	ptMu.Lock()
	defer ptMu.Unlock()
	if ptRegs == nil {
		ptRegs = map[string]*ptListen{}
	}
	for _, n := range ptNames {
		if ptRegs[n] != nil {
			continue
		}
		f, err := ptClientFactory(n)
		if err != nil {
			return fmt.Errorf("%s client factory: %w", n, err)
		}
		ln, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			return fmt.Errorf("pt listen: %w", err)
		}
		r := &ptListen{name: n, ln: ln, port: ln.Addr().(*net.TCPAddr).Port, factory: f}
		ptRegs[n] = r
		log.Printf("bridges: %s socks5 listening on 127.0.0.1:%d", n, r.port)
		go r.accept()
	}
	return nil
}

func (r *ptListen) accept() {
	for {
		conn, err := r.ln.Accept()
		if err != nil {
			var ne net.Error
			if errors.As(err, &ne) && ne.Timeout() {
				continue
			}
			log.Printf("bridges: %s accept: %v", r.name, err)
			return
		}
		go r.serve(conn)
	}
}

func (r *ptListen) serve(conn net.Conn) {
	defer func() {
		if p := recover(); p != nil {
			log.Printf("bridges: %s connection panicked: %v", r.name, p)
		}
	}()
	servePTConn(conn, r.name, r.factory, r)
}

// one connection from tor: read the socks request, find the bridge line its
// target belongs to, dial that bridge with the line's own arguments, then
// copy bytes both ways. the arguments in the handshake are never used.
func servePTConn(conn net.Conn, name string, factory base.ClientFactory, r *ptListen) {
	defer conn.Close()

	req, err := socks5.Handshake(conn)
	if err != nil {
		log.Printf("bridges: %s socks handshake: %v", name, err)
		return
	}
	if r != nil {
		r.requests.Add(1)
		r.lastReq.Store(time.Now().UnixNano())
	}
	line, ok := bridgeFor(name, req.Target)
	if !ok {
		log.Printf("bridges: %s: a target that is no bridge in use, refused", name)
		_ = req.Reply(socks5.ReplyConnectionNotAllowed)
		return
	}
	key := name + " " + bridgeAddrKey(line.addr)
	if bridgeIsDead(key) {
		// fail fast rather than making tor wait out another timeout
		_ = req.Reply(socks5.ReplyHostUnreachable)
		return
	}
	args, err := factory.ParseArgs(&line.args)
	if err != nil {
		log.Printf("bridges: %s line not usable", name)
		_ = req.Reply(socks5.ReplyGeneralFailure)
		return
	}
	dial := func(network, addr string) (net.Conn, error) {
		return net.Dial(network, addr)
	}
	remote, err := factory.Dial("tcp", req.Target, dial, args)
	if err != nil {
		log.Printf("bridges: %s dial failed: %s", name, dialErrKind(err))
		noteBridgeFail(key)
		_ = req.Reply(socks5.ErrorToReplyCode(err))
		return
	}
	noteBridgeOK(key)
	defer remote.Close()

	if err = req.Reply(socks5.ReplySucceeded); err != nil {
		log.Printf("bridges: socks reply: %v", err)
		return
	}
	log.Printf("bridges: %s connected", name)

	// the first side to finish ends both. a snowflake stream never sees eof
	// from its far end, so waiting for a half close would hold the
	// transport open after tor has gone.
	done := make(chan struct{}, 2)
	go func() {
		_, _ = io.Copy(remote, conn)
		done <- struct{}{}
	}()
	go func() {
		_, _ = io.Copy(conn, remote)
		done <- struct{}{}
	}()
	<-done
	conn.Close()
	remote.Close()
	<-done
}

// a dial error names the address it failed on, and logs never carry bridge
// addresses, so only its kind is logged
func dialErrKind(err error) string {
	var ne net.Error
	switch {
	case errors.As(err, &ne) && ne.Timeout():
		return "timeout"
	case errors.Is(err, syscall.ECONNREFUSED):
		return "refused"
	case errors.Is(err, syscall.ECONNRESET):
		return "reset"
	case errors.Is(err, syscall.ENETUNREACH), errors.Is(err, syscall.EHOSTUNREACH):
		return "unreachable"
	case errors.Is(err, os.ErrDeadlineExceeded):
		return "timeout"
	}
	return "other"
}

// takes newline separated bridge lines and whether to use them. the caller
// calls HaloRestartTor afterwards, which hands the new config to the running
// tor and bounces its network so it takes.
//
//export HaloSetBridges
func HaloSetBridges(cLines *C.char, on C.int) *C.char {
	return C.CString(setBridges(C.GoString(cLines), on != 0))
}

// HaloSetBridges in plain go, for the tests
func setBridges(raw string, on bool) string {
	good, bad, checks := sortBridgeLines(raw)
	lineChecksMu.Lock()
	lineChecks = checks
	lineChecksMu.Unlock()

	noteBridgeSecrets(good)
	bridgeMu.Lock()
	bridgeList = good
	bridgeOn = on && len(good) > 0
	enabled := bridgeOn
	bridgeMu.Unlock()

	if enabled {
		if err := startPTListeners(); err != nil {
			return fmt.Sprintf("error: %v", err)
		}
	}
	// turning bridges off leaves the listeners up: tor keeps the ports it
	// was given for the life of the process. a localhost socket nobody
	// dials costs nothing.

	if len(bad) > 0 {
		return fmt.Sprintf("ok: %d accepted, %d not understood", len(good), len(bad))
	}
	return fmt.Sprintf("ok: %d bridges", len(good))
}

// a json list with one entry per line of the last HaloSetBridges, in the
// order given: {"i":0,"state":"ok|fixed|broken","why":"..."}. it never
// repeats a line, the app has them.
//
//export HaloBridgeLineChecks
func HaloBridgeLineChecks() *C.char {
	return C.CString(bridgeLineChecks())
}

func bridgeLineChecks() string {
	lineChecksMu.Lock()
	defer lineChecksMu.Unlock()
	b, _ := json.Marshal(append([]lineCheck{}, lineChecks...))
	return string(b)
}

// hand tor the new bridge config and bounce its network so it takes. tor is
// never restarted for this: see reconnectTor for why it cannot be.
//
//export HaloRestartTor
func HaloRestartTor() *C.char {
	// asked for by hand, so the loop guard does not apply
	atomic.StoreInt64(&lastTorRestart, 0)
	routeBump()
	go reconnectTor()
	return C.CString("ok")
}

// android says the default network changed. see networkChanged.
//
//export HaloNetworkChanged
func HaloNetworkChanged() *C.char {
	networkChanged()
	return C.CString("ok")
}

// on|count|port, the port being obfs4's listener, 0 before any
//
//export HaloBridgeState
func HaloBridgeState() *C.char {
	port := 0
	if r := ptReg("obfs4"); r != nil {
		port = r.port
	}
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return C.CString(fmt.Sprintf("%t|%d|%d", bridgeOn, len(bridgeList), port))
}
