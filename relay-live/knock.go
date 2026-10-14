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
// every endpoint also gets decoy knocks at random, so its timing says less
// about when anything arrived. real and decoy knocks are the same request
// and keep the same floor.

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"errors"
	"io"
	"log"
	"math/rand/v2"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
	"golang.org/x/net/proxy"
)

const (
	knockKind = 21059
	// what the relay info lists, for the app to see this relay can knock
	knockTag = "knock/1"
	// a registration lives this long after it was signed. the app renews
	// its registrations every few days
	knockTTL = 30 * 24 * time.Hour
	// how far a registration's time may be from this box's: as far as a
	// wrap's, so a phone whose clock is off still registers
	knockSkew = futureSlack
	// real knocks to one endpoint, at most one a minute. wraps in between
	// get one more knock when the minute is up
	knockFloor     = time.Minute
	maxEndpointLen = 512
	// registrations, endpoints and addresses per endpoint, for everyone
	// together. the phone uses sixteen endpoints whatever its contacts
	maxKnockRegs     = 200000
	maxKnockEPs      = 50000
	maxRegsPerEP     = 256
	knockPostTimeout = 10 * time.Second
	knockWorkers     = 8
	knockQueueLen    = 4096
	// how long a push server keeps a knock for a phone that is offline
	knockPushTTL = "3600"
	knockTick    = 30 * time.Second
)

// the mean gap between decoys to one endpoint. a phone has sixteen
// endpoints, so at four hours it gets one every fifteen minutes, as many
// check-ins as its own timer adds
var knockDecoyMean = time.Duration(envInt("RELAY_KNOCK_DECOY_MIN", 240)) * time.Minute

// knocks sent per second for everyone together, decoys within half of it
var knockPerSec = envInt("RELAY_KNOCK_PER_SEC", 20)

type knockEP struct {
	url string
	// addresses registered to it
	regs int
	// the last knock out, real or decoy, and whether one waits for the floor
	last      time.Time
	trailing  bool
	nextDecoy time.Time
}

type knockReg struct {
	ep      *knockEP
	made    int64
	expires int64
}

type knockStats struct{ real, decoys, failed, dropped, gone atomic.Int64 }

type knocker struct {
	mu   sync.Mutex
	regs map[[32]byte]*knockReg
	eps  map[string]*knockEP
	db   *sql.DB
	now  func() time.Time
	rnd  *rand.Rand
	// endpoints to post to; decoy says which kind, for the counts only
	out    chan knockJob
	rate   *bucket
	post   func(ctx context.Context, endpoint string) (int, error)
	onions bool
	stats  knockStats
	// the floor and the timer behind the trailing knock, for the tests
	floor time.Duration
	after func(time.Duration, func())
}

type knockJob struct {
	url   string
	decoy bool
}

// sha256 of the address: the table lists no address, a wrap's p tag finds
// its registration by the same hash
func knockKey(addr string) [32]byte { return sha256.Sum256([]byte(strings.ToLower(addr))) }

func newKnocker(db *sql.DB, onions bool) *knocker {
	return &knocker{
		regs:   map[[32]byte]*knockReg{},
		eps:    map[string]*knockEP{},
		db:     db,
		now:    time.Now,
		rnd:    rand.New(rand.NewPCG(rand.Uint64(), rand.Uint64())),
		out:    make(chan knockJob, knockQueueLen),
		rate:   newBucket(float64(knockPerSec), float64(knockPerSec)*10),
		onions: onions,
		floor:  knockFloor,
		after:  func(d time.Duration, f func()) { time.AfterFunc(d, f) },
	}
}

