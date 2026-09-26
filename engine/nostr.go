// SPDX-License-Identifier: GPL-3.0-or-later
// the nostr layer: store-and-forward messaging through public relays. dart
// hands over libsignal ciphertext, the engine wraps it per conversation and
// publishes to every relay, and what arrives is queued for dart to poll.
// relays only ever see per-conversation keys, never an identity.

package main

import "C"

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"fiatjaf.com/nostr"
	"github.com/halo/engine/catchup"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"golang.org/x/crypto/hkdf"
)

var (
	nostrMu      sync.Mutex
	nostrRelays  []string
	nostrSubs    = map[string]context.CancelFunc{}
	nostrInbox   []string
	nostrSentIDs = map[string]bool{}
)

// a kick makes every relay runner drop its socket and reconnect now, with
// the since window, instead of waiting out the quiet timer. the periodic
// job uses it: after a night asleep the sockets are dead and nothing knows
// yet, and a job window is too short to wait for the idle timer.
var (
	kickMu sync.Mutex
	kickCh = make(chan struct{})
)

// the newest relay event: when the sender's relay stamped it and when it
// reached this phone. the difference is how long it waited out there,
// which is what tells a late message from a lost one.
var (
	lastEvMu   sync.Mutex
	lastEvAt   int64
	lastEvRecv int64
)

// a context for publishes that outlive the caller: thirty seconds of its
// own, cancelled by the last publisher out. made here so the analyser sees
// a plain pair rather than a cancel it cannot follow into the goroutines.
func detachedPublishCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 30*time.Second)
}

func kickChan() chan struct{} {
	kickMu.Lock()
	defer kickMu.Unlock()
	return kickCh
}

// sleep that a kick ends early. true when it was kicked. a runner waiting
// out a failed dial still hears the job's kick this way.
func sleepOrKick(d time.Duration) bool {
	select {
	case <-time.After(d):
		return false
	case <-kickChan():
		return true
	}
}

// a req that cannot match anything. the relay answers eose and nothing
// else, which is the cheapest proof that this circuit still carries data,
// and unlike cycling the subscription it does not refetch a single stored
// event. the library dispatches a fake eose after 7s when a relay stays
// silent, which would make every probe pass, so that is disabled here:
// only the relay's own eose counts.
func relayResponds(ctx context.Context, r *nostr.Relay) bool {
	pctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	sub, err := r.Subscribe(pctx, nostr.Filter{
		IDs:   []nostr.ID{{}},
		Limit: 1,
	}, nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
	if err != nil {
		return false
	}
	defer sub.Unsub()
	select {
	case <-sub.EndOfStoredEvents:
		return true
	case <-pctx.Done():
		return false
	}
}

// a page is a hundred because that is what our relay hands out. two hundred
// pages is twenty thousand wraps, more than fourteen days of retention will
// hold for one address, so the ceiling is a guard and not a limit anyone
// should meet.
const (
	catchupPage     = 100
	catchupMaxPages = 200
)

// connections still fetching what they missed, and how many have begun
// since the process started. a check-in waits for the first to reach zero
// after the second has moved.
var (
	catchupActive  int32
	catchupStarted int64
)

// "active started", two numbers
//
//export HaloCatchupState
func HaloCatchupState() *C.char {
	return C.CString(fmt.Sprintf("%d %d",
		atomic.LoadInt32(&catchupActive), atomic.LoadInt64(&catchupStarted)))
}

// how long one relay may spend catching up before the check-in stops waiting
// for it. paging back is up to catchupMaxPages requests at up to 45s each, so
// one slow relay could otherwise hold tor awake for the whole window.
//
// past this the relay's backfill is cancelled and it stops counting as active.
// its live subscription stays up, and the next connect asks again from the
// same anchor, so nothing is lost: it arrives later instead of holding the
// phone awake now.
const catchupCap = 30 * time.Second

// a relay dropped three check-ins running gets one longer window. a backlog
// deeper than the cap is walked in pieces and does finish eventually, but a
// relay that keeps hitting the cap is either slow or holding a lot, and
// giving it one proper turn is cheaper than dripping at it for an hour.
const catchupLongCap = 90 * time.Second
const catchupDropsBeforeLong = 3

// what one subscription's last catch-up cost. seconds and a flag, no content
// and no counts: enough to see who holds a check-in up without a debug build.
type catchupRun struct {
	Ms      int  `json:"ms"`
	Dropped bool `json:"dropped"`
	Long    bool `json:"long"`
	// what the walk covered, for the transport screen: pages fetched past
	// the first window, events seen, and how long the connect before it
	// took, so a slow catch-up can be explained without a debug build.
	Pages     int `json:"pages"`
	Events    int `json:"events"`
	ConnectMs int `json:"connect_ms"`
	// when it ended. the transport line only weighs the latest round, so a
	// contact deleted weeks ago does not go on being the slowest.
	At time.Time `json:"-"`
}

// catch-up is recorded per subscription, never per relay: a relay carries one
// subscription per contact, each walking its own backlog with its own start
// time, drop count and place. the key is the relay url and the
// subscription's address.
func catchupKey(u, rcvPk string) string { return u + " " + rcvPk }

func relayOfKey(k string) string {
	if i := strings.IndexByte(k, ' '); i >= 0 {
		return k[:i]
	}
	return k
}

var (
	catchupMu    sync.Mutex
	catchupLast  = map[string]catchupRun{}
	catchupFrom  = map[string]time.Time{}
	catchupDrops = map[string]int{}
	catchupLong  = map[string]bool{}
	// where each relay's backlog walk got to. a relay holding more than one
	// window can page keeps its place here, so the next check-in carries on
	// instead of re-walking the same pages and never reaching the tail.
	catchupMarks = map[string]catchup.Mark{}
	// the walk that is running now, folded into catchupLast when it ends
	catchupPend = map[string]catchupRun{}
	connectLast = map[string]int{}
	connectAt   = map[string]time.Time{}
	dialAt      = map[string]time.Time{}
)

func noteRelayConnect(u, key string, ms int) {
	catchupMu.Lock()
	connectLast[key] = ms
	connectAt[u] = time.Now()
	catchupMu.Unlock()
}

func noteRelayDial(u string) {
	catchupMu.Lock()
	dialAt[u] = time.Now()
	catchupMu.Unlock()
}

// when each relay was last dialled, whatever came of it.
func relayDialledAt(u string) time.Time {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	return dialAt[u]
}

// when each relay last connected. the sleep/wake test reads it to tell a
// runner that woke from one that is still asleep.
func relayConnectedAt(u string) time.Time {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	return connectAt[u]
}

func noteCatchupPages(key string, pages, events int) {
	catchupMu.Lock()
	catchupPend[key] = catchupRun{Pages: pages, Events: events}
	catchupMu.Unlock()
}

// a round of catch-ups: everything that ended within this of the newest one
// on the same relay. a check-in's subscriptions all catch up inside its
// window; anything older is from a round before.
const catchupRound = 5 * time.Minute

// the slowest subscription on a relay in its latest round (a dropped one
// ranks above any that finished), and how many there were, and how many of
// them were dropped. this is what the transport line shows for the relay.
// catchupMu must be held.
func slowestCatchupLocked(u string) (slow catchupRun, ok bool, subs, dropped int) {
	var newest time.Time
	for k, r := range catchupLast {
		if relayOfKey(k) == u && r.At.After(newest) {
			newest = r.At
		}
	}
	for k, r := range catchupLast {
		if relayOfKey(k) != u || newest.Sub(r.At) > catchupRound {
			continue
		}
		subs++
		if r.Dropped {
			dropped++
		}
		if !ok || (r.Dropped && !slow.Dropped) || (r.Dropped == slow.Dropped && r.Ms > slow.Ms) {
			slow, ok = r, true
		}
	}
	return
}

// what the slowest catch-up on a relay covered: connect ms, pages, events,
// and how many subscriptions there were and how many were dropped.
func catchupDetailOf(u string) (connectMs, pages, events, subs, dropped int) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	r, _, n, d := slowestCatchupLocked(u)
	return r.ConnectMs, r.Pages, r.Events, n, d
}

