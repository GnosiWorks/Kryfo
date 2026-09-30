// SPDX-License-Identifier: GPL-3.0-or-later
package main

// six digit pairing codes, read out loud and typed on the other phone. both
// sides derive the same keypair from the code alone: the person sharing
// publishes their invite encrypted to it, the person joining reads it.
//
// the joiner takes an invite only when the code's address holds exactly one
// event across the relays that answer, and the app then shows its three
// words to be matched against the sharer's screen before anything is added.
// the window is short because an address nobody is listening to is not worth
// publishing to.

import (
	"context"
	"encoding/hex"
	"fmt"
	"log"
	"math"
	"strconv"
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
	return C.CString(pairCodePublish(C.GoString(cCode), C.GoString(cPayload)))
}

// how long an invite stays at a code: the expiration the sharer stamps on it
const pairCodeLife = 10 * time.Minute

func pairCodePublish(code, payload string) string {
	out, pk, err := pairCodeEvent(code, payload, time.Now())
	if err != nil {
		return "error: " + err.Error()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	ok := nostrPublishMulti(ctx, pairLane(pk), out)
	if ok == 0 {
		return "error: no relays accepted"
	}
	log.Printf("paircode: published to %d relays, addr %s...", ok, pk[:12])
	return "ok"
}

// the event that puts payload at the code's address, made at now, and the
// address itself
func pairCodeEvent(code, payload string, now time.Time) (nostr.Event, string, error) {
	var out nostr.Event
	sk, pk, err := pairCodeKeys(code)
	if err != nil {
		return out, "", err
	}
	ck, err := nip44.GenerateConversationKey(pk, sk)
	if err != nil {
		return out, "", fmt.Errorf("key: %v", err)
	}
	ct, err := nip44.Encrypt(payload, ck)
	if err != nil {
		return out, "", fmt.Errorf("encrypt: %v", err)
	}
	// signed with a key made for this event alone, which only the sharer's
	// phone ever holds
	author := nostr2.GeneratePrivateKey()
	if author == "" {
		return out, "", fmt.Errorf("sign: no key")
	}
	ev := nostr2.Event{
		Kind:      1059,
		CreatedAt: nostr2.Timestamp(now.Unix()),
		Content:   ct,
		Tags: nostr2.Tags{
			{"p", pk},
			{"expiration", fmt.Sprintf("%d", now.Add(pairCodeLife).Unix())},
		},
	}
	if err := ev.Sign(author); err != nil {
		return out, "", fmt.Errorf("sign: %v", err)
	}
	if err := easyjson.Unmarshal([]byte(ev.String()), &out); err != nil {
		return out, "", fmt.Errorf("convert: %v", err)
	}
	return out, pk, nil
}

// how long the joiner keeps listening once the first event turns up at a
// code, for the relays that have not answered yet
var pairCollectWindow = 3 * time.Second

// how many events one relay is asked for at a code. a relay sends the
// newest first and stops here, so an answer this long may have left older
// ones out, and the code is refused
const pairQueryLimit = 100

// what one relay sent, and which one by its place in the list: an event, or
// nil once it has sent everything it holds (or could not be asked)
type pairAnswer struct {
	from int
	ev   *nostr.Event
}

// ask every relay at once and keep everything they hold at the address. a
// one-shot lookup, not a subscription: the caller polls while the screen is
// open. it ends once every relay has answered, a few seconds after the first
// event, or at the deadline, whichever comes first. full is true, and it ends
// at once, when one relay's answer reaches pairQueryLimit.
func pairCodeQuery(ctx context.Context, pk string) (got []nostr.Event, full bool) {
	nostrMu.Lock()
	urls := append([]string(nil), nostrRelays...)
	nostrMu.Unlock()
	if len(urls) == 0 {
		return nil, false
	}

	qctx, cancel := context.WithCancel(ctx)
	defer cancel()
	out := make(chan pairAnswer)
	since := nostr.Timestamp(time.Now().Add(-pairCodeLife - time.Minute).Unix())

	for i, u := range urls {
		go func(i int, u string) {
			// every relay reports done exactly once, after its events
			done := func() {
				select {
				case out <- pairAnswer{from: i}:
				case <-qctx.Done():
				}
			}
			client, err := torNostrClientFor(pairLane(pk))
			if err != nil {
				done()
				return
			}
			r := nostr.NewRelay(qctx, u, nostr.RelayOptions{})
			dctx, dcancel := relayDialCtx(qctx, u)
			err = r.ConnectWithClient(dctx, client)
			dcancel()
			if err != nil {
				done()
				return
			}
			defer r.Close()
			sub, err := r.Subscribe(qctx, nostr.Filter{
				Kinds: []nostr.Kind{1059},
				Tags:  nostr.TagMap{"p": []string{pk}},
				Since: since,
				Limit: pairQueryLimit,
			}, nostr.SubscriptionOptions{
				// the end of stored events comes from the relay or not at
				// all: a made-up one would cut its answer short
				MaxWaitForEOSE: time.Duration(math.MaxInt64),
			})
			if err != nil {
				done()
				return
			}
			eosed := false
			for {
				select {
				case ev, alive := <-sub.Events:
					if !alive {
						if !eosed {
							done()
						}
						return
					}
					// never dropped: a second invite is exactly what this is for
					select {
					case out <- pairAnswer{i, &ev}:
					case <-qctx.Done():
						return
					}
				case <-sub.EndOfStoredEvents:
					// stored events all come before this. the socket stays
					// open, so an invite that lands while others answer
					// still counts
					if !eosed {
						eosed = true
						done()
					}
				case <-qctx.Done():
					return
				}
			}
		}(i, u)
	}

	sent := make([]int, len(urls))
	pending := len(urls)
	deadline := time.NewTimer(12 * time.Second)
	defer deadline.Stop()
	var window <-chan time.Time
	for {
		select {
		case a := <-out:
			if a.ev == nil {
				pending--
				if pending == 0 {
					return got, false
				}
				continue
			}
			got = append(got, *a.ev)
			if sent[a.from]++; sent[a.from] >= pairQueryLimit {
				return got, true
			}
			if window == nil {
				window = time.After(pairCollectWindow)
			}
		case <-window:
			return got, false
		case <-deadline.C:
			return got, false
		case <-ctx.Done():
			return got, false
		}
	}
}

// an event still inside its life at a code: not past the expiration the
// sharer stamped on it, and not older than any invite can be
func pairCodeLive(ev nostr.Event, now time.Time) bool {
	if ev.CreatedAt.Time().Before(now.Add(-pairCodeLife - time.Minute)) {
		return false
	}
	if tg := ev.Tags.Find("expiration"); len(tg) > 1 {
		if exp, err := strconv.ParseInt(tg[1], 10, 64); err == nil && exp < now.Unix() {
			return false
		}
	}
	return true
}

// look for an invite at the address the code names. returns the payload,
// "empty" when nothing is there yet, since the other person may not have
// pressed share, or "twice" when the relays that answer hold more than one
// event there, or one answer is as long as a relay sends: a share is one
// event, copied to each relay, and a code that points at two people points
// at nobody.
//
//export HaloPairCodeFetch
func HaloPairCodeFetch(cCode *C.char) *C.char {
	return C.CString(pairCodeFetch(C.GoString(cCode)))
}

func pairCodeFetch(code string) string {
	sk, pk, err := pairCodeKeys(code)
	if err != nil {
		return "error: " + err.Error()
	}
	ck, err := nip44.GenerateConversationKey(pk, sk)
	if err != nil {
		return fmt.Sprintf("error: key: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	evs, full := pairCodeQuery(ctx, pk)
	if full {
		log.Printf("paircode: a full answer at %s..., none taken", pk[:12])
		return "twice"
	}
	now := time.Now()
	// counted by id, not by what it says: the same invite in a second event
	// is a second event
	ids := map[nostr.ID]bool{}
	var one nostr.Event
	for _, ev := range evs {
		if !pairCodeLive(ev, now) {
			continue
		}
		ids[ev.ID] = true
		one = ev
	}
	switch len(ids) {
	case 0:
		return "empty"
	case 1:
		pt, err := nip44.Decrypt(one.Content, ck)
		if err != nil {
			return "empty"
		}
		log.Printf("paircode: found an invite at %s...", pk[:12])
		return pt
	}
	log.Printf("paircode: %d events at %s..., none taken", len(ids), pk[:12])
	return "twice"
}
