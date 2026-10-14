package main

// knocks for the helper app mode. a phone that keeps no connection open
// registers a unifiedpush endpoint for an address it listens on, and when a
// wrap for that address is stored the relay posts an empty knock to it. the
// phone then checks in over tor as it always does. the knock carries
// nothing: no sender, no count, no id, the same zero bytes every time.
//
// a registration is an ephemeral event signed by the address's own key, so
// only whoever can read the address can point it somewhere, and it comes
// over the same lane as the address's subscription. its content is the
// endpoint, empty to forget it. nothing else is kept: a hash of the
// address, the endpoint, the registration's time and when it expires. no
// ip, no connection, nothing logged per endpoint.
//
// every endpoint also gets decoy knocks, each on a timer of its own, so its
// timing says less about when anything arrived. real and decoy knocks are
// the same request and keep the same floor.
//
// endpoints are counted, queued and paced per push server, its registrable
// domain under an icann suffix. each well-known public push server has a
// share of its own; every other server shares one, and each of those has a
// small cap inside it. so minting endpoints, on random topics of a public
// server or on made-up servers, fills one share and never the relay. no ip
// literal, no private suffix (github.io and the like), no made-up tld. see
// knock_send.go for the posts, knock_store.go for the table.
//
// no proof of work on registrations: a phone would pay for it what a
// desktop pays a hundred times faster, so it slows the people it is meant
// to serve more than the one filling the table. the per-server shares bound
// what minting registrations buys.

import (
	"context"
	"crypto/sha256"
	"log"
	"math/rand/v2"
	"net"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
	"golang.org/x/net/publicsuffix"
)

const (
	knockKind = 21059
	// what the relay info lists, for the app to see this relay can knock
	knockTag = "knock/1"
	// a registration lives this long after it was signed. the app renews
	// its registrations every few days
	knockTTL = 30 * 24 * time.Hour
	// how far a registration's time may be from this box's: as far as a
	// wrap's, so a phone whose clock is off still registers. a forget is
	// kept this long past its own time, so no registration from before it
	// can come back inside the window
	knockSkew = futureSlack
	// real knocks to one endpoint, at most one a minute. wraps in between
	// get one more knock when the minute is up, a little later still
	knockFloor = time.Minute
	knockTrail = 30 * time.Second
	// addresses per endpoint. the phone uses sixteen endpoints whatever
	// its contacts
	maxRegsPerEP     = 256
	maxEndpointLen   = 512
	knockTick        = 30 * time.Second
	knockSweepChunk  = 1000
	knockFailFor     = 24 * time.Hour
	knockFailAtLeast = 5
)

// the mean gap between decoy bursts to one endpoint. a burst is one decoy,
// and like a conversation's knocks it is followed by more a floor and a
// random while apart, this often each: two on average. a phone has sixteen
// endpoints, so at eight hours it gets about four decoys an hour, as many
// check-ins as its own timer adds
var knockDecoyMean = time.Duration(envInt("RELAY_KNOCK_DECOY_MIN", 480)) * time.Minute

const knockDecoyMore = 0.5

// knocks in one decoy run, on average
func decoyRunMean() float64 { return 1 / (1 - knockDecoyMore) }

// the shares. each well-known push server holds its own, every other
// server shares one, and one server outside the list holds what about
// sixty-four phones use. the relay holds no more than the shares add up to
var (
	knockPushHostEPs  = envInt("RELAY_KNOCK_PUSH_HOST_EPS", 20000)
	knockPushHostRegs = envInt("RELAY_KNOCK_PUSH_HOST_REGS", 80000)
	knockSharedEPs    = envInt("RELAY_KNOCK_SHARED_EPS", 10000)
	knockSharedRegs   = envInt("RELAY_KNOCK_SHARED_REGS", 40000)
	knockServerEPs    = envInt("RELAY_KNOCK_SERVER_EPS", 1024)
	knockServerRegs   = envInt("RELAY_KNOCK_SERVER_REGS", 4096)
)

