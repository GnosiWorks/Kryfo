// SPDX-License-Identifier: GPL-3.0-or-later
package catchup

import (
	"context"
	"encoding/binary"
	"math/rand/v2"
	"sort"
	"testing"

	"fiatjaf.com/nostr"
)

func TestHoldWhileAWalkIsUnderWay(t *testing.T) {
	var h Hold
	if h.Held() || h.From(500) != 500 {
		t.Fatalf("no hold changes nothing: %+v", h)
	}
	h = h.Cut(100, 900, false)
	if h != (Hold{Floor: 100, Began: 900}) {
		t.Fatalf("a walk cut short holds from where it began: %+v", h)
	}
	if h.From(700) != 100 {
		t.Fatal("the next window is not taken from where the walk began")
	}
	if h.From(50) != 50 {
		t.Fatal("a lower anchor is not kept")
	}
	// carried on from its mark: the same walk, the same hold
	if got := h.Cut(100, 1000, true); got != h {
		t.Fatalf("a resumed walk moved its hold: %+v", got)
	}
	// begun afresh: from its own start, and never above the old floor
	if got := h.Cut(300, 1000, false); got != (Hold{Floor: 100, Began: 1000}) {
		t.Fatalf("a fresh walk holds %+v", got)
	}
	if got := h.Done(false); got.Held() {
		t.Fatalf("a walk that stepped over nothing still holds %+v", got)
	}
}

func TestHoldAfterAWalkThatSteppedOver(t *testing.T) {
	h := Hold{Floor: 100, Began: 900}.Done(true)
	if h != (Hold{Floor: 900, Began: 900}) {
		t.Fatalf("a finished walk that stepped over stretches holds %+v", h)
	}
	if h.From(5000) != 900 || h.From(600) != 600 {
		t.Fatal("the next pass is not taken from when the walk began")
	}
	// the next pass stepped over nothing: nothing is owed
	if got := h.Done(false); got.Held() {
		t.Fatalf("still held after a clean pass: %+v", got)
	}
	if got := (Hold{}).Done(true); got.Held() {
		t.Fatalf("a walk nobody held made a hold: %+v", got)
	}
}

func TestHoldWhenARunnerStarts(t *testing.T) {
	h := Hold{}.Start(500, 900)
	if h != (Hold{Floor: 500, Began: 900}) || h.From(700) != 500 {
		t.Fatalf("a relay that held nothing holds %+v from the file", h)
	}
	if h.Cut(500, 1000, false) != (Hold{Floor: 500, Began: 1000}) {
		t.Fatal("a walk cut on the first pass does not hold from the file")
	}
	if h.Done(false).Held() {
		t.Fatal("a clean pass did not let go")
	}
	// a hold kept from before stays, and never above the file
	if got := (Hold{Floor: 300, Began: 800}).Start(500, 900); got != (Hold{Floor: 300, Began: 800}) {
		t.Fatalf("a lower hold became %+v", got)
	}
	if got := (Hold{Floor: 700, Began: 800}).Start(500, 900); got != (Hold{Floor: 500, Began: 800}) {
		t.Fatalf("a hold above the file became %+v", got)
	}
}

// what a relay holds as time passes: each event is there from when it
// arrived. our relay's onion and clearnet name share one.
type simEvent struct {
	ev      nostr.Event
	arrived nostr.Timestamp
}

type simStore struct {
	events []simEvent
	// wraps for nobody: they fill a first answer and never open
	nobody bool
}

func (s *simStore) add(ev nostr.Event, arrived nostr.Timestamp) {
	s.events = append(s.events, simEvent{ev, arrived})
}

// one entry of the relay list
type simRelay struct {
	key    string
	store  *simStore
	clock  *nostr.Timestamp
	left   int
	cancel context.CancelFunc
}

func (r *simRelay) query(since, until nostr.Timestamp, limit int) []nostr.Event {
	var hit []nostr.Event
	for _, e := range r.store.events {
		if e.arrived <= *r.clock && e.ev.CreatedAt >= since && e.ev.CreatedAt <= until {
			hit = append(hit, e.ev)
		}
	}
	sort.Slice(hit, func(i, j int) bool { return hit[i].CreatedAt > hit[j].CreatedAt })
	if limit > 100 {
		limit = 100
	}
	if len(hit) > limit {
		hit = hit[:limit]
	}
	return hit
}

// pages until this connection's time is up, like the engine's cap
func (r *simRelay) page(ctx context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	evs := r.query(since, until, limit)
	r.left--
	if r.left <= 0 {
		r.cancel()
	}
	return evs, nil
}

