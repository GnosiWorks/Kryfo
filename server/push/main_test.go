// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"context"
	"crypto"
	"crypto/ecdh"
	"crypto/hpke"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// the vector engine/push_seal_test.go seals with: one made by the app's
// code must open here
const (
	vectorSeed   = "kryfo push test vector, never a real key"
	vectorPub    = "SNrdb3PnM2ghYWfWaPYQZrJjXAb6T9jQFdg9Fvo_6ls"
	vectorToken  = "fcmTestToken:APA91b_vector-only_0123456789"
	vectorSealed = "AX4ZIJFmHcY44puFSkf2E5Q9IphFdswYnHBChNO9B8xziubrOBUxYXDNDOh20tbhE_jYRV2Qss7L1iseaZJQkfx-R0YchsjzEYbSrtA7OQBs3mR3RexKcsnooe65EIC9hQuOnp8ZnnP8H78fHuAVqIYpp1aTxnWFYsI5Rs5pU8p5o2_FArSt8W4XxyeQl4tEBA1upoU4lHg9_DimSsH9gbqFENXtCuXpSYOnI7m1qdFnMjFW8Zihk0AIk-WnqWh-vxRxvWtgU4Wa_bR5n4rdOKT0C7IPhTyAuamc-E9BnCILh9Y08Pot_jcyTr1VvMMknVud__gcEpTPOcTbLvm0fK13SO3YSFnd3OJQU0lmZhOdMR6Z9LiNOp8IionfZKc3DHDScTwirBWfkpssyH6qgMjx5TCXlpoFmGw2fGiyi5D5pkDPcJ6ThrmMVV9HSD2lmQgd1A2m9n4b0rBI3-A6heduo0EmnHak"
	phoneToken   = "cTestPhone:APA91bHtest_token_for_tests_only-abcdefghijklmnopqrstuvwxyz0123456789"
)

func vectorKey(t *testing.T) hpke.PrivateKey {
	t.Helper()
	k, err := hpke.DHKEM(ecdh.X25519()).DeriveKeyPair([]byte(vectorSeed))
	if err != nil {
		t.Fatal(err)
	}
	return k
}

func TestOpensTheEngineVector(t *testing.T) {
	k := vectorKey(t)
	if pubString(k) != vectorPub {
		t.Fatalf("vector public key %s", pubString(k))
	}
	got, err := open(k, vectorSealed)
	if err != nil || got != vectorToken {
		t.Fatalf("opened to %q, %v", got, err)
	}
}

func TestSixteenSealsDifferAndOpen(t *testing.T) {
	k := vectorKey(t)
	seen := map[string]bool{}
	for i := 0; i < 16; i++ {
		s, err := seal(k.PublicKey(), phoneToken)
		if err != nil {
			t.Fatal(err)
		}
		if seen[s] {
			t.Fatal("two seals of one token are the same")
		}
		seen[s] = true
		if got, err := open(k, s); err != nil || got != phoneToken {
			t.Fatalf("seal %d opened to %q, %v", i, got, err)
		}
	}
}

func TestOpensOnlyWellFormedSeals(t *testing.T) {
	k := vectorKey(t)
	other, _ := hpke.DHKEM(ecdh.X25519()).GenerateKey()
	good, _ := seal(k.PublicKey(), phoneToken)
	foreign, _ := seal(other.PublicKey(), phoneToken)
	raw, _ := b64.DecodeString(good)
	flipped := append([]byte(nil), raw...)
	flipped[len(flipped)-1] ^= 1
	v2 := append([]byte(nil), raw...)
	v2[0] = 2
	badToken, _ := seal(k.PublicKey(), "a token with spaces, which fcm never makes")
	// a token sealed as it is, unpadded: not this version's
	unpaddedCT, _ := hpke.Seal(k.PublicKey(), suiteKDF, suiteAEAD, []byte(sealInfo), []byte(phoneToken))
	unpadded := b64.EncodeToString(append([]byte{sealVersion}, unpaddedCT...))
	shortToken, _ := seal(k.PublicKey(), "short")
	for name, s := range map[string]string{
		"empty":          "",
		"another key":    foreign,
		"one bit off":    b64.EncodeToString(flipped),
		"version 2":      b64.EncodeToString(v2),
		"cut short":      good[:len(good)-10],
		"padded":         good + "==",
		"plain base64":   strings.ReplaceAll(good, "-", "+"),
		"too long":       good + strings.Repeat("A", maxSealed),
		"not a token":    badToken,
		"too short":      shortToken,
		"path traversal": "..%2f..%2fetc",
		"unpadded":       unpadded,
	} {
		if got, err := open(k, s); err == nil {
			t.Errorf("%s: opened to %q", name, got)
		}
	}
}