// the public push servers, by registrable domain: ntfy and the envs.net
// community ntfy, conversations' unifiedpush server, the unifiedpush fcm
// distributor, mozilla's autopush (sunup and the web push ones)
func knockPushHosts() map[string]bool {
	list := "ntfy.sh,envs.net,conversations.im,unifiedpush.org,mozilla.com"
	if v, ok := os.LookupEnv("RELAY_KNOCK_PUSH_HOSTS"); ok {
		list = v
	}
	out := map[string]bool{}
	for _, h := range strings.Split(list, ",") {
		if h = strings.ToLower(strings.TrimSpace(h)); h != "" {
			out[h] = true
		}
	}
	return out
}

// the ports an endpoint may name: 443 unless told otherwise
func knockPorts() map[string]bool {
	out := map[string]bool{"443": true}
	for _, p := range strings.Split(os.Getenv("RELAY_KNOCK_PORTS"), ",") {
		if n, err := strconv.Atoi(strings.TrimSpace(p)); err == nil && n > 0 && n < 65536 {
			out[strconv.Itoa(n)] = true
		}
	}
	return out
}

type knockEP struct {
	url, domain string
	// addresses registered to it, by key
	keys map[[32]byte]struct{}
	// the last knock out, real or decoy, and whether one waits for the floor
	last     time.Time
	trailing bool
	// a decoy timer from before is let go by its generation
	decoyGen int
	// waiting in its domain's queue
	queuedReal, queuedDecoy bool
	// failures in a row, since when
	fails        int
	failingSince time.Time
	// when the relay first took it, and whether a knock to it ever went
	// through: one a day old that did gets a lane new ones cannot fill
	born      time.Time
	delivered bool
}

// knocks for an endpoint known a day and proven are kept apart from new
// ones, so a flood of fresh endpoints on the same server cannot delay them
const knockTrustAfter = 24 * time.Hour

func (ep *knockEP) trusted(now time.Time) bool {
	return ep.delivered && now.Sub(ep.born) >= knockTrustAfter
}

type knockReg struct {
	ep      *knockEP
	made    int64
	expires int64
}

type knockStats struct{ real, decoys, failed, dropped, gone atomic.Int64 }

// what one share holds: a public push server's, or everyone else's
type knockShare struct{ eps, regs, epCap, regCap int }

type knocker struct {
	mu      sync.Mutex
	regs    map[[32]byte]*knockReg
	forgets map[[32]byte]int64
	eps     map[string]*knockEP
	domains map[string]*knockDomain
	shares  map[string]*knockShare
	store   *knockStore
	now     func() time.Time
	rnd     *rand.Rand
	onions  bool
	push    map[string]bool
	ports   map[string]bool
	stats   knockStats
	// the floor and the timers, for the tests
	floor time.Duration
	after func(time.Duration, func())
	q     knockQueue
}

// sha256 of the address: the table lists no address, a wrap's p tag finds
// its registration by the same hash
func knockKey(addr string) [32]byte { return sha256.Sum256([]byte(strings.ToLower(addr))) }

func newKnocker(store *knockStore, onions bool) *knocker {
	k := &knocker{
		regs:    map[[32]byte]*knockReg{},
		forgets: map[[32]byte]int64{},
		eps:     map[string]*knockEP{},
		domains: map[string]*knockDomain{},
		shares:  map[string]*knockShare{},
		store:   store,
		now:     time.Now,
		rnd:     rand.New(rand.NewPCG(rand.Uint64(), rand.Uint64())),
		onions:  onions,
		push:    knockPushHosts(),
		ports:   knockPorts(),
		floor:   knockFloor,
		after:   func(d time.Duration, f func()) { time.AfterFunc(d, f) },
	}
	k.q.init(k)
	return k
}

// the push server an endpoint belongs to: its registrable domain under an
// icann suffix, or an onion's own name. "" for an address, a private
// suffix or a tld that does not exist
func knockDomainOf(host string) string {
	host = strings.ToLower(host)
	if host == "" || strings.HasSuffix(host, ".") || strings.ContainsAny(host, "[]:%") {
		return ""
	}
	if net.ParseIP(host) != nil {
		return ""
	}
	if strings.HasSuffix(host, ".onion") {
		return host
	}
	if _, icann := publicsuffix.PublicSuffix(host); !icann {
		return ""
	}
	d, err := publicsuffix.EffectiveTLDPlusOne(host)
	if err != nil {
		return ""
	}
	return d
}

