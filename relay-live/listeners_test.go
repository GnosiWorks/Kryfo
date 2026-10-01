package main

import (
	"context"
	"net"
	"net/http/httptest"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/fasthttp/websocket"
	"github.com/fiatjaf/eventstore/slicestore"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

// socket buffers small enough that a client that stops reading holds up
// the relay's next write at once
const smallBuffer = 16 << 10

type smallBuffers struct{ net.Listener }

func (s smallBuffers) Accept() (net.Conn, error) {
	c, err := s.Listener.Accept()
	if tc, ok := c.(*net.TCPConn); ok {
		tc.SetWriteBuffer(smallBuffer)
	}
	return c, err
}

type backend interface {
	SaveEvent(context.Context, *nostr.Event) error
	QueryEvents(context.Context, nostr.Filter) (chan *nostr.Event, error)
	DeleteEvent(context.Context, *nostr.Event) error
}

// a relay with the limits on, over sockets with small buffers. tune runs
// after the limits are applied
func slowRelay(t *testing.T, db backend, tune func(*khatru.Relay)) (string, *limits) {
	t.Helper()
	relay := khatru.NewRelay()
	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	relay.DeleteEvent = append(relay.DeleteEvent, db.DeleteEvent)
	l := applyLimits(relay, "")
	if tune != nil {
		tune(relay)
	}
	srv := httptest.NewUnstartedServer(relay)
	srv.Listener = smallBuffers{srv.Listener}
	srv.Start()
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http"), l
}

func memStore(t *testing.T) backend {
	t.Helper()
	db := &slicestore.SliceStore{}
	if err := db.Init(); err != nil {
		t.Fatal(err)
	}
	return db
}

func testStore(t *testing.T) (*store, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "relay.sqlite")
	db, err := openStore(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(db.Close)
	return db, path
}

// a websocket with a small receive buffer, read only when the test says so
func dialSlow(t *testing.T, url string) *websocket.Conn {
	t.Helper()
	nd := &net.Dialer{Control: func(_, _ string, rc syscall.RawConn) error {
		var serr error
		err := rc.Control(func(fd uintptr) {
			serr = syscall.SetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_RCVBUF, smallBuffer)
		})
		if err != nil {
			return err
		}
		return serr
	}}
	d := websocket.Dialer{NetDialContext: nd.DialContext, HandshakeTimeout: 5 * time.Second}
	c, _, err := d.Dial(url, nil)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	return c
}

func sendReq(t *testing.T, c *websocket.Conn, id string, f nostr.Filter) {
	t.Helper()
	b, err := nostr.ReqEnvelope{SubscriptionID: id, Filters: nostr.Filters{f}}.MarshalJSON()
	if err != nil {
		t.Fatal(err)
	}
	if err := c.WriteMessage(websocket.TextMessage, b); err != nil {
		t.Fatal(err)
	}
}

func readNext(c *websocket.Conn, within time.Duration) (nostr.Envelope, error) {
	c.SetReadDeadline(time.Now().Add(within))
	_, msg, err := c.ReadMessage()
	if err != nil {
		return nil, err
	}
	return nostr.NewMessageParser().ParseMessage(string(msg))
}

// a live subscription for an address, up to its eose
func listen(t *testing.T, c *websocket.Conn, to string) {
	t.Helper()
	sendReq(t, c, "live", nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, LimitZero: true})
	for {
		env, err := readNext(c, 5*time.Second)
		if err != nil {
			t.Fatal(err)
		}
		switch env := env.(type) {
		case *nostr.EOSEEnvelope:
			return
		case *nostr.ClosedEnvelope:
			t.Fatalf("closed %q", env.Reason)
		}
	}
}

func openConns(l *limits) int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.conns)
}

