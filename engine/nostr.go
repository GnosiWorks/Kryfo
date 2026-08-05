// SPDX-License-Identifier: GPL-3.0-or-later
// halo nostr layer - store-and-forward messaging via public relays.
// phase 1.6 sprint 5+6: integration into engine.
//
// architecture:
//   - dart encrypts plaintext with libsignal -> ciphertext (base64)
//   - dart calls HaloNostrSend(peerXPubHex, b64Ciphertext)
//   - engine derives ephemeral nostr keypair from ECDH(myXPriv, peerXPub) + conversation id
//   - engine wraps ciphertext in nostr event signed by ephemeral key
//   - engine publishes to all configured relays in parallel
//
// receive:
//   - dart calls HaloNostrSubscribe(peerXPubHex) when contact is added
//   - engine derives the same ephemeral pubkey and subscribes for events authored by it
//   - on event arrival, engine appends "peerXPubHex|content" to nostrInbox queue
//   - dart polls HaloNostrPoll() and routes to libsignal.decrypt(peer, ciphertext)
//
// privacy mitigations:
//   - relays only ever see disposable per-conversation pubkeys, not identity
//   - libsignal ciphertext is opaque to relays (and to us)
//   - tor wiring deferred to next sprint (sprint 1.6.7)

package main

import "C"

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"golang.org/x/crypto/hkdf"
)

var (
	nostrMu      sync.Mutex
	nostrRelays  []string
	nostrSubs    = map[string]context.CancelFunc{}
	nostrInbox   []string
	nostrSentIDs = map[string]bool{}
)

// relay health. a relay that will not answer still costs a full tor circuit
// on every attempt, and with one subscribe goroutine per relay per contact
// that adds up fast - damus sat on 503 for fifty-three straight tries inside
// one ninety-second window. count consecutive failures, bench the relay for
// a doubling stretch, forget the whole history on the first success.
var (
	relayHealthMu sync.Mutex
	relayFails    = map[string]int{}
	relayCoolTill = map[string]time.Time{}
)

// a couple of misses is just a bad circuit, not a dead relay.
const relayFailGrace = 3

func relayBackoff(n int) time.Duration {
	if n <= relayFailGrace {
		return 0
	}
	shift := n - relayFailGrace - 1
	if shift > 6 {
		return 5 * time.Minute
	}
	d := 10 * time.Second << uint(shift)
	if d > 5*time.Minute {
		d = 5 * time.Minute
	}
	return d
}

func relayCold(u string) bool {
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	till, ok := relayCoolTill[u]
	return ok && time.Now().Before(till)
}

func relayFailed(u string) {
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	relayFails[u]++
	if d := relayBackoff(relayFails[u]); d > 0 {
		relayCoolTill[u] = time.Now().Add(d)
		log.Printf("nostr: benching %s for %s, %d failures in a row", u, d, relayFails[u])
	}
}

func relayOK(u string) {
	relayHealthMu.Lock()
	defer relayHealthMu.Unlock()
	if relayFails[u] != 0 {
		delete(relayFails, u)
		delete(relayCoolTill, u)
	}
}

// how long to wait before the next attempt, never shorter than the caller's
// own cadence.
func relayRetryAfter(u string, base time.Duration) time.Duration {
	relayHealthMu.Lock()
	n := relayFails[u]
	relayHealthMu.Unlock()
	if d := relayBackoff(n); d > base {
		return d
	}
	return base
}

// ---------- key derivation (mirrors probe) ----------

func nostrConversationID(a, b [32]byte) []byte {
	first, second := a[:], b[:]
	if string(first) > string(second) {
		first, second = second, first
	}
	h := sha256.New()
	h.Write(first)
	h.Write(second)
	return h.Sum(nil)[:16]
}

func nostrHkdf(secret, salt, info []byte, length int) []byte {
	r := hkdf.New(sha256.New, secret, salt, info)
	out := make([]byte, length)
	r.Read(out)
	return out
}