// the share a server's endpoints count in: its own for a known public push
// server, the common one ("") for any other
func (k *knocker) shareOf(domain string) (string, *knockShare) {
	name := ""
	if k.push[domain] {
		name = domain
	}
	sh := k.shares[name]
	if sh == nil {
		sh = &knockShare{epCap: knockSharedEPs, regCap: knockSharedRegs}
		if name != "" {
			sh.epCap, sh.regCap = knockPushHostEPs, knockPushHostRegs
		}
		k.shares[name] = sh
	}
	return name, sh
}

// a host written as a number in any base, which a resolver may read as an
// address
func numericHost(h string) bool {
	for _, part := range strings.Split(h, ".") {
		if part == "" {
			continue
		}
		p := strings.ToLower(part)
		if strings.HasPrefix(p, "0x") {
			return true
		}
		if _, err := strconv.ParseUint(p, 10, 64); err == nil {
			continue
		}
		return false
	}
	return true
}

// an endpoint is a url this relay will post to, named by whoever signs for
// an address. https on port 443 of a public name, or an onion when the
// box's tor is there to reach it. no user, no fragment, nothing longer
// than a push server hands out
func (k *knocker) endpointOK(raw string) bool {
	if len(raw) > maxEndpointLen || strings.ContainsAny(raw, " \t\r\n\\") {
		return false
	}
	u, err := url.Parse(raw)
	if err != nil || u.User != nil || u.Fragment != "" || u.Opaque != "" {
		return false
	}
	host := strings.ToLower(u.Hostname())
	if host == "" || strings.HasSuffix(host, ".") {
		return false
	}
	port := u.Port()
	if strings.HasSuffix(host, ".onion") {
		if !k.onions || (u.Scheme != "https" && u.Scheme != "http") {
			return false
		}
		return port == "" || port == "80" || port == "443"
	}
	if u.Scheme != "https" || host == "localhost" || strings.HasSuffix(host, ".localhost") {
		return false
	}
	if port != "" && !k.ports[port] {
		return false
	}
	if net.ParseIP(host) != nil || numericHost(host) {
		return false
	}
	return knockDomainOf(host) != ""
}

// the endpoint check with the default ports, for the tests and the loader
func knockEndpointOK(raw string, onions bool) bool {
	k := &knocker{onions: onions, ports: knockPorts()}
	return k.endpointOK(raw)
}

// what is kept for an address: the time of its registration or of its
// forget, and which
func (k *knocker) keptLocked(key [32]byte) (made int64, forget, any bool) {
	if r := k.regs[key]; r != nil {
		made, any = r.made, true
	}
	if f, ok := k.forgets[key]; ok && (!any || f >= made) {
		made, forget, any = f, true, true
	}
	return
}

// the reject hook's half: whether this registration may be taken. it is
// taken in apply, after khatru has run every reject hook.
//
// a pair address's key comes from the x25519 secret both ends share, so the
// contact on the other end can sign for it too. what that contact can do is
// point that one address, which only they write to, at a server of theirs,
// or forget it: the harm stays on that pair's lane. the ±skew window and
// newer-wins keep them from pinning a registration further ahead than that
func (k *knocker) check(ev *nostr.Event) (bool, string) {
	k.mu.Lock()
	defer k.mu.Unlock()
	return k.checkLocked(ev)
}

