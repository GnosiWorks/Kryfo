package main

// the posts. knocks wait per push server, and the servers are served in
// turn, the well-known public ones and all the others by turns, so that
// made-up servers can take at most half the turns, half the workers and
// their own slice of the queue. each server has its own pace, at most a
// couple of posts are in flight to one server and to one address, the
// name lookup counted, and a post gets three seconds. an endpoint that
// fails for a day on end is let go.

import (
	"bytes"
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"syscall"
	"time"

	"golang.org/x/net/proxy"
)

const (
	knockPostTimeout  = 3 * time.Second
	knockOnionTimeout = 30 * time.Second
	knockWorkers      = 32
	// workers the servers outside the list may hold at once
	knockSharedWorkers = 16
	// knocks waiting: one public push server, all the others together, and
	// one of those
	knockPushHostQueue = 2048
	knockSharedQueue   = 1024
	knockDomainQueue   = 64
	// posts in flight to one server, and to one address
	knockPerServer     = 2
	knockPerPushServer = 8
	knockPerIP         = 2
	knockPerPushHostIP = 8
	// how long a push server keeps a knock for a phone that is offline
	knockPushTTL = "3600"
)

// knocks sent per second for everyone together, decoys within half of it
var knockPerSec = envInt("RELAY_KNOCK_PER_SEC", 50)

// per server: a public push server takes far more than one of a few phones
var (
	knockDomainPerSec   = float64(envInt("RELAY_KNOCK_DOMAIN_PER_SEC", 2))
	knockPushHostPerSec = float64(envInt("RELAY_KNOCK_PUSH_HOST_PER_SEC", 50))
)

type knockJob struct {
	url   string
	decoy bool
}

type knockDomain struct {
	name      string
	push      bool
	eps, regs int
	// endpoints that never delivered yet and are less than a day old
	pending int
	// real knocks by the endpoint's age tier (knockEP.tier), and decoys
	lanes [knockTiers][]*knockEP
	decoy []*knockEP
	// each lane's turns so far, for the weighted turns between them
	credit [knockTiers]int
	inRing bool
	rate   *bucket
	// posts in flight, from the name lookup on
	inflight int
	// pending endpoints whose name passed unchecked
	unchecked int
}

func (d *knockDomain) waiting() int {
	n := len(d.decoy)
	for _, l := range d.lanes {
		n += len(l)
	}
	return n
}

// the lane whose turn it is, among those with knocks: weighted turns, so an
// older tier gets more of them and a new one never none. -1 for none
func (d *knockDomain) nextLane() int {
	total, best := 0, -1
	for t := range d.lanes {
		if len(d.lanes[t]) == 0 {
			continue
		}
		d.credit[t] += knockTierWeight[t]
		total += knockTierWeight[t]
		if best < 0 || d.credit[t] > d.credit[best] {
			best = t
		}
	}
	if best >= 0 {
		d.credit[best] -= total
	}
	return best
}

func (d *knockDomain) queueCap() int {
	if d.push {
		return knockPushHostQueue
	}
	return knockDomainQueue
}

func (d *knockDomain) busyCap() int {
	if d.push {
		return knockPerPushServer
	}
	return knockPerServer
}

func (k *knocker) domainLocked(name string) *knockDomain {
	d := k.domains[name]
	if d == nil {
		d = &knockDomain{name: name, push: k.push[name]}
		if d.push {
			d.rate = newBucket(knockPushHostPerSec, knockPushHostPerSec*10)
		} else {
			d.rate = newBucket(knockDomainPerSec, knockDomainPerSec*30)
		}
		k.domains[name] = d
	}
	return d
}

type knockQueue struct {
	k *knocker
	// servers with knocks waiting, served in turn: the public push servers
	// in one ring, all the others in the other, the two by turns
	push, shared []*knockDomain
	turn         bool
	// knocks waiting in the shared ring, and its posts in flight
	sharedQueued, sharedBusy int
	queued                   int
	cond                     *sync.Cond
	rate                     *bucket
	ipBusy                   map[string]int
	stopped                  bool
	post                     func(ctx context.Context, endpoint string) (int, error)
	resolve                  func(ctx context.Context, host string) ([]net.IP, error)
}

