// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the push gateway, for google push in the play build. a relay posts an
// empty knock to https://relay.kryfo.app/push/<sealed token>, and the
// gateway asks fcm to wake that phone with an empty high-priority message.
// the phone then checks in over tor, as a helper app's knock makes it do.
//
// the sealed token is a phone's fcm token sealed to this gateway's key
// (seal.go), sealed afresh for each of its sixteen endpoints, so a relay
// holds sixteen strings with nothing in common. the gateway opens one in
// memory and keeps nothing: no table, no file, no log line per token. in
// ram, gone with a restart, is a keyed hash of a token with the times of
// its last pushes, kept an hour (the floor below), a keyed hash of a token
// fcm said is no phone's, kept a day, and for a knock folded into the next
// push the token itself, up to 45 s.
//
//	kryfo-push                 serve
//	kryfo-push keygen <file>   make the key, print the public key for the app
//	kryfo-push pubkey <file>   print the public key of a key made before

import (
	"context"
	"crypto/hmac"
	"crypto/hpke"
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	// as the phone's own gate (KnockGate.kt): one push a phone every 45 s,
	// thirty an hour. a knock inside the floor is folded into one that
	// goes when the floor is up
	floorGap  = 45 * time.Second
	floorHour = 30
	// a full table of phones with their seal hashes must fit the unit's
	// MemoryMax=256M with room: about 110 MB at this size
	floorKept = 80_000
	goneFor   = 24 * time.Hour
	// gone tokens have a table of their own, the oldest let go first, so
	// junk sealed by anyone can never crowd out a phone
	goneKept = 20_000
	// a full table is swept at most this often, never on every knock
	sweepEvery = 10 * time.Second
	// a phone seals its one token once per slot, sixteen, and anew when a
	// slot is renewed. more seals of one token than this, each seen within
	// a day, are someone filling the relay with copies: answered as no
	// endpoint, so the relay lets them go
	sealsPerToken = 32
	sealSeenFor   = 24 * time.Hour
	maxBody       = 4 << 10
	maxInFlight   = 128
	// the relay gives a post three seconds: answer within that, and let a
	// slow fcm finish on its own
	answerBy = 2500 * time.Millisecond
	pushBy   = 10 * time.Second
)

// pushes for everyone together, so a flood cannot spend the project's quota
var everyone = newLimiter(100, 500)

func main() {
	if len(os.Args) == 3 && os.Args[1] == "keygen" {
		pub, err := keygen(os.Args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, "keygen:", err)
			os.Exit(1)
		}
		fmt.Println(pub)
		return
	}
	if len(os.Args) == 3 && os.Args[1] == "pubkey" {
		k, err := readKey(os.Args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, "pubkey:", err)
			os.Exit(1)
		}
		fmt.Println(pubString(k))
		return
	}
	if len(os.Args) != 1 {
		fmt.Fprintln(os.Stderr, "usage: kryfo-push [keygen <file> | pubkey <file>]")
		os.Exit(2)
	}
	addr := env("PUSH_ADDR", "127.0.0.1:3340")
	k, err := readKey(credential("PUSH_KEY_FILE", "box.key"))
	if err != nil {
		log.Fatal("push: ", err)
	}
	f, err := loadFCM(credential("PUSH_FCM_FILE", "fcm.json"))
	if err != nil {
		log.Fatal("push: ", err)
	}
	g := newGateway(k, f)
	go g.hourly()
	log.Printf("push: listening on %s", addr)
	log.Fatal(newServer(addr, g).ListenAndServe())
}

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

// a path from the environment, else systemd's credentials directory
// (LoadCredential), else /etc/kryfo-push
func credential(envName, file string) string {
	if v := os.Getenv(envName); v != "" {
		return v
	}
	if d := os.Getenv("CREDENTIALS_DIRECTORY"); d != "" {
		return filepath.Join(d, file)
	}
	return filepath.Join("/etc/kryfo-push", file)
}

