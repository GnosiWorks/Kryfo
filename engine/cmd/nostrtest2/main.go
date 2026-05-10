// halo nostr roundtrip probe — sprints 1.6.2 + 1.6.3 + 1.6.4 + 1.6.7
//
// what this probe does:
//   1. simulates two halos (alice, bob) with X25519 keys
//   2. derives a shared secret via ECDH (same crypto our engine already does)
//   3. derives ephemeral nostr keys per-conversation via HKDF
//      → relays see "encrypted blob to pubkey Y" but Y is disposable, can't be linked to identity
//   4. encrypts a real message with chacha20-poly1305 using the shared secret
//   5. wraps ciphertext in a nostr event signed with the ephemeral key
//   6. publishes to 3 public relays in parallel
//   7. subscribes to the same 3 relays in parallel, dedupes by event id, picks first
//   8. decrypts, verifies plaintext roundtripped intact
//
// not yet here: tor SOCKS routing (sprint 1.6.7) — added in next iteration
// once we confirm the fiatjaf.com/nostr RelayOptions API for custom dialers.

package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sort"
	"sync"
	"time"

	"fiatjaf.com/nostr"
	"golang.org/x/crypto/chacha20poly1305"
	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/hkdf"
)

const haloKind = 30078 // NIP-78 application-specific data

var relayURLs = []string{
	"wss://relay.damus.io",
	"wss://nos.lol",
	"wss://relay.snort.social",
}

// ---------- crypto helpers ----------

func genX25519() (priv, pub [32]byte) {
	if _, err := rand.Read(priv[:]); err != nil {
		panic(err)
	}
	curve25519.ScalarBaseMult(&pub, &priv)
	return
}

func ecdh(priv, peerPub [32]byte) []byte {
	out, err := curve25519.X25519(priv[:], peerPub[:])
	if err != nil {
		panic(err)
	}
	return out
}

// conversationID = first 16 bytes of sha256(min(a,b) || max(a,b))
// stable for both peers regardless of who initiated.
func conversationID(a, b [32]byte) []byte {
	first, second := a[:], b[:]
	if string(first) > string(second) {
		first, second = second, first
	}
	h := sha256.New()
	h.Write(first)
	h.Write(second)
	return h.Sum(nil)[:16]
}

func hkdfExpand(secret, salt, info []byte, length int) []byte {
	r := hkdf.New(sha256.New, secret, salt, info)
	out := make([]byte, length)
	if _, err := r.Read(out); err != nil {
		panic(err)
	}
	return out
}

// derive a deterministic 32-byte secp256k1 secret key from shared secret + conversation id
func deriveNostrSeed(sharedSecret, convID []byte) [32]byte {
	seed := hkdfExpand(sharedSecret, convID, []byte("halo-nostr-key-v1"), 32)
	var out [32]byte
	copy(out[:], seed)
	return out
}

func deriveMessageKey(sharedSecret, convID []byte) []byte {
	return hkdfExpand(sharedSecret, convID, []byte("halo-msg-key-v1"), 32)
}

func encrypt(key, plaintext []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(key)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}
	return append(nonce, aead.Seal(nil, nonce, plaintext, nil)...), nil
}

func decrypt(key, ct []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(key)
	if err != nil {
		return nil, err
	}
	if len(ct) < aead.NonceSize() {
		return nil, fmt.Errorf("ciphertext too short")
	}
	nonce, body := ct[:aead.NonceSize()], ct[aead.NonceSize():]
	return aead.Open(nil, nonce, body, nil)
}

// ---------- nostr fan-out ----------

func publishMulti(ctx context.Context, urls []string, ev nostr.Event) int {
	var wg sync.WaitGroup
	var ok int
	var mu sync.Mutex
	for _, url := range urls {
		wg.Add(1)
		go func(u string) {
			defer wg.Done()
			rctx, cancel := context.WithTimeout(ctx, 15*time.Second)
			defer cancel()
			r, err := nostr.RelayConnect(rctx, u, nostr.RelayOptions{})
			if err != nil {
				fmt.Printf("  ✗ %s — connect: %v\n", u, err)
				return
			}
			defer r.Close()
			if err := r.Publish(rctx, ev); err != nil {
				fmt.Printf("  ✗ %s — publish: %v\n", u, err)
				return
			}
			fmt.Printf("  ✓ %s — published\n", u)
			mu.Lock()
			ok++
			mu.Unlock()
		}(url)
	}
	wg.Wait()
	return ok
}