func TestKeygen(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "box.key")
	pub, err := keygen(path)
	if err != nil {
		t.Fatal(err)
	}
	st, err := os.Stat(path)
	if err != nil || st.Mode().Perm() != 0o600 {
		t.Fatalf("key file mode %v, %v", st.Mode(), err)
	}
	k, err := readKey(path)
	if err != nil || pubString(k) != pub {
		t.Fatalf("read back %v", err)
	}
	// what was printed is the public key only
	if raw, _ := os.ReadFile(path); strings.Contains(pub, strings.TrimSpace(string(raw))) {
		t.Fatal("keygen hands out the private key")
	}
	if _, err := keygen(path); err == nil {
		t.Fatal("keygen wrote over a key")
	}
	if _, err := readKey(filepath.Join(dir, "none")); err == nil {
		t.Fatal("read a key that is not there")
	}
	os.WriteFile(filepath.Join(dir, "bad"), []byte("not a key\n"), 0o600)
	if _, err := readKey(filepath.Join(dir, "bad")); err == nil {
		t.Fatal("read a key from junk")
	}
}

// a throwaway service account and a fake google: its token endpoint and
// fcm's send endpoint
type fakeGoogle struct {
	t   *testing.T
	srv *httptest.Server
	key *rsa.PrivateKey

	mu       sync.Mutex
	sends    []map[string]any
	auths    []string
	tokens   int
	answer   func(n int) (int, string, http.Header)
	delay    time.Duration
	tokenFor int
}

func newFakeGoogle(t *testing.T) *fakeGoogle {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	g := &fakeGoogle{t: t, key: key, tokenFor: 3600}
	g.srv = httptest.NewServer(http.HandlerFunc(g.serve))
	t.Cleanup(g.srv.Close)
	return g
}

func (g *fakeGoogle) serve(w http.ResponseWriter, r *http.Request) {
	switch {
	case r.URL.Path == "/token":
		r.ParseForm()
		g.checkJWT(r.PostForm.Get("assertion"))
		if r.PostForm.Get("grant_type") != "urn:ietf:params:oauth:grant-type:jwt-bearer" {
			g.t.Errorf("grant type %q", r.PostForm.Get("grant_type"))
		}
		g.mu.Lock()
		g.tokens++
		n := g.tokens
		life := g.tokenFor
		g.mu.Unlock()
		json.NewEncoder(w).Encode(map[string]any{
			"access_token": "access-" + string(rune('a'+n)),
			"expires_in":   life,
			"token_type":   "Bearer",
		})
	case r.URL.Path == "/v1/projects/kryfo-test/messages:send":
		if r.Method != http.MethodPost {
			g.t.Errorf("send with %s", r.Method)
		}
		var m map[string]any
		json.NewDecoder(r.Body).Decode(&m)
		g.mu.Lock()
		g.sends = append(g.sends, m)
		g.auths = append(g.auths, r.Header.Get("Authorization"))
		n := len(g.sends)
		answer, delay := g.answer, g.delay
		g.mu.Unlock()
		if delay > 0 {
			time.Sleep(delay)
		}
		code, body, h := http.StatusOK, `{"name":"projects/kryfo-test/messages/1"}`, http.Header{}
		if answer != nil {
			code, body, h = answer(n)
		}
		for k, v := range h {
			w.Header()[k] = v
		}
		w.WriteHeader(code)
		io.WriteString(w, body)
	default:
		http.NotFound(w, r)
	}
}

