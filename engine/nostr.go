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
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	mrand "math/rand/v2"
	"net"
	"net/http"
	"net/url"
	"os"
	"runtime"
	"slices"
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
	nostrMu     sync.Mutex
	nostrRelays []string
	// the mode changed and the app has not set its relays yet: the list
	// still names the old mode's, and the new route must not dial them
	nostrRelaysStale bool
	nostrSubs        = map[string]context.CancelFunc{}
	// the subscriptions of hidden chats, by key: a runner started again for
	// one stays on a socket of its own
	nostrHiddenSubs = map[string]bool{}
	// "tag|content" per event, and what each one still owes once the poll
	// has handed it over
	nostrInbox     []string
	nostrInboxDone []inboxDone
	nostrSentIDs   = map[string]bool{}
	// the counter the first-contact address was last watched on
	fcCounterNow int
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

// a context for publishes that outlive the caller: publishWait of its own,
// cancelled by the last publisher out. made here so the analyser sees a
// plain pair rather than a cancel it cannot follow into the goroutines.
func detachedPublishCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), publishWait)
}

// closed when the mode changes: a connection made before it went the old
// way, direct or through tor, and must not outlive it
var (
	routeEndMu sync.Mutex
	routeEnd   = make(chan struct{})
)

func routeEnded() <-chan struct{} {
	routeEndMu.Lock()
	defer routeEndMu.Unlock()
	return routeEnd
}

type routeKey struct{}

// parent, ending also when routeC does. a shared dial under it finds the
// route with routeOf
func onRoute(parent context.Context, routeC <-chan struct{}) (context.Context, context.CancelFunc) {
	ctx, cancel := context.WithCancel(context.WithValue(parent, routeKey{}, routeC))
	go func() {
		select {
		case <-routeC:
			cancel()
		case <-ctx.Done():
		}
	}()
	return ctx, cancel
}

// the route a context from onRoute is on, or nil
func routeOf(ctx context.Context) <-chan struct{} {
	c, _ := ctx.Value(routeKey{}).(<-chan struct{})
	return c
}

func routeGone(routeC <-chan struct{}) bool {
	select {
	case <-routeC:
		return true
	default:
		return false
	}
}

// a mode switch: every relay connection closes, and nothing is dialled off
// the old mode's list until setRelays brings the new one
func endRoute() {
	nostrMu.Lock()
	nostrRelaysStale = true
	nostrMu.Unlock()
	routeEndMu.Lock()
	close(routeEnd)
	routeEnd = make(chan struct{})
	routeEndMu.Unlock()
}

// called with every list set, for the tests
var relaysSetHook func([]string)

func setRelays(urls []string) {
	if h := relaysSetHook; h != nil {
		h(urls)
	}
	nostrMu.Lock()
	nostrRelays = urls
	nostrRelaysStale = false
	nostrMu.Unlock()
}

// the relays to use now. right after a mode switch the list is the old
// mode's for a moment, until the app sets the new one: wait for it while
// ctx lives
func relaysWhenSet(ctx context.Context) []string {
	for {
		nostrMu.Lock()
		stale := nostrRelaysStale
		urls := append([]string(nil), nostrRelays...)
		nostrMu.Unlock()
		if !stale {
			return urls
		}
		select {
		case <-ctx.Done():
			return nil
		case <-time.After(50 * time.Millisecond):
		}
	}
}

func kickChan() chan struct{} {
	kickMu.Lock()
	defer kickMu.Unlock()
	return kickCh
}

// sleep that a kick ends early, true when it was kicked, on a kick channel
// taken before the check that led here, so a kick between the two is not
// missed. a runner waiting out a failed dial still hears the job's kick
func sleepOrKickOn(kc chan struct{}, d time.Duration) bool {
	return sleepOrKickCtx(context.Background(), kc, d)
}

// as sleepOrKickOn, and over when ctx is
func sleepOrKickCtx(ctx context.Context, kc chan struct{}, d time.Duration) bool {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
		return false
	case <-kc:
		return true
	case <-ctx.Done():
		return false
	}
}

// called when a runner finds tor off the network, before it sleeps, for
// the tests
var runnerParkHook func()

// called by a runner past the cap as it starts waiting for its next read,
// for the tests
var sweepWaitHook func()

// a req shaped like any other this socket sends: its own address, nothing
// older than now and no stored events. the relay answers eose, which is the
// cheapest proof that this circuit still carries data, and unlike cycling
// the subscription it does not refetch a single stored event. the library
// dispatches a fake eose after 7s when a relay stays silent, which would
// make every probe pass, so that is disabled here: only the relay's own
// eose counts, or its refusal, which is an answer too.
func relayResponds(ctx context.Context, r *nostr.Relay, rcvPk string) bool {
	pctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	sub, err := r.Subscribe(pctx, probeFilter(rcvPk, time.Now()),
		nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
	if err != nil {
		return false
	}
	defer sub.Unsub()
	for {
		select {
		case _, alive := <-sub.Events:
			// the subscription that asked for it has it too. a closed one
			// went with its socket, unless the relay refused it first
			if !alive {
				select {
				case <-sub.ClosedReason:
					return true
				default:
					return false
				}
			}
		case <-sub.ClosedReason:
			return true
		case <-sub.EndOfStoredEvents:
			return true
		case <-pctx.Done():
			return false
		}
	}
}

func probeFilter(rcvPk string, now time.Time) nostr.Filter {
	return nostr.Filter{
		Kinds:     []nostr.Kind{1059},
		Tags:      nostr.TagMap{"p": []string{rcvPk}},
		Since:     nostr.Timestamp(now.Unix()),
		LimitZero: true,
	}
}

// how long a socket waits before it answers a kick, drawn per socket, so the
// sockets of different lanes do not all ask their relays in one instant
var kickSpread = time.Minute

func kickDelay() time.Duration { return spreadDelay(kickSpread, autoNow()) }

// the quiet timer, spread a quarter either way, so sockets that opened
// together do not probe together
func quietFor(deaf time.Duration) time.Duration {
	return deaf*3/4 + time.Duration(mrand.Int64N(int64(deaf/2)+1))
}

// a connection that dies within this of opening counts as dropped young
const youngConn = time.Minute

// the wait before redialling u when it keeps dropping young connections:
// the usual pause for the first, doubling from there to a ceiling. our own
// relay's ceiling is low, as with failed dials, see ownWaitRule.
func youngDropWait(u string, rejoin time.Duration, drops int, own bool) time.Duration {
	mine, ceiling := ownWaitRule(u, own)
	d := rejoin
	for i := 1; i < drops && d < ceiling; i++ {
		d *= 2
	}
	if d > ceiling {
		d = ceiling
	}
	if mine {
		d = ownSpread(d)
	}
	return d
}

// how far past this phone's clock an event may move the since anchor: a
// sender's clock can run a little fast
const anchorSlack = 5 * time.Minute

func anchorStamp(ts nostr.Timestamp, now time.Time) nostr.Timestamp {
	if max := nostr.Timestamp(now.Add(anchorSlack).Unix()); ts > max {
		return max
	}
	return ts
}

// an anchor read back is never later than now
func anchorNow(v int64, now time.Time) int64 {
	if n := now.Unix(); v > n {
		return n
	}
	return v
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
// for it. paging back is up to catchupMaxPages requests, each as long as
// events keep coming, so one slow relay could otherwise hold tor awake for
// the whole window.
//
// past this the relay stops counting as active, so a check-in can stop tor,
// which ends the walk and leaves its mark for the next connect. otherwise
// the walk goes on: a healthy socket is not redialled for hours, and what
// it has not reached yet would wait for that. a var for the tests.
var catchupCap = 30 * time.Second

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
	// what each relay's walk still owes the anchor, see catchup.Hold
	catchupHolds = map[string]catchup.Hold{}
	catchupFreed = map[string]catchup.Freed{}
	// the three above, see catchup.Book
	catchupBook = &catchup.Book{Marks: catchupMarks, Holds: catchupHolds, Freed: catchupFreed}
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

func catchupHoldOf(key string) catchup.Hold {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	return catchupHolds[key]
}

// our relay's clearnet name. the app puts our relay first in every list: in
// private mode its onion, with this name right after it, and in the other
// modes this name (relaysFor in app/state.dart). tests point it at a
// stand-in.
var ownRelayHost = &hostSeam{app: "relay.kryfo.app"}

// the entries of a relay list that reach our stores: the first, and any on
// one of their clearnet names. each store holds its own anchor, see
// catchup.Book and stores.go.
func ownRelays(urls []string) []string {
	var own []string
	for _, u := range urls {
		if storeOf(urls, u) != "" {
			own = append(own, u)
		}
	}
	return own
}

// u is one of our relay's entries in the list now set
func isOwnRelay(u string) bool {
	nostrMu.Lock()
	urls := nostrRelays
	nostrMu.Unlock()
	for _, o := range ownRelays(urls) {
		if o == u {
			return true
		}
	}
	return false
}

func relayHostIs(u, host string) bool {
	p, err := url.Parse(u)
	return err == nil && strings.EqualFold(p.Host, host)
}

// a connection on key, from the anchor last at now. own: our relay's keys
// for the address
func catchupConnect(key string, own []string, last, now nostr.Timestamp) catchup.Conn {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	return catchupBook.Connect(key, own, last, now)
}

// a connection's first answer came full, see catchup.Book.Owe
func catchupOwe(c catchup.Conn) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	catchupBook.Owe(c)
}

// a walk stopped short at m
func catchupCut(c catchup.Conn, m catchup.Mark) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	catchupBook.Cut(c, m)
}

// a walk reached the bottom of its window, see catchup.Book.Done
func catchupDone(c catchup.Conn, stepped bool) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	catchupBook.Done(c, stepped)
}

// the relay answered the subscription with CLOSED
func catchupRefused(c catchup.Conn) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	catchupBook.Refused(c)
}

// a runner starting on an address, see catchup.Book.Start
func catchupStart(own []string, anchor, now nostr.Timestamp) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	catchupBook.Start(own, anchor, now)
}

// the lowest anchor a walk on our relay still owes for an address
func catchupFloor(own []string) (nostr.Timestamp, bool) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	return catchupBook.Floor(own)
}

