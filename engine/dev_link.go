// SPDX-License-Identifier: GPL-3.0-or-later
package main

import "C"

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log"
	"maps"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/halo/engine/devices"
	"github.com/halo/engine/kshim"
)

// linking a device, both sides. the small messages go on two relay
// addresses only the qr names (one per direction), the bundles go to the
// phone's onion door with a one-time token. one link at a time on each
// side; nothing here runs unless the app starts a link, which it does only
// with the switch on. this is the one file that hands a list over as
// FromLink (session_door_test.go)

// how a link reaches the relays: post seals msg at the address seed names,
// fetch gives what the other side sealed there, oldest first
type linkWire interface {
	post(ctx context.Context, seed [32]byte, msg []byte) error
	fetch(ctx context.Context, seed [32]byte) ([][]byte, error)
}

// how the joiner reaches the phone's door: one line, acked
type linkDialer func(ctx context.Context, onion, line string) error

var (
	linkClock = time.Now
	// how often each side looks at its address
	linkPoll = 5 * time.Second
	// how long the door holds the last KLB1 line for the phone's app to
	// keep the device before it acks; the joiner waits as long
	linkKeptWait = time.Minute
	// the bundles may come this long after the link's own ten minutes
	linkBundlesLate            = 5 * time.Minute
	linkWireNow     linkWire   = relayLinkWire{}
	linkDialNow     linkDialer = dialLinkDoor
	// the phone's onion, without ".onion"
	linkOnionOf = func() string {
		mu.Lock()
		defer mu.Unlock()
		return strings.TrimSuffix(myAddr, ".onion")
	}
)

// the state names dart sees
const (
	lsOffer    = "offer"   // joiner: showing the qr
	lsAccept   = "accept"  // phone: the answer is out, waiting for the reveal
	lsDigits   = "digits"  // both: six digits to compare
	lsLinking  = "linking" // both: confirmed, the rest is under way
	lsPlaced   = "placed"  // joiner: knows its place, waits for its bundles
	lsSending  = "sending" // joiner: bundles on their way to the phone
	lsBundles  = "bundles" // phone: the device's bundles came
	lsKeeping  = "keeping" // phone: dart took them and keeps the device
	lsDone     = "done"    // both: nothing left to do here
	lsFailed   = "failed"  // both: see why
	lsWhyTime  = "expired" // the ten minutes ran out
	lsWhyReach = "unreached"
	lsWhyBad   = "refused" // a message that did not open or fit
	lsWhyFull  = "full"    // the phone already has every device it may
	lsWhyEnd   = "ended"   // the person stopped it
	lsWhyGone  = "gone"    // the other side stopped it
)

// an end message on the rendezvous: the other side stopped
const linkEndMagic = "KLE1"

var errLinkEnded = errors.New("link: the other side ended it")

// KLB1 goes to the door in lines of this many bytes at most
const linkChunk = 64 << 10

// the most lines a KLB1 takes
const linkChunksMost = devices.BundlesSizeMax/linkChunk + 1

const linkLinePrefix = "KLB1 "

type linkRun struct {
	mu     sync.Mutex
	st     string
	why    string
	sas    string
	cancel context.CancelFunc
	toJ    [32]byte
	toP    [32]byte

	// joiner
	j        *devices.Joiner
	confirm  chan struct{}
	welcome  []byte // a welcome come before the person confirmed
	linked   *devices.Linked
	place    devices.Place
	entry    devices.Entry
	ownTaken bool
	bundles  chan []byte
	given    bool // KLB1 sealed once, never twice under its key

	// the run's goroutine has stopped
	stopped bool

	// the world as it was when the run began
	wire  linkWire
	dial  linkDialer
	poll  time.Duration
	clock func() time.Time
	onion func() string

	// phone
	p        *devices.Linker
	identity devices.Key
	device   devices.DeviceKeys
	next     *devices.List
	ident    int
	want     int
	token    [devices.TokenSize]byte
	waiting  bool
	chunks   map[int]string
	nChunks  int
	got      devices.Bundles
	list     []byte
	// the door's last line waits on dart keeping the device: 0 waiting,
	// 1 kept (ack), 2 the door gave up
	ack      int
	keptCh   chan struct{}
	stream   *[devices.StreamKeySize]byte
	after    devices.AfterKeys
	bind     [32]byte
	deadline time.Time
}