type stats struct {
	sent, folded, gone, refused, failed, limited atomic.Int64
}

type gateway struct {
	key  hpke.PrivateKey
	fcm  pusher
	slot chan struct{}
	// the floor's hashes are keyed with this, made new each start
	salt []byte
	now  func() time.Time
	// runs f after d: a timer, or at once in the tests
	after func(d time.Duration, f func())

	mu    sync.Mutex
	floor map[[16]byte]*phone
	// gone tokens, and their order: each is kept goneFor, so the oldest
	// added is the first to end
	gone      map[[16]byte]time.Time
	goneOrder [][16]byte
	swept     time.Time
	st        stats
}

// what is held for one token, under its keyed hash
type phone struct {
	last      time.Time
	hourStart time.Time
	inHour    int
	trailing  bool
	// made by a push whose answer is not in yet: a failed first push
	// leaves no row
	fresh bool
	// keyed hashes of this token's seals, and when each was last knocked
	seals map[[8]byte]time.Time
}

// whether a seal of this token may knock: one already seen, or a new one
// while the token has room
func (p *phone) sealOK(s [8]byte, now time.Time) bool {
	if _, ok := p.seals[s]; ok {
		p.seals[s] = now
		return true
	}
	if len(p.seals) >= sealsPerToken {
		for k, at := range p.seals {
			if now.Sub(at) >= sealSeenFor {
				delete(p.seals, k)
			}
		}
		if len(p.seals) >= sealsPerToken {
			return false
		}
	}
	if p.seals == nil {
		p.seals = map[[8]byte]time.Time{}
	}
	p.seals[s] = now
	return true
}

func newGateway(k hpke.PrivateKey, f pusher) *gateway {
	salt := make([]byte, 32)
	rand.Read(salt)
	return &gateway{
		key:   k,
		fcm:   f,
		slot:  make(chan struct{}, maxInFlight),
		salt:  salt,
		now:   time.Now,
		after: func(d time.Duration, f func()) { time.AfterFunc(d, f) },
		floor: map[[16]byte]*phone{},
		gone:  map[[16]byte]time.Time{},
	}
}

func (g *gateway) hash(token string) [16]byte {
	m := hmac.New(sha256.New, g.salt)
	m.Write([]byte(token))
	var out [16]byte
	copy(out[:], m.Sum(nil))
	return out
}

func newServer(addr string, g *gateway) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           g,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    8 << 10,
		// no ErrorLog: a request that fails leaves no line
		ErrorLog: log.New(io.Discard, "", 0),
	}
}

// the answers, unifiedpush's: 201 sent, 202 taken for later, 404 and 410
// let the relay drop the endpoint, 429 paces it
func (g *gateway) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	sealed, ok := strings.CutPrefix(r.URL.Path, "/push/")
	if !ok || r.URL.RawQuery != "" || strings.Contains(sealed, "/") {
		g.st.refused.Add(1)
		http.Error(w, "not here", http.StatusNotFound)
		return
	}
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", "POST")
		http.Error(w, "post only", http.StatusMethodNotAllowed)
		return
	}
	// a knock has no body; a few bytes are let through and dropped unread
	if r.ContentLength > maxBody {
		g.st.refused.Add(1)
		http.Error(w, "too big", http.StatusRequestEntityTooLarge)
		return
	}
	if n, _ := io.Copy(io.Discard, io.LimitReader(r.Body, maxBody+1)); n > maxBody {
		g.st.refused.Add(1)
		http.Error(w, "too big", http.StatusRequestEntityTooLarge)
		return
	}
	token, err := open(g.key, sealed)
	if err != nil {
		g.st.refused.Add(1)
		http.Error(w, "no such endpoint", http.StatusNotFound)
		return
	}
	code, wait := g.knock(token, sealed)
	if wait > 0 {
		w.Header().Set("Retry-After", strconv.Itoa(int((wait+time.Second-1)/time.Second)))
	}
	w.WriteHeader(code)
}

