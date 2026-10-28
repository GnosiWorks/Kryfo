// SPDX-License-Identifier: GPL-3.0-or-later
package main

// our relays are two boxes at two companies, and each is a store of its
// own: a wrap one took the other may never have got. so each store keeps
// its own catch-up anchor and holds, and a pass on one never lets the other
// go. the entries of one store, an onion and a clearnet name, are ways into
// the same store. the fast route reads and writes both: the first to take a
// send ends the wait, the first copy to come is the one shown.

import (
	"context"
	"log"
	mrand "math/rand/v2"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"fiatjaf.com/nostr"
)

const (
	storeFirst  = "1"
	storeSecond = "2"
)

// the second store's clearnet name. a var so tests can point it at a
// stand-in
var secondRelayHost = "relay2.kryfo.app"

// our stores' onions. a relay is ours by its name alone, never by where it
// sits in a list: one that is not ours is never dialled in the clear
var (
	ownOnionHost    = "z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion"
	secondOnionHost = "cvwpee5zgbargtxd5wtbtnc6lkbgzxj5byfig3e53ic4t7su7r45n4yd.onion"
)

// the day the second store went live, 2026-10-28 00:00 utc: it holds nothing
// older, so its first walk starts there and not fourteen days back
const secondLiveAt = 1793145600

// the second store's first walks spread over this. a var for the tests
var secondFirstSpread = time.Minute

func secondFirstWalk() time.Duration {
	return time.Duration(mrand.Int64N(int64(secondFirstSpread) + 1))
}

// the store u reaches, "" for a relay that is not ours. by its name; an
// onion first in the list is the first store too, as an onion is reached
// through tor alone and nothing about it can go in the clear
func storeOf(urls []string, u string) string {
	switch {
	case relayHostIs(u, secondRelayHost), relayHostIs(u, secondOnionHost):
		return storeSecond
	case relayHostIs(u, ownRelayHost), relayHostIs(u, ownOnionHost), otherFirstHost(u):
		return storeFirst
	case len(urls) > 0 && urls[0] == u && isOnion(u):
		return storeFirst
	}
	return ""
}

// more names of the first store, for the tests' stand-ins. none in the app
var otherFirstHosts sync.Map

func otherFirstHost(u string) bool {
	p, err := url.Parse(u)
	if err != nil {
		return false
	}
	_, ok := otherFirstHosts.Load(strings.ToLower(p.Host))
	return ok
}

func isOnion(u string) bool {
	p, err := url.Parse(u)
	return err == nil && strings.HasSuffix(strings.ToLower(p.Hostname()), ".onion")
}

// the stores named in urls, the first one first
func storesIn(urls []string) []string {
	var out []string
	for _, u := range urls {
		if st := storeOf(urls, u); st != "" && !containsStr(out, st) {
			out = append(out, st)
		}
	}
	return out
}

func containsStr(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}

// the entries of store st in urls
func storeEntries(urls []string, st string) []string {
	var out []string
	for _, u := range urls {
		if storeOf(urls, u) == st {
			out = append(out, u)
		}
	}
	return out
}

// the first entry of its store: it carries that store's traffic, so it is
// healed hard. the clearnet name of a store that also has an onion is not
func storeLead(urls []string, u string) bool {
	st := storeOf(urls, u)
	if st == "" {
		return false
	}
	es := storeEntries(urls, st)
	return len(es) > 0 && es[0] == u
}

// a store's entries for an address, as catch-up keys
func storeCatchupKeys(urls []string, st, rcvPk string) []string {
	var keys []string
	for _, u := range storeEntries(urls, st) {
		keys = append(keys, catchupKey(u, rcvPk))
	}
	return keys
}

// where a store keeps an address's anchor. the first store's file is the
// one every version before had
func storeLastPath(lastPath, st string) string {
	if lastPath == "" || st == storeFirst {
		return lastPath
	}
	return lastPath + "." + st
}

// a store answers lately: an entry of it was up within ownUpRecent and has
// not failed since. relayHealthMu must be held
func storeUpLocked(urls []string, st, except string) bool {
	for _, o := range storeEntries(urls, st) {
		if o == except || relayFails[o] > 0 {
			continue
		}
		if at, ok := relayUpAt[o]; ok && time.Since(at) < ownUpRecent {
			return true
		}
	}
	return false
}

