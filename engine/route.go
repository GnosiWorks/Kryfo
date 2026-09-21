// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"log"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

// whether the route through tor actually carries anything.
//
// tor's own report is not enough. after a samsung came back from flight mode
// it said bootstrapped, publishing, can send - and every relay connection
// through it failed for sixteen minutes, with nothing acting on it, because
// the only dead man switch (relaysAllDead) sat on the path where building a
// client fails, and here building the client worked. so the judgement is made
// from what already happens: relay connections succeeding or failing. no
// probe of its own - a probe is battery, and a phone that pings on a timer is
// a phone that can be told apart from one that does not.

var (
	routeMu sync.Mutex
	// relays whose connect failed while tor claimed ready, since the last
	// connect that worked. distinct relays, not attempts: one relay that is
	// down for its own reasons must not make the whole route look dead.
	failedSinceOK = map[string]bool{}
	firstFailAt   time.Time
	// bumped whenever the route is torn down on purpose. a route is only
	// trusted once a relay has connected since the latest bump, so nothing
	// reads the tor that is about to go as the tor that came back.
	routeGen int64
	okGen    int64 = -1
	// rescues in a row with no relay answer in between, and when the last was
	rescues    int
	lastRescue time.Time
	// the bootstrap percentage when it last moved, and when that was
	stallPct   = -1
	stallSince time.Time
)

// a relay connect worked. the route carries traffic, whatever came before.
func routeNoteOK() {
	routeMu.Lock()
	for k := range failedSinceOK {
		delete(failedSinceOK, k)
	}
	firstFailAt = time.Time{}
	okGen = routeGen
	rescues = 0
	routeMu.Unlock()
}

// a relay connect failed while tor said it was ready.
func routeNoteFail(u string) {
	routeMu.Lock()
	if len(failedSinceOK) == 0 {
		firstFailAt = time.Now()
	}
	failedSinceOK[u] = true
	routeMu.Unlock()
}

// the route is about to be torn down on purpose. returns the new generation.
func routeBump() int64 {
	routeMu.Lock()
	routeGen++
	g := routeGen
	for k := range failedSinceOK {
		delete(failedSinceOK, k)
	}
	firstFailAt = time.Time{}
	routeMu.Unlock()
	return g
}

// true when the route can carry traffic now, judged by relays rather than by
// tor. outside private mode nothing depends on tor, so it is always true.
func routeOK() bool {
	if !modeNeedsTor() {
		return true
	}
	if !torReadyNow() {
		return false
	}
	routeMu.Lock()
	defer routeMu.Unlock()
	if okGen != routeGen {
		// nothing has connected since the latest bounce, or ever
		return false
	}
	return !(len(failedSinceOK) >= 2 && time.Since(firstFailAt) > 20*time.Second)
}

func routeGeneration() int64 {
	routeMu.Lock()
	defer routeMu.Unlock()
	return routeGen
}

// how long relays may all fail while tor claims ready before the route is
// rebuilt, and the least time between two rebuilds. the gap doubles with
// every rescue that did not bring a relay back, so a network that is simply
// gone is not bounced every minute until the battery is.
const deadFor = 60 * time.Second

func rescueGap(n int) time.Duration {
	d := time.Minute << uint(n)
	if n > 4 || d > 15*time.Minute {
		return 15 * time.Minute
	}
	return d
}

// how long a bootstrap may sit at one percentage before it is bounced. it is
// judged by the percentage not moving, never by how long bootstrapping takes:
// bridges on a slow or censored network can climb for many minutes, and every
// step up restarts this clock. the limit itself backs off too.
func stallLimit(n int) time.Duration {
	d := 3 * time.Minute << uint(n)
	if n > 3 || d > 30*time.Minute {
		return 30 * time.Minute
	}
	return d
}

var routeWatchOnce sync.Once

func startRouteWatch() {
	routeWatchOnce.Do(func() { go routeWatch() })
}