func (q *knockQueue) init(k *knocker) {
	q.k = k
	q.cond = sync.NewCond(&k.mu)
	q.rate = newBucket(float64(knockPerSec), float64(knockPerSec)*10)
	q.ipBusy = map[string]int{}
	q.resolve = knockResolver("tcp4")
}

func (q *knockQueue) ringOf(d *knockDomain) *[]*knockDomain {
	if d.push {
		return &q.push
	}
	return &q.shared
}

func (q *knockQueue) ringAppend(d *knockDomain) {
	if !d.inRing {
		d.inRing = true
		r := q.ringOf(d)
		*r = append(*r, d)
	}
}

// a knock to wait its turn. one of each kind per endpoint at most; decoys
// only while their queue is less than half full
func (q *knockQueue) addLocked(ep *knockEP, decoy bool) {
	k := q.k
	if k.eps[ep.url] != ep {
		return
	}
	d := k.domainLocked(ep.domain)
	tier := ep.tier(k.now())
	fresh := len(d.lanes[0]) + len(d.decoy)
	full := fresh >= d.queueCap() || (!d.push && q.sharedQueued >= knockSharedQueue)
	half := fresh >= d.queueCap()/2 || (!d.push && q.sharedQueued >= knockSharedQueue/2)
	if decoy {
		if ep.queuedDecoy || ep.queuedReal {
			return
		}
		if half {
			k.stats.dropped.Add(1)
			return
		}
		ep.queuedDecoy = true
		d.decoy = append(d.decoy, ep)
	} else if tier > 0 {
		// a lane per tier, each as long as a server's queue
		if ep.queuedReal {
			return
		}
		if len(d.lanes[tier]) >= d.queueCap() {
			k.stats.dropped.Add(1)
			return
		}
		ep.queuedReal = true
		d.lanes[tier] = append(d.lanes[tier], ep)
	} else {
		if ep.queuedReal {
			return
		}
		if full {
			k.stats.dropped.Add(1)
			return
		}
		ep.queuedReal = true
		d.lanes[0] = append(d.lanes[0], ep)
	}
	q.queued++
	if !d.push {
		q.sharedQueued++
	}
	q.ringAppend(d)
	q.cond.Signal()
}

func without(s []*knockEP, ep *knockEP) ([]*knockEP, bool) {
	for i, e := range s {
		if e == ep {
			return append(s[:i], s[i+1:]...), true
		}
	}
	return s, false
}

func (q *knockQueue) unqueued(d *knockDomain) {
	q.queued--
	if !d.push {
		q.sharedQueued--
	}
}

// an endpoint let go leaves the queue
func (q *knockQueue) forgetLocked(d *knockDomain, ep *knockEP) {
	var gone bool
	for t := range d.lanes {
		if d.lanes[t], gone = without(d.lanes[t], ep); gone {
			q.unqueued(d)
		}
	}
	if d.decoy, gone = without(d.decoy, ep); gone {
		q.unqueued(d)
	}
	ep.queuedReal, ep.queuedDecoy = false, false
}

// how long until the shared budget has a token
func (q *knockQueue) budgetWait(now time.Time) time.Duration {
	q.rate.takeN(now, 0)
	if q.rate.tokens >= 1 {
		return 0
	}
	if q.rate.perSec <= 0 {
		return time.Hour
	}
	return time.Duration((1 - q.rate.tokens) / q.rate.perSec * float64(time.Second))
}

