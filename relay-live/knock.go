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
	"errors"
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

// the mean gap between decoy runs to one endpoint. a run is shaped like a
// conversation's knocks: half are short, one to a few knocks, half long,
// three and more with a long tail, mostly a floor and a little apart and
// now and then minutes. 3.3 knocks a run on average: a phone has sixteen
// endpoints, so at thirteen hours it gets about four decoys an hour, as
// many check-ins as its own timer adds
var knockDecoyMean = time.Duration(envInt("RELAY_KNOCK_DECOY_MIN", 780)) * time.Minute

const (
	knockDecoyShortMore = 0.4
	knockDecoyLongMore  = 0.65
	knockDecoyLongRuns  = 0.5
	knockDecoyPause     = 0.15
	knockDecoyMaxRun    = 30
)

// knocks in one decoy run, on average
func decoyRunMean() float64 {
	short := 1 + knockDecoyShortMore/(1-knockDecoyShortMore)
	long := 3 + knockDecoyLongMore/(1-knockDecoyLongMore)
	return (1-knockDecoyLongRuns)*short + knockDecoyLongRuns*long
}

// the length of one decoy run
func (k *knocker) decoyRun() int {
	n, more := 1, knockDecoyShortMore
	if k.rnd.Float64() < knockDecoyLongRuns {
		n, more = 3, knockDecoyLongMore
	}
	for n < knockDecoyMaxRun && k.rnd.Float64() < more {
		n++
	}
	return n
}

// the shares. each well-known push server holds its own, every other
// server shares one, and one server outside the list holds what about
// sixteen phones use (a community server can be added to the list). the
// relay holds no more than the shares add up to. new registrations come
// at a pace per share; the last twentieth of a share is kept for
// addresses already there; endpoints that never worked yet hold at most a
// tenth of a public server's share, and a quarter of one other server's
// cap, until they deliver once or are a day old
var (
	knockPushHostEPs  = envInt("RELAY_KNOCK_PUSH_HOST_EPS", 20000)
	knockPushHostRegs = envInt("RELAY_KNOCK_PUSH_HOST_REGS", 80000)
	knockSharedEPs    = envInt("RELAY_KNOCK_SHARED_EPS", 20000)
	knockSharedRegs   = envInt("RELAY_KNOCK_SHARED_REGS", 80000)
	knockServerEPs    = envInt("RELAY_KNOCK_SERVER_EPS", 256)
	knockServerRegs   = envInt("RELAY_KNOCK_SERVER_REGS", 1024)
	// new registrations an hour, per share
	knockPushHostFresh = envInt("RELAY_KNOCK_PUSH_HOST_NEW_PER_HOUR", 4000)
	knockSharedFresh   = envInt("RELAY_KNOCK_SHARED_NEW_PER_HOUR", 1000)
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
	// when the relay first took this address
	first int64
}

type knockStats struct{ real, decoys, failed, dropped, gone atomic.Int64 }

// what one share holds: a public push server's, or everyone else's
type knockShare struct {
	eps, regs, epCap, regCap int
	// endpoints that have not delivered yet and are less than a day old
	pending map[*knockEP]struct{}
	// new registrations, so many an hour
	fresh *bucket
}

func (sh *knockShare) pendingCap() int { return sh.epCap / 10 }

// a token of the hour back, for a registration that did not stay
func (sh *knockShare) giveBack() {
	if sh.fresh.tokens += 1; sh.fresh.tokens > sh.fresh.max {
		sh.fresh.tokens = sh.fresh.max
	}
}

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
	// a new registration out of its connection's budget (limits.go)
	newReg func(ctx context.Context) bool
	// names looked up, and until when the answer holds
	lookup  func(ctx context.Context, host string) ([]net.IP, error)
	names   map[string]knockName
	namesMu sync.Mutex
	// name lookups, so many a second for everyone
	lookups *bucket
}

const knockNamesKept = 10000

type knockName struct {
	ok    bool
	until time.Time
}

// whether a name has a public address: "" when it has, or the answer to
// give. asked with a context of its own, so a caller that goes away cannot
// cut the lookup short, and at most so many a second for everyone. only a
// definite answer is remembered: an hour when the name has a public
// address, ten minutes when it does not exist or has none. a timeout or a
// failing resolver is never remembered
func (k *knocker) nameCheck(host string) string {
	host = strings.ToLower(host)
	now := time.Now()
	k.namesMu.Lock()
	if n, ok := k.names[host]; ok && now.Before(n.until) {
		k.namesMu.Unlock()
		if n.ok {
			return ""
		}
		return "invalid: this endpoint's name does not resolve"
	}
	if !k.lookups.take(now) {
		k.namesMu.Unlock()
		return "rate-limited: too many names to look up, try later"
	}
	k.namesMu.Unlock()
	lctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	ips, err := k.lookup(lctx, host)
	cancel()
	var dnsErr *net.DNSError
	definite := err == nil || (errors.As(err, &dnsErr) && dnsErr.IsNotFound)
	if !definite {
		return "error: the name could not be looked up, try again"
	}
	ok := false
	if err == nil {
		for _, ip := range ips {
			ok = ok || (publicIP(ip) && !selfIP(ip))
		}
	}
	hold := 10 * time.Minute
	if ok {
		hold = time.Hour
	}
	k.namesMu.Lock()
	k.rememberLocked(host, knockName{ok, now.Add(hold)})
	k.namesMu.Unlock()
	if ok {
		return ""
	}
	return "invalid: this endpoint's name does not resolve"
}

