// SPDX-License-Identifier: GPL-3.0-or-later
package main

// moat against recorded replies (testdata/moat, from moat_live_test.go),
// through a stand-in meek reflector and a stand-in moat with its own ca.

import (
	"bytes"
	"context"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func fixture(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", "moat", name+".json"))
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// the fixture moat would send for a request
func fixtureFor(t *testing.T, r *http.Request, body []byte) string {
	switch r.URL.Path {
	case "/moat/circumvention/builtin":
		return "builtin"
	case "/moat/circumvention/defaults":
		return "defaults"
	case "/moat/circumvention/map":
		return "map"
	case "/moat/circumvention/settings":
		var b struct{ Country string }
		_ = json.Unmarshal(body, &b)
		if b.Country == "" {
			return "settings-guess"
		}
		return "settings-" + b.Country
	case "/moat/fetch":
		if bytes.Contains(body, []byte(`"supported":["webtunnel"`)) {
			return "fetch-webtunnel"
		}
		return "fetch-obfs4"
	case "/moat/check":
		var b moatEnvelope
		_ = json.Unmarshal(body, &b)
		if len(b.Data) > 0 && strings.HasPrefix(b.Data[0].Challenge, "webtunnel") {
			return "check-webtunnel"
		}
		return "check-obfs4"
	}
	t.Errorf("no fixture for %s", r.URL.Path)
	return ""
}

// a stand-in moat with its own ca, answering from the fixtures
type standMoat struct {
	srv  *httptest.Server
	hits atomic.Int64
	pool *x509.CertPool
}

func newStandMoat(t *testing.T) *standMoat {
	m := &standMoat{}
	m.srv = httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		m.hits.Add(1)
		if _, ok := r.Header["User-Agent"]; ok {
			t.Errorf("moat was sent a user agent: %q", r.UserAgent())
		}
		body, _ := io.ReadAll(r.Body)
		if r.Header.Get("Content-Type") != moatContentType {
			t.Errorf("content type %q", r.Header.Get("Content-Type"))
		}
		name := fixtureFor(t, r, body)
		if name == "" {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write(fixture(t, name))
	}))
	t.Cleanup(m.srv.Close)
	m.pool = x509.NewCertPool()
	m.pool.AddCert(m.srv.Certificate())
	return m
}

// a stand-in meek reflector: each session is a tcp stream to the moat
// stand-in, and each post carries bytes up and brings back what is there
type standMeek struct {
	srv  *httptest.Server
	hits atomic.Int64
	host atomic.Value
}

func newStandMeek(t *testing.T, upstream string) *standMeek {
	m := &standMeek{}
	var mu sync.Mutex
	sessions := map[string]net.Conn{}
	m.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		m.hits.Add(1)
		m.host.Store(r.Host)
		id := r.Header.Get("X-Session-Id")
		mu.Lock()
		c := sessions[id]
		if c == nil {
			var err error
			if c, err = net.Dial("tcp", upstream); err != nil {
				mu.Unlock()
				http.Error(w, "upstream", http.StatusBadGateway)
				return
			}
			sessions[id] = c
		}
		mu.Unlock()
		up, _ := io.ReadAll(r.Body)
		if len(up) > 0 {
			_, _ = c.Write(up)
		}
		_ = c.SetReadDeadline(time.Now().Add(30 * time.Millisecond))
		buf := make([]byte, 64<<10)
		n, _ := c.Read(buf)
		_, _ = w.Write(buf[:n])
	}))
	t.Cleanup(func() {
		m.srv.Close()
		mu.Lock()
		for _, c := range sessions {
			c.Close()
		}
		mu.Unlock()
	})
	return m
}

// points moat at the stand-ins: meek fronted through 127.0.0.1 to a made-up
// reflector name, moat's own tls checked against the stand-in's ca
func useMoatStandIns(t *testing.T) (*standMoat, *standMeek) {
	t.Helper()
	moat := newStandMoat(t)
	meek := newStandMeek(t, moat.srv.Listener.Addr().String())
	front := meek.srv.Listener.Addr().String()
	oldHost, oldTargets, oldRoots := moatHost, moatTargets, moatRoots
	oldTr, oldDial := moatTransport, meekNetDial
	moatHost = "example.com"
	moatTargets = "http://reflector.example|" + front
	moatRoots = moat.pool
	reviewedHosts["reflector.example"] = true
	reviewedHosts["127.0.0.1"] = true
	moatTransport = moatTransportFor
	t.Cleanup(func() {
		moatHost, moatTargets, moatRoots = oldHost, oldTargets, oldRoots
		moatTransport, meekNetDial = oldTr, oldDial
		delete(reviewedHosts, "reflector.example")
		delete(reviewedHosts, "127.0.0.1")
		decoyState.Store(decoyUnknown)
	})
	setDecoy(false)
	return moat, meek
}