func (g *fakeGoogle) checkJWT(a string) {
	parts := strings.Split(a, ".")
	if len(parts) != 3 {
		g.t.Errorf("assertion of %d parts", len(parts))
		return
	}
	sig, _ := b64.DecodeString(parts[2])
	sum := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(&g.key.PublicKey, crypto.SHA256, sum[:], sig); err != nil {
		g.t.Errorf("assertion not signed by the service account: %v", err)
	}
	var c map[string]any
	raw, _ := b64.DecodeString(parts[1])
	json.Unmarshal(raw, &c)
	if c["iss"] != "push@kryfo-test.iam.gserviceaccount.com" || c["scope"] != fcmScope ||
		c["aud"] != g.srv.URL+"/token" {
		g.t.Errorf("claims %v", c)
	}
}

func (g *fakeGoogle) saFile(t *testing.T, edit func(m map[string]any)) string {
	t.Helper()
	der, _ := x509.MarshalPKCS8PrivateKey(g.key)
	m := map[string]any{
		"type":           "service_account",
		"project_id":     "kryfo-test",
		"private_key_id": "test-key-id",
		"private_key":    string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})),
		"client_email":   "push@kryfo-test.iam.gserviceaccount.com",
		"token_uri":      g.srv.URL + "/token",
	}
	if edit != nil {
		edit(m)
	}
	b, _ := json.Marshal(m)
	p := filepath.Join(t.TempDir(), "fcm.json")
	os.WriteFile(p, b, 0o600)
	return p
}

func (g *fakeGoogle) sent() []map[string]any {
	g.mu.Lock()
	defer g.mu.Unlock()
	return append([]map[string]any(nil), g.sends...)
}

// the fake token host is the only one besides google's the tests allow
func allowFake(t *testing.T, g *fakeGoogle) {
	old := tokenURLOK
	host := strings.TrimPrefix(g.srv.URL, "http://")
	tokenURLOK = func(u *url.URL) bool { return u.Host == host || old(u) }
	t.Cleanup(func() { tokenURLOK = old })
}

type rig struct {
	g      *gateway
	google *fakeGoogle
	k      hpke.PrivateKey
	clock  time.Time
	timers []func()
}

func newRig(t *testing.T) *rig {
	t.Helper()
	google := newFakeGoogle(t)
	allowFake(t, google)
	f, err := loadFCM(google.saFile(t, nil))
	if err != nil {
		t.Fatal(err)
	}
	f.base = google.srv.URL
	k := vectorKey(t)
	r := &rig{google: google, k: k, clock: time.Unix(1_800_000_000, 0)}
	r.g = newGateway(k, f)
	r.g.now = func() time.Time { return r.clock }
	r.g.after = func(_ time.Duration, f func()) { r.timers = append(r.timers, f) }
	everyone = newLimiter(1000, 1000)
	return r
}

func (r *rig) post(t *testing.T, path string, body []byte) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(body))
	w := httptest.NewRecorder()
	r.g.ServeHTTP(w, req)
	return w
}

func (r *rig) endpoint(t *testing.T, token string) string {
	s, err := seal(r.k.PublicKey(), token)
	if err != nil {
		t.Fatal(err)
	}
	return "/push/" + s
}

func TestKnockSendsAnEmptyHighPriorityMessage(t *testing.T) {
	r := newRig(t)
	if w := r.post(t, r.endpoint(t, phoneToken), nil); w.Code != http.StatusCreated {
		t.Fatalf("answer %d", w.Code)
	}
	sends := r.google.sent()
	if len(sends) != 1 {
		t.Fatalf("%d sends", len(sends))
	}
	msg := sends[0]["message"].(map[string]any)
	if msg["token"] != phoneToken {
		t.Fatalf("sent to %v", msg["token"])
	}
	if _, has := msg["data"]; has {
		t.Fatal("the message carries data")
	}
	if _, has := msg["notification"]; has {
		t.Fatal("the message carries a notification")
	}
	android := msg["android"].(map[string]any)
	if android["priority"] != "HIGH" || android["ttl"] != "3600s" {
		t.Fatalf("android block %v", android)
	}
	if len(msg) != 2 {
		t.Fatalf("message fields %v", msg)
	}
	if r.google.auths[0] != "Bearer access-b" {
		t.Fatalf("auth %q", r.google.auths[0])
	}
}