// an endpoint is a url this relay will post to, named by whoever signs for
// an address. https on a public address, or an onion when the box's tor is
// there to reach it. no user, no fragment, nothing longer than a push
// server hands out
func knockEndpointOK(raw string, onions bool) bool {
	if len(raw) > maxEndpointLen || strings.ContainsAny(raw, " \t\r\n") {
		return false
	}
	u, err := url.Parse(raw)
	if err != nil || u.User != nil || u.Fragment != "" || u.Opaque != "" {
		return false
	}
	host := strings.ToLower(u.Hostname())
	if host == "" {
		return false
	}
	if strings.HasSuffix(host, ".onion") {
		return onions && (u.Scheme == "https" || u.Scheme == "http")
	}
	if u.Scheme != "https" || host == "localhost" || strings.HasSuffix(host, ".localhost") {
		return false
	}
	if ip := net.ParseIP(host); ip != nil && !publicIP(ip) {
		return false
	}
	return true
}

func publicIP(ip net.IP) bool {
	if ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() ||
		ip.IsLinkLocalMulticast() || ip.IsInterfaceLocalMulticast() ||
		ip.IsMulticast() || ip.IsUnspecified() {
		return false
	}
	if v4 := ip.To4(); v4 != nil {
		// this network, shared address space, ietf, benchmarking, reserved
		switch {
		case v4[0] == 0, v4[0] == 100 && v4[1]&0xc0 == 64,
			v4[0] == 192 && v4[1] == 0 && v4[2] == 0,
			v4[0] == 198 && v4[1]&0xfe == 18, v4[0] >= 240:
			return false
		}
		return true
	}
	// nat64 and 6to4 can carry a private v4 inside
	if ip[0] == 0x00 && ip[1] == 0x64 && ip[2] == 0xff && ip[3] == 0x9b {
		return false
	}
	if ip[0] == 0x20 && ip[1] == 0x02 {
		return false
	}
	return true
}

// the reject hook's half: whether this registration may be taken. it is
// taken in apply, after khatru has run every reject hook
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
	if ev.Content == "" {
		return false, ""
	}
	if !knockEndpointOK(ev.Content, k.onions) {
		return true, "invalid: this endpoint cannot be knocked"
	}
	k.mu.Lock()
	defer k.mu.Unlock()
	reg := k.regs[knockKey(ev.PubKey)]
	ep := k.eps[ev.Content]
	if reg == nil && len(k.regs) >= maxKnockRegs {
		return true, "error: the relay is full, try later"
	}
	if ep == nil && len(k.eps) >= maxKnockEPs {
		return true, "error: the relay is full, try later"
	}
	if ep != nil && ep.regs >= maxRegsPerEP && (reg == nil || reg.ep != ep) {
		return true, "error: too many addresses on one endpoint"
	}
	return false, ""
}

// takes a registration that passed check. an older one than what is kept
// changes nothing, so a replay cannot undo a newer change
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
	if old := k.regs[key]; old != nil && old.made >= made {
		return
	}
	if ev.Content == "" {
		k.dropLocked(key)
		k.save(key, nil)
		return
	}
	k.setLocked(key, ev.Content, made, time.Unix(made, 0).Add(knockTTL).Unix())
	k.save(key, k.regs[key])
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
		ep = &knockEP{url: endpoint, nextDecoy: k.now().Add(k.decoyGap())}
		k.eps[endpoint] = ep
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
	if reg.ep.regs <= 0 && k.eps[reg.ep.url] == reg.ep {
		delete(k.eps, reg.ep.url)
	}
}