var (
	linkMu   sync.Mutex
	linkRuns = map[string]*linkRun{}
)

// a run on the wire, door, clock and onion of now
func (r *linkRun) world() *linkRun {
	r.wire, r.dial, r.poll, r.clock, r.onion = linkWireNow, linkDialNow, linkPoll, linkClock, linkOnionOf
	return r
}

func newLinkID() string {
	var b [16]byte
	rand.Read(b[:])
	return hex.EncodeToString(b[:])
}

func (r *linkRun) set(st, why string) {
	r.mu.Lock()
	r.st, r.why = st, why
	r.mu.Unlock()
}

// the run ends without a link. its secrets go once its own goroutine has
// stopped using them (ended), never from under it
func (r *linkRun) failed(why string) {
	r.mu.Lock()
	tell := r.failLocked(why)
	r.mu.Unlock()
	r.cancel()
	if tell {
		r.tellEnd()
	}
}

// the run fails here: r.mu held. true when the other side is to hear of
// it, which is once it may be waiting on this side and did not end it
// itself
func (r *linkRun) failLocked(why string) bool {
	if r.st == lsDone || r.st == lsFailed {
		return false
	}
	tell := why != lsWhyGone && r.st != lsOffer
	r.st, r.why = lsFailed, why
	r.giveUpAck()
	if r.stopped {
		r.forget()
	}
	return tell
}

// a door still holding the last line is told no: r.mu held
func (r *linkRun) giveUpAck() {
	if r.keptCh != nil && r.ack == 0 {
		r.ack = 2
		close(r.keptCh)
	}
}

// the run's goroutine is done: a failed run's secrets go now; a good one's
// stay for take, which wipes them
func (r *linkRun) ended() {
	r.cancel()
	r.mu.Lock()
	r.stopped = true
	failed := r.st == lsFailed
	undo := failed && r.ownTaken
	var id devices.Key
	var list []byte
	if undo {
		id, list = r.linked.Identity, r.place.List
	}
	if failed {
		r.forget()
	}
	r.mu.Unlock()
	// a failed joiner leaves its state as before the link: the next link's
	// first list is taken afresh, never refused as a rollback
	if undo {
		if d := devNow(); d != nil {
			d.mu.Lock()
			d.own.Undo(id, list)
			d.mu.Unlock()
		}
	}
}

// everything secret goes; the state stays for dart to read. r.mu held, and
// the run's goroutine no longer at work
func (r *linkRun) forget() {
	if r.j != nil {
		r.j.Abort()
	}
	if r.p != nil {
		r.p.Abort()
	}
	if r.linked != nil {
		r.linked.Forget()
	}
	r.after.Forget()
	if r.stream != nil {
		for i := range r.stream {
			r.stream[i] = 0
		}
	}
	r.waiting = false
	r.chunks = nil
}

func whyOf(err error) string {
	switch {
	case errors.Is(err, devices.ErrExpired), errors.Is(err, context.DeadlineExceeded):
		return lsWhyTime
	case errors.Is(err, devices.ErrTooMany):
		return lsWhyFull
	case errors.Is(err, errLinkUnreached):
		return lsWhyReach
	case errors.Is(err, errLinkEnded):
		return lsWhyGone
	case errors.Is(err, context.Canceled):
		return lsWhyEnd
	}
	return lsWhyBad
}

var errLinkUnreached = errors.New("link: unreached")

// waits for the first message with magic at seed, past those already
// seen. a message of another kind is passed over: the other side's earlier
// ones stay at the address
func (r *linkRun) await(ctx context.Context, seed [32]byte, magic string, seen map[string]bool, also func([]byte)) ([]byte, error) {
	tick := time.NewTicker(r.poll)
	defer tick.Stop()
	for {
		msgs, err := r.wire.fetch(ctx, seed)
		if err == nil {
			for _, m := range msgs {
				k := string(m)
				if seen[k] || len(m) < 4 {
					continue
				}
				switch string(m[:4]) {
				case linkEndMagic:
					return nil, errLinkEnded
				case magic:
					seen[k] = true
					return m, nil
				}
				// another kind stays unread for the step that wants it,
				// in whatever order the relays gave them; a watcher with
				// its own record (also) passes each over once
				if also != nil {
					seen[k] = true
					also(m)
				}
			}
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-tick.C:
		}
	}
}