func TestEverySealOfOnePhoneReachesIt(t *testing.T) {
	r := newRig(t)
	for i := 0; i < 16; i++ {
		r.clock = r.clock.Add(floorGap)
		if w := r.post(t, r.endpoint(t, phoneToken), nil); w.Code != http.StatusCreated {
			t.Fatalf("slot %d answer %d", i, w.Code)
		}
	}
	for _, m := range r.google.sent() {
		if m["message"].(map[string]any)["token"] != phoneToken {
			t.Fatal("a seal reached another token")
		}
	}
	// one access token for all of them
	if r.google.tokens != 1 {
		t.Fatalf("%d access tokens", r.google.tokens)
	}
}

func TestRefusesMalformedInput(t *testing.T) {
	r := newRig(t)
	good := r.endpoint(t, phoneToken)
	cases := []struct {
		name   string
		method string
		path   string
		body   []byte
		code   int
	}{
		{"get", http.MethodGet, good, nil, http.StatusMethodNotAllowed},
		{"put", http.MethodPut, good, nil, http.StatusMethodNotAllowed},
		{"root", http.MethodPost, "/", nil, http.StatusNotFound},
		{"bare push", http.MethodPost, "/push/", nil, http.StatusNotFound},
		{"other path", http.MethodPost, "/gif/" + strings.TrimPrefix(good, "/push/"), nil, http.StatusNotFound},
		{"sub path", http.MethodPost, good + "/x", nil, http.StatusNotFound},
		{"query", http.MethodPost, good + "?up=1", nil, http.StatusNotFound},
		{"junk token", http.MethodPost, "/push/" + strings.Repeat("A", 120), nil, http.StatusNotFound},
		{"big body", http.MethodPost, good, bytes.Repeat([]byte("x"), maxBody+1), http.StatusRequestEntityTooLarge},
	}
	for _, c := range cases {
		req := httptest.NewRequest(c.method, c.path, bytes.NewReader(c.body))
		w := httptest.NewRecorder()
		r.g.ServeHTTP(w, req)
		if w.Code != c.code {
			t.Errorf("%s: %d, want %d", c.name, w.Code, c.code)
		}
	}
	if n := len(r.google.sent()); n != 0 {
		t.Fatalf("%d sends for refused knocks", n)
	}
	// a small body is dropped unread and the knock still goes
	if w := r.post(t, good, []byte("hello")); w.Code != http.StatusCreated {
		t.Fatalf("knock with a small body: %d", w.Code)
	}
}

func TestFloorFoldsKnocksLikeThePhone(t *testing.T) {
	r := newRig(t)
	ep := r.endpoint(t, phoneToken)
	if w := r.post(t, ep, nil); w.Code != http.StatusCreated {
		t.Fatalf("first %d", w.Code)
	}
	r.clock = r.clock.Add(10 * time.Second)
	// another of the phone's endpoints, inside the floor: folded, and one
	// push is owed when the floor is up
	// answered as a push sent now: a fold says nothing of the phone
	if w := r.post(t, r.endpoint(t, phoneToken), nil); w.Code != http.StatusCreated {
		t.Fatalf("inside the floor %d", w.Code)
	}
	if w := r.post(t, ep, nil); w.Code != http.StatusCreated {
		t.Fatalf("third %d", w.Code)
	}
	if len(r.timers) != 1 {
		t.Fatalf("%d pushes owed, want one", len(r.timers))
	}
	if n := len(r.google.sent()); n != 1 {
		t.Fatalf("%d sends inside the floor", n)
	}
	r.clock = r.clock.Add(35 * time.Second)
	r.timers[0]()
	if n := len(r.google.sent()); n != 2 {
		t.Fatalf("%d sends after the floor", n)
	}
	// another phone is not held by this one's floor
	if w := r.post(t, r.endpoint(t, "otherPhone:APA91b_another_test_token_0123456789"), nil); w.Code != http.StatusCreated {
		t.Fatalf("other phone %d", w.Code)
	}
}