// one knock for a token: now, folded into the one after the floor, or
// refused for the hour. a row in the table is made only for a push that is
// let through: a refused knock holds nothing and counts toward nothing
func (g *gateway) knock(token, sealed string) (int, time.Duration) {
	h := g.hash(token)
	var sh [8]byte
	full := g.hash(sealed)
	copy(sh[:], full[:8])
	now := g.now()
	g.mu.Lock()
	if until, ok := g.gone[h]; ok {
		if now.Before(until) {
			g.mu.Unlock()
			g.st.gone.Add(1)
			return http.StatusGone, 0
		}
		delete(g.gone, h)
	}
	p := g.floor[h]
	if p != nil {
		if !p.sealOK(sh, now) {
			g.mu.Unlock()
			g.st.refused.Add(1)
			return http.StatusNotFound, 0
		}
		if now.Sub(p.hourStart) >= time.Hour || now.Before(p.hourStart) {
			p.hourStart, p.inHour = now, 0
		}
		if p.trailing {
			// one is already waiting for the floor: this one goes with it
			g.mu.Unlock()
			g.st.folded.Add(1)
			return http.StatusCreated, 0
		}
		if p.inHour >= floorHour {
			wait := p.hourStart.Add(time.Hour).Sub(now)
			g.mu.Unlock()
			g.st.limited.Add(1)
			return http.StatusTooManyRequests, wait
		}
		if !p.last.IsZero() && now.Sub(p.last) < floorGap && !now.Before(p.last) {
			p.trailing = true
			p.inHour++
			wait := p.last.Add(floorGap).Sub(now)
			g.mu.Unlock()
			g.st.folded.Add(1)
			g.after(wait, func() { g.trail(h, token) })
			// as a push sent now answers: a fold says nothing of the phone
			return http.StatusCreated, 0
		}
	} else if len(g.floor) >= floorKept {
		if now.Sub(g.swept) >= sweepEvery {
			g.sweepLocked(now)
		}
		if len(g.floor) >= floorKept {
			g.mu.Unlock()
			g.st.limited.Add(1)
			return http.StatusTooManyRequests, 10 * time.Second
		}
	}
	if code, wait, ok := g.admit(); !ok {
		g.mu.Unlock()
		return code, wait
	}
	if p == nil {
		p = &phone{hourStart: now, fresh: true, seals: map[[8]byte]time.Time{sh: now}}
		g.floor[h] = p
	}
	p.last = now
	p.inHour++
	g.mu.Unlock()
	return g.send(h, token)
}

// the global pace and a free slot, taken together or not at all
func (g *gateway) admit() (int, time.Duration, bool) {
	if !everyone.allow() {
		g.st.limited.Add(1)
		return http.StatusTooManyRequests, 2 * time.Second, false
	}
	select {
	case g.slot <- struct{}{}:
		return 0, 0, true
	default:
		g.st.limited.Add(1)
		return http.StatusTooManyRequests, 2 * time.Second, false
	}
}

// the folded knock, once the floor is up. refused then, it is dropped: the
// knock before it went
func (g *gateway) trail(h [16]byte, token string) {
	g.mu.Lock()
	p := g.floor[h]
	if p != nil {
		p.trailing = false
	}
	_, _, ok := g.admit()
	if ok && p != nil {
		p.last = g.now()
	}
	g.mu.Unlock()
	if ok {
		g.send(h, token)
	}
}