// while a side waits on its person or its door, an end from the other side
// is watched for on its own address; the stop func ends the watch
func (r *linkRun) watchEnd(ctx context.Context, seed [32]byte) func() {
	wctx, stop := context.WithCancel(ctx)
	done := make(chan struct{})
	go func() {
		defer close(done)
		if _, err := r.await(wctx, seed, "\x00\x00\x00\x00", map[string]bool{}, func([]byte) {}); errors.Is(err, errLinkEnded) {
			r.failed(lsWhyGone)
		}
	}()
	return func() {
		stop()
		<-done
	}
}

// ---- the joiner ----

func joinStart(key devices.Key, reg uint32) (string, *linkRun, error) {
	j, err := devices.StartJoin(key, reg, linkClock())
	if err != nil {
		return "", nil, err
	}
	toJ, toP, err := devices.Rendezvous(j.Offer())
	if err != nil {
		return "", nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), devices.LinkLife+linkBundlesLate)
	r := &linkRun{st: lsOffer, j: j, toJ: toJ, toP: toP, cancel: cancel,
		confirm: make(chan struct{}, 1), bundles: make(chan []byte, 1)}
	r.world()
	id := newLinkID()
	linkMu.Lock()
	// one link at a time: a new code ends the one before
	for k, o := range linkRuns {
		if o.j != nil {
			o.failed(lsWhyEnd)
			delete(linkRuns, k)
		}
	}
	linkRuns[id] = r
	linkMu.Unlock()
	go r.join(ctx)
	return id, r, nil
}

func (r *linkRun) join(ctx context.Context) {
	defer r.ended()
	if err := r.joinSteps(ctx); err != nil {
		log.Printf("link: the joining side ended (%s)", whyOf(err))
		r.failed(whyOf(err))
	}
}

func (r *linkRun) joinSteps(ctx context.Context) error {
	seen := map[string]bool{}
	accept, err := r.await(ctx, r.toJ, "KLA2", seen, nil)
	if err != nil {
		return err
	}
	reveal, err := r.j.HandleAccept(accept, r.clock())
	if err != nil {
		return err
	}
	if err := r.wire.post(ctx, r.toP, reveal); err != nil {
		return errLinkUnreached
	}
	sas, err := r.j.SAS()
	if err != nil {
		return err
	}
	r.mu.Lock()
	r.st, r.sas = lsDigits, sas
	r.mu.Unlock()
	// a welcome that comes while the person still compares is held, never
	// taken and never a failure: it is opened once they confirm
	held := func(m []byte) {
		if len(m) >= 4 && string(m[:4]) == "KLW2" {
			r.mu.Lock()
			if r.welcome == nil {
				r.welcome = m
			}
			r.mu.Unlock()
		}
	}
	waitCtx, stop := context.WithCancel(ctx)
	looked := make(chan struct{})
	go func() {
		defer close(looked)
		// its own record of what it saw: what comes after the welcome
		// stays unread for the steps below
		if _, err := r.await(waitCtx, r.toJ, "\x00\x00\x00\x00", maps.Clone(seen), held); errors.Is(err, errLinkEnded) {
			r.failed(lsWhyGone)
		}
	}()
	select {
	case <-r.confirm:
	case <-ctx.Done():
	}
	stop()
	<-looked
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if err := r.j.Confirm(); err != nil {
		return err
	}
	r.set(lsLinking, "")
	r.mu.Lock()
	w := r.welcome
	r.mu.Unlock()
	if w == nil {
		if w, err = r.await(ctx, r.toJ, "KLW2", seen, nil); err != nil {
			return err
		}
	}
	seen[string(w)] = true
	linked, err := r.j.HandleWelcome(w, r.clock())
	if err != nil {
		return err
	}
	r.mu.Lock()
	r.linked = linked
	r.mu.Unlock()
	pm, err := r.await(ctx, r.toJ, "KLP1", seen, nil)
	if err != nil {
		return err
	}
	place, err := devices.OpenPlace(linked.After, linked.Bind, pm)
	if err != nil {
		return err
	}
	l, err := devices.ReadList(place.List, devVerifier{devShimNow()})
	if err != nil {
		return err
	}
	e, ok := l.FindKey(linked.Keys.Key)
	if l.Identity != linked.Identity || !ok || e.Reg != linked.Keys.Reg {
		return devices.ErrNotListed
	}
	r.mu.Lock()
	r.place, r.entry, r.st = place, e, lsPlaced
	r.mu.Unlock()
	defer r.watchEnd(ctx, r.toJ)()
	var klb1 []byte
	select {
	case klb1 = <-r.bundles:
	case <-ctx.Done():
		return ctx.Err()
	}
	r.set(lsSending, "")
	if err := sendLinkBundles(ctx, r.dial, place, klb1); err != nil {
		return err
	}
	r.mu.Lock()
	r.st = lsDone
	r.mu.Unlock()
	return nil
}