func TestThirtyAnHour(t *testing.T) {
	r := newRig(t)
	ep := r.endpoint(t, phoneToken)
	for i := 0; i < floorHour; i++ {
		if w := r.post(t, ep, nil); w.Code != http.StatusCreated {
			t.Fatalf("knock %d: %d", i, w.Code)
		}
		r.clock = r.clock.Add(floorGap)
	}
	w := r.post(t, ep, nil)
	if w.Code != http.StatusTooManyRequests || w.Header().Get("Retry-After") == "" {
		t.Fatalf("past the hour's cap: %d, retry %q", w.Code, w.Header().Get("Retry-After"))
	}
	r.clock = r.clock.Add(time.Hour)
	if w := r.post(t, ep, nil); w.Code != http.StatusCreated {
		t.Fatalf("an hour on: %d", w.Code)
	}
}

func TestGoneTokenIsGoneWithoutAskingAgain(t *testing.T) {
	r := newRig(t)
	r.google.answer = func(int) (int, string, http.Header) {
		return http.StatusNotFound, `{"error":{"code":404,"message":"Requested entity was not found.","details":[{"errorCode":"UNREGISTERED"}]}}`, nil
	}
	ep := r.endpoint(t, phoneToken)
	if w := r.post(t, ep, nil); w.Code != http.StatusGone {
		t.Fatalf("unregistered: %d", w.Code)
	}
	r.clock = r.clock.Add(time.Hour)
	if w := r.post(t, ep, nil); w.Code != http.StatusGone {
		t.Fatalf("again: %d", w.Code)
	}
	if n := len(r.google.sent()); n != 1 {
		t.Fatalf("fcm asked %d times", n)
	}
}

func TestFCMAnswers(t *testing.T) {
	for _, c := range []struct {
		name  string
		code  int
		body  string
		h     http.Header
		want  int
		retry string
	}{
		{"pacing", 429, `{"error":{"details":[{"errorCode":"QUOTA_EXCEEDED"}]}}`, http.Header{"Retry-After": {"30"}}, 429, "30"},
		{"down", 503, `{}`, nil, 502, ""},
		{"bad token", 400, `{"error":{"message":"The registration token is not a valid FCM registration token","details":[{"errorCode":"INVALID_ARGUMENT"}]}}`, nil, 410, ""},
		// a wrong service-account file is ours to fix: no phone loses its endpoints
		{"other project", 403, `{"error":{"details":[{"errorCode":"SENDER_ID_MISMATCH"}]}}`, nil, 502, ""},
		{"bare not found", 404, `{"error":{"code":404,"message":"Not found"}}`, nil, 502, ""},
		{"not json", 404, `<html>gone</html>`, nil, 502, ""},
		{"our credentials", 403, `{"error":{"details":[{"errorCode":"PERMISSION_DENIED"}]}}`, nil, 502, ""},
		{"bad message", 400, `{"error":{"message":"Invalid JSON payload","details":[{"errorCode":"INVALID_ARGUMENT"}]}}`, nil, 502, ""},
	} {
		r := newRig(t)
		r.google.answer = func(int) (int, string, http.Header) { return c.code, c.body, c.h }
		w := r.post(t, r.endpoint(t, phoneToken), nil)
		if w.Code != c.want || w.Header().Get("Retry-After") != c.retry {
			t.Errorf("%s: %d retry %q, want %d %q", c.name, w.Code, w.Header().Get("Retry-After"), c.want, c.retry)
		}
	}
}

func TestStaleAccessTokenIsRenewedOnce(t *testing.T) {
	r := newRig(t)
	r.google.answer = func(n int) (int, string, http.Header) {
		if n == 1 {
			return 401, `{}`, nil
		}
		return 200, `{}`, nil
	}
	if w := r.post(t, r.endpoint(t, phoneToken), nil); w.Code != http.StatusCreated {
		t.Fatalf("answer %d", w.Code)
	}
	if r.google.tokens != 2 || r.google.auths[1] != "Bearer access-c" {
		t.Fatalf("%d tokens, auths %v", r.google.tokens, r.google.auths)
	}
}