// the phone's side as the engine keeps it: one anchor per address, shared
// by its relays, and the book, kept in memory
type simPhone struct {
	t      *testing.T
	anchor nostr.Timestamp
	disk   nostr.Timestamp
	got    map[nostr.ID]bool
	book   *Book
	// our relay's entries
	own []string
}

const (
	simWindow = 12 * 3600
	simSlack  = 300
)

func (p *simPhone) deliver(ev nostr.Event) bool {
	if p.got[ev.ID] {
		return false
	}
	p.got[ev.ID] = true
	return true
}

// one connection, the way the relay runner makes it: it reads the anchor as
// it connects, then takes the first answer, then walks. the other relays can
// move the anchor in between.
type simConn struct {
	p       *simPhone
	r       *simRelay
	now     nostr.Timestamp
	pages   int
	c       Conn
	since   nostr.Timestamp
	oldest  nostr.Timestamp
	pending nostr.Timestamp
	walks   bool
}

// no window of our relay is ever above a wrap it has still to hand over
func (p *simPhone) begin(r *simRelay, now nostr.Timestamp, pages int) *simConn {
	c := &simConn{p: p, r: r, now: now, pages: pages, c: p.book.Connect(r.key, p.own, min(p.anchor, now), now)}
	c.since = max(c.c.Base-simWindow, 0)
	if !c.c.Own {
		return c
	}
	for _, e := range r.store.events {
		if e.arrived <= now && !p.got[e.ev.ID] && e.ev.CreatedAt < c.since {
			p.t.Fatalf("at %d a wrap that reached %s at %d, stamped %d, is below its window from %d",
				now, r.key, e.arrived, e.ev.CreatedAt, c.since)
		}
	}
	return c
}

func (c *simConn) answer() {
	p := c.p
	limit := 100
	if c.c.Resumed {
		limit = 5
	}
	first := c.r.query(c.since, 1<<40, limit)
	for _, ev := range first {
		// every wrap here opens, and one the app took before still moves
		// the anchor
		p.deliver(ev)
		if !c.r.store.nobody {
			c.pending = max(c.pending, min(ev.CreatedAt, c.now+simSlack))
		}
		if c.oldest == 0 || ev.CreatedAt < c.oldest {
			c.oldest = ev.CreatedAt
		}
	}
	if len(first) < limit {
		c.finish(false)
		return
	}
	// a full answer: the walk owes its window from here on
	p.book.Owe(c.c)
	p.save()
	c.walks = true
}

// the subscription is answered with CLOSED
func (c *simConn) refuse() {
	c.p.book.Refused(c.c)
	c.p.save()
}

func (p *simPhone) open(r *simRelay, now nostr.Timestamp, pages int) *simConn {
	c := p.begin(r, now, pages)
	c.answer()
	return c
}

// the rest of the window, until this connection's time is up
func (c *simConn) walk() {
	if !c.walks {
		return
	}
	p, r := c.p, c.r
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	r.left, r.cancel = c.pages, cancel
	if c.pages <= 0 {
		cancel()
	}
	m := p.book.Marks[r.key]
	res, mark := Continue(ctx, r.page, c.since, c.oldest, 100, 1000, p.deliver, m)
	if res.Complete {
		c.finish(m.Started())
		return
	}
	p.book.Cut(c.c, mark)
	p.save()
}

// the window is in: the anchor moves and the file follows
func (c *simConn) finish(stepped bool) {
	p := c.p
	p.book.Done(c.c, stepped)
	p.anchor = max(p.anchor, c.pending)
	p.save()
}

// what the anchor file gets, at the moments the runner writes it: the
// anchor, or what a walk on our relay still owes
func (p *simPhone) save() {
	p.disk = p.anchor
	if f, held := p.book.Floor(p.own); held && f < p.disk {
		p.disk = f
	}
}

// a process starts: the book of the one before is gone, the anchor comes
// from the file, and our relay holds from it
func (p *simPhone) start(now nostr.Timestamp) {
	p.anchor = p.disk
	p.book = NewBook()
	p.book.Start(p.own, p.anchor, now)
}

// the relays of one run and how each check-in goes: ours is our relay's
// only entry, or onion and clear are its two; other is a public relay with
// the texts; stuck are public relays that never get through
type simNet struct {
	ours, onion, clear, other *simRelay
	refusing, stalled         *simRelay
}

