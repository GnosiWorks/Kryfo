// SPDX-License-Identifier: GPL-3.0-or-later
package main

// moat: the tor project's bridge service. tor being blocked is why anyone
// asks it, so it is reached outside tor: by default through meek, domain
// fronted through a cdn as tor browser does, so the network sees tls to the
// cdn's front only. plain https to bridges.torproject.org is a manual last
// resort the app offers behind a warning, never something automatic does.
// once tor is up the built-in lines are refreshed through tor instead.
//
// every call but the built-in refresh through tor needs an explicit consent
// flag, and none is made while a decoy session is open, or before the app
// has said whether one is. the tls inside every path is pinned to the roots
// in moat_roots.crt.
// nothing moat returns is logged.

import "C"

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	pt "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/goptlib"
)

// the service. tests point these at a stand-in.
var (
	moatHost = "bridges.torproject.org"
	moatPath = "/moat"
)

// tor browser's bridgedb_targets: the reflector, then its fronts. reviewed
// at release, and every host in it is on the allowlist in builtin.go.
var moatTargets = "https://1723079976.rsc.cdn77.org|cdn.zk.mk+www.cdn77.com"

// let's encrypt's roots, the ca bridges.torproject.org uses. nothing else
// is trusted for moat, so a ca pushed onto the phone cannot read it.
//
//go:embed moat_roots.crt
var moatRootsPEM []byte

var moatRoots = func() *x509.CertPool {
	p := x509.NewCertPool()
	if !p.AppendCertsFromPEM(moatRootsPEM) {
		panic("moat roots")
	}
	return p
}()

// bridgedb speaks jsonapi and is picky about the content type
const moatContentType = "application/vnd.api+json"

var moatTimeout = 45 * time.Second

// how moat is reached
const (
	viaMeek  = "meek"
	viaPlain = "plain"
	viaTor   = "tor"
)

// what the app passes with every moat call
type moatOpts struct {
	// the person agreed to ask the tor project. no call without it except
	// the built-in refresh through tor.
	Consent bool `json:"consent"`
	// meek (the default), plain or tor
	Via string `json:"via,omitempty"`
	// set by automatic, which never takes the plain path
	Automatic bool `json:"automatic,omitempty"`
	// two letters, from the picker. empty lets moat guess.
	Country    string   `json:"country,omitempty"`
	Transports []string `json:"transports,omitempty"`
	// the captcha: what was asked for, and the answer
	Transport string `json:"transport,omitempty"`
	Challenge string `json:"challenge,omitempty"`
	Solution  string `json:"solution,omitempty"`
}

// stable codes the app maps to words
var (
	errMoatConsent     = errors.New("no_consent")
	errMoatDecoy       = errors.New("decoy")
	errMoatPlainAuto   = errors.New("plain_in_automatic")
	errMoatVia         = errors.New("bad_via")
	errMoatUnreachable = errors.New("moat_unreachable")
	errMoatUntrusted   = errors.New("moat_untrusted")
	errMoatReply       = errors.New("moat_bad_reply")
	errMoatWrong       = errors.New("moat_wrong")
	errMoatNoCountry   = errors.New("moat_no_country")
	errMoatNoLines     = errors.New("lines_bad")
	errMoatNoTor       = errors.New("tor_not_ready")
	errMoatArgs        = errors.New("bad_request")
)

// whether a decoy session is open: unknown until the app says, and moat is
// refused while unknown
const (
	decoyUnknown int32 = iota
	decoyOff
	decoyOn
)

var decoyState atomic.Int32

// the app says whether a decoy session is open. 1 open, 0 not.
//
//export HaloSetDecoy
func HaloSetDecoy(on C.int) *C.char {
	setDecoy(on != 0)
	return C.CString("ok")
}

func setDecoy(on bool) {
	if on {
		decoyState.Store(decoyOn)
		// a call under way gives up and dials nothing more
		cancelMoatCalls()
	} else {
		decoyState.Store(decoyOff)
	}
}

// the moat calls under way, so a decoy opening ends them
var moatCalls struct {
	sync.Mutex
	next int
	m    map[int]context.CancelFunc
}