// while the other store answers, a store that is down is not waited on:
// it comes back within this, not every few seconds from every runner
const otherStoreCeiling = 2 * time.Minute

// closed when none of our stores answers any more, so a runner of ours
// napping out a long backoff dials at once: the store that was benched
// while the other carried is the way in now
var (
	oursGoneMu sync.Mutex
	oursGoneC  = make(chan struct{})
)

func oursGoneChan() chan struct{} {
	oursGoneMu.Lock()
	defer oursGoneMu.Unlock()
	return oursGoneC
}

func oursGoneWake() {
	oursGoneMu.Lock()
	close(oursGoneC)
	oursGoneC = make(chan struct{})
	oursGoneMu.Unlock()
}

// u of ours failed. when no store answers now, every entry of ours is let
// off the long wait it was given while another store carried, and its
// runners are woken. relayHealthMu must be held; true when they must be
func oursAllGoneLocked(urls []string, u string) bool {
	if storeOf(urls, u) == "" || len(storesIn(urls)) < 2 {
		return false
	}
	for _, st := range storesIn(urls) {
		if storeUpLocked(urls, st, u) {
			return false
		}
	}
	now := time.Now()
	woke := false
	for _, o := range ownRelays(urls) {
		if till, ok := relayCoolTill[o]; ok && till.Sub(now) > ownRelayCeiling {
			relayCoolTill[o] = now.Add(ownSpread(ownRelayCeiling))
			woke = true
		}
	}
	return woke
}

// woken because none of ours answers, a runner waits up to this first, so
// every socket of ours does not redial in one instant. a var for the tests
var goneSpread = 3 * time.Second

// sleeps d, over early on a kick, on ours all gone when own, or with ctx
func napFor(ctx context.Context, d time.Duration, own bool) {
	kc := kickChan()
	var gone chan struct{}
	if own {
		gone = oursGoneChan()
	}
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
	case <-kc:
	case <-gone:
		spread := time.NewTimer(time.Duration(mrand.Int64N(int64(goneSpread) + 1)))
		defer spread.Stop()
		select {
		case <-spread.C:
		case <-ctx.Done():
		}
	case <-ctx.Done():
	}
}

// the round trip each relay showed last: its socket opening, a send taken,
// a probe answered. what the details page shows, and how the quicker store
// is told
var (
	relayMsMu sync.Mutex
	relayMs   = map[string]int{}
)

func noteRelayMs(u string, d time.Duration) {
	ms := int(d.Milliseconds())
	if ms < 1 {
		ms = 1
	}
	relayMsMu.Lock()
	if old, ok := relayMs[u]; ok {
		// one slow answer does not make a store the slower one
		ms = (old + ms) / 2
	}
	relayMs[u] = ms
	relayMsMu.Unlock()
}

func relayMsOf(u string) int {
	relayMsMu.Lock()
	defer relayMsMu.Unlock()
	return relayMs[u]
}

func relayMsClear() {
	relayMsMu.Lock()
	clear(relayMs)
	relayMsMu.Unlock()
}

// the store that answers quicker now, of those that answer at all, "" with
// fewer than two up
func quickerStore(urls []string) string {
	relayHealthMu.Lock()
	var up []string
	for _, st := range storesIn(urls) {
		if storeUpLocked(urls, st, "") {
			up = append(up, st)
		}
	}
	relayHealthMu.Unlock()
	if len(up) < 2 {
		return ""
	}
	best, bestMs := "", 0
	for _, st := range up {
		ms := 0
		for _, u := range storeEntries(urls, st) {
			if m := relayMsOf(u); m > 0 && (ms == 0 || m < ms) {
				ms = m
			}
		}
		if ms > 0 && (best == "" || ms < bestMs) {
			best, bestMs = st, ms
		}
	}
	return best
}

// the public relays fast falls back on, and only while neither of our
// stores answers. they are reached through tor, never directly: on fast
// only our servers see the phone's address. empty on the other routes
var nostrBackups []string