func TestSlowFCMAnswersInTime(t *testing.T) {
	r := newRig(t)
	r.google.delay = answerBy + time.Second
	start := time.Now()
	w := r.post(t, r.endpoint(t, phoneToken), nil)
	if w.Code != http.StatusAccepted {
		t.Fatalf("answer %d", w.Code)
	}
	if took := time.Since(start); took > answerBy+500*time.Millisecond {
		t.Fatalf("answered after %v, the relay waits three seconds", took)
	}
	// the push still goes
	deadline := time.Now().Add(5 * time.Second)
	for len(r.google.sent()) == 0 && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	if len(r.google.sent()) != 1 {
		t.Fatal("the slow push never went")
	}
}

// nothing about a token reaches the disk or the log
func TestKeepsNothing(t *testing.T) {
	dir := t.TempDir()
	wd, _ := os.Getwd()
	os.Chdir(dir)
	t.Setenv("TMPDIR", dir)
	defer os.Chdir(wd)
	var logged bytes.Buffer
	log.SetOutput(&logged)
	defer log.SetOutput(os.Stderr)

	r := newRig(t)
	ep := r.endpoint(t, phoneToken)
	for i := 0; i < 5; i++ {
		r.post(t, ep, nil)
		r.post(t, "/push/"+strings.Repeat("B", 100), nil)
		r.clock = r.clock.Add(time.Minute)
	}
	r.g.mu.Lock()
	r.g.sweepLocked(r.clock.Add(2 * time.Hour))
	held := len(r.g.floor)
	r.g.mu.Unlock()
	if held != 0 {
		t.Fatalf("%d phones held two hours on", held)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 0 {
		t.Fatalf("files left: %v", entries)
	}
	out := logged.String()
	for _, secret := range []string{phoneToken, "APA91b", strings.TrimPrefix(ep, "/push/")} {
		if strings.Contains(out, secret) {
			t.Fatalf("the log holds %q", secret)
		}
	}
	// what is held is a keyed hash, never the token
	r.post(t, ep, nil)
	r.g.mu.Lock()
	for h := range r.g.floor {
		if bytes.Contains([]byte(phoneToken), h[:4]) {
			t.Fatal("the floor's key is not a keyed hash")
		}
	}
	r.g.mu.Unlock()
}

func TestServiceAccountFile(t *testing.T) {
	g := newFakeGoogle(t)
	allowFake(t, g)
	pemKey := func() string {
		der, _ := x509.MarshalPKCS8PrivateKey(g.key)
		return string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))
	}()
	for name, edit := range map[string]func(map[string]any){
		"not a service account": func(m map[string]any) { m["type"] = "authorized_user" },
		"no project":            func(m map[string]any) { delete(m, "project_id") },
		"odd project":           func(m map[string]any) { m["project_id"] = "../../x" },
		"no email":              func(m map[string]any) { delete(m, "client_email") },
		"foreign token host":    func(m map[string]any) { m["token_uri"] = "https://evil.example/token" },
		"plain http":            func(m map[string]any) { m["token_uri"] = "http://oauth2.googleapis.com/token" },
		"no key":                func(m map[string]any) { m["private_key"] = "" },
		"broken key":            func(m map[string]any) { m["private_key"] = strings.Replace(pemKey, "M", "_", 5) },
	} {
		_, err := loadFCM(g.saFile(t, edit))
		if err == nil {
			t.Errorf("%s: loaded", name)
			continue
		}
		// an error names a field, never what is in it
		if strings.Contains(err.Error(), "PRIVATE KEY") || strings.Contains(err.Error(), "kryfo-test") ||
			strings.Contains(err.Error(), "push@") {
			t.Errorf("%s: error carries the file: %v", name, err)
		}
	}
	if _, err := loadFCM(filepath.Join(t.TempDir(), "missing.json")); err == nil {
		t.Error("loaded a file that is not there")
	}
	// google's own host passes without the fake
	f, err := loadFCM(g.saFile(t, func(m map[string]any) { m["token_uri"] = "https://oauth2.googleapis.com/token" }))
	if err != nil || f.project != "kryfo-test" {
		t.Fatalf("google's token host: %v", err)
	}
}