func trackMoatCall(cancel context.CancelFunc) func() {
	moatCalls.Lock()
	defer moatCalls.Unlock()
	if moatCalls.m == nil {
		moatCalls.m = map[int]context.CancelFunc{}
	}
	moatCalls.next++
	id := moatCalls.next
	moatCalls.m[id] = cancel
	return func() {
		moatCalls.Lock()
		delete(moatCalls.m, id)
		moatCalls.Unlock()
	}
}

func cancelMoatCalls() {
	moatCalls.Lock()
	defer moatCalls.Unlock()
	for _, c := range moatCalls.m {
		c()
	}
}

func decoyClosed() bool { return decoyState.Load() == decoyOff }

// moat requests that passed the gate, by path, for the tests
var moatSent struct {
	sync.Mutex
	n map[string]int
}

func noteMoatSent(via string) {
	moatSent.Lock()
	if moatSent.n == nil {
		moatSent.n = map[string]int{}
	}
	moatSent.n[via]++
	moatSent.Unlock()
}

// every rule a call must pass before anything leaves the phone
func moatGate(o moatOpts) (string, error) {
	if !o.Consent {
		return "", errMoatConsent
	}
	if !decoyClosed() {
		return "", errMoatDecoy
	}
	via := o.Via
	if via == "" {
		via = viaMeek
	}
	switch via {
	case viaMeek, viaTor:
	case viaPlain:
		if o.Automatic {
			return "", errMoatPlainAuto
		}
	default:
		return "", errMoatVia
	}
	return via, nil
}

// the raw connections one moat call made. they all close when the call
// ends, and none is made after: meek_lite polls and retries on its own and
// would otherwise keep reaching the cdn after a give-up.
//
// host, targets, roots, fronts and dial are taken when the call starts. a
// dial meek or net/http makes late reads only these, never the package
// values a later call or a test may change.
type moatDials struct {
	ctx     context.Context
	host    string
	targets string
	roots   *x509.CertPool
	fronts  []string
	dial    func(context.Context, string, string) (net.Conn, error)

	mu    sync.Mutex
	conns []net.Conn
	shut  bool
}

func newMoatDials(ctx context.Context) *moatDials {
	d := &moatDials{ctx: ctx, host: moatHost, targets: moatTargets,
		roots: moatRoots, dial: meekNetDial}
	for _, h := range meekHosts(d.targets) {
		if hostAllowed(h) {
			d.fronts = append(d.fronts, h)
		}
	}
	return d
}

func (d *moatDials) tlsConfig() *tls.Config {
	return &tls.Config{
		ServerName: d.host,
		RootCAs:    d.roots,
		MinVersion: tls.VersionTLS12,
	}
}

func (d *moatDials) keep(c net.Conn) (net.Conn, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.shut || d.ctx.Err() != nil {
		c.Close()
		return nil, errors.New("moat: call over")
	}
	d.conns = append(d.conns, c)
	return c, nil
}

func (d *moatDials) closeAll() {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.shut = true
	for _, c := range d.conns {
		c.Close()
	}
	d.conns = nil
}

// meek's own dials go to a front on the allowlist and nowhere else
func (d *moatDials) front(network, addr string) (net.Conn, error) {
	host, _, err := net.SplitHostPort(addr)
	if err != nil || !d.frontAllowed(host) {
		return nil, fmt.Errorf("meek: not an allowed front")
	}
	if d.ctx.Err() != nil {
		return nil, d.ctx.Err()
	}
	c, err := d.dial(d.ctx, network, addr)
	if err != nil {
		return nil, err
	}
	return d.keep(c)
}

// tests reach the front another way
var meekNetDial = (&net.Dialer{Timeout: 20 * time.Second}).DialContext

func (d *moatDials) frontAllowed(host string) bool {
	for _, h := range d.fronts {
		if strings.EqualFold(h, host) {
			return true
		}
	}
	return false
}