func catchupMarkOf(key string) catchup.Mark {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	return catchupMarks[key]
}

func setCatchupMark(key string, m catchup.Mark) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	if m.Started() {
		catchupMarks[key] = m
	} else {
		delete(catchupMarks, key)
	}
}

// how long this subscription gets this time round.
func catchupCapFor(key string) (time.Duration, bool) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	if catchupDrops[key] >= catchupDropsBeforeLong {
		// one longer turn, then back to the usual
		catchupDrops[key] = 0
		catchupLong[key] = true
		return catchupLongCap, true
	}
	catchupLong[key] = false
	return catchupCap, false
}

func noteCatchupStart(key string) {
	catchupMu.Lock()
	catchupFrom[key] = time.Now()
	catchupMu.Unlock()
}

func noteCatchupDone(key string, dropped bool) {
	u := relayOfKey(key)
	catchupMu.Lock()
	ms := 0
	if t, ok := catchupFrom[key]; ok {
		ms = int(time.Since(t).Milliseconds())
		delete(catchupFrom, key)
	}
	long := catchupLong[key]
	if dropped {
		catchupDrops[key]++
	} else {
		catchupDrops[key] = 0
	}
	drops := catchupDrops[key]
	pend := catchupPend[key]
	delete(catchupPend, key)
	catchupLast[key] = catchupRun{Ms: ms, Dropped: dropped, Long: long,
		Pages: pend.Pages, Events: pend.Events, ConnectMs: connectLast[key], At: time.Now()}
	catchupMu.Unlock()
	if dropped {
		log.Printf("nostr: %s still catching up after %dms - dropped for this check-in (%d in a row)",
			u, ms, drops)
	}
}

// the last catch-up for this relay: milliseconds, whether it was dropped, and
// whether there has been one at all.
func catchupOf(u string) (int, bool, bool, bool) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	r, ok, _, _ := slowestCatchupLocked(u)
	return r.Ms, r.Dropped, r.Long, ok
}