func sentCount() int {
	moatSent.Lock()
	defer moatSent.Unlock()
	n := 0
	for _, v := range moatSent.n {
		n += v
	}
	return n
}

func reply(t *testing.T, s string) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal([]byte(s), &m); err != nil {
		t.Fatalf("not json: %q", s)
	}
	return m
}

func TestMoatOverMeekStandIn(t *testing.T) {
	moat, meek := useMoatStandIns(t)
	r := reply(t, moatSettingsJSON(`{"consent":true,"country":"ir"}`))
	if r["ok"] != true {
		t.Fatalf("settings: %v", r)
	}
	if moat.hits.Load() != 1 || meek.hits.Load() == 0 {
		t.Fatalf("moat %d hits, meek %d", moat.hits.Load(), meek.hits.Load())
	}
	// the cdn sees the reflector's name in the host header, the network
	// only the front
	if h, _ := meek.host.Load().(string); h != "reflector.example" {
		t.Errorf("host header %q", h)
	}
	if r["country"] != "ir" || r["guessed"] == true {
		t.Errorf("country %v guessed %v", r["country"], r["guessed"])
	}
	types := map[string]bool{}
	for _, s := range r["settings"].([]any) {
		types[s.(map[string]any)["type"].(string)] = true
	}
	for _, want := range []string{"obfs4", "webtunnel", "snowflake"} {
		if !types[want] {
			t.Errorf("ir settings lack %s", want)
		}
	}
	if moatSettingsCached() == nil {
		t.Error("settings not cached")
	}
	dropMoatSettings()

	// no country sent: moat's guess comes back marked as one
	r = reply(t, moatSettingsJSON(`{"consent":true}`))
	if r["guessed"] != true || r["country"] != "zz" {
		t.Errorf("guess: %v", r)
	}
}

func TestMoatPinning(t *testing.T) {
	moat, _ := useMoatStandIns(t)
	// the real roots: the stand-in's ca is as foreign as a pushed one
	moatRoots = func() *x509.CertPool {
		p := x509.NewCertPool()
		p.AppendCertsFromPEM(moatRootsPEM)
		return p
	}()
	before := moat.hits.Load()
	if _, err := moatSettingsCall(moatOpts{Consent: true, Country: "ir"}); err != errMoatUntrusted {
		t.Fatalf("got %v, want %v", err, errMoatUntrusted)
	}
	if moat.hits.Load() != before {
		t.Error("a request reached moat over an untrusted tls")
	}
}

func TestMoatRootsArePinned(t *testing.T) {
	var names []string
	rest := moatRootsPEM
	for {
		var blk *pem.Block
		if blk, rest = pem.Decode(rest); blk == nil {
			break
		}
		c, err := x509.ParseCertificate(blk.Bytes)
		if err != nil {
			t.Fatal(err)
		}
		if !c.IsCA || c.CheckSignatureFrom(c) != nil {
			t.Errorf("%s is not a self-signed root", c.Subject)
		}
		names = append(names, c.Subject.CommonName)
	}
	want := "ISRG Root X1,ISRG Root X2,Root YR,Root YE"
	if strings.Join(names, ",") != want {
		t.Errorf("roots %v, want %s", names, want)
	}
	// the system pool is never used
	if moatTLS().RootCAs != moatRoots {
		t.Error("moat tls is not pinned")
	}
}

func TestMeekFrontsOnlyFromTheAllowlist(t *testing.T) {
	moat, meek := useMoatStandIns(t)
	delete(reviewedHosts, "127.0.0.1")
	if _, err := moatSettingsCall(moatOpts{Consent: true, Country: "ir"}); err != errMoatUnreachable {
		t.Fatalf("got %v", err)
	}
	if meek.hits.Load() != 0 || moat.hits.Load() != 0 {
		t.Error("a front off the allowlist was dialled")
	}
	// and the shipped targets are all reviewed
	for _, h := range meekHosts("https://1723079976.rsc.cdn77.org|cdn.zk.mk+www.cdn77.com") {
		if !hostAllowed(h) {
			t.Errorf("%s is not reviewed", h)
		}
	}
}

