package main

import (
	"bytes"
	"container/heap"
	"context"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/fasthttp/websocket"
	"github.com/fiatjaf/eventstore/slicestore"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
	"golang.org/x/net/dns/dnsmessage"
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

func (c *fakeClock) set(t time.Time) {
	c.mu.Lock()
	c.t = t
	c.mu.Unlock()
}

type fakeTimer struct {
	at  time.Time
	seq int
	f   func()
}

// timers by when they are due, and in the order set at the same time
type timerHeap []fakeTimer

func (h timerHeap) Len() int { return len(h) }
func (h timerHeap) Less(i, j int) bool {
	if h[i].at.Equal(h[j].at) {
		return h[i].seq < h[j].seq
	}
	return h[i].at.Before(h[j].at)
}
func (h timerHeap) Swap(i, j int) { h[i], h[j] = h[j], h[i] }
func (h *timerHeap) Push(x any)   { *h = append(*h, x.(fakeTimer)) }
func (h *timerHeap) Pop() any {
	old := *h
	x := old[len(old)-1]
	*h = old[:len(old)-1]
	return x
}

// a knocker on a fake clock whose timers run when the test moves the clock.
// nothing is posted: knocks stay queued until drained
type testKnocks struct {
	*knocker
	clock  *fakeClock
	tmu    sync.Mutex
	timers timerHeap
	seq    int
	// what the queue took and when, as timers fired
	log []stamped
}

type stamped struct {
	knockJob
	at time.Time
}

// every name resolves to a public address, but those with "nx" in them
func fakeLookup(_ context.Context, host string) ([]net.IP, error) {
	if strings.Contains(host, "nx") {
		return nil, &net.DNSError{Err: "no such host", Name: host, IsNotFound: true}
	}
	return []net.IP{net.ParseIP("1.1.1.1")}, nil
}

func newTestKnocks(t *testing.T) *testKnocks {
	t.Helper()
	tk := &testKnocks{clock: &fakeClock{t: time.Unix(1_800_000_000, 0)}}
	tk.knocker = newKnocker(nil, false)
	tk.lookup = fakeLookup
	tk.now = tk.clock.now
	tk.after = func(d time.Duration, f func()) {
		tk.tmu.Lock()
		tk.seq++
		heap.Push(&tk.timers, fakeTimer{tk.clock.now().Add(d), tk.seq, f})
		tk.tmu.Unlock()
	}
	return tk
}

// moves the clock on by d, firing every timer due on the way in order, and
// stamps what each one queued with its time
func (tk *testKnocks) advance(d time.Duration) {
	end := tk.clock.now().Add(d)
	for {
		tk.tmu.Lock()
		if len(tk.timers) == 0 || tk.timers[0].at.After(end) {
			tk.tmu.Unlock()
			break
		}
		next := heap.Pop(&tk.timers).(fakeTimer)
		tk.tmu.Unlock()
		tk.clock.set(next.at)
		next.f()
		for _, j := range tk.drain() {
			tk.log = append(tk.log, stamped{j, next.at})
		}
	}
	tk.clock.set(end)
}

// what is waiting to be posted, taken out of the queue
func (tk *testKnocks) drain() []knockJob {
	tk.mu.Lock()
	defer tk.mu.Unlock()
	var out []knockJob
	for _, d := range tk.domains {
		for _, l := range d.lanes {
			for _, ep := range l {
				out = append(out, knockJob{ep.url, false})
				ep.queuedReal = false
			}
		}
		for _, ep := range d.decoy {
			out = append(out, knockJob{ep.url, true})
			ep.queuedDecoy = false
		}
		d.lanes, d.decoy = [knockTiers][]*knockEP{}, nil
		d.inRing = false
	}
	tk.q.push, tk.q.shared = nil, nil
	tk.q.queued, tk.q.sharedQueued = 0, 0
	return out
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

func register(t *testing.T, tk *testKnocks, endpoint string) (sk, pk string) {
	t.Helper()
	sk, pk = keypair()
	ev := signedReg(t, sk, endpoint, tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatalf("%s: %s", endpoint, msg)
	}
	// a working endpoint, as most are
	tk.mu.Lock()
	tk.settledLocked(tk.eps[endpoint])
	tk.mu.Unlock()
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
		{"https://ntfy.sh:443/upXyZ", false, true},
		{"https://8.8.8.8/up", false, false},
		{"https://[2a00:1450:4001::1]/up", false, false},
		{"https://x1.zzqq/up", false, false},
		{"https://a.b.github.io/up", false, false},
		{"https://foo.duckdns.org/up", false, false},
		{"https://up.conversations.im/up", false, true},
		{"https://fcm.distributor.unifiedpush.org/up", false, true},
		{"https://1.2.3.4.5/up", false, false},
		{"https://push.example.org:8443/up", false, false},
		{"https://8.8.8.8:25/x", false, false},
		{"https://example.com:6379/", false, false},
		{"http://ntfy.sh/up", false, false},
		{"ftp://ntfy.sh/up", false, false},
		{"https://localhost/up", false, false},
		{"https://localhost./up", false, false},
		{"https://a.localhost/up", false, false},
		{"https://ntfy.sh./up", false, false},
		{"https://127.0.0.1/up", false, false},
		{"https://127.1/up", false, false},
		{"https://2130706433/up", false, false},
		{"https://0x7f.1/up", false, false},
		{"https://10.0.0.2/up", false, false},
		{"https://192.168.1.1/up", false, false},
		{"https://169.254.169.254/latest", false, false},
		{"https://100.64.0.1/up", false, false},
		{"https://192.0.2.1/up", false, false},
		{"https://192.88.99.1/up", false, false},
		{"https://[::1]/up", false, false},
		{"https://[fd00::1]/up", false, false},
		{"https://[::ffff:127.0.0.1]/up", false, false},
		{"https://[::7f00:1]/up", false, false},
		{"https://[64:ff9b::a00:1]/up", false, false},
		{"https://user:pw@ntfy.sh/up", false, false},
		{"https://ntfy.sh/up#x", false, false},
		{"https://ntfy.sh/upX?delay=zzz", false, false},
		{"https://ntfy.sh/upX?up=2", false, false},
		{"https://gotify.example.org/UP?token=AbC-1_x", false, true},
		{"https://fcm.distributor.unifiedpush.org/wpfcm?v2&instance=x1&token=abc", false, true},
		{"https://gotify.example.org/UP?token=a%20b", false, false},
		{"https://gotify.example.org/UP?token=", false, false},
		{"https://gotify.example.org/UP?token=abc:DEF-1_x", false, true},
		{"https://gotify.example.org/UP?token=abc%3ADEF", false, true},
		{"https://gotify.example.org/UP?v3&token=abc", false, false},
		{"https://ntfy.sh/upX?up=1&%zz=1", false, false},
		{"https://ntfy.sh/upX?up=1;x=1", false, false},
		{"https://gotify.example.org/UP?x;y=z", false, false},
		{"https://gotify.example.org/UP?token=a&token=b%", false, false},
		{"https://fcm.distributor.unifiedpush.org/wpfcm?v2&instance=kryfo-3.0&token=cXyZ:APA91bF-a_b", false, true},
		{"https://fcm.distributor.unifiedpush.org/wpfcm?v2&instance=x&token=cXyZ%3AAPA91b", false, true},
		{"https://fcm.distributor.unifiedpush.org/wpfcm?v3&instance=x&token=a:b&app=k_1", false, true},
		{"https://fcm.distributor.unifiedpush.org/wpfcm?v2&token=a%20b", false, false},
		{"https://fcm.distributor.unifiedpush.org/wpfcm?v2&token=a&%zz=1", false, false},
		{"https://fcm.distributor.unifiedpush.org/wpfcm?v2;token=a", false, false},
		{"https://fcm.distributor.unifiedpush.org/wpfcm?Delay=1", false, false},
		{"https://fcm.distributor.unifiedpush.org/wpfcm?v2&token=a/b", false, false},
		{"https:///up", false, false},
		{"https://ntfy.sh/up x", false, false},
		{"https://com/up", false, false},
		{"https://ntfy.sh/" + strings.Repeat("a", maxEndpointLen), false, false},
		{"http://abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuv.onion/up", false, false},
		{"http://abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuv.onion/up", true, true},
		{"http://abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuv.onion:22/up", true, false},
	} {
		if got := knockEndpointOK(c.url, c.onions); got != c.ok {
			t.Errorf("%q onions=%v: got %v, want %v", c.url, c.onions, got, c.ok)
		}
	}
}

func TestKnockPortsCanBeOpened(t *testing.T) {
	t.Setenv("RELAY_KNOCK_PORTS", "8443")
	if !knockEndpointOK("https://push.example.org:8443/up", false) {
		t.Fatal("a port the box allows was refused")
	}
	if knockEndpointOK("https://push.example.org:25/up", false) {
		t.Fatal("a port the box does not allow was taken")
	}
}

func TestPublicIPForms(t *testing.T) {
	for s, want := range map[string]bool{
		"8.8.8.8": true, "2a00:1450:4001::1": true,
		"::7f00:1": false, "::a00:1": false, "::ffff:127.0.0.1": false, "::ffff:10.0.0.1": false,
		"fec0::1": false, "2001:0:4136:e378:8000:63bf:3fff:fdd2": false, "2001:db8::1": false,
		"192.0.2.1": false, "198.51.100.1": false, "203.0.113.1": false, "192.88.99.1": false,
		"100::1": false, "64:ff9b::a00:1": false, "64:ff9b:1::a00:1": false, "2002:a00:1::1": false,
		"255.255.255.255": false, "0.0.0.0": false, "::": false,
	} {
		if got := publicIP(net.ParseIP(s)); got != want {
			t.Errorf("%s: public %v, want %v", s, got, want)
		}
	}
}

func TestKnockRefusesTheBoxItself(t *testing.T) {
	selfMu.Lock()
	selfIPs["8.8.4.4"] = true
	selfMu.Unlock()
	t.Cleanup(func() {
		selfMu.Lock()
		delete(selfIPs, "8.8.4.4")
		selfMu.Unlock()
	})
	if publicOnly("tcp4", "8.8.4.4:443", nil) == nil {
		t.Fatal("the dial reached the box's own address")
	}
	if _, err := knockResolver("tcp4")(context.Background(), "8.8.4.4"); err == nil {
		t.Fatal("the resolver handed out the box's own address")
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

	first := signedReg(t, sk, testEP, now)
	tk.apply(&first)
	if len(tk.regs) != 1 || len(tk.eps) != 1 {
		t.Fatalf("regs %d eps %d after one registration", len(tk.regs), len(tk.eps))
	}
	// the same one again, or an older one, is refused so the app knows
	for _, ev := range []nostr.Event{first, signedReg(t, sk, "https://other.example.org/up", now.Add(-time.Minute))} {
		rej, msg := tk.check(&ev)
		if !rej || !strings.HasPrefix(msg, "duplicate:") {
			t.Fatalf("not newer: %v %q", rej, msg)
		}
		tk.apply(&ev)
	}
	if reg := tk.regs[knockKey(pk)]; reg.ep.url != testEP {
		t.Fatalf("an older registration replaced a newer one: %s", reg.ep.url)
	}
	forget := signedReg(t, sk, "", now.Add(time.Second))
	tk.apply(&forget)
	if len(tk.regs) != 0 || len(tk.eps) != 0 {
		t.Fatalf("regs %d eps %d after forget", len(tk.regs), len(tk.eps))
	}
}

func TestKnockReplayAfterForget(t *testing.T) {
	tk := newTestKnocks(t)
	sk, pk := keypair()
	now := tk.clock.now()
	reg := signedReg(t, sk, testEP, now)
	tk.apply(&reg)
	forget := signedReg(t, sk, "", now.Add(time.Second))
	tk.apply(&forget)
	tk.advance(time.Hour)
	if rej, msg := tk.check(&reg); !rej || !strings.HasPrefix(msg, "duplicate:") {
		t.Fatalf("a replay inside the window: %v %q", rej, msg)
	}
	tk.apply(&reg)
	if tk.regs[knockKey(pk)] != nil {
		t.Fatal("an old registration came back after a newer forget")
	}
	// past the window the forget goes, and the replay is too old anyway
	tk.advance(2 * knockSkew)
	tk.tick()
	if len(tk.forgets) != 0 {
		t.Fatal("a forget was kept past its window")
	}
	if rej, _ := tk.check(&reg); !rej {
		t.Fatal("a replay past the window was taken")
	}
	// a fresh one after the forget is taken
	fresh := signedReg(t, sk, testEP, tk.clock.now())
	tk.apply(&fresh)
	if tk.regs[knockKey(pk)] == nil {
		t.Fatal("a new registration after a forget was refused")
	}
}

func TestKnockForgetWinsATie(t *testing.T) {
	tk := newTestKnocks(t)
	sk, pk := keypair()
	now := tk.clock.now()
	reg := signedReg(t, sk, testEP, now)
	tk.apply(&reg)
	forget := signedReg(t, sk, "", now)
	if rej, msg := tk.check(&forget); rej {
		t.Fatalf("a forget in the same second was refused: %s", msg)
	}
	tk.apply(&forget)
	if tk.regs[knockKey(pk)] != nil {
		t.Fatal("a forget in the same second lost to the registration")
	}
	again := signedReg(t, sk, "https://other.example.org/up", now)
	if rej, _ := tk.check(&again); !rej {
		t.Fatal("a registration in the forget's second was taken")
	}
}

func TestKnockForgetForNothingKeepsNothing(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < 100; i++ {
		sk, _ := keypair()
		ev := signedReg(t, sk, "", tk.clock.now())
		tk.apply(&ev)
	}
	if len(tk.forgets) != 0 {
		t.Fatalf("%d forgets kept for addresses that had nothing", len(tk.forgets))
	}
}

func TestKnockStoresNoAddress(t *testing.T) {
	tk := newTestKnocks(t)
	_, pk := register(t, tk, testEP)
	raw, _ := hex.DecodeString(pk)
	for key := range tk.regs {
		if bytes.Equal(key[:], raw) || key != knockKey(pk) {
			t.Fatal("the table is keyed by something other than the address's hash")
		}
	}
}

func TestKnockOnWrapWithFloorAndOneTrailing(t *testing.T) {
	tk := newTestKnocks(t)
	_, pk := register(t, tk, testEP)
	_, other := keypair()
	tk.drain()

	w := wrap(t, other, nil)
	tk.stored(&w)
	if got := tk.drain(); len(got) != 0 {
		t.Fatalf("a wrap for an unregistered address knocked: %v", got)
	}

	// a burst of fifty slices: one knock now, one after the minute
	start := tk.clock.now()
	for i := 0; i < 50; i++ {
		w := wrap(t, pk, nil)
		tk.stored(&w)
	}
	got := tk.drain()
	if len(got) != 1 || got[0].url != testEP || got[0].decoy {
		t.Fatalf("knocks right after the burst: %+v", got)
	}
	tk.log = nil
	tk.advance(knockFloor + knockTrail)
	var trailing []stamped
	for _, s := range tk.log {
		if !s.decoy {
			trailing = append(trailing, s)
		}
	}
	if len(trailing) != 1 {
		t.Fatalf("trailing knocks: %d, want 1", len(trailing))
	}
	if at := trailing[0].at.Sub(start); at < knockFloor || at >= knockFloor+knockTrail {
		t.Fatalf("the trailing knock came %v after the first", at)
	}
}

func TestKnockStormStaysBounded(t *testing.T) {
	tk := newTestKnocks(t)
	_, pk := register(t, tk, testEP)
	tk.drain()
	// a wrap every second for an hour
	sent := 0
	for s := 0; s < 3600; s++ {
		w := wrap(t, pk, nil)
		tk.stored(&w)
		sent += len(tk.drain())
		tk.log = nil
		tk.advance(time.Second)
		for _, j := range tk.log {
			if !j.decoy {
				sent++
			}
		}
	}
	if sent > 61 {
		t.Fatalf("%d knocks in an hour of wraps, want at most 61", sent)
	}
	if sent < 40 {
		t.Fatalf("%d knocks in an hour of wraps: wraps went unannounced", sent)
	}
}

// decoys go per endpoint: twenty endpoints with sixteen addresses each get
// as many as twenty with one, and both as many as the timer and the runs
// promise. counted over many endpoints and two months, so chance stays far
// inside the bounds
func TestKnockDecoysPerEndpointNotPerAddress(t *testing.T) {
	tk := newTestKnocks(t)
	for e := 0; e < 20; e++ {
		for i := 0; i < 16; i++ {
			register(t, tk, fmt.Sprintf("https://push.example.org/many%d", e))
		}
		register(t, tk, fmt.Sprintf("https://push.example.org/one%d", e))
	}
	span := 60 * 24 * time.Hour
	tk.advance(span)
	many, one := 0, 0
	for _, s := range tk.log {
		if !s.decoy {
			t.Fatal("a decoy timer sent a real knock")
		}
		if strings.Contains(s.url, "/many") {
			many++
		} else {
			one++
		}
	}
	want := 20 * float64(span) / float64(knockDecoyMean) * decoyRunMean()
	for name, n := range map[string]int{"sixteen addresses": many, "one address": one} {
		if f := float64(n) / want; f < 0.75 || f > 1.25 {
			t.Fatalf("%s: %d decoys on twenty endpoints, expected near %.0f", name, n, want)
		}
	}
	if r := float64(many) / float64(one); r < 0.8 || r > 1.25 {
		t.Fatalf("sixteen addresses got %d decoys, one got %d", many, one)
	}
}

func TestKnockDecoyKeepsTheFloor(t *testing.T) {
	tk := newTestKnocks(t)
	_, pk := register(t, tk, testEP)
	tk.drain()
	w := wrap(t, pk, nil)
	tk.stored(&w)
	tk.drain()
	tk.mu.Lock()
	ep := tk.eps[testEP]
	gen := ep.decoyGen
	tk.mu.Unlock()
	tk.decoyDue(ep, gen)
	if got := tk.drain(); len(got) != 0 {
		t.Fatal("a decoy went out inside the floor of a real knock")
	}
}

// chi-square of the times' phase in the timer's tick, against an even
// spread over bins
func phaseChi2(ts []time.Time, bins int) float64 {
	counts := make([]float64, bins)
	for _, t := range ts {
		ph := t.UnixNano() % int64(knockTick)
		counts[int(ph*int64(bins)/int64(knockTick))]++
	}
	want := float64(len(ts)) / float64(bins)
	var chi float64
	for _, c := range counts {
		chi += (c - want) * (c - want) / want
	}
	return chi
}

// two-sample kolmogorov-smirnov distance between the phases of a and b
func phaseKS(a, b []time.Time) float64 {
	ph := func(ts []time.Time) []float64 {
		out := make([]float64, len(ts))
		for i, t := range ts {
			out[i] = float64(t.UnixNano()%int64(knockTick)) / float64(knockTick)
		}
		sort.Float64s(out)
		return out
	}
	x, y := ph(a), ph(b)
	var i, j int
	var d float64
	for i < len(x) && j < len(y) {
		if x[i] <= y[j] {
			i++
		} else {
			j++
		}
		d = math.Max(d, math.Abs(float64(i)/float64(len(x))-float64(j)/float64(len(y))))
	}
	return d
}

func TestKnockDecoyTimesLookLikeRealOnes(t *testing.T) {
	tk := newTestKnocks(t)
	var pks []string
	for i := 0; i < 40; i++ {
		_, pk := register(t, tk, fmt.Sprintf("https://push.example.org/up%d", i))
		pks = append(pks, pk)
	}
	tk.drain()
	// wraps at random instants, as messages come; decoys on their timers.
	// the clock moves in uneven steps, never on a tick
	var real, decoy []time.Time
	for step := 0; step < 20000; step++ {
		tk.log = nil
		tk.advance(time.Duration(tk.rnd.Int64N(int64(20 * time.Second))))
		if tk.rnd.IntN(10) == 0 {
			w := wrap(t, pks[tk.rnd.IntN(len(pks))], nil)
			tk.stored(&w)
			for _, j := range tk.drain() {
				tk.log = append(tk.log, stamped{j, tk.clock.now()})
			}
		}
		for _, s := range tk.log {
			if s.decoy {
				decoy = append(decoy, s.at)
			} else {
				real = append(real, s.at)
			}
		}
	}
	if len(decoy) < 300 || len(real) < 500 {
		t.Fatalf("too few to judge: %d decoys, %d real", len(decoy), len(real))
	}
	// 30 bins, 29 degrees of freedom: 70 is far past p 0.0001
	if c := phaseChi2(decoy, 30); c > 70 {
		t.Fatalf("decoys bunch within the tick: chi2 %.0f", c)
	}
	if c := phaseChi2(real, 30); c > 70 {
		t.Fatalf("real knocks bunch within the tick: chi2 %.0f", c)
	}
	// some 650 decoys and 2000 real: 0.1 is about p 0.0001 too
	if d := phaseKS(real, decoy); d > 0.1 {
		t.Fatalf("real and decoy send times differ: ks %.3f", d)
	}
}

// a decoy comes with trailing ones as often as a conversation's first
// knock does, so a gap of a floor and a little is no mark of a real one
func TestKnockDecoysComeInBurstsToo(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < 40; i++ {
		register(t, tk, fmt.Sprintf("https://push.example.org/up%d", i))
	}
	tk.drain()
	tk.log = nil
	tk.advance(30 * 24 * time.Hour)
	last := map[string]time.Time{}
	burst, decoys := 0, 0
	for _, s := range tk.log {
		if !s.decoy {
			t.Fatal("no wrap came, yet a real knock went")
		}
		decoys++
		if l, ok := last[s.url]; ok {
			if g := s.at.Sub(l); g >= knockFloor && g < knockFloor+knockTrail {
				burst++
			}
		}
		last[s.url] = s.at
	}
	if frac := float64(burst) / float64(decoys); frac < 0.3 {
		t.Fatalf("only %.2f of decoys follow another a floor apart", frac)
	}
}

type knockClass struct{ tp, fp, fn int }

func (c knockClass) precision() float64 {
	return float64(c.tp) / math.Max(1, float64(c.tp+c.fp))
}

func (c *knockClass) score(called, decoy bool) {
	switch {
	case called && !decoy:
		c.tp++
	case called && decoy:
		c.fp++
	case !called && !decoy:
		c.fn++
	}
}

// conversations every [conv] per endpoint, of 3 to 17 messages, with the
// decoys on their timers. how well two simple watchers tell the real knocks
// apart: A calls a knock real when it comes 60 to 90 s after the one
// before, C when it is in a run of four or more less than 15 min apart.
// also the share of knocks that are real, the most any watcher could get
// by calling every knock real
func knockWatch(t *testing.T, conv time.Duration) (a, c knockClass, realShare float64) {
	tk := newTestKnocks(t)
	var addrs []string
	for i := 0; i < 40; i++ {
		_, pk := register(t, tk, fmt.Sprintf("https://push.example.org/up%d", i))
		addrs = append(addrs, pk)
	}
	tk.drain()
	horizon := 30 * 24 * time.Hour
	for _, addr := range addrs {
		at := time.Duration(0)
		for {
			at += time.Duration(tk.rnd.ExpFloat64() * float64(conv))
			if at > horizon {
				break
			}
			mt := at
			for j := 0; j < 3+tk.rnd.IntN(15); j++ {
				mt += time.Duration(tk.rnd.ExpFloat64() * float64(20*time.Second))
				tk.after(mt, func() { tk.wrapFor(addr) })
			}
		}
	}
	tk.log = nil
	tk.advance(horizon)
	type kn struct {
		at    time.Time
		decoy bool
	}
	per := map[string][]kn{}
	nreal := 0
	for _, s := range tk.log {
		per[s.url] = append(per[s.url], kn{s.at, s.decoy})
		if !s.decoy {
			nreal++
		}
	}
	for _, ks := range per {
		runLen := make([]int, len(ks))
		start := 0
		for i := 1; i <= len(ks); i++ {
			if i == len(ks) || ks[i].at.Sub(ks[i-1].at) >= 15*time.Minute {
				for j := start; j < i; j++ {
					runLen[j] = i - start
				}
				start = i
			}
		}
		for i := 1; i < len(ks); i++ {
			g := ks[i].at.Sub(ks[i-1].at)
			a.score(g >= knockFloor && g < knockFloor+knockTrail, ks[i].decoy)
		}
		for i := range ks {
			c.score(runLen[i] >= 4, ks[i].decoy)
		}
	}
	return a, c, float64(nreal) / float64(len(tk.log))
}

// a decoy run is shaped like a conversation's knocks: a watcher that calls
// long runs real does little better than one that calls every knock real
func TestKnockDecoyRunsLookLikeConversations(t *testing.T) {
	if testing.Short() {
		t.Skip("a month of knocks")
	}
	for _, conv := range []time.Duration{2 * time.Hour, 8 * time.Hour} {
		a, c, share := knockWatch(t, conv)
		t.Logf("conversations every %v: real share %.3f, A precision %.3f, C precision %.3f",
			conv, share, a.precision(), c.precision())
		if c.precision() > share+0.06 {
			t.Errorf("conversations every %v: runs of four give %.3f against a share of %.3f", conv, c.precision(), share)
		}
	}
}

func TestKnockExpiry(t *testing.T) {
	tk := newTestKnocks(t)
	_, pk := register(t, tk, testEP)
	tk.drain()
	tk.clock.set(tk.clock.now().Add(knockTTL + time.Second))
	w := wrap(t, pk, nil)
	tk.stored(&w)
	if got := tk.drain(); len(got) != 0 {
		t.Fatal("an expired registration was knocked")
	}
	tk.tick()
	if len(tk.regs) != 0 || len(tk.eps) != 0 || len(tk.domains) != 0 {
		t.Fatal("an expired registration was kept")
	}
}

func TestKnockSweepLetsWrapsIn(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	store, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer store.close()
	store.start()
	tk := newTestKnocks(t)
	tk.store = store
	const n = 20000
	tk.mu.Lock()
	for i := 0; i < n; i++ {
		var key [32]byte
		key[0], key[1], key[2] = byte(i), byte(i>>8), byte(i>>16)
		tk.setLocked(key, fmt.Sprintf("https://x.org/%d", i%200), tk.clock.now().Unix(), tk.clock.now().Add(knockTTL).Unix())
		tk.store.put(key, tk.regs[key].ep.url, tk.regs[key].made, tk.regs[key].expires, 0, false)
	}
	tk.mu.Unlock()
	store.flush(time.Minute)
	tk.clock.set(tk.clock.now().Add(knockTTL + time.Second))
	done := make(chan struct{})
	go func() {
		tk.tick()
		close(done)
	}()
	var worst time.Duration
	_, pk := keypair()
	for {
		select {
		case <-done:
			if len(tk.regs) != 0 {
				t.Fatalf("%d left after the sweep", len(tk.regs))
			}
			if worst > 250*time.Millisecond {
				t.Fatalf("a wrap waited %v on the sweep", worst)
			}
			return
		default:
		}
		t0 := time.Now()
		tk.wrapFor(pk)
		if w := time.Since(t0); w > worst {
			worst = w
		}
		time.Sleep(time.Millisecond)
	}
}

func TestKnockGoneEndpointIsDropped(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < 3; i++ {
		register(t, tk, testEP)
	}
	tk.q.result(tk.eps[testEP], false, http.StatusNotFound, nil)
	if len(tk.regs) != 0 || len(tk.eps) != 0 {
		t.Fatalf("regs %d eps %d after a 404", len(tk.regs), len(tk.eps))
	}
}

func TestKnockFailingEndpointGoesAfterADay(t *testing.T) {
	tk := newTestKnocks(t)
	register(t, tk, testEP)
	ep := tk.eps[testEP]
	tk.q.result(ep, false, 201, nil)
	// an hour of trouble: kept
	for i := 0; i < 10; i++ {
		tk.q.result(ep, false, 0, context.DeadlineExceeded)
		tk.clock.set(tk.clock.now().Add(6 * time.Minute))
	}
	if tk.eps[testEP] == nil {
		t.Fatal("an endpoint was let go after an hour of failures")
	}
	// one success starts the count again
	tk.q.result(ep, false, 201, nil)
	tk.clock.set(tk.clock.now().Add(knockFailFor))
	tk.q.result(ep, false, 503, nil)
	if tk.eps[testEP] == nil {
		t.Fatal("one failure after a success let the endpoint go")
	}
	for i := 0; i < knockFailAtLeast; i++ {
		tk.clock.set(tk.clock.now().Add(knockFailFor / knockFailAtLeast))
		tk.q.result(ep, true, 0, context.DeadlineExceeded)
	}
	if tk.eps[testEP] != nil || len(tk.regs) != 0 {
		t.Fatal("an endpoint failing for a day was kept")
	}
	// a server pacing us is not the endpoint failing
	register(t, tk, testEP)
	ep = tk.eps[testEP]
	for i := 0; i < 50; i++ {
		tk.clock.set(tk.clock.now().Add(time.Hour))
		tk.q.result(ep, false, http.StatusTooManyRequests, nil)
	}
	if tk.eps[testEP] == nil {
		t.Fatal("a 429 let the endpoint go")
	}
}

func TestKnockCeilingPerEndpoint(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < maxRegsPerEP; i++ {
		register(t, tk, testEP)
	}
	sk, _ := keypair()
	ev := signedReg(t, sk, testEP, tk.clock.now())
	if rej, _ := tk.check(&ev); !rej {
		t.Fatal("an endpoint took more addresses than its ceiling")
	}
}

func r3key(i int) string { return fmt.Sprintf("%064x", i+1) }

// a registration with no signature: check and apply read the key, the time
// and the content only
func r3reg(pk, ep string, at time.Time) nostr.Event {
	return nostr.Event{Kind: knockKind, PubKey: pk, CreatedAt: nostr.Timestamp(at.Unix()), Content: ep}
}

// made-up servers, or random topics on a public one, fill one share and
// never the relay
func TestKnockMintingFillsOneShareOnly(t *testing.T) {
	tk := newTestKnocks(t)
	now := tk.clock.now()
	try := func(i int, ep string) bool {
		ev := r3reg(r3key(i), ep, now)
		rej, _ := tk.checkLocked(&ev)
		if !rej {
			tk.setLocked(knockKey(ev.PubKey), ep, now.Unix(), now.Add(knockTTL).Unix())
		}
		return !rej
	}
	tk.mu.Lock()
	defer tk.mu.Unlock()
	// 782 invented servers with 256 endpoints each: the common share holds
	// what it holds, one server what it may
	took, i := 0, 0
	for srv := 0; srv < 782; srv++ {
		for j := 0; j < 256; j++ {
			if try(i, fmt.Sprintf("https://h%d.s%d.org/up", j, srv)) {
				took++
			}
			i++
		}
	}
	if took > knockSharedEPs {
		t.Fatalf("invented servers took %d endpoints, the common share is %d", took, knockSharedEPs)
	}
	for d, dom := range tk.domains {
		if !dom.push && dom.eps > knockServerEPs {
			t.Fatalf("%s holds %d endpoints", d, dom.eps)
		}
	}
	// 1563 random ntfy topics with 256 addresses each
	ntfy := 0
	for topic := 0; topic < 1563; topic++ {
		for j := 0; j < maxRegsPerEP; j++ {
			if try(i, fmt.Sprintf("https://ntfy.sh/rand%d", topic)) {
				ntfy++
			}
			i++
		}
	}
	if ntfy > knockPushHostRegs {
		t.Fatalf("one public server took %d addresses, its share is %d", ntfy, knockPushHostRegs)
	}
	// every other public server still takes new ones
	for _, ep := range []string{
		"https://up.conversations.im/legit",
		"https://updates.push.services.mozilla.com/wpush/v2/legit",
		"https://fcm.distributor.unifiedpush.org/legit",
	} {
		if !try(i, ep) {
			t.Fatalf("%s was refused after the attack", ep)
		}
		i++
	}
	if len(tk.regs) > len(knockPushHosts())*knockPushHostRegs+knockSharedRegs {
		t.Fatal("the relay holds more than its shares")
	}
}

func TestKnockOneServerHasACap(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < knockServerEPs; i++ {
		register(t, tk, fmt.Sprintf("https://a%d.victim.org/%d", i%7, i))
	}
	sk, _ := keypair()
	ev := signedReg(t, sk, "https://victim.org/more", tk.clock.now())
	if rej, msg := tk.check(&ev); !rej || !strings.Contains(msg, "push server") {
		t.Fatalf("one server took more than its cap: %v %q", rej, msg)
	}
	register(t, tk, "https://ntfy.sh/upLegit")
	register(t, tk, "https://push.own-server.org/up")
}

// made-up servers flooding the queue: knocks to a public push server still
// go, every one of them
func TestKnockPublicServersKeepTheirTurns(t *testing.T) {
	for _, n := range []int{10, 500} {
		tk := newTestKnocks(t)
		tk.mu.Lock()
		now := tk.clock.now()
		var att, leg []*knockEP
		for d := 0; d < n; d++ {
			for j := 0; j < knockDomainQueue; j++ {
				tk.setLocked(knockKey(r3key(d*1000+j)), fmt.Sprintf("https://h%d.s%d.org/%d", j, d, j), now.Unix(), now.Add(knockTTL).Unix())
			}
		}
		for j := 0; j < 400; j++ {
			tk.setLocked(knockKey(r3key(5_000_000+j)), fmt.Sprintf("https://ntfy.sh/up%d", j), now.Unix(), now.Add(knockTTL).Unix())
		}
		for _, ep := range tk.eps {
			if ep.domain == "ntfy.sh" {
				leg = append(leg, ep)
			} else {
				att = append(att, ep)
			}
		}
		served, dropped := 0, 0
		qi := 0
		for ms := 0; ms < 60_000; ms++ {
			now = now.Add(time.Millisecond)
			// the attacker keeps its queues full
			if ms%50 == 0 {
				for _, ep := range att {
					if !ep.queuedReal {
						tk.q.addLocked(ep, false)
					}
				}
			}
			if ms%200 == 0 {
				before := tk.stats.dropped.Load()
				tk.q.addLocked(leg[qi%len(leg)], false)
				qi++
				if tk.stats.dropped.Load() > before {
					dropped++
				}
			}
			for {
				ep, _, ok := tk.q.nextLocked(now)
				if !ok {
					break
				}
				if ep.domain == "ntfy.sh" {
					served++
				}
				// posts end at once here
				tk.q.doneLocked(ep)
			}
		}
		tk.mu.Unlock()
		if dropped != 0 || served < 295 {
			t.Fatalf("%d made-up servers: ntfy.sh served %d of 300, %d dropped", n, served, dropped)
		}
	}
}

// thousands of fresh random topics on the same public server, knocked at
// 300 a second: endpoints a day old that knocked before keep their lane
func TestKnockProvenEndpointsKeepTheirLane(t *testing.T) {
	tk := newTestKnocks(t)
	tk.mu.Lock()
	now := tk.clock.now()
	day := now.Add(-knockTrustAfter - time.Hour)
	var leg, att []*knockEP
	for i := 0; i < 1000; i++ {
		u := fmt.Sprintf("https://ntfy.sh/upLegit%d", i)
		tk.setLocked(knockKey(r3key(1_000_000+i)), u, now.Unix(), now.Add(knockTTL).Unix())
		tk.eps[u].delivered, tk.eps[u].born = true, day
		leg = append(leg, tk.eps[u])
	}
	for i := 0; i < 19000; i++ {
		u := fmt.Sprintf("https://ntfy.sh/rand%d", i)
		tk.setLocked(knockKey(r3key(i)), u, now.Unix(), now.Add(knockTTL).Unix())
		att = append(att, tk.eps[u])
	}
	var asked, served, dropped, ti, li int
	waiting := map[*knockEP]bool{}
	var acc float64
	for ms := 0; ms < 60_000; ms++ {
		now = now.Add(time.Millisecond)
		tk.clock.set(now)
		for acc += 0.3; acc >= 1; acc-- {
			tk.q.addLocked(att[ti%len(att)], false)
			ti++
		}
		if ms%200 == 0 {
			ep := leg[li%len(leg)]
			li++
			before := tk.stats.dropped.Load()
			tk.q.addLocked(ep, false)
			asked++
			if tk.stats.dropped.Load() > before {
				dropped++
			} else {
				waiting[ep] = true
			}
		}
		for {
			ep, _, ok := tk.q.nextLocked(now)
			if !ok {
				break
			}
			if waiting[ep] {
				served++
				delete(waiting, ep)
			}
			tk.q.doneLocked(ep)
		}
	}
	tk.mu.Unlock()
	if float64(served) < 0.95*float64(asked) || dropped != 0 {
		t.Fatalf("proven endpoints: %d asked, %d served, %d dropped", asked, served, dropped)
	}
}

// endpoints of a day and of a month, both proven, flooding a server: a
// first-day user's knocks still get turns, never none
func TestKnockOldLanesDoNotShutOutTheFirstDay(t *testing.T) {
	tk := newTestKnocks(t)
	tk.mu.Lock()
	now := tk.clock.now()
	var newcomers, att []*knockEP
	for i := 0; i < 1000; i++ {
		u := fmt.Sprintf("https://ntfy.sh/new%d", i)
		tk.setLocked(knockKey(r3key(1_000_000+i)), u, now.Unix(), now.Add(knockTTL).Unix())
		tk.eps[u].delivered = true
		newcomers = append(newcomers, tk.eps[u])
	}
	for i := 0; i < 19000; i++ {
		u := fmt.Sprintf("https://ntfy.sh/old%d", i)
		tk.setLocked(knockKey(r3key(i)), u, now.Unix(), now.Add(knockTTL).Unix())
		tk.eps[u].delivered, tk.eps[u].born = true, now.Add(-40*24*time.Hour)
		att = append(att, tk.eps[u])
	}
	var asked, served, ti, li int
	waiting := map[*knockEP]bool{}
	var acc float64
	for ms := 0; ms < 60_000; ms++ {
		now = now.Add(time.Millisecond)
		tk.clock.set(now)
		for acc += 0.3; acc >= 1; acc-- {
			tk.q.addLocked(att[ti%len(att)], false)
			ti++
		}
		if ms%200 == 0 {
			ep := newcomers[li%len(newcomers)]
			li++
			tk.q.addLocked(ep, false)
			asked++
			waiting[ep] = true
		}
		for {
			ep, _, ok := tk.q.nextLocked(now)
			if !ok {
				break
			}
			if waiting[ep] {
				served++
				delete(waiting, ep)
			}
			tk.q.doneLocked(ep)
		}
	}
	tk.mu.Unlock()
	if float64(served) < 0.95*float64(asked) {
		t.Fatalf("first-day endpoints: %d asked, %d served", asked, served)
	}
}

// an endpoint's age and whether it delivered survive a restart; one that
// never delivered does not become old by waiting
func TestKnockAgeSurvivesARestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	st, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	st.start()
	tk := newTestKnocks(t)
	tk.store = st
	now := tk.clock.now()
	// signed two hours back, as the window allows
	dead := r3reg(r3key(1), "https://ntfy.sh/dead", now.Add(-knockSkew+time.Second))
	good := r3reg(r3key(2), "https://ntfy.sh/good", now)
	tk.take(nil, &dead)
	tk.take(nil, &good)
	tk.q.result(tk.eps["https://ntfy.sh/good"], true, 201, nil)
	st.flush(time.Minute)
	st.close()

	st2, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer st2.close()
	tk2 := newTestKnocks(t)
	tk2.store = st2
	tk2.clock.set(now.Add(23 * time.Hour))
	if err := tk2.load(); err != nil {
		t.Fatal(err)
	}
	d, g := tk2.eps["https://ntfy.sh/dead"], tk2.eps["https://ntfy.sh/good"]
	if !g.born.Equal(now) || !g.delivered {
		t.Fatalf("the proven endpoint came back born %v delivered %v", g.born, g.delivered)
	}
	if d.trusted(tk2.now()) || d.delivered {
		t.Fatal("a never-delivered endpoint came back trusted")
	}
	tk2.clock.set(now.Add(25 * time.Hour))
	if !g.trusted(tk2.now()) || d.trusted(tk2.now()) {
		t.Fatal("a day on: the proven one should be old, the dead one not")
	}
}

// an address joining an endpoint that delivered already keeps it proven
// across a restart, after the first address is forgotten
func TestKnockProvenSurvivesItsFirstAddress(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	st, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	st.start()
	tk := newTestKnocks(t)
	tk.store = st
	now := tk.clock.now()
	ep := "https://ntfy.sh/shared"
	skA, _ := keypair()
	a := signedReg(t, skA, ep, now)
	tk.take(nil, &a)
	tk.q.result(tk.eps[ep], true, 201, nil)
	st.flush(time.Minute)
	b := r3reg(r3key(2), ep, now)
	tk.take(nil, &b)
	tk.clock.set(now.Add(time.Minute))
	forget := signedReg(t, skA, "", tk.clock.now())
	if rej, msg := tk.take(nil, &forget); rej {
		t.Fatal(msg)
	}
	st.flush(time.Minute)
	st.close()

	st2, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer st2.close()
	tk2 := newTestKnocks(t)
	tk2.store = st2
	tk2.clock.set(now.Add(time.Hour))
	if err := tk2.load(); err != nil {
		t.Fatal(err)
	}
	if len(tk2.regs) != 1 || tk2.eps[ep] == nil || !tk2.eps[ep].delivered {
		t.Fatal("the endpoint came back as one that never delivered")
	}
}

// an address loaded at a start and forgotten within the hour gives back
// no token: it took none of this hour's
func TestKnockLoadedForgetGivesNothingBack(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	st, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	st.start()
	tk := newTestKnocks(t)
	tk.store = st
	now := tk.clock.now()
	sk, _ := keypair()
	ev := signedReg(t, sk, "https://ntfy.sh/kept", now)
	tk.take(nil, &ev)
	st.flush(time.Minute)
	st.close()

	st2, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	st2.start()
	defer st2.close()
	tk2 := newTestKnocks(t)
	tk2.store = st2
	tk2.clock.set(now.Add(2 * time.Hour))
	if err := tk2.load(); err != nil {
		t.Fatal(err)
	}
	_, sh := tk2.shareOf("ntfy.sh")
	sh.fresh.tokens = 0
	tk2.clock.set(now.Add(2*time.Hour + time.Minute))
	forget := signedReg(t, sk, "", tk2.clock.now())
	if rej, msg := tk2.take(nil, &forget); rej {
		t.Fatal(msg)
	}
	if len(tk2.regs) != 0 || sh.fresh.tokens != 0 {
		t.Fatalf("a forget after a start gave back %.0f tokens", sh.fresh.tokens)
	}
}

// one connection's wraps set off a bounded number of knocks
func TestKnockConnectionKnockBudget(t *testing.T) {
	url, tk := testKnockRelay(t)
	var pks []string
	for i := 0; i < 60; i++ {
		_, pk := keypair()
		tk.mu.Lock()
		tk.setLocked(knockKey(pk), fmt.Sprintf("https://ntfy.sh/up%d", i), time.Now().Unix(), time.Now().Add(knockTTL).Unix())
		tk.mu.Unlock()
		pks = append(pks, pk)
	}
	tk.drain()
	r := connect(t, url)
	for _, pk := range pks {
		if err := publish(t, r, wrap(t, pk, nil)); err != nil {
			t.Fatal(err)
		}
	}
	time.Sleep(100 * time.Millisecond)
	if n := len(tk.drain()); n > knockBurst+3 {
		t.Fatalf("one connection's wraps set off %d knocks", n)
	}
}

// an endpoint that never worked is let go at its first error, so it holds
// a new one's room for minutes, not a day: its first decoy comes soon
func TestKnockUnprovenEndpointGoesAtItsFirstError(t *testing.T) {
	tk := newTestKnocks(t)
	_, sh := tk.shareOf("ntfy.sh")
	for i := 0; i < sh.pendingCap(); i++ {
		ev := r3reg(r3key(i), fmt.Sprintf("https://ntfy.sh/sq%d", i), tk.clock.now())
		if rej, msg := tk.take(nil, &ev); rej {
			t.Fatal(msg)
		}
	}
	legit := r3reg(r3key(900000), "https://ntfy.sh/legit", tk.clock.now())
	if rej, _ := tk.take(nil, &legit); !rej {
		t.Fatal("the room for new endpoints was not full")
	}
	tk.drain()
	tk.log = nil
	tk.advance(10 * time.Minute)
	first := map[string]bool{}
	for _, j := range tk.log {
		first[j.url] = true
		if ep := tk.eps[j.url]; ep != nil {
			tk.q.result(ep, j.decoy, 400, nil)
		}
	}
	if len(first) < sh.pendingCap() {
		t.Fatalf("%d of %d new endpoints knocked within ten minutes", len(first), sh.pendingCap())
	}
	if len(sh.pending) != 0 {
		t.Fatalf("%d endpoints that answered with errors still hold room", len(sh.pending))
	}
	if rej, msg := tk.take(nil, &legit); rej {
		t.Fatalf("a new user after the squatters went: %q", msg)
	}
	// a proven endpoint is not let go for one error
	tk.q.result(tk.eps["https://ntfy.sh/legit"], false, 201, nil)
	tk.q.result(tk.eps["https://ntfy.sh/legit"], false, 500, nil)
	if tk.eps["https://ntfy.sh/legit"] == nil {
		t.Fatal("a proven endpoint went at one error")
	}
}

// a new endpoint goes at once only on a refusal of the endpoint itself; a
// busy or failing server goes the failure path, a shorter one while the
// endpoint never delivered
func TestKnockUnprovenEndpointSurvivesABusyServer(t *testing.T) {
	tk := newTestKnocks(t)
	n := 0
	fresh := func() *knockEP {
		n++
		ep := fmt.Sprintf("https://ntfy.sh/busy%d", n)
		ev := r3reg(r3key(n), ep, tk.clock.now())
		if rej, msg := tk.take(nil, &ev); rej {
			t.Fatal(msg)
		}
		return tk.eps[ep]
	}
	for _, code := range []int{400, 401, 403, 404, 405, 410, 413} {
		ep := fresh()
		tk.q.result(ep, true, code, nil)
		if tk.eps[ep.url] != nil {
			t.Fatalf("a new endpoint answered %d was kept", code)
		}
	}
	for _, code := range []int{408, 429, 500, 502, 503, 504, 507} {
		ep := fresh()
		tk.q.result(ep, true, code, nil)
		if tk.eps[ep.url] == nil {
			t.Fatalf("a new endpoint went at one %d", code)
		}
	}
	ep := fresh()
	tk.q.result(ep, true, 0, context.DeadlineExceeded)
	if tk.eps[ep.url] == nil {
		t.Fatal("a new endpoint went at one timeout")
	}
	// three failures over half an hour within the hour let a new one go
	ep = fresh()
	for i := 0; i < knockNewFailAtLeast; i++ {
		if tk.eps[ep.url] == nil {
			t.Fatalf("a new endpoint went after %d failures", i)
		}
		tk.q.result(ep, false, 503, nil)
		tk.clock.set(tk.clock.now().Add(15 * time.Minute))
	}
	if tk.eps[ep.url] != nil {
		t.Fatal("a new endpoint failing three times within the hour was kept")
	}
	// spread over hours they do not
	ep = fresh()
	for i := 0; i < knockNewFailAtLeast; i++ {
		tk.q.result(ep, false, 503, nil)
		tk.clock.set(tk.clock.now().Add(time.Hour))
	}
	if tk.eps[ep.url] == nil {
		t.Fatal("a new endpoint failing now and then went")
	}
	// a proven one is kept through refusals and failures alike
	ep = fresh()
	tk.q.result(ep, false, 201, nil)
	for _, code := range []int{400, 403, 503, 503, 503} {
		tk.q.result(ep, false, code, nil)
	}
	tk.q.result(ep, false, 0, errNotPublic)
	if tk.eps[ep.url] == nil {
		t.Fatal("a proven endpoint went within minutes")
	}
}

// a new user whose server fails for a few minutes is kept, however many
// knocks went into the outage
func TestKnockNewEndpointSurvivesAShortOutage(t *testing.T) {
	tk := newTestKnocks(t)
	for i, c := range []struct {
		outage time.Duration
		err    error
	}{
		{5 * time.Minute, nil},
		{10 * time.Minute, nil},
		{10 * time.Minute, context.DeadlineExceeded},
		{29 * time.Minute, nil},
	} {
		url := fmt.Sprintf("https://ntfy.sh/outage%d", i)
		ev := r3reg(r3key(i), url, tk.clock.now())
		if rej, msg := tk.take(nil, &ev); rej {
			t.Fatal(msg)
		}
		ep := tk.eps[url]
		start := tk.clock.now()
		for tk.clock.now().Sub(start) < c.outage {
			if c.err != nil {
				tk.q.result(ep, false, 0, c.err)
			} else {
				tk.q.result(ep, false, 503, nil)
			}
			tk.clock.set(tk.clock.now().Add(time.Minute))
		}
		if tk.eps[url] == nil {
			t.Fatalf("a new endpoint went in a %v outage", c.outage)
		}
		tk.q.result(ep, false, 201, nil)
		if !ep.delivered || ep.fails != 0 {
			t.Fatalf("after the outage: delivered %v, %d failures", ep.delivered, ep.fails)
		}
	}
}

// with no wraps at all, a dead new endpoint gets its decoys again a gap
// after each failure and goes within the hour, never before half an hour;
// one whose server is down for less than half an hour stays
func TestKnockDeadNewEndpointGoesWithinTheHour(t *testing.T) {
	for _, outage := range []time.Duration{time.Hour, 25 * time.Minute} {
		tk := newTestKnocks(t)
		start := tk.clock.now()
		urls := make([]string, 50)
		for i := range urls {
			urls[i] = fmt.Sprintf("https://ntfy.sh/dead%d", i)
			ev := r3reg(r3key(i), urls[i], start)
			if rej, msg := tk.take(nil, &ev); rej {
				t.Fatal(msg)
			}
		}
		live := func() int {
			n := 0
			for _, u := range urls {
				if tk.eps[u] != nil {
					n++
				}
			}
			return n
		}
		for tk.clock.now().Sub(start) < time.Hour {
			tk.advance(10 * time.Second)
			for _, j := range tk.log {
				ep := tk.eps[j.url]
				if ep == nil {
					continue
				}
				if !j.decoy {
					t.Fatal("a real knock with no wrap")
				}
				if j.at.Sub(start) < outage {
					tk.q.result(ep, true, 503, nil)
				} else {
					tk.q.result(ep, true, 201, nil)
				}
			}
			tk.log = nil
			if tk.clock.now().Sub(start) == 30*time.Minute && live() != len(urls) {
				t.Fatalf("%d of %d new endpoints went inside half an hour", len(urls)-live(), len(urls))
			}
		}
		want := 0
		if outage < 30*time.Minute {
			want = len(urls)
		}
		if got := live(); got != want {
			t.Fatalf("server down %v: %d of %d new endpoints left after an hour, want %d", outage, got, len(urls), want)
		}
	}
}

// a failure brings the next decoy run closer and leaves the one going on
// as it is: a failed knock says nothing about whether the next is real
func TestKnockFailureKeepsTheDecoyRun(t *testing.T) {
	tk := newTestKnocks(t)
	url := "https://ntfy.sh/run"
	ev := r3reg(r3key(1), url, tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatal(msg)
	}
	tk.drain()
	ep := tk.eps[url]
	// the next run far off, one of five going on, its first knock out
	tk.mu.Lock()
	tk.decoyAfterLocked(ep, 10*time.Hour)
	ep.last = tk.clock.now()
	ep.runGen++
	tk.decoyRunLocked(ep, ep.runGen, 4)
	tk.mu.Unlock()
	tk.q.result(ep, true, 503, nil)
	failed := tk.clock.now()
	if ep.decoyAt.Before(failed.Add(knockNewFailGap+tk.floor)) || !ep.decoyAt.Before(failed.Add(knockNewFailGap*3/2+tk.floor)) {
		t.Fatalf("next decoy run %v after a failure", ep.decoyAt.Sub(failed))
	}
	tk.advance(knockNewFailGap - 15*time.Second)
	if len(tk.log) == 0 {
		t.Fatal("a failure cut the decoy run short")
	}
	for _, j := range tk.log {
		if !j.decoy {
			t.Fatal("a real knock with no wrap")
		}
	}
}

// a redirect is not a knock delivered: it counts as a failure
func TestKnockRedirectIsNotDelivered(t *testing.T) {
	tk := newTestKnocks(t)
	for i, code := range []int{301, 302, 303, 307, 308} {
		url := fmt.Sprintf("https://ntfy.sh/moved%d", i)
		ev := r3reg(r3key(i), url, tk.clock.now())
		if rej, msg := tk.take(nil, &ev); rej {
			t.Fatal(msg)
		}
		ep := tk.eps[url]
		tk.q.result(ep, true, code, nil)
		_, sh := tk.shareOf("ntfy.sh")
		if _, pend := sh.pending[ep]; ep.delivered || !pend || ep.fails != 1 {
			t.Fatalf("%d: delivered %v, still new %v, %d failures", code, ep.delivered, pend, ep.fails)
		}
	}
}

// at send time a name that is not there lets a new endpoint go; a resolver
// that fails does not
func TestKnockNewEndpointWithoutANameGoes(t *testing.T) {
	tk := newTestKnocks(t)
	posted := 0
	tk.q.post = func(context.Context, string) (int, error) { posted++; return 201, nil }
	for i, c := range []struct {
		err  error
		kept bool
	}{
		{&net.DNSError{Err: "no such host", IsNotFound: true}, false},
		{errNotPublic, false},
		{&net.DNSError{Err: "i/o timeout", IsTimeout: true}, true},
		{context.DeadlineExceeded, true},
	} {
		tk.q.resolve = func(context.Context, string) ([]net.IP, error) { return nil, c.err }
		url := fmt.Sprintf("https://push.s%d.org/x", i)
		ev := r3reg(r3key(i), url, tk.clock.now())
		if rej, msg := tk.take(nil, &ev); rej {
			t.Fatal(msg)
		}
		tk.mu.Lock()
		tk.domains[tk.eps[url].domain].inflight++
		tk.mu.Unlock()
		tk.q.send(context.Background(), tk.eps[url], true)
		if (tk.eps[url] != nil) != c.kept {
			t.Fatalf("%v: kept %v", c.err, tk.eps[url] != nil)
		}
	}
	if posted != 0 {
		t.Fatal("a knock went out without a public address")
	}
}

func TestKnockServerNamesMustResolve(t *testing.T) {
	tk := newTestKnocks(t)
	asked := 0
	tk.lookup = func(ctx context.Context, host string) ([]net.IP, error) {
		asked++
		return fakeLookup(ctx, host)
	}
	for i := 0; i < 5; i++ {
		sk, _ := keypair()
		ev := signedReg(t, sk, "https://up.nx-nobody.org/x", tk.clock.now())
		if rej, msg := tk.take(nil, &ev); !rej || !strings.Contains(msg, "resolve") {
			t.Fatalf("a name that does not resolve: %v %q", rej, msg)
		}
	}
	if asked != 1 {
		t.Fatalf("the name was looked up %d times, the answer is kept", asked)
	}
	// a listed server needs no lookup
	sk, _ := keypair()
	ev := signedReg(t, sk, "https://ntfy.sh/up", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatal(msg)
	}
	if asked != 1 {
		t.Fatal("a listed server's name was looked up")
	}
}

// a lookup comes after every other check: nothing malformed, stale or
// refused costs one
func TestKnockLookupAfterEveryOtherCheck(t *testing.T) {
	tk := newTestKnocks(t)
	asked := 0
	tk.lookup = func(ctx context.Context, host string) ([]net.IP, error) {
		asked++
		return fakeLookup(ctx, host)
	}
	now := tk.clock.now()
	for _, ev := range []nostr.Event{
		r3reg(r3key(1), "https://a1.victim.org/x", now.Add(-365*24*time.Hour)),
		r3reg(r3key(2), "http://a2.victim.org/x", now),
		r3reg(r3key(3), "https://a3.victim.org:8443/x", now),
		r3reg(r3key(4), "https://localhost/x", now),
		r3reg(r3key(5), "https://intranet/x", now),
		r3reg(r3key(6), "https://db.internal/x", now),
		r3reg(r3key(7), "https://x.y.github.io/x", now),
		{Kind: knockKind, PubKey: "zz", CreatedAt: nostr.Timestamp(now.Unix()), Content: "https://a8.victim.org/x"},
		{Kind: knockKind, PubKey: r3key(9), CreatedAt: nostr.Timestamp(now.Unix()), Content: "https://a9.victim.org/x", Tags: nostr.Tags{{"x"}}},
		r3reg(r3key(10), "https://a10.victim.org/"+strings.Repeat("x", 2000), now),
	} {
		if rej, _ := tk.take(nil, &ev); !rej {
			t.Fatalf("%q was taken", ev.Content)
		}
	}
	if asked != 0 {
		t.Fatalf("%d names looked up for registrations refused anyway", asked)
	}
}

// a caller that goes away does not cut the lookup short, and a lookup that
// fails for a while is not remembered as a name that does not exist
func TestKnockLookupIsNotPoisoned(t *testing.T) {
	tk := newTestKnocks(t)
	fail := true
	tk.lookup = func(ctx context.Context, host string) ([]net.IP, error) {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		if fail {
			return nil, &net.DNSError{Err: "i/o timeout", Name: host, IsTimeout: true}
		}
		return []net.IP{net.ParseIP("1.1.1.1")}, nil
	}
	gone, cancel := context.WithCancel(context.Background())
	cancel()
	ev := r3reg(r3key(1), "https://push.community.org/a", tk.clock.now())
	if rej, msg := tk.take(gone, &ev); !rej || !strings.HasPrefix(msg, "error:") {
		t.Fatalf("a timeout answered %v %q", rej, msg)
	}
	fail = false
	ev2 := r3reg(r3key(2), "https://push.community.org/b", tk.clock.now())
	if rej, msg := tk.take(gone, &ev2); rej {
		t.Fatalf("after a timeout and with the caller gone, the name was refused: %q", msg)
	}
}

// a renewal or a move to an endpoint already held is never looked up
func TestKnockRenewalNeedsNoLookup(t *testing.T) {
	tk := newTestKnocks(t)
	ev := r3reg(r3key(1), "https://push.community.org/old", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatal(msg)
	}
	tk.lookup = func(context.Context, string) ([]net.IP, error) {
		return nil, &net.DNSError{Err: "no such host", IsNotFound: true}
	}
	tk.namesMu.Lock()
	tk.names = map[string]knockName{}
	tk.namesMu.Unlock()
	renew := r3reg(r3key(1), "https://push.community.org/old", tk.clock.now().Add(time.Second))
	if rej, msg := tk.take(nil, &renew); rej {
		t.Fatalf("a renewal was looked up and refused: %q", msg)
	}
	join := r3reg(r3key(2), "https://push.community.org/old", tk.clock.now())
	if rej, msg := tk.take(nil, &join); rej {
		t.Fatalf("an address joining an endpoint already held was refused: %q", msg)
	}
}

// lookups have a pace for everyone; past it a name passes unchecked and
// nothing is remembered
func TestKnockLookupsArePaced(t *testing.T) {
	tk := newTestKnocks(t)
	tk.lookups = newBucket(0, 3)
	asked := 0
	tk.lookup = func(ctx context.Context, host string) ([]net.IP, error) {
		asked++
		return fakeLookup(ctx, host)
	}
	for i := 0; i < 10; i++ {
		ev := r3reg(r3key(i), fmt.Sprintf("https://push.s%d.org/x", i), tk.clock.now())
		if rej, msg := tk.take(nil, &ev); rej {
			t.Fatalf("past the pace: %q", msg)
		}
	}
	if asked != 3 || len(tk.names) != 3 || len(tk.eps) != 10 {
		t.Fatalf("%d asked, %d names remembered, %d endpoints", asked, len(tk.names), len(tk.eps))
	}
}

// names that do not exist, sent as fast as the relay takes them on fresh
// connections, keep no community server out; once the posts find them not
// there they are gone
func TestKnockMadeUpNamesKeepNoOneOut(t *testing.T) {
	tk := newTestKnocks(t)
	tk.q.resolve = func(ctx context.Context, host string) ([]net.IP, error) { return fakeLookup(ctx, host) }
	tk.q.post = func(context.Context, string) (int, error) { return 201, nil }
	for i := 0; i < 500; i++ {
		ev := r3reg(r3key(i), fmt.Sprintf("https://up.nx%d.org/x", i), tk.clock.now())
		tk.take(nil, &ev)
	}
	legit := "https://push.community.org/up"
	ev := r3reg(r3key(900000), legit, tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatalf("a community server after a flood of made-up names: %q", msg)
	}
	tk.drain()
	tk.log = nil
	tk.advance(10 * time.Minute)
	for _, j := range tk.log {
		if ep := tk.eps[j.url]; ep != nil {
			tk.mu.Lock()
			tk.domainLocked(ep.domain).inflight++
			tk.mu.Unlock()
			tk.q.send(context.Background(), ep, j.decoy)
		}
	}
	if len(tk.eps) != 1 || tk.eps[legit] == nil || !tk.eps[legit].delivered {
		t.Fatalf("%d endpoints left after the posts", len(tk.eps))
	}
}

// names past the lookup pace hold a few of one server's new places, so
// names that were checked keep the rest
func TestKnockUncheckedNamesHoldAFew(t *testing.T) {
	tk := newTestKnocks(t)
	tk.lookups = newBucket(0, 0)
	n := 0
	for i := 0; i < knockUncheckedEPs+5; i++ {
		ev := r3reg(r3key(i), fmt.Sprintf("https://nx%d.victim.org/x", i), tk.clock.now())
		if rej, _ := tk.take(nil, &ev); !rej {
			n++
		}
	}
	if n != knockUncheckedEPs {
		t.Fatalf("%d unchecked names taken on one server, the cap is %d", n, knockUncheckedEPs)
	}
	// another server is not held by them
	other := r3reg(r3key(1000), "https://push.other.org/x", tk.clock.now())
	if rej, msg := tk.take(nil, &other); rej {
		t.Fatalf("another server's unchecked name: %q", msg)
	}
	// a checked name on the same server gets in
	tk.lookups = newBucket(20, 40)
	legit := r3reg(r3key(1001), "https://push.victim.org/u", tk.clock.now())
	if rej, msg := tk.take(nil, &legit); rej {
		t.Fatalf("a checked name on the held server: %q", msg)
	}
	if tk.eps["https://push.victim.org/u"].unchecked {
		t.Fatal("a checked name counted as unchecked")
	}
	// one that delivers or goes gives its place back
	tk.lookups = newBucket(0, 0)
	tk.q.result(tk.eps["https://nx0.victim.org/x"], true, 201, nil)
	tk.gone("https://nx1.victim.org/x")
	for i, want := range []bool{false, false, true} {
		ev := r3reg(r3key(2000+i), fmt.Sprintf("https://late%d.victim.org/x", i), tk.clock.now())
		if rej, _ := tk.take(nil, &ev); rej != want {
			t.Fatalf("unchecked name %d after two places came back: refused %v", i, rej)
		}
	}
	if d := tk.domains["victim.org"]; d.unchecked != knockUncheckedEPs {
		t.Fatalf("%d unchecked counted", d.unchecked)
	}
}

// posts go over ipv4, so a server with ipv6 addresses only is refused up
// front, with an answer the app shows
func TestKnockNameNeedsAnIPv4Address(t *testing.T) {
	tk := newTestKnocks(t)
	tk.lookup = func(ctx context.Context, host string) ([]net.IP, error) {
		switch {
		case strings.HasPrefix(host, "v6only."):
			return []net.IP{net.ParseIP("2606:4700::1111")}, nil
		case strings.HasPrefix(host, "both."):
			return []net.IP{net.ParseIP("2606:4700::1111"), net.ParseIP("1.1.1.1")}, nil
		}
		return fakeLookup(ctx, host)
	}
	ev := r3reg(r3key(1), "https://v6only.community.org/x", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); !rej || !strings.HasPrefix(msg, "invalid:") {
		t.Fatalf("an ipv6-only server: %v %q", rej, msg)
	}
	// remembered with the same answer
	ev = r3reg(r3key(2), "https://v6only.community.org/y", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); !rej || msg != knockNoV4 {
		t.Fatalf("an ipv6-only server again: %v %q", rej, msg)
	}
	ev = r3reg(r3key(3), "https://both.community.org/x", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatalf("a server with both: %q", msg)
	}
	// posting over both, ipv6 alone will do
	tk.v4 = false
	tk.names = map[string]knockName{}
	ev = r3reg(r3key(4), "https://v6only.community.org/z", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatalf("an ipv6-only server with posts over both: %q", msg)
	}
}

// a resolver on a dns server of the test's own: answer gives, by a name's
// first label and the type asked, the addresses or the failure
func testResolver(t *testing.T, answer func(label string, aaaa bool) ([]net.IP, dnsmessage.RCode)) *net.Resolver {
	t.Helper()
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { pc.Close() })
	go func() {
		buf := make([]byte, 1500)
		for {
			n, addr, err := pc.ReadFrom(buf)
			if err != nil {
				return
			}
			var m dnsmessage.Message
			if m.Unpack(buf[:n]) != nil || len(m.Questions) == 0 {
				continue
			}
			q := m.Questions[0]
			resp := dnsmessage.Message{Header: dnsmessage.Header{ID: m.ID, Response: true, RecursionAvailable: true, RecursionDesired: true}, Questions: m.Questions}
			if q.Type == dnsmessage.TypeA || q.Type == dnsmessage.TypeAAAA {
				label, _, _ := strings.Cut(q.Name.String(), ".")
				ips, rc := answer(label, q.Type == dnsmessage.TypeAAAA)
				resp.RCode = rc
				for _, ip := range ips {
					h := dnsmessage.ResourceHeader{Name: q.Name, Type: q.Type, Class: q.Class, TTL: 60}
					if q.Type == dnsmessage.TypeA {
						resp.Answers = append(resp.Answers, dnsmessage.Resource{Header: h, Body: &dnsmessage.AResource{A: [4]byte(ip.To4())}})
					} else {
						resp.Answers = append(resp.Answers, dnsmessage.Resource{Header: h, Body: &dnsmessage.AAAAResource{AAAA: [16]byte(ip.To16())}})
					}
				}
			}
			if out, err := resp.Pack(); err == nil {
				pc.WriteTo(out, addr)
			}
		}
	}()
	return &net.Resolver{PreferGo: true, Dial: func(ctx context.Context, _, _ string) (net.Conn, error) {
		var d net.Dialer
		return d.DialContext(ctx, "udp", pc.LocalAddr().String())
	}}
}