func devShimNow() *kshim.Lib {
	devMu.Lock()
	defer devMu.Unlock()
	return devShim
}

// KLB1 to the door, in lines: "KLB1 <token> <i>/<n> <base64>"
func sendLinkBundles(ctx context.Context, dial linkDialer, p devices.Place, klb1 []byte) error {
	n := (len(klb1) + linkChunk - 1) / linkChunk
	tok := hex.EncodeToString(p.Token[:])
	for i := 0; i < n; i++ {
		end := min((i+1)*linkChunk, len(klb1))
		line := linkLinePrefix + tok + " " + strconv.Itoa(i) + "/" + strconv.Itoa(n) + " " +
			base64.StdEncoding.EncodeToString(klb1[i*linkChunk:end])
		// a fresh tor may need a while for the phone's descriptor: tried
		// again, further apart, while the run lasts
		for try := 0; ; try++ {
			err := dial(ctx, p.Onion, line)
			if err == nil {
				break
			}
			select {
			case <-ctx.Done():
				return errLinkUnreached
			case <-time.After(linkBackoff(try)):
			}
		}
	}
	return nil
}

var linkBackoffs = []time.Duration{2 * time.Second, 5 * time.Second, 10 * time.Second, 20 * time.Second, 30 * time.Second}

func linkBackoff(try int) time.Duration {
	return linkBackoffs[min(try, len(linkBackoffs)-1)]
}

// ---- the phone ----

func linkStart(offer []byte, identity devices.Key) (string, *linkRun, error) {
	p, accept, err := devices.AcceptOffer(offer, identity, linkClock())
	if err != nil {
		return "", nil, err
	}
	toJ, toP, err := devices.Rendezvous(offer)
	if err != nil {
		return "", nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), devices.LinkLife+linkBundlesLate)
	r := &linkRun{st: lsAccept, p: p, identity: identity, toJ: toJ, toP: toP, cancel: cancel,
		confirm: make(chan struct{}, 1), deadline: linkClock().Add(devices.LinkLife + linkBundlesLate)}
	r.world()
	id := newLinkID()
	linkMu.Lock()
	// one link at a time: a new one ends the one before
	for k, o := range linkRuns {
		if o.p != nil {
			o.failed(lsWhyEnd)
			delete(linkRuns, k)
		}
	}
	linkRuns[id] = r
	linkMu.Unlock()
	go r.phone(ctx, accept)
	return id, r, nil
}

func (r *linkRun) phone(ctx context.Context, accept []byte) {
	defer r.ended()
	if err := r.phoneSteps(ctx, accept); err != nil {
		log.Printf("link: the phone's side ended (%s)", whyOf(err))
		r.failed(whyOf(err))
	}
}