// exponential, so the gaps keep no rhythm of their own
func (k *knocker) decoyGap() time.Duration {
	return time.Duration(k.rnd.ExpFloat64() * float64(knockDecoyMean))
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

// one knock now if the floor allows, or one when it is up
func (k *knocker) ringLocked(ep *knockEP, decoy bool) {
	now := k.now()
	if wait := ep.last.Add(k.floor).Sub(now); wait > 0 {
		// a decoy inside the floor is not needed: a knock just went
		if decoy || ep.trailing {
			return
		}
		ep.trailing = true
		k.after(wait, func() { k.trail(ep) })
		return
	}
	ep.last = now
	k.queue(knockJob{ep.url, decoy})
}

func (k *knocker) trail(ep *knockEP) {
	k.mu.Lock()
	defer k.mu.Unlock()
	ep.trailing = false
	if k.eps[ep.url] != ep {
		return
	}
	ep.last = k.now()
	k.queue(knockJob{ep.url, false})
}

// decoys wait while the queue is half full: real knocks come first
func (k *knocker) queue(j knockJob) {
	if j.decoy && len(k.out) >= cap(k.out)/2 {
		k.stats.dropped.Add(1)
		return
	}
	select {
	case k.out <- j:
	default:
		k.stats.dropped.Add(1)
	}
}

// one pass of the timer: expired registrations go, decoys that are due go
// out
func (k *knocker) tick() {
	now := k.now()
	k.mu.Lock()
	defer k.mu.Unlock()
	var gone [][32]byte
	for key, reg := range k.regs {
		if reg.expires <= now.Unix() {
			gone = append(gone, key)
		}
	}
	for _, key := range gone {
		k.dropLocked(key)
		k.save(key, nil)
	}
	for _, ep := range k.eps {
		if now.Before(ep.nextDecoy) {
			continue
		}
		ep.nextDecoy = now.Add(k.decoyGap())
		k.ringLocked(ep, true)
	}
}

// the endpoint is gone for good: its push server said so
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
		k.save(key, nil)
	}
	k.stats.gone.Add(1)
}

func (k *knocker) send(ctx context.Context, j knockJob) {
	for !k.takeRate(j.decoy) {
		if j.decoy {
			k.stats.dropped.Add(1)
			return
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(time.Second / time.Duration(max(knockPerSec, 1))):
		}
	}
	code, err := k.post(ctx, j.url)
	switch {
	case err != nil || code >= 500 || code == http.StatusTooManyRequests:
		k.stats.failed.Add(1)
	case code == http.StatusNotFound || code == http.StatusGone:
		// unifiedpush: an endpoint answers 404 once its app let it go
		k.gone(j.url)
	case code >= 400:
		k.stats.failed.Add(1)
	case j.decoy:
		k.stats.decoys.Add(1)
	default:
		k.stats.real.Add(1)
	}
}

// decoys only while more than half of the second's budget is left
func (k *knocker) takeRate(decoy bool) bool {
	k.mu.Lock()
	defer k.mu.Unlock()
	now := k.now()
	if decoy {
		k.rate.takeN(now, 0)
		if k.rate.tokens <= k.rate.max/2 {
			return false
		}
	}
	return k.rate.take(now)
}

func (k *knocker) run(ctx context.Context) {
	for i := 0; i < knockWorkers; i++ {
		go func() {
			for {
				select {
				case <-ctx.Done():
					return
				case j := <-k.out:
					k.send(ctx, j)
				}
			}
		}()
	}
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
	regs, eps := len(k.regs), len(k.eps)
	k.mu.Unlock()
	s := &k.stats
	log.Printf("knock: %d registrations, %d endpoints, last hour %d knocks, %d decoys, %d failed, %d dropped, %d gone",
		regs, eps, s.real.Swap(0), s.decoys.Swap(0), s.failed.Swap(0), s.dropped.Swap(0), s.gone.Swap(0))
}

// ---- the post ----

var errNotPublic = errors.New("not a public address")

// refuses every address that is not public, after the name is resolved,
// so a name cannot point the relay at its own box
func publicOnly(network, address string, _ syscall.RawConn) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return err
	}
	ip := net.ParseIP(host)
	if ip == nil || !publicIP(ip) {
		return errNotPublic
	}
	return nil
}

