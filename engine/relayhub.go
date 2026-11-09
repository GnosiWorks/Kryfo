// SPDX-License-Identifier: GPL-3.0-or-later
package main

// one socket per relay for the addresses of one batch (batches.go), instead
// of one per address. a batch has a lane of its own, so its own tor
// circuits: the relay learns that these few addresses are one phone's, and
// nothing ties them to the phone's other batches but timing. no address of
// another batch or identity, no hidden chat and no first-contact address is
// ever on it (they keep a socket and a lane each).
//
// each address still asks for its own window, with its own since and limit,
// as before. once the window is in, the address moves to a live req that
// names up to hubMaxAddrs addresses with limit 0, and its window's req is
// closed. the window's req stays open until that live req is on the wire,
// so nothing that reaches the relay in between is missed. anchors, catch-up
// walks and asks by id stay per address; only the socket and the live req
// are shared.

import (
	"context"
	"errors"
	"log"
	"math"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"fiatjaf.com/nostr"
)

// the most addresses one live req names: what relay-live takes in one filter
// (relay-live/limits.go maxAddrs)
const hubMaxAddrs = 10

// how long a socket gathers the addresses that join before it asks for
// them: until none joined for hubGather, at most hubGatherMax
var (
	hubGather    = 250 * time.Millisecond
	hubGatherMax = 2 * time.Second
)

// one-shot reqs (a window, a page, an ask by ids) waiting for their answer at
// once on one socket: a public relay takes 20 subscriptions per connection.
// our relay has no such cap and paces them instead
var hubSlots, hubSlotsOwn = 8, 32

// a socket that carried something this lately needs no probe of its own
var hubFresh = 15 * time.Second

// relay-live's budget per socket (10 reqs a second, a burst of 200), kept
// under on this side for our relays, so a burst of addresses waits instead
// of being turned away
var hubPacePerSec, hubPaceBurst = 8.0, 180.0

// the budget before 0.6 (2 a second, a burst of 100). each socket keeps
// count of it too. a relay that turns a req away as too fast still runs
// the old one: every socket to it keeps to the old count from then on,
// while this process lives, and the window turned away is asked again
var hubOldPerSec, hubOldBurst = 2.0, 90.0

// the relays that turned a req away as too fast
var hubSlow sync.Map

func hubSlowed(u string) bool {
	_, ok := hubSlow.Load(u)
	return ok
}

// relay-live's answer to a req past its budget
func tooFast(reason string) bool { return strings.HasPrefix(reason, "rate-limited:") }

// the subscriptions that share a socket: one lane, one group, one relay
type hubKey struct{ lane, group, url string }

type relayHub struct {
	// the socket now, nil for none. under hubsMu
	cur *hubConn
	// closed while cur is up, so a socket's turn ends as soon as another
	// address of its group got the socket up. under hubsMu
	upC chan struct{}
	up  bool
}

var (
	hubsMu sync.Mutex
	hubs   = map[hubKey]*relayHub{}
)

// under hubsMu
func hubOf(k hubKey) *relayHub {
	h := hubs[k]
	if h == nil {
		h = &relayHub{upC: make(chan struct{})}
		hubs[k] = h
	}
	return h
}

// closed once a socket of k is up
func hubReady(k hubKey) <-chan struct{} {
	hubsMu.Lock()
	defer hubsMu.Unlock()
	return hubOf(k).upC
}

// under hubsMu
func (h *relayHub) downLocked(c *hubConn) {
	if h.cur != c {
		return
	}
	h.cur = nil
	if h.up {
		h.upC, h.up = make(chan struct{}), false
	}
}

// one socket
type hubConn struct {
	hub  *relayHub
	url  string
	lane string
	// its place before the dial (dialpace.go), nil for none
	place  *paceTicket
	paced  bool
	routeC <-chan struct{}
	ctx    context.Context
	cancel context.CancelFunc
	relay  *nostr.Relay
	// closed once the dial is over, err its outcome
	dialed chan struct{}
	err    error
	slots  chan struct{}
	// unix ms of the last frame something on it took
	heard  atomic.Int64
	flushC chan struct{}

	paceMu sync.Mutex
	tokens float64
	// the old budget's count, below zero while past it, and the old
	// budget as it was when the socket was made
	oldTokens         float64
	oldPerSec, oldMax float64
	paceLast          time.Time

	mu sync.Mutex
	// joins attached, the dial's waiters included
	members int
	byAddr  map[string][]*hubMember
	batches []*hubBatch
	probing *hubProbe
}