// a resolver that fails on A but answers AAAA is a lookup that failed, not
// a server without ipv4: nothing is remembered, and once A answers again the
// name passes. the same at send time
func TestKnockFailedALookupIsNoAnswer(t *testing.T) {
	var mu sync.Mutex
	aFails := true
	v4, v6 := net.ParseIP("1.1.1.1"), net.ParseIP("2606:4700::1111")
	res := testResolver(t, func(label string, aaaa bool) ([]net.IP, dnsmessage.RCode) {
		mu.Lock()
		defer mu.Unlock()
		switch {
		case label == "dual" && !aaaa && aFails:
			return nil, dnsmessage.RCodeServerFailure
		case label == "dual" && !aaaa, label == "v4" && !aaaa:
			return []net.IP{v4}, dnsmessage.RCodeSuccess
		case label == "dual", label == "v6only" && aaaa:
			return []net.IP{v6}, dnsmessage.RCodeSuccess
		case label == "v6only", label == "v4":
			return nil, dnsmessage.RCodeSuccess
		}
		return nil, dnsmessage.RCodeNameError
	})
	tk := newTestKnocks(t)
	tk.lookup = tk.lookupOn(res)
	if msg, _ := tk.nameCheck("dual.community.org"); msg != "error: the name could not be looked up, try again" {
		t.Fatalf("A failing, AAAA there: %q", msg)
	}
	if _, kept := tk.names["dual.community.org"]; kept {
		t.Fatal("a failed lookup was remembered")
	}
	send := knockResolverOn(res, "tcp4")
	_, err := send(context.Background(), "dual.community.org")
	var dnsErr *net.DNSError
	if err == nil || errors.Is(err, errNotPublic) || errors.As(err, &dnsErr) && dnsErr.IsNotFound {
		t.Fatalf("A failing at send time: %v", err)
	}
	mu.Lock()
	aFails = false
	mu.Unlock()
	if msg, _ := tk.nameCheck("dual.community.org"); msg != "" {
		t.Fatalf("A back: %q", msg)
	}
	if ips, err := send(context.Background(), "dual.community.org"); err != nil || len(ips) != 1 || !ips[0].Equal(v4) {
		t.Fatalf("A back at send time: %v %v", ips, err)
	}
	for host, want := range map[string]string{
		"v4.community.org":     "",
		"v6only.community.org": knockNoV4,
		"gone.community.org":   knockNoName,
	} {
		if msg, _ := tk.nameCheck(host); msg != want {
			t.Fatalf("%s: %q, want %q", host, msg, want)
		}
	}
	// posting over both, ipv6 alone will do
	tk.v4 = false
	tk.names = map[string]knockName{}
	if msg, _ := tk.nameCheck("v6only.community.org"); msg != "" {
		t.Fatalf("an ipv6-only server with posts over both: %q", msg)
	}
}