// the reflector and front hosts in a targets value
func meekHosts(targets string) []string {
	var out []string
	for _, t := range strings.Split(targets, ",") {
		u, fronts, ok := strings.Cut(t, "|")
		if !ok {
			continue
		}
		out = append(out, urlHost(u))
		for _, f := range strings.Split(fronts, "+") {
			if h, _, err := net.SplitHostPort(f); err == nil {
				f = h
			}
			out = append(out, f)
		}
	}
	return out
}

// the outer tls hello toward the cdn. tor browser's moat passes only
// targets, so lyrebird uses its default, chrome's; named here so a new
// lyrebird default does not change it unseen.
const meekHello = "hellochrome_auto"

// a tunnel to moat through meek. meek_lite ignores the target, the
// reflector's server decides where the bytes go.
func meekDial(d *moatDials) (net.Conn, error) {
	f, err := ptClientFactory("meek_lite")
	if err != nil {
		return nil, err
	}
	args := pt.Args{}
	args.Add("targets", d.targets)
	args.Add("utls", meekHello)
	parsed, err := f.ParseArgs(&args)
	if err != nil {
		return nil, err
	}
	return f.Dial("tcp", net.JoinHostPort(d.host, "443"), d.front, parsed)
}

// tests replace this to count and to stand in for the network
var moatTransport = moatTransportFor

func moatTransportFor(via string, d *moatDials) (*http.Transport, error) {
	tr := &http.Transport{
		DisableKeepAlives:   true,
		TLSClientConfig:     d.tlsConfig(),
		TLSHandshakeTimeout: 30 * time.Second,
		MaxIdleConns:        1,
	}
	switch via {
	case viaMeek:
		tr.DialTLSContext = func(ctx context.Context, _, _ string) (net.Conn, error) {
			c, err := meekDial(d)
			if err != nil {
				return nil, err
			}
			if c, err = d.keep(c); err != nil {
				return nil, err
			}
			tc := tls.Client(c, d.tlsConfig())
			if err := tc.HandshakeContext(ctx); err != nil {
				c.Close()
				return nil, err
			}
			return tc, nil
		}
	case viaPlain:
		tr.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
			if host, _, _ := net.SplitHostPort(addr); host != d.host {
				return nil, fmt.Errorf("moat: not the moat host")
			}
			c, err := (&net.Dialer{Timeout: 20 * time.Second}).DialContext(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			return d.keep(c)
		}
	case viaTor:
		mu.Lock()
		t := torNode
		mu.Unlock()
		if t == nil || !torReadyNow() {
			return nil, errMoatNoTor
		}
		td, err := torDialerAs(context.Background(), t, laneName(laneMoat))
		if err != nil {
			return nil, errMoatNoTor
		}
		tr.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
			c, err := td.DialContext(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			return d.keep(c)
		}
	default:
		return nil, errMoatVia
	}
	return tr, nil
}

// one request. the reply body comes back whatever the status, since moat
// says what went wrong in it.
func moatDo(o moatOpts, method, path string, body any) ([]byte, int, error) {
	via, err := moatGate(o)
	if err != nil {
		return nil, 0, err
	}
	var rd io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return nil, 0, errMoatArgs
		}
		rd = bytes.NewReader(b)
	}
	ctx, cancel := context.WithTimeout(context.Background(), moatTimeout)
	untrack := trackMoatCall(cancel)
	dials := newMoatDials(ctx)
	// a give-up, a timeout or a decoy opening shuts every socket at once
	unhook := context.AfterFunc(ctx, dials.closeAll)
	defer func() {
		cancel()
		untrack()
		unhook()
		dials.closeAll()
	}()
	// a decoy may have opened since the gate
	if !decoyClosed() {
		return nil, 0, errMoatDecoy
	}
	tr, err := moatTransport(via, dials)
	if err != nil {
		return nil, 0, err
	}
	defer tr.CloseIdleConnections()
	req, err := http.NewRequestWithContext(ctx, method, "https://"+dials.host+moatPath+path, rd)
	if err != nil {
		return nil, 0, errMoatArgs
	}
	req.Header.Set("Content-Type", moatContentType)
	req.Header.Set("Accept", moatContentType)
	// empty, so go leaves its own user agent out
	req.Header.Set("User-Agent", "")
	noteMoatSent(via)
	resp, err := (&http.Client{Transport: tr, Timeout: moatTimeout,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		}}).Do(req)
	if err != nil && !decoyClosed() {
		return nil, 0, errMoatDecoy
	}
	if err != nil {
		// the error can name a front or an address, so only its kind
		var ue x509.UnknownAuthorityError
		var he x509.HostnameError
		if errors.As(err, &ue) || errors.As(err, &he) {
			log.Printf("moat: %s %s: certificate not trusted", via, path)
			return nil, 0, errMoatUntrusted
		}
		log.Printf("moat: %s %s: unreachable", via, path)
		return nil, 0, errMoatUnreachable
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		log.Printf("moat: %s %s: reply cut off", via, path)
		return nil, resp.StatusCode, errMoatUnreachable
	}
	// a decoy opened while the reply was on its way: it is dropped
	if !decoyClosed() {
		return nil, 0, errMoatDecoy
	}
	log.Printf("moat: %s %s: %d, %d bytes", via, path, resp.StatusCode, len(raw))
	return raw, resp.StatusCode, nil
}