// a full cache lets one entry go, an expired one where it finds one
func (k *knocker) rememberLocked(host string, n knockName) {
	if _, there := k.names[host]; !there && len(k.names) >= knockNamesKept {
		var victim string
		seen := 0
		now := time.Now()
		for h, old := range k.names {
			if victim == "" || now.After(old.until) {
				victim = h
			}
			if seen++; seen >= 64 || now.After(old.until) {
				break
			}
		}
		delete(k.names, victim)
	}
	k.names[host] = n
}

// for the tests: whether a name passes
func (k *knocker) resolves(_ context.Context, host string) bool { return k.nameCheck(host) == "" }

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
		names:   map[string]knockName{},
		lookups: newBucket(20, 40),
		lookup: func(ctx context.Context, host string) ([]net.IP, error) {
			addrs, err := net.DefaultResolver.LookupIPAddr(ctx, host)
			var ips []net.IP
			for _, a := range addrs {
				ips = append(ips, a.IP)
			}
			return ips, err
		},
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
		fresh := knockSharedFresh
		sh = &knockShare{epCap: knockSharedEPs, regCap: knockSharedRegs, pending: map[*knockEP]struct{}{}}
		if name != "" {
			sh.epCap, sh.regCap, fresh = knockPushHostEPs, knockPushHostRegs, knockPushHostFresh
		}
		sh.fresh = newBucket(float64(fresh)/3600, float64(fresh))
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
	// the last twentieth of a share is for addresses already registered
	full := func(n, max int) bool {
		if reg != nil {
			return n >= max
		}
		return n >= max-max/20
	}
	if ep == nil {
		if full(sh.eps, sh.epCap) || (name == "" && d != nil && d.eps >= knockServerEPs) {
			return true, "error: this push server has all the endpoints it may"
		}
		if name != "" && len(sh.pending) >= sh.pendingCap() ||
			name == "" && d != nil && d.pending >= knockServerEPs/4 {
			return true, "error: too many new endpoints on this push server, try later"
		}
	} else if len(ep.keys) >= maxRegsPerEP {
		return true, "error: too many addresses on one endpoint"
	}
	if full(sh.regs, sh.regCap) || (name == "" && d != nil && d.regs >= knockServerRegs) {
		return true, "error: this push server has all the addresses it may"
	}
	return false, ""
}

// takes a registration as the reject hook, checked and kept in one step,
// so two at once for one address end with the newer, and a share cannot
// fill between the check and the taking. a forget is written to disk, on
// its own path and synced, before the relay answers it; one that cannot be
// written is answered with an error, so the phone sends it again
func (k *knocker) take(ctx context.Context, ev *nostr.Event) (bool, string) {
	if ev.Content == "" {
		return k.takeForget(ev)
	}
	key := knockKey(ev.PubKey)
	made := int64(ev.CreatedAt)
	now := k.now()
	k.mu.Lock()
	if rej, msg := k.checkLocked(ev); rej {
		k.mu.Unlock()
		return rej, msg
	}
	reg := k.regs[key]
	ep := k.eps[ev.Content]
	u, _ := url.Parse(ev.Content)
	host := strings.ToLower(u.Hostname())
	domain := knockDomainOf(host)
	_, sh := k.shareOf(domain)
	if reg == nil || reg.ep != ep {
		// a new registration or a move: out of the connection's budget
		if k.newReg != nil && ctx != nil && !k.newReg(ctx) {
			k.mu.Unlock()
			return true, "rate-limited: too many new registrations at once"
		}
	}
	// a token of the share's hour only when the share grows: a new address,
	// or a new endpoint
	tookFresh := false
	if reg == nil || ep == nil {
		if !sh.fresh.take(now) {
			k.mu.Unlock()
			return true, "error: too many new registrations on this push server, try later"
		}
		tookFresh = true
	}
	// a server outside the list must have a name that resolves: looked up
	// for a new endpoint only, after every other check, with the lock let go
	lookup := ep == nil && !k.push[domain] && !strings.HasSuffix(host, ".onion")
	k.mu.Unlock()
	if lookup {
		if msg := k.nameCheck(host); msg != "" {
			if tookFresh {
				k.mu.Lock()
				sh.giveBack()
				k.mu.Unlock()
			}
			return true, msg
		}
	}
	k.mu.Lock()
	defer k.mu.Unlock()
	if lookup {
		// things may have moved while the name was looked up
		if rej, msg := k.checkLocked(ev); rej {
			if tookFresh {
				sh.giveBack()
			}
			return rej, msg
		}
	}
	delete(k.forgets, key)
	k.setLocked(key, ev.Content, made, time.Unix(made, 0).Add(knockTTL).Unix())
	k.store.put(key, ev.Content, made, k.regs[key].expires)
	return false, ""
}