// a full cache lets one entry go at a time, never all of them
func TestKnockNameCacheEvictsOne(t *testing.T) {
	tk := newTestKnocks(t)
	tk.lookups = newBucket(0, 1e9)
	n := 0
	tk.lookup = func(ctx context.Context, host string) ([]net.IP, error) {
		n++
		return fakeLookup(ctx, host)
	}
	tk.resolves(nil, "push.legit.org")
	for i := 0; i < 2*knockNamesKept; i++ {
		tk.resolves(nil, fmt.Sprintf("r%d.junk.org", i))
	}
	if len(tk.names) != knockNamesKept {
		t.Fatalf("the cache holds %d", len(tk.names))
	}
	hits := 0
	for i := 2*knockNamesKept - 100; i < 2*knockNamesKept; i++ {
		before := n
		tk.resolves(nil, fmt.Sprintf("r%d.junk.org", i))
		if n == before {
			hits++
		}
	}
	if hits < 90 {
		t.Fatalf("recent names were looked up again: %d of 100 kept", hits)
	}
}

// moving addresses between endpoints already held grows nothing and takes
// no token of the hour; new users still get in
func TestKnockMovesTakeNoToken(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < 50; i++ {
		if rej, msg := tk.take(nil, &[]nostr.Event{r3reg(r3key(i), "https://push.own.org/a", tk.clock.now())}[0]); rej {
			t.Fatal(msg)
		}
	}
	// one address stays on each endpoint, so neither is let go
	tk.take(nil, &[]nostr.Event{r3reg(r3key(98), "https://push.own.org/a", tk.clock.now())}[0])
	tk.take(nil, &[]nostr.Event{r3reg(r3key(99), "https://push.own.org/b", tk.clock.now())}[0])
	_, sh := tk.shareOf("")
	before := sh.fresh.tokens
	at := tk.clock.now()
	for m := 1; m <= 2000; m++ {
		i := m % 50
		target := "https://push.own.org/b"
		if (m/50)%2 == 1 {
			target = "https://push.own.org/a"
		}
		tk.take(nil, &[]nostr.Event{r3reg(r3key(i), target, at.Add(time.Duration(m)*time.Second))}[0])
	}
	if sh.fresh.tokens < before-1 {
		t.Fatalf("moves took %.0f tokens of the hour", before-sh.fresh.tokens)
	}
	// and a registration forgotten within the hour gives its token back
	sk, _ := keypair()
	reg := signedReg(t, sk, "https://push.own.org/a", tk.clock.now())
	tk.take(nil, &reg)
	mid := sh.fresh.tokens
	forget := signedReg(t, sk, "", tk.clock.now().Add(time.Second))
	tk.take(nil, &forget)
	if sh.fresh.tokens <= mid {
		t.Fatal("a registration forgotten within the hour kept its token")
	}
}