// moat's own error list, which comes with a 200 at times
type moatErrors struct {
	Errors []struct {
		Code   int    `json:"code"`
		Status string `json:"status"`
		Detail string `json:"detail"`
	} `json:"errors"`
}

// the first error code in a reply, 0 for none
func moatErrCode(raw []byte) int {
	var e moatErrors
	if json.Unmarshal(raw, &e) != nil || len(e.Errors) == 0 {
		return 0
	}
	if e.Errors[0].Code == 0 {
		return -1
	}
	return e.Errors[0].Code
}

// ---- circumvention settings ----

type moatSettingWire struct {
	Bridges struct {
		Type          string   `json:"type"`
		Source        string   `json:"source"`
		BridgeStrings []string `json:"bridge_strings"`
	} `json:"bridges"`
}

type moatSettingsWire struct {
	Settings []moatSettingWire `json:"settings"`
	Country  string            `json:"country"`
}

// one setting as the engine uses it: a transport and lines tor can take
type moatSetting struct {
	Type   string   `json:"type"`
	Source string   `json:"source"`
	Lines  []string `json:"lines"`
}

type moatSettingsOut struct {
	Settings []moatSetting `json:"settings"`
	// the country moat used, never stored. guessed when the app sent
	// none: moat then maps the address it saw, which over meek is the
	// phone's own as the cdn passes it on, but not every time.
	Country string `json:"country,omitempty"`
	Guessed bool   `json:"guessed,omitempty"`
}

// the transports kryfo can use
func moatTransports(want []string) []string {
	if len(want) == 0 {
		return []string{"obfs4", "snowflake", "webtunnel"}
	}
	var out []string
	for _, w := range want {
		for _, n := range ptNames {
			if w == n {
				out = append(out, w)
			}
		}
	}
	return out
}

// settings in moat's order, each turned into lines kryfo checked. a
// builtin setting gets the reviewed built-in lines, never moat's strings,
// as tor browser does. a setting kryfo cannot use is skipped.
func parseMoatSettings(list []moatSettingWire) []moatSetting {
	var out []moatSetting
	for _, s := range list {
		t := strings.ToLower(s.Bridges.Type)
		known := false
		for _, n := range ptNames {
			known = known || n == t
		}
		if !known {
			continue
		}
		var lines []string
		switch s.Bridges.Source {
		case "builtin":
			lines = builtinLines(t)
		case "bridgedb":
			lines = moatLines(s.Bridges.BridgeStrings, t)
		default:
			continue
		}
		if len(lines) > 0 {
			out = append(out, moatSetting{Type: t, Source: s.Bridges.Source, Lines: lines})
		}
	}
	return out
}