// how long this subscription gets this time round.
func catchupCapFor(key string) (time.Duration, bool) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	if catchupDrops[key] >= catchupDropsBeforeLong {
		// one longer turn, then back to the usual
		catchupDrops[key] = 0
		catchupLong[key] = true
		return checkInBound(catchupLongCap, checkInLongCap), true
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
	if !dropped {
		startSteps.caughtUp(rcvOfKey(key))
	}
	if dropped {
		log.Printf("nostr: %s still catching up after %dms, dropped for this check-in (%d in a row)",
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

// how long a page may go without a single event before it is given up. a
// hundred media slices over a slow circuit take longer than any fixed wait,
// yet each one comes within this; a dead circuit sends nothing at all.
// the tests set it, and a walk can outlive the test that started it
var pageQuietSet atomic.Int64

func pageQuiet() time.Duration {
	if d := pageQuietSet.Load(); d > 0 {
		return time.Duration(d)
	}
	return 20 * time.Second
}

// how many times its limit a page reads at most while it waits for the
// eose. a contact's photo is a hundred wraps, and a relay can send them
// among a page's stored events; only one that ignores the limit pays for
// reading this far
const pageReads = 4

// the longest content a wrap can have: a nip-44 payload holds at most this
// much, and nothing longer opens
const wrapContentMax = 87472

// a wrap's tags are a p and an expiration, well inside this
const wrapTagsMax = 1024

// an event larger than a wrap can be keeps only its id and stamp. it still
// counts toward its page and moves the page's oldest, so the walk goes on
// below it, and with no content it is left unopened.
func pageEntry(ev nostr.Event) nostr.Event {
	tags := 0
	for _, tag := range ev.Tags {
		tags += len(tag)
		for _, v := range tag {
			tags += len(v)
		}
	}
	if len(ev.Content) <= wrapContentMax && tags <= wrapTagsMax {
		return ev
	}
	return nostr.Event{ID: ev.ID, PubKey: ev.PubKey, CreatedAt: ev.CreatedAt, Kind: ev.Kind}
}

// one page of stored events, closed again as soon as the relay says that
// was all. a page cut short, by a quiet circuit, the relay or the caller,
// returns what it got with the error, in the order it came, so the walk
// keeps it. of an event larger than a wrap can be it keeps only its id and stamp.
// past limit it reads on to the eose, up to pageReads times the limit: a
// live event the relay sent among the stored ones takes a place, and the
// walk judges a full page by its limit-th newest stamp, so it needs limit
// stored ones. it keeps only the events at that stamp or above, the walk
// asks for the rest again.
func relayPage(ctx context.Context, r *nostr.Relay, rcvPk string, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
	pctx, cancel := context.WithCancel(ctx)
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
	quiet := time.NewTimer(pageQuiet())
	defer quiet.Stop()
	var out []nostr.Event
	read := 0
	for {
		select {
		case ev, alive := <-sub.Events:
			if !alive {
				return out, errors.New("relay closed the page")
			}
			read++
			out = catchup.Newest(append(out, pageEntry(ev)), limit)
			if limit > 0 && read >= limit*pageReads {
				return out, nil
			}
			quiet.Reset(pageQuiet())
		case <-sub.EndOfStoredEvents:
			return out, nil
		case <-quiet.C:
			// a relay that keeps to the limit sent all it had
			if limit > 0 && read >= limit {
				return out, nil
			}
			return out, errors.New("page went quiet")
		case <-ctx.Done():
			return out, ctx.Err()
		}
	}
}

// ids asked for in one filter
const heldAskChunk = 100

// the stored events with these ids, each handed to take as it comes, asked
// for heldAskChunk at a time. a chunk answered in part is asked again for
// the rest: a relay may cap what one filter brings. answered is true once
// the relay went through all of them, and missing holds the ids an answer
// that brought none of what it was asked for came back without
func relayByIDs(ctx context.Context, r *nostr.Relay, rcvPk string, ids []nostr.ID, take func(nostr.Event) bool) (missing []nostr.ID, answered bool) {
	for at := 0; at < len(ids); at += heldAskChunk {
		left := ids[at:min(at+heldAskChunk, len(ids))]
		for len(left) > 0 {
			got, ok := relayIDsOnce(ctx, r, rcvPk, left, take)
			if !ok {
				return nil, false
			}
			var rest []nostr.ID
			for _, id := range left {
				if !got[id] {
					rest = append(rest, id)
				}
			}
			if len(rest) == len(left) {
				missing = append(missing, rest...)
				break
			}
			left = rest
		}
	}
	return missing, true
}

// one filter of ids: those that came, and whether the relay said that was all
func relayIDsOnce(ctx context.Context, r *nostr.Relay, rcvPk string, ids []nostr.ID, take func(nostr.Event) bool) (map[nostr.ID]bool, bool) {
	pctx, cancel := context.WithCancel(ctx)
	defer cancel()
	sub, err := r.Subscribe(pctx, nostr.Filter{
		IDs:   ids,
		Kinds: []nostr.Kind{1059},
		Tags:  nostr.TagMap{"p": []string{rcvPk}},
		Limit: len(ids),
	}, nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
	if err != nil {
		return nil, false
	}
	defer sub.Unsub()
	got := map[nostr.ID]bool{}
	quiet := time.NewTimer(pageQuiet())
	defer quiet.Stop()
	for {
		select {
		case ev, alive := <-sub.Events:
			if !alive {
				return nil, false
			}
			got[ev.ID] = true
			take(ev)
			quiet.Reset(pageQuiet())
		case <-sub.EndOfStoredEvents:
			return got, true
		case <-quiet.C:
			return nil, false
		case <-ctx.Done():
			return nil, false
		}
	}
}

// the cap cut a connection's first answer, see catchup.Book.KeepFirst
func keepFirstAnswer(c catchup.Conn, oldest nostr.Timestamp, now time.Time) {
	catchupMu.Lock()
	defer catchupMu.Unlock()
	catchupBook.KeepFirst(c, oldest, nostr.Timestamp(now.Add(anchorSlack).Unix()))
}

// a connection whose walk is under way asks for no more than this at first:
// the walk has the rest, and a slow circuit spends its window on new ground
// rather than on the newest hundred again
const catchupResumeLimit = 5

// relay health. a relay that will not answer still costs a full tor circuit
// on every attempt, and with one subscribe goroutine per relay per contact
// that adds up fast. count consecutive failures, bench the relay for a
// doubling stretch, forget the whole history on the first success.
var (
	relayHealthMu sync.Mutex
	relayFails    = map[string]int{}
	relayCoolTill = map[string]time.Time{}
	// when each relay's last failure was counted
	relayFailAt = map[string]time.Time{}
	// when each relay last answered: a subscription, an event, a probe, an ok
	relayUpAt = map[string]time.Time{}
)

// a couple of misses is just a bad circuit, not a dead relay.
const relayFailGrace = 3

// failures to one relay this close after a counted one count with it: many
// sockets failing together is one hiccup on the way there, and counted one
// by one it benched the relay for every subscription at once. a var for
// the tests.
var relayFailBurst = 5 * time.Second

// our own relay carries the traffic, so it is retried far more eagerly than
// the public ones: seconds apart rather than minutes. it is still a ceiling
// and not an exemption. it holds wraps no other relay has, and a receiver in
// relay mode reads nothing else.
const ownRelayCeiling = 20 * time.Second

// another way into our relay that answered this recently is taken as up
const ownUpRecent = 10 * time.Minute

func relayUp(u string) {
	wakeRouteProven()
	relayEverOK.Store(u, true)
	relayHealthMu.Lock()
	relayUpAt[u] = time.Now()
	relayHealthMu.Unlock()
}

// the longest any relay is benched
const relayMaxBench = 5 * time.Minute

// mine: u reaches one of our stores, in the list now set or as the runner's
// first entry (own). ceiling: the longest it waits. another way into the
// same store that answers leaves it the usual backoff, as nothing waits on
// u then. the other store answering leaves it a short one, so it is back
// within minutes of returning. with none of ours answering it gets the low
// ceiling and is redialled seconds apart.
func ownWaitRule(u string, own bool) (mine bool, ceiling time.Duration) {
	nostrMu.Lock()
	urls := nostrRelays
	nostrMu.Unlock()
	st := storeOf(urls, u)
	if st == "" && !own {
		return false, relayMaxBench
	}
	if st == "" {
		st = storeFirst
	}
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	other := false
	for _, o := range ownRelays(urls) {
		at, ok := relayUpAt[o]
		if !ok || o == u || time.Since(at) >= ownUpRecent {
			continue
		}
		if storeOf(urls, o) == st {
			return true, relayMaxBench
		}
		if relayFails[o] == 0 {
			other = true
		}
	}
	if other {
		return true, otherStoreCeiling
	}
	return true, ownRelayCeiling
}

// another of our stores than u's answered lately, with no failure since
func otherStoreAnswers(urls []string, u string) bool {
	st := storeOf(urls, u)
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	for _, o := range ownRelays(urls) {
		if o == u || storeOf(urls, o) == st {
			continue
		}
		if at, ok := relayUpAt[o]; ok && time.Since(at) < ownUpRecent && relayFails[o] == 0 {
			return true
		}
	}
	return false
}

// a fifth either way, so the runners of one relay do not all redial it in
// the same second
func ownSpread(d time.Duration) time.Duration {
	if d <= 0 {
		return d
	}
	return d*4/5 + time.Duration(mrand.Int64N(int64(d*2/5)+1))
}

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

// the dials out now to each relay on a failing streak
var failingDials sync.Map // url -> *atomic.Int32

// whether this socket may dial u now, and what to call once the dial is
// over. a relay with no failure since it last answered: always
func failingDialBegin(u string) (bool, func()) {
	relayHealthMu.Lock()
	failing := relayFails[u] > 0
	relayHealthMu.Unlock()
	if !failing {
		return true, func() {}
	}
	v, _ := failingDials.LoadOrStore(u, new(atomic.Int32))
	n := v.(*atomic.Int32)
	if !n.CompareAndSwap(0, 1) {
		return false, nil
	}
	return true, func() { n.Store(0) }
}

// a runner's base wait after a failure: our second store's entries wait as
// a public relay does while our first store answers, not three seconds
func retryFor(u string, retry time.Duration, own bool) time.Duration {
	if own && retry < 10*time.Second && secondStoreSpared(nostrRelaysNow(), u) {
		return 10 * time.Second
	}
	return retry
}

// u is an entry of our second store and our first store answers: it may
// wait. our first store never does: the versions before the second store
// read it alone
func secondStoreSpared(urls []string, u string) bool {
	return storeOf(urls, u) == storeSecond && otherStoreAnswers(urls, u)
}

// closed when every bench is let go of, at a wake or a new route
var benchClear = struct {
	sync.Mutex
	c chan struct{}
}{c: make(chan struct{})}

func benchClearChan() <-chan struct{} {
	benchClear.Lock()
	defer benchClear.Unlock()
	return benchClear.c
}

// when u's bench ends, zero when it has none
func relayCoolUntil(u string) time.Time {
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	return relayCoolTill[u]
}

// a public relay on the bench is not dialled before its bench ends, kick
// or no kick: a kick is for sockets a change may have helped, and one that
// turned tor away at its door is not. a wake or a new route lets every
// bench go. false once ctx is over
func waitOutBench(ctx context.Context, u string) bool {
	cleared := benchClearChan()
	till := relayCoolUntil(u)
	d := time.Until(till)
	if d <= 0 {
		return true
	}
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-cleared:
	case <-t.C:
	}
	return true
}

// a public relay that never answered in this process (one that turns tor
// away at its door, say) backs off further, up to this
const relayDeadBench = 15 * time.Minute

// the relays that answered at least once in this process. a bench cleared
// at a wake or a new route does not clear this
var relayEverOK sync.Map

// the backoff after n failures in a row on u: a public relay that never
// answered here goes on doubling past relayMaxBench
func relayBackoffFor(u string, n int) time.Duration {
	if _, ok := relayEverOK.Load(u); ok || storeOf(nostrRelaysNow(), u) != "" || n <= relayFailGrace+6 {
		return relayBackoff(n)
	}
	return min(relayMaxBench<<uint(min(n-relayFailGrace-6, 2)), relayDeadBench)
}

// the ceiling for u's waits: a public relay that never answered here has
// the longer one
func deadCeiling(u string, ceiling time.Duration) time.Duration {
	if _, ok := relayEverOK.Load(u); ok || ceiling != relayMaxBench {
		return ceiling
	}
	return relayDeadBench
}

func nostrRelaysNow() []string {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	return nostrRelays
}

func relayCold(u string) bool {
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	till, ok := relayCoolTill[u]
	return ok && time.Now().Before(till)
}

// the relay's own answer (an OK false, or an http status at the upgrade), not a socket or circuit failure
func relayAnswered(err error) bool {
	if err == nil {
		return false
	}
	e := err.Error()
	return strings.HasPrefix(e, "msg: ") || strings.Contains(e, "expected handshake response status code")
}

// the relay says it holds the event already
func relayHasIt(err error) bool {
	return err != nil && strings.HasPrefix(err.Error(), "msg: duplicate:")
}

// the relay answered no: benched as for a failure, the route not marked down
func relayRefused(u string, began time.Time, err error) {
	relayFailedAs(u, began, false)
}

// an attempt on u that began at began has failed
func relayFailed(u string, began time.Time) { relayFailedAs(u, began, true) }

// route: the failure may speak for the route, not only for u
func relayFailedAs(u string, began time.Time, route bool) {
	// only tor's warmup can make a connect failure meaningless, also for a
	// backup, which goes through tor on every route
	if (modeNeedsTor() && !torReadyNow()) || (isBackup(u) && !torCarriesNow()) {
		return
	}
	// nor can a sleep, or the first stretch of the wake after it. a refusal
	// is the relay's own answer and counts
	if route && wakeExcuses(began) {
		return
	}
	if modeNeedsTor() && route && !isBackup(u) {
		routeNoteFailFrom(u, began)
	}
	_, ceiling := ownWaitRule(u, false)
	ceiling = deadCeiling(u, ceiling)
	nostrMu.Lock()
	urls := nostrRelays
	nostrMu.Unlock()
	relayHealthMu.Lock()
	now := time.Now()
	// an attempt already under way when the last failure was counted, or
	// failing right after it, went down in the same hiccup
	if last, ok := relayFailAt[u]; ok && (began.Before(last) || now.Sub(last) < relayFailBurst) {
		relayHealthMu.Unlock()
		return
	}
	relayFailAt[u] = now
	relayFails[u]++
	d := relayBackoffFor(u, relayFails[u])
	if d > ceiling {
		d = ceiling
	}
	if d > 0 {
		relayCoolTill[u] = now.Add(d)
		log.Printf("nostr: benching %s for %s, %d failures in a row", u, d, relayFails[u])
	}
	gone := oursAllGoneLocked(urls, u)
	relayHealthMu.Unlock()
	if gone {
		log.Println("nostr: none of our relays answers, every one of them is tried again now")
		oursGoneWake()
	}
}

// forget every bench. a relay benched while the route under it was dead did
// nothing wrong, and holding it out for five more minutes after the route is
// rebuilt is five more minutes of a message sitting in the outbox.
func relayClearBenches() {
	benchClear.Lock()
	close(benchClear.c)
	benchClear.c = make(chan struct{})
	benchClear.Unlock()
	relayHealthMu.Lock()
	for k := range relayFails {
		delete(relayFails, k)
	}
	for k := range relayCoolTill {
		delete(relayCoolTill, k)
	}
	for k := range relayFailAt {
		delete(relayFailAt, k)
	}
	for k := range relayUpAt {
		delete(relayUpAt, k)
	}
	relayHealthMu.Unlock()
}

// whether the relays now configured still name u
func relayListed(ctx context.Context, u string) bool {
	for _, r := range relaysWhenSet(ctx) {
		if r == u {
			return true
		}
	}
	return isBackup(u)
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
	wakeRouteProven()
	relayEverOK.Store(u, true)
	relayHealthMu.Lock()
	relayUpAt[u] = time.Now()
	if relayFails[u] != 0 {
		delete(relayFails, u)
		delete(relayCoolTill, u)
		delete(relayFailAt, u)
	}
	relayHealthMu.Unlock()
	// a store that answers takes what it missed meanwhile
	topupKick(u)
}

// how long to wait before the next attempt, never shorter than the caller's
// own cadence. our own relay backs off too, but to a much lower ceiling
// (see ownWaitRule): exempt, every subscription would redial a failing relay
// every few seconds, around the clock, on whatever connection the phone has.
func relayRetryAfter(u string, base time.Duration, own bool) time.Duration {
	mine, ceiling := ownWaitRule(u, own)
	ceiling = deadCeiling(u, ceiling)
	relayHealthMu.Lock()
	n := relayFails[u]
	relayHealthMu.Unlock()
	d := relayBackoffFor(u, n)
	if d > ceiling {
		d = ceiling
	}
	if d < base {
		d = base
	}
	if mine {
		d = ownSpread(d)
	}
	return d
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

// the clients torNostrClientFor hands out, one per lane, each dialling
// through tor's socks proxy under its lane's name. keyed by lane, or by ""
// for the one direct client every lane shares outside private mode.
var (
	cachedNostrClients  = map[string]*http.Client{}
	cachedNostrClientMu sync.Mutex
)

// the cached clients go, so new streams take the socks names now; kept sockets and door streams stay
func nostrDropClients() {
	cachedNostrClientMu.Lock()
	cachedNostrClients = map[string]*http.Client{}
	cachedNostrClientMu.Unlock()
	torOnlyMu.Lock()
	torOnlyClient = nil
	torOnlyMu.Unlock()
}

// called from shutdown and from every bounce. the cached client pins the
// socks address it was built on, and a bounce can move it.
func nostrResetClient() {
	cachedNostrClientMu.Lock()
	cachedNostrClients = map[string]*http.Client{}
	cachedNostrClientMu.Unlock()
	// the preview client dials the tor it was built on. after a restart
	// that tor is gone, and a client kept from before would dial a dead
	// port for the rest of the process
	torOnlyMu.Lock()
	torOnlyClient = nil
	torOnlyMu.Unlock()
	updateResetClient()
	dropSocksAddr()
	// kept sockets and door streams dialled the old way go with it
	pubCloseAll("")
	doorCloseAll()
}

// how long a relay's websocket may take to open. the relay library gives
// seven seconds when the context has no deadline of its own, and an onion
// relay takes longer than that whenever tor has to find it again: the
// descriptor, an introduction and a rendezvous, six hops, then tls. only the
// handshake is bounded by this; the connection lives on the relay's own
// context.
func relayDialCtx(parent context.Context, u string) (context.Context, context.CancelFunc) {
	d := relayDialWait
	if strings.Contains(u, ".onion") {
		d = onionDialWait
	}
	return context.WithTimeout(parent, checkInBound(d, checkInDialWait))
}

const (
	relayDialWait = 20 * time.Second
	onionDialWait = 45 * time.Second
)

// how long a send waits for a relay to take its wrap. our relay's onion can
// be the only way in and may need the whole onion dial before it can take
// anything. the first ok still ends the wait. the app gives a send 60s.
const publishWait = onionDialWait + 10*time.Second

// the everyday lane's client, for the main identity's sends
func torNostrClient() (*http.Client, error) { return torNostrClientFor(laneEveryday) }

// nothing in here talks to tor: the socks address is pinned or remembered,
// and bine builds a plain socks5 dialer from it. so the mutex is held for
// microseconds, and a resume or a reconnect that resets the client never
// waits on a relay runner (see control_events.go).
func torNostrClientFor(lane string) (*http.Client, error) {
	if modeNeedsTor() {
		return torClientFor(lane)
	}
	cachedNostrClientMu.Lock()
	defer cachedNostrClientMu.Unlock()
	if c := cachedNostrClients[""]; c != nil {
		return c, nil
	}
	// balanced and fast do not go through tor at all, so there is nothing to
	// wait for and no dialer to build.
	c := directNostrClient()
	cachedNostrClients[""] = c
	log.Printf("nostr: direct client (%s mode, not via tor)", currentMode())
	return c, nil
}

// the lane's client over tor's socks listener, on any route
func torClientFor(lane string) (*http.Client, error) {
	cachedNostrClientMu.Lock()
	defer cachedNostrClientMu.Unlock()
	// "" is the direct client's
	key := lane
	if key == "" {
		key = "tor"
	}
	if c := cachedNostrClients[key]; c != nil {
		return c, nil
	}
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil {
		return nil, fmt.Errorf("tor not started")
	}
	d, err := torDialerAs(context.Background(), t, laneName(lane))
	if err != nil {
		return nil, fmt.Errorf("tor dialer: %v", err)
	}
	c := torLaneClient(d.DialContext)
	cachedNostrClients[key] = c
	log.Printf("nostr: %s client built over tor's socks listener", laneKind(lane))
	return c, nil
}

// a lane's client over tor
func torLaneClient(dial func(ctx context.Context, network, addr string) (net.Conn, error)) *http.Client {
	return &http.Client{
		Transport: &http.Transport{
			DialContext:           dial,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 10 * time.Second,
		},
		Timeout:       60 * time.Second,
		CheckRedirect: noRedirect,
	}
}

// a relay, the gif service and the registry answer where they are asked: a
// redirect is not followed to another host
func noRedirect(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }

func nostrPublishMulti(ctx context.Context, lane string, ev nostr.Event) (ok int) {
	for {
		routeC := routeEnded()
		ok = nostrPublishOn(ctx, lane, ev, routeC)
		if ok > 0 || ctx.Err() != nil || !routeGone(routeC) {
			return ok
		}
		// the mode changed under it: out again on the new list, the new way
		log.Printf("nostr: the route changed during a publish, sending again")
	}
}

// one fan-out over the relays of the route routeC belongs to. a relay whose
// client comes from a newer route, or whose publish is still going when the
// route ends, is left out
func nostrPublishOn(ctx context.Context, lane string, ev nostr.Event, routeC <-chan struct{}) (ok int) {
	all := relaysInUse(ctx)

	// our relay's entries are never left out: it carries the traffic and the
	// tor watchdog already covers it going away.
	own := map[string]bool{}
	for _, u := range ownRelays(all) {
		own[u] = true
	}
	urls := make([]string, 0, len(all))
	for _, u := range all {
		// an entry of our second store on the bench is left out only while
		// our first store answers: that one carries it, and the second is
		// given it once it answers again (topup). the first never is
		if (own[u] && !(relayCold(u) && secondStoreSpared(all, u))) || (!own[u] && !relayCold(u)) {
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
	// which stores took it, and whether anyone did, for the top-up
	var tookMu sync.Mutex
	took := map[string]bool{}
	anyTook, tookPublic := false, false
	stores := storesIn(all)
	for _, url := range urls {
		go func(u string) {
			began := time.Now()
			// last publisher out turns off the lights (frees bg). a store
			// none of whose entries took it gets it once it answers
			defer func() {
				if atomic.AddInt32(&pending, -1) == 0 {
					bgCancel()
					tookMu.Lock()
					var missed []string
					for _, st := range stores {
						if anyTook && !took[st] {
							missed = append(missed, st)
						}
					}
					public, took := tookPublic, anyTook
					tookMu.Unlock()
					// every store has it: nothing will need it wrapped again.
					// a route that ended before anyone took it sends it again
					if len(missed) == 0 && (took || !routeGone(routeC)) {
						forgetSeal(ev.ID.Hex())
					}
					if !routeGone(routeC) {
						for _, st := range missed {
							topupAdd(st, lane, ev)
						}
						// on fast, a send our first store missed also goes to
						// the public relays through tor, as a private sender's
						// does: private readers and versions before the second
						// store read the first store and those alone
						if containsStr(missed, storeFirst) && !public {
							go publishToBackups(lane, ev, routeC)
						}
					}
				}
			}()
			client, err := relayClientFor(lane, u)
			if err != nil {
				log.Printf("nostr: tor not ready, skipping publish to %s: %v", u, err)
				result <- false
				return
			}
			// the list is the old mode's and the client may be the new one's
			if routeGone(routeC) {
				result <- false
				return
			}
			pctx, pcancel := onRoute(bg, routeC)
			defer pcancel()
			gen := routeGeneration()
			err = publishTo(pctx, lane, u, client, ev)
			// the relay has this event already: a copy sent before landed
			if relayHasIt(err) {
				err = nil
			}
			if err != nil {
				log.Printf("nostr: publish %s: %v", u, err)
				if !routeGone(routeC) {
					if relayAnswered(err) {
						// tor carried the question and the answer
						routeAliveOn(gen, u)
						relayRefused(u, began, err)
					} else {
						relayFailed(u, began)
					}
				}
				result <- false
				return
			}
			if !isBackup(u) {
				routeAliveOn(gen, u)
			}
			noteRelayMs(u, time.Since(began))
			tookMu.Lock()
			anyTook = true
			if st := storeOf(all, u); st != "" {
				took[st] = true
			} else {
				tookPublic = true
			}
			tookMu.Unlock()
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

// asks relay u a question and, when it answers, takes the answer as proof
// of the route generation the question was asked in
func probeProves(u string, ask func() bool) bool {
	gen := routeGeneration()
	if !ask() {
		return false
	}
	routeAliveOn(gen, u)
	return true
}

// how long a runner waits for tor before it tries again
var torRetryWait = 10 * time.Second

// run a long-lived subscription against all configured relays for what
// lands on pair c's receive address rcvPk, tagged [tag] (its subscription
// key). dedupes across relays. exits when ctx is cancelled.
func nostrSubscribeRunner(ctx context.Context, tag string, c convPair, rcvPk string) {
	// the addresses of a batch share a socket per relay, a hidden chat's
	// keeps one of its own on a lane of its own
	hidden := hiddenOf(ctx)
	if !hidden {
		ctx = shareOn(ctx, identGroup(c.ident))
	}
	nostrSubscribeRunnerAt(ctx, c.listenLaneAs(rcvPk, hidden), tag, rcvPk, c.unwrapStamped)
}

// a first-contact address: what lands on it is opened with its key alone
func nostrSubscribeRunnerFc(ctx context.Context, tag, fcSk, fcPk string) {
	nostrSubscribeRunnerAt(ctx, laneFirstContact, tag, fcPk, func(gw nostr2.Event) (string, nostr2.Timestamp, error) {
		content, sealPk, at, err := nip17UnwrapFirstContactWithStamped(fcSk, gw)
		return helloLine(content, sealPk), at, err
	})
}

// a hello (KHL1, base64) on the v3 first-contact address goes to the app
// with the key its seal was signed with, which the app checks;
// anything else as it came
func helloLine(content, sealPk string) string {
	if strings.HasPrefix(content, khl1B64) {
		return "khl:" + sealPk + "|" + content
	}
	return content
}

// what base64 of "KHL1" starts with
const khl1B64 = "S0hMMQ"

// the general runner: one receive address, one way to open what lands on
// it, one tag the inbox line carries so dart knows who it was for, and the
// lane whose circuits it may use.
func nostrSubscribeRunnerFn(ctx context.Context, lane, tag string, rcvPk string, unwrap func(nostr2.Event) (string, error)) {
	nostrSubscribeRunnerAt(ctx, lane, tag, rcvPk, func(gw nostr2.Event) (string, nostr2.Timestamp, error) {
		content, err := unwrap(gw)
		return content, 0, err
	})
}

// the same, with the stamp the sender put inside the wrap handed on with
// each line: the outer stamps are made up, that one is their clock
func nostrSubscribeRunnerAt(ctx context.Context, lane, tag string, rcvPk string, unwrap func(nostr2.Event) (string, nostr2.Timestamp, error)) {
	runnersLive.Add(1)
	defer runnersLive.Add(-1)
	urls := relaysWhenSet(ctx)
	if ctx.Err() != nil {
		return
	}
	// the public relays fast falls back on, read only while none of ours
	// answers, see stores.go
	backups := backupsNow()

	// remember ids and the high-water timestamp on disk so a relaunch picks
	// up where it left off rather than refetch the whole window.
	seenPath := ""
	lastPath := ""
	// each of our stores keeps its own anchor: a wrap only one of them holds
	// is never stepped over because the other moved on. the public relays
	// go with the first store's, as they always did; the backups have one of
	// their own that nothing is written for
	type storeAnchor struct {
		saved int64
		// what the file holds, -1 while there is none
		onDisk int64
		path   string
		keys   []string
		// no file yet: its first walk is the whole store
		fresh bool
	}
	stores := storesIn(urls)
	if len(stores) == 0 {
		stores = []string{storeFirst}
	}
	anchors := map[string]*storeAnchor{}
	for _, st := range stores {
		anchors[st] = &storeAnchor{onDisk: -1, keys: storeCatchupKeys(urls, st, rcvPk)}
	}
	const anchorBackup = "backup"
	var lastMu sync.Mutex
	if savedDataDir() != "" {
		seenPath, lastPath = addressFiles(rcvPk)
		// a subscription on an address let go of before keeps files again
		for _, p := range []string{seenPath, seenPath + ".tmp", lastPath, heardFile(rcvPk), heardFile(rcvPk) + ".tmp"} {
			goneFiles.Delete(p)
		}
		loadHeard(rcvPk)
		for _, st := range stores {
			a := anchors[st]
			a.path = storeLastPath(lastPath, st)
			goneFiles.Delete(a.path)
			if b, err := os.ReadFile(a.path); err == nil {
				if v, perr := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64); perr == nil {
					a.onDisk = v
					a.saved = anchorNow(v, time.Now())
				}
			} else if st == storeSecond {
				// the second store with no file yet walks all it holds, which
				// is nothing from before the day it went live: what it alone
				// took before this phone first read it is in there
				a.fresh = true
				a.saved = anchorNow(secondLiveAt, time.Now())
			}
		}
	}
	firstKey := stores[0]
	if anchors[storeFirst] != nil {
		firstKey = storeFirst
	}
	first := anchors[firstKey]
	// the backups start from the newest any store has got to
	backupAnchor := int64(0)
	for _, a := range anchors {
		backupAnchor = max(backupAnchor, a.saved)
	}
	// each file is no later than anything its store owed before, so it
	// holds from there until a pass on it is clean. the list is this
	// runner's for good, and so are our stores' entries in it
	for _, st := range stores {
		a := anchors[st]
		catchupStart(a.keys, nostr.Timestamp(a.saved), nostr.Timestamp(time.Now().Unix()))
	}
	seen := loadSeen(seenPath)
	seenWhileRunning(ctx, seen)
	// the anchor as this runner found it, before our relay moves it
	startAnchor := first.saved
	// a contact's address is ranked for the public relays, see public_live.go.
	// one just added counts as heard now and is live until the next start
	var live *liveAddr
	if rankedLane(lane) {
		heard := first.saved
		if freshOf(ctx) != nil {
			heard = time.Now().Unix()
		}
		live = liveJoin(rcvPk, heard, freshOf(ctx) != nil)
		go func() {
			<-ctx.Done()
			liveLeave(rcvPk, live)
		}()
	}
	ownURLs := ownRelays(urls)
	if live != nil {
		for _, u := range append(slices.Clone(urls), backups...) {
			if !slices.Contains(ownURLs, u) {
				heardInMemory(catchupKey(u, rcvPk))
			}
		}
	}
	// runners share the anchor and read it back, or a relay that never sees
	// a new event stays pinned to the launch window for the whole process.
	loadLast := func(st string) int64 {
		lastMu.Lock()
		defer lastMu.Unlock()
		if st == anchorBackup {
			return anchorNow(backupAnchor, time.Now())
		}
		a := anchors[st]
		if a == nil {
			a = first
		}
		return anchorNow(a.saved, time.Now())
	}

	// the anchor only moves forward. the file follows it whenever the two
	// differ, which also puts back one that was later than now and leaves a
	// file once an address has been caught up. it stays at or below what its
	// store still owes: after a restart no walk is remembered, and its first
	// window comes from the file. so whenever a walk is left owing,
	// saveLast(0) takes the file down to it at once. it stays at or below
	// every line the app has not kept yet too, and moves up once it has.
	saveLast := func(st string, ts int64) {
		lastMu.Lock()
		defer lastMu.Unlock()
		if st == anchorBackup {
			backupAnchor = max(backupAnchor, ts)
			return
		}
		a := anchors[st]
		if a == nil {
			a = first
		}
		if ts > a.saved {
			a.saved = ts
		}
		disk := a.saved
		if f, held := catchupFloor(a.keys); held && int64(f) < disk {
			disk = int64(f)
		}
		// nor past what the app has not kept yet: a death before it does
		// fetches that again from the file
		if f, owed := owedFloor(seen); owed && int64(f) < disk {
			disk = int64(f)
		}
		if a.path == "" || disk == a.onDisk || engineHeld.Load() {
			return
		}
		seenFileMu.Lock()
		defer seenFileMu.Unlock()
		if fileGone(a.path) {
			return
		}
		if os.WriteFile(a.path, []byte(strconv.FormatInt(disk, 10)), 0600) == nil {
			a.onDisk = disk
		}
	}
	// every file looks again, as the app keeps lines
	saveAll := func(int64) {
		for _, st := range stores {
			saveLast(st, 0)
		}
	}

	// fresh: the id was new here, which is what the catch-up counts to know
	// it is still finding things. opened: it unwrapped and went to the inbox,
	// now or on an earlier pass, and only that may move the anchor. the
	// relay library has already checked that the id is the event's own, so
	// an id that opened once comes with the stamp it opened with. from and
	// until: when it reached the relay, in ms by this clock, as far as the
	// way it came tells (inboxDone)
	// bare: it came from a public relay, whose reach the disk keeps none of
	take := func(ev nostr.Event, from, until int64, bare bool) (fresh, opened bool) {
		id := ev.ID.Hex()
		nostrMu.Lock()
		mine := nostrSentIDs[id]
		nostrMu.Unlock()
		if mine {
			return false, false
		}
		if !seen.claim(ev.ID) {
			// the app took it before, maybe in a process before this one,
			// or has it on the way from another store. it moves the anchor
			// again, of this store too, or after a restart the anchor stays
			// at the file until the contact sends something new
			return false, seen.taken(ev.ID)
		}
		var gw nostr2.Event
		if err := easyjson.Unmarshal([]byte(ev.String()), &gw); err != nil {
			log.Printf("nostr: wrap parse failed: %v", err)
			seen.notOpened(ev.ID)
			return true, false
		}
		content, sent, err := unwrap(gw)
		if err != nil {
			log.Printf("nostr: unwrap dropped one: %v", err)
			seen.notOpened(ev.ID)
			return true, false
		}
		lastEvMu.Lock()
		lastEvAt = int64(ev.CreatedAt)
		lastEvRecv = time.Now().Unix()
		lastEvMu.Unlock()
		noteRecv()
		if live != nil {
			liveHeard(rcvPk, time.Now().Unix())
		}
		if tag == laneFirstContact {
			startSteps.fcIn()
		}
		nostrMu.Lock()
		nostrInbox = append(nostrInbox, tag+"|"+content)
		nostrInboxDone = append(nostrInboxDone, inboxDone{set: seen, id: ev.ID, at: ev.CreatedAt, sent: int64(sent), resave: saveAll, from: from, until: until, bare: bare})
		nostrMu.Unlock()
		short := tag
		if len(short) > 12 {
			short = short[:12]
		}
		log.Printf("nostr: received event %s for %s...", id[:12], short)
		return true, true
	}
	// what an ask by ids brings was held: it reached the relay when it
	// first came, as far as that was known, or at any time before now
	byIDsOn := func(bare bool) func(nostr.Event) bool {
		return func(ev nostr.Event) bool {
			from, until := seen.heldReach(ev.ID)
			if until <= 0 {
				from, until = 0, time.Now().UnixMilli()
			}
			fresh, _ := take(ev, from, until, bare)
			return fresh
		}
	}

	for _, url := range append(slices.Clone(urls), backups...) {
		// the first entry of each of our stores carries its traffic: heal
		// it hard
		own := storeLead(urls, url)
		backup := !slices.Contains(urls, url)
		runnersLive.Add(1)
		go func(u string) {
			defer runnersLive.Add(-1)
			// one of our stores' entries
			ownEntry := slices.Contains(ownURLs, u)
			// whose anchor this relay reads and moves
			anchorKey := storeOf(urls, u)
			if anchorKey == "" {
				anchorKey = firstKey
			}
			if backup {
				anchorKey = anchorBackup
			}
			loadLast := func() int64 { return loadLast(anchorKey) }
			saveLast := func(ts int64) { saveLast(anchorKey, ts) }
			// the keys of this relay's store: a pass on one lets only these go
			storeKeys := []string(nil)
			if ownEntry {
				storeKeys = anchors[anchorKey].keys
			}
			// a wait a kick ends early, and so does the runner's end. ours
			// also wake when none of ours answers any more
			nap := func(d time.Duration) { napFor(ctx, d, ownEntry) }
			// the second store's first walk of every address, at its own
			// time: an update does not walk all of it for everyone at once
			if ownEntry && storeLead(urls, u) && anchors[anchorKey].fresh {
				if d := secondFirstWalk(); d > 0 {
					t := time.NewTimer(d)
					select {
					case <-ctx.Done():
						t.Stop()
						return
					case <-t.C:
					}
				}
			}
			if tag == laneFirstContact {
				fcRelaysLive.Add(1)
				defer fcRelaysLive.Add(-1)
			}
			// this subscription's catch-up record, apart from every other
			// contact's on the same relay
			ck := catchupKey(u, rcvPk)
			// counted for the width of a wake's turns
			socks := &pubSockets
			if ownEntry {
				socks = &ownSockets
			}
			socks.Add(1)
			defer socks.Add(-1)
			last := nostr.Timestamp(loadLast())
			retry := 10 * time.Second
			rejoin := 5 * time.Second
			deaf := 4 * time.Minute
			kicked := false
			// connections in a row the relay closed within youngConn
			youngDrops := 0
			// the last moment this runner knew its subscription was alive: a
			// successful subscribe, an event, a probe answered. the gap from
			// there decides how much the next subscribe asks for. wall clock
			// on purpose: go's monotonic clock stops while the phone is
			// asleep, and a night asleep is exactly the gap this has to see.
			var lastAlive time.Time
			// the route generation the live connection was made in
			connGen := int64(-1)
			markAlive := func() {
				lastAlive = time.Now().Round(0)
				relayUp(u)
				if connGen >= 0 {
					routeAliveOn(connGen, u)
				}
			}
			if own {
				retry = 3 * time.Second
				rejoin = 2 * time.Second
				deaf = 75 * time.Second
			}
			// past the cap, the address reads this public relay now and
			// then instead of holding a socket on it. sweeping: the
			// connection now is such a read. swept: one ended. cuts: reads
			// in a row that ended before their catch-up did
			sweeper := live != nil && !ownEntry
			// by ownClock: sleep counts, and a clock set back or ahead moves
			// nothing. 0 until the first is drawn
			var nextSweep time.Duration
			sweeping, swept := false, false
			cuts := 0
			// the next read was drawn in the round for our relay down
			drawnDown := false
			// an attempt on our relay failed, while tor could carry it
			ownMiss := func() {
				if ownEntry && !(modeNeedsTor() && !torReadyNow()) {
					ownRelayFailed()
					storeFailed(anchorKey)
				}
			}
			turn := subTurn{tag: tag, fresh: freshOf(ctx), own: ownEntry}
			defer turn.done()
			// the socket this address shares, if it shares one: its turn ends
			// once another address got it up
			hk := hubKey{lane: lane, group: shareOf(ctx), url: u}
			if hk.group != "" {
				turn.ready = func() <-chan struct{} { return hubReady(hk) }
				turn.batch = &hk
				startSteps.member(lane, rcvPk)
			}
			for {
				// nothing is counted while it parks or waits for tor below:
				// the turn counts again from take
				turn.done()
				select {
				case <-ctx.Done():
					return
				default:
				}
				sweeping = false
				// a backup is read only while our first store is down and tor
				// carries. the wait ends when either changes
				if backup {
					wake, torMoved := liveWakeChan(), torWakeChan()
					if !backupsOn() {
						t := time.NewTimer(backupLook)
						select {
						case <-ctx.Done():
							t.Stop()
							return
						case <-wake:
						case <-torMoved:
						case <-t.C:
						}
						t.Stop()
						continue
					}
				}
				// both channels before the look, so a change of the round or
				// a kick right after it still wakes the wait
				onPub, kc0 := true, kickChan()
				var settle time.Duration
				var wake <-chan struct{}
				if sweeper {
					onPub, settle, wake = livePlace(rcvPk)
				}
				if settle > 0 {
					// the start's addresses are still joining: the list is
					// chosen once they are in
					sleepOrKickCtx(ctx, kc0, settle)
					continue
				}
				if !onPub {
					now := ownClock()
					down := ownRelayDown()
					switch {
					case nextSweep == 0:
						nextSweep, drawnDown = now+firstSweepDelay(), down
					case down && !drawnDown:
						// our relay went down: this address's next read comes
						// at its own time in the short round, if that is sooner
						nextSweep = min(nextSweep, now+firstSweepDelay())
						drawnDown = true
					case !down && drawnDown:
						// ours is back: the short round's reads are dropped, the
						// next comes at its own time in the usual one
						nextSweep, drawnDown = now+firstSweepDelay(), false
					}
					if wait := nextSweep - now; wait > 0 {
						if h := sweepWaitHook; h != nil {
							h()
						}
						// a kick only looks at the clock again
						t := time.NewTimer(wait)
						select {
						case <-ctx.Done():
							t.Stop()
							return
						case <-wake:
						case <-kc0:
						case <-t.C:
						}
						t.Stop()
						continue
					}
					sweeping = true
				}
				// taken before the list and the client, so both are of one
				// mode: a switch after this ends what it dials
				routeC := routeEnded()
				// a mode switch took this relay off the list. the app starts
				// every runner again on the new one; until it gets here this
				// one must not dial it, least of all in the clear
				if !relayListed(ctx, u) {
					if ctx.Err() == nil {
						log.Printf("nostr: %s is off the relay list, not dialled again", u)
					}
					return
				}
				// tor is down because it was asked to be, or there is no
				// network. do not poll for it every ten seconds: the kick that
				// follows a resume or the network coming back wakes this.
				kc := kickChan()
				if modeNeedsTor() && (torIsPaused() || netAway()) {
					if h := runnerParkHook; h != nil {
						h()
					}
					// it asks at the wake now, not at the add
					turn.fresh = nil
					sleepOrKickCtx(ctx, kc, 15*time.Minute)
					continue
				}
				// a public relay on the bench: its bench first
				if !ownEntry && !backup && time.Until(relayCoolUntil(u)) > 0 {
					if !waitOutBench(ctx, u) {
						return
					}
					continue
				}
				// at the start, a dial through tor waits for tor to be up:
				// its turn is drawn from there, not held in tor with the rest
				if g := startGateChan(); g != nil && relayOverTor(lane, u) {
					turn.fresh = nil
					select {
					case <-ctx.Done():
						return
					case <-g:
					case <-kc:
					}
					continue
				}
				client, err := relayClientFor(lane, u)
				if err != nil {
					// it asks as tor comes up, beside the start's first
					// socket, not at the add
					turn.fresh = nil
					wait := torRetryWait
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
						go reconnectTorFor(whyDialer)
						nap(30 * time.Second)
						continue
					}
					// tor is on its way at the start: up to it, not ten seconds
					if g := startGateChan(); g != nil {
						select {
						case <-ctx.Done():
							return
						case <-g:
						case <-kc:
						}
						continue
					}
					nap(wait)
					continue
				}
				if !turn.take(ctx) {
					return
				}
				// the client may be the new mode's, the relay the old list's
				select {
				case <-routeC:
					turn.done()
					continue
				default:
				}
				// a relay on a failing streak takes one dial at a time: while
				// another socket's dial to it is out, this try counts as failed
				// and waits its own backoff, so a dead relay costs one dial a
				// round and not one per socket. joining a shared socket that
				// is up is no dial
				goDial, dialOver := true, func() {}
				if hk.group == "" || !isClosed(hubReady(hk)) {
					goDial, dialOver = failingDialBegin(u)
				}
				if !goDial {
					turn.dialed(false)
					nap(relayRetryAfter(u, retryFor(u, retry, own), own))
					continue
				}
				// each connection has a context of its own, so the relay and
				// everything the library starts for it end with the connection
				// and not with the subscription. ending it closes the relay.
				conn, connDone := context.WithCancel(ctx)
				dialAt := time.Now()
				dialGen := routeGeneration()
				r, fresh, err := relayJoin(conn, hk, rcvPk, client, routeC, ownEntry)
				dialOver()
				turn.dialed(err == nil)
				if err != nil && routeGone(routeC) {
					connDone()
					nap(rejoin)
					continue
				}
				if err != nil {
					connDone()
					log.Printf("nostr: subscribe-connect %s: %v", u, err)
					ownMiss()
					if relayAnswered(err) {
						// turned away at the door, through a route that works
						routeAliveOn(dialGen, u)
						relayRefused(u, dialAt, err)
						// that was this round's read: every address past the
						// cap asking again at the backoff's pace is the pile
						// the relay turns away
						if sweeping {
							nextSweep, drawnDown = ownClock()+sweepDelay(), ownRelayDown()
							cuts = 0
						}
					} else {
						relayFailed(u, dialAt)
					}
					nap(relayRetryAfter(u, retryFor(u, retry, own), own))
					continue
				}
				// the mode changed while it dialled. nothing is asked on it
				select {
				case <-routeC:
					r.close()
					connDone()
					nap(rejoin)
					continue
				default:
				}
				// wall clock, like lastAlive: a connection that lived through a
				// night asleep lived
				connected := time.Now().Round(0)
				noteRelayConnect(u, ck, int(time.Since(dialAt).Milliseconds()))
				startSteps.relayUp()
				if tag == laneFirstContact {
					startSteps.fcUp(u)
				}
				connGen = routeGeneration()
				// a relay answered. this is the one fact the watchdog trusts.
				// a shared socket says so once it carried something lately
				if fresh {
					noteRelayConnected()
					routeAnswered(u, connGen)
				}
				// the anchor is what was saved, by this runner or another. it
				// is only saved once a catch-up has run to its end, so a
				// connection that dropped half way asks for the same window
				// again and not for the little that came after.
				last = nostr.Timestamp(loadLast())
				// our relay, still walking its window or owing one more
				// pass over it, takes the window from where that walk began
				cc := catchupConnect(ck, storeKeys, last, nostr.Timestamp(connected.Unix()))
				resumed, base := cc.Resumed, cc.Base
				// a public relay's window reaches back to what it is known to
				// have handed over, not only to the anchor: our relay moves
				// that with every wrap, and a read may come hours after a
				// wrap only this relay has. after a start nothing is known
				// yet: back to the anchor the runner started with. to the
				// quarter hour, or the since would carry this phone's clock
				if sweeper && base > 0 {
					reach := nostr.Timestamp(heardOf(ck) / 1000)
					if reach <= 0 {
						reach = nostr.Timestamp(startAnchor)
					}
					if reach > 0 && reach < base {
						base = reach / 900 * 900
					}
				}
				// a wrap can be a 16k base64 slice of a video, so a reconnect
				// seconds after the last one asks for twenty, not a hundred. a
				// cold start, or a gap long enough to have missed a
				// conversation, still asks for the lot.
				limit := 100
				if !lastAlive.IsZero() &&
					time.Now().Round(0).Sub(lastAlive) < 5*time.Minute {
					limit = 20
				}
				if resumed && limit > catchupResumeLimit {
					limit = catchupResumeLimit
				}
				f := nostr.Filter{
					Kinds: []nostr.Kind{1059},
					Tags:  nostr.TagMap{"p": []string{rcvPk}},
					Limit: limit,
				}
				// after the first connect only ask for what we missed
				if base > 0 {
					// wraps carry timestamps jittered up to ~10h into the past,
					// so pull the window back or a late-stamped fresh wrap gets
					// filtered out. the dedup layers eat the refetch.
					since := base - nostr.Timestamp(12*3600)
					if since > 0 {
						f.Since = since
					}
				}
				// the library fakes an eose after 7s of silence. a hundred
				// slices over tor take longer than that, and a fake one would
				// end the count below before the relay was done. so no
				// subscription here takes a fake one
				sub, err := r.subscribe(f)
				// what comes before the eose reached the relay before this
				// moment, and after what it is known to have handed over. a
				// shared socket may have held the req back until now
				subAt := time.Now().UnixMilli()
				if err != nil {
					log.Printf("nostr: subscribe %s: %v", u, err)
					connDone()
					ownMiss()
					relayFailed(u, dialAt)
					nap(relayRetryAfter(u, retry, own))
					continue
				}
				// our own relay's successes clear its failure count too
				relayOK(u)
				markAlive()
				// set once the catch-up ran to its end: from then on each
				// sign of life says the relay handed over all it took
				var covered atomic.Bool
				// our relay said something on this connection, not just took
				// the req: a listener with nothing behind it takes those too
				spoke := false
				aliveNow := func() {
					markAlive()
					if ownEntry {
						spoke = true
						ownRelayAnswered()
						storeAnswered(anchorKey)
					} else {
						pubRelayAnswered()
					}
					if covered.Load() {
						noteHeard(conn, u, rcvPk, time.Now(), false)
					}
				}
				// an answer speaks for the route the probe was asked on,
				// whenever the socket was dialled: a bump that tore nothing
				// down leaves it carrying
				// when the last probe was asked
				var asked time.Time
				probe := func() bool {
					asked = time.Now()
					if !probeProves(u, func() bool { return r.probe(conn, rcvPk) }) {
						return false
					}
					noteRelayMs(u, time.Since(asked))
					aliveNow()
					return true
				}
				caught := func() {
					covered.Store(true)
					noteHeard(conn, u, rcvPk, time.Now(), true)
				}
				// a walk's pages reach back below the first answer
				walked := func(ev nostr.Event) bool {
					fresh, _ := take(ev, heardOf(ck), time.Now().UnixMilli(), sweeper)
					return fresh
				}
				log.Printf("nostr: listening on %s for addr %s...", u, rcvPk[:12])
				// a dead tor circuit leaves the websocket open but mute: no
				// error, no channel close. quiet too long gets a probe, and a
				// reconnect if nothing answers; the since window refetches
				// whatever we missed.
				idle := time.NewTimer(quietFor(deaf))
				// a kick is answered after this socket's own delay
				var kickT *time.Timer
				var kickC <-chan time.Time
				stopKick := func() {
					if kickT != nil {
						kickT.Stop()
					}
					kickT, kickC = nil, nil
				}
				// the relay closed it, rather than a probe going unanswered
				dropped := false
				// stored events come newest first and stop at the relay's cap.
				// until the relay says that was all, count them and remember
				// the oldest: a full answer means there may be more behind it.
				// the anchor is held back until that has been fetched too.
				cctx, ccancel := context.WithCancel(conn)
				// held events let go of come by their ids: the window has
				// mostly moved past them. the poll keeps them together. asked
				// on connecting, and on a probe this socket makes anyway
				var asking atomic.Bool
				// closed once the ask made on connecting is over, nil for none
				var askDone chan struct{}
				askWanted := func() {
					ids := seen.wanted(time.Now())
					if len(ids) == 0 || !asking.CompareAndSwap(false, true) {
						return
					}
					walkBegins(tag)
					done := make(chan struct{})
					if askDone == nil {
						askDone = done
					}
					go func() {
						defer close(done)
						defer asking.Store(false)
						defer walkEnds(tag)
						if missing, answered := r.byIDs(cctx, rcvPk, ids, byIDsOn(sweeper)); answered {
							seen.notOnRelay(u, urls, missing)
						}
					}()
				}
				askWanted()
				firstAsk := askDone
				// counted while this connection is still fetching what it
				// missed, so a check-in knows when it may stop tor again
				atomic.AddInt32(&catchupActive, 1)
				atomic.AddInt64(&catchupStarted, 1)
				walkBegins(tag)
				noteCatchupStart(ck)
				var settleOnce, walkOnce, sweptOnce sync.Once
				var capT *time.Timer
				// closed once a read of a public relay has caught up: the
				// socket goes there, until the address's next read
				var caughtC chan struct{}
				if sweeping {
					caughtC = make(chan struct{})
				}
				// the select's copy, nil once it has been looked at
				sweptC := (<-chan struct{})(caughtC)
				// a backup closes once ours answer again
				var backupWake <-chan struct{}
				if backup {
					backupWake = liveWakeChan()
				}
				// a read closes once what it asked by ids is answered too, or
				// the ask gave up on its own quiet: the held ones may be on
				// this relay alone
				closeCaught := func() {
					if caughtC == nil {
						return
					}
					sweptOnce.Do(func() {
						go func() {
							if firstAsk != nil {
								<-firstAsk
							}
							close(caughtC)
						}()
					})
				}
				// the poll holds the address until the walk is out, not just
				// while a check-in waits for it, and no longer than the walk
				// keeps bringing something
				endHold := func() { walkOnce.Do(func() { walkEnds(tag) }) }
				holdT := time.AfterFunc(pageQuiet(), endHold)
				brought := func() { holdT.Reset(pageQuiet()) }
				settled := func() {
					settleOnce.Do(func() {
						if capT != nil {
							capT.Stop()
						}
						atomic.AddInt32(&catchupActive, -1)
						noteCatchupDone(ck, false)
					})
					holdT.Stop()
					endHold()
					closeCaught()
				}
				// nobody waits on one relay for longer than this. whichever
				// of the two fires first wins the Once, so a relay is either
				// finished or dropped, never both. a dropped walk still goes
				// on while the socket lives: a healthy one is not redialled
				// for a long time, and what lies below would wait for that.
				thisCap, longTurn := catchupCapFor(ck)
				if longTurn {
					log.Printf("nostr: %s dropped %d check-ins running, giving it %s this time",
						u, catchupDropsBeforeLong, catchupLongCap)
				}
				// where the first answer so far would be walked from, see
				// catchup.Below, while it is coming
				var firstOldest atomic.Int64
				var firstOpen atomic.Bool
				firstOpen.Store(true)
				capT = time.AfterFunc(thisCap, func() {
					settleOnce.Do(func() {
						if firstOpen.Load() {
							keepFirstAnswer(cc, nostr.Timestamp(firstOldest.Load()), time.Now())
							saveLast(0)
						}
						atomic.AddInt32(&catchupActive, -1)
						noteCatchupDone(ck, true)
					})
					// a read with no eose ends here, not as a live socket
					closeCaught()
				})
				eose := sub.EndOfStoredEvents
				stored := 0
				var oldest nostr.Timestamp
				first := catchup.NewAnswer(limit)
				var caughtUp int32
				var pending int64
				since := f.Since
				for {
					select {
					case ev, alive := <-sub.Events:
						if !alive {
							idle.Stop()
							stopKick()
							r.close()
							dropped = true
							if !spoke {
								ownMiss()
							}
							// the request itself was answered with CLOSED: a
							// relay that hands over nothing owes nothing
							if eose != nil && stored == 0 {
								select {
								case <-sub.ClosedReason:
									log.Printf("nostr: %s refused the subscription", u)
									catchupRefused(cc)
									saveLast(0)
								default:
								}
							}
							goto reconnect
						}
						aliveNow()
						if ev.ID.Hex() != "" {
							if eose != nil {
								brought()
								stored++
								first.Add(ev.CreatedAt)
								firstOldest.Store(int64(first.Below()))
								if oldest == 0 || ev.CreatedAt < oldest {
									oldest = ev.CreatedAt
								}
							}
							from, until := heardOf(ck), subAt
							if eose == nil {
								now := time.Now().UnixMilli()
								from, until = now, now
							}
							fresh, opened := take(ev, from, until, sweeper)
							if fresh && opened && eose == nil {
								liveCame(tag)
							}
							if opened {
								ts := anchorStamp(ev.CreatedAt, time.Now())
								if ts > last {
									last = ts
								}
								if atomic.LoadInt32(&caughtUp) == 1 {
									saveLast(int64(last))
								} else if int64(ts) > atomic.LoadInt64(&pending) {
									atomic.StoreInt64(&pending, int64(ts))
								}
							}
						}
						if !idle.Stop() {
							select {
							case <-idle.C:
							default:
							}
						}
						idle.Reset(quietFor(deaf))
					case <-eose:
						eose = nil
						firstOpen.Store(false)
						// an empty answer is one round trip
						if stored == 0 {
							noteRelayMs(u, time.Since(time.UnixMilli(subAt)))
						}
						if ownEntry {
							spoke = true
							ownRelayAnswered()
							storeAnswered(anchorKey)
						} else {
							pubRelayAnswered()
						}
						if stored < limit || oldest == 0 {
							// the whole window came in this one answer, the
							// stretches walked before included
							catchupDone(cc, false)
							atomic.StoreInt32(&caughtUp, 1)
							caught()
							saveLast(atomic.LoadInt64(&pending))
							noteCatchupPages(ck, 0, stored)
							settled()
							continue
						}
						log.Printf("nostr: %s answered with a full %d, paging back", u, stored)
						oldest = first.Below()
						// the file must not pass what the walk owes while it
						// is under way, the other relays' saves included
						catchupOwe(cc)
						saveLast(0)
						go func(from nostr.Timestamp) {
							defer settled()
							// carries this relay's place from last time, so a
							// backlog deeper than one window is walked in
							// pieces instead of re-walked from the top and
							// never finished.
							m := catchupMarkOf(ck)
							res, mark := catchup.Continue(cctx, func(pc context.Context, s, t nostr.Timestamp, n int) ([]nostr.Event, error) {
								return r.page(pc, rcvPk, s, t, n)
							}, since, from, catchupPage, catchupMaxPages, func(ev nostr.Event) bool {
								brought()
								return walked(ev)
							}, m)
							if res.Complete {
								catchupDone(cc, m.Started())
							} else {
								catchupCut(cc, mark)
								saveLast(0)
							}
							noteCatchupPages(ck, res.Pages, res.Fetched)
							log.Printf("nostr: %s paged back %d pages, %d events, %d new, complete=%v, resume=%d",
								u, res.Pages, res.Fetched, res.Fresh, res.Complete, res.Until)
							if !res.Complete {
								// stopped short on a socket that is still up, past
								// where it began. only a new connection carries on
								// from the mark, and this one may answer probes for
								// hours. one that got nowhere keeps its socket, or
								// a page never answered redials it for ever
								start := from
								if m.Started() && from <= m.Top && from > m.Cursor {
									start = m.Cursor
								}
								if cctx.Err() == nil && res.Until < start {
									r.close()
								}
								return
							}
							atomic.StoreInt32(&caughtUp, 1)
							caught()
							saveLast(atomic.LoadInt64(&pending))
						}(oldest)
					case <-backupWake:
						if backupsOn() {
							backupWake = liveWakeChan()
							continue
						}
						log.Printf("nostr: our first relay answers again, %s closed", u)
						idle.Stop()
						stopKick()
						r.close()
						goto reconnect
					case <-sweptC:
						sweptC = nil
						log.Printf("nostr: %s read for addr %s..., closed until the next round", u, rcvPk[:12])
						idle.Stop()
						stopKick()
						r.close()
						swept = true
						goto reconnect
					case <-idle.C:
						// quiet is what a conversation looks like nearly all of the
						// time, and cycling the sub re-runs the since window, which
						// after a media send is a hundred base64 chunks. ask a
						// question that fetches nothing instead: it costs a frame
						// and an eose, and a real eose proves the circuit still
						// carries data.
						if probe() {
							askWanted()
							idle.Reset(quietFor(deaf))
							continue
						}
						log.Printf("nostr: %s did not answer a probe, cycling the sub", u)
						ownMiss()
						stopKick()
						r.drop(asked)
						goto reconnect
					case <-kickChan():
						// the job knocks every fifteen minutes so sockets that
						// died while the phone was asleep come back inside its
						// short window. each socket answers after its own
						// delay, see kickSpread.
						//
						// a runner with no live subscription never gets here:
						// it is asleep in its nap and still reconnects at
						// once, which is the case the kick exists for.
						if kickC == nil {
							kickT = time.NewTimer(kickDelayFor(ownEntry))
							kickC = kickT.C
							// a check-in waits for the probe, and for the
							// redial if it goes unanswered
							turn.hold()
						}
						turn.skip()
					case <-kickC:
						kickT, kickC = nil, nil
						// a socket that is still answering does not need
						// reviving, and dropping it costs a full since window
						// on every contact and every relay, so ask before
						// tearing down.
						if probe() {
							turn.probed(true)
							turn.done()
							log.Printf("nostr: %s kicked but still answering, keeping the sub", u)
							askWanted()
							if !idle.Stop() {
								select {
								case <-idle.C:
								default:
								}
							}
							idle.Reset(quietFor(deaf))
							continue
						}
						log.Printf("nostr: %s kicked, reconnecting now", u)
						turn.probed(false)
						ownMiss()
						idle.Stop()
						r.drop(asked)
						kicked = true
						goto reconnect
					case <-routeC:
						// the mode changed: this socket went the old way. the
						// app starts this runner again in a moment; one it
						// missed redials after the usual wait, the new way
						log.Printf("nostr: the route changed, %s closed", u)
						idle.Stop()
						stopKick()
						r.close()
						goto reconnect
					case <-ctx.Done():
						idle.Stop()
						stopKick()
						ccancel()
						settled()
						r.close()
						connDone()
						return
					}
				}
			reconnect:
				ccancel()
				settled()
				connDone()
				connGen = -1
				// a relay that answers and then closes is not redialled at
				// the same pace for ever. a connection that lived resets it
				if lived := time.Since(connected); lived >= youngConn {
					youngDrops = 0
				} else if dropped {
					youngDrops++
				}
				// a kick's hold lasts through its own redial only
				if !kicked {
					turn.done()
				}
				// the round counts from a read that caught up. one that ended
				// before is tried again within the round
				if sweeping {
					now := ownClock()
					if atomic.LoadInt32(&caughtUp) == 1 || cuts >= sweepRetries {
						nextSweep, cuts = now+sweepDelay(), 0
					} else {
						nextSweep = now + sweepRetryDelay()
						cuts++
					}
					drawnDown = ownRelayDown()
				}
				switch {
				case swept:
					// the loop's top waits for the next round
					swept = false
				case sweeping:
					// so does a read cut short
				case kicked:
					kicked = false
				case youngDrops > 0:
					nap(youngDropWait(u, rejoin, youngDrops, own))
				default:
					nap(rejoin)
				}
			}
		}(url)
	}
}

// the relays, comma separated, then after a | the backups: public relays
// read through tor only while none of ours answers (fast). the backups are
// set first, so a runner that sees the new list sees its backups too
//
//export HaloNostrInit
func HaloNostrInit(cRelaysCSV *C.char) *C.char {
	return C.CString(nostrInit(goStr(cRelaysCSV)))
}

func nostrInit(csv string) string {
	main, back, _ := strings.Cut(csv, "|")
	clean, backups := relayCSV(main), relayCSV(back)
	if len(clean) == 0 {
		return "error: no valid relay urls"
	}
	setBackups(backups)
	setRelays(clean)
	log.Printf("nostr: configured %d relays: %v, %d backups", len(clean), clean, len(backups))
	return "ok"
}

func relayCSV(csv string) []string {
	var out []string
	for _, u := range strings.Split(csv, ",") {
		if u = strings.TrimSpace(u); u != "" {
			out = append(out, u)
		}
	}
	return out
}

//export HaloNostrSend
func HaloNostrSend(cIdent C.int, cPeerXPubHex, cMsg *C.char) *C.char {
	return C.CString(nostrSend(identArg(cIdent), goStr(cPeerXPubHex), goStr(cMsg)))
}

// as HaloNostrSend, for a hidden chat: on the chat's own lane, over tor on
// every route, never on the everyday sends' circuit or from this phone's ip
//
//export HaloNostrSendHidden
func HaloNostrSendHidden(cIdent C.int, cPeerXPubHex, cMsg *C.char) *C.char {
	return C.CString(nostrSendAs(identArg(cIdent), goStr(cPeerXPubHex), goStr(cMsg), true))
}

// msg to peerHex from my identity [ident], on their pair's addresses
//
// [peerArg] names the pair as pairArg reads it
func nostrSend(ident int, peerArg, msg string) string {
	return nostrSendAs(ident, peerArg, msg, false)
}

func nostrSendAs(ident int, peerArg, msg string, hidden bool) string {
	c, peerHex, err := pairArg(ident, peerArg)
	if err != nil {
		if errors.Is(err, errBadPeer) {
			return "error: bad peer pubkey"
		}
		return fmt.Sprintf("error: wrap: %v", err)
	}
	// an opener address only listens: the opener goes with its seed
	if c.dev != nil && c.dev.opener {
		return "error: wrap: a device pair sends with its seed"
	}
	return nostrSendOn(c, msg, sendLane(c, peerHex, hidden))
}

// the lane a send to the pair goes on: a hidden chat's own, over tor on
// every route, when the app says the chat is hidden or the pair is
// listened on as one; the everyday sends' lane for the rest. "" when a
// hidden chat's lane cannot be found: such a send does not go at all
func sendLane(c convPair, peerHex string, hidden bool) string {
	nostrMu.Lock()
	hidden = hidden || nostrHiddenSubs[c.subKey(peerHex)]
	nostrMu.Unlock()
	if !hidden {
		return laneEveryday
	}
	_, rcvPk, err := c.rcvAddress()
	if err != nil {
		return ""
	}
	return hiddenLane(rcvPk)
}

func nostrSendOn(c convPair, msg, lane string) string {
	if lane == "" {
		return "error: wrap: no lane for a hidden chat"
	}
	gw, err := c.wrap(msg)
	if err != nil {
		return fmt.Sprintf("error: wrap: %v", err)
	}
	// the wrap is built with the nip59 lib's event type; cross into the relay
	// lib as plain json. id and sig survive verbatim, both speak nip-01.
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		return fmt.Sprintf("error: wrap convert: %v", err)
	}
	nostrMu.Lock()
	nostrSentIDs[ev.ID.Hex()] = true
	if len(nostrSentIDs) > 4096 {
		nostrSentIDs = map[string]bool{}
	}
	nostrMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), publishWait)
	defer cancel()
	ok := nostrPublishMulti(ctx, lane, ev)
	if ok == 0 {
		return "error: no relays accepted"
	}
	// log the drop-box we published to. if a peer isn't receiving, compare this
	// against the "at addr" in their subscribe line: a mismatch means the two
	// sides derived different addresses and nothing will ever arrive.
	dst, derr := c.theirAddress()
	if derr == nil {
		log.Printf("nostr: sent event %s to %d relays, addr %s...", ev.ID.Hex()[:12], ok, dst[:12])
	} else {
		log.Printf("nostr: sent event %s to %d relays", ev.ID.Hex()[:12], ok)
	}
	return "ok"
}

//export HaloNostrSubscribe
func HaloNostrSubscribe(cIdent C.int, cPeerXPubHex *C.char) *C.char {
	return C.CString(nostrSubscribe(identArg(cIdent), goStr(cPeerXPubHex), false))
}

// as HaloNostrSubscribe, for someone the user just added or accepted: the
// first turn of each socket is free (subTurn.fresh)
//
//export HaloNostrSubscribeNew
func HaloNostrSubscribeNew(cIdent C.int, cPeerXPubHex *C.char) *C.char {
	return C.CString(nostrSubscribe(identArg(cIdent), goStr(cPeerXPubHex), true))
}

// as HaloNostrSubscribe, for a hidden chat: its address keeps a socket and
// a tor circuit of its own on every relay and every route, never one it
// shares with the everyday chats
//
//export HaloNostrSubscribeHidden
func HaloNostrSubscribeHidden(cIdent C.int, cPeerXPubHex *C.char) *C.char {
	return C.CString(nostrSubscribeAs(identArg(cIdent), goStr(cPeerXPubHex), false, true))
}

// both: a hidden chat just added or accepted
//
//export HaloNostrSubscribeHiddenNew
func HaloNostrSubscribeHiddenNew(cIdent C.int, cPeerXPubHex *C.char) *C.char {
	return C.CString(nostrSubscribeAs(identArg(cIdent), goStr(cPeerXPubHex), true, true))
}

// listen on my identity [ident]'s receive address for peerHex
func nostrSubscribe(ident int, peerArg string, fresh bool) string {
	return nostrSubscribeAs(ident, peerArg, fresh, false)
}

// hidden: a hidden chat's, see HaloNostrSubscribeHidden
func nostrSubscribeAs(ident int, peerArg string, fresh, hidden bool) string {
	c, peerHex, err := pairArg(ident, peerArg)
	if err != nil {
		if errors.Is(err, errBadPeer) {
			return "error: bad peer pubkey"
		}
		return fmt.Sprintf("error: derive: %v", err)
	}
	rcvSk, rcvPk, err := c.rcvAddress()
	if err != nil {
		return fmt.Sprintf("error: derive: %v", err)
	}
	nostrSubscribeAt(c, peerHex, rcvSk, rcvPk, fresh, hidden)
	return "ok"
}

// a runner for the pair's address, in place of any running one. the main
// identity's go by the peer's key, as before; another's say whose they are,
// and the knocks take their address as noted
func nostrSubscribeAt(c convPair, peerHex, rcvSk, rcvPk string, fresh, hidden bool) {
	key := c.subKey(peerHex)
	// every identity's, the main one's too: the knocks take the address
	// the subscription was made on, never one derived again
	// a hidden chat's knocks go on its own lane too, never in a batch's
	// registration
	lane := c.listenLaneAs(rcvPk, hidden)
	noteKnockTarget(key, knockTarget{rcvPk, rcvSk, lane, lane, strings.ToLower(peerHex)})
	nostrMu.Lock()
	if cancel, exists := nostrSubs[key]; exists {
		cancel()
		delete(nostrSubs, key)
	}
	ctx, cancel := context.WithCancel(context.Background())
	nostrSubs[key] = cancel
	if hidden {
		nostrHiddenSubs[key] = true
	} else {
		delete(nostrHiddenSubs, key)
	}
	nostrMu.Unlock()
	if fresh {
		ctx = asFresh(ctx)
	}
	if hidden {
		ctx = asHidden(ctx)
	}
	if c.dev != nil {
		their, _ := c.theirAddress()
		noteDevListen(key, devListen{rcv: rcvPk, their: their, opener: c.dev.opener})
	}

	go nostrSubscribeRunner(ctx, key, c, rcvPk)
	log.Printf("nostr: subscribed for peer %s... at addr %s...", peerHex[:12], rcvPk[:12])
}

// what a full shelf left on the relay for a peer: "mark" lets it go on
// its own address alone, for its runner's next connection or probe;
// "free", for an accept, does that and fetches it now, by id, the
// first-contact address's too; "drop" takes it as kept. free and mark do
// nothing where nothing is held
//
//export HaloNostrLetHeld
func HaloNostrLetHeld(cIdent C.int, cPeerXPubHex, cHow *C.char) *C.char {
	if err := nostrLetHeld(identArg(cIdent), goStr(cPeerXPubHex), goStr(cHow)); err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString("ok")
}

// "mark" for each peer of a json list of {"i": identity, "x": x key}, on a
// start or an unlock:
// an accept that died before its fetch goes on at the peer's runner's
// next connection or probe. its own address only, where something is
// held, and nothing restarts
//
//export HaloNostrMarkHeld
func HaloNostrMarkHeld(cPeersJSON *C.char) *C.char {
	var peers []identPeer
	if err := json.Unmarshal([]byte(goStr(cPeersJSON)), &peers); err != nil {
		return C.CString("error: bad list")
	}
	nostrMarkHeld(peers)
	return C.CString("ok")
}

// the pinned chats, which keep live sockets on the public relays first,
// as a json list of {"i": identity, "x": x key}. they count from the next
// start or mode switch on, and stay in memory
//
//export HaloNostrPinned
func HaloNostrPinned(cPeersJSON *C.char) *C.char {
	var peers []identPeer
	if err := json.Unmarshal([]byte(goStr(cPeersJSON)), &peers); err != nil {
		return C.CString("error: bad list")
	}
	nostrPinned(peers)
	return C.CString("ok")
}

// each peer's receive address on the identity it is reached on
func peerAddresses(peers []identPeer) []string {
	var rcv []string
	for _, h := range peers {
		c, _, err := pairArg(h.I, h.arg())
		if err != nil {
			continue
		}
		if _, rcvPk, err := c.rcvAddress(); err == nil {
			rcv = append(rcv, rcvPk)
		}
	}
	return rcv
}

func nostrPinned(peers []identPeer) {
	livePin(peerAddresses(peers))
}

func nostrMarkHeld(peers []identPeer) {
	for _, rcvPk := range peerAddresses(peers) {
		if p, _ := addressFiles(rcvPk); heldOnFile(p) > 0 {
			markHeldFile(p, seenFreeMark)
		}
	}
}

// how many ids an address's file holds back. a file with no held line is
// not read twice
func heldOnFile(path string) int {
	if path == "" {
		return 0
	}
	b, err := os.ReadFile(path)
	if err != nil || !(strings.HasPrefix(string(b), seenHeldMark) || strings.Contains(string(b), "\n"+seenHeldMark)) {
		return 0
	}
	return loadSeen(path).heldCount()
}

func nostrLetHeld(ident int, peerArg, how string) error {
	if how != "free" && how != "drop" && how != "mark" {
		return errors.New("bad how")
	}
	c, peerHex, err := pairArg(ident, peerArg)
	if err != nil {
		return err
	}
	rcvSk, rcvPk, err := c.rcvAddress()
	if err != nil {
		return err
	}
	seenPath, _ := addressFiles(rcvPk)
	if how == "drop" {
		markHeldFile(seenPath, seenDropMark)
		return nil
	}
	nostrMu.Lock()
	_, on := nostrSubs[c.subKey(peerHex)]
	// a device pair never came through a first-contact address
	_, fcOn := nostrSubs["firstcontact"]
	fcOn = fcOn && c.dev == nil
	fc := fcCounterNow
	nostrMu.Unlock()
	fcPath := ""
	if fcOn && how == "free" {
		// the main identity's v3 first-contact address: what a stranger
		// sent before an accept lands there
		if me, err := identityOf(mainIdent); err == nil {
			if _, fcPk, err := nip17FirstContactKeysAs(me, fc); err == nil {
				fcPath, _ = addressFiles(fcPk)
			}
		}
	}
	// that lane is everyone's: whoever else it held is asked for again and
	// held again
	own, lane := heldOnFile(seenPath) > 0, heldOnFile(fcPath) > 0
	if own {
		markHeldFile(seenPath, seenFreeMark)
	}
	if lane {
		markHeldFile(fcPath, seenFreeMark)
	}
	if how == "mark" {
		return nil
	}
	if h := letHeldHook; h != nil {
		h()
	}
	// a runner reads the mark as it starts. free comes with an accept, so
	// it asks at once as the accept's own listen would
	if own && on {
		nostrMu.Lock()
		hidden := nostrHiddenSubs[c.subKey(peerHex)]
		nostrMu.Unlock()
		nostrSubscribeAt(c, peerHex, rcvSk, rcvPk, true, hidden)
	}
	if lane {
		// only the listener read above: a new invite address may have
		// replaced it since
		return restartFirstContact(fc)
	}
	return nil
}

// called before nostrLetHeld starts listeners again, for the tests
var letHeldHook func()

// stop listening for a peer, and take what its receive address kept on
// disk with it
//
//export HaloNostrUnsubscribe
func HaloNostrUnsubscribe(cIdent C.int, cPeerXPubHex *C.char) *C.char {
	if err := nostrUnsubscribe(identArg(cIdent), goStr(cPeerXPubHex)); err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString("ok")
}

func nostrUnsubscribe(ident int, peerArg string) error {
	if base, _, _ := strings.Cut(peerArg, "."); strings.Contains(base, "/") {
		return devUnsubscribe(ident, peerArg)
	}
	c, peerHex, err := pairArg(ident, peerArg)
	if err != nil {
		return err
	}
	key := c.subKey(peerHex)
	nostrMu.Lock()
	if cancel, exists := nostrSubs[key]; exists {
		cancel()
		delete(nostrSubs, key)
	}
	delete(nostrHiddenSubs, key)
	nostrMu.Unlock()
	if _, rcvPk, err := c.rcvAddress(); err == nil {
		dropAddressFiles(rcvPk)
	}
	// what waits to reach them on this identity goes with them
	if dst, err := c.theirAddress(); err == nil {
		topupPurgeAddr(dst)
	}
	return nil
}

// the public half of our first-contact address. goes in the invite so a
// stranger can reach us before either side knows the other's key.
//
// the main identity's v3 one, for the v3 links it hands out: any other
// identity's first-contact keys are random, one per invite (HaloFcKeyPk)
//
//export HaloFirstContactPk
func HaloFirstContactPk(cIdent C.int, counter C.int) *C.char {
	_, pk, err := mainFirstContactKeys(identArg(cIdent), int(counter))
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	return C.CString(pk)
}

// relay loops the first-contact listener runs now, old and new together
// for a moment while it is replaced. loops, not sockets: a loop dials its
// relay again by itself, so only a missing loop needs a new listener, and
// a phone offline would otherwise start one every minute
var fcRelaysLive atomic.Int32

// subscription runners and their relay loops still going, every lane
var runnersLive atomic.Int32

// how many relays the first-contact listener is on, -1 when there is none.
// a listener that started on an empty list is on none and hears nothing
//
//export HaloFirstContactRelays
func HaloFirstContactRelays() C.int { return C.int(firstContactRelays()) }

func firstContactRelays() int {
	nostrMu.Lock()
	_, on := nostrSubs["firstcontact"]
	nostrMu.Unlock()
	if !on {
		return -1
	}
	return int(fcRelaysLive.Load())
}

// watch our own first-contact address. unlike every other subscription this
// needs no contacts, which is the whole point: a fresh install with an empty
// roster can still be reached.
//
//export HaloNostrSubscribeFirstContact
func HaloNostrSubscribeFirstContact(cIdent C.int, counter C.int) *C.char {
	if err := subscribeFirstContact(identArg(cIdent), int(counter)); err != nil {
		return C.CString(fmt.Sprintf("error: derive: %v", err))
	}
	return C.CString("ok")
}

// the v3 first-contact keys of [ident] at [counter]: the main identity's
// only. nothing else has an address derived from its key
func mainFirstContactKeys(ident, counter int) (sk, pk string, err error) {
	if ident != mainIdent {
		return "", "", errors.New("only the main identity has a v3 first-contact address")
	}
	me, err := identityOf(mainIdent)
	if err != nil {
		return "", "", err
	}
	return nip17FirstContactKeysAs(me, counter)
}

func subscribeFirstContact(ident, counter int) error {
	if ident != mainIdent {
		return errors.New("only the main identity has a v3 first-contact address")
	}
	return firstContactOn(counter, false)
}

// the first-contact listener on counter started again, if it still runs
func restartFirstContact(counter int) error { return firstContactOn(counter, true) }

func firstContactOn(counter int, again bool) error {
	fcSk, fcPk, err := mainFirstContactKeys(mainIdent, counter)
	if err != nil {
		return err
	}

	nostrMu.Lock()
	old, replaced := nostrSubs["firstcontact"]
	if again && (!replaced || fcCounterNow != counter) {
		nostrMu.Unlock()
		return nil
	}
	if replaced {
		old()
		delete(nostrSubs, "firstcontact")
	}
	ctx, cancel := context.WithCancel(context.Background())
	nostrSubs["firstcontact"] = cancel
	fcCounterNow = counter
	nostrMu.Unlock()
	// the address that replaces it listens on a new circuit, so a relay
	// cannot tie the two together
	if replaced {
		dropLane(laneFirstContact)
	}

	go nostrSubscribeRunnerFc(ctx, "firstcontact", fcSk, fcPk)
	log.Printf("nostr: watching first-contact addr %s...", fcPk[:12])
	return nil
}

// introduce ourselves to someone who has never heard of us. the seal is
// signed with our usual per-conversation key, so once they know us the normal
// verification applies to everything after this.
//
//export HaloNostrSendFirstContact
func HaloNostrSendFirstContact(cIdent C.int, cPeerXPubHex, cFcPk, cMsg *C.char) *C.char {
	return C.CString(nostrSendFirstContact(identArg(cIdent), goStr(cPeerXPubHex), goStr(cFcPk), goStr(cMsg)))
}

func nostrSendFirstContact(ident int, peerArg, fcPk, msg string) string {
	c, _, err := pairArg(ident, peerArg)
	if errors.Is(err, errBadPeer) {
		return "error: bad peer pubkey"
	}
	if len(fcPk) != 64 {
		return "error: bad first-contact pubkey"
	}
	if err != nil {
		return fmt.Sprintf("error: wrap: %v", err)
	}
	gw, err := c.wrapFirstContact(fcPk, msg)
	if err != nil {
		return fmt.Sprintf("error: wrap: %v", err)
	}
	// the wrap comes from the nip59 lib's event type; cross into the relay
	// lib as plain json, same as the normal send path.
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		return fmt.Sprintf("error: wrap convert: %v", err)
	}
	nostrMu.Lock()
	nostrSentIDs[ev.ID.Hex()] = true
	if len(nostrSentIDs) > 4096 {
		nostrSentIDs = map[string]bool{}
	}
	nostrMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), publishWait)
	defer cancel()
	ok := nostrPublishMulti(ctx, laneHello, ev)
	if ok == 0 {
		return "error: no relays accepted"
	}
	log.Printf("nostr: sent first-contact %s to %d relays, addr %s...", ev.ID.Hex()[:12], ok, fcPk[:12])
	return "ok"
}

// drop every relay socket and reconnect now. returns "ok".
//
//export HaloNostrKick
func HaloNostrKick() *C.char {
	nostrKick()
	return C.CString("ok")
}

func nostrKick() {
	// a kick at a wake takes the wake's turns
	wakeCheck()
	kickRelays()
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

// what the relays delivered since the last poll, as {"k": token, "m": [...]}
// with one {"t": tag, "c": content} per event, or "" when there is nothing.
// the events in it are remembered as seen only once HaloNostrAck confirms
// them; a batch not confirmed by the next poll is offered again.
//
//export HaloNostrPoll
func HaloNostrPoll() *C.char {
	return C.CString(nostrPoll())
}

// the app has kept a batch from the poll: token is its "k", failed a json
// array of the places in its "m" the app could not keep, which are offered
// again, or {"f": those, "h": the places it leaves on the relay until it
// has room}. "ok", or "error: ..." with the batch left to come again.
//
//export HaloNostrAck
func HaloNostrAck(cToken, cFailed *C.char) *C.char {
	return C.CString(nostrAck(goStr(cToken), goStr(cFailed)))
}

func nostrPoll() string {
	return nostrPollAt(time.Now())
}

// a line offered this many times and never kept stops coming. it is not
// remembered as seen, so a copy fetched again, in this process or the next,
// is taken again
const pollMaxTries = 5

// batches handed to the app and not yet confirmed, by token. nostrMu
var (
	pollInflight = map[uint64]pollBatch{}
	pollToken    uint64
)

type pollBatch struct {
	lines []string
	done  []inboxDone
}

// lines back to the front of the inbox, in their order, each one try
// further on. nostrMu must be held
func pollRequeueLocked(lines []string, done []inboxDone) {
	var l []string
	var d []inboxDone
	for i, line := range lines {
		dn := done[i]
		dn.tries++
		if dn.tries >= pollMaxTries {
			log.Printf("nostr: a delivery the app never kept, left for the next start")
			if dn.set != nil {
				dn.set.release(dn.id)
			}
			continue
		}
		l = append(l, line)
		d = append(d, dn)
	}
	nostrInbox = append(l, nostrInbox...)
	nostrInboxDone = append(d, nostrInboxDone...)
}

// the oldest stamp among the lines of set the app has not kept yet, in the
// inbox or handed over and not confirmed
func owedFloor(set *seenIDs) (nostr.Timestamp, bool) {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	var low nostr.Timestamp
	owed := false
	see := func(done []inboxDone) {
		for _, d := range done {
			if d.set == set && (!owed || d.at < low) {
				low, owed = d.at, true
			}
		}
	}
	see(nostrInboxDone)
	for _, b := range pollInflight {
		see(b.done)
	}
	return low, owed
}

func nostrAck(token, failed string) string {
	tok, err := strconv.ParseUint(token, 10, 64)
	if err != nil {
		return "error: bad token"
	}
	bad, later, groups, err := ackLists(failed)
	if err != nil {
		return "error: bad list"
	}
	nostrMu.Lock()
	b, ok := pollInflight[tok]
	delete(pollInflight, tok)
	if !ok {
		// offered again already, the next ack covers it
		nostrMu.Unlock()
		return "ok"
	}
	again := map[int]bool{}
	for _, i := range bad {
		again[i] = true
	}
	left := map[int]string{}
	for j, i := range later {
		g := ""
		if j < len(groups) {
			g = groups[j]
		}
		left[i] = g
	}
	var kept, held []inboxDone
	var names, heldL []string
	var backL []string
	var backD []inboxDone
	for i, l := range b.lines {
		d := b.done[i]
		g, isHeld := left[i]
		switch {
		case again[i]:
			backL = append(backL, l)
			backD = append(backD, d)
		// let go of since it was polled: it goes to the app again
		case isHeld && d.set != nil && heldGen(d.set.path) != d.freed:
			backL = append(backL, l)
			backD = append(backD, d)
		case isHeld:
			held = append(held, d)
			names = append(names, g)
			heldL = append(heldL, l)
		default:
			kept = append(kept, d)
		}
	}
	pollRequeueLocked(backL, backD)
	nostrMu.Unlock()
	if h := ackHook; h != nil {
		h()
	}
	took, stale := markHeld(held, names, time.Now())
	markHandedOver(append(kept, took...))
	// let go of while this ran: to the app again, as above
	if len(stale) > 0 {
		var l []string
		var d []inboxDone
		for _, i := range stale {
			l = append(l, heldL[i])
			d = append(d, held[i])
		}
		nostrMu.Lock()
		pollRequeueLocked(l, d)
		nostrMu.Unlock()
	}
	return "ok"
}

// called between nostrAck's check and its holds, for the tests
var ackHook func()

// the app's list of places it could not keep, "[...]", or that list, the
// places it leaves on the relay until it has room and the group each of
// those is held in, {"f":[...],"h":[...],"g":[...]}
func ackLists(raw string) (failed, held []int, groups []string, err error) {
	if raw == "" {
		return nil, nil, nil, nil
	}
	if strings.HasPrefix(strings.TrimSpace(raw), "{") {
		var o struct {
			F []int    `json:"f"`
			H []int    `json:"h"`
			G []string `json:"g"`
		}
		err = json.Unmarshal([]byte(raw), &o)
		return o.F, o.H, o.G, err
	}
	err = json.Unmarshal([]byte(raw), &failed)
	return failed, nil, nil, err
}

// events the app left on the relay, each in the group named for it: held
// where there is room, the rest returned to be taken as kept. the anchor
// moves past them either way, a held one comes back by its id. stale: the
// places of those let go of since the poll, which are not held
func markHeld(done []inboxDone, names []string, now time.Time) (kept []inboxDone, stale []int) {
	saves := map[*seenIDs]func(int64){}
	for i, d := range done {
		if d.set == nil {
			kept = append(kept, d)
			continue
		}
		// how a public relay was read is not written: a live socket's
		// moment and a read's span would tell the two apart on disk
		from := d.from
		if d.bare {
			from = 0
		}
		held, late := d.set.holdSince(d.id, d.at, names[i], now, from, d.until, d.freed)
		if late {
			stale = append(stale, i)
			continue
		}
		if !held {
			kept = append(kept, d)
			continue
		}
		if d.resave != nil {
			saves[d.set] = d.resave
		}
	}
	for _, save := range saves {
		save(0)
	}
	return kept, stale
}

// a walk brings its stored wraps a page at a time, and each page is a random
// slice of the conversation. while an address is walked the poll keeps its
// lines back, so the app gets the whole of it at once and can put it in
// order. other addresses go over as they come. a walk that runs long, or
// brings a lot, goes over as it stands, and so does an address the moment
// a live wrap comes for it.
const (
	pollHoldMax   = 20 * time.Second
	pollHoldBytes = 8 << 20
)

// when the poll first kept lines back. nostrMu
var pollHeldSince time.Time

// addresses with a walk under way, by the tag their lines carry, one count
// per relay. nostrMu
var walkingTags = map[string]int{}

// held addresses a live wrap came for since the last poll. nostrMu
var liveTags = map[string]bool{}

func walkBegins(tag string) {
	nostrMu.Lock()
	walkingTags[tag]++
	nostrMu.Unlock()
}

func walkEnds(tag string) {
	nostrMu.Lock()
	if walkingTags[tag] <= 1 {
		delete(walkingTags, tag)
	} else {
		walkingTags[tag]--
	}
	nostrMu.Unlock()
}

// a live wrap for tag is in the inbox: what is held for it goes with it
func liveCame(tag string) {
	nostrMu.Lock()
	if walkingTags[tag] > 0 {
		liveTags[tag] = true
	}
	nostrMu.Unlock()
}

func lineTag(line string) string {
	if i := strings.IndexByte(line, '|'); i >= 0 {
		return line[:i]
	}
	return line
}

func nostrPollAt(now time.Time) string {
	nostrMu.Lock()
	// what the app took last time and never confirmed comes again first
	toks := make([]uint64, 0, len(pollInflight))
	for k := range pollInflight {
		toks = append(toks, k)
	}
	slices.Sort(toks)
	for i := len(toks) - 1; i >= 0; i-- {
		b := pollInflight[toks[i]]
		delete(pollInflight, toks[i])
		pollRequeueLocked(b.lines, b.done)
	}
	lines, done := nostrInbox, nostrInboxDone
	var kept []string
	var keptDone []inboxDone
	if len(walkingTags) > 0 && len(lines) > 0 {
		lines, done = nil, nil
		size := 0
		for i, l := range nostrInbox {
			tag := lineTag(l)
			if walkingTags[tag] > 0 && !liveTags[tag] {
				kept = append(kept, l)
				keptDone = append(keptDone, nostrInboxDone[i])
				size += len(l)
			} else {
				lines = append(lines, l)
				done = append(done, nostrInboxDone[i])
			}
		}
		if len(kept) > 0 && !pollHolds(now, size) {
			lines, done = nostrInbox, nostrInboxDone
			kept, keptDone = nil, nil
		}
	}
	clear(liveTags)
	nostrInbox, nostrInboxDone = kept, keptDone
	if len(kept) == 0 {
		pollHeldSince = time.Time{}
	}
	if len(lines) == 0 {
		nostrMu.Unlock()
		return ""
	}
	entries, took := pollEntriesOf(lines)
	for j, n := range took {
		entries[j].A = done[n].sent
		entries[j].F = done[n].from
		entries[j].U = done[n].until
	}
	// what cannot go over never will: remembered now, as before
	var gone []inboxDone
	var b pollBatch
	at := 0
	for i := range lines {
		if at < len(took) && took[at] == i {
			d := done[i]
			if d.set != nil {
				d.freed = heldGen(d.set.path)
			}
			b.lines = append(b.lines, lines[i])
			b.done = append(b.done, d)
			at++
		} else {
			gone = append(gone, done[i])
		}
	}
	var tok uint64
	if len(entries) > 0 {
		pollToken++
		tok = pollToken
		pollInflight[tok] = b
	}
	nostrMu.Unlock()
	markHandedOver(gone)
	if tok == 0 {
		return ""
	}
	// a batch can be megabytes, and every runner's take waits on nostrMu
	raw, err := json.Marshal(struct {
		K string      `json:"k"`
		M []pollEntry `json:"m"`
	}{strconv.FormatUint(tok, 10), entries})
	if err == nil {
		return string(raw)
	}
	nostrMu.Lock()
	if _, ok := pollInflight[tok]; ok {
		delete(pollInflight, tok)
		pollRequeueLocked(b.lines, b.done)
	}
	nostrMu.Unlock()
	return ""
}

// nostrMu must be held
func pollHolds(now time.Time, size int) bool {
	if pollHeldSince.IsZero() {
		pollHeldSince = now
	}
	return now.Sub(pollHeldSince) < pollHoldMax && size < pollHoldBytes
}

type pollEntry struct {
	T string `json:"t"`
	C string `json:"c"`
	// when the sender wrapped it, by their clock, in seconds: each send
	// wraps anew, so a retry has its own. 0 when the lane has no such stamp
	A int64 `json:"a,omitempty"`
	// when it reached the relay, in ms by this phone's clock: no earlier
	// than f and no later than u. live after the eose both are when it came;
	// a stored one is between what the relay was known to have handed over
	// and the subscribe. 0 for what is not known
	F int64 `json:"f,omitempty"`
	U int64 `json:"u,omitempty"`
}

// content with a line break or a nul is dropped: nothing the app sends
// carries one (signal is base64, frames are encoded json). each entry stands
// alone, so the others always arrive.
func pollJSON(lines []string) string {
	out, _ := pollEntriesOf(lines)
	if len(out) == 0 {
		return ""
	}
	b, err := json.Marshal(out)
	if err != nil {
		return ""
	}
	return string(b)
}

// the entries pollJSON hands over, and the places in lines they came from
func pollEntriesOf(lines []string) ([]pollEntry, []int) {
	out := make([]pollEntry, 0, len(lines))
	var took []int
	for n, l := range lines {
		i := strings.IndexByte(l, '|')
		if i < 0 {
			continue
		}
		c := l[i+1:]
		if strings.ContainsAny(c, "\n\r\x00") {
			log.Printf("nostr: dropped a delivery that holds a line break")
			continue
		}
		out = append(out, pollEntry{T: l[:i], C: c})
		took = append(took, n)
	}
	return out, took
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
	url := goStr(cUrl)
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
	return C.CString(torPost(goStr(cUrl), goStr(cBody)))
}

// the badge service's calls: the services lane carries them, over tor on
// every route. people search has its own (searchPost)
func torPost(url, body string) string { return torPostOn(url, body, servicesClient) }

func torPostOn(url, body string, clientOf func(context.Context) (*http.Client, error)) string {
	if url == "" {
		return "error: empty url"
	}
	// one bound for the wait on tor and the request
	ctx, cancel := context.WithTimeout(context.Background(), servicesWait)
	defer cancel()
	client, err := clientOf(ctx)
	if err != nil {
		return fmt.Sprintf("error: tor client: %v", err)
	}
	req, err := http.NewRequest("POST", url, strings.NewReader(body))
	if err != nil {
		return fmt.Sprintf("error: req: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return fmt.Sprintf("error: post: %v", err)
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		return fmt.Sprintf("error: read: %v", err)
	}
	if resp.StatusCode >= 300 {
		return fmt.Sprintf("error: status %d: %s", resp.StatusCode, string(out))
	}
	return string(out)
}

// GET over tor that keeps the body for any 2xx: the badge service answers
// 202 while a payment is still pending.
//
//export HaloTorGetJSON
func HaloTorGetJSON(cUrl *C.char) *C.char {
	return C.CString(torGetJSON(goStr(cUrl)))
}

// others' handle lookups and badge receipts: the services lane, as above.
// the own handle's lookup has its own (ownHandleGetJSON)
func torGetJSON(url string) string { return torGetJSONOn(url, servicesClient) }

func torGetJSONOn(url string, clientOf func(context.Context) (*http.Client, error)) string {
	if url == "" {
		return "error: empty url"
	}
	ctx, cancel := context.WithTimeout(context.Background(), servicesWait)
	defer cancel()
	client, err := clientOf(ctx)
	if err != nil {
		return fmt.Sprintf("error: tor client: %v", err)
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return fmt.Sprintf("error: req: %v", err)
	}
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return fmt.Sprintf("error: get: %v", err)
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		return fmt.Sprintf("error: read: %v", err)
	}
	if resp.StatusCode >= 300 {
		return fmt.Sprintf("error: status %d", resp.StatusCode)
	}
	return string(out)
}