// a forget is written to disk, on its own path and synced, before the
// relay answers it; one that cannot be written is answered with an error,
// so the phone sends it again
func (k *knocker) takeForget(ev *nostr.Event) (bool, string) {
	key := knockKey(ev.PubKey)
	made := int64(ev.CreatedAt)
	k.mu.Lock()
	if rej, msg := k.checkLocked(ev); rej {
		k.mu.Unlock()
		return rej, msg
	}
	// only a forget that took something is kept: one for nothing guards
	// nothing
	if k.regs[key] == nil {
		k.mu.Unlock()
		return false, ""
	}
	k.mu.Unlock()
	if msg := k.store.writeForget(key, made, made+int64(knockSkew/time.Second)); msg != "" {
		return true, msg
	}
	k.mu.Lock()
	defer k.mu.Unlock()
	if kept, _, any := k.keptLocked(key); any && kept > made {
		// a newer one came meanwhile; on disk the newer wins as well
		return true, "duplicate: not newer than what is kept"
	}
	// an address taken within the hour and forgotten gives its token back
	if reg := k.regs[key]; reg != nil && k.now().Unix()-reg.first < 3600 {
		_, sh := k.shareOf(reg.ep.domain)
		sh.giveBack()
	}
	k.dropLocked(key)
	k.forgets[key] = made
	return false, ""
}

// take, for the tests: the answer left out
func (k *knocker) apply(ev *nostr.Event) {
	if ev.Kind == knockKind {
		k.take(nil, ev)
	}
}

func (k *knocker) setLocked(key [32]byte, endpoint string, made, expires int64) {
	first := k.now().Unix()
	if old := k.regs[key]; old != nil {
		if old.ep.url == endpoint {
			old.made, old.expires = made, expires
			return
		}
		first = old.first
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
		sh.pending[ep] = struct{}{}
		d.pending++
		k.decoyLocked(ep)
	} else {
		d = k.domainLocked(ep.domain)
	}
	ep.keys[key] = struct{}{}
	d.regs++
	_, sh := k.shareOf(ep.domain)
	sh.regs++
	k.regs[key] = &knockReg{ep: ep, made: made, expires: expires, first: first}
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
	k.settledLocked(ep)
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

// an endpoint no longer counted as new: it delivered, it is a day old, or
// it is gone
func (k *knocker) settledLocked(ep *knockEP) {
	_, sh := k.shareOf(ep.domain)
	if _, ok := sh.pending[ep]; !ok {
		return
	}
	delete(sh.pending, ep)
	if d := k.domains[ep.domain]; d != nil {
		d.pending--
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
		k.decoyRunLocked(ep, gen, k.decoyRun()-1)
	}
	k.decoyLocked(ep)
}

// the rest of a decoy run, as a conversation's knocks follow its first:
// mostly a floor and a little apart, now and then a pause of minutes
func (k *knocker) decoyRunLocked(ep *knockEP, gen, left int) {
	if left <= 0 {
		return
	}
	wait := k.floor + time.Duration(k.rnd.Int64N(int64(knockTrail)))
	if k.rnd.Float64() < knockDecoyPause {
		wait = k.floor + knockTrail + time.Duration(k.rnd.Int64N(int64(8*time.Minute)))
	}
	k.after(wait, func() {
		k.mu.Lock()
		defer k.mu.Unlock()
		if k.eps[ep.url] != ep || ep.decoyGen != gen+1 {
			return
		}
		if k.ringLocked(ep, true) {
			k.decoyRunLocked(ep, gen, left-1)
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
	k.mu.Lock()
	now0 := k.now()
	for _, sh := range k.shares {
		for ep := range sh.pending {
			if now0.Sub(ep.born) >= knockTrustAfter {
				k.settledLocked(ep)
			}
		}
	}
	k.mu.Unlock()
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

// registrations come in through the reject hook (limits.event, which counts
// them like any event) and are taken there, so the answer says whether they
// were. they are never handed to a listener
func applyKnocks(relay *khatru.Relay, l *limits, k *knocker) {
	l.knock = k
	k.newReg = l.takeNewReg
	// taken in the reject hook already; this only lets khatru answer ok
	relay.OnEphemeralEvent = append(relay.OnEphemeralEvent, func(context.Context, *nostr.Event) {})
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