// bridge strings from moat, each with its transport in front and checked
// the way tor will use it. a string without a transport gets the one asked
// for, never obfs4 by default, and one of another transport is left out.
func moatLines(raw []string, transport string) []string {
	var good []string
	for _, b := range raw {
		f := strings.Fields(b)
		if len(f) == 0 || transport == "" {
			continue
		}
		known := false
		for _, n := range ptNames {
			known = known || strings.EqualFold(f[0], n)
		}
		if !known {
			f = append([]string{transport}, f...)
		} else if !strings.EqualFold(f[0], transport) {
			continue
		}
		ln, _ := normaliseBridgeLine(strings.Join(f, " "))
		if moatLineOK(ln) {
			good = append(good, ln)
		}
	}
	return good
}

// a line from moat tor can take. a snowflake line also needs every host
// in it reviewed: its broker, fronts and stun servers are reached outside
// tor, and amp cache and sqs lines are left out by design.
func moatLineOK(ln string) bool {
	b, err := checkBridgeLine(ln)
	if err != nil {
		return false
	}
	if b.transport != "snowflake" {
		return true
	}
	hosts, ok := lineHosts(b)
	if !ok {
		return false
	}
	for _, h := range hosts {
		if !hostAllowed(h) {
			return false
		}
	}
	return true
}

func moatSettingsCall(o moatOpts) (moatSettingsOut, error) {
	body := map[string]any{"transports": moatTransports(o.Transports)}
	if c := strings.ToLower(strings.TrimSpace(o.Country)); c != "" {
		if len(c) != 2 || strings.Trim(c, "abcdefghijklmnopqrstuvwxyz") != "" {
			return moatSettingsOut{}, errMoatArgs
		}
		body["country"] = c
	}
	raw, code, err := moatDo(o, "POST", "/circumvention/settings", body)
	if err != nil {
		return moatSettingsOut{}, err
	}
	out, err := readMoatSettings(raw, code)
	out.Guessed = out.Country != "" && body["country"] == nil
	return out, err
}

func readMoatSettings(raw []byte, code int) (moatSettingsOut, error) {
	switch moatErrCode(raw) {
	case 0:
	case 406:
		return moatSettingsOut{}, errMoatNoCountry
	default:
		return moatSettingsOut{}, errMoatReply
	}
	if code != 200 {
		return moatSettingsOut{}, errMoatReply
	}
	var w moatSettingsWire
	if json.Unmarshal(raw, &w) != nil {
		return moatSettingsOut{}, errMoatReply
	}
	out := moatSettingsOut{Settings: parseMoatSettings(w.Settings)}
	if len(w.Country) == 2 {
		out.Country = strings.ToLower(w.Country)
	}
	return out, nil
}

func moatDefaultsCall(o moatOpts) (moatSettingsOut, error) {
	raw, code, err := moatDo(o, "POST", "/circumvention/defaults",
		map[string]any{"transports": moatTransports(o.Transports)})
	if err != nil {
		return moatSettingsOut{}, err
	}
	out, err := readMoatSettings(raw, code)
	out.Country = ""
	return out, err
}

// the countries moat has settings for, and the transports for each, for
// the country picker
func moatMapCall(o moatOpts) (map[string][]string, error) {
	raw, code, err := moatDo(o, "GET", "/circumvention/map", nil)
	if err != nil {
		return nil, err
	}
	return readMoatMap(raw, code)
}

func readMoatMap(raw []byte, code int) (map[string][]string, error) {
	if code != 200 || moatErrCode(raw) != 0 {
		return nil, errMoatReply
	}
	var w map[string]struct {
		Settings []moatSettingWire `json:"settings"`
	}
	if json.Unmarshal(raw, &w) != nil {
		return nil, errMoatReply
	}
	out := map[string][]string{}
	for c, s := range w {
		if len(c) != 2 {
			continue
		}
		var types []string
		for _, one := range s.Settings {
			types = append(types, strings.ToLower(one.Bridges.Type))
		}
		out[strings.ToLower(c)] = types
	}
	return out, nil
}

// the built-in lines moat has now, per transport, unchecked
func moatBuiltinCall(o moatOpts) (map[string][]string, error) {
	raw, code, err := moatDo(o, "POST", "/circumvention/builtin",
		map[string]any{"transports": moatTransports(o.Transports)})
	if err != nil {
		return nil, err
	}
	return readMoatBuiltin(raw, code)
}