// the next knock: the two rings by turns, each server in its ring in turn,
// a real knock before a decoy, from a server with pace to spare and room
// for another post. nothing is walked while the shared budget is empty,
// and no server's token is spent unless the shared budget gives one too.
// the server's in-flight count is taken here, before the name lookup
func (q *knockQueue) nextLocked(now time.Time) (ep *knockEP, decoy, ok bool) {
	if q.budgetWait(now) > 0 {
		return nil, false, false
	}
	q.turn = !q.turn
	rings := []*[]*knockDomain{&q.push, &q.shared}
	if q.turn {
		rings[0], rings[1] = rings[1], rings[0]
	}
	for _, r := range rings {
		if ep, decoy, ok = q.fromRing(r, now); ok {
			return
		}
	}
	return nil, false, false
}

func (q *knockQueue) fromRing(r *[]*knockDomain, now time.Time) (ep *knockEP, decoy, ok bool) {
	for n := len(*r); n > 0; n-- {
		d := (*r)[0]
		*r = (*r)[1:]
		d.inRing = false
		if d.waiting() == 0 {
			continue
		}
		requeue := func() { q.ringAppend(d) }
		if d.inflight >= d.busyCap() || (!d.push && q.sharedBusy >= knockSharedWorkers) {
			requeue()
			continue
		}
		d.rate.takeN(now, 0)
		if d.rate.tokens < 1 {
			requeue()
			continue
		}
		if t := d.nextLane(); t >= 0 {
			ep, d.lanes[t] = d.lanes[t][0], d.lanes[t][1:]
			ep.queuedReal = false
		} else {
			// decoys only while more than half the second's budget is left
			if q.rate.tokens <= q.rate.max/2 {
				requeue()
				continue
			}
			ep, d.decoy = d.decoy[0], d.decoy[1:]
			ep.queuedDecoy, decoy = false, true
		}
		d.rate.take(now)
		q.rate.take(now)
		q.unqueued(d)
		d.inflight++
		if !d.push {
			q.sharedBusy++
		}
		if d.waiting() > 0 {
			requeue()
		}
		return ep, decoy, true
	}
	return nil, false, false
}

// a post is over: its server's in-flight count goes back
func (q *knockQueue) doneLocked(ep *knockEP) {
	d := q.k.domains[ep.domain]
	if d == nil {
		return
	}
	d.inflight--
	if !d.push {
		q.sharedBusy--
	}
	if d.eps <= 0 && d.waiting() == 0 && d.inflight == 0 {
		delete(q.k.domains, ep.domain)
	}
}

// waits for a knock that may go. false once stopped
func (q *knockQueue) take() (ep *knockEP, decoy, ok bool) {
	k := q.k
	k.mu.Lock()
	defer k.mu.Unlock()
	for !q.stopped {
		now := k.now()
		if ep, decoy, ok = q.nextLocked(now); ok {
			return
		}
		if q.queued == 0 {
			q.cond.Wait()
			continue
		}
		// the shared budget empty: until its next token. a server's pace
		// or room: look again shortly
		wait := q.budgetWait(now)
		if wait <= 0 || wait > time.Second {
			wait = 20 * time.Millisecond
		}
		k.mu.Unlock()
		time.Sleep(wait)
		k.mu.Lock()
	}
	return nil, false, false
}

func (q *knockQueue) start(ctx context.Context) {
	go func() {
		<-ctx.Done()
		q.k.mu.Lock()
		q.stopped = true
		q.cond.Broadcast()
		q.k.mu.Unlock()
	}()
	for i := 0; i < knockWorkers; i++ {
		go func() {
			for {
				ep, decoy, ok := q.take()
				if !ok {
					return
				}
				if !q.send(ctx, ep, decoy) {
					// its address was busy: give the others a turn
					time.Sleep(20 * time.Millisecond)
				}
			}
		}()
	}
}