func TestMoatShippedTargetsReviewed(t *testing.T) {
	for _, h := range meekHosts(moatTargets) {
		if !hostAllowed(h) {
			t.Errorf("moat target %s is not reviewed", h)
		}
	}
	if len(meekHosts(moatTargets)) < 2 {
		t.Error("no front in moatTargets")
	}
}

func TestMoatGate(t *testing.T) {
	moat, meek := useMoatStandIns(t)
	plain := 0
	moatTransport = func(via string, d *moatDials) (*http.Transport, error) {
		if via == viaPlain {
			plain++
		}
		return moatTransportFor(via, d)
	}
	sent := sentCount()
	cases := []struct {
		name  string
		decoy int32
		o     moatOpts
		want  error
	}{
		{"no consent", decoyOff, moatOpts{Country: "ir"}, errMoatConsent},
		{"decoy open", decoyOn, moatOpts{Consent: true, Country: "ir"}, errMoatDecoy},
		{"decoy unknown", decoyUnknown, moatOpts{Consent: true, Country: "ir"}, errMoatDecoy},
		{"plain in automatic", decoyOff, moatOpts{Consent: true, Via: viaPlain, Automatic: true}, errMoatPlainAuto},
		{"unknown path", decoyOff, moatOpts{Consent: true, Via: "direct"}, errMoatVia},
	}
	for _, c := range cases {
		decoyState.Store(c.decoy)
		if _, err := moatSettingsCall(c.o); err != c.want {
			t.Errorf("%s: %v, want %v", c.name, err, c.want)
		}
		if _, err := moatFetchCall(c.o); err != c.want {
			t.Errorf("%s captcha: %v, want %v", c.name, err, c.want)
		}
		if _, err := moatBuiltinCall(c.o); err != c.want {
			t.Errorf("%s builtin: %v, want %v", c.name, err, c.want)
		}
	}
	if moat.hits.Load() != 0 || meek.hits.Load() != 0 || sentCount() != sent || plain != 0 {
		t.Errorf("refused calls went out: moat %d meek %d sent %d plain %d",
			moat.hits.Load(), meek.hits.Load(), sentCount()-sent, plain)
	}
	// the exports say the same, as codes
	decoyState.Store(decoyOff)
	for in, want := range map[string]string{
		`{"country":"ir"}`: "no_consent",
		`{"consent":true,"via":"plain","automatic":true}`: "plain_in_automatic",
		`not json`: "bad_request",
	} {
		if r := reply(t, moatSettingsJSON(in)); r["error"] != want {
			t.Errorf("%s: %v, want %s", in, r, want)
		}
	}
	// meek is the default path
	if v, _ := moatGate(moatOpts{Consent: true}); v != viaMeek {
		t.Errorf("default path %q", v)
	}
}

func TestBuiltinRefreshNeedsTor(t *testing.T) {
	useMoatStandIns(t)
	sent := sentCount()
	mu.Lock()
	had := torNode
	torNode = nil
	mu.Unlock()
	defer func() { mu.Lock(); torNode = had; mu.Unlock() }()
	r := reply(t, builtinRefreshJSON(`{"consent":true,"force":true,"via":"plain"}`))
	if r["error"] != "tor_not_ready" {
		t.Errorf("refresh without tor: %v", r)
	}
	if sentCount() != sent {
		t.Error("a refresh went out without tor")
	}
}