func (r *linkRun) phoneSteps(ctx context.Context, accept []byte) error {
	if err := r.wire.post(ctx, r.toJ, accept); err != nil {
		return errLinkUnreached
	}
	seen := map[string]bool{}
	reveal, err := r.await(ctx, r.toP, "KLR2", seen, nil)
	if err != nil {
		return err
	}
	if err := r.p.HandleReveal(reveal, r.clock()); err != nil {
		return err
	}
	dk, err := r.p.Device()
	if err != nil {
		return err
	}
	sas, err := r.p.SAS()
	if err != nil {
		return err
	}
	r.mu.Lock()
	r.device, r.sas, r.st = dk, sas, lsDigits
	r.mu.Unlock()
	unwatch := r.watchEnd(ctx, r.toP)
	select {
	case <-r.confirm:
	case <-ctx.Done():
	}
	unwatch()
	if ctx.Err() != nil {
		return ctx.Err()
	}
	r.mu.Lock()
	list, want := r.list, r.want
	r.mu.Unlock()
	onion := r.onion()
	if err := r.p.Confirm(r.clock()); err != nil {
		return err
	}
	stream, err := devices.NewStreamKey()
	if err != nil {
		return err
	}
	bind, err := r.p.Bind()
	if err != nil {
		return err
	}
	w, err := r.p.Welcome(stream, r.clock())
	if err != nil {
		return err
	}
	after, err := r.p.After()
	if err != nil {
		return err
	}
	tok, err := devices.NewToken()
	if err != nil {
		return err
	}
	place, err := devices.SealPlace(after, bind, devices.Place{Onion: onion, Token: tok, Want: want, List: list})
	if err != nil {
		return err
	}
	r.mu.Lock()
	r.stream, r.after, r.bind, r.token = stream, after, bind, tok
	r.chunks, r.waiting = map[int]string{}, true
	r.mu.Unlock()
	if err := r.wire.post(ctx, r.toJ, w); err != nil {
		return errLinkUnreached
	}
	if err := r.wire.post(ctx, r.toJ, place); err != nil {
		return errLinkUnreached
	}
	// the rest comes through the door; an end from the new device is
	// watched for meanwhile
	_, err = r.await(ctx, r.toP, "\x00\x00\x00\x00", seen, nil)
	r.mu.Lock()
	st := r.st
	r.mu.Unlock()
	if st == lsDone {
		return nil
	}
	return err
}

// the phone's next own list with the device on it, unsigned, from the
// list held (the phone alone when none is)
func (d *devState) linkList(r *linkRun, ident int, phoneReg uint32) ([]byte, error) {
	id, ok := d.idents[ident]
	if !ok || d.mine[id].key != id || id != r.identity {
		return nil, devices.ErrUnknown
	}
	l := d.own.Current(id)
	if l == nil {
		var err error
		if l, err = devices.Genesis(id, phoneReg, rand.Reader); err != nil {
			return nil, err
		}
	}
	if len(l.Devices) >= devices.MaxDevices {
		return nil, devices.ErrTooMany
	}
	r.mu.Lock()
	dk, signed := r.device, r.list != nil
	r.mu.Unlock()
	if signed || r.p == nil {
		return nil, devices.ErrState
	}
	if _, taken := l.FindKey(dk.Key); taken {
		return nil, devices.ErrDuplicate
	}
	e, err := devices.EntryFor(l, dk, rand.Reader)
	if err != nil {
		return nil, err
	}
	next, err := l.Add(e, rand.Reader)
	if err != nil {
		return nil, err
	}
	// one bundle for each contact device the first copies may reach, a
	// phone for a contact with no list held, and the pool's usual eight
	want := 8
	for c, i := range d.peers {
		if i != ident {
			continue
		}
		if cl := d.book.Current(c); cl != nil {
			want += len(cl.Devices)
		} else {
			want++
		}
	}
	r.mu.Lock()
	r.next, r.ident, r.want = next, ident, min(want, devices.BundlesMost)
	r.mu.Unlock()
	return next.Body(), nil
}

// a signature made by dart's ks_sign over the body linkList gave
type givenSig struct {
	pub devices.Key
	sig []byte
}

func (g givenSig) Public() devices.Key { return g.pub }
func (g givenSig) Sign(string, []byte) ([]byte, error) {
	return append([]byte(nil), g.sig...), nil
}