// waits until the relay holds n connections
func waitConns(t *testing.T, l *limits, n int, within time.Duration) {
	t.Helper()
	end := time.Now().Add(within)
	for openConns(l) != n {
		if time.Now().After(end) {
			t.Fatalf("%d connections open after %v, want %d", openConns(l), within, n)
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// a raw client reads what is left and then finds its connection closed
func readToClose(t *testing.T, c *websocket.Conn) {
	t.Helper()
	end := time.Now().Add(5 * time.Second)
	for time.Now().Before(end) {
		if _, err := readNext(c, 5*time.Second); err != nil {
			return
		}
	}
	t.Fatal("the connection stayed open")
}

func bigWrap(t *testing.T, to string, at nostr.Timestamp) nostr.Event {
	return wrap(t, to, func(e *nostr.Event) {
		e.Content = strings.Repeat("s", 60<<10)
		e.CreatedAt = at
	})
}

func publishTimed(t *testing.T, r *nostr.Relay, ev nostr.Event) time.Duration {
	t.Helper()
	t0 := time.Now()
	if err := publish(t, r, ev); err != nil {
		t.Fatalf("publish: %v", err)
	}
	return time.Since(t0)
}

// every wrap to the address, read back from the store on a new connection
func checkStored(t *testing.T, url, to string, want []string) {
	t.Helper()
	got, why := ask(t, connect(t, url), nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Limit: 100})
	if why != "" {
		t.Fatalf("closed %q", why)
	}
	have := map[string]bool{}
	for _, ev := range got {
		have[ev.ID] = true
	}
	for _, id := range want {
		if !have[id] {
			t.Fatalf("%d of %d wraps in the store, %s missing", len(got), len(want), id)
		}
	}
}

// a listener that stops reading costs the publisher nothing: every ok comes
// back at once, the listener is closed once a write to it runs out of time,
// and it finds every wrap in the store when it comes back
func TestStuckListenerIsClosedAndThePublisherIsNot(t *testing.T) {
	const wait = 2 * time.Second
	url, l := slowRelay(t, memStore(t), func(r *khatru.Relay) { r.WriteWait = wait })
	to := addr()
	lis := dialSlow(t, url)
	listen(t, lis, to)

	pub := connect(t, url)
	var sent []string
	var worst time.Duration
	for i := 0; i < 12; i++ {
		ev := bigWrap(t, to, nostr.Now()-3600)
		worst = max(worst, publishTimed(t, pub, ev))
		sent = append(sent, ev.ID)
	}
	if worst >= wait {
		t.Fatalf("an ok took %v, as long as a write to the listener may", worst)
	}
	waitConns(t, l, 1, wait+3*time.Second)
	readToClose(t, lis)
	checkStored(t, url, to, sent)
}

// a listener that falls further behind than its queue is closed before any
// write to it runs out of time, and finds every wrap in the store
func TestListenerFarBehindIsClosed(t *testing.T) {
	url, l := slowRelay(t, memStore(t), func(r *khatru.Relay) {
		r.WriteWait = time.Minute
		r.MaxQueuedSize = 256 << 10
	})
	to := addr()
	lis := dialSlow(t, url)
	listen(t, lis, to)

	pub := connect(t, url)
	var sent []string
	var worst time.Duration
	for i := 0; i < 12; i++ {
		ev := bigWrap(t, to, nostr.Now()-3600)
		worst = max(worst, publishTimed(t, pub, ev))
		sent = append(sent, ev.ID)
	}
	if worst >= 2*time.Second {
		t.Fatalf("an ok took %v", worst)
	}
	waitConns(t, l, 1, 3*time.Second)
	readToClose(t, lis)
	checkStored(t, url, to, sent)
}

// a full page of stored wraps for one address, 6 MB
func fillPage(t *testing.T, db *store, to string) map[string]bool {
	t.Helper()
	page := map[string]bool{}
	for i := 0; i < 100; i++ {
		ev := bigWrap(t, to, nostr.Now()-3600-nostr.Timestamp(i))
		if err := db.SaveEvent(context.Background(), &ev); err != nil {
			t.Fatal(err)
		}
		page[ev.ID] = true
	}
	return page
}

// starts a page of stored wraps to a raw client and reads its first wrap,
// so the page is streaming and its read of the store is open
func startPage(t *testing.T, c *websocket.Conn, to string) string {
	t.Helper()
	sendReq(t, c, "page", nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Limit: 100})
	env, err := readNext(c, 5*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	ev, ok := env.(*nostr.EventEnvelope)
	if !ok {
		t.Fatalf("got %v first, want a wrap", env)
	}
	return ev.Event.ID
}

// while a page streams to a reader that has stopped for now, every
// publisher is answered at once, to that reader's address and to others.
// once it reads again it gets the whole page and every new wrap.
func TestPublishersAreAnsweredWhileAPageStreams(t *testing.T) {
	db, _ := testStore(t)
	to, other := addr(), addr()
	want := fillPage(t, db, to)
	url, _ := slowRelay(t, db, nil)
	rd := dialSlow(t, url)
	got := map[string]bool{startPage(t, rd, to): true}

	pub := connect(t, url)
	var worst time.Duration
	for i := 0; i < 10; i++ {
		for _, dest := range []string{to, other} {
			ev := wrap(t, dest, nil)
			worst = max(worst, publishTimed(t, pub, ev))
			if dest == to {
				want[ev.ID] = true
			}
		}
	}
	if worst >= 2*time.Second {
		t.Fatalf("an ok took %v while a page was streaming", worst)
	}

	eose := false
	for !eose || len(got) < len(want) {
		env, err := readNext(rd, 10*time.Second)
		if err != nil {
			t.Fatalf("%d of %d wraps, eose %v: %v", len(got), len(want), eose, err)
		}
		switch env := env.(type) {
		case *nostr.EventEnvelope:
			if !want[env.Event.ID] {
				t.Fatalf("a wrap that was not asked for")
			}
			got[env.Event.ID] = true
		case *nostr.EOSEEnvelope:
			eose = true
		default:
			t.Fatalf("got %v", env)
		}
	}
}

// a reader that stops for good in the middle of a page is closed once a
// write to it runs out of time, and its read of the store ends with it
func TestStuckPageIsClosed(t *testing.T) {
	const wait = time.Second
	db, path := testStore(t)
	to := addr()
	fillPage(t, db, to)
	url, l := slowRelay(t, db, func(r *khatru.Relay) { r.WriteWait = wait })
	rd := dialSlow(t, url)
	startPage(t, rd, to)
	waitConns(t, l, 0, wait+3*time.Second)
	readToClose(t, rd)
	emptyWAL(t, db, path)
}

func liveHeap() int64 {
	runtime.GC()
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	return int64(m.HeapAlloc)
}

// what a wrap holds in memory once the relay has parsed it, measured
func heldInMemory(t *testing.T, ev nostr.Event) int64 {
	t.Helper()
	b, err := nostr.EventEnvelope{Event: ev}.MarshalJSON()
	if err != nil {
		t.Fatal(err)
	}
	const n = 100
	keep := make([]*nostr.Event, 0, n)
	p := nostr.NewMessageParser()
	before := liveHeap()
	for i := 0; i < n; i++ {
		env, err := p.ParseMessage(string(b))
		if err != nil {
			t.Fatal(err)
		}
		keep = append(keep, &env.(*nostr.EventEnvelope).Event)
	}
	held := (liveHeap() - before) / n
	runtime.KeepAlive(keep)
	return held
}

// waits until nothing more is written to the listeners
func settled(t *testing.T, relay *khatru.Relay) int64 {
	t.Helper()
	end := time.Now().Add(5 * time.Second)
	q := relay.Queued()
	for time.Now().Before(end) {
		time.Sleep(300 * time.Millisecond)
		if n := relay.Queued(); n == q && n > 0 {
			return n
		}
		q = relay.Queued()
	}
	t.Fatal("the queue did not settle")
	return 0
}

// what a listener's queue is held to covers what its wraps hold in memory,
// for wraps heavy in tags and for content the allocator rounds up
func TestQueueCountsWhatWrapsHold(t *testing.T) {
	var relay *khatru.Relay
	url, _ := slowRelay(t, memStore(t), func(r *khatru.Relay) {
		r.WriteWait = time.Minute
		relay = r
	})
	to := addr()
	lis := dialSlow(t, url)
	listen(t, lis, to)
	pub := connect(t, url)
	// enough that a write to the listener is stuck
	for i := 0; i < 5; i++ {
		publishTimed(t, pub, bigWrap(t, to, nostr.Now()-3600))
	}
	for name, mod := range map[string]func(*nostr.Event){
		"tags": func(e *nostr.Event) {
			for len(e.Tags) < maxTags {
				e.Tags = append(e.Tags, nostr.Tag{"", "", "", ""})
			}
		},
		"33 kB": func(e *nostr.Event) { e.Content = strings.Repeat("s", 33<<10) },
	} {
		const n = 20
		before := settled(t, relay)
		var ev nostr.Event
		for i := 0; i < n; i++ {
			ev = wrap(t, to, mod)
			publishTimed(t, pub, ev)
		}
		counted := (relay.Queued() - before) / n
		if held := heldInMemory(t, ev); counted < held {
			t.Errorf("%s: a queued wrap counts %d and holds %d", name, counted, held)
		}
	}
}

// slow listeners together are held to one bound. past it the listener a
// wrap was for is closed, the others keep what they have, and the closed
// one finds its wraps in the store
func TestSlowListenersShareOneBound(t *testing.T) {
	var relay *khatru.Relay
	url, l := slowRelay(t, memStore(t), func(r *khatru.Relay) {
		r.WriteWait = time.Minute
		r.MaxQueuedSize = 1 << 20
		r.MaxQueuedTotal = 500 << 10
		relay = r
	})
	a, b := addr(), addr()
	la, lb := dialSlow(t, url), dialSlow(t, url)
	listen(t, la, a)
	listen(t, lb, b)

	pub := connect(t, url)
	sent := map[string][]string{}
	var worst time.Duration
	for _, to := range []string{a, a, a, a, a, b, b, b, b, b} {
		ev := bigWrap(t, to, nostr.Now()-3600)
		worst = max(worst, publishTimed(t, pub, ev))
		sent[to] = append(sent[to], ev.ID)
		if q := relay.Queued(); q > relay.MaxQueuedTotal {
			t.Fatalf("%d bytes queued, the bound is %d", q, relay.MaxQueuedTotal)
		}
	}
	if worst >= 2*time.Second {
		t.Fatalf("an ok took %v", worst)
	}
	waitConns(t, l, 2, 3*time.Second)
	readToClose(t, lb)
	got := 0
	for got < len(sent[a]) {
		env, err := readNext(la, 5*time.Second)
		if err != nil {
			t.Fatalf("the listener under the bound got %d of %d: %v", got, len(sent[a]), err)
		}
		if _, ok := env.(*nostr.EventEnvelope); ok {
			got++
		}
	}
	checkStored(t, url, b, sent[b])
}

// a page read so slowly that it would outlast its deadline, though no write
// to it runs out of time, is closed at the deadline without an eose, and
// its read of the store ends with it
func TestSlowPageIsClosedAtItsDeadline(t *testing.T) {
	const pageWait = 1500 * time.Millisecond
	db, path := testStore(t)
	to := addr()
	fillPage(t, db, to)
	url, l := slowRelay(t, db, func(r *khatru.Relay) { r.PageWait = pageWait })
	rd := dialSlow(t, url)
	startPage(t, rd, to)
	t0 := time.Now()
	for {
		time.Sleep(250 * time.Millisecond)
		env, err := readNext(rd, 5*time.Second)
		if err != nil {
			break
		}
		if _, ok := env.(*nostr.EventEnvelope); !ok {
			t.Fatalf("got %v, want a wrap or the end", env)
		}
		if time.Since(t0) > pageWait+3*time.Second {
			t.Fatal("the page is still being written")
		}
	}
	waitConns(t, l, 0, 3*time.Second)
	emptyWAL(t, db, path)
}