// one page of stored events, closed again as soon as the relay says that
// was all. a relay that never says so costs the page its 45 seconds and the
// catch-up its anchor, and the next connect asks again.
func relayPage(ctx context.Context, r *nostr.Relay, rcvPk string, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
	pctx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()
	sub, err := r.Subscribe(pctx, nostr.Filter{
		Kinds: []nostr.Kind{1059},
		Tags:  nostr.TagMap{"p": []string{rcvPk}},
		Since: since,
		Until: until,
		Limit: limit,
	}, nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
	if err != nil {
		return nil, err
	}
	defer sub.Unsub()
	var out []nostr.Event
	for {
		select {
		case ev, alive := <-sub.Events:
			if !alive {
				return nil, errors.New("relay closed the page")
			}
			out = append(out, ev)
		case <-sub.EndOfStoredEvents:
			return out, nil
		case <-pctx.Done():
			return nil, pctx.Err()
		}
	}
}

// relay health. a relay that will not answer still costs a full tor circuit
// on every attempt, and with one subscribe goroutine per relay per contact
// that adds up fast. count consecutive failures, bench the relay for a
// doubling stretch, forget the whole history on the first success.
var (
	relayHealthMu sync.Mutex
	relayFails    = map[string]int{}
	relayCoolTill = map[string]time.Time{}
)

// a couple of misses is just a bad circuit, not a dead relay.
const relayFailGrace = 3

// our own relay carries the traffic, so it is retried far more eagerly than
// the public ones: seconds apart rather than minutes. it is still a ceiling
// and not an exemption.
const ownRelayCeiling = 20 * time.Second

func relayBackoff(n int) time.Duration {
	if n <= relayFailGrace {
		return 0
	}
	shift := n - relayFailGrace - 1
	if shift > 6 {
		return 5 * time.Minute
	}
	d := 10 * time.Second << uint(shift)
	if d > 5*time.Minute {
		d = 5 * time.Minute
	}
	return d
}

func relayCold(u string) bool {
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	till, ok := relayCoolTill[u]
	return ok && time.Now().Before(till)
}

func relayFailed(u string) {
	// only tor's warmup can make a connect failure meaningless
	if modeNeedsTor() && !torReadyNow() {
		return
	}
	if modeNeedsTor() {
		routeNoteFail(u)
	}
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	relayFails[u]++
	if d := relayBackoff(relayFails[u]); d > 0 {
		relayCoolTill[u] = time.Now().Add(d)
		log.Printf("nostr: benching %s for %s, %d failures in a row", u, d, relayFails[u])
	}
}

// forget every bench. a relay benched while the route under it was dead did
// nothing wrong, and holding it out for five more minutes after the route is
// rebuilt is five more minutes of a message sitting in the outbox.
func relayClearBenches() {
	relayHealthMu.Lock()
	for k := range relayFails {
		delete(relayFails, k)
	}
	for k := range relayCoolTill {
		delete(relayCoolTill, k)
	}
	relayHealthMu.Unlock()
}

// end every runner's backoff now, so it dials again instead of waiting out a
// sleep that was sized for the route that is gone.
func kickRelays() {
	kickMu.Lock()
	close(kickCh)
	kickCh = make(chan struct{})
	kickMu.Unlock()
}

func relayOK(u string) {
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	if relayFails[u] != 0 {
		delete(relayFails, u)
		delete(relayCoolTill, u)
	}
}

// how long to wait before the next attempt, never shorter than the caller's
// own cadence. our own relay backs off too, but to a much lower ceiling:
// exempt, every subscription would redial a failing relay every few seconds,
// around the clock, on whatever connection the phone has.
func relayRetryAfter(u string, base time.Duration, own bool) time.Duration {
	relayHealthMu.Lock()
	n := relayFails[u]
	relayHealthMu.Unlock()
	d := relayBackoff(n)
	if own && d > ownRelayCeiling {
		d = ownRelayCeiling
	}
	if d > base {
		return d
	}
	return base
}

func nostrConversationID(a, b [32]byte) []byte {
	first, second := a[:], b[:]
	if string(first) > string(second) {
		first, second = second, first
	}
	h := sha256.New()
	h.Write(first)
	h.Write(second)
	return h.Sum(nil)[:16]
}

func nostrHkdf(secret, salt, info []byte, length int) []byte {
	r := hkdf.New(sha256.New, secret, salt, info)
	out := make([]byte, length)
	r.Read(out)
	return out
}

// the client torNostrClient hands out, dialling through tor's socks proxy
var (
	cachedNostrClient   *http.Client
	cachedNostrClientMu sync.Mutex
)

// called from shutdown and from every bounce. the cached client pins the
// socks address it was built on, and a bounce can move it.
func nostrResetClient() {
	cachedNostrClientMu.Lock()
	cachedNostrClient = nil
	cachedNostrClientMu.Unlock()
	// the preview client dials the tor it was built on. after a restart
	// that tor is gone, and a client kept from before would dial a dead
	// port for the rest of the process
	torOnlyMu.Lock()
	torOnlyClient = nil
	torOnlyMu.Unlock()
	dropSocksAddr()
}

// how long a relay's websocket may take to open. the relay library gives
// seven seconds when the context has no deadline of its own, and an onion
// relay takes longer than that whenever tor has to find it again: the
// descriptor, an introduction and a rendezvous, six hops, then tls. only the
// handshake is bounded by this; the connection lives on the relay's own
// context.
func relayDialCtx(parent context.Context, u string) (context.Context, context.CancelFunc) {
	d := 20 * time.Second
	if strings.Contains(u, ".onion") {
		d = 45 * time.Second
	}
	return context.WithTimeout(parent, d)
}

// nothing in here talks to tor: the socks address is pinned or remembered,
// and bine builds a plain socks5 dialer from it. so the mutex is held for
// microseconds, and a resume or a reconnect that resets the client never
// waits on a relay runner (see control_events.go).
func torNostrClient() (*http.Client, error) {
	cachedNostrClientMu.Lock()
	defer cachedNostrClientMu.Unlock()
	if cachedNostrClient != nil {
		return cachedNostrClient, nil
	}
	// balanced and fast do not go through tor at all, so there is nothing to
	// wait for and no dialer to build.
	if !modeNeedsTor() {
		cachedNostrClient = directNostrClient()
		log.Printf("nostr: direct client (%s mode, not via tor)", currentMode())
		return cachedNostrClient, nil
	}
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil {
		return nil, fmt.Errorf("tor not started")
	}
	d, err := torDialer(context.Background(), t)
	if err != nil {
		return nil, fmt.Errorf("tor dialer: %v", err)
	}
	cachedNostrClient = &http.Client{
		Transport: &http.Transport{
			DialContext:           d.DialContext,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 10 * time.Second,
		},
		Timeout: 60 * time.Second,
	}
	log.Printf("nostr: client built over tor's socks listener")
	return cachedNostrClient, nil
}

func nostrPublishMulti(ctx context.Context, ev nostr.Event) (ok int) {
	nostrMu.Lock()
	all := append([]string(nil), nostrRelays...)
	nostrMu.Unlock()

	// index 0 is our own relay and is never benched: it carries the traffic
	// and the tor watchdog already covers it going away.
	urls := make([]string, 0, len(all))
	for i, u := range all {
		if i == 0 || !relayCold(u) {
			urls = append(urls, u)
		}
	}
	if len(urls) == 0 {
		urls = all
	}

	// publishes run on a context detached from the caller's, which dies once
	// we return on the first success. the slower relays keep landing for
	// redundancy.
	bg, bgCancel := detachedPublishCtx()
	if len(urls) == 0 {
		bgCancel()
		return 0
	}

	result := make(chan bool, len(urls))
	var pending int32 = int32(len(urls))
	for _, url := range urls {
		go func(u string) {
			// last publisher out turns off the lights (frees bg).
			defer func() {
				if atomic.AddInt32(&pending, -1) == 0 {
					bgCancel()
				}
			}()
			client, err := torNostrClient()
			if err != nil {
				log.Printf("nostr: tor not ready, skipping publish to %s: %v", u, err)
				result <- false
				return
			}
			r := nostr.NewRelay(bg, u, nostr.RelayOptions{})
			dctx, dcancel := relayDialCtx(bg, u)
			err = r.ConnectWithClient(dctx, client)
			dcancel()
			if err != nil {
				log.Printf("nostr: connect %s: %v", u, err)
				relayFailed(u)
				result <- false
				return
			}
			defer r.Close()
			if err := r.Publish(bg, ev); err != nil {
				log.Printf("nostr: publish %s: %v", u, err)
				relayFailed(u)
				result <- false
				return
			}
			relayOK(u)
			noteSend()
			log.Printf("nostr: published to %s ok", u)
			result <- true
		}(url)
	}

	// return the instant one relay accepts; the rest keep going on bg for
	// redundancy. if the caller's ctx dies first, we still leave the
	// background publishes running and report what landed so far.
	accepted := 0
	for i := 0; i < len(urls); i++ {
		select {
		case r := <-result:
			if r {
				accepted++
				if accepted >= 1 {
					return accepted
				}
			}
		case <-ctx.Done():
			log.Printf("nostr: caller ctx done, %d relays in ok so far (rest continue in bg)", accepted)
			return accepted
		}
	}
	return accepted
}

// run a long-lived subscription against all configured relays for events from `pk`.
// dedupes across relays. exits when ctx is cancelled.
func nostrSubscribeRunner(ctx context.Context, peerXPubHex string, peerArr [32]byte, rcvPk string) {
	nostrSubscribeRunnerMode(ctx, peerXPubHex, peerArr, rcvPk, false, 0)
}

func nostrSubscribeRunnerMode(ctx context.Context, peerXPubHex string, peerArr [32]byte, rcvPk string, fc bool, fcCounter int) {
	tag := peerXPubHex
	unwrap := func(gw nostr2.Event) (string, error) { return nip17Unwrap(peerArr, gw) }
	if fc {
		tag = "firstcontact"
		unwrap = func(gw nostr2.Event) (string, error) {
			content, _, err := nip17UnwrapFirstContact(fcCounter, gw)
			return content, err
		}
	}
	nostrSubscribeRunnerFn(ctx, tag, rcvPk, unwrap)
}

// the general runner: one receive address, one way to open what lands on
// it, one tag the inbox line carries so dart knows who it was for.
func nostrSubscribeRunnerFn(ctx context.Context, tag string, rcvPk string, unwrap func(nostr2.Event) (string, error)) {
	nostrMu.Lock()
	urls := append([]string(nil), nostrRelays...)
	nostrMu.Unlock()

	seen := map[string]bool{}
	var seenMu sync.Mutex

	// remember ids and the high-water timestamp on disk so a relaunch picks
	// up where it left off rather than refetch the whole window.
	seenPath := ""
	lastPath := ""
	var lastSaved int64
	if savedDataDir != "" {
		tag := rcvPk
		if len(tag) > 16 {
			tag = tag[:16]
		}
		seenPath = savedDataDir + "/nostr_seen_" + tag
		lastPath = savedDataDir + "/nostr_last_" + tag
		if b, err := os.ReadFile(seenPath); err == nil {
			lines := strings.Split(string(b), "\n")
			// keep the file from growing forever; old ids age out of the
			// relay window anyway
			if len(lines) > 4000 {
				lines = lines[len(lines)-2000:]
				os.WriteFile(seenPath, []byte(strings.Join(lines, "\n")), 0600)
			}
			for _, line := range lines {
				if line != "" {
					seen[line] = true
				}
			}
		}
		if b, err := os.ReadFile(lastPath); err == nil {
			if v, perr := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64); perr == nil {
				lastSaved = v
			}
		}
	}
	saveSeen := func(id string) {
		if seenPath == "" {
			return
		}
		f, err := os.OpenFile(seenPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
		if err != nil {
			return
		}
		f.WriteString(id + "\n")
		f.Close()
	}
	// runners share the anchor and read it back, or a relay that never sees
	// a new event stays pinned to the launch window for the whole process.
	loadLast := func() int64 {
		seenMu.Lock()
		defer seenMu.Unlock()
		return lastSaved
	}

	saveLast := func(ts int64) {
		seenMu.Lock()
		stale := ts <= lastSaved
		if !stale {
			lastSaved = ts
		}
		seenMu.Unlock()
		if stale || lastPath == "" {
			return
		}
		os.WriteFile(lastPath, []byte(strconv.FormatInt(ts, 10)), 0600)
	}

	// true when the event had not been seen before, which is what the
	// catch-up counts to know it is still finding things
	dispatch := func(ev nostr.Event) bool {
		id := ev.ID.Hex()
		nostrMu.Lock()
		mine := nostrSentIDs[id]
		nostrMu.Unlock()
		if mine {
			return false
		}
		seenMu.Lock()
		dup := seen[id]
		seen[id] = true
		seenMu.Unlock()
		if dup {
			return false
		}
		lastEvMu.Lock()
		lastEvAt = int64(ev.CreatedAt)
		lastEvRecv = time.Now().Unix()
		lastEvMu.Unlock()
		saveSeen(id)
		var gw nostr2.Event
		if err := easyjson.Unmarshal([]byte(ev.String()), &gw); err != nil {
			log.Printf("nostr: wrap parse failed: %v", err)
			return true
		}
		content, err := unwrap(gw)
		if err != nil {
			log.Printf("nostr: unwrap dropped one: %v", err)
			return true
		}
		noteRecv()
		nostrMu.Lock()
		nostrInbox = append(nostrInbox, tag+"|"+content)
		nostrMu.Unlock()
		short := tag
		if len(short) > 12 {
			short = short[:12]
		}
		log.Printf("nostr: received event %s for %s...", id[:12], short)
		return true
	}

	for i, url := range urls {
		// first relay is our own: it carries the traffic, heal it hard
		own := i == 0
		go func(u string) {
			// this subscription's catch-up record, apart from every other
			// contact's on the same relay
			ck := catchupKey(u, rcvPk)
			last := nostr.Timestamp(lastSaved)
			retry := 10 * time.Second
			rejoin := 5 * time.Second
			deaf := 4 * time.Minute
			kicked := false
			// the last moment this runner knew its subscription was alive: a
			// successful subscribe, an event, a probe answered. the gap from
			// there decides how much the next subscribe asks for. wall clock
			// on purpose: go's monotonic clock stops while the phone is
			// asleep, and a night asleep is exactly the gap this has to see.
			var lastAlive time.Time
			markAlive := func() { lastAlive = time.Now().Round(0) }
			if own {
				retry = 3 * time.Second
				rejoin = 2 * time.Second
				deaf = 75 * time.Second
			}
			for {
				select {
				case <-ctx.Done():
					return
				default:
				}
				// tor is down because it was asked to be. do not poll for it
				// every ten seconds: the kick that follows a resume wakes this.
				if modeNeedsTor() && torIsPaused() {
					sleepOrKick(15 * time.Minute)
					continue
				}
				client, err := torNostrClient()
				if err != nil {
					wait := 10 * time.Second
					log.Printf("nostr: tor not ready, retry subscribe to %s in %s: %v", u, wait, err)
					// a hung dialer that nothing rescues leaves the phone deaf
					// to every relay, which looks like features being broken
					// rather than a transport that died.
					if modeNeedsTor() && relaysAllDead() {
						log.Println("nostr: no relay has connected in 3 minutes, rebuilding tor")
						// arm first: the other relay goroutines are in this
						// same loop and would otherwise each fire one.
						armRelayWatch()
						atomic.StoreInt64(&lastTorRestart, 0)
						go reconnectTor()
						sleepOrKick(30 * time.Second)
						continue
					}
					sleepOrKick(wait)
					continue
				}
				r := nostr.NewRelay(ctx, u, nostr.RelayOptions{})
				dialAt := time.Now()
				noteRelayDial(u)
				dctx, dcancel := relayDialCtx(ctx, u)
				err = r.ConnectWithClient(dctx, client)
				dcancel()
				if err != nil {
					log.Printf("nostr: subscribe-connect %s: %v", u, err)
					relayFailed(u)
					sleepOrKick(relayRetryAfter(u, retry, own))
					continue
				}
				noteRelayConnect(u, ck, int(time.Since(dialAt).Milliseconds()))
				// a relay answered. this is the one fact the watchdog trusts.
				noteRelayConnected()
				// the anchor is what was saved, by this runner or another. it
				// is only saved once a catch-up has run to its end, so a
				// connection that dropped half way asks for the same window
				// again and not for the little that came after.
				last = nostr.Timestamp(loadLast())
				// a wrap can be a 16k base64 slice of a video, so a reconnect
				// seconds after the last one asks for twenty, not a hundred. a
				// cold start, or a gap long enough to have missed a
				// conversation, still asks for the lot.
				limit := 100
				if !lastAlive.IsZero() &&
					time.Now().Round(0).Sub(lastAlive) < 5*time.Minute {
					limit = 20
				}
				f := nostr.Filter{
					Kinds: []nostr.Kind{1059},
					Tags:  nostr.TagMap{"p": []string{rcvPk}},
					Limit: limit,
				}
				// after the first connect only ask for what we missed
				if last > 0 {
					// wraps carry timestamps jittered up to ~10h into the past,
					// so pull the window back or a late-stamped fresh wrap gets
					// filtered out. the dedup layers eat the refetch.
					since := last - nostr.Timestamp(12*3600)
					if since > 0 {
						f.Since = since
					}
				}
				// the library fakes an eose after 7s of silence. a hundred
				// slices over tor take longer than that, and a fake one would
				// end the count below before the relay was done.
				sub, err := r.Subscribe(ctx, f, nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
				if err != nil {
					log.Printf("nostr: subscribe %s: %v", u, err)
					r.Close()
					relayFailed(u)
					sleepOrKick(relayRetryAfter(u, retry, own))
					continue
				}
				// our own relay's successes clear its failure count too
				relayOK(u)
				markAlive()
				log.Printf("nostr: listening on %s for addr %s...", u, rcvPk[:12])
				// a dead tor circuit leaves the websocket open but mute: no
				// error, no channel close. quiet too long gets a probe, and a
				// reconnect if nothing answers; the since window refetches
				// whatever we missed.
				idle := time.NewTimer(deaf)
				// stored events come newest first and stop at the relay's cap.
				// until the relay says that was all, count them and remember
				// the oldest: a full answer means there may be more behind it.
				// the anchor is held back until that has been fetched too.
				cctx, ccancel := context.WithCancel(ctx)
				// counted while this connection is still fetching what it
				// missed, so a check-in knows when it may stop tor again
				atomic.AddInt32(&catchupActive, 1)
				atomic.AddInt64(&catchupStarted, 1)
				noteCatchupStart(ck)
				var settleOnce sync.Once
				var capT *time.Timer
				settled := func() {
					settleOnce.Do(func() {
						if capT != nil {
							capT.Stop()
						}
						atomic.AddInt32(&catchupActive, -1)
						noteCatchupDone(ck, false)
					})
				}
				// nobody waits on one relay for longer than this. whichever
				// of the two fires first wins the Once, so a relay is either
				// finished or dropped, never both.
				thisCap, longTurn := catchupCapFor(ck)
				if longTurn {
					log.Printf("nostr: %s dropped %d check-ins running, giving it %s this time",
						u, catchupDropsBeforeLong, catchupLongCap)
				}
				capT = time.AfterFunc(thisCap, func() {
					settleOnce.Do(func() {
						atomic.AddInt32(&catchupActive, -1)
						noteCatchupDone(ck, true)
						ccancel()
					})
				})
				eose := sub.EndOfStoredEvents
				stored := 0
				var oldest nostr.Timestamp
				var caughtUp int32
				var pending int64
				since := f.Since
				for {
					select {
					case ev, alive := <-sub.Events:
						if !alive {
							idle.Stop()
							r.Close()
							goto reconnect
						}
						markAlive()
						if ev.ID.Hex() != "" {
							if eose != nil {
								stored++
								if oldest == 0 || ev.CreatedAt < oldest {
									oldest = ev.CreatedAt
								}
							}
							if ev.CreatedAt > last {
								last = ev.CreatedAt
							}
							if atomic.LoadInt32(&caughtUp) == 1 {
								saveLast(int64(last))
							} else if int64(ev.CreatedAt) > atomic.LoadInt64(&pending) {
								atomic.StoreInt64(&pending, int64(ev.CreatedAt))
							}
							dispatch(ev)
						}
						if !idle.Stop() {
							select {
							case <-idle.C:
							default:
							}
						}
						idle.Reset(deaf)
					case <-eose:
						eose = nil
						if stored < limit || oldest == 0 {
							atomic.StoreInt32(&caughtUp, 1)
							saveLast(atomic.LoadInt64(&pending))
							noteCatchupPages(ck, 0, stored)
							settled()
							continue
						}
						log.Printf("nostr: %s answered with a full %d, paging back", u, stored)
						go func(from nostr.Timestamp) {
							defer settled()
							// carries this relay's place from last time, so a
							// backlog deeper than one window is walked in
							// pieces instead of re-walked from the top and
							// never finished.
							res, mark := catchup.Continue(cctx, func(pc context.Context, s, t nostr.Timestamp, n int) ([]nostr.Event, error) {
								return relayPage(pc, r, rcvPk, s, t, n)
							}, since, from, catchupPage, catchupMaxPages, dispatch, catchupMarkOf(ck))
							setCatchupMark(ck, mark)
							noteCatchupPages(ck, res.Pages, res.Fetched)
							log.Printf("nostr: %s paged back %d pages, %d events, %d new, complete=%v, resume=%d",
								u, res.Pages, res.Fetched, res.Fresh, res.Complete, res.Until)
							if !res.Complete {
								return
							}
							atomic.StoreInt32(&caughtUp, 1)
							saveLast(atomic.LoadInt64(&pending))
						}(oldest)
					case <-idle.C:
						// quiet is what a conversation looks like nearly all of the
						// time, and cycling the sub re-runs the since window, which
						// after a media send is a hundred base64 chunks. ask a
						// question nothing can answer instead: a req matching no
						// event costs a frame and an eose, and a real eose proves
						// the circuit still carries data.
						if relayResponds(ctx, r) {
							markAlive()
							idle.Reset(deaf)
							continue
						}
						log.Printf("nostr: %s did not answer a probe, cycling the sub", u)
						r.Close()
						goto reconnect
					case <-kickChan():
						// the job knocks every fifteen minutes so sockets that
						// died while the phone was asleep come back inside its
						// short window. a socket that is still answering does
						// not need reviving, and dropping it costs a full since
						// window on every contact and every relay, so ask
						// before tearing down.
						//
						// a runner with no live subscription never gets here:
						// it is asleep in sleepOrKick and still reconnects at
						// once, which is the case the kick exists for.
						if relayResponds(ctx, r) {
							markAlive()
							log.Printf("nostr: %s kicked but still answering, keeping the sub", u)
							if !idle.Stop() {
								select {
								case <-idle.C:
								default:
								}
							}
							idle.Reset(deaf)
							continue
						}
						log.Printf("nostr: %s kicked, reconnecting now", u)
						idle.Stop()
						r.Close()
						kicked = true
						goto reconnect
					case <-ctx.Done():
						idle.Stop()
						ccancel()
						settled()
						r.Close()
						return
					}
				}
			reconnect:
				ccancel()
				settled()
				if kicked {
					kicked = false
				} else {
					sleepOrKick(rejoin)
				}
			}
		}(url)
	}
}

//export HaloNostrInit
func HaloNostrInit(cRelaysCSV *C.char) *C.char {
	csv := C.GoString(cRelaysCSV)
	if csv == "" {
		return C.CString("error: empty relay list")
	}
	urls := strings.Split(csv, ",")
	clean := make([]string, 0, len(urls))
	for _, u := range urls {
		u = strings.TrimSpace(u)
		if u != "" {
			clean = append(clean, u)
		}
	}
	if len(clean) == 0 {
		return C.CString("error: no valid relay urls")
	}
	nostrMu.Lock()
	nostrRelays = clean
	nostrMu.Unlock()
	log.Printf("nostr: configured %d relays: %v", len(clean), clean)
	return C.CString("ok")
}

//export HaloNostrSend
func HaloNostrSend(cPeerXPubHex, cMsg *C.char) *C.char {
	log.Printf("nostr: HaloNostrSend ENTRY")
	peerHex := C.GoString(cPeerXPubHex)
	msg := C.GoString(cMsg)

	peerBytes, err := hex.DecodeString(peerHex)
	if err != nil || len(peerBytes) != 32 {
		return C.CString("error: bad peer pubkey")
	}
	var peerArr [32]byte
	copy(peerArr[:], peerBytes)

	gw, err := nip17Wrap(peerArr, msg)
	if err != nil {
		return C.CString(fmt.Sprintf("error: wrap: %v", err))
	}
	// the wrap is built with the nip59 lib's event type; cross into the relay
	// lib as plain json. id and sig survive verbatim, both speak nip-01.
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		return C.CString(fmt.Sprintf("error: wrap convert: %v", err))
	}
	nostrMu.Lock()
	nostrSentIDs[ev.ID.Hex()] = true
	if len(nostrSentIDs) > 4096 {
		nostrSentIDs = map[string]bool{}
	}
	nostrMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	ok := nostrPublishMulti(ctx, ev)
	if ok == 0 {
		return C.CString("error: no relays accepted")
	}
	// log the drop-box we published to. if a peer isn't receiving, compare this
	// against the "at addr" in their subscribe line: a mismatch means the two
	// sides derived different addresses and nothing will ever arrive.
	_, dst, derr := nip17DeriveRole(peerArr, nip17RcvInfo, hex.EncodeToString(peerArr[:]))
	if derr == nil {
		log.Printf("nostr: sent event %s to %d relays, addr %s...", ev.ID.Hex()[:12], ok, dst[:12])
	} else {
		log.Printf("nostr: sent event %s to %d relays", ev.ID.Hex()[:12], ok)
	}
	return C.CString("ok")
}

//export HaloNostrSubscribe
func HaloNostrSubscribe(cPeerXPubHex *C.char) *C.char {
	peerHex := C.GoString(cPeerXPubHex)
	peerBytes, err := hex.DecodeString(peerHex)
	if err != nil || len(peerBytes) != 32 {
		return C.CString("error: bad peer pubkey")
	}
	var peerArr [32]byte
	copy(peerArr[:], peerBytes)

	_, rcvPk, err := nip17RcvAddress(peerArr)
	if err != nil {
		return C.CString(fmt.Sprintf("error: derive: %v", err))
	}

	nostrMu.Lock()
	if cancel, exists := nostrSubs[peerHex]; exists {
		cancel()
		delete(nostrSubs, peerHex)
	}
	ctx, cancel := context.WithCancel(context.Background())
	nostrSubs[peerHex] = cancel
	nostrMu.Unlock()

	go nostrSubscribeRunner(ctx, peerHex, peerArr, rcvPk)
	log.Printf("nostr: subscribed for peer %s... at addr %s...", peerHex[:12], rcvPk[:12])
	return C.CString("ok")
}

// the public half of our first-contact address. goes in the invite so a
// stranger can reach us before either side knows the other's key.
//
//export HaloFirstContactPk
func HaloFirstContactPk(counter C.int) *C.char {
	_, pk, err := nip17FirstContactKeys(int(counter))
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	return C.CString(pk)
}

// watch our own first-contact address. unlike every other subscription this
// needs no contacts, which is the whole point: a fresh install with an empty
// roster can still be reached.
//
//export HaloNostrSubscribeFirstContact
func HaloNostrSubscribeFirstContact(counter C.int) *C.char {
	_, fcPk, err := nip17FirstContactKeys(int(counter))
	if err != nil {
		return C.CString(fmt.Sprintf("error: derive: %v", err))
	}

	nostrMu.Lock()
	if cancel, exists := nostrSubs["firstcontact"]; exists {
		cancel()
		delete(nostrSubs, "firstcontact")
	}
	ctx, cancel := context.WithCancel(context.Background())
	nostrSubs["firstcontact"] = cancel
	nostrMu.Unlock()

	var zero [32]byte
	go nostrSubscribeRunnerMode(ctx, "firstcontact", zero, fcPk, true, int(counter))
	log.Printf("nostr: watching first-contact addr %s...", fcPk[:12])
	return C.CString("ok")
}

// introduce ourselves to someone who has never heard of us. the seal is
// signed with our usual per-conversation key, so once they know us the normal
// verification applies to everything after this.
//
//export HaloNostrSendFirstContact
func HaloNostrSendFirstContact(cPeerXPubHex, cFcPk, cMsg *C.char) *C.char {
	peerHex := C.GoString(cPeerXPubHex)
	fcPk := C.GoString(cFcPk)
	msg := C.GoString(cMsg)

	peerBytes, err := hex.DecodeString(peerHex)
	if err != nil || len(peerBytes) != 32 {
		return C.CString("error: bad peer pubkey")
	}
	if len(fcPk) != 64 {
		return C.CString("error: bad first-contact pubkey")
	}
	var peerArr [32]byte
	copy(peerArr[:], peerBytes)

	gw, err := nip17WrapFirstContact(peerArr, fcPk, msg)
	if err != nil {
		return C.CString(fmt.Sprintf("error: wrap: %v", err))
	}
	// the wrap comes from the nip59 lib's event type; cross into the relay
	// lib as plain json, same as the normal send path.
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		return C.CString(fmt.Sprintf("error: wrap convert: %v", err))
	}
	nostrMu.Lock()
	nostrSentIDs[ev.ID.Hex()] = true
	if len(nostrSentIDs) > 4096 {
		nostrSentIDs = map[string]bool{}
	}
	nostrMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	ok := nostrPublishMulti(ctx, ev)
	if ok == 0 {
		return C.CString("error: no relays accepted")
	}
	log.Printf("nostr: sent first-contact %s to %d relays, addr %s...", ev.ID.Hex()[:12], ok, fcPk[:12])
	return C.CString("ok")
}