// the door's side: a line of KLB1 for the link that waits, or false and
// the door treats it as it treats any line that is not a message
func linkDoorTake(line string) bool {
	if !strings.HasPrefix(line, linkLinePrefix) {
		return false
	}
	f := strings.Fields(line[len(linkLinePrefix):])
	if len(f) != 3 {
		return false
	}
	tok, err := hex.DecodeString(f[0])
	if err != nil || len(tok) != devices.TokenSize {
		return false
	}
	i, n, ok := chunkOf(f[1])
	if !ok {
		return false
	}
	linkMu.Lock()
	var r *linkRun
	for _, o := range linkRuns {
		o.mu.Lock()
		if o.waiting && subtle.ConstantTimeCompare(o.token[:], tok) == 1 {
			r = o
		}
		o.mu.Unlock()
	}
	linkMu.Unlock()
	if r == nil {
		return false
	}
	r.mu.Lock()
	if !r.waiting || (r.nChunks != 0 && r.nChunks != n) || len(f[2]) > base64.StdEncoding.EncodedLen(linkChunk) {
		r.mu.Unlock()
		return false
	}
	r.nChunks = n
	r.chunks[i] = f[2]
	if len(r.chunks) < n {
		r.mu.Unlock()
		return true
	}
	var klb1 []byte
	for k := 0; k < n; k++ {
		b, err := base64.StdEncoding.DecodeString(r.chunks[k])
		if err != nil {
			r.endBundles(nil, lsWhyBad)
			r.mu.Unlock()
			return false
		}
		klb1 = append(klb1, b...)
	}
	if !r.endBundles(klb1, "") {
		r.mu.Unlock()
		return false
	}
	kept := r.keptCh
	r.mu.Unlock()
	// the last line is acked only once the phone's app kept the device:
	// a page closed or a keep that failed leaves the new device unlinked
	// too, never half
	t := time.NewTimer(linkKeptWait)
	defer t.Stop()
	select {
	case <-kept:
	case <-t.C:
	}
	r.mu.Lock()
	tell := r.ack == 0 && r.failLocked(lsWhyReach)
	acked := r.ack == 1
	r.mu.Unlock()
	if !acked {
		r.cancel()
	}
	if tell {
		r.tellEnd()
	}
	return acked
}

func chunkOf(s string) (i, n int, ok bool) {
	a, b, found := strings.Cut(s, "/")
	if !found {
		return 0, 0, false
	}
	i, e1 := strconv.Atoi(a)
	n, e2 := strconv.Atoi(b)
	if e1 != nil || e2 != nil || n < 1 || n > linkChunksMost || i < 0 || i >= n || a != strconv.Itoa(i) || b != strconv.Itoa(n) {
		return 0, 0, false
	}
	return i, n, true
}

// the whole KLB1, or nothing: r.mu held. the token is spent either way.
// true when the bundles are the device's, under the list it was given
func (r *linkRun) endBundles(klb1 []byte, why string) bool {
	r.waiting = false
	r.chunks = nil
	if why == "" {
		l, err := devices.ParseList(r.list)
		var e devices.Entry
		ok := err == nil
		if ok {
			e, ok = l.FindKey(r.device.Key)
		}
		if !ok {
			why = lsWhyBad
		} else if b, err := devices.OpenBundles(r.after, r.bind, klb1, r.identity, e); err != nil {
			why = lsWhyBad
		} else {
			r.got, r.entry = b, e
		}
	}
	if why != "" {
		// the phone's goroutine wakes and ends, and wipes; the new device
		// hears of it at once
		if r.failLocked(why) {
			go r.tellEnd()
		}
		r.cancel()
		return false
	}
	r.st = lsBundles
	r.keptCh = make(chan struct{})
	return true
}

// ---- dart's calls ----

type linkArgs struct {
	Link  string   `json:"link"`
	Key   string   `json:"key"`
	Reg   uint32   `json:"reg"`
	Offer string   `json:"offer"`
	Ident int      `json:"ident"`
	Sig   []byte   `json:"sig"`
	First []byte   `json:"first"`
	Last  []byte   `json:"last"`
	Once  [][]byte `json:"once"`
	Made  int64    `json:"made"`
}

type linkOut struct {
	Err       string     `json:"err,omitempty"`
	Link      string     `json:"link,omitempty"`
	Offer     string     `json:"offer,omitempty"`
	St        string     `json:"st,omitempty"`
	Why       string     `json:"why,omitempty"`
	SAS       string     `json:"sas,omitempty"`
	Identity  string     `json:"identity,omitempty"`
	KeyNumber string     `json:"key_number,omitempty"`
	Device    *devEntry  `json:"device,omitempty"`
	Body      []byte     `json:"body,omitempty"`
	List      []byte     `json:"list,omitempty"`
	First     []byte     `json:"first,omitempty"`
	Last      []byte     `json:"last,omitempty"`
	Once      [][]byte   `json:"once,omitempty"`
	Made      int64      `json:"made,omitempty"`
	Stream    []byte     `json:"stream,omitempty"`
	Bind      []byte     `json:"bind,omitempty"`
	Onion     string     `json:"onion,omitempty"`
	Want      int        `json:"want,omitempty"`
	Rows      []devOp    `json:"rows,omitempty"`
	Gone      []devEntry `json:"gone,omitempty"`
}