// ---------- relay pool ----------
// torNostrClient builds an http.Client whose dials route through the engine's
// running tor SOCKS proxy. returns error if tor isn't ready.
var (
	cachedNostrClient   *http.Client
	cachedNostrClientMu sync.Mutex
	dialerHangs         int
)

// called from shutdown. the cached client pins the old tor's socks
// dialer; without this every publish after a restart-in-process talked
// to a dead port.
func nostrResetClient() {
	cachedNostrClientMu.Lock()
	cachedNostrClient = nil
	cachedNostrClientMu.Unlock()
}

func torNostrClient() (*http.Client, error) {
	cachedNostrClientMu.Lock()
	defer cachedNostrClientMu.Unlock()
	if cachedNostrClient != nil {
		return cachedNostrClient, nil
	}
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil {
		return nil, fmt.Errorf("tor not started")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	log.Printf("nostr: building cached http.Client via t.Dialer (once)")
	// t.Dialer can wedge on a busy control conn mid-bootstrap and it does not
	// honor ctx. run it off to the side so a hang can't hold the client mutex
	// forever - every send in the app queues behind that lock.
	built := make(chan *http.Client, 1)
	fail := make(chan error, 1)
	go func() {
		d, e := t.Dialer(ctx, nil)
		if e != nil {
			fail <- e
			return
		}
		built <- &http.Client{
			Transport: &http.Transport{
				DialContext:           d.DialContext,
				TLSHandshakeTimeout:   10 * time.Second,
				ResponseHeaderTimeout: 10 * time.Second,
			},
			Timeout: 60 * time.Second,
		}
	}()
	select {
	case c := <-built:
		log.Printf("nostr: cached http.Client built")
		cachedNostrClient = c
		dialerHangs = 0
		restoreReachableIfHealed()
		return cachedNostrClient, nil
	case e := <-fail:
		log.Printf("nostr: t.Dialer returned err=%v", e)
		return nil, fmt.Errorf("tor dialer: %v", e)
	case <-ctx.Done():
		dialerHangs++
		log.Printf("nostr: t.Dialer hung (%d in a row), giving up this round", dialerHangs)
		// a wedged control conn never recovers on its own - every retry
		// re-hangs. after a few, bounce tor's network to rebuild it, and
		// stop the status dot lying green while nothing can send.
		// drop the poisoned client so the next attempt rebuilds clean, and
		// stop the dot lying green while the dialer is provably dead. the
		// hard backoff in the subscribe loop is what actually heals it -
		// it lets the busy control port drain instead of piling on more
		// hung dials (that hammering is what wedges it).
		cachedNostrClient = nil
		if dialerHangs >= 3 {
			demoteFromReachable()
		}
		// dropping the client alone never heals a wedged control conn - the
		// rebuild just re-hangs. past a higher bar the process itself is gone,
		// so relaunch tor (async, it takes seconds and holds startMu).
		if dialerHangs >= 5 {
			dialerHangs = 0
			go restartTor()
		}
		return nil, fmt.Errorf("tor dialer hung")
	}
}

// the dot must not read reachable while the dialer is provably dead.
func demoteFromReachable() {
	statusMu.Lock()
	if torStatus == "reachable" {
		log.Println("nostr: dialer dead, status reachable -> publishing (was lying green)")
		torStatus = "publishing"
	}
	statusMu.Unlock()
}

func restoreReachableIfHealed() {
	statusMu.Lock()
	// only lift back to reachable if we'd demoted (hs is up, we just lost the
	// dialer). hsdirUploads > 0 means the descriptor was published earlier.
	if torStatus == "publishing" && hsdirUploads > 0 {
		log.Println("nostr: dialer alive again, status publishing -> reachable")
		torStatus = "reachable"
	}
	statusMu.Unlock()
}

func nostrPublishMulti(ctx context.Context, ev nostr.Event) (ok int) {
	nostrMu.Lock()
	all := append([]string(nil), nostrRelays...)
	nostrMu.Unlock()

	// index 0 is our own relay and is never benched - it carries the traffic
	// and the tor watchdog already covers it going away.
	urls := make([]string, 0, len(all))
	for i, u := range all {
		if i == 0 || !relayCold(u) {
			urls = append(urls, u)
		}
	}
	if len(urls) == 0 {
		urls = all
	}

	// publishes run on a context detached from the caller's: HaloNostrSend
	// does `defer cancel()`, so once we return the request ctx dies. we
	// want the SLOWER relays to keep landing for redundancy after we've
	// already returned on the first success - hence background + our own
	// timeout, not a child of ctx.
	bg, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)

	result := make(chan bool, len(urls))
	var pending int32 = int32(len(urls))
	for _, url := range urls {
		go func(u string) {
			// last publisher out turns off the lights (frees bg).
			defer func() {
				if atomic.AddInt32(&pending, -1) == 0 {
					bgCancel()
				}
			}()
			client, err := torNostrClient()
			if err != nil {
				log.Printf("nostr: tor not ready, skipping publish to %s: %v", u, err)
				result <- false
				return
			}
			r := nostr.NewRelay(bg, u, nostr.RelayOptions{})
			if err := r.ConnectWithClient(bg, client); err != nil {
				log.Printf("nostr: connect %s: %v", u, err)
				relayFailed(u)
				result <- false
				return
			}
			defer r.Close()
			if err := r.Publish(bg, ev); err != nil {
				log.Printf("nostr: publish %s: %v", u, err)
				relayFailed(u)
				result <- false
				return
			}
			relayOK(u)
			log.Printf("nostr: published to %s ok", u)
			result <- true
		}(url)
	}

	// return the instant ONE relay accepts - delivery no longer waits on the
	// second-fastest (usually a flaky public relay). the rest keep going on
	// bg for redundancy. if the caller's ctx dies first, we still leave the
	// background publishes running and report what landed so far.
	accepted := 0
	for i := 0; i < len(urls); i++ {
		select {
		case r := <-result:
			if r {
				accepted++
				if accepted >= 1 {
					return accepted
				}
			}
		case <-ctx.Done():
			log.Printf("nostr: caller ctx done, %d relays in ok so far (rest continue in bg)", accepted)
			return accepted
		}
	}
	return accepted
}