// one post. false when it could not go now and waits again
func (q *knockQueue) send(ctx context.Context, ep *knockEP, decoy bool) bool {
	k := q.k
	release := func() {
		k.mu.Lock()
		q.doneLocked(ep)
		k.mu.Unlock()
	}
	u, err := url.Parse(ep.url)
	if err != nil {
		release()
		k.gone(ep.url)
		return true
	}
	host := strings.ToLower(u.Hostname())
	ipKey := host
	var ips []net.IP
	if !strings.HasSuffix(host, ".onion") {
		rctx, cancel := context.WithTimeout(ctx, knockPostTimeout)
		ips, err = q.resolve(rctx, host)
		cancel()
		if err != nil || len(ips) == 0 {
			release()
			// a name that is not there or has no public address is a
			// definite answer, a resolver that fails is not
			var dnsErr *net.DNSError
			if err == nil || errors.As(err, &dnsErr) && dnsErr.IsNotFound {
				err = errNotPublic
			}
			q.result(ep, decoy, 0, err)
			return true
		}
		ipKey = ips[0].String()
	}
	limit := knockPerIP
	if k.push[ep.domain] {
		limit = knockPerPushHostIP
	}
	k.mu.Lock()
	if q.ipBusy[ipKey] >= limit {
		q.doneLocked(ep)
		q.addLocked(ep, decoy)
		k.mu.Unlock()
		return false
	}
	q.ipBusy[ipKey]++
	k.mu.Unlock()
	pctx := ctx
	if ips != nil {
		pctx = context.WithValue(ctx, knockDialIPs{}, ips)
	}
	code, err := q.post(pctx, ep.url)
	k.mu.Lock()
	if q.ipBusy[ipKey]--; q.ipBusy[ipKey] <= 0 {
		delete(q.ipBusy, ipKey)
	}
	q.doneLocked(ep)
	k.mu.Unlock()
	q.result(ep, decoy, code, err)
	return true
}

func (q *knockQueue) result(ep *knockEP, decoy bool, code int, err error) {
	k := q.k
	switch {
	case err == nil && (code == http.StatusNotFound || code == http.StatusGone):
		// unifiedpush: an endpoint answers 404 once its app let it go
		k.gone(ep.url)
		return
	case err == nil && code == http.StatusTooManyRequests:
		// the server is pacing us, not refusing the endpoint
		k.stats.failed.Add(1)
		return
	case err == nil && code >= 200 && code < 300:
		k.mu.Lock()
		ep.fails, ep.failingSince, ep.lastFail = 0, time.Time{}, time.Time{}
		if !ep.delivered {
			ep.delivered = true
			k.store.proven(ep.url)
		}
		// it worked: no longer one of the share's new ones
		k.settledLocked(ep)
		k.mu.Unlock()
		if decoy {
			k.stats.decoys.Add(1)
		} else {
			k.stats.real.Add(1)
		}
		return
	}
	k.stats.failed.Add(1)
	now := k.now()
	k.mu.Lock()
	// an endpoint that never worked and is refused for good is let go at
	// once: it would only hold a new one's room. a busy or failing server
	// is not a refusal
	if !ep.delivered && (err == nil && knockRefused(code) || errors.Is(err, errNotPublic)) {
		k.mu.Unlock()
		k.gone(ep.url)
		return
	}
	// one that never worked counts one failure per gap: a burst of knocks
	// into a short outage is one
	if ep.delivered || ep.lastFail.IsZero() || now.Sub(ep.lastFail) >= knockNewFailGap {
		ep.fails++
		ep.lastFail = now
	}
	if ep.failingSince.IsZero() {
		ep.failingSince = now
	}
	failing := now.Sub(ep.failingSince)
	drop := ep.fails >= knockFailAtLeast && failing >= knockFailFor
	// one that never worked goes sooner
	drop = drop || !ep.delivered && ep.fails >= knockNewFailAtLeast && failing >= knockNewFailSpan && failing <= knockNewFailFor
	if !drop {
		k.recheckLocked(ep)
	}
	k.mu.Unlock()
	if drop {
		k.gone(ep.url)
	}
}

