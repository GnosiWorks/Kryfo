package main

// what our relay takes. the app sends one kind, gift wraps, each to one
// address, and asks for wraps by address. anything else is not ours, and a
// filter without an address is a scrape of everyone's post box.
// limits count per connection and for everyone together, never per ip:
// behind tor every caller looks the same, and the relay keeps no addresses.

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
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
	// a wrap carries its address and an expiration. every parsed tag costs
	// about 100 bytes of memory while the wrap waits for a listener, and is
	// looked at for every listener, whatever it holds
	maxTags, maxTagLen = 8, 4
	// how far ahead of this box a wrap may be stamped. not tighter, so a
	// phone whose clock runs fast still delivers
	futureSlack = 2 * time.Hour
	// below this much free space the relay stops taking wraps, so a flood
	// cannot fill the disk the other services write to
	minFreeBytes = 2 << 30
	// free space is read again after this much is taken, not only on the
	// poll, so the floor holds however fast wraps come in
	diskRecheck = 32 << 20
	// what a stored wrap costs beyond its content and tags: id, key,
	// signature and the index entries
	rowOverhead = 512
	// what a save writes to the wal beside the wrap: the table's page, one
	// per index and room for a split, 4 kB each. counted toward the
	// recheck, so the floor holds while a long read keeps the wal full
	walPages = 8 << 12
	// a client gets this long to take each frame, then it is closed
	writeWait = 10 * time.Second
	// and this long for a page of stored wraps. the store's read stays open
	// while a page is written, which keeps the wal from being emptied. the
	// app gives up on a page after 90 s
	pageWait = 2 * time.Minute
	// live wraps waiting for one connection, counted as what they hold in
	// memory. a phone on a slow circuit gets about 160 media slices of
	// slack, then it is closed and reads the rest from the store
	maxQueued = 8 << 20
)

// live wraps waiting for all connections together, so slow listeners
// cannot add up past the box's memory. past it, the connection a wrap was
// for is closed
var maxQueuedTotal = int64(envInt("RELAY_MAX_QUEUED_MB", 256)) << 20

// bytes of wraps taken per minute for everyone together, with four minutes
// of it as a burst. a media slice is about 40 kB, so this is far above what
// people send; it sets how fast the disk can fill at all
var storedPerMin = envInt("RELAY_MAX_MB_PER_MIN", 240) << 20

type bucket struct {
	tokens, max, perSec float64
	last                time.Time
}

func newBucket(perSec, burst float64) *bucket {
	return &bucket{tokens: burst, max: burst, perSec: perSec, last: time.Now()}
}

func (b *bucket) take(now time.Time) bool { return b.takeN(now, 1) }

func (b *bucket) takeN(now time.Time, n float64) bool {
	b.tokens += now.Sub(b.last).Seconds() * b.perSec
	if b.tokens > b.max {
		b.tokens = b.max
	}
	b.last = now
	if b.tokens < n {
		return false
	}
	b.tokens -= n
	return true
}

type budget struct{ events, reqs *bucket }

type limits struct {
	mu       sync.Mutex
	conns    map[*khatru.WebSocket]*budget
	maxConns int
	// bytes stored, for everyone together. guarded by mu
	stored  *bucket
	dataDir string
	diskLow atomic.Bool
	// bytes taken since free space was last read
	written atomic.Int64
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

// call it after the store is attached: it wraps the store's queries
func applyLimits(relay *khatru.Relay, dataDir string) *limits {
	l := &limits{
		conns:    map[*khatru.WebSocket]*budget{},
		maxConns: maxConns,
		stored:   newBucket(float64(storedPerMin)/60, float64(storedPerMin)*4),
		dataDir:  dataDir,
	}
	relay.MaxMessageSize = maxMessage
	relay.WriteWait = writeWait
	relay.PageWait = pageWait
	relay.MaxQueuedSize = maxQueued
	relay.MaxQueuedTotal = maxQueuedTotal
	relay.RejectConnection = append(relay.RejectConnection, l.full)
	relay.OnConnect = append(relay.OnConnect, l.connect)
	relay.OnDisconnect = append(relay.OnDisconnect, l.disconnect)
	relay.RejectEvent = append(relay.RejectEvent, l.event)
	relay.OverwriteFilter = append(relay.OverwriteFilter, l.limitZero)
	relay.RejectFilter = append(relay.RejectFilter, l.filter)
	relay.RejectCountFilter = append(relay.RejectCountFilter, l.filter)
	for i, q := range relay.QueryEvents {
		relay.QueryEvents[i] = noDeletionLookups(q)
	}
	if dataDir != "" {
		go l.watchDisk(dataDir)
	}
	return l
}

type queryFunc = func(context.Context, nostr.Filter) (chan *nostr.Event, error)

var errNoDeletion = errors.New("this relay deletes nothing on request")

// khatru looks up a kind 5's targets before any reject hook runs. this relay
// keeps wraps until they expire, so those lookups never reach the store and
// the event then meets l.event like any other. khatru's expiry checks have
// no connection and pass.
func noDeletionLookups(q queryFunc) queryFunc {
	return func(ctx context.Context, f nostr.Filter) (chan *nostr.Event, error) {
		if khatru.IsInternalCall(ctx) && khatru.GetConnection(ctx) != nil {
			return nil, errNoDeletion
		}
		return q(ctx, f)
	}
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

// every event costs one from the connection, taken or refused
func (l *limits) event(ctx context.Context, ev *nostr.Event) (bool, string) {
	if !l.take(ctx, true) {
		return true, "rate-limited: slow down"
	}
	if ev.Kind != wrapKind {
		return true, "blocked: this relay only keeps gift wraps"
	}
	if len(ev.Tags) > maxTags {
		return true, "invalid: too many tags"
	}
	addrs := 0
	for _, t := range ev.Tags {
		if len(t) > maxTagLen {
			return true, "invalid: a tag is too long"
		}
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
	size := storedSize(ev)
	l.mu.Lock()
	ok := l.stored.takeN(time.Now(), float64(size))
	l.mu.Unlock()
	if !ok {
		return true, "rate-limited: the relay is busy, try later"
	}
	l.noteWritten(size + walPages)
	return false, ""
}

// the tags are stored as the json the store writes for them, escapes and
// all
func storedSize(ev *nostr.Event) int {
	tags, _ := json.Marshal(ev.Tags)
	return rowOverhead + len(ev.Content) + len(tags)
}

func (l *limits) noteWritten(n int) {
	if l.dataDir == "" || l.written.Add(int64(n)) < diskRecheck {
		return
	}
	l.written.Store(0)
	l.diskLow.Store(freeBytes(l.dataDir) < minFreeBytes)
}

// khatru answers a limit 0 req with a live subscription and never runs
// RejectFilter for it, so the same check runs here. a refused one drops its
// limit 0 and meets RejectFilter like any other req.
func (l *limits) limitZero(ctx context.Context, f *nostr.Filter) {
	if !f.LimitZero {
		return
	}
	if filterOK(*f) && l.take(ctx, false) {
		return
	}
	f.LimitZero = false
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

// by id alone (the liveness probe of older builds), or wraps to named
// addresses
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
		l.written.Store(0)
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