// ten names, each a server of its own, fill a little of the common share
func TestKnockTenNamesCannotFillTheCommonShare(t *testing.T) {
	tk := newTestKnocks(t)
	tk.lookups = newBucket(0, 1e9)
	for i := 0; i < 20000; i++ {
		ev := r3reg(r3key(i), fmt.Sprintf("https://h%d.srv%d.org/up", i, i%10), tk.clock.now())
		tk.take(nil, &ev)
	}
	_, sh := tk.shareOf("")
	if sh.eps > 10*knockServerEPs/4 {
		t.Fatalf("ten servers hold %d endpoints while none ever delivered", sh.eps)
	}
	sk, _ := keypair()
	ev := signedReg(t, sk, "https://push.own-server.org/up", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatalf("a server of one's own was refused: %q", msg)
	}
}

// new registrations come at a pace per share; renewals always go
func TestKnockNewRegistrationsArePaced(t *testing.T) {
	tk := newTestKnocks(t)
	var first nostr.Event
	for i := 0; i < knockPushHostFresh; i++ {
		ev := r3reg(r3key(i), fmt.Sprintf("https://ntfy.sh/up%d", i/200), tk.clock.now())
		if rej, msg := tk.take(nil, &ev); rej {
			t.Fatalf("%d: %q", i, msg)
		}
		if i == 0 {
			first = ev
		}
	}
	ev := r3reg(r3key(knockPushHostFresh), "https://ntfy.sh/up0", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); !rej || !strings.Contains(msg, "new registrations") {
		t.Fatalf("past the hour's pace: %v %q", rej, msg)
	}
	renew := r3reg(first.PubKey, first.Content, tk.clock.now().Add(time.Second))
	if rej, msg := tk.take(nil, &renew); rej {
		t.Fatalf("a renewal was refused: %q", msg)
	}
	tk.clock.set(tk.clock.now().Add(time.Hour))
	ev = r3reg(r3key(knockPushHostFresh), "https://ntfy.sh/up0", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatalf("an hour later: %q", msg)
	}
}

