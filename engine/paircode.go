// SPDX-License-Identifier: GPL-3.0-or-later
package main

// six digit pairing codes. someone reads a number out and the other person
// types it - across a table, down a phone line, in a room where holding two
// phones together is awkward.
//
// both sides derive the same keypair from the code alone. the person sharing
// publishes their invite encrypted to that key; the person joining subscribes
// to it and reads what lands. no server knows either of them, and the relay
// sees one more sealed blob.
//
// six digits is a million combinations and there is no rate limit on a public
// relay, so a determined watcher can enumerate the space. what they get is an
// invite - the thing you were about to read out loud anyway. it is not a
// secret, it is an introduction, and the request inbox plus proof of work is
// what actually gates a stranger. the code exists so the right person finds
// you quickly, not so the wrong one cannot.
//
// the window is short for the same reason: an address nobody is listening to
// is not worth publishing to.

import (
	"context"
	"encoding/hex"
	"fmt"
	"log"
	"sync"
	"time"

	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
)

import "C"

const pairCodeInfo = "kryfo-paircode-v1:"

// the code alone decides the keypair, so both phones land on the same one
// without having exchanged anything first.
func pairCodeKeys(code string) (sk, pk string, err error) {
	if len(code) != 6 {
		return "", "", fmt.Errorf("a pairing code is six digits")
	}
	for ctr := 0; ctr < 4; ctr++ {
		seed := nostrHkdf(
			[]byte(pairCodeInfo+code),
			nil,
			[]byte(fmt.Sprintf("%s%d", pairCodeInfo, ctr)),
			32,
		)
		sk = hex.EncodeToString(seed)
		if pk, err = nostr2.GetPublicKey(sk); err == nil {
			return sk, pk, nil
		}
	}
	return "", "", fmt.Errorf("pair code derive failed")
}

// put an invite at the address the code names. encrypted to the derived key,
// so it is readable by whoever has the code and nobody else, and stamped to
// expire in ten minutes.
//
//export HaloPairCodePublish
func HaloPairCodePublish(cCode, cPayload *C.char) *C.char {
	code := C.GoString(cCode)
	payload := C.GoString(cPayload)

	sk, pk, err := pairCodeKeys(code)
	if err != nil {
		return C.CString("error: " + err.Error())
	}

	ck, err := nip44.GenerateConversationKey(pk, sk)
	if err != nil {
		return C.CString(fmt.Sprintf("error: key: %v", err))
	}
	ct, err := nip44.Encrypt(payload, ck)
	if err != nil {
		return C.CString(fmt.Sprintf("error: encrypt: %v", err))
	}

	exp := fmt.Sprintf("%d", time.Now().Add(10*time.Minute).Unix())
	ev := nostr2.Event{
		Kind:      1059,
		CreatedAt: nostr2.Now(),
		Content:   ct,
		Tags: nostr2.Tags{
			{"p", pk},
			{"expiration", exp},
		},
	}
	if err := ev.Sign(sk); err != nil {
		return C.CString(fmt.Sprintf("error: sign: %v", err))
	}

	var out nostr.Event
	if err := easyjson.Unmarshal([]byte(ev.String()), &out); err != nil {
		return C.CString(fmt.Sprintf("error: convert: %v", err))
	}

	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	ok := nostrPublishMulti(ctx, out)
	if ok == 0 {
		return C.CString("error: no relays accepted")
	}
	log.Printf("paircode: published to %d relays, addr %s...", ok, pk[:12])
	return C.CString("ok")
}

// ask every relay at once and take whatever comes back first. this is a
// one-shot lookup, not a subscription - the caller polls while the screen is
// open and stops when it closes.
func pairCodeQuery(ctx context.Context, pk string) []nostr.Event {
	nostrMu.Lock()
	urls := append([]string(nil), nostrRelays...)
	nostrMu.Unlock()

	out := make(chan nostr.Event, 16)
	done := make(chan struct{})
	var wg sync.WaitGroup

	for _, u := range urls {
		wg.Add(1)
		go func(u string) {
			defer wg.Done()
			client, err := torNostrClient()
			if err != nil {
				return
			}
			r := nostr.NewRelay(ctx, u, nostr.RelayOptions{})
			if err := r.ConnectWithClient(ctx, client); err != nil {
				return
			}
			defer r.Close()
			sub, err := r.Subscribe(ctx, nostr.Filter{
				Kinds: []nostr.Kind{1059},
				Tags:  nostr.TagMap{"p": []string{pk}},
				Limit: 5,
			}, nostr.SubscriptionOptions{})
			if err != nil {
				return
			}
			for {
				select {
				case ev, alive := <-sub.Events:
					if !alive {
						return
					}
					select {
					case out <- ev:
					default:
					}
				case <-done:
					return
				case <-ctx.Done():
					return
				}
			}
		}(u)
	}

	go func() { wg.Wait(); close(out) }()

	var got []nostr.Event
	deadline := time.After(12 * time.Second)
	for {
		select {
		case ev, alive := <-out:
			if !alive {
				close(done)
				return got
			}
			got = append(got, ev)
			// one is enough; the code only ever points at one invite
			close(done)
			return got
		case <-deadline:
			close(done)
			return got
		case <-ctx.Done():
			close(done)
			return got
		}
	}
}

// look for an invite at the address the code names. returns the payload, or
// "empty" when nothing is there yet - the caller polls, because the other
// person may not have pressed share.
//
//export HaloPairCodeFetch
func HaloPairCodeFetch(cCode *C.char) *C.char {
	code := C.GoString(cCode)

	sk, pk, err := pairCodeKeys(code)
	if err != nil {
		return C.CString("error: " + err.Error())
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	evs := pairCodeQuery(ctx, pk)
	if len(evs) == 0 {
		return C.CString("empty")
	}

	ck, err := nip44.GenerateConversationKey(pk, sk)
	if err != nil {
		return C.CString(fmt.Sprintf("error: key: %v", err))
	}
	// newest first; an old code reused by someone else would otherwise win
	for i := len(evs) - 1; i >= 0; i-- {
		pt, err := nip44.Decrypt(evs[i].Content, ck)
		if err != nil {
			continue
		}
		log.Printf("paircode: found an invite at %s...", pk[:12])
		return C.CString(pt)
	}
	return C.CString("empty")
}