// one live req
type hubBatch struct {
	// the addresses it should name, each with the joins that want it
	want map[string]int
	// what the req on the wire names
	asked map[string]bool
	sub   *nostr.Subscription
}

type hubProbe struct {
	done chan struct{}
	ok   bool
}

func (c *hubConn) noteHeard() { c.heard.Store(time.Now().UnixMilli()) }

func (c *hubConn) heardWithin(d time.Duration) bool {
	return time.Since(time.UnixMilli(c.heard.Load())) < d
}

// the socket goes, and every join on it with it
func (c *hubConn) close() {
	c.cancel()
	hubsMu.Lock()
	c.hub.downLocked(c)
	hubsMu.Unlock()
}

func (c *hubConn) dial(client *http.Client) {
	// the wait ends with the socket and with its route
	pctx, pcancel := onRoute(c.ctx, c.routeC)
	if err := c.place.wait(pctx); err != nil {
		pcancel()
		c.err = err
		close(c.dialed)
		c.close()
		return
	}
	pcancel()
	noteRelayDial(c.url)
	opts := relayOptionsFor(c.url)
	if c.paced {
		opts.ClosedHandler = func(reason string) {
			if tooFast(reason) {
				c.slowDown()
			}
		}
	}
	r := nostr.NewRelay(c.ctx, c.url, opts)
	rctx, rcancel := onRoute(c.ctx, c.routeC)
	dctx, dcancel := relayDialCtx(rctx, c.url)
	err := r.ConnectWithClient(dctx, client)
	dcancel()
	rcancel()
	if err == nil && c.ctx.Err() != nil {
		err = c.ctx.Err()
	}
	c.relay, c.err = r, err
	if err == nil {
		c.noteHeard()
		hubsMu.Lock()
		if c.hub.cur == c && !c.hub.up {
			close(c.hub.upC)
			c.hub.up = true
		}
		hubsMu.Unlock()
		go c.watch()
		go c.flusher()
	}
	close(c.dialed)
	if err != nil {
		c.close()
	}
}

// the socket ends with its route and with the connection under it
func (c *hubConn) watch() {
	select {
	case <-c.ctx.Done():
	case <-c.routeC:
	case <-c.relay.Context().Done():
	}
	c.close()
}

// joins the socket of k, dialling it if there is none. ctx is the join's:
// the join leaves when it ends
func hubJoin(ctx context.Context, k hubKey, addr string, client *http.Client, routeC <-chan struct{}, paced bool, rank int) (*hubMember, bool, error) {
	hubsMu.Lock()
	h := hubOf(k)
	c := h.cur
	if c != nil && c.routeC != routeC && routeGone(routeC) {
		// the join is the old route's: the socket is the new one's
		hubsMu.Unlock()
		return nil, false, errors.New("the route changed")
	}
	if c != nil && (c.ctx.Err() != nil || c.routeC != routeC) {
		// one of the old route is not taken on to the new one
		c.cancel()
		h.downLocked(c)
		c = nil
	}
	dialing := false
	if c == nil {
		cctx, cancel := context.WithCancel(context.Background())
		slots := hubSlots
		if paced {
			slots = hubSlotsOwn
		}
		c = &hubConn{hub: h, url: k.url, lane: k.lane, place: paceJoin(k.lane, k.url, rank), paced: paced, routeC: routeC, ctx: cctx, cancel: cancel,
			dialed: make(chan struct{}), slots: make(chan struct{}, slots), flushC: make(chan struct{}, 1),
			byAddr: map[string][]*hubMember{}, tokens: hubPaceBurst, oldTokens: hubOldBurst, oldPerSec: hubOldPerSec, oldMax: hubOldBurst, paceLast: time.Now()}
		h.cur = c
		dialing = true
	} else {
		// the open chat joining a socket still in line moves it up
		c.place.raise(rank)
	}
	c.mu.Lock()
	c.members++
	c.mu.Unlock()
	hubsMu.Unlock()
	mctx, mcancel := context.WithCancel(ctx)
	m := &hubMember{c: c, addr: addr, ctx: mctx, cancel: mcancel, wake: make(chan struct{}, 1)}
	stop := context.AfterFunc(c.ctx, mcancel)
	context.AfterFunc(mctx, func() {
		stop()
		m.leave()
	})
	if dialing {
		go c.dial(client)
	}
	select {
	case <-c.dialed:
	case <-mctx.Done():
		m.leave()
		return nil, false, mctx.Err()
	}
	if c.err != nil {
		m.leave()
		return nil, false, c.err
	}
	if mctx.Err() != nil {
		m.leave()
		return nil, false, errors.New("socket closed")
	}
	return m, dialing, nil
}