// answers that refuse the endpoint itself, not the moment
func knockRefused(code int) bool {
	switch code {
	case http.StatusBadRequest, http.StatusUnauthorized, http.StatusForbidden, http.StatusNotFound,
		http.StatusMethodNotAllowed, http.StatusGone, http.StatusRequestEntityTooLarge:
		return true
	}
	return false
}

// ---- where a post may go ----

var errNotPublic = errors.New("not a public address")

func publicIP(ip net.IP) bool {
	if ip == nil || ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() ||
		ip.IsLinkLocalMulticast() || ip.IsInterfaceLocalMulticast() ||
		ip.IsMulticast() || ip.IsUnspecified() {
		return false
	}
	if v4 := ip.To4(); v4 != nil {
		switch {
		// this network, shared address space, ietf, the documentation
		// ranges, benchmarking, the old 6to4 relays, reserved
		case v4[0] == 0, v4[0] == 100 && v4[1]&0xc0 == 64,
			v4[0] == 192 && v4[1] == 0 && (v4[2] == 0 || v4[2] == 2),
			v4[0] == 198 && v4[1] == 51 && v4[2] == 100,
			v4[0] == 203 && v4[1] == 0 && v4[2] == 113,
			v4[0] == 198 && v4[1]&0xfe == 18,
			v4[0] == 192 && v4[1] == 88 && v4[2] == 99,
			v4[0] >= 240:
			return false
		}
		return true
	}
	ip = ip.To16()
	switch {
	// v4-compatible (::/96), and anything else with a v4 tucked inside:
	// nat64 (64:ff9b::/32 covers the local-use /48), 6to4, teredo
	case allZero(ip[:12]),
		ip[0] == 0x00 && ip[1] == 0x64 && ip[2] == 0xff && ip[3] == 0x9b,
		ip[0] == 0x20 && ip[1] == 0x02,
		ip[0] == 0x20 && ip[1] == 0x01 && ip[2] == 0 && ip[3] == 0,
		// documentation (2001:db8::/32, 3fff::/20), benchmarking
		// (2001:2::/48), segment routing (5f00::/16), discard-only,
		// site-local
		ip[0] == 0x20 && ip[1] == 0x01 && ip[2] == 0x0d && ip[3] == 0xb8,
		ip[0] == 0x3f && ip[1] == 0xff && ip[2]&0xf0 == 0,
		ip[0] == 0x20 && ip[1] == 0x01 && ip[2] == 0 && ip[3] == 0x02 && ip[4] == 0 && ip[5] == 0,
		ip[0] == 0x5f && ip[1] == 0x00,
		ip[0] == 0x01 && allZero(ip[1:8]),
		ip[0] == 0xfe && ip[1]&0xc0 == 0xc0:
		return false
	}
	return true
}

func allZero(b []byte) bool {
	for _, x := range b {
		if x != 0 {
			return false
		}
	}
	return true
}

// the box's own addresses: a name may point at them from outside too
var (
	selfMu  sync.RWMutex
	selfIPs = map[string]bool{}
)

func noteSelfIPs() {
	selfMu.Lock()
	defer selfMu.Unlock()
	if addrs, err := net.InterfaceAddrs(); err == nil {
		for _, a := range addrs {
			if n, ok := a.(*net.IPNet); ok {
				selfIPs[n.IP.String()] = true
			}
		}
	}
	for _, s := range strings.Split(os.Getenv("RELAY_KNOCK_SELF"), ",") {
		if ip := net.ParseIP(strings.TrimSpace(s)); ip != nil {
			selfIPs[ip.String()] = true
		}
	}
}

func selfIP(ip net.IP) bool {
	selfMu.RLock()
	defer selfMu.RUnlock()
	return selfIPs[ip.String()]
}

// refuses every address that is not public, or is this box, after the
// name is resolved, so a name cannot point the relay at itself
func publicOnly(network, address string, _ syscall.RawConn) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return err
	}
	ip := net.ParseIP(host)
	if ip == nil || !publicIP(ip) || selfIP(ip) {
		return errNotPublic
	}
	return nil
}

