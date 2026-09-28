package main

// what our relay takes. the app sends one kind, gift wraps, each to one
// address, and asks for wraps by address. anything else is not ours, and a
// filter without an address is a scrape of everyone's post box.
// limits count per connection and for everyone together, never per ip:
// behind tor every caller looks the same, and the relay keeps no addresses.

import (
	"context"
	"encoding/hex"
	"net/http"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

const (
	wrapKind = 1059
	// nip-44 caps a wrap's content near 90 kB
	maxMessage = 256 << 10
	// a media send is a burst of slices, then quiet
	eventsPerSec, eventBurst = 10, 500
	// one live subscription per socket, catch-up pages one after another
	reqsPerSec, reqBurst = 2, 100
	maxIDs, maxAddrs     = 20, 10
	// wide, so a phone whose clock runs fast still delivers. it only keeps a
	// wrap from outliving the sweep
	futureSlack = 48 * time.Hour
	// below this much free space the relay stops taking wraps, so a flood
	// cannot fill the disk the other services write to
	minFreeBytes = 2 << 30
)

type bucket struct {
	tokens, max, perSec float64
	last                time.Time
}

func newBucket(perSec, burst float64) *bucket {
	return &bucket{tokens: burst, max: burst, perSec: perSec, last: time.Now()}
}

func (b *bucket) take(now time.Time) bool {
	b.tokens += now.Sub(b.last).Seconds() * b.perSec
	if b.tokens > b.max {
		b.tokens = b.max
	}
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

type budget struct{ events, reqs *bucket }

type limits struct {
	mu       sync.Mutex
	conns    map[*khatru.WebSocket]*budget
	maxConns int
	diskLow  atomic.Bool
}

// sockets for everyone together. a phone holds one per contact address,
// so this is sized by the box's memory, not by a count of people
var maxConns = envInt("RELAY_MAX_CONNS", 20000)

func envInt(k string, d int) int {
	if n, err := strconv.Atoi(os.Getenv(k)); err == nil && n > 0 {
		return n
	}
	return d
}

func applyLimits(relay *khatru.Relay, dataDir string) *limits {
	l := &limits{conns: map[*khatru.WebSocket]*budget{}, maxConns: maxConns}
	relay.MaxMessageSize = maxMessage
	relay.RejectConnection = append(relay.RejectConnection, l.full)
	relay.OnConnect = append(relay.OnConnect, l.connect)
	relay.OnDisconnect = append(relay.OnDisconnect, l.disconnect)
	relay.RejectEvent = append(relay.RejectEvent, l.event)
	relay.RejectFilter = append(relay.RejectFilter, l.filter)
	relay.RejectCountFilter = append(relay.RejectCountFilter, l.filter)
	if dataDir != "" {
		go l.watchDisk(dataDir)
	}
	return l
}

func (l *limits) full(*http.Request) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.conns) >= l.maxConns
}

func (l *limits) connect(ctx context.Context) {
	ws := khatru.GetConnection(ctx)
	if ws == nil {
		return
	}
	l.mu.Lock()
	l.conns[ws] = &budget{newBucket(eventsPerSec, eventBurst), newBucket(reqsPerSec, reqBurst)}
	l.mu.Unlock()
}

func (l *limits) disconnect(ctx context.Context) {
	ws := khatru.GetConnection(ctx)
	l.mu.Lock()
	delete(l.conns, ws)
	l.mu.Unlock()
}

// takes one from the connection's events or reqs. a connection the relay
// did not see open gets nothing.
func (l *limits) take(ctx context.Context, events bool) bool {
	ws := khatru.GetConnection(ctx)
	l.mu.Lock()
	defer l.mu.Unlock()
	b := l.conns[ws]
	if b == nil {
		return false
	}
	if events {
		return b.events.take(time.Now())
	}
	return b.reqs.take(time.Now())
}

func (l *limits) event(ctx context.Context, ev *nostr.Event) (bool, string) {
	if ev.Kind != wrapKind {
		return true, "blocked: this relay only keeps gift wraps"
	}
	addrs := 0
	for _, t := range ev.Tags {
		if len(t) > 0 && t[0] == "p" {
			if len(t) < 2 || !isKey(t[1]) {
				return true, "invalid: bad p tag"
			}
			addrs++
		}
	}
	if addrs != 1 {
		return true, "invalid: a wrap goes to one address"
	}
	now := time.Now()
	if ev.CreatedAt.Time().After(now.Add(futureSlack)) {
		return true, "invalid: created_at is in the future"
	}
	if ev.CreatedAt.Time().Before(now.Add(-wrapTTL)) {
		return true, "invalid: older than this relay keeps"
	}
	if l.diskLow.Load() {
		return true, "error: the relay is full, try later"
	}
	if !l.take(ctx, true) {
		return true, "rate-limited: slow down"
	}
	return false, ""
}

func (l *limits) filter(ctx context.Context, f nostr.Filter) (bool, string) {
	if !l.take(ctx, false) {
		return true, "rate-limited: slow down"
	}
	if !filterOK(f) {
		return true, "blocked: ask for wraps by address"
	}
	return false, ""
}

// by id alone (the app's liveness probe), or wraps to named addresses
func filterOK(f nostr.Filter) bool {
	if f.Search != "" || len(f.Authors) > 0 {
		return false
	}
	if len(f.IDs) > 0 {
		if len(f.IDs) > maxIDs || len(f.Kinds) > 0 || len(f.Tags) > 0 {
			return false
		}
		for _, id := range f.IDs {
			if !isKey(id) {
				return false
			}
		}
		return true
	}
	if len(f.Kinds) != 1 || f.Kinds[0] != wrapKind || len(f.Tags) != 1 {
		return false
	}
	ps, ok := f.Tags["p"]
	if !ok || len(ps) == 0 || len(ps) > maxAddrs {
		return false
	}
	for _, p := range ps {
		if !isKey(p) {
			return false
		}
	}
	return true
}

func isKey(s string) bool {
	if len(s) != 64 {
		return false
	}
	_, err := hex.DecodeString(s)
	return err == nil
}

func (l *limits) watchDisk(dir string) {
	for {
		l.diskLow.Store(freeBytes(dir) < minFreeBytes)
		time.Sleep(30 * time.Second)
	}
}

// free space where the database lives. when it cannot be read the relay
// keeps taking wraps: a broken check must not stop delivery.
func freeBytes(dir string) uint64 {
	var st syscall.Statfs_t
	if err := syscall.Statfs(dir, &st); err != nil {
		return ^uint64(0)
	}
	return st.Bavail * uint64(st.Bsize)
}