func TestCredentialPaths(t *testing.T) {
	t.Setenv("PUSH_KEY_FILE", "")
	t.Setenv("CREDENTIALS_DIRECTORY", "")
	if p := credential("PUSH_KEY_FILE", "box.key"); p != "/etc/kryfo-push/box.key" {
		t.Fatalf("default %s", p)
	}
	t.Setenv("CREDENTIALS_DIRECTORY", "/run/credentials/kryfo-push.service")
	if p := credential("PUSH_KEY_FILE", "box.key"); p != "/run/credentials/kryfo-push.service/box.key" {
		t.Fatalf("systemd %s", p)
	}
	t.Setenv("PUSH_KEY_FILE", "/tmp/k")
	if p := credential("PUSH_KEY_FILE", "box.key"); p != "/tmp/k" {
		t.Fatalf("env %s", p)
	}
}

func TestFloorHasRoomForEveryone(t *testing.T) {
	r := newRig(t)
	r.g.mu.Lock()
	for i := 0; i < floorKept; i++ {
		var h [16]byte
		h[0], h[1], h[2] = byte(i), byte(i>>8), byte(i>>16)
		r.g.floor[h] = &phone{last: r.clock.Add(-2 * time.Hour), hourStart: r.clock.Add(-2 * time.Hour)}
	}
	r.g.mu.Unlock()
	// a full table lets the old go first
	if w := r.post(t, r.endpoint(t, phoneToken), nil); w.Code != http.StatusCreated {
		t.Fatalf("answer %d with a full table of old ones", w.Code)
	}
	r.g.mu.Lock()
	n := len(r.g.floor)
	r.g.mu.Unlock()
	if n != 1 {
		t.Fatalf("%d held after the sweep", n)
	}
}

func TestPushTimesOut(t *testing.T) {
	g := newFakeGoogle(t)
	allowFake(t, g)
	f, _ := loadFCM(g.saFile(t, nil))
	f.base = g.srv.URL
	g.delay = 2 * time.Second
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()
	start := time.Now()
	if o, _ := f.push(ctx, phoneToken); o != failed {
		t.Fatalf("outcome %v", o)
	}
	if time.Since(start) > time.Second {
		t.Fatal("the push outlived its context")
	}
}

// every seal is as long as every other, whatever its token's length
func TestSealsAreOneLength(t *testing.T) {
	k := vectorKey(t)
	short, _ := seal(k.PublicKey(), strings.Repeat("a", 140))
	long, _ := seal(k.PublicKey(), strings.Repeat("b", 300))
	if len(short) != sealedLen || len(long) != sealedLen {
		t.Fatalf("seals of %d and %d characters, want %d", len(short), len(long), sealedLen)
	}
	if got, err := open(k, short); err != nil || got != strings.Repeat("a", 140) {
		t.Fatalf("short opened to %q, %v", got, err)
	}
}

// fcm, answering at once with one outcome for every token but the phone's
type stubFCM struct {
	mu    sync.Mutex
	asked int
	phone string
	junk  outcome
}

func (f *stubFCM) push(_ context.Context, token string) (outcome, time.Duration) {
	f.mu.Lock()
	f.asked++
	f.mu.Unlock()
	if token == f.phone {
		return sent, 0
	}
	return f.junk, 0
}

func junkToken(i int) string { return fmt.Sprintf("junk%08d:%s", i, strings.Repeat("x", 40)) }