// through tor the refresh shows moat no address, so it goes out without
// consent. the decoy gate, the tor-only path and the back-off still hold.
func TestBuiltinRefreshNeedsNoConsent(t *testing.T) {
	moat, _ := useMoatStandIns(t)
	resetBuiltinState(t)
	defer func() { builtinMu.Lock(); builtinFailedAt = time.Time{}; builtinMu.Unlock() }()
	var vias []string
	moatTransport = func(via string, d *moatDials) (*http.Transport, error) {
		vias = append(vias, via)
		tr, _ := moatTransportFor(viaPlain, d)
		tr.DialContext = func(ctx context.Context, network, _ string) (net.Conn, error) {
			c, err := (&net.Dialer{}).DialContext(ctx, network, moat.srv.Listener.Addr().String())
			if err != nil {
				return nil, err
			}
			return d.keep(c)
		}
		return tr, nil
	}

	// a decoy open: refused, nothing out, no back-off
	setDecoy(true)
	if r := reply(t, builtinRefreshJSON(`{"force":true}`)); r["error"] != "decoy" {
		t.Fatalf("in a decoy: %v", r)
	}
	if moat.hits.Load() != 0 || builtinBackingOff() {
		t.Fatal("a refused refresh went out")
	}

	setDecoy(false)
	r := reply(t, builtinRefreshJSON(`{"via":"plain"}`))
	if r["ok"] != true || r["kept"] == nil {
		t.Fatalf("refresh without consent: %v", r)
	}
	if moat.hits.Load() != 1 || len(vias) != 1 || vias[0] != viaTor {
		t.Fatalf("refresh went %v, %d hits", vias, moat.hits.Load())
	}
	// the other moat calls still want consent
	if r := reply(t, moatSettingsJSON(`{"via":"tor"}`)); r["error"] != "no_consent" {
		t.Errorf("settings without consent: %v", r)
	}

	// a failed try still holds the next one off, forced or not
	builtinMu.Lock()
	builtinFreshAt = time.Time{}
	builtinMu.Unlock()
	moat.srv.Close()
	if r := reply(t, builtinRefreshJSON(`{}`)); r["error"] != "moat_unreachable" {
		t.Fatalf("with moat gone: %v", r)
	}
	if r := reply(t, builtinRefreshJSON(`{"force":true}`)); r["skipped"] != true {
		t.Errorf("right after a failure: %v", r)
	}
	if len(vias) != 2 {
		t.Errorf("%d tries, want 2", len(vias))
	}
}

func TestMoatSettingsFixtures(t *testing.T) {
	for _, name := range []string{"settings-ir", "settings-cn", "settings-ru", "settings-tm", "defaults"} {
		out, err := readMoatSettings(fixture(t, name), 200)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if len(out.Settings) == 0 {
			t.Errorf("%s: nothing usable", name)
		}
		for _, s := range out.Settings {
			for _, ln := range s.Lines {
				if !strings.HasPrefix(ln, s.Type+" ") {
					t.Errorf("%s: a %s setting with a line of another transport", name, s.Type)
				}
				if !validBridgeLine(ln) {
					t.Errorf("%s: an unusable line kept", name)
				}
				if s.Type == "snowflake" {
					b, _ := parseBridgeLine(ln)
					hosts, ok := lineHosts(b)
					for _, h := range hosts {
						ok = ok && hostAllowed(h)
					}
					if !ok {
						t.Errorf("%s: snowflake line with a host not reviewed", name)
					}
					for _, bad := range []string{"ampcache", "sqsqueue", "google", "amazonaws"} {
						if strings.Contains(ln, bad) {
							t.Errorf("%s: %s line kept", name, bad)
						}
					}
				}
			}
			// a builtin setting is kryfo's own reviewed set
			if s.Source == "builtin" && strings.Join(s.Lines, "\n") != strings.Join(builtinLines(s.Type), "\n") {
				t.Errorf("%s: builtin %s setting is not the bundled set", name, s.Type)
			}
		}
	}
	// moat sends amp cache and sqs snowflake lines for some countries, and
	// they are left out
	for _, name := range []string{"settings-cn", "settings-ru"} {
		var w moatSettingsWire
		_ = json.Unmarshal(fixture(t, name), &w)
		raw, used := 0, 0
		for _, s := range w.Settings {
			if s.Bridges.Type == "snowflake" {
				raw += len(s.Bridges.BridgeStrings)
			}
		}
		out, _ := readMoatSettings(fixture(t, name), 200)
		for _, s := range out.Settings {
			if s.Type == "snowflake" {
				used += len(s.Lines)
			}
		}
		if used >= raw {
			t.Errorf("%s: %d of %d snowflake lines kept, amp or sqs got through", name, used, raw)
		}
	}
	// a country moat has nothing for, and one it guessed
	for _, name := range []string{"settings-de", "settings-guess"} {
		out, err := readMoatSettings(fixture(t, name), 200)
		if err != nil || len(out.Settings) != 0 {
			t.Errorf("%s: %v %v", name, out, err)
		}
	}
	if _, err := readMoatSettings([]byte(`{"errors":[{"code":406,"detail":"Could not find country code for circumvention settings"}]}`), 200); err != errMoatNoCountry {
		t.Errorf("406: %v", err)
	}
	if _, err := readMoatSettings([]byte(`<html>`), 200); err != errMoatReply {
		t.Errorf("html: %v", err)
	}
}