// run a long-lived subscription against all configured relays for events from `pk`.
// dedupes across relays. exits when ctx is cancelled.
func nostrSubscribeRunner(ctx context.Context, peerXPubHex string, peerArr [32]byte, rcvPk string) {
	nostrSubscribeRunnerMode(ctx, peerXPubHex, peerArr, rcvPk, false, 0)
}

func nostrSubscribeRunnerMode(ctx context.Context, peerXPubHex string, peerArr [32]byte, rcvPk string, fc bool, fcCounter int) {
	nostrMu.Lock()
	urls := append([]string(nil), nostrRelays...)
	nostrMu.Unlock()

	seen := map[string]bool{}
	var seenMu sync.Mutex

	// restarts used to refetch the whole 12h window and shove every old
	// wrap back through decrypt. remember ids + high-water timestamp on
	// disk so a relaunch picks up where it left off.
	seenPath := ""
	lastPath := ""
	var lastSaved int64
	if savedDataDir != "" {
		tag := rcvPk
		if len(tag) > 16 {
			tag = tag[:16]
		}
		seenPath = savedDataDir + "/nostr_seen_" + tag
		lastPath = savedDataDir + "/nostr_last_" + tag
		if b, err := os.ReadFile(seenPath); err == nil {
			lines := strings.Split(string(b), "\n")
			// keep the file from growing forever - old ids age out of the
			// relay window anyway
			if len(lines) > 4000 {
				lines = lines[len(lines)-2000:]
				os.WriteFile(seenPath, []byte(strings.Join(lines, "\n")), 0600)
			}
			for _, line := range lines {
				if line != "" {
					seen[line] = true
				}
			}
		}
		if b, err := os.ReadFile(lastPath); err == nil {
			if v, perr := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64); perr == nil {
				lastSaved = v
			}
		}
	}
	saveSeen := func(id string) {
		if seenPath == "" {
			return
		}
		f, err := os.OpenFile(seenPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
		if err != nil {
			return
		}
		f.WriteString(id + "\n")
		f.Close()
	}
	saveLast := func(ts int64) {
		seenMu.Lock()
		stale := ts <= lastSaved
		if !stale {
			lastSaved = ts
		}
		seenMu.Unlock()
		if stale || lastPath == "" {
			return
		}
		os.WriteFile(lastPath, []byte(strconv.FormatInt(ts, 10)), 0600)
	}

	dispatch := func(ev nostr.Event) {
		id := ev.ID.Hex()
		nostrMu.Lock()
		mine := nostrSentIDs[id]
		nostrMu.Unlock()
		if mine {
			return
		}
		seenMu.Lock()
		dup := seen[id]
		seen[id] = true
		seenMu.Unlock()
		if dup {
			return
		}
		saveSeen(id)
		var gw nostr2.Event
		if err := easyjson.Unmarshal([]byte(ev.String()), &gw); err != nil {
			log.Printf("nostr: wrap parse failed: %v", err)
			return
		}
		var content string
		var err error
		if fc {
			content, _, err = nip17UnwrapFirstContact(fcCounter, gw)
		} else {
			content, err = nip17Unwrap(peerArr, gw)
		}
		if err != nil {
			log.Printf("nostr: unwrap dropped one: %v", err)
			return
		}
		tag := peerXPubHex
		if fc {
			tag = "firstcontact"
		}
		nostrMu.Lock()
		nostrInbox = append(nostrInbox, tag+"|"+content)
		nostrMu.Unlock()
		log.Printf("nostr: received event %s for peer %s...", id[:12], peerXPubHex[:12])
	}

	for i, url := range urls {
		// first relay is our own - it carries the traffic, heal it hard
		own := i == 0
		go func(u string) {
			last := nostr.Timestamp(lastSaved)
			retry := 10 * time.Second
			rejoin := 5 * time.Second
			deaf := 4 * time.Minute
			if own {
				retry = 3 * time.Second
				rejoin = 2 * time.Second
				deaf = 75 * time.Second
			}
			for {
				select {
				case <-ctx.Done():
					return
				default:
				}
				client, err := torNostrClient()
				if err != nil {
					cachedNostrClientMu.Lock()
					hangs := dialerHangs
					cachedNostrClientMu.Unlock()
					wait := 10 * time.Second
					if hangs >= 3 {
						wait = 45 * time.Second
					}
					log.Printf("nostr: tor not ready, retry subscribe to %s in %s: %v", u, wait, err)
					time.Sleep(wait)
					continue
				}
				r := nostr.NewRelay(ctx, u, nostr.RelayOptions{})
				if err := r.ConnectWithClient(ctx, client); err != nil {
					log.Printf("nostr: subscribe-connect %s: %v", u, err)
					wait := retry
					if !own {
						relayFailed(u)
						wait = relayRetryAfter(u, retry)
					}
					time.Sleep(wait)
					continue
				}
				f := nostr.Filter{
					Kinds: []nostr.Kind{1059},
					Tags:  nostr.TagMap{"p": []string{rcvPk}},
					Limit: 100,
				}
				// after the first connect only ask for what we missed - refetching
				// 100 old events over tor on every reconnect was pure waste.
				if last > 0 {
					// wraps carry timestamps jittered up to ~10h into the past,
					// so pull the window back or a late-stamped fresh wrap gets
					// filtered out. the dedup layers eat the refetch.
					since := last - nostr.Timestamp(12*3600)
					if since > 0 {
						f.Since = since
					}
				}
				sub, err := r.Subscribe(ctx, f, nostr.SubscriptionOptions{})
				if err != nil {
					log.Printf("nostr: subscribe %s: %v", u, err)
					r.Close()
					wait := retry
					if !own {
						relayFailed(u)
						wait = relayRetryAfter(u, retry)
					}
					time.Sleep(wait)
					continue
				}
				if !own {
					relayOK(u)
				}
				log.Printf("nostr: listening on %s for addr %s...", u, rcvPk[:12])
				// a dead tor circuit leaves the websocket open but mute - no
				// error, no channel close, this select just goes deaf forever
				// while messages slide past. quiet too long = assume dead and
				// reconnect; the since window refetches whatever we missed.
				idle := time.NewTimer(deaf)
				for {
					select {
					case ev, alive := <-sub.Events:
						if !alive {
							idle.Stop()
							r.Close()
							goto reconnect
						}
						if ev.ID.Hex() != "" {
							if ev.CreatedAt > last {
								last = ev.CreatedAt
								saveLast(int64(ev.CreatedAt))
							}
							dispatch(ev)
						}
						if !idle.Stop() {
							select {
							case <-idle.C:
							default:
							}
						}
						idle.Reset(deaf)
					case <-idle.C:
						log.Printf("nostr: %s quiet %s, cycling the sub", u, deaf)
						r.Close()
						// a quiet relay proves nothing on its own - an idle chat looks
						// exactly like a dead circuit from here. just cycle the sub; a
						// genuinely unusable tor shows up as dial failures, which
						// restartTor already watches for.
						goto reconnect
					case <-ctx.Done():
						idle.Stop()
						r.Close()
						return
					}
				}
			reconnect:
				time.Sleep(rejoin)
			}
		}(url)
	}
}

