package main

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/fiatjaf/eventstore/slicestore"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

const testEP = "https://push.example.org/upAbCdEf?up=1"

type fakeClock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *fakeClock) now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.t
}

func (c *fakeClock) add(d time.Duration) {
	c.mu.Lock()
	c.t = c.t.Add(d)
	c.mu.Unlock()
}

// a knocker on a fake clock whose trailing knocks wait in timers the test
// fires itself. nothing is posted: knocks stay in k.out
type testKnocks struct {
	*knocker
	clock  *fakeClock
	mu     sync.Mutex
	timers []func()
}

func newTestKnocks(t *testing.T) *testKnocks {
	t.Helper()
	tk := &testKnocks{clock: &fakeClock{t: time.Unix(1_800_000_000, 0)}}
	tk.knocker = newKnocker(nil, false)
	tk.now = tk.clock.now
	tk.after = func(_ time.Duration, f func()) {
		tk.mu.Lock()
		tk.timers = append(tk.timers, f)
		tk.mu.Unlock()
	}
	return tk
}

func (tk *testKnocks) fire() {
	tk.mu.Lock()
	ts := tk.timers
	tk.timers = nil
	tk.mu.Unlock()
	for _, f := range ts {
		f()
	}
}

// what is waiting to be posted
func (tk *testKnocks) drain() []knockJob {
	var out []knockJob
	for {
		select {
		case j := <-tk.out:
			out = append(out, j)
		default:
			return out
		}
	}
}

func signedReg(t *testing.T, sk string, endpoint string, at time.Time) nostr.Event {
	t.Helper()
	ev := nostr.Event{Kind: knockKind, CreatedAt: nostr.Timestamp(at.Unix()), Content: endpoint}
	if err := ev.Sign(sk); err != nil {
		t.Fatal(err)
	}
	return ev
}

func keypair() (sk, pk string) {
	sk = nostr.GeneratePrivateKey()
	pk, _ = nostr.GetPublicKey(sk)
	return
}

func TestKnockEndpoints(t *testing.T) {
	for _, c := range []struct {
		url    string
		onions bool
		ok     bool
	}{
		{testEP, false, true},
		{"https://ntfy.sh/upXyZ?up=1", false, true},
		{"https://push.example.org:8443/up", false, true},
		{"http://ntfy.sh/up", false, false},
		{"ftp://ntfy.sh/up", false, false},
		{"https://localhost/up", false, false},
		{"https://a.localhost/up", false, false},
		{"https://127.0.0.1/up", false, false},
		{"https://10.0.0.2/up", false, false},
		{"https://192.168.1.1/up", false, false},
		{"https://169.254.169.254/latest", false, false},
		{"https://100.64.0.1/up", false, false},
		{"https://[::1]/up", false, false},
		{"https://[fd00::1]/up", false, false},
		{"https://[64:ff9b::a00:1]/up", false, false},
		{"https://user:pw@ntfy.sh/up", false, false},
		{"https://ntfy.sh/up#x", false, false},
		{"https:///up", false, false},
		{"https://ntfy.sh/up x", false, false},
		{"https://ntfy.sh/" + strings.Repeat("a", maxEndpointLen), false, false},
		{"http://abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuv.onion/up", false, false},
		{"http://abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuv.onion/up", true, true},
		{"https://8.8.8.8/up", false, true},
	} {
		if got := knockEndpointOK(c.url, c.onions); got != c.ok {
			t.Errorf("%q onions=%v: got %v, want %v", c.url, c.onions, got, c.ok)
		}
	}
}

