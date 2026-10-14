// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the helper app mode, the engine's half. our relay knocks a unifiedpush
// endpoint when a wrap for an address registered with it arrives
// (relay-live/knock.go). the app picks which of its sixteen endpoints each
// address uses (helper_slots.dart); the engine lists the addresses with the
// group each one belongs to, and signs and sends the registrations.
//
// the app never sees an address: it gets an id, a keyed hash of it, and the
// groups are named the same way, so nothing it keeps in its settings names
// an address. the hidden chats' addresses are left out: the everyday side
// must not register what the vault holds.
//
// a registration is signed by the address's own key and goes to our relay
// only, over that address's lane, through tor's socks port whatever the
// route: a route switch in the middle of a batch ends the batch. a slot with
// no address gets a registration for a key that belongs to nothing, on a
// lane of its own.

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
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
	// how far back the app may date a registration
	knockBack = time.Hour
	// the capability check's own lane: it ties to nothing else
	laneKnockInfo = "knockinfo"
)

// the call's bound, the app waits a little longer (main.dart)
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
	// the peer behind a contact's address, for leaving hidden chats out
	peer string
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
				out = append(out, knockTarget{pk, sk, laneFirstContact, "firstcontact:" + pk, ""})
			}
		case isHexKey(k):
			peer, err := peerArr(k)
			if err != nil {
				continue
			}
			sk, pk, err := nip17RcvAddress(peer)
			if err == nil {
				lane := receiveLane(pk)
				out = append(out, knockTarget{pk, sk, lane, lane, strings.ToLower(k)})
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

// a keyed hash under this identity: the same every start, and it says
// nothing of what went in to whoever reads the app's settings
func knockID(s string) string {
	me, err := myXid()
	if err != nil {
		return ""
	}
	m := hmac.New(sha256.New, nostrHkdf(me.priv[:], nil, []byte("kryfo knock id"), 32))
	m.Write([]byte(s))
	return hex.EncodeToString(m.Sum(nil))[:32]
}

// the group as the app sees it: a contact lane by its number, the others by
// a keyed hash, keeping the kind
func knockGroupID(g string) string {
	if strings.HasPrefix(g, laneEveryday+":") {
		return g
	}
	kind := g
	if i := strings.IndexByte(g, ':'); i >= 0 {
		kind = g[:i]
	}
	return kind + ":" + knockID(g)[:16]
}

// the addresses listened on now, less the hidden chats' peers in exclude.
// by id
func knockLive(exclude []string) map[string]knockTarget {
	skip := map[string]bool{}
	for _, p := range exclude {
		skip[strings.ToLower(p)] = true
	}
	out := map[string]knockTarget{}
	for _, t := range knockTargets() {
		if t.peer != "" && skip[t.peer] {
			continue
		}
		id := knockID(t.pk)
		if id == "" {
			continue
		}
		out[id] = t
	}
	return out
}

// the addresses and their groups, as json: [{"i":id,"g":group}]. no
// address, no key. exclude: a json list of peers whose addresses stay out
//
//export HaloKnockAddresses
func HaloKnockAddresses(cExclude *C.char) *C.char {
	return C.CString(knockAddresses(goStr(cExclude)))
}

// the hidden chats' peers the app named last: their addresses are neither
// listed nor signed for, whatever an item asks
var (
	knockHiddenMu sync.Mutex
	knockHidden   []string
)

func knockAddresses(excludeJSON string) string {
	var exclude []string
	if json.Unmarshal([]byte(excludeJSON), &exclude) == nil {
		knockHiddenMu.Lock()
		knockHidden = exclude
		knockHiddenMu.Unlock()
	} else {
		// a list that cannot be read keeps the last one
		knockHiddenMu.Lock()
		exclude = knockHidden
		knockHiddenMu.Unlock()
	}
	type row struct {
		I string `json:"i"`
		G string `json:"g"`
	}
	rows := []row{}
	for id, t := range knockLive(exclude) {
		rows = append(rows, row{id, knockGroupID(t.group)})
	}
	slices.SortFunc(rows, func(a, b row) int { return strings.Compare(a.I, b.I) })
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
	// the address's id, or for a slot with none, the key that stands in
	I string `json:"i,omitempty"`
	K string `json:"k,omitempty"`
	S int    `json:"s,omitempty"`
	E string `json:"e"`
	// when to sign it, unix seconds: the app spreads a batch out so the
	// relay keeps no one second for unrelated lanes. now when unset, or
	// when ahead of now or more than knockBack before it
	T int64 `json:"t,omitempty"`
}

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

// a lane's client through tor's socks port, whatever the route: a route
// switch cannot hand a registration a direct client
func knockTorClient(lane string) (*http.Client, error) {
	key := "tor:" + lane
	cachedNostrClientMu.Lock()
	defer cachedNostrClientMu.Unlock()
	if c := cachedNostrClients[key]; c != nil {
		return c, nil
	}
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil {
		return nil, fmt.Errorf("tor not started")
	}
	d, err := torDialerAs(context.Background(), t, laneName(lane))
	if err != nil {
		return nil, fmt.Errorf("tor dialer: %v", err)
	}
	c := torLaneClient(d.DialContext)
	cachedNostrClients[key] = c
	return c, nil
}

// sends one registration to our relay on lane. a var for the tests
var knockPublish = func(ctx context.Context, lane string, ev nostr.Event) error {
	own := ownRelays(relaysWhenSet(ctx))
	if len(own) == 0 {
		return fmt.Errorf("no relay")
	}
	client, err := knockTorClient(lane)
	if err != nil {
		return err
	}
	var last error
	for _, u := range own {
		pctx, cancel := relayDialCtx(ctx, u)
		last = publishTo(pctx, lane, u, client, ev)
		cancel()
		if last == nil || strings.Contains(last.Error(), "duplicate:") {
			return last
		}
	}
	return last
}

// registers each item and answers {"done":[...],"dup":[...],"unknown":[...],
// "refused":[...]}: the ids, and "s<n>" for the slots without one, that our
// relay took, those it said were not newer than what it keeps, ids not
// listened on now or hidden, and those our relay refused for good (invalid,
// blocked). what went nowhere, tor down, the relay unreached, or a refusal
// for now (error, rate-limited), is in none.
// a registration needs the private route; a forget goes over tor on any
// route. both only for an address listened on now, on its lane as it is
// now: an address that is gone, a first-contact address replaced, a chat
// hidden, is never signed for again, its registration lapses
//
//export HaloKnockRegister
func HaloKnockRegister(cItems *C.char) *C.char {
	return C.CString(knockRegister(goStr(cItems)))
}

func knockRegister(raw string) string {
	// {"items":[...],"hidden":[...]}: the hidden chats named in the call
	// itself, so a register never runs on an older list. a bare list of
	// items uses the last one named
	var items []knockItem
	var call struct {
		Items  []knockItem `json:"items"`
		Hidden *[]string   `json:"hidden"`
	}
	if strings.HasPrefix(strings.TrimSpace(raw), "{") {
		if err := json.Unmarshal([]byte(raw), &call); err != nil {
			return "error: bad items"
		}
		items = call.Items
		if call.Hidden != nil {
			knockHiddenMu.Lock()
			knockHidden = *call.Hidden
			knockHiddenMu.Unlock()
		}
	} else if err := json.Unmarshal([]byte(raw), &items); err != nil {
		return "error: bad items"
	}
	mode := currentMode()
	routeC := routeEnded()
	private := modeNeedsTor()
	knockHiddenMu.Lock()
	hidden := knockHidden
	knockHiddenMu.Unlock()
	live := knockLive(hidden)
	ctx, cancel := context.WithTimeout(context.Background(), knockWait)
	defer cancel()
	now := time.Now()
	var (
		dmu       sync.Mutex
		done, dup = []string{}, []string{}
		unknown   = []string{}
		refused   = []string{}
		wg        sync.WaitGroup
		sem       = make(chan struct{}, knockParallel)
	)
	// the route the batch began on: anything not sent before it changes
	// stays unsent
	moved := func() bool { return currentMode() != mode || routeGone(routeC) }
	for _, it := range items {
		var sk, pk, lane, name string
		forget := it.E == ""
		switch {
		case it.I != "":
			t, ok := live[it.I]
			if !ok {
				unknown = append(unknown, it.I)
				continue
			}
			sk, pk, lane, name = t.sk, t.pk, t.lane, it.I
		case it.K != "" && it.S >= 0 && it.S < 64:
			p, err := nostr2.GetPublicKey(it.K)
			if err != nil {
				continue
			}
			sk, pk, lane, name = it.K, p, knockSlotLane(it.S), "s"+strconv.Itoa(it.S)
		default:
			continue
		}
		if !forget && !private {
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
			if moved() {
				return
			}
			err := knockPublish(ctx, lane, ev)
			dmu.Lock()
			defer dmu.Unlock()
			switch {
			case err == nil:
				done = append(done, name)
			case strings.Contains(err.Error(), "duplicate:"):
				dup = append(dup, name)
			case strings.HasPrefix(err.Error(), "msg: invalid:") || strings.HasPrefix(err.Error(), "msg: blocked:"):
				// the relay answered no, and will again
				refused = append(refused, name)
			default:
				log.Printf("knock: a registration on %s was not taken: %v", laneKind(lane), err)
			}
		}()
	}
	wg.Wait()
	slices.Sort(done)
	slices.Sort(dup)
	slices.Sort(unknown)
	slices.Sort(refused)
	b, _ := json.Marshal(map[string][]string{"done": done, "dup": dup, "unknown": unknown, "refused": refused})
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

// the check's client, on its own lane. a var for the tests
var knockInfoClient = func(ctx context.Context) (*http.Client, error) {
	for {
		c, err := knockTorClient(laneKnockInfo)
		if err == nil {
			return c, nil
		}
		select {
		case <-ctx.Done():
			return nil, err
		case <-time.After(servicesPoll):
		}
	}
}

// whether our relay can knock: "yes", "no", or why it could not be asked.
// the relay's info page, over tor, carries nothing about who asks
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