// drop every relay socket and reconnect now. returns "ok".
//
//export HaloNostrKick
func HaloNostrKick() *C.char {
	kickRelays()
	return C.CString("ok")
}

// what the go side is holding, for the transport screen and for finding
// out what grows. json, bytes.
//
//export HaloMemStats
func HaloMemStats() *C.char {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	nostrMu.Lock()
	inbox := len(nostrInbox)
	subs := len(nostrSubs)
	sent := len(nostrSentIDs)
	nostrMu.Unlock()
	lastEvMu.Lock()
	evAt, evRecv := lastEvAt, lastEvRecv
	lastEvMu.Unlock()
	return C.CString(fmt.Sprintf(
		`{"heapAlloc":%d,"heapSys":%d,"heapIdle":%d,"sys":%d,"numGC":%d,"goroutines":%d,"inbox":%d,"subs":%d,"sentIds":%d,"lastEvAt":%d,"lastEvRecv":%d}`,
		m.HeapAlloc, m.HeapSys, m.HeapIdle, m.Sys, m.NumGC, runtime.NumGoroutine(), inbox, subs, sent, evAt, evRecv,
	))
}

//export HaloNostrPoll
func HaloNostrPoll() *C.char {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	if len(nostrInbox) == 0 {
		return C.CString("")
	}
	out := strings.Join(nostrInbox, "\n")
	nostrInbox = nostrInbox[:0]
	return C.CString(out)
}