// our relay holds a video's slices, sent while the phone was away, more than
// one check-in can page, and only it has them. a text sent since is on every
// relay. while ours walks the slices over many check-ins, the contact keeps
// sending: texts to every relay, more slices to ours, every wrap stamped up
// to ten hours back, so many land inside stretches already walked. the
// process restarts once on the way.
//
// with our relay as one entry, the other relay hands over the texts and
// moves the anchor, either after ours has read the anchor and before its
// first answer comes, or before ours has connected at all. with our relay as
// an onion and a clearnet name, both walk, or the onion never connects, or
// it refuses every subscription, or it stops connecting half way through.
// public relays that never get through, refusing every subscription or
// never finishing a walk, sit alongside.
//
// every wrap arrives, and neither a window of our relay nor the anchor file
// is ever past one still to come. the anchor is back where it was once a
// relay has answered after the restart. a text a day later moves the anchor
// past the whole video, and then nothing is held.
func TestWrapsStampedIntoWalkedStretchesArrive(t *testing.T) {
	oursFirst := func(n *simNet, p *simPhone, clock nostr.Timestamp, round int) {
		c := p.begin(n.ours, clock, 3)
		p.open(n.other, clock, 3).walk()
		c.answer()
		c.walk()
	}
	otherFirst := func(n *simNet, p *simPhone, clock nostr.Timestamp, round int) {
		p.open(n.other, clock, 3).walk()
		p.open(n.ours, clock, 3).walk()
	}
	// the onion, slower, reads the anchor first, then the clearnet name,
	// then the other relay answers, and the two page in turn. when the
	// other relay answers before the clearnet name reads the anchor, the
	// onion's window can begin below the clearnet name's.
	twins := func(onionUntil int, otherBetween bool) func(n *simNet, p *simPhone, clock nostr.Timestamp, round int) {
		return func(n *simNet, p *simPhone, clock nostr.Timestamp, round int) {
			var o *simConn
			if round < onionUntil {
				o = p.begin(n.onion, clock, 1)
			}
			if otherBetween {
				p.open(n.other, clock, 3).walk()
			}
			c := p.begin(n.clear, clock, 3)
			if !otherBetween {
				p.open(n.other, clock, 3).walk()
			}
			if o != nil {
				o.answer()
			}
			c.answer()
			if o != nil {
				o.walk()
			}
			c.walk()
		}
	}
	// the onion's first answer is in before the other relay moves the
	// anchor and the clearnet name connects, so the clearnet name's window
	// would begin above what the onion owes
	onionAnswersFirst := func(onionUntil, clearPages int) func(n *simNet, p *simPhone, clock nostr.Timestamp, round int) {
		return func(n *simNet, p *simPhone, clock nostr.Timestamp, round int) {
			var o *simConn
			if round < onionUntil {
				o = p.open(n.onion, clock, 1)
			}
			p.open(n.other, clock, 3).walk()
			c := p.open(n.clear, clock, clearPages)
			if o != nil {
				o.walk()
			}
			c.walk()
		}
	}
	for _, run := range []struct {
		name  string
		twins bool
		stuck bool
		burst bool
		round func(n *simNet, p *simPhone, clock nostr.Timestamp, round int)
	}{
		{name: "ours reads the anchor first", round: oursFirst},
		{name: "the other relay first after the restart", round: func(n *simNet, p *simPhone, clock nostr.Timestamp, round int) {
			if round == simRestart {
				otherFirst(n, p, clock, round)
			} else {
				oursFirst(n, p, clock, round)
			}
		}},
		{name: "the other relay first every time", round: otherFirst},
		{name: "public relays that never get through", stuck: true, round: func(n *simNet, p *simPhone, clock nostr.Timestamp, round int) {
			p.begin(n.refusing, clock, 3).refuse()
			p.open(n.stalled, clock, 0).walk()
			oursFirst(n, p, clock, round)
		}},
		{name: "onion and clearnet name both walk", twins: true, round: twins(1<<30, false)},
		{name: "the other relay answers between the two", twins: true, round: twins(1<<30, true)},
		{name: "the onion never connects", twins: true, round: twins(0, false)},
		{name: "the onion stops connecting half way", twins: true, round: twins(4*3, false)},
		{name: "the onion stops connecting after the other relay moved on", twins: true, round: twins(4*3, true)},
		{name: "the onion answers first, then stops connecting", twins: true, round: onionAnswersFirst(4*3, 3)},
		{name: "the clearnet name gets through at once, the onion stops half way", twins: true, round: onionAnswersFirst(4*3, 50)},
		{name: "a second video, and the onion stops connecting in it", twins: true, burst: true, round: onionAnswersFirst(simBurstEnd, 3)},
		{name: "the onion refuses every subscription", twins: true, round: func(n *simNet, p *simPhone, clock nostr.Timestamp, round int) {
			p.begin(n.onion, clock, 3).refuse()
			twins(0, false)(n, p, clock, round)
		}},
	} {
		t.Run(run.name, func(t *testing.T) { simWalkedStretches(t, run.twins, run.stuck, run.burst, run.round) })
	}
}

