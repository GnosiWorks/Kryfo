// nostr roundtrip probe: two local identities, ECDH, a per-conversation
// ephemeral key, one message published to three public relays and read back.
// relays see a disposable pubkey that cannot be linked to either identity.

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
				fmt.Printf("fail %s connect: %v\n", u, err)
				return
			}
			defer r.Close()
			if err := r.Publish(rctx, ev); err != nil {
				fmt.Printf("fail %s publish: %v\n", u, err)
				return
			}
			fmt.Printf("ok %s published\n", u)
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
				fmt.Printf("fail %s connect: %v\n", u, err)
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
				fmt.Printf("fail %s subscribe: %v\n", u, err)
				return
			}
			select {
			case ev := <-sub.Events:
				if ev.ID.Hex() != "" {
					fmt.Printf("ok %s got the event\n", u)
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

func main() {
	fmt.Println("nostr probe: encrypt, throwaway key, three relays")
	fmt.Println()

	// two identities, each with an x25519 key
	aliceXPriv, aliceXPub := genX25519()
	bobXPriv, bobXPub := genX25519()
	fmt.Printf("alice X25519 pub: %s...\n", hex.EncodeToString(aliceXPub[:8]))
	fmt.Printf("bob X25519 pub:   %s...\n", hex.EncodeToString(bobXPub[:8]))

	// both sides derive the same secret
	aliceShared := ecdh(aliceXPriv, bobXPub)
	bobShared := ecdh(bobXPriv, aliceXPub)
	if hex.EncodeToString(aliceShared) != hex.EncodeToString(bobShared) {
		fmt.Println("fail: the shared secrets don't match")
		return
	}
	fmt.Printf("shared secret:    %s... (same on both sides)\n", hex.EncodeToString(aliceShared[:8]))

	// the conversation id, from both public keys
	convID := conversationID(aliceXPub, bobXPub)
	fmt.Printf("conv id:          %s\n", hex.EncodeToString(convID))

	// a throwaway nostr key from the secret and the conversation id
	nostrSeed := deriveNostrSeed(aliceShared, convID)
	nostrSK := nostr.SecretKey(nostrSeed)
	nostrPK := nostrSK.Public()
	fmt.Printf("ephemeral nostr:  %s...\n", nostrPK.Hex()[:16])
	fmt.Println("relays see this address, not either identity")

	// chacha20-poly1305 stands in for libsignal here
	msgKey := deriveMessageKey(aliceShared, convID)
	plaintext := []byte("hello bob, this is alice over halo+nostr+ephemeral keys")
	ciphertext, err := encrypt(msgKey, plaintext)
	if err != nil {
		fmt.Println("encrypt err:", err)
		return
	}
	fmt.Printf("\nencrypted msg:    %d bytes ciphertext\n", len(ciphertext))

	// a nostr event signed with the throwaway key
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

	fmt.Println("\npublishing to 3 relays")
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	publishOK := publishMulti(ctx, relayURLs, ev)
	fmt.Printf("publish: %d/%d relays accepted\n", publishOK, len(relayURLs))
	if publishOK == 0 {
		fmt.Println("fail: no relays accepted")
		return
	}

	fmt.Println("\nsubscribing to 3 relays, first event wins")
	time.Sleep(2 * time.Second) // let the relays propagate
	got, ok := subscribeMulti(ctx, relayURLs, nostrPK, haloKind)
	if !ok {
		fmt.Println("fail: no relay returned the event")
		return
	}
	fmt.Println("subscribe: got event back from relay network")

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
		fmt.Println("\nroundtrip ok")
		fmt.Println("the message came back through the relays and decrypted")
	} else {
		fmt.Println("fail: plaintext mismatch")
	}

	_ = sort.Strings
}