// fetch a url over the tor http client and return the html body (capped).
// used for sender-side link previews so the receiver never has to fetch and
// leak their ip. best-effort: returns "error: ..." on any failure, caller skips.
//
//export HaloTorGet
func HaloTorGet(cUrl *C.char) *C.char {
	url := C.GoString(cUrl)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	// no user agent: the request should not say which app made it
	req.Header.Set("User-Agent", "")
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: get: %v", err))
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return C.CString(fmt.Sprintf("error: status %d", resp.StatusCode))
	}
	// cap at 256kb: the og tags live in <head>, no need for the whole page.
	limited := io.LimitReader(resp.Body, 256*1024)
	body, err := io.ReadAll(limited)
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	return C.CString(string(body))
}

// a client that only ever dials through tor, whatever the send mode. the
// shared client above goes direct in balanced and fast modes, which is right
// for relays and wrong for a link preview: a preview that cannot go over
// tor does not go. built once, no redirects past two, and never a plain
// fallback.
var (
	torOnlyMu     sync.Mutex
	torOnlyClient *http.Client
)

func torOnlyHTTP() (*http.Client, error) {
	torOnlyMu.Lock()
	defer torOnlyMu.Unlock()
	if torOnlyClient != nil {
		return torOnlyClient, nil
	}
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil {
		return nil, fmt.Errorf("tor not started")
	}
	d, err := torDialer(context.Background(), t)
	if err != nil {
		return nil, fmt.Errorf("tor dialer: %v", err)
	}
	torOnlyClient = &http.Client{
		Transport: &http.Transport{
			DialContext:           d.DialContext,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 10 * time.Second,
		},
		Timeout: 15 * time.Second,
		// two redirects at most: a shortener into a canonical url is
		// ordinary, a longer chain is not worth following
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) > 2 {
				return fmt.Errorf("too many redirects")
			}
			return nil
		},
	}
	return torOnlyClient, nil
}

