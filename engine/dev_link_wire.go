// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"sort"
	"time"

	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
)

// a link's rendezvous on the relays. each direction is one key made from
// the offer: its events are signed by it and sealed to itself, so only who
// holds the offer can put one there or read one. the reader takes nothing
// else: an event by any other author, or sealed under any other
// conversation, is not the link's

const linkInfo = "kryfo-link-rendezvous-v1:"

// the nostr key of a rendezvous seed
func linkKeys(seed [32]byte) (sk, pk string, err error) {
	for ctr := 0; ctr < 4; ctr++ {
		k := seed[:]
		if ctr > 0 {
			k = nostrHkdf(seed[:], nil, []byte(fmt.Sprintf("%s%d", linkInfo, ctr)), 32)
		}
		sk = hex.EncodeToString(k)
		if pk, err = nostr2.GetPublicKey(sk); err == nil {
			return sk, pk, nil
		}
	}
	return "", "", errors.New("link key derive failed")
}

// the event that puts msg at seed's address, made at now
func linkEvent(seed [32]byte, msg []byte, now time.Time) (nostr.Event, string, error) {
	var out nostr.Event
	sk, pk, err := linkKeys(seed)
	if err != nil {
		return out, "", err
	}
	ck, err := nip44.GenerateConversationKey(pk, sk)
	if err != nil {
		return out, "", err
	}
	ct, err := nip44.Encrypt(base64.StdEncoding.EncodeToString(msg), ck)
	if err != nil {
		return out, "", err
	}
	ev := nostr2.Event{
		Kind:      1059,
		CreatedAt: nostr2.Timestamp(now.Unix()),
		Content:   ct,
		Tags: nostr2.Tags{
			{"p", pk},
			{"expiration", fmt.Sprintf("%d", now.Add(15*time.Minute).Unix())},
		},
	}
	if err := ev.Sign(sk); err != nil {
		return out, "", err
	}
	if err := easyjson.Unmarshal([]byte(ev.String()), &out); err != nil {
		return out, "", err
	}
	return out, pk, nil
}

// the link message in ev, when ev is the link's own at seed's address
func linkEventOpen(seed [32]byte, ev nostr.Event) ([]byte, bool) {
	sk, pk, err := linkKeys(seed)
	if err != nil || ev.PubKey.Hex() != pk || !ev.CheckID() || !ev.VerifySignature() {
		return nil, false
	}
	if tg := ev.Tags.Find("p"); len(tg) < 2 || tg[1] != pk {
		return nil, false
	}
	ck, err := nip44.GenerateConversationKey(pk, sk)
	if err != nil {
		return nil, false
	}
	pt, err := nip44.Decrypt(ev.Content, ck)
	if err != nil {
		return nil, false
	}
	b, err := base64.StdEncoding.DecodeString(pt)
	if err != nil || len(b) < 4 {
		return nil, false
	}
	return b, true
}

// the link's own events among evs, oldest first, each once
func linkMessages(seed [32]byte, evs []nostr.Event) [][]byte {
	sort.SliceStable(evs, func(i, j int) bool { return evs[i].CreatedAt < evs[j].CreatedAt })
	seen := map[string]bool{}
	var out [][]byte
	for _, ev := range evs {
		m, ok := linkEventOpen(seed, ev)
		if !ok || seen[string(m)] {
			continue
		}
		seen[string(m)] = true
		out = append(out, m)
	}
	return out
}

type relayLinkWire struct{}

func (relayLinkWire) post(ctx context.Context, seed [32]byte, msg []byte) error {
	ev, pk, err := linkEvent(seed, msg, time.Now())
	if err != nil {
		return err
	}
	pctx, cancel := context.WithTimeout(ctx, publishWait)
	defer cancel()
	if nostrPublishMulti(pctx, linkLane(pk), ev) == 0 {
		return errLinkUnreached
	}
	return nil
}

func (relayLinkWire) fetch(ctx context.Context, seed [32]byte) ([][]byte, error) {
	_, pk, err := linkKeys(seed)
	if err != nil {
		return nil, err
	}
	got, _, heard := pairCodeQuery(ctx, pairLane(pk), []string{pk})
	if heard == 0 {
		return nil, errLinkUnreached
	}
	return linkMessages(seed, got), nil
}

func linkLane(pk string) string { return "link:" + pk }

// a line to the phone's door, over tor
func dialLinkDoor(ctx context.Context, onion, line string) error {
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil {
		return errLinkUnreached
	}
	// the run bounds the stream by its own keep wait
	return sendOneLineBy(ctx, t, onion+".onion", line)
}