func (k *knocker) checkLocked(ev *nostr.Event) (bool, string) {
	if len(ev.Tags) != 0 {
		return true, "invalid: a knock registration has no tags"
	}
	if !isKey(ev.PubKey) {
		return true, "invalid: bad address"
	}
	now := k.now()
	t := ev.CreatedAt.Time()
	if t.Before(now.Add(-knockSkew)) || t.After(now.Add(knockSkew)) {
		return true, "invalid: created_at is too far from now"
	}
	forget := ev.Content == ""
	var domain string
	if !forget {
		if !k.endpointOK(ev.Content) {
			return true, "invalid: this endpoint cannot be knocked"
		}
		u, _ := url.Parse(ev.Content)
		domain = knockDomainOf(u.Hostname())
	}
	key := knockKey(ev.PubKey)
	made := int64(ev.CreatedAt)
	if kept, wasForget, any := k.keptLocked(key); any {
		// newer wins; in the same second a forget beats a registration
		if made < kept || (made == kept && !(forget && !wasForget)) {
			return true, "duplicate: not newer than what is kept"
		}
	}
	if forget {
		return false, ""
	}
	reg := k.regs[key]
	ep := k.eps[ev.Content]
	if reg != nil && reg.ep == ep {
		// a renewal takes nothing new
		return false, ""
	}
	name, sh := k.shareOf(domain)
	d := k.domains[domain]
	if ep == nil {
		if sh.eps >= sh.epCap {
			return true, "error: this push server has all the endpoints it may"
		}
		if name == "" && d != nil && d.eps >= knockServerEPs {
			return true, "error: this push server has all the endpoints it may"
		}
	} else if len(ep.keys) >= maxRegsPerEP {
		return true, "error: too many addresses on one endpoint"
	}
	if sh.regs >= sh.regCap || (name == "" && d != nil && d.regs >= knockServerRegs) {
		return true, "error: this push server has all the addresses it may"
	}
	return false, ""
}

// takes a registration, checked again in the same step, so two at once for
// one address end with the newer. a forget is on disk before the relay
// answers it: a crash right after cannot bring the registration back
func (k *knocker) apply(ev *nostr.Event) {
	if ev.Kind != knockKind {
		return
	}
	key := knockKey(ev.PubKey)
	made := int64(ev.CreatedAt)
	k.mu.Lock()
	if rej, _ := k.checkLocked(ev); rej {
		k.mu.Unlock()
		return
	}
	if ev.Content == "" {
		// only a forget that took something is kept: one for nothing
		// guards nothing
		if k.regs[key] == nil {
			k.mu.Unlock()
			return
		}
		k.dropLocked(key)
		k.forgets[key] = made
		done := k.store.putWait(key, "", made, made+int64(knockSkew/time.Second))
		k.mu.Unlock()
		k.store.wait(done)
		return
	}
	delete(k.forgets, key)
	k.setLocked(key, ev.Content, made, time.Unix(made, 0).Add(knockTTL).Unix())
	k.store.put(key, ev.Content, made, k.regs[key].expires)
	k.mu.Unlock()
}

func (k *knocker) setLocked(key [32]byte, endpoint string, made, expires int64) {
	if old := k.regs[key]; old != nil {
		if old.ep.url == endpoint {
			old.made, old.expires = made, expires
			return
		}
		k.dropLocked(key)
	}
	ep := k.eps[endpoint]
	d := (*knockDomain)(nil)
	if ep == nil {
		u, _ := url.Parse(endpoint)
		ep = &knockEP{url: endpoint, domain: knockDomainOf(u.Hostname()), keys: map[[32]byte]struct{}{}, born: time.Unix(made, 0)}
		if nb := k.now(); nb.Before(ep.born) {
			ep.born = nb
		}
		k.eps[endpoint] = ep
		d = k.domainLocked(ep.domain)
		d.eps++
		_, sh := k.shareOf(ep.domain)
		sh.eps++
		k.decoyLocked(ep)
	} else {
		d = k.domainLocked(ep.domain)
	}
	ep.keys[key] = struct{}{}
	d.regs++
	_, sh := k.shareOf(ep.domain)
	sh.regs++
	k.regs[key] = &knockReg{ep: ep, made: made, expires: expires}
}