// ---------- FFI exports ----------

//export HaloNostrInit
func HaloNostrInit(cRelaysCSV *C.char) *C.char {
	csv := C.GoString(cRelaysCSV)
	if csv == "" {
		return C.CString("error: empty relay list")
	}
	urls := strings.Split(csv, ",")
	clean := make([]string, 0, len(urls))
	for _, u := range urls {
		u = strings.TrimSpace(u)
		if u != "" {
			clean = append(clean, u)
		}
	}
	if len(clean) == 0 {
		return C.CString("error: no valid relay urls")
	}
	nostrMu.Lock()
	nostrRelays = clean
	nostrMu.Unlock()
	log.Printf("nostr: configured %d relays: %v", len(clean), clean)
	return C.CString("ok")
}

//export HaloNostrSend
func HaloNostrSend(cPeerXPubHex, cMsg *C.char) *C.char {
	log.Printf("nostr: HaloNostrSend ENTRY")
	peerHex := C.GoString(cPeerXPubHex)
	msg := C.GoString(cMsg)

	peerBytes, err := hex.DecodeString(peerHex)
	if err != nil || len(peerBytes) != 32 {
		return C.CString("error: bad peer pubkey")
	}
	var peerArr [32]byte
	copy(peerArr[:], peerBytes)

	gw, err := nip17Wrap(peerArr, msg)
	if err != nil {
		return C.CString(fmt.Sprintf("error: wrap: %v", err))
	}
	// the wrap is built with the nip59 lib's event type; cross into the relay
	// lib as plain json. id and sig survive verbatim, both speak nip-01.
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		return C.CString(fmt.Sprintf("error: wrap convert: %v", err))
	}
	nostrMu.Lock()
	nostrSentIDs[ev.ID.Hex()] = true
	if len(nostrSentIDs) > 4096 {
		nostrSentIDs = map[string]bool{}
	}
	nostrMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	ok := nostrPublishMulti(ctx, ev)
	if ok == 0 {
		return C.CString("error: no relays accepted")
	}
	// log the drop-box we published to. if a peer isn't receiving, compare this
	// against the "at addr" in their subscribe line - a mismatch means the two
	// sides derived different addresses and nothing will ever arrive.
	_, dst, derr := nip17DeriveRole(peerArr, nip17RcvInfo, hex.EncodeToString(peerArr[:]))
	if derr == nil {
		log.Printf("nostr: sent event %s to %d relays, addr %s...", ev.ID.Hex()[:12], ok, dst[:12])
	} else {
		log.Printf("nostr: sent event %s to %d relays", ev.ID.Hex()[:12], ok)
	}
	return C.CString("ok")
}

