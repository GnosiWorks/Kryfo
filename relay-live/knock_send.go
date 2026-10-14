package main

// the posts. knocks wait per push server and the servers are served in
// turn, so a server that is slow or flooded holds up its own knocks only.
// each server has its own pace, and at most a couple of posts are in flight
// to one address at a time. a post gets three seconds. an endpoint that
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
	// knocks waiting, for everyone and per server
	knockQueueLen      = 8192
	knockDomainQueue   = 64
	knockPushHostQueue = 2048
	// posts in flight to one address
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
	name        string
	push        bool
	eps         int
	real, decoy []*knockEP
	inRing      bool
	rate        *bucket
}

func (d *knockDomain) waiting() int { return len(d.real) + len(d.decoy) }

func (d *knockDomain) queueCap() int {
	if d.push {
		return knockPushHostQueue
	}
	return knockDomainQueue
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
	// servers with knocks waiting, served in turn
	ring    []*knockDomain
	queued  int
	cond    *sync.Cond
	rate    *bucket
	ipBusy  map[string]int
	stopped bool
	post    func(ctx context.Context, endpoint string) (int, error)
	resolve func(ctx context.Context, host string) ([]net.IP, error)
}

func (q *knockQueue) init(k *knocker) {
	q.k = k
	q.cond = sync.NewCond(&k.mu)
	q.rate = newBucket(float64(knockPerSec), float64(knockPerSec)*10)
	q.ipBusy = map[string]int{}
	q.resolve = knockResolver("tcp4")
}

// a knock to wait its turn. one of each kind per endpoint at most; decoys
// only while the queues are less than half full
func (q *knockQueue) addLocked(ep *knockEP, decoy bool) {
	k := q.k
	if k.eps[ep.url] != ep {
		return
	}
	d := k.domainLocked(ep.domain)
	if decoy {
		if ep.queuedDecoy || ep.queuedReal {
			return
		}
		if q.queued >= knockQueueLen/2 || d.waiting() >= d.queueCap()/2 {
			k.stats.dropped.Add(1)
			return
		}
		ep.queuedDecoy = true
		d.decoy = append(d.decoy, ep)
	} else {
		if ep.queuedReal {
			return
		}
		if q.queued >= knockQueueLen || d.waiting() >= d.queueCap() {
			k.stats.dropped.Add(1)
			return
		}
		ep.queuedReal = true
		d.real = append(d.real, ep)
	}
	q.queued++
	if !d.inRing {
		d.inRing = true
		q.ring = append(q.ring, d)
	}
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

// an endpoint let go leaves the queue
func (q *knockQueue) forgetLocked(d *knockDomain, ep *knockEP) {
	var gone bool
	if d.real, gone = without(d.real, ep); gone {
		q.queued--
	}
	if d.decoy, gone = without(d.decoy, ep); gone {
		q.queued--
	}
	ep.queuedReal, ep.queuedDecoy = false, false
}

// the next knock: the next server in turn with a knock and pace to spare,
// a real knock before a decoy. ok false when none may go now
func (q *knockQueue) nextLocked(now time.Time) (ep *knockEP, decoy, ok bool) {
	for n := len(q.ring); n > 0; n-- {
		d := q.ring[0]
		q.ring = q.ring[1:]
		d.inRing = false
		if d.waiting() == 0 {
			continue
		}
		requeue := func() {
			d.inRing = true
			q.ring = append(q.ring, d)
		}
		if len(d.real) > 0 {
			if !d.rate.take(now) || !q.rate.take(now) {
				requeue()
				continue
			}
			ep, d.real = d.real[0], d.real[1:]
			ep.queuedReal = false
		} else {
			// decoys only while more than half the second's budget is left
			q.rate.takeN(now, 0)
			if q.rate.tokens <= q.rate.max/2 || !d.rate.take(now) || !q.rate.take(now) {
				requeue()
				continue
			}
			ep, d.decoy = d.decoy[0], d.decoy[1:]
			ep.queuedDecoy, decoy = false, true
		}
		q.queued--
		if d.waiting() > 0 {
			requeue()
		}
		return ep, decoy, true
	}
	return nil, false, false
}

// waits for a knock that may go. false once stopped
func (q *knockQueue) take() (ep *knockEP, decoy, ok bool) {
	k := q.k
	k.mu.Lock()
	defer k.mu.Unlock()
	for !q.stopped {
		if ep, decoy, ok = q.nextLocked(k.now()); ok {
			return
		}
		if q.queued == 0 {
			q.cond.Wait()
			continue
		}
		// knocks wait on their pace: look again shortly
		k.mu.Unlock()
		time.Sleep(20 * time.Millisecond)
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
	u, err := url.Parse(ep.url)
	if err != nil {
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
			q.result(ep, decoy, 0, errNotPublic)
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
	case err == nil && code < 400:
		k.mu.Lock()
		ep.fails, ep.failingSince = 0, time.Time{}
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
	ep.fails++
	if ep.failingSince.IsZero() {
		ep.failingSince = now
	}
	drop := ep.fails >= knockFailAtLeast && now.Sub(ep.failingSince) >= knockFailFor
	k.mu.Unlock()
	if drop {
		k.gone(ep.url)
	}
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
		// documentation, discard-only, site-local
		ip[0] == 0x20 && ip[1] == 0x01 && ip[2] == 0x0d && ip[3] == 0xb8,
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
	return func(ctx context.Context, host string) ([]net.IP, error) {
		var all []net.IP
		if ip := net.ParseIP(host); ip != nil {
			all = []net.IP{ip}
		} else {
			addrs, err := net.DefaultResolver.LookupIPAddr(ctx, host)
			if err != nil {
				return nil, err
			}
			for _, a := range addrs {
				all = append(all, a.IP)
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
