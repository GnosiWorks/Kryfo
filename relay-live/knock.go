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
// endpoints are counted, queued and paced per push server (its registrable
// domain), so one person's endpoints fill their own server's share and
// queue, not everyone's. see knock_send.go for the posts, knock_store.go
// for the table.
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
	// registrations, endpoints and addresses per endpoint, for everyone
	// together. the phone uses sixteen endpoints whatever its contacts
	maxKnockRegs     = 400000
	maxKnockEPs      = 200000
	maxRegsPerEP     = 256
	maxEndpointLen   = 512
	knockTick        = 30 * time.Second
	knockSweepChunk  = 1000
	knockFailFor     = 24 * time.Hour
	knockFailAtLeast = 5
)

// the mean gap between decoys to one endpoint. a phone has sixteen
// endpoints, so at four hours it gets one every fifteen minutes, as many
// check-ins as its own timer adds
var knockDecoyMean = time.Duration(envInt("RELAY_KNOCK_DECOY_MIN", 240)) * time.Minute

// endpoints one push server may hold: a server of one's own, or one we do
// not know, holds what sixteen phones use; the big public ones far more
var (
	knockPerDomain   = envInt("RELAY_KNOCK_PER_DOMAIN", 256)
	knockPerPushHost = envInt("RELAY_KNOCK_PER_PUSH_HOST", 100000)
)

// the public push servers, by registrable domain: ntfy, conversations'
// unifiedpush server, mozilla's autopush (sunup and the web push ones)
func knockPushHosts() map[string]bool {
	list := "ntfy.sh,conversations.im,mozilla.com"
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
	// addresses registered to it
	regs int
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
}

type knockReg struct {
	ep      *knockEP
	made    int64
	expires int64
}

type knockStats struct{ real, decoys, failed, dropped, gone atomic.Int64 }

type knocker struct {
	mu      sync.Mutex
	regs    map[[32]byte]*knockReg
	forgets map[[32]byte]int64
	eps     map[string]*knockEP
	domains map[string]*knockDomain
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

// the push server an endpoint belongs to: its registrable domain, or the
// host itself for an address or an onion. "" for one that has none
func knockDomainOf(host string) string {
	host = strings.ToLower(strings.TrimSuffix(host, "."))
	if host == "" {
		return ""
	}
	if net.ParseIP(host) != nil || strings.HasSuffix(host, ".onion") {
		return host
	}
	d, err := publicsuffix.EffectiveTLDPlusOne(host)
	if err != nil {
		return ""
	}
	return d
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
	if ip := net.ParseIP(host); ip != nil {
		if !publicIP(ip) || selfIP(ip) {
			return false
		}
	} else if numericHost(host) {
		return false
	}
	return knockDomainOf(host) != ""
}

// the endpoint check with the default ports, for the tests and the loader
func knockEndpointOK(raw string, onions bool) bool {
	k := &knocker{onions: onions, ports: knockPorts()}
	return k.endpointOK(raw)
}

func (k *knocker) domainCap(d string) int {
	if k.push[d] {
		return knockPerPushHost
	}
	return knockPerDomain
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
	k.mu.Lock()
	defer k.mu.Unlock()
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
	if reg == nil && len(k.regs) >= maxKnockRegs {
		return true, "error: the relay is full, try later"
	}
	if ep == nil {
		if len(k.eps) >= maxKnockEPs {
			return true, "error: the relay is full, try later"
		}
		if d := k.domains[domain]; d != nil && d.eps >= k.domainCap(domain) {
			return true, "error: this push server has all the endpoints it may"
		}
	}
	if ep != nil && ep.regs >= maxRegsPerEP && (reg == nil || reg.ep != ep) {
		return true, "error: too many addresses on one endpoint"
	}
	return false, ""
}

// takes a registration that passed check
func (k *knocker) apply(ev *nostr.Event) {
	if ev.Kind != knockKind {
		return
	}
	if rej, _ := k.check(ev); rej {
		return
	}
	key := knockKey(ev.PubKey)
	made := int64(ev.CreatedAt)
	k.mu.Lock()
	defer k.mu.Unlock()
	if ev.Content == "" {
		// only a forget that took something is kept: one for nothing
		// guards nothing
		if k.regs[key] == nil {
			return
		}
		k.dropLocked(key)
		k.forgets[key] = made
		k.store.put(key, "", made, made+int64(knockSkew/time.Second))
		return
	}
	delete(k.forgets, key)
	k.setLocked(key, ev.Content, made, time.Unix(made, 0).Add(knockTTL).Unix())
	k.store.put(key, ev.Content, made, k.regs[key].expires)
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
	if ep == nil {
		u, _ := url.Parse(endpoint)
		ep = &knockEP{url: endpoint, domain: knockDomainOf(u.Hostname())}
		k.eps[endpoint] = ep
		k.domainLocked(ep.domain).eps++
		k.decoyLocked(ep)
	}
	ep.regs++
	k.regs[key] = &knockReg{ep: ep, made: made, expires: expires}
}

func (k *knocker) dropLocked(key [32]byte) {
	reg := k.regs[key]
	if reg == nil {
		return
	}
	delete(k.regs, key)
	reg.ep.regs--
	if reg.ep.regs <= 0 {
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
	if d := k.domains[ep.domain]; d != nil {
		d.eps--
		k.q.forgetLocked(d, ep)
		if d.eps <= 0 && d.waiting() == 0 {
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
	k.ringLocked(ep, true)
	k.decoyLocked(ep)
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
// while more, so the trailing knock keeps no fixed distance from the last
func (k *knocker) ringLocked(ep *knockEP, decoy bool) {
	// a trailing knock on its way carries this one too
	if ep.trailing {
		return
	}
	now := k.now()
	if wait := ep.last.Add(k.floor).Sub(now); wait > 0 {
		// a decoy inside the floor is not needed: a knock just went
		if decoy {
			return
		}
		ep.trailing = true
		wait += time.Duration(k.rnd.Int64N(int64(knockTrail)))
		k.after(wait, func() { k.trail(ep) })
		return
	}
	ep.last = now
	k.q.addLocked(ep, decoy)
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
	var keys [][32]byte
	for key, reg := range k.regs {
		if reg.ep == ep {
			keys = append(keys, key)
		}
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
				k.dropLocked(key)
				k.store.put(key, "", 0, 0)
				n++
			}
		}
		for key, made := range k.forgets {
			if n >= knockSweepChunk {
				break
			}
			if made+int64(knockSkew/time.Second) <= now {
				delete(k.forgets, key)
				k.store.put(key, "", 0, 0)
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
	log.Printf("knock: %d registrations, %d endpoints on %d servers, last hour %d knocks, %d decoys, %d failed, %d dropped, %d gone",
		regs, eps, doms, s.real.Swap(0), s.decoys.Swap(0), s.failed.Swap(0), s.dropped.Swap(0), s.gone.Swap(0))
}

// ---- wiring ----

// registrations come in through the reject hooks (limits.event, which
// counts them like any event) and are taken once every hook said yes. they
// are never handed to a listener
func applyKnocks(relay *khatru.Relay, l *limits, k *knocker) {
	l.knock = k
	relay.OnEphemeralEvent = append(relay.OnEphemeralEvent, func(_ context.Context, ev *nostr.Event) { k.apply(ev) })
	relay.OnEventSaved = append(relay.OnEventSaved, func(_ context.Context, ev *nostr.Event) { k.stored(ev) })
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