func subscribeMulti(ctx context.Context, urls []string, pk nostr.PubKey, kind nostr.Kind) (nostr.Event, bool) {
	rctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	out := make(chan nostr.Event, len(urls))
	var wg sync.WaitGroup
	for _, url := range urls {
		wg.Add(1)
		go func(u string) {
			defer wg.Done()
			r, err := nostr.RelayConnect(rctx, u, nostr.RelayOptions{})
			if err != nil {
				fmt.Printf("  ✗ %s — connect: %v\n", u, err)
				return
			}
			defer r.Close()
			f := nostr.Filter{
				Authors: []nostr.PubKey{pk},
				Kinds:   []nostr.Kind{kind},
				Limit:   5,
			}
			sub, err := r.Subscribe(rctx, f, nostr.SubscriptionOptions{})
			if err != nil {
				fmt.Printf("  ✗ %s — subscribe: %v\n", u, err)
				return
			}
			select {
			case ev := <-sub.Events:
				if ev.ID.Hex() != "" {
					fmt.Printf("  ✓ %s — got event\n", u)
					select {
					case out <- ev:
					default:
					}
				}
			case <-rctx.Done():
			}
		}(url)
	}

	go func() { wg.Wait(); close(out) }()

	seen := map[string]bool{}
	for ev := range out {
		id := ev.ID.Hex()
		if !seen[id] {
			seen[id] = true
			return ev, true
		}
	}
	return nostr.Event{}, false
}

// ---------- main ----------

func main() {
	fmt.Println("=== halo nostr full-stack probe (encrypt + ephemeral keys + fan-out) ===\n")

	// 1. two halos: alice + bob, each generates X25519
	aliceXPriv, aliceXPub := genX25519()
	bobXPriv, bobXPub := genX25519()
	fmt.Printf("alice X25519 pub: %s...\n", hex.EncodeToString(aliceXPub[:8]))
	fmt.Printf("bob X25519 pub:   %s...\n", hex.EncodeToString(bobXPub[:8]))

	// 2. ECDH shared secret (both compute the same)
	aliceShared := ecdh(aliceXPriv, bobXPub)
	bobShared := ecdh(bobXPriv, aliceXPub)
	if hex.EncodeToString(aliceShared) != hex.EncodeToString(bobShared) {
		fmt.Println("FAIL: ECDH shared secrets don't match")
		return
	}
	fmt.Printf("shared secret:    %s... ✓ (both peers derived identical)\n", hex.EncodeToString(aliceShared[:8]))

	// 3. conversation id (deterministic from both pubkeys)
	convID := conversationID(aliceXPub, bobXPub)
	fmt.Printf("conv id:          %s\n", hex.EncodeToString(convID))

	// 4. derive ephemeral nostr key from shared secret + conv id
	nostrSeed := deriveNostrSeed(aliceShared, convID)
	nostrSK := nostr.SecretKey(nostrSeed)
	nostrPK := nostrSK.Public()
	fmt.Printf("ephemeral nostr:  %s...\n", nostrPK.Hex()[:16])
	fmt.Println("  → relays see this disposable address, NOT alice/bob's identity")

	// 5. encrypt a real message with chacha20-poly1305 (placeholder for libsignal)
	msgKey := deriveMessageKey(aliceShared, convID)
	plaintext := []byte("hello bob, this is alice over halo+nostr+ephemeral keys")
	ciphertext, err := encrypt(msgKey, plaintext)
	if err != nil {
		fmt.Println("encrypt err:", err)
		return
	}
	fmt.Printf("\nencrypted msg:    %d bytes ciphertext\n", len(ciphertext))

	// 6. wrap in nostr event, sign with ephemeral key
	ev := nostr.Event{
		PubKey:    nostrPK,
		CreatedAt: nostr.Now(),
		Kind:      haloKind,
		Tags: nostr.Tags{
			{"d", hex.EncodeToString(convID)},
			{"halo", "v1"},
		},
		Content: hex.EncodeToString(ciphertext),
	}
	ev.Sign(nostrSK)
	fmt.Printf("nostr event id:   %s...\n", ev.ID.Hex()[:16])

	// 7. publish to 3 relays in parallel
	fmt.Println("\n--- publishing to 3 relays ---")
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	publishOK := publishMulti(ctx, relayURLs, ev)
	fmt.Printf("publish: %d/%d relays accepted\n", publishOK, len(relayURLs))
	if publishOK == 0 {
		fmt.Println("FAIL: no relays accepted")
		return
	}

	// 8. subscribe from 3 relays, dedupe, pick first
	fmt.Println("\n--- subscribing to 3 relays (dedupe by event id) ---")
	time.Sleep(2 * time.Second) // let the relays propagate
	got, ok := subscribeMulti(ctx, relayURLs, nostrPK, haloKind)
	if !ok {
		fmt.Println("FAIL: no relay returned the event")
		return
	}
	fmt.Println("subscribe: got event back from relay network")

	// 9. decrypt
	gotCipher, err := hex.DecodeString(got.Content)
	if err != nil {
		fmt.Println("hex decode err:", err)
		return
	}
	gotPlain, err := decrypt(msgKey, gotCipher)
	if err != nil {
		fmt.Println("decrypt err:", err)
		return
	}
	fmt.Printf("\ndecrypted: %q\n", gotPlain)

	if string(gotPlain) == string(plaintext) {
		fmt.Println("\n✓✓✓ FULL ROUNDTRIP OK")
		fmt.Println("encrypted halo message survived: ephemeral keys + 3-relay fan-out + retrieval + decrypt")
	} else {
		fmt.Println("FAIL: plaintext mismatch")
	}

	// suppress unused
	_ = sort.Strings
}