// anyone can seal junk with the public key: 200 000 junk tokens, gone at
// fcm, take no phone's row, keep a small table of their own, and a phone
// new to the gateway still gets its push
func TestJunkCannotLockPhonesOut(t *testing.T) {
	r := newRig(t)
	stub := &stubFCM{phone: phoneToken, junk: gone}
	r.g.fcm = stub
	everyone = newLimiter(1e9, 1e9)
	for i := 0; i < floorKept; i++ {
		r.g.knock(junkToken(i))
	}
	r.g.mu.Lock()
	rows, gones := len(r.g.floor), len(r.g.gone)
	r.g.mu.Unlock()
	if rows != 0 {
		t.Fatalf("junk holds %d phone rows", rows)
	}
	if gones > goneKept {
		t.Fatalf("%d gone rows, the cap is %d", gones, goneKept)
	}
	if code, _ := r.g.knock(phoneToken); code != http.StatusCreated {
		t.Fatalf("a real phone after the junk: %d", code)
	}
	// a day on, still: nothing junk left behind blocks it
	r.clock = r.clock.Add(25 * time.Hour)
	if code, _ := r.g.knock(phoneToken); code != http.StatusCreated {
		t.Fatalf("a real phone a day on: %d", code)
	}
}

// junk refused by the global pace takes no row and counts toward nothing
func TestRefusedKnocksHoldNothing(t *testing.T) {
	r := newRig(t)
	r.g.fcm = &stubFCM{phone: phoneToken, junk: gone}
	everyone = newLimiter(0.0001, 1)
	everyone.allow()
	for i := 0; i < 50_000; i++ {
		if code, _ := r.g.knock(junkToken(i)); code != http.StatusTooManyRequests {
			t.Fatalf("junk %d past an empty pace: %d", i, code)
		}
	}
	r.g.mu.Lock()
	rows, gones := len(r.g.floor), len(r.g.gone)
	r.g.mu.Unlock()
	if rows != 0 || gones != 0 {
		t.Fatalf("refused junk holds %d rows and %d gone", rows, gones)
	}
	everyone = newLimiter(1000, 1000)
	if code, _ := r.g.knock(phoneToken); code != http.StatusCreated {
		t.Fatalf("the phone once the pace is back: %d", code)
	}
}

// a full table of live phones is swept at most every few seconds, not on
// every knock that finds it full
func TestFullTableIsNotSweptPerKnock(t *testing.T) {
	r := newRig(t)
	r.g.fcm = &stubFCM{phone: phoneToken, junk: sent}
	r.g.mu.Lock()
	for i := 0; i < floorKept; i++ {
		var h [16]byte
		h[0], h[1], h[2] = byte(i), byte(i>>8), byte(i>>16)
		r.g.floor[h] = &phone{last: r.clock, hourStart: r.clock}
	}
	r.g.mu.Unlock()
	if code, _ := r.g.knock(junkToken(1)); code != http.StatusTooManyRequests {
		t.Fatalf("a full table: %d", code)
	}
	r.g.mu.Lock()
	first := r.g.swept
	r.g.mu.Unlock()
	start := time.Now()
	for i := 2; i < 2000; i++ {
		r.g.knock(junkToken(i))
	}
	if took := time.Since(start); took > time.Second {
		t.Fatalf("2000 knocks on a full table took %v", took)
	}
	r.g.mu.Lock()
	again := r.g.swept
	r.g.mu.Unlock()
	if !again.Equal(first) {
		t.Fatal("swept again within the gap")
	}
}

// the gone table lets its oldest go first, and a gone entry ends after a day
func TestGoneTableKeepsItsCap(t *testing.T) {
	r := newRig(t)
	r.g.mu.Lock()
	defer r.g.mu.Unlock()
	for i := 0; i < goneKept+500; i++ {
		r.g.addGoneLocked(r.g.hash(junkToken(i)), r.clock)
	}
	if len(r.g.gone) != goneKept {
		t.Fatalf("%d gone rows", len(r.g.gone))
	}
	if _, ok := r.g.gone[r.g.hash(junkToken(0))]; ok {
		t.Fatal("the oldest stayed")
	}
	if _, ok := r.g.gone[r.g.hash(junkToken(goneKept+499))]; !ok {
		t.Fatal("the newest went")
	}
}