// the addresses a host may be posted to, public ones only
func knockResolver(netw string) func(ctx context.Context, host string) ([]net.IP, error) {
	return knockResolverOn(net.DefaultResolver, netw)
}

// over ipv4 only A records are asked for: an A lookup that fails is a
// failed lookup, not a name without a public address
func knockResolverOn(r *net.Resolver, netw string) func(ctx context.Context, host string) ([]net.IP, error) {
	family := "ip"
	if netw == "tcp4" {
		family = "ip4"
	}
	return func(ctx context.Context, host string) ([]net.IP, error) {
		all := []net.IP{net.ParseIP(host)}
		if all[0] == nil {
			var err error
			if all, err = r.LookupIP(ctx, family, host); err != nil {
				return nil, err
			}
		}
		var out []net.IP
		for _, ip := range all {
			if netw == "tcp4" && ip.To4() == nil {
				continue
			}
			if publicIP(ip) && !selfIP(ip) {
				out = append(out, ip)
			}
		}
		if len(out) == 0 {
			return nil, errNotPublic
		}
		return out, nil
	}
}

// the address the queue resolved for a post, so the dial takes that one
type knockDialIPs struct{}

// the client for knocks: no proxy from the environment, no redirects, no
// cookies, short timeouts, small answers. dial is where it may connect
func knockClientWith(dial func(ctx context.Context, network, addr string) (net.Conn, error)) *http.Client {
	return &http.Client{
		Transport: &http.Transport{
			Proxy:                  nil,
			DialContext:            dial,
			TLSHandshakeTimeout:    knockPostTimeout,
			ResponseHeaderTimeout:  knockPostTimeout,
			MaxResponseHeaderBytes: 16 << 10,
			MaxIdleConns:           256,
			MaxIdleConnsPerHost:    8,
			IdleConnTimeout:        60 * time.Second,
			ForceAttemptHTTP2:      true,
		},
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
}

// ipv4 unless told otherwise: some push servers limit a whole v6 /64 at
// once. onions through the box's tor when one is given
func knockClient(netw, socks string) *http.Client {
	d := &net.Dialer{Timeout: knockPostTimeout, Control: publicOnly}
	var onion proxy.ContextDialer
	if socks != "" {
		if sd, err := proxy.SOCKS5("tcp", socks, nil, &net.Dialer{Timeout: knockPostTimeout}); err == nil {
			onion, _ = sd.(proxy.ContextDialer)
		}
	}
	return knockClientWith(func(ctx context.Context, _, addr string) (net.Conn, error) {
		host, port, err := net.SplitHostPort(addr)
		if err != nil {
			return nil, err
		}
		if strings.HasSuffix(strings.ToLower(host), ".onion") {
			if onion == nil {
				return nil, errNotPublic
			}
			return onion.DialContext(ctx, "tcp", addr)
		}
		if ips, ok := ctx.Value(knockDialIPs{}).([]net.IP); ok && len(ips) > 0 {
			addr = net.JoinHostPort(ips[0].String(), port)
		}
		return d.DialContext(ctx, netw, addr)
	})
}

// the knock: an empty post, the same for real and decoy
func knockPoster(c *http.Client) func(ctx context.Context, endpoint string) (int, error) {
	return func(ctx context.Context, endpoint string) (int, error) {
		wait := knockPostTimeout
		if u, err := url.Parse(endpoint); err == nil && strings.HasSuffix(strings.ToLower(u.Hostname()), ".onion") {
			wait = knockOnionTimeout
		}
		ctx, cancel := context.WithTimeout(ctx, wait)
		defer cancel()
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(nil))
		if err != nil {
			return 0, err
		}
		req.Header.Set("TTL", knockPushTTL)
		req.Header.Set("Urgency", "high")
		req.Header.Set("User-Agent", "")
		resp, err := c.Do(req)
		if err != nil {
			return 0, err
		}
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		resp.Body.Close()
		return resp.StatusCode, nil
	}
}
