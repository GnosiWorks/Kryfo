// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a wrap is stamped up to six hours back when it is made, and readers ask
// each store for twelve hours behind what they have. a wrap that reaches a
// store hours late is stamped below that, and nobody asks for it there. so
// the seal inside each wrap this phone makes is kept a while, and a late
// top-up goes out as a fresh wrap around the same seal: a new id and a new
// stamp, the same message, which the app knows twice by its uid.

import (
	"fmt"
	"math/rand"
	"sync"

	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
)

// what a wrap needs to be made again: its seal, who it is for, and its
// tags past the p, the expiration among them
type keptSeal struct {
	Seal string      `json:"s"`
	To   string      `json:"t"`
	Tags nostr2.Tags `json:"g,omitempty"`
}

// the seals of the wraps made lately, by the wrap's id, in memory only
var (
	keptMu    sync.Mutex
	keptSeals = map[string]keptSeal{}
)

const keptMax = 4096

func keepSeal(id string, k keptSeal) {
	keptMu.Lock()
	defer keptMu.Unlock()
	if len(keptSeals) >= keptMax {
		keptSeals = map[string]keptSeal{}
	}
	keptSeals[id] = k
}

func keptSealOf(id string) (keptSeal, bool) {
	keptMu.Lock()
	defer keptMu.Unlock()
	k, ok := keptSeals[id]
	return k, ok
}

// nip59.GiftWrap, with the seal kept for a fresh wrap later
func giftWrapKept(rumor nostr2.Event, recipient string,
	encrypt func(string) (string, error), sign func(*nostr2.Event) error,
	modify func(*nostr2.Event)) (nostr2.Event, error) {
	rumor.Sig = ""
	ct, err := encrypt(rumor.String())
	if err != nil {
		return nostr2.Event{}, err
	}
	seal := nostr2.Event{
		Kind:      nostr2.KindSeal,
		Content:   ct,
		CreatedAt: nostr2.Now() - nostr2.Timestamp(60*rand.Int63n(600)),
		Tags:      make(nostr2.Tags, 0),
	}
	if err := sign(&seal); err != nil {
		return nostr2.Event{}, err
	}
	gw, err := wrapSeal(seal.String(), recipient, nil, modify)
	if err != nil {
		return nostr2.Event{}, err
	}
	var extra nostr2.Tags
	for _, tag := range gw.Tags {
		if len(tag) > 0 && tag[0] != "p" {
			extra = append(extra, tag)
		}
	}
	keepSeal(gw.ID, keptSeal{Seal: seal.String(), To: recipient, Tags: extra})
	return gw, nil
}

// the outer wrap around a seal: a key of its own, a stamp up to six hours
// back as nip-59 has it, the recipient's p and the tags given
func wrapSeal(sealJSON, recipient string, tags nostr2.Tags, modify func(*nostr2.Event)) (nostr2.Event, error) {
	nonce := nostr2.GeneratePrivateKey()
	ck, err := nip44.GenerateConversationKey(recipient, nonce)
	if err != nil {
		return nostr2.Event{}, err
	}
	ct, err := nip44.Encrypt(sealJSON, ck)
	if err != nil {
		return nostr2.Event{}, err
	}
	gw := nostr2.Event{
		Kind:      nostr2.KindGiftWrap,
		Content:   ct,
		CreatedAt: nostr2.Now() - nostr2.Timestamp(60*rand.Int63n(600)),
		Tags:      append(nostr2.Tags{{"p", recipient}}, tags...),
	}
	if modify != nil {
		modify(&gw)
	}
	if err := gw.Sign(nonce); err != nil {
		return nostr2.Event{}, err
	}
	return gw, nil
}

// a fresh wrap around a kept seal, for the relay library
func rewrap(k keptSeal) (nostr.Event, error) {
	gw, err := wrapSeal(k.Seal, k.To, k.Tags, nil)
	if err != nil {
		return nostr.Event{}, err
	}
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		return nostr.Event{}, fmt.Errorf("wrap convert: %v", err)
	}
	// our own subscription does not hand it back
	nostrMu.Lock()
	nostrSentIDs[ev.ID.Hex()] = true
	nostrMu.Unlock()
	return ev, nil
}