func TestKnockRegistrationIsCheckedAndOrdered(t *testing.T) {
	tk := newTestKnocks(t)
	sk, pk := keypair()
	now := tk.clock.now()

	stale := signedReg(t, sk, testEP, now.Add(-knockSkew-time.Minute))
	if rej, _ := tk.check(&stale); !rej {
		t.Fatal("a stale registration was taken: it could be a replay")
	}
	ahead := signedReg(t, sk, testEP, now.Add(knockSkew+time.Minute))
	if rej, _ := tk.check(&ahead); !rej {
		t.Fatal("a registration from far ahead was taken")
	}
	tagged := signedReg(t, sk, testEP, now)
	tagged.Tags = nostr.Tags{{"p", pk}}
	if rej, _ := tk.check(&tagged); !rej {
		t.Fatal("a registration with tags was taken")
	}
	private := signedReg(t, sk, "https://127.0.0.1/up", now)
	if rej, _ := tk.check(&private); !rej {
		t.Fatal("a loopback endpoint was taken")
	}

	first := signedReg(t, sk, testEP, now)
	tk.apply(&first)
	if len(tk.regs) != 1 || len(tk.eps) != 1 {
		t.Fatalf("regs %d eps %d after one registration", len(tk.regs), len(tk.eps))
	}
	// an older one, replayed, changes nothing
	older := signedReg(t, sk, "https://other.example.org/up", now.Add(-time.Minute))
	tk.apply(&older)
	if reg := tk.regs[knockKey(pk)]; reg.ep.url != testEP {
		t.Fatalf("an older registration replaced a newer one: %s", reg.ep.url)
	}
	// a newer one with no endpoint forgets it
	forget := signedReg(t, sk, "", now.Add(time.Second))
	tk.apply(&forget)
	if len(tk.regs) != 0 || len(tk.eps) != 0 {
		t.Fatalf("regs %d eps %d after forget", len(tk.regs), len(tk.eps))
	}
}

func TestKnockStoresNoAddress(t *testing.T) {
	tk := newTestKnocks(t)
	sk, pk := keypair()
	ev := signedReg(t, sk, testEP, tk.clock.now())
	tk.apply(&ev)
	raw, _ := hex.DecodeString(pk)
	for key := range tk.regs {
		if bytes.Equal(key[:], raw) || key != knockKey(pk) {
			t.Fatal("the table is keyed by something other than the address's hash")
		}
	}
}

func TestKnockOnWrapWithFloorAndOneTrailing(t *testing.T) {
	tk := newTestKnocks(t)
	sk, pk := keypair()
	reg := signedReg(t, sk, testEP, tk.clock.now())
	tk.apply(&reg)
	_, other := keypair()

	w := wrap(t, other, nil)
	tk.stored(&w)
	if got := tk.drain(); len(got) != 0 {
		t.Fatalf("a wrap for an unregistered address knocked: %v", got)
	}

	// a burst of fifty slices: one knock now, one when the minute is up
	for i := 0; i < 50; i++ {
		w := wrap(t, pk, nil)
		tk.stored(&w)
	}
	got := tk.drain()
	if len(got) != 1 || got[0].url != testEP || got[0].decoy {
		t.Fatalf("knocks right after the burst: %+v", got)
	}
	if len(tk.timers) != 1 {
		t.Fatalf("%d trailing knocks waiting, want 1", len(tk.timers))
	}
	tk.clock.add(knockFloor)
	tk.fire()
	if got := tk.drain(); len(got) != 1 {
		t.Fatalf("trailing knocks: %d, want 1", len(got))
	}
	// quiet after: nothing more
	tk.fire()
	if got := tk.drain(); len(got) != 0 {
		t.Fatalf("knocks after the burst was answered: %d", len(got))
	}
}

func TestKnockStormStaysBounded(t *testing.T) {
	tk := newTestKnocks(t)
	sk, pk := keypair()
	reg := signedReg(t, sk, testEP, tk.clock.now())
	tk.apply(&reg)
	// a wrap every second for an hour: at most one knock a minute, plus
	// the trailing one each minute rolls into
	sent := 0
	for s := 0; s < 3600; s++ {
		w := wrap(t, pk, nil)
		tk.stored(&w)
		tk.clock.add(time.Second)
		if s%60 == 59 {
			tk.fire()
		}
		sent += len(tk.drain())
	}
	if sent > 61 {
		t.Fatalf("%d knocks in an hour of wraps, want at most 61", sent)
	}
	if sent < 59 {
		t.Fatalf("%d knocks in an hour of wraps: wraps went unannounced", sent)
	}
}