// endpoints that never delivered hold at most a tenth of a share, until
// they deliver once or are a day old
func TestKnockNewEndpointsHoldATenth(t *testing.T) {
	tk := newTestKnocks(t)
	_, sh := tk.shareOf("ntfy.sh")
	sh.fresh = newBucket(0, 1e9)
	n := 0
	for i := 0; i < sh.pendingCap()+50; i++ {
		ev := r3reg(r3key(i), fmt.Sprintf("https://ntfy.sh/new%d", i), tk.clock.now())
		if rej, _ := tk.take(nil, &ev); !rej {
			n++
		}
	}
	if n != sh.pendingCap() {
		t.Fatalf("%d new endpoints taken, the cap is %d", n, sh.pendingCap())
	}
	tk.q.result(tk.eps["https://ntfy.sh/new0"], true, 201, nil)
	ev := r3reg(r3key(900000), "https://ntfy.sh/after", tk.clock.now())
	if rej, msg := tk.take(nil, &ev); rej {
		t.Fatalf("one delivered, room for one: %q", msg)
	}
	tk.clock.set(tk.clock.now().Add(knockTrustAfter))
	tk.tick()
	if len(sh.pending) != 0 {
		t.Fatalf("%d still new a day later", len(sh.pending))
	}
}

// near full, a share keeps its last twentieth for addresses already there
func TestKnockNearFullKeepsRoomForTheRegistered(t *testing.T) {
	old := knockPushHostEPs
	knockPushHostEPs = 100
	t.Cleanup(func() { knockPushHostEPs = old })
	tk := newTestKnocks(t)
	var firstPk string
	for i := 0; i < 95; i++ {
		ev := r3reg(r3key(i), fmt.Sprintf("https://ntfy.sh/e%d", i), tk.clock.now())
		if rej, msg := tk.take(nil, &ev); rej {
			t.Fatalf("%d: %q", i, msg)
		}
		tk.q.result(tk.eps[ev.Content], true, 201, nil)
		if i == 0 {
			firstPk = ev.PubKey
		}
	}
	ev := r3reg(r3key(500), "https://ntfy.sh/newcomer", tk.clock.now())
	if rej, _ := tk.take(nil, &ev); !rej {
		t.Fatal("a new address took the last twentieth")
	}
	move := r3reg(firstPk, "https://ntfy.sh/moved", tk.clock.now().Add(time.Second))
	if rej, msg := tk.take(nil, &move); rej {
		t.Fatalf("an address already there could not move: %q", msg)
	}
}

