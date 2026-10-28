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
	"net/http"
	"sync"
	"time"
)

const (
	storeFirst  = "1"
	storeSecond = "2"
)

// the second store's clearnet name. a var so tests can point it at a
// stand-in
var secondRelayHost = "relay2.kryfo.app"

// the store u reaches in urls, "" for a relay that is not ours. the first
// entry is the first store whatever its name, as in private mode its onion
func storeOf(urls []string, u string) string {
	switch {
	case relayHostIs(u, secondRelayHost):
		return storeSecond
	case relayHostIs(u, ownRelayHost):
		return storeFirst
	case len(urls) > 0 && urls[0] == u:
		return storeFirst
	}
	return ""
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

// how long none of our stores may answer on fast before the backups are
// read: a short outage waits in the outbox, a long one goes the long way
var fastDownAfter = 2 * time.Minute

// and how long ours keep failing meanwhile, with tor able to carry
var fastFailSpan = time.Minute

// how often a backup waiting for ours to go down looks again, for tor
// coming up meanwhile
var backupLook = 30 * time.Second

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

// the client for relay u: a backup always goes through tor
func relayClientFor(lane, u string) (*http.Client, error) {
	if isBackup(u) {
		return backupClientFor(lane)
	}
	return torNostrClientFor(lane)
}

// the relays a send or a one-shot ask goes to now: the list, and the
// backups while neither of our stores answers and tor can carry them
func relaysInUse(ctx context.Context) []string {
	urls := relaysWhenSet(ctx)
	if b := backupsNow(); len(b) > 0 && backupsOn() {
		urls = append(urls, b...)
	}
	return urls
}

// the backups are read: our stores are down, as the round for capped
// public reads says, and tor can carry
func backupsOn() bool {
	return ownRelayDown() && torCarriesNow() && !torIsPaused()
}