func readMoatBuiltin(raw []byte, code int) (map[string][]string, error) {
	if code != 200 || moatErrCode(raw) != 0 {
		return nil, errMoatReply
	}
	var w map[string][]string
	if json.Unmarshal(raw, &w) != nil {
		return nil, errMoatReply
	}
	return w, nil
}

// ---- the captcha ----

type moatItem struct {
	ID        string   `json:"id,omitempty"`
	Type      string   `json:"type"`
	Version   string   `json:"version"`
	Supported []string `json:"supported,omitempty"`
	Transport string   `json:"transport,omitempty"`
	Image     string   `json:"image,omitempty"`
	Challenge string   `json:"challenge,omitempty"`
	Solution  string   `json:"solution,omitempty"`
	QRCode    string   `json:"qrcode,omitempty"`
	Bridges   []string `json:"bridges,omitempty"`
}

type moatEnvelope struct {
	Data []moatItem `json:"data"`
}

// a captcha as moat sends it. transport is a list, or one name.
type moatChallenge struct {
	Data []struct {
		Transport json.RawMessage `json:"transport"`
		Image     string          `json:"image"`
		Challenge string          `json:"challenge"`
	} `json:"data"`
}

// the transports the captcha may hand out, the one asked for first. moat
// hands out lines for the first transport in the challenge it made from
// this list.
func captchaTransports(first string) []string {
	out := []string{"obfs4", "webtunnel"}
	if first == "webtunnel" {
		out = []string{"webtunnel", "obfs4"}
	}
	return out
}

// the transport a captcha's lines will be: the one asked for
func captchaTransport(o moatOpts) (string, error) {
	t := strings.ToLower(o.Transport)
	switch t {
	case "":
		return "obfs4", nil
	case "obfs4", "webtunnel":
		return t, nil
	}
	return "", errMoatArgs
}

type moatCaptcha struct {
	Image     string `json:"image"`
	Challenge string `json:"challenge"`
	Transport string `json:"transport"`
}

// asks for a captcha. the challenge is opaque, carries a signed time and
// dies after thirty minutes.
func moatFetchCall(o moatOpts) (moatCaptcha, error) {
	t, err := captchaTransport(o)
	if err != nil {
		return moatCaptcha{}, err
	}
	raw, code, err := moatDo(o, "POST", "/fetch", map[string]any{
		"data": []moatItem{{
			Version:   "0.1.0",
			Type:      "client-transports",
			Supported: captchaTransports(t),
		}},
	})
	if err != nil {
		return moatCaptcha{}, err
	}
	return readMoatFetch(raw, code)
}

func readMoatFetch(raw []byte, code int) (moatCaptcha, error) {
	var env moatChallenge
	if code != 200 || moatErrCode(raw) != 0 || json.Unmarshal(raw, &env) != nil || len(env.Data) == 0 {
		return moatCaptcha{}, errMoatReply
	}
	d := env.Data[0]
	if d.Image == "" || d.Challenge == "" {
		return moatCaptcha{}, errMoatReply
	}
	var one string
	var list []string
	if json.Unmarshal(d.Transport, &list) == nil && len(list) > 0 {
		one = list[0]
	} else if json.Unmarshal(d.Transport, &one) != nil {
		one = ""
	}
	return moatCaptcha{Image: d.Image, Challenge: d.Challenge, Transport: one}, nil
}

// sends the answer. a wrong or stale answer is errMoatWrong, and the app
// fetches another captcha.
func moatCheckCall(o moatOpts) ([]string, error) {
	t, err := captchaTransport(o)
	if err != nil {
		return nil, err
	}
	sol := strings.TrimSpace(o.Solution)
	if o.Challenge == "" || sol == "" {
		return nil, errMoatArgs
	}
	raw, code, err := moatDo(o, "POST", "/check", map[string]any{
		"data": []moatItem{{
			ID:        "2",
			Type:      "moat-solution",
			Version:   "0.1.0",
			Transport: t,
			Challenge: o.Challenge,
			Solution:  sol,
			QRCode:    "false",
		}},
	})
	if err != nil {
		return nil, err
	}
	return readMoatCheck(raw, code, t)
}