// one connection makes a bounded number of new registrations
func TestKnockConnectionRegistrationBudget(t *testing.T) {
	url, _ := testKnockRelay(t)
	r := connect(t, url)
	took := 0
	for i := 0; i < regBurst+10; i++ {
		sk, _ := keypair()
		if publish(t, r, signedReg(t, sk, fmt.Sprintf("https://ntfy.sh/c%d", i), time.Now())) == nil {
			took++
		}
	}
	if took > regBurst+1 {
		t.Fatalf("one connection made %d new registrations", took)
	}
}

// with the shared budget empty no server's token is spent, and the ring is
// not walked
func TestKnockEmptyBudgetSpendsNothing(t *testing.T) {
	tk := newTestKnocks(t)
	tk.mu.Lock()
	defer tk.mu.Unlock()
	now := tk.clock.now()
	for d := 0; d < 1000; d++ {
		tk.setLocked(knockKey(r3key(d)), fmt.Sprintf("https://s%d.org/x", d), now.Unix(), now.Add(knockTTL).Unix())
	}
	for _, ep := range tk.eps {
		tk.q.addLocked(ep, false)
	}
	tk.q.rate.tokens, tk.q.rate.last = 0, now
	first := tk.q.shared[0]
	before := first.rate.tokens
	t0 := time.Now()
	for i := 0; i < 200; i++ {
		if _, _, ok := tk.q.nextLocked(now); ok {
			t.Fatal("a knock went with the shared budget empty")
		}
	}
	if first.rate.tokens != before {
		t.Fatalf("a server's tokens went %.0f -> %.0f", before, first.rate.tokens)
	}
	if per := time.Since(t0) / 200; per > 50*time.Microsecond {
		t.Fatalf("a poll with the budget empty took %v", per)
	}
	if w := tk.q.budgetWait(now); w <= 0 || w > time.Second {
		t.Fatalf("the wait for the next token: %v", w)
	}
}

