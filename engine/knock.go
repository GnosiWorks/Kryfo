// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the helper app mode, the engine's half. our relay knocks a unifiedpush
// endpoint when a wrap for an address registered with it arrives
// (relay-live/knock.go). the app picks which of its sixteen endpoints each
// address uses (helper_slots.dart); the engine lists the addresses with the
// lane each one listens on, and signs and sends the registrations.
//
// a registration is signed by the address's own key and goes to our relay
// only, over the same lane, so over the same circuit, as the address's
// subscription. it never travels outside tor. a slot with no address gets
// a registration for a key that belongs to nothing, on a lane of its own.

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
)

import "C"

const (
	knockKind = 21059
	// what our relay's info lists once it can knock
	knockTag = "knock/1"
	// the most registrations sent at once, each on its lane's circuit
	knockParallel = 4
)

// the call's bound, the app waits a little longer (helper_push.dart)
var knockWait = 90 * time.Second

// an address the engine listens on, with what it takes to register it
type knockTarget struct {
	pk, sk string
	// the lane the registration goes out on
	lane string
	// what may share an endpoint: addresses the relay already sees over
	// one circuit. a first-contact address that is replaced listens on a
	// new circuit, so each one is a group of its own
	group string
}

// rooms' addresses, noted as they are subscribed: their keys are not
// derivable from the subscription's name. by subscription key
var (
	knockNotesMu sync.Mutex
	knockNotes   = map[string]knockTarget{}
)

func noteKnockTarget(key string, t knockTarget) {
	knockNotesMu.Lock()
	knockNotes[key] = t
	knockNotesMu.Unlock()
}

// every address listened on now, sorted by address
func knockTargets() []knockTarget {
	nostrMu.Lock()
	keys := make([]string, 0, len(nostrSubs))
	for k := range nostrSubs {
		keys = append(keys, k)
	}
	fc := fcCounterNow
	nostrMu.Unlock()
	live := map[string]bool{}
	var out []knockTarget
	knockNotesMu.Lock()
	for _, k := range keys {
		live[k] = true
		if t, ok := knockNotes[k]; ok {
			out = append(out, t)
		}
	}
	for k := range knockNotes {
		if !live[k] {
			delete(knockNotes, k)
		}
	}
	knockNotesMu.Unlock()
	for _, k := range keys {
		switch {
		case k == "firstcontact":
			sk, pk, err := nip17FirstContactKeys(fc)
			if err == nil {
				out = append(out, knockTarget{pk, sk, laneFirstContact, "firstcontact:" + pk})
			}
		case isHexKey(k):
			peer, err := peerArr(k)
			if err != nil {
				continue
			}
			sk, pk, err := nip17RcvAddress(peer)
			if err == nil {
				lane := receiveLane(pk)
				out = append(out, knockTarget{pk, sk, lane, lane})
			}
		}
	}
	slices.SortFunc(out, func(a, b knockTarget) int { return strings.Compare(a.pk, b.pk) })
	return slices.CompactFunc(out, func(a, b knockTarget) bool { return a.pk == b.pk })
}

func isHexKey(s string) bool {
	if len(s) != 64 {
		return false
	}
	_, err := hex.DecodeString(s)
	return err == nil
}

// the addresses and their groups, as json: [{"a":addr,"g":group}]. no keys
//
//export HaloKnockAddresses
func HaloKnockAddresses() *C.char {
	return C.CString(knockAddresses())
}

func knockAddresses() string {
	type row struct {
		A string `json:"a"`
		G string `json:"g"`
	}
	rows := []row{}
	for _, t := range knockTargets() {
		rows = append(rows, row{t.pk, t.group})
	}
	b, _ := json.Marshal(rows)
	return string(b)
}

// a registration: the endpoint for pk, or none to forget it
func knockEvent(sk, pk, endpoint string, at time.Time) (nostr.Event, error) {
	var out nostr.Event
	ev := nostr2.Event{
		Kind:      knockKind,
		CreatedAt: nostr2.Timestamp(at.Unix()),
		Tags:      nostr2.Tags{},
		Content:   endpoint,
	}
	if err := ev.Sign(sk); err != nil {
		return out, err
	}
	if ev.PubKey != pk {
		return out, fmt.Errorf("key does not match the address")
	}
	if err := easyjson.Unmarshal([]byte(ev.String()), &out); err != nil {
		return out, err
	}
	return out, nil
}

// one registration to send
type knockItem struct {
	// the address, or for a slot with none, the key that stands in
	A string `json:"a,omitempty"`
	K string `json:"k,omitempty"`
	S int    `json:"s,omitempty"`
	E string `json:"e"`
	// when to sign it, unix seconds: the app spreads a batch out so the
	// relay keeps no one second for unrelated lanes. now when unset, or
	// when ahead of now or more than knockBack before it
	T int64 `json:"t,omitempty"`
}

// how far back the app may date a registration
const knockBack = time.Hour