// one address's join of a socket
type hubMember struct {
	c      *hubConn
	addr   string
	ctx    context.Context
	cancel context.CancelFunc
	once   sync.Once

	mu sync.Mutex
	// live wraps from the shared req not handed over yet
	q      []nostr.Event
	wake   chan struct{}
	subbed bool
	slot   bool
}

func (m *hubMember) leave() {
	m.once.Do(func() {
		m.cancel()
		c := m.c
		hubsMu.Lock()
		c.mu.Lock()
		m.mu.Lock()
		subbed := m.subbed
		m.mu.Unlock()
		if subbed {
			c.byAddr[m.addr] = slices.DeleteFunc(c.byAddr[m.addr], func(x *hubMember) bool { return x == m })
			if len(c.byAddr[m.addr]) == 0 {
				delete(c.byAddr, m.addr)
			}
			c.unaskLocked(m.addr)
		}
		c.members--
		last := c.members == 0
		if last {
			c.cancel()
			c.hub.downLocked(c)
		}
		c.mu.Unlock()
		hubsMu.Unlock()
		m.dropSlot()
		if !last && subbed {
			c.kickFlush()
		}
	})
}

func (c *hubConn) takeSlot(ctx context.Context) error {
	select {
	case c.slots <- struct{}{}:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (c *hubConn) dropSlot() { <-c.slots }

func (m *hubMember) dropSlot() {
	m.mu.Lock()
	held := m.slot
	m.slot = false
	m.mu.Unlock()
	if held {
		m.c.dropSlot()
	}
}

// the relay keeps the old budget: this socket's bucket is empty there now
func (c *hubConn) slowDown() {
	if _, was := hubSlow.LoadOrStore(c.url, true); !was {
		log.Printf("nostr: an own relay keeps the old req budget, %v a second from now on", c.oldPerSec)
	}
	c.paceMu.Lock()
	c.oldTokens = 0
	c.paceMu.Unlock()
}

// waits for a req's place in our relay's budget, the old one once the relay
// showed it keeps that
func (c *hubConn) pace(ctx context.Context) error {
	if !c.paced {
		return nil
	}
	for {
		c.paceMu.Lock()
		now := time.Now()
		dt := now.Sub(c.paceLast).Seconds()
		c.tokens = min(hubPaceBurst, c.tokens+dt*hubPacePerSec)
		c.oldTokens = min(c.oldMax, c.oldTokens+dt*c.oldPerSec)
		c.paceLast = now
		have, rate := c.tokens, hubPacePerSec
		if hubSlowed(c.url) {
			have, rate = c.oldTokens, c.oldPerSec
		}
		if have >= 1 {
			c.tokens--
			c.oldTokens--
			c.paceMu.Unlock()
			return nil
		}
		wait := time.Duration((1 - have) / rate * float64(time.Second))
		c.paceMu.Unlock()
		t := time.NewTimer(wait)
		select {
		case <-t.C:
		case <-ctx.Done():
			t.Stop()
			return ctx.Err()
		}
	}
}

// the address on a live req, under c.mu
func (c *hubConn) askLocked(addr string) {
	for _, b := range c.batches {
		if b.want[addr] > 0 {
			b.want[addr]++
			return
		}
	}
	for _, b := range c.batches {
		if len(b.want) < hubMaxAddrs {
			b.want[addr] = 1
			return
		}
	}
	c.batches = append(c.batches, &hubBatch{want: map[string]int{addr: 1}, asked: map[string]bool{}})
}

// under c.mu
func (c *hubConn) unaskLocked(addr string) {
	for _, b := range c.batches {
		if b.want[addr] > 0 {
			if b.want[addr]--; b.want[addr] == 0 {
				delete(b.want, addr)
			}
			return
		}
	}
}

// whether the live req on the wire names addr
func (c *hubConn) asks(addr string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, b := range c.batches {
		if b.sub != nil && b.asked[addr] {
			return true
		}
	}
	return false
}

func (c *hubConn) kickFlush() {
	select {
	case c.flushC <- struct{}{}:
	default:
	}
}

// the live reqs follow what the joins want, after a short gathering
func (c *hubConn) flusher() {
	for {
		select {
		case <-c.ctx.Done():
			return
		case <-c.flushC:
		}
		most := time.NewTimer(hubGatherMax)
		quiet := time.NewTimer(hubGather)
	gather:
		for {
			select {
			case <-c.ctx.Done():
				most.Stop()
				quiet.Stop()
				return
			case <-c.flushC:
				quiet.Reset(hubGather)
			case <-quiet.C:
				break gather
			case <-most.C:
				break gather
			}
		}
		most.Stop()
		quiet.Stop()
		c.flushAll()
	}
}

func (c *hubConn) flushAll() {
	type job struct {
		b    *hubBatch
		want []string
	}
	var jobs []job
	c.mu.Lock()
	for _, b := range c.batches {
		same := len(b.want) == len(b.asked) && (b.sub != nil || len(b.want) == 0)
		for a := range b.want {
			if !b.asked[a] {
				same = false
				break
			}
		}
		if !same {
			want := make([]string, 0, len(b.want))
			for a := range b.want {
				want = append(want, a)
			}
			slices.Sort(want)
			jobs = append(jobs, job{b, want})
		}
	}
	c.mu.Unlock()
	for _, j := range jobs {
		if c.ctx.Err() != nil {
			return
		}
		c.flushOne(j.b, j.want)
	}
}

func liveFilter(addrs []string) nostr.Filter {
	return nostr.Filter{
		Kinds:     []nostr.Kind{1059},
		Tags:      nostr.TagMap{"p": addrs},
		LimitZero: true,
	}
}

func (c *hubConn) flushOne(b *hubBatch, want []string) {
	if len(want) == 0 {
		c.mu.Lock()
		old := b.sub
		b.sub, b.asked = nil, map[string]bool{}
		c.mu.Unlock()
		if old != nil {
			old.Unsub()
		}
		return
	}
	if c.pace(c.ctx) != nil {
		return
	}
	sub, err := c.relay.Subscribe(c.ctx, liveFilter(want),
		nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
	if err != nil {
		c.close()
		return
	}
	c.mu.Lock()
	old := b.sub
	b.sub = sub
	b.asked = map[string]bool{}
	var woke []*hubMember
	for _, a := range want {
		b.asked[a] = true
		woke = append(woke, c.byAddr[a]...)
	}
	c.mu.Unlock()
	go c.pump(b, sub)
	if old != nil {
		old.Unsub()
	}
	for _, m := range woke {
		m.poke()
	}
}

// what a live req brings goes to the joins of its addresses. one the relay
// closed takes them off: they join again and ask again
func (c *hubConn) pump(b *hubBatch, sub *nostr.Subscription) {
	for {
		select {
		case ev, alive := <-sub.Events:
			if !alive {
				if c.ctx.Err() != nil {
					return
				}
				c.mu.Lock()
				if b.sub != sub {
					c.mu.Unlock()
					return
				}
				var gone []*hubMember
				for a := range b.asked {
					gone = append(gone, c.byAddr[a]...)
				}
				b.sub, b.asked = nil, map[string]bool{}
				c.mu.Unlock()
				for _, m := range gone {
					m.cancel()
				}
				return
			}
			c.noteHeard()
			c.route(ev)
		case <-sub.EndOfStoredEvents:
			c.noteHeard()
		}
	}
}

func (c *hubConn) route(ev nostr.Event) {
	var to []*hubMember
	c.mu.Lock()
	for p := range ev.Tags.FindAll("p") {
		if len(p) > 1 {
			to = append(to, c.byAddr[p[1]]...)
		}
	}
	c.mu.Unlock()
	for _, m := range to {
		m.mu.Lock()
		m.q = append(m.q, ev)
		m.mu.Unlock()
		m.poke()
	}
}

func (m *hubMember) poke() {
	select {
	case m.wake <- struct{}{}:
	default:
	}
}

func (m *hubMember) takeQueue() []nostr.Event {
	m.mu.Lock()
	defer m.mu.Unlock()
	q := m.q
	m.q = nil
	return q
}

// the address's subscription on a shared socket, read as the library's: what
// its window holds, the eose, then what comes live. one per join
func (m *hubMember) subscribe(f nostr.Filter) (*linkSub, error) {
	c := m.c
	if err := c.takeSlot(m.ctx); err != nil {
		return nil, err
	}
	m.mu.Lock()
	m.slot = true
	m.mu.Unlock()
	if err := c.pace(m.ctx); err != nil {
		m.dropSlot()
		return nil, err
	}
	win, err := c.relay.Subscribe(m.ctx, f, nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
	if err != nil {
		m.dropSlot()
		return nil, err
	}
	c.mu.Lock()
	m.mu.Lock()
	m.subbed = true
	m.mu.Unlock()
	c.byAddr[m.addr] = append(c.byAddr[m.addr], m)
	c.askLocked(m.addr)
	c.mu.Unlock()
	c.kickFlush()
	events, eose, closed := make(chan nostr.Event), make(chan struct{}), make(chan string, 1)
	go m.feed(f, win, events, eose, closed)
	return &linkSub{Events: events, EndOfStoredEvents: eose, ClosedReason: closed}, nil
}

func (m *hubMember) send(to chan nostr.Event, ev nostr.Event) bool {
	select {
	case to <- ev:
		return true
	case <-m.ctx.Done():
		return false
	}
}

func (m *hubMember) feed(f nostr.Filter, win *nostr.Subscription, events chan nostr.Event, eose chan struct{}, closed chan string) {
	defer close(events)
	defer m.cancel()
	c := m.c
	winEv, winEose := win.Events, win.EndOfStoredEvents
	eosed, handed, again := false, false, false
	for {
		// the window is in and a live req names the address: its own req
		// goes, and what the live one brought meanwhile is handed over
		if !handed && eosed && c.asks(m.addr) {
			win.Unsub()
			m.dropSlot()
			handed = true
		}
		if handed {
			for _, ev := range m.takeQueue() {
				if !m.send(events, ev) {
					return
				}
			}
		}
		select {
		case ev, alive := <-winEv:
			if !alive {
				winEv, winEose = nil, nil
				if !handed {
					// turned away, or the socket went
					select {
					case r := <-win.ClosedReason:
						// too fast for a relay on the old budget: once more,
						// paced under that one now, so the runner never
						// sees it (a refusal lets go of the catch-up's hold)
						if c.paced && tooFast(r) && !again && !eosed && m.ctx.Err() == nil {
							again = true
							if c.pace(m.ctx) == nil {
								if w, err := c.relay.Subscribe(m.ctx, f, nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)}); err == nil {
									win, winEv, winEose = w, w.Events, w.EndOfStoredEvents
									continue
								}
							}
						}
						closed <- r
					default:
					}
					return
				}
				continue
			}
			c.noteHeard()
			if !m.send(events, ev) {
				return
			}
		case <-winEose:
			winEose = nil
			eosed = true
			c.noteHeard()
			// the window is answered: what stays open until the live req
			// takes over costs the relay nothing to look up
			m.dropSlot()
			select {
			case eose <- struct{}{}:
			case <-m.ctx.Done():
				return
			}
		case <-m.wake:
		case <-m.ctx.Done():
			return
		}
	}
}

// a probe, unless the socket carried something just now. the joins that
// ask while one is out wait for its answer
func (m *hubMember) probe(ctx context.Context, rcvPk string) bool {
	c := m.c
	if c.heardWithin(hubFresh) {
		return true
	}
	c.mu.Lock()
	p := c.probing
	if p == nil {
		p = &hubProbe{done: make(chan struct{})}
		c.probing = p
		go func() {
			ok := c.pace(c.ctx) == nil && relayResponds(c.ctx, c.relay, rcvPk)
			if ok {
				c.noteHeard()
			}
			p.ok = ok
			c.mu.Lock()
			c.probing = nil
			c.mu.Unlock()
			close(p.done)
		}()
	}
	c.mu.Unlock()
	select {
	case <-p.done:
		return p.ok
	case <-ctx.Done():
		return false
	}
}

func (m *hubMember) page(ctx context.Context, rcvPk string, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
	c := m.c
	if err := c.takeSlot(ctx); err != nil {
		return nil, err
	}
	defer c.dropSlot()
	if err := c.pace(ctx); err != nil {
		return nil, err
	}
	evs, err := relayPage(ctx, c.relay, rcvPk, since, until, limit)
	if err == nil {
		c.noteHeard()
	}
	return evs, err
}

func (m *hubMember) byIDs(ctx context.Context, rcvPk string, ids []nostr.ID, take func(nostr.Event) bool) ([]nostr.ID, bool) {
	c := m.c
	if err := c.takeSlot(ctx); err != nil {
		return nil, false
	}
	defer c.dropSlot()
	if err := c.pace(ctx); err != nil {
		return nil, false
	}
	missing, answered := relayByIDs(ctx, c.relay, rcvPk, ids, take)
	if answered {
		c.noteHeard()
	}
	return missing, answered
}

func (m *hubMember) close() { m.leave() }

// a probe asked at asked went unanswered: the socket goes too, unless
// something else came on it since
func (m *hubMember) drop(asked time.Time) {
	if m.c.heard.Load() < asked.UnixMilli() {
		m.c.close()
	}
	m.leave()
}

// the subscription's channels, the library's or a shared socket's
type linkSub struct {
	Events            <-chan nostr.Event
	EndOfStoredEvents <-chan struct{}
	ClosedReason      <-chan string
}

// what a runner does on its relay connection: its own socket, as before, or
// its join of a shared one
type relayLink interface {
	subscribe(f nostr.Filter) (*linkSub, error)
	page(ctx context.Context, rcvPk string, since, until nostr.Timestamp, limit int) ([]nostr.Event, error)
	byIDs(ctx context.Context, rcvPk string, ids []nostr.ID, take func(nostr.Event) bool) ([]nostr.ID, bool)
	probe(ctx context.Context, rcvPk string) bool
	// this address off the connection
	close()
	// the connection did not answer a probe asked at asked
	drop(asked time.Time)
}

// a socket of the address's own
type soloLink struct {
	ctx context.Context
	r   *nostr.Relay
}

func (s soloLink) subscribe(f nostr.Filter) (*linkSub, error) {
	sub, err := s.r.Subscribe(s.ctx, f, nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
	if err != nil {
		return nil, err
	}
	return &linkSub{Events: sub.Events, EndOfStoredEvents: sub.EndOfStoredEvents, ClosedReason: sub.ClosedReason}, nil
}

func (s soloLink) page(ctx context.Context, rcvPk string, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
	return relayPage(ctx, s.r, rcvPk, since, until, limit)
}

func (s soloLink) byIDs(ctx context.Context, rcvPk string, ids []nostr.ID, take func(nostr.Event) bool) ([]nostr.ID, bool) {
	return relayByIDs(ctx, s.r, rcvPk, ids, take)
}

func (s soloLink) probe(ctx context.Context, rcvPk string) bool {
	return relayResponds(ctx, s.r, rcvPk)
}

func (s soloLink) close() { s.r.Close() }

func (s soloLink) drop(time.Time) { s.r.Close() }

// the runner's connection to relay u: a socket of its own when group is
// "", else its join of the group's socket. fresh: it dialled now, or the
// socket carried something lately, so it says the route works
func relayJoin(conn context.Context, k hubKey, addr string, client *http.Client, routeC <-chan struct{}, paced bool, rank int) (link relayLink, fresh bool, err error) {
	if k.group == "" {
		// a dial still under way when the mode changes ends there
		rctx, rcancel := onRoute(conn, routeC)
		if err := paceJoin(k.lane, k.url, rank).wait(rctx); err != nil {
			rcancel()
			return nil, false, err
		}
		r := nostr.NewRelay(conn, k.url, relayOptionsFor(k.url))
		noteRelayDial(k.url)
		dctx, dcancel := relayDialCtx(rctx, k.url)
		err := r.ConnectWithClient(dctx, client)
		dcancel()
		rcancel()
		if err != nil {
			return nil, false, err
		}
		return soloLink{conn, r}, true, nil
	}
	m, dialed, err := hubJoin(conn, k, addr, client, routeC, paced, rank)
	if err != nil {
		return nil, false, err
	}
	return m, dialed || m.c.heardWithin(hubFresh), nil
}

// which socket an address shares, set on its runner's context. none: a
// socket of its own
type shareKey struct{}

func shareOn(ctx context.Context, group string) context.Context {
	return context.WithValue(ctx, shareKey{}, group)
}

func shareOf(ctx context.Context) string {
	g, _ := ctx.Value(shareKey{}).(string)
	return g
}

// a hidden chat's address: never on a shared socket
type hiddenKey struct{}

func asHidden(ctx context.Context) context.Context {
	return context.WithValue(ctx, hiddenKey{}, true)
}

func hiddenOf(ctx context.Context) bool {
	h, _ := ctx.Value(hiddenKey{}).(bool)
	return h
}

// the group of an identity's addresses on a lane
func identGroup(ident int) string { return "i" + strconv.Itoa(ident) }

// sockets open now, shared ones counted once, for the tests
func hubSockets() int {
	hubsMu.Lock()
	defer hubsMu.Unlock()
	n := 0
	for _, h := range hubs {
		if h.cur != nil && h.up {
			n++
		}
	}
	return n
}