func TestKnockGoneUsesTheIndex(t *testing.T) {
	tk := newTestKnocks(t)
	tk.mu.Lock()
	now := tk.clock.now()
	for i := 0; i < 200000; i++ {
		tk.setLocked(knockKey(r3key(i)), fmt.Sprintf("https://ntfy.sh/r%d", i/maxRegsPerEP), now.Unix(), now.Add(knockTTL).Unix())
	}
	tk.mu.Unlock()
	t0 := time.Now()
	tk.gone("https://ntfy.sh/r5")
	if w := time.Since(t0); w > 2*time.Millisecond {
		t.Fatalf("one gone() took %v", w)
	}
	if len(tk.regs) != 200000-maxRegsPerEP {
		t.Fatalf("%d left", len(tk.regs))
	}
}

func TestKnockCheckAndApplyAreOneStep(t *testing.T) {
	tk := newTestKnocks(t)
	now := tk.clock.now()
	// the hour's pace out of the way: this is about order only
	_, sh := tk.shareOf("ntfy.sh")
	sh.fresh = newBucket(0, 1e9)
	older := 0
	for i := 0; i < 5000; i++ {
		pk := r3key(i)
		a := r3reg(pk, fmt.Sprintf("https://ntfy.sh/a%d", i%100), now)
		b := r3reg(pk, fmt.Sprintf("https://ntfy.sh/b%d", i%100), now.Add(time.Second))
		var wg sync.WaitGroup
		wg.Add(2)
		go func() { defer wg.Done(); tk.apply(&a) }()
		go func() { defer wg.Done(); tk.apply(&b) }()
		wg.Wait()
		tk.mu.Lock()
		if r := tk.regs[knockKey(pk)]; r == nil || r.made == a.CreatedAt.Time().Unix() {
			older++
		}
		tk.mu.Unlock()
	}
	if older != 0 {
		t.Fatalf("the older registration won %d of 5000 pairs", older)
	}
}

// what is answered ok is what is kept: a share that fills while many come
// at once refuses the rest, never takes them in the answer and drops them
func TestKnockAnswerIsWhatIsKept(t *testing.T) {
	old := knockPushHostEPs
	knockPushHostEPs = 40
	t.Cleanup(func() { knockPushHostEPs = old })
	tk := newTestKnocks(t)
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok := 0
	for i := 0; i < 200; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			ev := r3reg(r3key(i), fmt.Sprintf("https://ntfy.sh/e%d", i), tk.clock.now())
			if rej, _ := tk.take(nil, &ev); !rej {
				mu.Lock()
				ok++
				mu.Unlock()
			}
		}(i)
	}
	wg.Wait()
	if ok != len(tk.regs) {
		t.Fatalf("%d answered ok, %d kept", ok, len(tk.regs))
	}
}

func TestKnockServersAreServedInTurn(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < knockDomainQueue; i++ {
		register(t, tk, fmt.Sprintf("https://flood.org/%d", i))
	}
	register(t, tk, "https://quiet.org/up")
	tk.drain()
	tk.mu.Lock()
	for u, ep := range tk.eps {
		if strings.Contains(u, "flood") {
			tk.q.addLocked(ep, false)
		}
	}
	tk.q.addLocked(tk.eps["https://quiet.org/up"], false)
	var order []string
	for i := 0; i < 3; i++ {
		ep, _, ok := tk.q.nextLocked(tk.clock.now())
		if !ok {
			t.Fatal("nothing to send")
		}
		order = append(order, ep.domain)
		tk.q.doneLocked(ep)
	}
	tk.mu.Unlock()
	found := false
	for _, d := range order[:2] {
		found = found || d == "quiet.org"
	}
	if !found {
		t.Fatalf("a quiet server waited behind a flooded one: %v", order)
	}
}

func TestKnockFullQueues(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < knockDomainQueue+10; i++ {
		register(t, tk, fmt.Sprintf("https://flood.org/%d", i))
	}
	register(t, tk, "https://quiet.org/up")
	tk.drain()
	tk.mu.Lock()
	defer tk.mu.Unlock()
	for _, ep := range tk.eps {
		if ep.domain == "flood.org" {
			tk.q.addLocked(ep, false)
		}
	}
	if d := tk.domains["flood.org"]; d.waiting() > knockDomainQueue {
		t.Fatalf("one server queued %d", d.waiting())
	}
	tk.q.addLocked(tk.eps["https://quiet.org/up"], false)
	if tk.domains["quiet.org"].waiting() != 1 {
		t.Fatal("a full server kept another's knock out")
	}
	// the common queue as a whole is bounded too
	now := tk.clock.now()
	for d := 0; d < 100; d++ {
		for j := 0; j < knockDomainQueue; j++ {
			u := fmt.Sprintf("https://s%d.org/%d", d, j)
			tk.setLocked(knockKey(r3key(10000+d*100+j)), u, now.Unix(), now.Add(knockTTL).Unix())
			tk.q.addLocked(tk.eps[u], false)
		}
	}
	if tk.q.sharedQueued > knockSharedQueue {
		t.Fatalf("the common queue holds %d", tk.q.sharedQueued)
	}
	// and a public server's knock still goes in
	tk.setLocked(knockKey(r3key(1)), "https://ntfy.sh/up", now.Unix(), now.Add(knockTTL).Unix())
	tk.q.addLocked(tk.eps["https://ntfy.sh/up"], false)
	if tk.domains["ntfy.sh"].waiting() != 1 {
		t.Fatal("a public server's knock was kept out by the common queue")
	}
}

func TestKnockDecoysYieldToRealKnocks(t *testing.T) {
	tk := newTestKnocks(t)
	for i := 0; i < 20; i++ {
		register(t, tk, fmt.Sprintf("https://ntfy.sh/up%d", i))
	}
	tk.drain()
	tk.mu.Lock()
	defer tk.mu.Unlock()
	tk.q.rate = newBucket(0, 10)
	for _, ep := range tk.eps {
		tk.q.addLocked(ep, true)
	}
	n := 0
	for {
		ep, _, ok := tk.q.nextLocked(tk.clock.now())
		if !ok {
			break
		}
		tk.q.doneLocked(ep)
		n++
	}
	if n != 5 {
		t.Fatalf("decoys took %d of a budget of 10, want half", n)
	}
	for _, ep := range tk.eps {
		tk.q.addLocked(ep, false)
	}
	n = 0
	for {
		ep, _, ok := tk.q.nextLocked(tk.clock.now())
		if !ok {
			break
		}
		tk.q.doneLocked(ep)
		n++
	}
	if n != 5 {
		t.Fatalf("real knocks got %d of the rest", n)
	}
}

// slow servers hold up their own knocks only: a real knock to another one
// goes at once, through the real client's transport
func TestKnockSlowServersDoNotHoldUpOthers(t *testing.T) {
	hang := make(chan struct{})
	defer close(hang)
	slow := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-hang:
		case <-r.Context().Done():
		}
	}))
	defer slow.Close()
	served := make(chan time.Time, 4)
	good := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		served <- time.Now()
		w.WriteHeader(201)
	}))
	defer good.Close()

	k := newKnocker(nil, false)
	k.lookup = fakeLookup
	// the names resolve to two public addresses, dialled to the stand-ins
	k.q.resolve = func(_ context.Context, host string) ([]net.IP, error) {
		if strings.Contains(host, "slow") {
			return []net.IP{net.ParseIP("9.9.9.9")}, nil
		}
		return []net.IP{net.ParseIP("1.1.1.1")}, nil
	}
	c := knockClientWith(func(ctx context.Context, n, addr string) (net.Conn, error) {
		to := good.Listener.Addr().String()
		if ips, _ := ctx.Value(knockDialIPs{}).([]net.IP); len(ips) > 0 && ips[0].String() == "9.9.9.9" {
			to = slow.Listener.Addr().String()
		}
		return (&net.Dialer{}).DialContext(ctx, n, to)
	})
	c.Transport.(*http.Transport).TLSClientConfig = slow.Client().Transport.(*http.Transport).TLSClientConfig.Clone()
	c.Transport.(*http.Transport).TLSClientConfig.InsecureSkipVerify = true
	k.q.post = knockPoster(c)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	k.q.start(ctx)

	k.mu.Lock()
	for i := 0; i < 40; i++ {
		k.setLocked([32]byte{byte(i), 1}, fmt.Sprintf("https://h%d.slow.org/up", i), k.now().Unix(), k.now().Add(time.Hour).Unix())
	}
	k.setLocked([32]byte{9, 9}, "https://good.org/up", k.now().Unix(), k.now().Add(time.Hour).Unix())
	for u, ep := range k.eps {
		if strings.Contains(u, "slow") {
			k.q.addLocked(ep, false)
		}
	}
	k.mu.Unlock()
	time.Sleep(200 * time.Millisecond)
	t0 := time.Now()
	k.mu.Lock()
	k.q.addLocked(k.eps["https://good.org/up"], false)
	k.mu.Unlock()
	select {
	case at := <-served:
		if w := at.Sub(t0); w > time.Second {
			t.Fatalf("a knock to another server waited %v behind slow ones", w)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the knock to another server never went")
	}
	k.mu.Lock()
	busy := k.q.ipBusy["9.9.9.9"]
	k.mu.Unlock()
	if busy > knockPerIP {
		t.Fatalf("%d posts in flight to one address", busy)
	}
}

func TestKnockPostGivesUpQuickly(t *testing.T) {
	hang := make(chan struct{})
	defer close(hang)
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-hang:
		case <-r.Context().Done():
		}
	}))
	defer srv.Close()
	t0 := time.Now()
	_, err := knockPoster(srv.Client())(context.Background(), srv.URL+"/up")
	if err == nil {
		t.Fatal("a hanging server answered")
	}
	if w := time.Since(t0); w > knockPostTimeout+time.Second {
		t.Fatalf("a post waited %v", w)
	}
}

func TestKnockTableSurvivesARestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	store, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	store.start()
	clock := &fakeClock{t: time.Unix(1_800_000_000, 0)}
	k := newKnocker(store, false)
	k.lookup = fakeLookup
	k.now = clock.now
	sk, pk := keypair()
	ev := signedReg(t, sk, testEP, clock.now())
	k.apply(&ev)
	sk2, pk2 := keypair()
	ev2 := signedReg(t, sk2, testEP, clock.now().Add(-5*time.Minute))
	k.apply(&ev2)
	// a forget is kept across a restart for its window
	f2 := signedReg(t, sk2, "", clock.now())
	k.apply(&f2)
	if !store.flush(10 * time.Second) {
		t.Fatal("the writer did not catch up")
	}
	for _, p := range []string{path, path + "-wal", path + "-shm"} {
		if st, err := os.Stat(p); err == nil && st.Mode().Perm() != 0o600 {
			t.Fatalf("%s is %v", filepath.Base(p), st.Mode().Perm())
		}
	}
	store.close()

	for _, c := range []struct {
		after   time.Duration
		forgets int
	}{{time.Hour, 1}, {knockTTL - 2*time.Minute, 0}} {
		store, err := openKnockStore(path)
		if err != nil {
			t.Fatal(err)
		}
		k := newKnocker(store, false)
		k.lookup = fakeLookup
		k.now = func() time.Time { return clock.now().Add(c.after) }
		if err := k.load(); err != nil {
			t.Fatal(err)
		}
		if len(k.regs) != 1 || k.regs[knockKey(pk)] == nil {
			t.Fatalf("after %v: %d registrations", c.after, len(k.regs))
		}
		if len(k.forgets) != c.forgets {
			t.Fatalf("after %v: %d forgets, want %d", c.after, len(k.forgets), c.forgets)
		}
		if c.forgets == 1 {
			old := signedReg(t, sk2, testEP, clock.now().Add(-5*time.Minute))
			if rej, _ := k.check(&old); !rej {
				t.Fatal("after a restart a replay beat the forget")
			}
		}
		var raw int
		store.db.QueryRow(`SELECT count(*) FROM knock WHERE instr(lower(hex(addr)), ?) > 0`, pk[:16]).Scan(&raw)
		if raw != 0 {
			t.Fatal("the table holds the address itself")
		}
		_ = pk2
		store.close()
	}
}