// HaloDevLink runs one call of a link: op, and its args as json.
//
//export HaloDevLink
func HaloDevLink(cOp, cArgs *C.char) *C.char {
	return C.CString(devLinkJSON(goStr(cOp), goStr(cArgs)))
}

func devLinkJSON(op, raw string) string {
	out := &linkOut{}
	var a linkArgs
	err := json.Unmarshal([]byte(raw), &a)
	if err == nil {
		err = linkCall(op, &a, out)
	}
	if err != nil {
		out.Err = devErrName(err)
		if out.Err == "error" {
			out.Err = whyOf(err)
		}
	}
	b, jerr := json.Marshal(out)
	if jerr != nil {
		return `{"err":"error"}`
	}
	return string(b)
}

func runOf(id string) (*linkRun, error) {
	linkMu.Lock()
	defer linkMu.Unlock()
	r, ok := linkRuns[id]
	if !ok {
		return nil, devices.ErrUnknown
	}
	return r, nil
}

func linkCall(op string, a *linkArgs, out *linkOut) error {
	switch op {
	case "join_start":
		k, err := parseHexKey(a.Key)
		if err != nil {
			return err
		}
		id, r, err := joinStart(k, a.Reg)
		if err != nil {
			return err
		}
		out.Link, out.Offer = id, r.j.OfferText()
		return nil
	case "link_start":
		offer, err := devices.ParseOfferText(a.Offer)
		if err != nil {
			return err
		}
		k, err := parseHexKey(a.Key)
		if err != nil {
			return err
		}
		id, _, err := linkStart(offer, k)
		if err != nil {
			return err
		}
		out.Link = id
		return nil
	}
	r, err := runOf(a.Link)
	if err != nil {
		return err
	}
	switch op {
	case "state":
		r.state(out)
		return nil
	case "confirm":
		return r.confirmed()
	case "end":
		r.failed(lsWhyEnd)
		linkMu.Lock()
		delete(linkRuns, a.Link)
		linkMu.Unlock()
		return nil
	case "list":
		d := devNow()
		if d == nil {
			return devices.ErrUnknown
		}
		d.mu.Lock()
		defer d.mu.Unlock()
		body, err := d.linkList(r, a.Ident, a.Reg)
		out.Body = body
		return err
	case "sign":
		return r.signed(a.Sig)
	case "own":
		return r.takeOwn(a.Ident, out)
	case "bundles":
		return r.giveBundles(a)
	case "take":
		return r.take(a.Link, out)
	case "kept":
		return r.kept(a.Link)
	}
	return errors.New("no such call")
}

func (r *linkRun) state(out *linkOut) {
	r.mu.Lock()
	defer r.mu.Unlock()
	out.St, out.Why = r.st, r.why
	if r.st == lsDigits {
		out.SAS = r.sas
	}
	if r.linked != nil && (r.st == lsPlaced || r.st == lsSending || r.st == lsDone) {
		out.Identity = hexKey(r.linked.Identity)
		out.KeyNumber = r.linked.KeyNumber()
		e := entryOut(r.entry)
		out.Device = &e
		out.Want = r.place.Want
	}
	if r.p != nil && (r.st == lsBundles || r.st == lsKeeping) {
		e := entryOut(r.entry)
		out.Device = &e
	}
}

// the other side hears of an end at once, not when its own time runs out.
// sent on its own, not by the run, which is stopping; best effort
func (r *linkRun) tellEnd() {
	r.mu.Lock()
	to := r.toP
	if r.p != nil {
		to = r.toJ
	}
	w := r.wire
	r.mu.Unlock()
	msg := make([]byte, 4+16)
	copy(msg, linkEndMagic)
	rand.Read(msg[4:])
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		w.post(ctx, to, msg)
	}()
}

// the person said the digits match. the phone's side needs its signed
// list first
func (r *linkRun) confirmed() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.st != lsDigits || (r.p != nil && r.list == nil) {
		return devices.ErrState
	}
	select {
	case r.confirm <- struct{}{}:
	default:
	}
	return nil
}