// the process restarts at this check-in. a second video, when there is one,
// is sent over the check-ins from simBurst to simBurstEnd, long after the
// first is in, with a text at every one of them that moves the anchor.
const (
	simRestart  = 6
	simBurst    = 4 * 10
	simBurstEnd = 4 * 11
)

func simWalkedStretches(t *testing.T, twins, stuck, burst bool,
	round func(n *simNet, p *simPhone, clock nostr.Timestamp, round int)) {
	rng := rand.New(rand.NewPCG(7, 11))
	const t0 = nostr.Timestamp(1_800_000_000)
	const checkIn = 15 * 60
	clock := t0
	store, texts := &simStore{}, &simStore{}
	n := &simNet{other: &simRelay{key: "other", store: texts, clock: &clock}}
	p := &simPhone{t: t, disk: t0 - 8*3600, got: map[nostr.ID]bool{}}
	if twins {
		n.onion = &simRelay{key: "onion", store: store, clock: &clock}
		n.clear = &simRelay{key: "clear", store: store, clock: &clock}
		p.own = []string{"onion", "clear"}
	} else {
		n.ours = &simRelay{key: "ours", store: store, clock: &clock}
		p.own = []string{"ours"}
	}
	stalled := &simStore{nobody: true}
	if stuck {
		n.refusing = &simRelay{key: "refusing", store: &simStore{}, clock: &clock}
		n.stalled = &simRelay{key: "stalled", store: stalled, clock: &clock}
	}
	id := uint32(0)
	wrap := func(sent nostr.Timestamp) nostr.Event {
		id++
		var i nostr.ID
		binary.BigEndian.PutUint32(i[:], id)
		return nostr.Event{ID: i, CreatedAt: sent - nostr.Timestamp(60*rng.IntN(600))}
	}
	for i := 0; i < 4000; i++ {
		sent := t0 - 7*3600
		store.add(wrap(sent), sent)
	}
	// wraps for nobody that fill every first answer, so its walk goes on
	for i := 0; i < 300; i++ {
		stalled.add(nostr.Event{ID: nostr.ID{0xee, byte(i), byte(i >> 8)}, CreatedAt: t0 - nostr.Timestamp(i*60)}, t0-8*3600)
	}
	// stamped as late as a wrap can be, so it moves the anchor far
	late := wrap(t0 - 3600)
	late.CreatedAt = t0 - 3600
	store.add(late, t0-3600)
	texts.add(late, t0-3600)
	p.start(clock)

	var before nostr.Timestamp
	for r := 0; r < 4*36; r++ {
		clock = t0 + nostr.Timestamp(r*checkIn)
		if r == simRestart {
			before = p.anchor
			p.start(clock)
		}
		round(n, p, clock, r)
		if r == simRestart && p.anchor < before {
			t.Fatalf("after the restart the anchor is at %d, below the %d it had reached", p.anchor, before)
		}
		for _, e := range store.events {
			if e.arrived <= clock && !p.got[e.ev.ID] && e.ev.CreatedAt < p.disk-simWindow {
				t.Fatalf("round %d: the anchor file %d is past a wrap still to come, stamped %d",
					r, p.disk, e.ev.CreatedAt)
			}
		}
		if r == 4*24 {
			text := wrap(clock + 60)
			store.add(text, clock+60)
			texts.add(text, clock+60)
		}
		// the next quarter of an hour: slices for five hours, texts for twelve
		if r < 4*5 {
			for i := 0; i < 20; i++ {
				sent := clock + nostr.Timestamp(rng.IntN(checkIn))
				store.add(wrap(sent), sent)
			}
		}
		if r < 4*12 {
			sent := clock + nostr.Timestamp(rng.IntN(checkIn))
			text := wrap(sent)
			store.add(text, sent)
			texts.add(text, sent)
		}
		if burst && r >= simBurst && r < simBurstEnd {
			for i := 0; i < 60; i++ {
				sent := clock + nostr.Timestamp(rng.IntN(checkIn))
				store.add(wrap(sent), sent)
			}
			text := wrap(clock + 60)
			text.CreatedAt = clock + 60
			store.add(text, clock+60)
			texts.add(text, clock+60)
		}
	}
	missing := 0
	for _, e := range store.events {
		if !p.got[e.ev.ID] {
			missing++
		}
	}
	if missing > 0 {
		t.Fatalf("%d of %d wraps never came", missing, len(store.events))
	}
	if len(p.book.Holds) > 0 {
		t.Fatalf("hours after the last text the book still holds %+v", p.book.Holds)
	}
	if p.disk != p.anchor || p.anchor < t0+4*3600 {
		t.Fatalf("the anchor is at %d and its file at %d", p.anchor, p.disk)
	}
}