// a mass expiry never crowds out a registration taken right after it, and
// a forget is on disk before the relay answers it
func TestKnockTableKeepsRoomForRegistrations(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	st, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()
	tk := newTestKnocks(t)
	tk.store = st
	now := tk.clock.now()
	// the writer held back while the sweep queues its deletes
	tk.mu.Lock()
	for i := 0; i < 100000; i++ {
		tk.setLocked(knockKey(r3key(i)), fmt.Sprintf("https://ntfy.sh/r%d", i/maxRegsPerEP), now.Unix(), now.Add(knockTTL).Unix())
	}
	tk.mu.Unlock()
	tk.clock.set(now.Add(knockTTL + time.Second))
	tk.tick()
	sk, pk := keypair()
	ev := signedReg(t, sk, "https://ntfy.sh/legit", tk.clock.now())
	tk.apply(&ev)
	if st.dropped.Load() != 0 {
		t.Fatalf("%d writes dropped", st.dropped.Load())
	}
	st.start()
	st.flush(time.Minute)
	var n int
	st.db.QueryRow(`SELECT count(*) FROM knock WHERE endpoint = 'https://ntfy.sh/legit'`).Scan(&n)
	if n != 1 {
		t.Fatal("the registration after the sweep is not in the table")
	}
	forget := signedReg(t, sk, "", tk.clock.now().Add(time.Second))
	tk.apply(&forget)
	var ep string
	st.db.QueryRow(`SELECT endpoint FROM knock WHERE addr = ?`, func() []byte { k := knockKey(pk); return k[:] }()).Scan(&ep)
	if ep != "" {
		t.Fatal("the forget was answered before it was on disk")
	}
}

// a forget the table cannot take is answered with an error, and nothing
// is forgotten in memory either: the phone sends it again
func TestKnockForgetOnALockedTableIsAnError(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	st, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()
	st.start()
	tk := newTestKnocks(t)
	tk.store = st
	sk, pk := keypair()
	reg := signedReg(t, sk, "https://ntfy.sh/up", tk.clock.now())
	if rej, msg := tk.take(nil, &reg); rej {
		t.Fatal(msg)
	}
	st.flush(time.Minute)
	other, err := sql.Open("sqlite3", path+"?_busy_timeout=0")
	if err != nil {
		t.Fatal(err)
	}
	defer other.Close()
	conn, err := other.Conn(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := conn.ExecContext(context.Background(), `BEGIN IMMEDIATE`); err != nil {
		t.Fatal(err)
	}
	forget := signedReg(t, sk, "", tk.clock.now().Add(time.Second))
	rej, msg := tk.take(nil, &forget)
	if !rej || !strings.HasPrefix(msg, "error:") {
		t.Fatalf("a forget not written was answered %v %q", rej, msg)
	}
	if tk.regs[knockKey(pk)] == nil {
		t.Fatal("a forget not written was taken in memory")
	}
	conn.ExecContext(context.Background(), `ROLLBACK`)
	conn.Close()
	if rej, msg := tk.take(nil, &forget); rej {
		t.Fatalf("sent again: %q", msg)
	}
	var ep string
	k := knockKey(pk)
	st.db.QueryRow(`SELECT endpoint FROM knock WHERE addr = ?`, k[:]).Scan(&ep)
	if ep != "" || tk.regs[k] != nil {
		t.Fatal("the forget sent again did not land")
	}
}

// with the writer's queue full of renewals, every forget still reaches the
// disk before it is answered
func TestKnockForgetsReachDiskUnderLoad(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	st, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()
	tk := newTestKnocks(t)
	tk.store = st
	now := tk.clock.now()
	const nf = 2000
	var sks []string
	for i := 0; i < nf; i++ {
		sk, _ := keypair()
		ev := signedReg(t, sk, fmt.Sprintf("https://ntfy.sh/f%d", i/200), now)
		tk.take(nil, &ev)
		sks = append(sks, sk)
	}
	// the writer not running, its queue filled to the brim by renewals
	for i := 0; len(st.ch) < cap(st.ch); i++ {
		st.put([32]byte{byte(i), byte(i >> 8), byte(i >> 16)}, "https://ntfy.sh/x", now.Unix(), now.Unix()+1, 0, false)
	}
	for _, sk := range sks {
		ev := signedReg(t, sk, "", now.Add(time.Second))
		if rej, msg := tk.take(nil, &ev); rej {
			t.Fatal(msg)
		}
	}
	var n int
	st.fdb.QueryRow(`SELECT count(*) FROM knock WHERE endpoint = ''`).Scan(&n)
	if n != nf {
		t.Fatalf("%d of %d forgets on disk", n, nf)
	}
}

// a storm of forgets is written in batches, each synced once, and past a
// thousand waiting the answer is to try later: none waits for minutes
func TestKnockForgetStorm(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	st, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()
	st.start()
	tk := newTestKnocks(t)
	tk.store = st
	_, sh := tk.shareOf("ntfy.sh")
	sh.fresh, sh.epCap, sh.regCap = newBucket(0, 1e9), 1e9, 1e9
	now := tk.clock.now()
	const n = 20000
	for i := 0; i < n; i++ {
		ev := r3reg(r3key(i), fmt.Sprintf("https://ntfy.sh/s%d", i/250), now)
		tk.take(nil, &ev)
	}
	st.flush(time.Minute)
	var wg sync.WaitGroup
	var ok, later, other atomic.Int64
	var slowest atomic.Int64
	t0 := time.Now()
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			ev := r3reg(r3key(i), "", now.Add(time.Second))
			s := time.Now()
			rej, msg := tk.take(nil, &ev)
			if d := int64(time.Since(s)); d > slowest.Load() {
				slowest.Store(d)
			}
			switch {
			case !rej:
				ok.Add(1)
			case strings.HasPrefix(msg, "rate-limited:"):
				later.Add(1)
			default:
				other.Add(1)
			}
		}(i)
	}
	wg.Wait()
	if other.Load() != 0 || ok.Load() == 0 {
		t.Fatalf("%d taken, %d told to try later, %d other", ok.Load(), later.Load(), other.Load())
	}
	if el := time.Since(t0); el > 30*time.Second || time.Duration(slowest.Load()) > 20*time.Second {
		t.Fatalf("the storm took %v, the slowest answer %v", el, time.Duration(slowest.Load()))
	}
	var rows int
	st.fdb.QueryRow(`SELECT count(*) FROM knock WHERE endpoint = ''`).Scan(&rows)
	if int64(rows) != ok.Load() {
		t.Fatalf("%d answered ok, %d on disk", ok.Load(), rows)
	}
}

func TestKnockWritesNeverBlock(t *testing.T) {
	path := filepath.Join(t.TempDir(), "knock.sqlite")
	store, err := openKnockStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer store.close()
	// the writer not running: puts past the buffer are dropped, not waited on
	t0 := time.Now()
	for i := 0; i < cap(store.ch)+100; i++ {
		store.put([32]byte{byte(i)}, testEP, 1, 2, 0, false)
	}
	if time.Since(t0) > time.Second || store.dropped.Load() != 100 {
		t.Fatalf("puts took %v, %d dropped", time.Since(t0), store.dropped.Load())
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
	// the same again tells the app it is not newer
	if err := publish(t, r, ev); err == nil || !strings.Contains(err.Error(), "duplicate") {
		t.Fatalf("a repeat answered %v", err)
	}
	if got, _ := ask(t, r, nostr.Filter{IDs: []string{ev.ID}}); len(got) != 0 {
		t.Fatal("the registration was stored")
	}
	select {
	case got := <-sub.Events:
		t.Fatalf("a listener was handed the registration: %s", got.Content)
	case <-time.After(300 * time.Millisecond):
	}
	tk.drain()

	if err := publish(t, r, wrap(t, pk, nil)); err != nil {
		t.Fatal(err)
	}
	got := waitKnocks(tk, 1)
	if len(got) != 1 || got[0].url != testEP {
		t.Fatalf("knocks after a wrap: %+v", got)
	}
	if err := publish(t, r, wrap(t, pk, func(e *nostr.Event) { e.Tags = append(e.Tags, nostr.Tag{"p", addr()}) })); err == nil {
		t.Fatal("a wrap to two addresses was taken")
	}

	// another key registers only itself
	sk2, pk2 := keypair()
	other := signedReg(t, sk2, "https://evil.org/up", time.Now())
	if err := publish(t, r, other); err != nil {
		t.Fatal(err)
	}
	tk.mu.Lock()
	defer tk.mu.Unlock()
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

// the real client refuses at the dial whatever the url or the resolver
// says: a loopback url, and the forms that carry one
func TestKnockClientReachesNothingPrivate(t *testing.T) {
	hit := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hit = true
	}))
	defer srv.Close()
	_, port, _ := net.SplitHostPort(srv.Listener.Addr().String())
	c := knockClient("tcp", "")
	for _, u := range []string{
		srv.URL + "/up",
		"https://[::ffff:127.0.0.1]:" + port + "/up",
		"https://[::7f00:1]:" + port + "/up",
		"https://[::1]:" + port + "/up",
	} {
		_, err := knockPoster(c)(context.Background(), u)
		if err == nil || hit || !strings.Contains(err.Error(), errNotPublic.Error()) {
			t.Fatalf("%s: %v (reached: %v)", u, err, hit)
		}
	}
	// a name the queue resolved to loopback is refused at the dial too
	ctx := context.WithValue(context.Background(), knockDialIPs{}, []net.IP{net.ParseIP("127.0.0.1")})
	if _, err := knockPoster(c)(ctx, "https://example.com:"+port+"/up"); err == nil || hit {
		t.Fatal("a resolved loopback address was dialled")
	}
	if _, err := knockResolver("tcp4")(context.Background(), "127.0.0.1"); err == nil {
		t.Fatal("the resolver handed out loopback")
	}
}

func TestKnockClientFollowsNoRedirect(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://127.0.0.1:1/", http.StatusFound)
	}))
	defer srv.Close()
	c := knockClientWith(func(ctx context.Context, n, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, n, srv.Listener.Addr().String())
	})
	code, err := knockPoster(c)(context.Background(), srv.URL+"/up")
	if err != nil || code != http.StatusFound {
		t.Fatalf("a redirect was followed: %d %v", code, err)
	}
}

func TestKnockClientTakesSmallAnswersOnly(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Big", strings.Repeat("a", 64<<10))
		w.WriteHeader(201)
	}))
	defer srv.Close()
	c := knockClientWith(func(ctx context.Context, n, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, n, srv.Listener.Addr().String())
	})
	if _, err := knockPoster(c)(context.Background(), srv.URL+"/up"); err == nil {
		t.Fatal("a 64 kB header was read")
	}
}

// the whole way: a registration over the websocket, a wrap to that
// address, and the knock arriving at a push server as an empty post,
// through the queue and the real client's transport
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
	tk.q.resolve = func(context.Context, string) ([]net.IP, error) { return []net.IP{net.ParseIP("1.1.1.1")}, nil }
	c := knockClientWith(func(ctx context.Context, n, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, n, push.Listener.Addr().String())
	})
	tr := c.Transport.(*http.Transport)
	tr.TLSClientConfig = push.Client().Transport.(*http.Transport).TLSClientConfig.Clone()
	tr.TLSClientConfig.InsecureSkipVerify = true
	tk.q.post = knockPoster(c)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	tk.q.start(ctx)

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
	// the minute and a little are up: one more for what came during it
	tk.tmu.Lock()
	timers := tk.timers
	tk.timers = nil
	tk.tmu.Unlock()
	for _, tm := range timers {
		tm.f()
	}
	deadline = time.Now().Add(3 * time.Second)
	for len(got()) < 2 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if b := got(); len(b) < 2 || b[1] != 0 {
		t.Fatalf("knocks after the floor: %v", b)
	}
}

// khatru logs an unexpected close; with no address of the caller
func TestUnexpectedCloseLogsNoAddress(t *testing.T) {
	relay := khatru.NewRelay()
	var buf bytes.Buffer
	var mu sync.Mutex
	relay.Log = log.New(writerFunc(func(p []byte) (int, error) {
		mu.Lock()
		defer mu.Unlock()
		return buf.Write(p)
	}), "", 0)
	applyLimits(relay, "")
	srv := httptest.NewServer(relay)
	defer srv.Close()
	c, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(srv.URL, "http"), http.Header{"X-Forwarded-For": {"203.0.113.9"}})
	if err != nil {
		t.Fatal(err)
	}
	c.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(4000, "bye"))
	c.Close()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		mu.Lock()
		got := buf.String()
		mu.Unlock()
		if strings.Contains(got, "unexpected close") {
			if strings.Contains(got, "127.0.0.1") || strings.Contains(got, "203.0.113.9") {
				t.Fatalf("the log names the caller: %q", got)
			}
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("no unexpected close was logged")
}

type writerFunc func([]byte) (int, error)

func (f writerFunc) Write(p []byte) (int, error) { return f(p) }