// the client for knocks: no proxy from the environment, no redirects, no
// cookies, short timeouts. ipv4 unless told otherwise: some push servers
// limit a whole v6 /64 at once. onions through the box's tor when one is
// given
func knockClient(netw, socks string) *http.Client {
	d := &net.Dialer{Timeout: 5 * time.Second, Control: publicOnly}
	tr := &http.Transport{
		Proxy: nil,
		DialContext: func(ctx context.Context, _, addr string) (net.Conn, error) {
			return d.DialContext(ctx, netw, addr)
		},
		TLSHandshakeTimeout:   5 * time.Second,
		ResponseHeaderTimeout: knockPostTimeout,
		MaxIdleConnsPerHost:   8,
		IdleConnTimeout:       90 * time.Second,
		ForceAttemptHTTP2:     true,
	}
	if socks != "" {
		if sd, err := proxy.SOCKS5("tcp", socks, nil, &net.Dialer{Timeout: 5 * time.Second}); err == nil {
			if cd, ok := sd.(proxy.ContextDialer); ok {
				open := tr.DialContext
				tr.DialContext = func(ctx context.Context, n, addr string) (net.Conn, error) {
					host, _, _ := net.SplitHostPort(addr)
					if strings.HasSuffix(strings.ToLower(host), ".onion") {
						return cd.DialContext(ctx, "tcp", addr)
					}
					return open(ctx, n, addr)
				}
			}
		}
	}
	return &http.Client{
		Transport:     tr,
		Timeout:       knockPostTimeout,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
}

// the knock: an empty post, the same for real and decoy
func knockPoster(c *http.Client) func(ctx context.Context, endpoint string) (int, error) {
	return func(ctx context.Context, endpoint string) (int, error) {
		ctx, cancel := context.WithTimeout(ctx, knockPostTimeout)
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

// ---- the table ----

func openKnockStore(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite3", path+"?_journal_mode=WAL&_sync=NORMAL&_busy_timeout=5000")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS knock (
		addr BLOB PRIMARY KEY, endpoint TEXT NOT NULL,
		made INTEGER NOT NULL, expires INTEGER NOT NULL)`); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

// what was registered before a restart, the expired left out and deleted
func (k *knocker) load() error {
	if k.db == nil {
		return nil
	}
	now := k.now().Unix()
	if _, err := k.db.Exec(`DELETE FROM knock WHERE expires <= ?`, now); err != nil {
		return err
	}
	rows, err := k.db.Query(`SELECT addr, endpoint, made, expires FROM knock`)
	if err != nil {
		return err
	}
	defer rows.Close()
	k.mu.Lock()
	defer k.mu.Unlock()
	for rows.Next() {
		var a []byte
		var ep string
		var made, exp int64
		if err := rows.Scan(&a, &ep, &made, &exp); err != nil {
			return err
		}
		if len(a) != 32 || !knockEndpointOK(ep, k.onions) {
			continue
		}
		var key [32]byte
		copy(key[:], a)
		k.setLocked(key, ep, made, exp)
	}
	return rows.Err()
}

// called under mu. a write that fails is logged without its row: the
// registration still works until a restart
func (k *knocker) save(key [32]byte, reg *knockReg) {
	if k.db == nil {
		return
	}
	var err error
	if reg == nil {
		_, err = k.db.Exec(`DELETE FROM knock WHERE addr = ?`, key[:])
	} else {
		_, err = k.db.Exec(`INSERT INTO knock (addr, endpoint, made, expires) VALUES (?, ?, ?, ?)
			ON CONFLICT(addr) DO UPDATE SET endpoint = excluded.endpoint, made = excluded.made, expires = excluded.expires`,
			key[:], reg.ep.url, reg.made, reg.expires)
	}
	if err != nil {
		log.Printf("knock: table write: %v", err)
	}
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
	db, err := openKnockStore(dataDir + "/knock.sqlite")
	if err != nil {
		return nil, err
	}
	socks := os.Getenv("RELAY_KNOCK_SOCKS")
	netw := "tcp4"
	if os.Getenv("RELAY_KNOCK_NET") == "tcp" {
		netw = "tcp"
	}
	k := newKnocker(db, socks != "")
	k.post = knockPoster(knockClient(netw, socks))
	if err := k.load(); err != nil {
		db.Close()
		return nil, err
	}
	applyKnocks(relay, l, k)
	go k.run(context.Background())
	return k, nil
}
