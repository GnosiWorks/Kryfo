// halo nostr layer — store-and-forward messaging via public relays.
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
	"encoding/hex"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"fiatjaf.com/nostr"
	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/hkdf"
)

const haloNostrKind = 30078

var (
	nostrMu      sync.Mutex
	nostrRelays  []string
	nostrSubs    = map[string]context.CancelFunc{}
	nostrInbox   []string
)

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

// derive the deterministic ephemeral nostr keypair for conversation with peer.
// both peers compute the same keypair from their shared ECDH secret -> they read/write the same address.
func nostrDeriveKeys(peerXPub [32]byte) (sk nostr.SecretKey, pk nostr.PubKey, err error) {
	shared, e := curve25519.X25519(myXPriv[:], peerXPub[:])
	if e != nil {
		return sk, pk, e
	}
	convID := nostrConversationID(myXPub, peerXPub)
	seed := nostrHkdf(shared, convID, []byte("halo-nostr-key-v1"), 32)
	var seedArr [32]byte
	copy(seedArr[:], seed)
	sk = nostr.SecretKey(seedArr)
	pk = sk.Public()
	return
}

// ---------- relay pool ----------

func nostrPublishMulti(ctx context.Context, ev nostr.Event) (ok int) {
	nostrMu.Lock()
	urls := append([]string(nil), nostrRelays...)
	nostrMu.Unlock()

	var wg sync.WaitGroup
	var mu sync.Mutex
	for _, url := range urls {
		wg.Add(1)
		go func(u string) {
			defer wg.Done()
			rctx, cancel := context.WithTimeout(ctx, 15*time.Second)
			defer cancel()
			r, err := nostr.RelayConnect(rctx, u, nostr.RelayOptions{})
			if err != nil {
				log.Printf("nostr: connect %s: %v", u, err)
				return
			}
			defer r.Close()
			if err := r.Publish(rctx, ev); err != nil {
				log.Printf("nostr: publish %s: %v", u, err)
				return
			}
			mu.Lock()
			ok++
			mu.Unlock()
		}(url)
	}
	wg.Wait()
	return
}

// run a long-lived subscription against all configured relays for events from `pk`.
// dedupes across relays. exits when ctx is cancelled.
func nostrSubscribeRunner(ctx context.Context, peerXPubHex string, pk nostr.PubKey) {
	nostrMu.Lock()
	urls := append([]string(nil), nostrRelays...)
	nostrMu.Unlock()

	seen := map[string]bool{}
	var seenMu sync.Mutex

	dispatch := func(ev nostr.Event) {
		id := ev.ID.Hex()
		seenMu.Lock()
		dup := seen[id]
		seen[id] = true
		seenMu.Unlock()
		if dup {
			return
		}
		nostrMu.Lock()
		nostrInbox = append(nostrInbox, peerXPubHex+"|"+ev.Content)
		nostrMu.Unlock()
		log.Printf("nostr: received event %s for peer %s...", id[:12], peerXPubHex[:12])
	}

	for _, url := range urls {
		go func(u string) {
			for {
				select {
				case <-ctx.Done():
					return
				default:
				}
				r, err := nostr.RelayConnect(ctx, u, nostr.RelayOptions{})
				if err != nil {
					log.Printf("nostr: subscribe-connect %s: %v", u, err)
					time.Sleep(10 * time.Second)
					continue
				}
				f := nostr.Filter{
					Authors: []nostr.PubKey{pk},
					Kinds:   []nostr.Kind{haloNostrKind},
					Limit:   100,
				}
				sub, err := r.Subscribe(ctx, f, nostr.SubscriptionOptions{})
				if err != nil {
					log.Printf("nostr: subscribe %s: %v", u, err)
					r.Close()
					time.Sleep(10 * time.Second)
					continue
				}
				for {
					select {
					case ev, alive := <-sub.Events:
						if !alive {
							r.Close()
							goto reconnect
						}
						if ev.ID.Hex() != "" {
							dispatch(ev)
						}
					case <-ctx.Done():
						r.Close()
						return
					}
				}
			reconnect:
				time.Sleep(5 * time.Second)
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
	peerHex := C.GoString(cPeerXPubHex)
	msg := C.GoString(cMsg)

	peerBytes, err := hex.DecodeString(peerHex)
	if err != nil || len(peerBytes) != 32 {
		return C.CString("error: bad peer pubkey")
	}
	var peerArr [32]byte
	copy(peerArr[:], peerBytes)

	sk, pk, err := nostrDeriveKeys(peerArr)
	if err != nil {
		return C.CString(fmt.Sprintf("error: derive: %v", err))
	}

	convID := nostrConversationID(myXPub, peerArr)
	ev := nostr.Event{
		PubKey:    pk,
		CreatedAt: nostr.Now(),
		Kind:      haloNostrKind,
		Tags: nostr.Tags{
			{"d", hex.EncodeToString(convID)},
			{"halo", "v1"},
		},
		Content: msg,
	}
	ev.Sign(sk)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	ok := nostrPublishMulti(ctx, ev)
	if ok == 0 {
		return C.CString("error: no relays accepted")
	}
	log.Printf("nostr: sent event %s to %d/%d relays", ev.ID.Hex()[:12], ok, len(nostrRelays))
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

	_, pk, err := nostrDeriveKeys(peerArr)
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

	go nostrSubscribeRunner(ctx, peerHex, pk)
	log.Printf("nostr: subscribed for peer %s... at ephemeral %s...", peerHex[:12], pk.Hex()[:12])
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