func (it knockItem) at(now time.Time) time.Time {
	if it.T <= 0 {
		return now
	}
	t := time.Unix(it.T, 0)
	if t.After(now) || now.Sub(t) > knockBack {
		return now
	}
	return t
}

// sends one registration to our relay on lane. a var for the tests
var knockPublish = func(ctx context.Context, lane string, ev nostr.Event) error {
	own := ownRelays(relaysWhenSet(ctx))
	if len(own) == 0 {
		return fmt.Errorf("no relay")
	}
	client, err := torNostrClientFor(lane)
	if err != nil {
		return err
	}
	var last error
	for _, u := range own {
		pctx, cancel := relayDialCtx(ctx, u)
		last = publishTo(pctx, lane, u, client, ev)
		cancel()
		if last == nil {
			return nil
		}
	}
	return last
}

// registers each item and answers {"done":[...]}: the addresses, and "s<n>"
// for the slots without one, that our relay took. an address not listened
// on now is left out
//
//export HaloKnockRegister
func HaloKnockRegister(cItems *C.char) *C.char {
	return C.CString(knockRegister(goStr(cItems)))
}

func knockRegister(raw string) string {
	if !modeNeedsTor() {
		return "error: only over tor"
	}
	var items []knockItem
	if err := json.Unmarshal([]byte(raw), &items); err != nil {
		return "error: bad items"
	}
	byPk := map[string]knockTarget{}
	for _, t := range knockTargets() {
		byPk[t.pk] = t
	}
	ctx, cancel := context.WithTimeout(context.Background(), knockWait)
	defer cancel()
	now := time.Now()
	var (
		dmu  sync.Mutex
		done = []string{}
		wg   sync.WaitGroup
		sem  = make(chan struct{}, knockParallel)
	)
	for _, it := range items {
		var sk, pk, lane, name string
		switch {
		case it.A != "":
			t, ok := byPk[it.A]
			if !ok {
				continue
			}
			sk, pk, lane, name = t.sk, t.pk, t.lane, t.pk
		case it.K != "" && it.S >= 0 && it.S < 64:
			p, err := nostr2.GetPublicKey(it.K)
			if err != nil {
				continue
			}
			sk, pk, lane, name = it.K, p, knockSlotLane(it.S), "s"+strconv.Itoa(it.S)
		default:
			continue
		}
		ev, err := knockEvent(sk, pk, it.E, it.at(now))
		if err != nil {
			continue
		}
		wg.Add(1)
		go func() {
			defer wg.Done()
			select {
			case sem <- struct{}{}:
			case <-ctx.Done():
				return
			}
			defer func() { <-sem }()
			if err := knockPublish(ctx, lane, ev); err != nil {
				log.Printf("knock: a registration on %s was not taken: %v", laneKind(lane), err)
				return
			}
			dmu.Lock()
			done = append(done, name)
			dmu.Unlock()
		}()
	}
	wg.Wait()
	slices.Sort(done)
	b, _ := json.Marshal(map[string][]string{"done": done})
	return string(b)
}

// a slot with no address registers on a lane of its own, apart from every
// address's and every other slot's
func knockSlotLane(slot int) string { return "knock:" + strconv.Itoa(slot) }

// the relay info's address for a relay url
func knockInfoURL(u string) (string, bool) {
	p, err := url.Parse(u)
	if err != nil || p.Host == "" {
		return "", false
	}
	switch p.Scheme {
	case "wss":
		p.Scheme = "https"
	case "ws":
		p.Scheme = "http"
	default:
		return "", false
	}
	p.Path, p.RawQuery, p.Fragment = "/", "", ""
	return p.String(), true
}

// the services lane's client, a var for the tests
var knockInfoClient = func(ctx context.Context) (*http.Client, error) { return servicesClient(ctx) }

// whether our relay can knock: "yes", "no", or why it could not be asked.
// the relay's info page, over tor on the services lane, carries nothing
// about who asks
//
//export HaloKnockCheck
func HaloKnockCheck() *C.char { return C.CString(knockCheck()) }

func knockCheck() string {
	ctx, cancel := context.WithTimeout(context.Background(), knockWait)
	defer cancel()
	own := ownRelays(relaysWhenSet(ctx))
	if len(own) == 0 {
		return "error: no relay"
	}
	client, err := knockInfoClient(ctx)
	if err != nil {
		return "error: " + err.Error()
	}
	last := "error: no answer"
	for _, u := range own {
		info, ok := knockInfoURL(u)
		if !ok {
			continue
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, info, nil)
		if err != nil {
			continue
		}
		req.Header.Set("Accept", "application/nostr+json")
		req.Header.Set("User-Agent", "")
		resp, err := client.Do(req)
		if err != nil {
			last = "error: " + err.Error()
			continue
		}
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			last = "error: " + resp.Status
			continue
		}
		var doc struct {
			Tags []string `json:"tags"`
		}
		if json.Unmarshal(body, &doc) != nil {
			last = "error: bad relay info"
			continue
		}
		if slices.Contains(doc.Tags, knockTag) {
			return "yes"
		}
		return "no"
	}
	return last
}