func TestKnockDecoysPerEndpointNotPerAddress(t *testing.T) {
	tk := newTestKnocks(t)
	// sixteen addresses on one endpoint, one on another
	for i := 0; i < 16; i++ {
		sk, _ := keypair()
		ev := signedReg(t, sk, testEP, tk.clock.now())
		tk.apply(&ev)
	}
	sk, _ := keypair()
	ev := signedReg(t, sk, "https://push.example.org/upOther", tk.clock.now())
	tk.apply(&ev)

	counts := map[string]int{}
	// four days in timer steps
	for i := 0; i < int(96*time.Hour/knockTick); i++ {
		tk.clock.add(knockTick)
		tk.tick()
		for _, j := range tk.drain() {
			if !j.decoy {
				t.Fatal("a decoy pass sent a real knock")
			}
			counts[j.url]++
		}
	}
	mean := float64(96*time.Hour) / float64(knockDecoyMean)
	for u, n := range counts {
		if float64(n) < mean/3 || float64(n) > mean*3 {
			t.Errorf("%s: %d decoys in four days, expected near %.0f", u, n, mean)
		}
	}
	if len(counts) != 2 {
		t.Fatalf("decoys reached %d endpoints, want 2", len(counts))
	}
	// the number of addresses behind an endpoint does not show in its
	// decoys
	a, b := counts[testEP], counts["https://push.example.org/upOther"]
	if a > 3*b+3 {
		t.Fatalf("sixteen addresses got %d decoys, one got %d", a, b)
	}
}

func TestKnockDecoyKeepsTheFloor(t *testing.T) {
	tk := newTestKnocks(t)
	sk, pk := keypair()
	ev := signedReg(t, sk, testEP, tk.clock.now())
	tk.apply(&ev)
	w := wrap(t, pk, nil)
	tk.stored(&w)
	tk.drain()
	tk.eps[testEP].nextDecoy = tk.clock.now()
	tk.clock.add(time.Second)
	tk.tick()
	if got := tk.drain(); len(got) != 0 {
		t.Fatal("a decoy went out inside the floor of a real knock")
	}
}

func TestKnockExpiry(t *testing.T) {
	tk := newTestKnocks(t)
	sk, pk := keypair()
	ev := signedReg(t, sk, testEP, tk.clock.now())
	tk.apply(&ev)
	tk.clock.add(knockTTL + time.Second)
	w := wrap(t, pk, nil)
	tk.stored(&w)
	if got := tk.drain(); len(got) != 0 {
		t.Fatal("an expired registration was knocked")
	}
	tk.tick()
	if len(tk.regs) != 0 || len(tk.eps) != 0 {
		t.Fatal("an expired registration was kept")
	}
}

func TestKnockGoneEndpointIsDropped(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < 3; i++ {
		sk, _ := keypair()
		ev := signedReg(t, sk, testEP, tk.clock.now())
		tk.apply(&ev)
	}
	tk.post = func(context.Context, string) (int, error) { return http.StatusNotFound, nil }
	tk.send(context.Background(), knockJob{testEP, false})
	if len(tk.regs) != 0 || len(tk.eps) != 0 {
		t.Fatalf("regs %d eps %d after a 404", len(tk.regs), len(tk.eps))
	}
}

func TestKnockCeilingPerEndpoint(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < maxRegsPerEP; i++ {
		sk, _ := keypair()
		ev := signedReg(t, sk, testEP, tk.clock.now())
		tk.apply(&ev)
	}
	sk, _ := keypair()
	ev := signedReg(t, sk, testEP, tk.clock.now())
	if rej, _ := tk.check(&ev); !rej {
		t.Fatal("an endpoint took more addresses than its ceiling")
	}
}

func TestKnockDecoysYieldToRealKnocks(t *testing.T) {
	tk := newTestKnocks(t)
	posts := 0
	tk.post = func(context.Context, string) (int, error) { posts++; return 201, nil }
	tk.rate = newBucket(0, 10)
	for i := 0; i < 10; i++ {
		tk.send(context.Background(), knockJob{testEP, true})
	}
	if posts != 5 {
		t.Fatalf("decoys took %d of a budget of 10, want half", posts)
	}
	for i := 0; i < 5; i++ {
		tk.send(context.Background(), knockJob{testEP, false})
	}
	if posts != 10 {
		t.Fatalf("real knocks got %d of the rest", posts-5)
	}
}

func TestKnockTableSurvivesARestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	db, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	clock := &fakeClock{t: time.Unix(1_800_000_000, 0)}
	k := newKnocker(db, false)
	k.now = clock.now
	sk, pk := keypair()
	ev := signedReg(t, sk, testEP, clock.now())
	k.apply(&ev)
	sk2, _ := keypair()
	ev2 := signedReg(t, sk2, testEP, clock.now().Add(-5*time.Minute))
	k.apply(&ev2)
	db.Close()

	// a day later both come back; a month later only what is left
	for _, c := range []struct {
		after time.Duration
		want  int
	}{{24 * time.Hour, 2}, {knockTTL - 2*time.Minute, 1}} {
		db, err := openKnockStore(path)
		if err != nil {
			t.Fatal(err)
		}
		k := newKnocker(db, false)
		k.now = func() time.Time { return clock.now().Add(c.after) }
		if err := k.load(); err != nil {
			t.Fatal(err)
		}
		if len(k.regs) != c.want {
			t.Fatalf("after %v: %d registrations, want %d", c.after, len(k.regs), c.want)
		}
		if k.regs[knockKey(pk)] == nil {
			t.Fatalf("after %v: the newest registration is gone", c.after)
		}
		var raw int
		db.QueryRow(`SELECT count(*) FROM knock WHERE instr(lower(hex(addr)), ?) > 0`, pk[:16]).Scan(&raw)
		if raw != 0 {
			t.Fatal("the table holds the address itself")
		}
		db.Close()
	}
}

// ---- over a real websocket ----

func testKnockRelay(t *testing.T) (string, *testKnocks) {
	t.Helper()
	relay := khatru.NewRelay()
	db := &slicestore.SliceStore{}
	if err := db.Init(); err != nil {
		t.Fatal(err)
	}
	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	l := applyLimits(relay, "")
	tk := newTestKnocks(t)
	tk.now = time.Now
	applyKnocks(relay, l, tk.knocker)
	srv := httptest.NewServer(relay)
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http"), tk
}

func waitKnocks(tk *testKnocks, n int) []knockJob {
	var got []knockJob
	deadline := time.Now().Add(3 * time.Second)
	for len(got) < n && time.Now().Before(deadline) {
		got = append(got, tk.drain()...)
		time.Sleep(10 * time.Millisecond)
	}
	return got
}

func TestKnockEndToEndOverTheRelay(t *testing.T) {
	url, tk := testKnockRelay(t)
	r := connect(t, url)
	sk, pk := keypair()

	ev := signedReg(t, sk, testEP, time.Now())
	// a listener asking for that very id hears nothing of it
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	spy := connect(t, url)
	sub, err := spy.Subscribe(ctx, nostr.Filters{{IDs: []string{ev.ID}}})
	if err != nil {
		t.Fatal(err)
	}
	<-sub.EndOfStoredEvents

	if err := publish(t, r, ev); err != nil {
		t.Fatalf("the registration was refused: %v", err)
	}
	if got, _ := ask(t, r, nostr.Filter{IDs: []string{ev.ID}}); len(got) != 0 {
		t.Fatal("the registration was stored")
	}
	select {
	case got := <-sub.Events:
		t.Fatalf("a listener was handed the registration: %s", got.Content)
	case <-time.After(300 * time.Millisecond):
	}

	if err := publish(t, r, wrap(t, pk, nil)); err != nil {
		t.Fatal(err)
	}
	got := waitKnocks(tk, 1)
	if len(got) != 1 || got[0].url != testEP {
		t.Fatalf("knocks after a wrap: %+v", got)
	}
	// a wrap the relay refuses knocks nobody
	if err := publish(t, r, wrap(t, pk, func(e *nostr.Event) { e.Tags = append(e.Tags, nostr.Tag{"p", addr()}) })); err == nil {
		t.Fatal("a wrap to two addresses was taken")
	}

	// someone else cannot point the address elsewhere: the registration
	// is signed by the address, so another key registers only itself
	sk2, pk2 := keypair()
	other := signedReg(t, sk2, "https://evil.example.org/up", time.Now())
	if err := publish(t, r, other); err != nil {
		t.Fatal(err)
	}
	if tk.regs[knockKey(pk)].ep.url != testEP || tk.regs[knockKey(pk2)] == nil {
		t.Fatal("a registration reached another address")
	}
}