//export HaloNostrSubscribe
func HaloNostrSubscribe(cPeerXPubHex *C.char) *C.char {
	peerHex := C.GoString(cPeerXPubHex)
	peerBytes, err := hex.DecodeString(peerHex)
	if err != nil || len(peerBytes) != 32 {
		return C.CString("error: bad peer pubkey")
	}
	var peerArr [32]byte
	copy(peerArr[:], peerBytes)

	_, rcvPk, err := nip17RcvAddress(peerArr)
	if err != nil {
		return C.CString(fmt.Sprintf("error: derive: %v", err))
	}

	nostrMu.Lock()
	if cancel, exists := nostrSubs[peerHex]; exists {
		cancel()
		delete(nostrSubs, peerHex)
	}
	ctx, cancel := context.WithCancel(context.Background())
	nostrSubs[peerHex] = cancel
	nostrMu.Unlock()

	go nostrSubscribeRunner(ctx, peerHex, peerArr, rcvPk)
	log.Printf("nostr: subscribed for peer %s... at addr %s...", peerHex[:12], rcvPk[:12])
	return C.CString("ok")
}

// the public half of our first-contact address. goes in the invite so a
// stranger can reach us before either side knows the other's key.
//
//export HaloFirstContactPk
func HaloFirstContactPk(counter C.int) *C.char {
	_, pk, err := nip17FirstContactKeys(int(counter))
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	return C.CString(pk)
}