func routeWatch() {
	for {
		time.Sleep(10 * time.Second)
		if why := routeNeedsRescue(time.Now()); why != "" {
			log.Printf("halo: route rescue - %s", why)
			atomic.StoreInt64(&lastTorRestart, 0)
			go reconnectTor()
		}
	}
}

// the decision, apart from the loop so it can be tested with a clock. "" when
// nothing should happen, otherwise the reason. records the rescue it allows.
func routeNeedsRescue(now time.Time) string {
	if !modeNeedsTor() || torIsPaused() {
		return ""
	}
	if atomic.LoadInt32(&reconnectRunning) == 1 || atomic.LoadInt32(&torRestarting) == 1 {
		return ""
	}
	statusMu.RLock()
	st, pct := torStatus, bootstrapPct
	statusMu.RUnlock()

	routeMu.Lock()
	defer routeMu.Unlock()

	if st != "starting" {
		stallPct = -1
	}
	switch {
	case st == "bootstrapped" || st == "publishing" || st == "reachable":
		if len(failedSinceOK) < 2 || now.Sub(firstFailAt) < deadFor {
			return ""
		}
		if !lastRescue.IsZero() && now.Sub(lastRescue) < rescueGap(rescues) {
			return ""
		}
		why := "tor says ready but every relay has failed for " +
			now.Sub(firstFailAt).Round(time.Second).String()
		rescues++
		lastRescue = now
		return why
	case st == "starting":
		if pct != stallPct {
			stallPct, stallSince = pct, now
			return ""
		}
		if now.Sub(stallSince) < stallLimit(rescues) {
			return ""
		}
		why := "bootstrap has not moved from " + strconv.Itoa(pct) + "% for " +
			now.Sub(stallSince).Round(time.Second).String()
		rescues++
		lastRescue = now
		stallPct = -1
		return why
	}
	// "off" is the app's watchdog: it restarts the listener itself
	return ""
}

// android says the network changed. tor's open connections belong to the
// network that went, and tor finds that out one timeout at a time - which is
// how a phone back from flight mode sat for sixteen minutes saying ready and
// carrying nothing. bounce it the way orbot does: DisableNetwork 1 then 0.
//
// a network that flaps must not be bounced on every flap, so the bounce waits
// for five quiet seconds after the last change, and two network bounces are
// never less than twenty seconds apart. the last change always gets one.
var (
	netMu         sync.Mutex
	netChangedAt  time.Time
	netWorker     bool
	lastNetBounce time.Time
)

// vars rather than consts so the test can run the debounce in milliseconds
var (
	netQuiet = 5 * time.Second
	netGap   = 20 * time.Second
)

func networkChanged() {
	netMu.Lock()
	netChangedAt = time.Now()
	if netWorker {
		netMu.Unlock()
		return
	}
	netWorker = true
	netMu.Unlock()
	go netBounceWorker()
}

func netBounceWorker() {
	for {
		netMu.Lock()
		wait := time.Until(netChangedAt.Add(netQuiet))
		if gap := time.Until(lastNetBounce.Add(netGap)); gap > wait {
			wait = gap
		}
		if wait > 0 {
			netMu.Unlock()
			time.Sleep(wait)
			continue
		}
		lastNetBounce = time.Now()
		netWorker = false
		netMu.Unlock()

		if !modeNeedsTor() || torIsPaused() {
			return
		}
		netBounce()
		return
	}
}

// a var so the debounce can be tested without a tor.
var netBounce = func() {
	log.Println("halo: network changed, bouncing tor")
	atomic.StoreInt64(&lastTorRestart, 0)
	if r := reconnectTor(); r == "error: one already running" {
		// the running one may be past the point where it would have
		// helped. one more, once it is done.
		time.Sleep(10 * time.Second)
		atomic.StoreInt64(&lastTorRestart, 0)
		go reconnectTor()
	}
}