func (k *knocker) dropLocked(key [32]byte) {
	reg := k.regs[key]
	if reg == nil {
		return
	}
	delete(k.regs, key)
	delete(reg.ep.keys, key)
	if d := k.domains[reg.ep.domain]; d != nil {
		d.regs--
	}
	_, sh := k.shareOf(reg.ep.domain)
	sh.regs--
	if len(reg.ep.keys) == 0 {
		k.dropEPLocked(reg.ep)
	}
}

func (k *knocker) dropEPLocked(ep *knockEP) {
	if k.eps[ep.url] != ep {
		return
	}
	delete(k.eps, ep.url)
	// its timers and queue places see it gone and do nothing
	ep.decoyGen++
	_, sh := k.shareOf(ep.domain)
	sh.eps--
	if d := k.domains[ep.domain]; d != nil {
		d.eps--
		k.q.forgetLocked(d, ep)
		if d.eps <= 0 && d.waiting() == 0 && d.inflight == 0 {
			delete(k.domains, ep.domain)
		}
	}
}

// exponential, so the gaps keep no rhythm of their own
func (k *knocker) decoyGap() time.Duration {
	return time.Duration(k.rnd.ExpFloat64() * float64(knockDecoyMean))
}

// the endpoint's next decoy, on a timer of its own: each one goes out at
// its own instant, never batched with others on a tick
func (k *knocker) decoyLocked(ep *knockEP) {
	ep.decoyGen++
	gen := ep.decoyGen
	k.after(k.decoyGap(), func() { k.decoyDue(ep, gen) })
}

func (k *knocker) decoyDue(ep *knockEP, gen int) {
	k.mu.Lock()
	defer k.mu.Unlock()
	if k.eps[ep.url] != ep || ep.decoyGen != gen {
		return
	}
	if k.ringLocked(ep, true) {
		k.decoyMoreLocked(ep, gen)
	}
	k.decoyLocked(ep)
}

// a decoy is followed, as a conversation's first knock is, by another a
// floor and a random while later, this often, and that one again
func (k *knocker) decoyMoreLocked(ep *knockEP, gen int) {
	if k.rnd.Float64() >= knockDecoyMore {
		return
	}
	wait := k.floor + time.Duration(k.rnd.Int64N(int64(knockTrail)))
	k.after(wait, func() {
		k.mu.Lock()
		defer k.mu.Unlock()
		if k.eps[ep.url] != ep || ep.decoyGen != gen+1 {
			return
		}
		if k.ringLocked(ep, true) {
			k.decoyMoreLocked(ep, gen)
		}
	})
}

// a wrap was stored: knock each registered address it names
func (k *knocker) stored(ev *nostr.Event) {
	if ev.Kind != wrapKind {
		return
	}
	for _, t := range ev.Tags {
		if len(t) >= 2 && t[0] == "p" {
			k.wrapFor(t[1])
		}
	}
}

func (k *knocker) wrapFor(addr string) {
	k.mu.Lock()
	defer k.mu.Unlock()
	reg := k.regs[knockKey(addr)]
	if reg == nil || reg.expires <= k.now().Unix() {
		return
	}
	k.ringLocked(reg.ep, false)
}

// one knock now if the floor allows, or one when it is up and a random
// while more, so the trailing knock keeps no fixed distance from the last.
// true when one went into the queue now
func (k *knocker) ringLocked(ep *knockEP, decoy bool) bool {
	// a trailing knock on its way carries this one too
	if ep.trailing {
		return false
	}
	now := k.now()
	if wait := ep.last.Add(k.floor).Sub(now); wait > 0 {
		// a decoy inside the floor is not needed: a knock just went
		if decoy {
			return false
		}
		ep.trailing = true
		wait += time.Duration(k.rnd.Int64N(int64(knockTrail)))
		k.after(wait, func() { k.trail(ep) })
		return false
	}
	ep.last = now
	k.q.addLocked(ep, decoy)
	return true
}

func (k *knocker) trail(ep *knockEP) {
	k.mu.Lock()
	defer k.mu.Unlock()
	ep.trailing = false
	if k.eps[ep.url] != ep {
		return
	}
	ep.last = k.now()
	k.q.addLocked(ep, false)
}