// watch our own first-contact address. unlike every other subscription this
// needs no contacts, which is the whole point: a fresh install with an empty
// roster can still be reached.
//
//export HaloNostrSubscribeFirstContact
func HaloNostrSubscribeFirstContact(counter C.int) *C.char {
	_, fcPk, err := nip17FirstContactKeys(int(counter))
	if err != nil {
		return C.CString(fmt.Sprintf("error: derive: %v", err))
	}

	nostrMu.Lock()
	if cancel, exists := nostrSubs["firstcontact"]; exists {
		cancel()
		delete(nostrSubs, "firstcontact")
	}
	ctx, cancel := context.WithCancel(context.Background())
	nostrSubs["firstcontact"] = cancel
	nostrMu.Unlock()

	var zero [32]byte
	go nostrSubscribeRunnerMode(ctx, "firstcontact", zero, fcPk, true, int(counter))
	log.Printf("nostr: watching first-contact addr %s...", fcPk[:12])
	return C.CString("ok")
}

// introduce ourselves to someone who has never heard of us. the seal is
// signed with our usual per-conversation key, so once they know us the normal
// verification applies to everything after this.
//
//export HaloNostrSendFirstContact
func HaloNostrSendFirstContact(cPeerXPubHex, cFcPk, cMsg *C.char) *C.char {
	peerHex := C.GoString(cPeerXPubHex)
	fcPk := C.GoString(cFcPk)
	msg := C.GoString(cMsg)

	peerBytes, err := hex.DecodeString(peerHex)
	if err != nil || len(peerBytes) != 32 {
		return C.CString("error: bad peer pubkey")
	}
	if len(fcPk) != 64 {
		return C.CString("error: bad first-contact pubkey")
	}
	var peerArr [32]byte
	copy(peerArr[:], peerBytes)

	gw, err := nip17WrapFirstContact(peerArr, fcPk, msg)
	if err != nil {
		return C.CString(fmt.Sprintf("error: wrap: %v", err))
	}
	// the wrap comes from the nip59 lib's event type; cross into the relay
	// lib as plain json, same as the normal send path.
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		return C.CString(fmt.Sprintf("error: wrap convert: %v", err))
	}
	nostrMu.Lock()
	nostrSentIDs[ev.ID.Hex()] = true
	if len(nostrSentIDs) > 4096 {
		nostrSentIDs = map[string]bool{}
	}
	nostrMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	ok := nostrPublishMulti(ctx, ev)
	if ok == 0 {
		return C.CString("error: no relays accepted")
	}
	log.Printf("nostr: sent first-contact %s to %d relays, addr %s...", ev.ID.Hex()[:12], ok, fcPk[:12])
	return C.CString("ok")
}