// the phone's list signed by dart: checked through the shim before it
// goes anywhere
func (r *linkRun) signed(sig []byte) error {
	r.mu.Lock()
	next := r.next
	r.mu.Unlock()
	if next == nil || r.p == nil {
		return devices.ErrState
	}
	wire, err := next.Sign(givenSig{pub: r.identity, sig: sig})
	if err != nil {
		return err
	}
	if _, err := devices.ReadList(wire, devVerifier{devShimNow()}); err != nil {
		return err
	}
	r.mu.Lock()
	r.list = wire
	r.mu.Unlock()
	return nil
}

// the joiner's first own list, as the link brought it, into the state
// dart loaded for the new container: the only FromLink there is
func (r *linkRun) takeOwn(ident int, out *linkOut) error {
	r.mu.Lock()
	if r.j == nil || r.st != lsPlaced || r.ownTaken {
		r.mu.Unlock()
		return devices.ErrState
	}
	id, list, key := r.linked.Identity, r.place.List, r.linked.Keys.Key
	r.mu.Unlock()
	d := devNow()
	if d == nil {
		return devices.ErrUnknown
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	m, ok := d.mine[id]
	if !ok || m.ident != ident || m.key != key {
		return devices.ErrUnknown
	}
	s := d.snap(id)
	gone, err := d.own.Set(id, list, key, devices.FromLink(), d.v)
	out.Rows = s.rows()
	for _, e := range gone {
		out.Gone = append(out.Gone, entryOut(e))
	}
	if err != nil {
		return err
	}
	r.mu.Lock()
	r.ownTaken = true
	r.mu.Unlock()
	return nil
}

// the joiner's bundles, made by dart for its place: sealed and sent
func (r *linkRun) giveBundles(a *linkArgs) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.j == nil || r.st != lsPlaced || !r.ownTaken || r.given {
		return devices.ErrState
	}
	r.given = true
	klb1, err := devices.SealBundles(r.linked.After, r.linked.Bind, devices.Bundles{
		Made: time.UnixMilli(a.Made), First: a.First, Last: a.Last, Once: a.Once,
	})
	if err != nil {
		return err
	}
	select {
	case r.bundles <- klb1:
	default:
		return devices.ErrState
	}
	return nil
}

// what the link left for dart, once: the joiner's stream key; the phone's
// device, its list and its bundles. the run goes after
func (r *linkRun) take(id string, out *linkOut) error {
	if err := r.takeLocked(out); errors.Is(err, errStay) {
		return nil
	} else if err != nil {
		return err
	}
	linkMu.Lock()
	delete(linkRuns, id)
	linkMu.Unlock()
	return nil
}

func (r *linkRun) takeLocked(out *linkOut) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	switch {
	case r.j != nil && r.st == lsDone:
		out.Stream = append([]byte(nil), r.linked.StreamKey[:]...)
		out.Identity = hexKey(r.linked.Identity)
		// the history comes from the phone's onion, under this link's
		// transcript
		out.Bind = append([]byte(nil), r.linked.Bind[:]...)
		out.Onion = r.place.Onion
	case r.p != nil && r.st == lsBundles:
		e := entryOut(r.entry)
		out.Device = &e
		out.List = r.list
		out.First, out.Last, out.Once = r.got.First, r.got.Last, r.got.Once
		out.Made = r.got.Made.UnixMilli()
		out.Stream = append([]byte(nil), r.stream[:]...)
		out.Bind = append([]byte(nil), r.bind[:]...)
		// the run stays until dart kept the device ("kept") or not ("end")
		r.st = lsKeeping
		return errStay
	default:
		return devices.ErrState
	}
	r.forget()
	return nil
}

var errStay = errors.New("link: the run stays")

// the phone's app kept the device (its own list, bundles, notice): the
// door acks the last line and the new device is linked. an error here
// means the door gave up already, and dart keeps nothing
func (r *linkRun) kept(id string) error {
	r.mu.Lock()
	if r.p == nil || r.st != lsKeeping || r.ack != 0 {
		r.mu.Unlock()
		return devices.ErrState
	}
	r.ack, r.st = 1, lsDone
	close(r.keptCh)
	r.forget()
	r.mu.Unlock()
	r.cancel()
	linkMu.Lock()
	delete(linkRuns, id)
	linkMu.Unlock()
	return nil
}