// asks fcm, with a slot already taken, and answers with what it said if it
// says it in time. a push still running then finishes on its own
func (g *gateway) send(h [16]byte, token string) (int, time.Duration) {
	type answer struct {
		o    outcome
		wait time.Duration
	}
	done := make(chan answer, 1)
	go func() {
		defer func() { <-g.slot }()
		ctx, cancel := context.WithTimeout(context.Background(), pushBy)
		defer cancel()
		o, wait := g.fcm.push(ctx, token)
		g.noted(h, o)
		done <- answer{o, wait}
	}()
	t := time.NewTimer(answerBy)
	defer t.Stop()
	select {
	case a := <-done:
		switch a.o {
		case sent:
			return http.StatusCreated, 0
		case gone:
			return http.StatusGone, 0
		case busy:
			if a.wait <= 0 {
				a.wait = 10 * time.Second
			}
			return http.StatusTooManyRequests, a.wait
		default:
			return http.StatusBadGateway, a.wait
		}
	case <-t.C:
		return http.StatusAccepted, 0
	}
}

func (g *gateway) noted(h [16]byte, o outcome) {
	switch o {
	case sent:
		g.st.sent.Add(1)
		g.mu.Lock()
		if p := g.floor[h]; p != nil {
			p.fresh = false
		}
		g.mu.Unlock()
	case gone:
		g.st.gone.Add(1)
		// asked again only after a day: the relay drops the endpoint anyway.
		// it leaves the phones' table for the gone one, which has its own cap
		g.mu.Lock()
		delete(g.floor, h)
		g.addGoneLocked(h, g.now())
		g.mu.Unlock()
	case busy:
		g.st.limited.Add(1)
	default:
		g.st.failed.Add(1)
		// a token never pushed to, whose first push failed, holds no row
		g.mu.Lock()
		if p := g.floor[h]; p != nil && p.fresh && !p.trailing {
			delete(g.floor, h)
		}
		g.mu.Unlock()
	}
}

func (g *gateway) addGoneLocked(h [16]byte, now time.Time) {
	if _, ok := g.gone[h]; !ok {
		g.goneOrder = append(g.goneOrder, h)
	}
	g.gone[h] = now.Add(goneFor)
	// the oldest first, when full or ended; an entry asked about and found
	// ended was deleted already and is skipped
	for len(g.goneOrder) > 0 {
		first := g.goneOrder[0]
		until, ok := g.gone[first]
		if ok && len(g.gone) <= goneKept && now.Before(until) {
			break
		}
		if ok && (len(g.gone) > goneKept || !now.Before(until)) {
			delete(g.gone, first)
		}
		g.goneOrder = g.goneOrder[1:]
	}
	if cap(g.goneOrder) > 4*goneKept && len(g.goneOrder) < goneKept {
		g.goneOrder = append([][16]byte(nil), g.goneOrder...)
	}
}

// what has not pushed for an hour, and is not waiting or gone, is dropped
func (g *gateway) sweepLocked(now time.Time) {
	g.swept = now
	for h, p := range g.floor {
		if p.trailing {
			continue
		}
		if now.Sub(p.last) >= time.Hour && now.Sub(p.hourStart) >= time.Hour {
			delete(g.floor, h)
		}
	}
}

// counts only, never a token, an address or a hash
func (g *gateway) hourly() {
	t := time.NewTicker(time.Minute)
	defer t.Stop()
	for n := 1; ; n++ {
		<-t.C
		g.mu.Lock()
		g.sweepLocked(g.now())
		held := len(g.floor)
		g.mu.Unlock()
		if n%60 != 0 {
			continue
		}
		s := &g.st
		log.Printf("push: last hour %d sent, %d folded, %d gone, %d refused, %d failed, %d limited, %d held",
			s.sent.Swap(0), s.folded.Swap(0), s.gone.Swap(0), s.refused.Swap(0), s.failed.Swap(0), s.limited.Swap(0), held)
	}
}

type limiter struct {
	mu                  sync.Mutex
	rate, burst, tokens float64
	last                time.Time
}

func newLimiter(rate, burst float64) *limiter {
	return &limiter{rate: rate, burst: burst, tokens: burst, last: time.Now()}
}

func (l *limiter) allow() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := time.Now()
	l.tokens = min(l.burst, l.tokens+now.Sub(l.last).Seconds()*l.rate)
	l.last = now
	if l.tokens < 1 {
		return false
	}
	l.tokens--
	return true
}