//export HaloNostrPoll
func HaloNostrPoll() *C.char {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	if len(nostrInbox) == 0 {
		return C.CString("")
	}
	out := strings.Join(nostrInbox, "\n")
	nostrInbox = nostrInbox[:0]
	return C.CString(out)
}

// posts a wake-up trigger to the peer's ntfy endpoint via tor. fire-and-
// forget from dart's perspective. message body is a fixed string; ntfy
// only cares that *something* arrived to wake subscribers.
//
//export HaloNtfyPing
func HaloNtfyPing(cEndpoint *C.char) *C.char {
	endpoint := C.GoString(cEndpoint)
	if endpoint == "" {
		return C.CString("error: empty endpoint")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, strings.NewReader("halo"))
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	req.Header.Set("Content-Type", "text/plain")
	req.Header.Set("Title", "halo")
	req.Header.Set("Priority", "high")
	resp, err := client.Do(req)
	if err != nil {
		return C.CString(fmt.Sprintf("error: post: %v", err))
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return C.CString(fmt.Sprintf("error: status %d", resp.StatusCode))
	}
	log.Printf("ntfy: pinged %s -> %d", endpoint, resp.StatusCode)
	return C.CString("ok")
}

// fetch a url over the tor http client and return the html body (capped).
// used for sender-side link previews so the receiver never has to fetch and
// leak their ip. best-effort: returns "error: ..." on any failure, caller skips.
//
//export HaloTorGet
func HaloTorGet(cUrl *C.char) *C.char {
	url := C.GoString(cUrl)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; halo-preview)")
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: get: %v", err))
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return C.CString(fmt.Sprintf("error: status %d", resp.StatusCode))
	}
	// cap at 256kb - the og tags live in <head>, no need for the whole page.
	limited := io.LimitReader(resp.Body, 256*1024)
	body, err := io.ReadAll(limited)
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	return C.CString(string(body))
}

// POST json over tor, returning the response body. used for the badge
// service (creating a donation invoice) so the donor's ip never touches
// anything. any non-2xx comes back as "error: ..." for the caller to skip.
//
//export HaloTorPost
func HaloTorPost(cUrl *C.char, cBody *C.char) *C.char {
	url := C.GoString(cUrl)
	body := C.GoString(cBody)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("POST", url, strings.NewReader(body))
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	req.Header.Set("Content-Type", "application/json")
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: post: %v", err))
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	if resp.StatusCode >= 300 {
		return C.CString(fmt.Sprintf("error: status %d: %s", resp.StatusCode, string(out)))
	}
	return C.CString(string(out))
}

// GET over tor that keeps the body for ANY 2xx - the badge service answers
// 202 while a payment is still pending, which HaloTorGet would reject.
//
//export HaloTorGetJSON
func HaloTorGetJSON(cUrl *C.char) *C.char {
	url := C.GoString(cUrl)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: get: %v", err))
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	if resp.StatusCode >= 300 {
		return C.CString(fmt.Sprintf("error: status %d", resp.StatusCode))
	}
	return C.CString(string(out))
}

// like HaloTorGet but returns the body base64-encoded, for binary content
// (link-preview images). fetched over tor so the receiver never loads the
// image from the origin and leaks their ip. capped larger than html.
//
//export HaloTorGetB64
func HaloTorGetB64(cUrl *C.char) *C.char {
	url := C.GoString(cUrl)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; halo-preview)")
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: get: %v", err))
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return C.CString(fmt.Sprintf("error: status %d", resp.StatusCode))
	}
	// cap at 1mb - preview thumbnails, not full-res.
	limited := io.LimitReader(resp.Body, 1024*1024)
	body, err := io.ReadAll(limited)
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	return C.CString("ok:" + base64.StdEncoding.EncodeToString(body))
}