// the endpoint is gone for good: its push server said so, or it failed for
// a day on end
func (k *knocker) gone(endpoint string) {
	k.mu.Lock()
	defer k.mu.Unlock()
	ep := k.eps[endpoint]
	if ep == nil {
		return
	}
	keys := make([][32]byte, 0, len(ep.keys))
	for key := range ep.keys {
		keys = append(keys, key)
	}
	for _, key := range keys {
		k.dropLocked(key)
		k.store.put(key, "", 0, 0)
	}
	k.dropEPLocked(ep)
	k.stats.gone.Add(1)
}

// one pass of the timer: expired registrations and forgets go, a chunk at
// a time with the lock let go in between, so wraps keep being taken
func (k *knocker) tick() {
	for {
		now := k.now().Unix()
		k.mu.Lock()
		n := 0
		for key, reg := range k.regs {
			if n >= knockSweepChunk {
				break
			}
			if reg.expires <= now {
				// the table's copy may stay: a start deletes what expired
				k.dropLocked(key)
				k.store.putSweep(key)
				n++
			}
		}
		for key, made := range k.forgets {
			if n >= knockSweepChunk {
				break
			}
			if made+int64(knockSkew/time.Second) <= now {
				delete(k.forgets, key)
				k.store.putSweep(key)
				n++
			}
		}
		k.mu.Unlock()
		if n < knockSweepChunk {
			return
		}
	}
}

func (k *knocker) run(ctx context.Context) {
	k.q.start(ctx)
	t := time.NewTicker(knockTick)
	defer t.Stop()
	hour := time.NewTicker(time.Hour)
	defer hour.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			k.tick()
		case <-hour.C:
			k.logStats()
		}
	}
}

// counts only: never an endpoint, a host or an address
func (k *knocker) logStats() {
	k.mu.Lock()
	regs, eps, doms := len(k.regs), len(k.eps), len(k.domains)
	k.mu.Unlock()
	s := &k.stats
	log.Printf("knock: %d registrations, %d endpoints on %d servers, last hour %d knocks, %d decoys, %d failed, %d dropped, %d gone, %d table writes dropped",
		regs, eps, doms, s.real.Swap(0), s.decoys.Swap(0), s.failed.Swap(0), s.dropped.Swap(0), s.gone.Swap(0), k.store.droppedSwap())
}

// ---- wiring ----

// registrations come in through the reject hooks (limits.event, which
// counts them like any event) and are taken once every hook said yes. they
// are never handed to a listener
func applyKnocks(relay *khatru.Relay, l *limits, k *knocker) {
	l.knock = k
	relay.OnEphemeralEvent = append(relay.OnEphemeralEvent, func(_ context.Context, ev *nostr.Event) { k.apply(ev) })
	relay.OnEventSaved = append(relay.OnEventSaved, func(ctx context.Context, ev *nostr.Event) {
		// a wrap's knock comes out of its connection's budget; a knock per
		// endpoint is held to the floor besides
		if ev.Kind == wrapKind && l.takeKnock(ctx) {
			k.stored(ev)
		}
	})
	relay.PreventBroadcast = append(relay.PreventBroadcast, func(_ *khatru.WebSocket, ev *nostr.Event) bool {
		return ev.Kind == knockKind
	})
	relay.Info.Tags = append(relay.Info.Tags, knockTag)
}

func startKnocks(relay *khatru.Relay, l *limits, dataDir string) (*knocker, error) {
	store, err := openKnockStore(dataDir + "/knock.sqlite")
	if err != nil {
		return nil, err
	}
	socks := os.Getenv("RELAY_KNOCK_SOCKS")
	netw := "tcp4"
	if os.Getenv("RELAY_KNOCK_NET") == "tcp" {
		netw = "tcp"
	}
	noteSelfIPs()
	k := newKnocker(store, socks != "")
	k.q.post = knockPoster(knockClient(netw, socks))
	if err := k.load(); err != nil {
		store.close()
		return nil, err
	}
	store.start()
	applyKnocks(relay, l, k)
	go k.run(context.Background())
	return k, nil
}