func TestKnockRelayAdvertisesIt(t *testing.T) {
	url, _ := testKnockRelay(t)
	req, _ := http.NewRequest("GET", "http"+strings.TrimPrefix(url, "ws"), nil)
	req.Header.Set("Accept", "application/nostr+json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var info struct {
		Tags []string `json:"tags"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, tag := range info.Tags {
		found = found || tag == knockTag
	}
	if !found {
		t.Fatalf("the relay info does not say it knocks: %v", info.Tags)
	}
}

func TestOldRelayRefusesRegistrations(t *testing.T) {
	url, _ := testRelay(t)
	r := connect(t, url)
	sk, _ := keypair()
	err := publish(t, r, signedReg(t, sk, testEP, time.Now()))
	if err == nil || !strings.Contains(err.Error(), "only keeps gift wraps") {
		t.Fatalf("a relay without knocks answered %v", err)
	}
}

// ---- the post itself ----

func TestKnockIsAnEmptyPost(t *testing.T) {
	var mu sync.Mutex
	var got *http.Request
	var body []byte
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		mu.Lock()
		got, body = r, b
		mu.Unlock()
		w.WriteHeader(201)
	}))
	defer srv.Close()
	code, err := knockPoster(srv.Client())(context.Background(), srv.URL+"/up")
	if err != nil || code != 201 {
		t.Fatalf("post: %d %v", code, err)
	}
	mu.Lock()
	defer mu.Unlock()
	if got.Method != http.MethodPost || len(body) != 0 {
		t.Fatalf("knock was %s with %d bytes", got.Method, len(body))
	}
	if got.Header.Get("TTL") == "" || got.Header.Get("User-Agent") != "" {
		t.Fatalf("headers: %v", got.Header)
	}
}

func TestKnockClientReachesNothingPrivate(t *testing.T) {
	hit := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hit = true
	}))
	defer srv.Close()
	// a public name that resolves to the box itself is still refused, at
	// the dial
	c := knockClient("tcp4", "")
	_, err := knockPoster(c)(context.Background(), srv.URL+"/up")
	if err == nil || hit {
		t.Fatal("the knock client reached a loopback address")
	}
	if !strings.Contains(err.Error(), errNotPublic.Error()) {
		t.Fatalf("refused for another reason: %v", err)
	}
}

func TestKnockClientFollowsNoRedirect(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://127.0.0.1:1/", http.StatusFound)
	}))
	defer srv.Close()
	c := srv.Client()
	c.CheckRedirect = knockClient("tcp4", "").CheckRedirect
	code, err := knockPoster(c)(context.Background(), srv.URL+"/up")
	if err != nil || code != http.StatusFound {
		t.Fatalf("a redirect was followed: %d %v", code, err)
	}
}

// the whole way: a registration over the websocket, a wrap to that
// address, and the knock arriving at a push server as an empty post
func TestKnockReachesAPushServer(t *testing.T) {
	var mu sync.Mutex
	var bodies []int
	push := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		mu.Lock()
		bodies = append(bodies, len(b))
		mu.Unlock()
		w.WriteHeader(http.StatusCreated)
	}))
	defer push.Close()
	got := func() []int {
		mu.Lock()
		defer mu.Unlock()
		return append([]int(nil), bodies...)
	}

	url, tk := testKnockRelay(t)
	// every name the knock asks for is the push server here
	c := push.Client()
	tr := c.Transport.(*http.Transport).Clone()
	tr.TLSClientConfig.InsecureSkipVerify = true
	tr.DialContext = func(ctx context.Context, n, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, n, push.Listener.Addr().String())
	}
	tk.post = knockPoster(&http.Client{Transport: tr})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go tk.run(ctx)

	r := connect(t, url)
	sk, pk := keypair()
	if err := publish(t, r, signedReg(t, sk, "https://push.example.org/upXyZ?up=1", time.Now())); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 5; i++ {
		if err := publish(t, r, wrap(t, pk, nil)); err != nil {
			t.Fatal(err)
		}
	}
	deadline := time.Now().Add(3 * time.Second)
	for len(got()) < 1 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	time.Sleep(200 * time.Millisecond)
	if b := got(); len(b) != 1 || b[0] != 0 {
		t.Fatalf("knocks at the push server after five wraps: %v", b)
	}
	// the minute is up: one more for what came during it
	tk.fire()
	deadline = time.Now().Add(3 * time.Second)
	for len(got()) < 2 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if b := got(); len(b) != 2 || b[1] != 0 {
		t.Fatalf("knocks after the floor: %v", b)
	}
}