func readMoatCheck(raw []byte, code int, transport string) ([]string, error) {
	// a wrong or expired answer is 419, in the status or in the body
	if code == 419 || moatErrCode(raw) == 419 {
		return nil, errMoatWrong
	}
	var env moatEnvelope
	if code != 200 || moatErrCode(raw) != 0 || json.Unmarshal(raw, &env) != nil || len(env.Data) == 0 {
		return nil, errMoatReply
	}
	good := moatLines(env.Data[0].Bridges, transport)
	if len(good) == 0 {
		return nil, errMoatNoLines
	}
	return good, nil
}

// ---- exports ----

// {"ok":true,...} or {"error":"<code>"}
func moatReply(v any, err error) string {
	if err != nil {
		b, _ := json.Marshal(map[string]string{"error": err.Error()})
		return string(b)
	}
	m := map[string]any{}
	if v != nil {
		b, _ := json.Marshal(v)
		_ = json.Unmarshal(b, &m)
	}
	m["ok"] = true
	b, _ := json.Marshal(m)
	return string(b)
}

// runs one call with the opts json the app sent
func withMoatOpts(opts string, f func(moatOpts) (any, error)) string {
	var o moatOpts
	if json.Unmarshal([]byte(opts), &o) != nil {
		return moatReply(nil, errMoatArgs)
	}
	v, err := f(o)
	if err == nil && !decoyClosed() {
		v, err = nil, errMoatDecoy
	}
	return moatReply(v, err)
}

// the settings moat has for this country, or the one it guesses. opts as
// moatOpts. {"ok":true,"settings":[{"type","source","lines"}],"country",
// "guessed"}. an empty list means moat has nothing special for that
// country, and the defaults apply.
//
//export HaloMoatSettings
func HaloMoatSettings(cOpts *C.char) *C.char {
	return C.CString(moatSettingsJSON(goStr(cOpts)))
}

func moatSettingsJSON(opts string) string {
	return withMoatOpts(opts, func(o moatOpts) (any, error) {
		out, err := moatSettingsCall(o)
		if err == nil && len(out.Settings) > 0 && decoyClosed() {
			cacheMoatSettings(out.Settings)
		}
		return out, err
	})
}

// the fallback settings for a country moat has none for, same shape
//
//export HaloMoatDefaults
func HaloMoatDefaults(cOpts *C.char) *C.char {
	return C.CString(withMoatOpts(goStr(cOpts), func(o moatOpts) (any, error) {
		return moatDefaultsCall(o)
	}))
}

// {"ok":true,"countries":{"cn":["snowflake",...],...}}, the countries moat
// has settings for
//
//export HaloMoatMap
func HaloMoatMap(cOpts *C.char) *C.char {
	return C.CString(withMoatOpts(goStr(cOpts), func(o moatOpts) (any, error) {
		m, err := moatMapCall(o)
		return map[string]any{"countries": m}, err
	}))
}

// a captcha, for opts.transport (obfs4 or webtunnel).
// {"ok":true,"image":<base64 jpeg>,"challenge","transport"}
//
//export HaloMoatCaptcha
func HaloMoatCaptcha(cOpts *C.char) *C.char {
	return C.CString(moatCaptchaJSON(goStr(cOpts)))
}

func moatCaptchaJSON(opts string) string {
	return withMoatOpts(opts, func(o moatOpts) (any, error) {
		return moatFetchCall(o)
	})
}

// the answer, with opts.transport, challenge and solution.
// {"ok":true,"lines":[...]}, or {"error":"moat_wrong"} for another try.
//
//export HaloMoatAnswer
func HaloMoatAnswer(cOpts *C.char) *C.char {
	return C.CString(moatAnswerJSON(goStr(cOpts)))
}

func moatAnswerJSON(opts string) string {
	return withMoatOpts(opts, func(o moatOpts) (any, error) {
		lines, err := moatCheckCall(o)
		if err != nil {
			return nil, err
		}
		log.Printf("moat: got %d usable bridges", len(lines))
		return map[string]any{"lines": lines}, nil
	})
}