func setBackups(urls []string) {
	nostrMu.Lock()
	nostrBackups = append([]string(nil), urls...)
	nostrMu.Unlock()
}

func backupsNow() []string {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	return append([]string(nil), nostrBackups...)
}

func isBackup(u string) bool {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	return containsStr(nostrBackups, u)
}

// how long our first store may go without answering on fast before the
// backups are read and written: a blip waits, an outage goes the long way.
// it is the one every version before the second store reads
var fastDownAfter = 2 * time.Minute

// and how long its attempts keep failing meanwhile, with tor able to carry
var fastFailSpan = time.Minute

// how long a backup waiting for its turn sleeps when nothing wakes it: the
// round changing and tor's status both do
var backupLook = 5 * time.Minute

// closed whenever tor's status changes, so a backup waiting for tor looks
// again at once
var (
	torWakeMu sync.Mutex
	torWakeC  = make(chan struct{})
)

func torWakeChan() <-chan struct{} {
	torWakeMu.Lock()
	defer torWakeMu.Unlock()
	return torWakeC
}

func torStatusMoved() {
	torWakeMu.Lock()
	close(torWakeC)
	torWakeC = make(chan struct{})
	torWakeMu.Unlock()
}

// ours answer again: the publish sockets kept on the backups go too
func backupsLetGo() {
	for _, u := range backupsNow() {
		pubCloseURL(u)
	}
}

// tor carries, whatever the route. on fast the backups need it
func torCarriesNow() bool {
	statusMu.RLock()
	defer statusMu.RUnlock()
	return torStatus == "bootstrapped" || torStatus == "publishing" || torStatus == "reachable"
}

// the client a backup is dialled with: tor's, under the lane's own name,
// on every route
func backupClientFor(lane string) (*http.Client, error) {
	return torClientFor(lane)
}

// the client for relay u. off the private route only our own stores'
// clearnet names are dialled in the clear: a backup, an onion, or any relay
// that is not ours always goes through tor
func relayClientFor(lane, u string) (*http.Client, error) {
	if isBackup(u) {
		return backupClientFor(lane)
	}
	if currentMode() != modePrivate {
		nostrMu.Lock()
		urls := nostrRelays
		nostrMu.Unlock()
		if isOnion(u) || (storeOf(urls, u) == "" && !clearForTests(u)) {
			return backupClientFor(lane)
		}
	}
	return torNostrClientFor(lane)
}

// stand-ins the tests reach in the clear as public relays, where they have
// no tor to go through. none in the app
var clearTestHosts sync.Map

func clearForTests(u string) bool {
	p, err := url.Parse(u)
	if err != nil {
		return false
	}
	_, ok := clearTestHosts.Load(strings.ToLower(p.Host))
	return ok
}

// the relays a send or a one-shot ask goes to now: the list, and the
// backups while our first store is down and tor can carry them
func relaysInUse(ctx context.Context) []string {
	urls := relaysWhenSet(ctx)
	if b := backupsNow(); len(b) > 0 && backupsOn() {
		urls = append(urls, b...)
	}
	return urls
}

// ev to every backup through tor, on the fast route, while tor carries: a
// send our first store missed
func publishToBackups(lane string, ev nostr.Event, routeC <-chan struct{}) {
	if currentMode() != modeBalanced || !torCarriesNow() || torIsPaused() {
		return
	}
	for _, u := range backupsNow() {
		go func(u string) {
			client, err := backupClientFor(lane)
			if err != nil || routeGone(routeC) {
				return
			}
			ctx, cancel := onRoute(context.Background(), routeC)
			defer cancel()
			pctx, pcancel := context.WithTimeout(ctx, publishWait)
			defer pcancel()
			if err := publishTo(pctx, lane, u, client, ev); err != nil && !relayHasIt(err) {
				log.Printf("nostr: backup %s did not take what our first relay missed: %v", u, err)
			}
		}(u)
	}
}

// the backups are read and written: our first store is down, and tor can
// carry them
func backupsOn() bool {
	return firstStoreDown() && torCarriesNow() && !torIsPaused()
}