func TestMoatMapAndBuiltinFixtures(t *testing.T) {
	m, err := readMoatMap(fixture(t, "map"), 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(m["ir"]) == 0 || len(m["cn"]) == 0 || len(m["ru"]) == 0 {
		t.Errorf("map: %v", m)
	}
	bi, err := readMoatBuiltin(fixture(t, "builtin"), 200)
	if err != nil {
		t.Fatal(err)
	}
	// the bundled set is what moat had when it was recorded, less the
	// transports kryfo does not speak
	for tr, lines := range builtinBundled {
		have := map[string]bool{}
		for _, ln := range bi[tr] {
			n, _ := normaliseBridgeLine(ln)
			have[n] = true
		}
		for _, ln := range lines {
			if !have[ln] {
				t.Errorf("bundled %s line not in the recorded builtin reply", tr)
			}
		}
	}
}

func TestMoatCaptchaFixtures(t *testing.T) {
	for _, tr := range []string{"obfs4", "webtunnel"} {
		c, err := readMoatFetch(fixture(t, "fetch-"+tr), 200)
		if err != nil {
			t.Fatal(err)
		}
		if c.Transport != tr || c.Image == "" || c.Challenge == "" {
			t.Errorf("fetch %s: transport %q, %d image bytes", tr, c.Transport, len(c.Image))
		}
		lines, err := readMoatCheck(fixture(t, "check-"+tr), 200, tr)
		if err != nil || len(lines) == 0 {
			t.Fatalf("check %s: %v", tr, err)
		}
		for _, ln := range lines {
			if !strings.HasPrefix(ln, tr+" ") {
				t.Errorf("check %s: %q", tr, ln[:12])
			}
		}
	}
	// a reply whose lines lack the transport gets the one asked for, and
	// a webtunnel line never becomes obfs4
	var env moatEnvelope
	_ = json.Unmarshal(fixture(t, "check-webtunnel"), &env)
	var bare []string
	for _, ln := range env.Data[0].Bridges {
		bare = append(bare, strings.SplitN(ln, " ", 2)[1])
	}
	env.Data[0].Bridges = bare
	raw, _ := json.Marshal(env)
	lines, err := readMoatCheck(raw, 200, "webtunnel")
	if err != nil || len(lines) != len(bare) {
		t.Fatalf("bare webtunnel lines: %d, %v", len(lines), err)
	}
	for _, ln := range lines {
		if !strings.HasPrefix(ln, "webtunnel ") {
			t.Errorf("bare line became %q", ln[:10])
		}
	}
	if got := moatLines(env.Data[0].Bridges, "obfs4"); len(got) != 0 {
		t.Errorf("bare webtunnel lines taken as obfs4: %d", len(got))
	}
	var full moatEnvelope
	_ = json.Unmarshal(fixture(t, "check-webtunnel"), &full)
	if got := moatLines(full.Data[0].Bridges, "obfs4"); len(got) != 0 {
		t.Errorf("webtunnel lines kept for obfs4: %d", len(got))
	}
	// a wrong answer: the rdsys docs' 419 in the body, or the status
	doc := []byte(`{"errors":[{"id":"4","type":"moat-bridges","version":"0.1.0","code":419,"status":"No You're A Teapot","detail":"The CAPTCHA solution was incorrect."}]}`)
	if _, err := readMoatCheck(doc, 200, "obfs4"); err != errMoatWrong {
		t.Errorf("419 body: %v", err)
	}
	if _, err := readMoatCheck(nil, 419, "obfs4"); err != errMoatWrong {
		t.Errorf("419 status: %v", err)
	}
	if _, err := moatFetchCall(moatOpts{Consent: true, Transport: "snowflake"}); err != errMoatArgs {
		t.Errorf("snowflake captcha: %v", err)
	}
}

func TestMoatCaptchaOverMeekStandIn(t *testing.T) {
	useMoatStandIns(t)
	for _, tr := range []string{"obfs4", "webtunnel"} {
		r := reply(t, moatCaptchaJSON(`{"consent":true,"transport":"`+tr+`"}`))
		if r["ok"] != true || r["transport"] != tr {
			t.Fatalf("captcha %s: %v", tr, r["error"])
		}
		in, _ := json.Marshal(map[string]any{"consent": true, "transport": tr,
			"challenge": r["challenge"], "solution": "freedom"})
		a := reply(t, moatAnswerJSON(string(in)))
		lines, _ := a["lines"].([]any)
		if a["ok"] != true || len(lines) == 0 {
			t.Fatalf("answer %s: %v", tr, a["error"])
		}
		for _, ln := range lines {
			if !strings.HasPrefix(ln.(string), tr+" ") {
				t.Errorf("answer %s gave another transport", tr)
			}
		}
	}
}

// nothing moat sends reaches the log: no line, address, fingerprint, site
// or captcha image
func TestMoatLogsNothingItGets(t *testing.T) {
	useMoatStandIns(t)
	var buf bytes.Buffer
	old := log.Writer()
	log.SetOutput(&buf)
	defer log.SetOutput(old)
	moatSettingsJSON(`{"consent":true,"country":"ru"}`)
	c := reply(t, moatCaptchaJSON(`{"consent":true,"transport":"webtunnel"}`))
	in, _ := json.Marshal(map[string]any{"consent": true, "transport": "webtunnel",
		"challenge": c["challenge"], "solution": "x"})
	moatAnswerJSON(string(in))
	builtinRefreshJSON(`{"consent":true,"force":true}`)
	logged := buf.String()
	if !strings.Contains(logged, "moat:") {
		t.Fatal("nothing logged at all, the test proves nothing")
	}
	var secrets []string
	for _, name := range []string{"settings-ru", "check-webtunnel"} {
		var v any
		_ = json.Unmarshal(fixture(t, name), &v)
		collectLines(v, &secrets)
	}
	var words []string
	for _, ln := range secrets {
		f := strings.Fields(ln)
		words = append(words, f[1])
		for _, w := range f[2:] {
			if isFingerprint(w) {
				words = append(words, w)
			}
			if k, v, ok := strings.Cut(w, "="); ok && (k == "url" || k == "cert") {
				words = append(words, v)
				if h := urlHost(v); h != "" {
					words = append(words, h)
				}
			}
		}
	}
	img, _ := c["image"].(string)
	words = append(words, img[:32])
	for _, w := range words {
		if strings.Contains(logged, w) {
			t.Errorf("the log carries something moat sent: %.12s", w)
		}
	}
}

func collectLines(v any, out *[]string) {
	switch x := v.(type) {
	case map[string]any:
		for _, e := range x {
			collectLines(e, out)
		}
	case []any:
		for _, e := range x {
			collectLines(e, out)
		}
	case string:
		if f := strings.Fields(x); len(f) > 2 {
			for _, n := range ptNames {
				if f[0] == n {
					*out = append(*out, x)
				}
			}
		}
	}
}

// the plain path checks moat's certificate against the same pinned roots
func TestMoatPlainPinned(t *testing.T) {
	moat, meek := useMoatStandIns(t)
	addr := moat.srv.Listener.Addr().String()
	moatTransport = func(via string, d *moatDials) (*http.Transport, error) {
		rt, err := moatTransportFor(via, d)
		if err != nil || via != viaPlain {
			return rt, err
		}
		dial := rt.DialContext
		rt.DialContext = func(ctx context.Context, network, a string) (net.Conn, error) {
			if _, err := dial(ctx, network, "203.0.113.1:1"); err == nil || !strings.Contains(err.Error(), "not the moat host") {
				t.Errorf("plain dialled a host that is not moat: %v", err)
			}
			if a != "example.com:443" {
				t.Errorf("plain dials %s", a)
			}
			return (&net.Dialer{}).DialContext(ctx, network, addr)
		}
		return rt, nil
	}
	if _, err := moatSettingsCall(moatOpts{Consent: true, Via: viaPlain, Country: "ir"}); err != nil {
		t.Fatalf("plain with the stand-in's ca: %v", err)
	}
	moatRoots = func() *x509.CertPool {
		p := x509.NewCertPool()
		p.AppendCertsFromPEM(moatRootsPEM)
		return p
	}()
	if _, err := moatSettingsCall(moatOpts{Consent: true, Via: viaPlain, Country: "ir"}); err != errMoatUntrusted {
		t.Fatalf("plain with a foreign ca: %v", err)
	}
	if moat.hits.Load() != 1 || meek.hits.Load() != 0 {
		t.Errorf("moat %d hits, meek %d", moat.hits.Load(), meek.hits.Load())
	}
}