// GET a page over tor and nothing else, for the sender-side link preview.
// capped at 128kb, html only, no user agent, "error: ..." on any failure
// including tor not being up. the caller skips, it never falls back.
//
//export HaloTorGetStrict
func HaloTorGetStrict(cUrl *C.char) *C.char {
	url := C.GoString(cUrl)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torOnlyHTTP()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor: %v", err))
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	req.Header.Set("User-Agent", "")
	req.Header.Set("Accept", "text/html")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: get: %v", err))
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return C.CString(fmt.Sprintf("error: status %d", resp.StatusCode))
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 128*1024))
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	return C.CString(string(body))
}

// POST json over tor, returning the response body. used for the badge
// service (creating a donation invoice) so the donor's ip never touches
// anything. any non-2xx comes back as "error: ..." for the caller to skip.
//
//export HaloTorPost
func HaloTorPost(cUrl *C.char, cBody *C.char) *C.char {
	url := C.GoString(cUrl)
	body := C.GoString(cBody)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("POST", url, strings.NewReader(body))
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	req.Header.Set("Content-Type", "application/json")
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: post: %v", err))
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	if resp.StatusCode >= 300 {
		return C.CString(fmt.Sprintf("error: status %d: %s", resp.StatusCode, string(out)))
	}
	return C.CString(string(out))
}

// GET over tor that keeps the body for any 2xx: the badge service answers
// 202 while a payment is still pending, which HaloTorGet would reject.
//
//export HaloTorGetJSON
func HaloTorGetJSON(cUrl *C.char) *C.char {
	url := C.GoString(cUrl)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: get: %v", err))
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	if resp.StatusCode >= 300 {
		return C.CString(fmt.Sprintf("error: status %d", resp.StatusCode))
	}
	return C.CString(string(out))
}

// like HaloTorGet but returns the body base64-encoded, for binary content
// (link-preview images). fetched over tor so the receiver never loads the
// image from the origin and leaks their ip. capped larger than html.
//
//export HaloTorGetB64
func HaloTorGetB64(cUrl *C.char) *C.char {
	url := C.GoString(cUrl)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	// no user agent: the request should not say which app made it
	req.Header.Set("User-Agent", "")
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: get: %v", err))
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return C.CString(fmt.Sprintf("error: status %d", resp.StatusCode))
	}
	// cap at 1mb: preview thumbnails, not full-res.
	limited := io.LimitReader(resp.Body, 1024*1024)
	body, err := io.ReadAll(limited)
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	return C.CString("ok:" + base64.StdEncoding.EncodeToString(body))
}
