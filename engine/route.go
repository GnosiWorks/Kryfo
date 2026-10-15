// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"log"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/cretz/bine/control"
)

// whether the route through tor actually carries anything. tor's own report
// is not enough: it can say bootstrapped while every relay connection through
// it fails. so the judgement comes from relay connections succeeding or
// failing. no probe of its own: a probe is battery, and a phone that pings on
// a timer can be told apart from one that does not.

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
	// when tor was first seen off while nobody asked for it to be
	offSince time.Time
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
	correctStaleStart()
}

// set from the start of a bounce until tor is back on the network. a connect
// that finishes in that window went through the tor that is going.
var bounceOff int32

// a relay has just connected through tor, so tor can carry traffic whatever
// its own status says, and the status follows the relay. a status stuck at
// "starting" holds back paused uploads and gets a working tor bounced.
//
// what counts is whether the connect came after tor was back on the network,
// even while the reconnect is still finishing, since that is where the
// relays reconnect. reconnectOn bumps the route generation a second time at
// exactly that point, so okGen == routeGen says so, and bounceOff covers the
// window before it. the route watch also applies this on every tick, for a
// connect that landed while bounceOff was still set.
func correctStaleStart() {
	if !modeNeedsTor() || torIsPaused() || atomic.LoadInt32(&bounceOff) == 1 {
		return
	}
	routeMu.Lock()
	proven := okGen == routeGen
	routeMu.Unlock()
	if !proven {
		return
	}
	statusMu.Lock()
	// off too: a reconnect that gave up half way says off while the tor
	// under it carries relays
	stale := torStatus == "starting" || torStatus == "off"
	if stale {
		bootstrapPct = 100
	}
	statusMu.Unlock()
	if stale {
		log.Println("halo: a relay connected through tor while it said starting - it is up")
		setStatus("publishing")
	}
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
		correctStaleStart()
		if netValveDue(time.Now()) {
			go netValveTry()
		}
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
	// no network: nothing can get through, and a rescue then only spends
	// tor's guards and the back-off. the change that brings one bounces
	if netOffline.Load() {
		return ""
	}
	// automatic owns the bounces while it tries: not counted as a rescue
	if autoGateHeld() {
		return ""
	}
	if atomic.LoadInt32(&reconnectRunning) == 1 || atomic.LoadInt32(&torRestarting) == 1 {
		return ""
	}
	statusMu.RLock()
	st, pct := torStatus, bootstrapPct
	statusMu.RUnlock()
	// before routeMu: it takes mu
	up := st == "off" && torUp()

	routeMu.Lock()
	defer routeMu.Unlock()

	if st != "starting" {
		stallPct = -1
	}
	if st != "off" {
		offSince = time.Time{}
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
	case up:
		// a tor this process started is off and nobody paused it: a
		// reconnect gave up half way, and tor may have taken the network
		// off after it gave up. the app's watchdog only does first starts
		if offSince.IsZero() {
			offSince = now
			return ""
		}
		if now.Sub(offSince) < offFor {
			return ""
		}
		if !lastRescue.IsZero() && now.Sub(lastRescue) < rescueGap(rescues) {
			return ""
		}
		why := "tor has been off for " + now.Sub(offSince).Round(time.Second).String()
		rescues++
		lastRescue = now
		return why
	}
	// an off tor that never started is the app's watchdog: it starts it
	return ""
}

// how long tor may sit off before the watch brings it back
const offFor = 15 * time.Second

// a tor runs in this process and has an address
func torUp() bool {
	mu.Lock()
	defer mu.Unlock()
	return torNode != nil && myAddr != ""
}

// a new network is a fresh start. the back-off grown while there was none,
// a flight's worth of rescues, must not hold off the first one on the ground
func routeFreshNetwork() {
	routeMu.Lock()
	rescues = 0
	lastRescue = time.Time{}
	stallPct = -1
	offSince = time.Time{}
	routeMu.Unlock()
}

// android says the network changed. tor's open connections belong to the
// network that went, and tor finds that out one timeout at a time. bounce it
// the way orbot does: DisableNetwork 1 then 0.
//
// a network that flaps must not be bounced on every flap, so the bounce waits
// for five quiet seconds after the last change, and two network bounces are
// never less than twenty seconds apart. the last change always gets one.
var (
	netMu         sync.Mutex
	netChangedAt  time.Time
	netWorker     bool
	lastNetBounce time.Time
	// when tor last went on the network, and the network the watch said
	// was there then
	netOnAt  time.Time
	netOnNet netInfo
)

// vars rather than consts so the test can run the debounce in milliseconds
var (
	netQuiet = 5 * time.Second
	netGap   = 20 * time.Second
)

// the app said there is no network at all: airplane mode, or nothing in
// range. a bounce then proves nothing, so it waits for the network to come
var netOffline atomic.Bool

// when the network went, zero while there is one, and the tries the valve
// made since. netGoneMu
var (
	netGoneMu    sync.Mutex
	netGoneAt    time.Time
	netValveN    int
	netValveLast time.Time
)

// whether there is a network now, from whichever call says so. true when
// there was none before
func setOffline(off bool) (was bool) {
	netGoneMu.Lock()
	defer netGoneMu.Unlock()
	was = netOffline.Swap(off)
	switch {
	case off && !was:
		netGoneAt, netValveN, netValveLast = time.Now(), 0, time.Time{}
	case !off:
		netGoneAt = time.Time{}
	}
	return was
}

// what the plain call said last
const (
	connUnsaid int32 = iota
	connOn
	connOff
)

var connSaid atomic.Int32

// tor stays off the network for want of one, unless the valve is trying it
func netAway() bool { return netOffline.Load() && !netValveOpen.Load() }

// a change the app saw, and whether a network is there after it
func networkChangedTo(online bool) {
	// android's watch on the default network has the say once it has
	// spoken: this older call can say none while a network is there
	// the watch has the say: a word of the plain call that differs is a
	// dispute for the valve, not a change of network
	if n, ok := netDetailTrusted(); ok && n.On != online {
		return
	}
	was := setOffline(!online)
	networkChanged()
	if !online {
		// at once, not after the quiet window: every guard tor tries with
		// no network is marked down, and tor waits ten minutes before it
		// tries a primary guard again
		go netPark()
		return
	}
	if was {
		netBack()
	}
}

// the network came back. runners that slept through the outage dial
// again, through tor once the bounce has put it back on the network
func netBack() {
	if !modeNeedsTor() || !torParked.Load() {
		kickRelays()
	}
}

// tor off the network while there is none. reconnectOn leaves it off and
// the network-change bounce puts it back on. a var for the tests, set in
// init: a park reaches a reconnect, which can park
var netPark func()

func init() { netPark = parkForNoNetwork }

func parkForNoNetwork() {
	if !netAway() || !modeNeedsTor() || torIsPaused() || torParked.Load() {
		return
	}
	mu.Lock()
	up := torNode != nil && torNode.Control != nil
	mu.Unlock()
	if !up || !netAway() {
		return
	}
	log.Println("halo: no network, taking tor off it")
	// past automatic's gate: going off the network is safe in any mode, and
	// an attempt under way is stopped by the outage anyway
	reconnectTorBy(true, true)
}

// tor was left off the network because there was none
var torParked atomic.Bool

// tor left off the network for want of one. a network that came meanwhile
// found it not parked yet and bounced nothing, so it is looked at again
func netParked() {
	torParked.Store(true)
	if !netAway() {
		networkChanged()
	}
}

// DisableNetwork 0 commands tor took, counted under the control lock
var netOns atomic.Int64

// tor was told DisableNetwork 1 and has not gone on since. it starts that
// way. under the control lock
var torNetOff atomic.Bool

func init() { torNetOff.Store(true) }

// tor took DisableNetwork 1: every connection it held is closed
func netWentOff() { torNetOff.Store(true) }

// tor went on the network. a park that came meanwhile found it parked
// still and left it, so it is looked at again. under the control lock
func netWentOn() {
	netOns.Add(1)
	torParked.Store(false)
	// a 0 to a tor that was on already keeps what it held on the old network
	if torNetOff.Swap(false) {
		n, _ := netDetailNow()
		netMu.Lock()
		netOnAt, netOnNet = time.Now(), n
		netMu.Unlock()
	}
	if netAway() {
		go netPark()
	}
}

// offline this long by the app's word, tor is tried anyway in case the
// word was wrong, and again after each wait, twice as long up to the most
var (
	netValveAfter = 10 * time.Minute
	netValveMost  = time.Hour
)

// set while the valve tries tor with no network said to be there
var netValveOpen atomic.Bool

// the least wait for a valve while the plain call has said nothing: the
// watch alone saying none is believed for longer
var netValveUnsaid = 30 * time.Minute

// the watch says none while the plain call sees a network
func netDisputed() bool {
	d, ok := netDetailTrusted()
	return ok && !d.On && connSaid.Load() == connOn
}

// what connectivity sees, from the app on every event: whether the two
// calls disagree, and no change of its own
func connectivitySaw(on bool) {
	if on {
		connSaid.Store(connOn)
	} else {
		connSaid.Store(connOff)
	}
}

// whether the valve tries now. records the try it allows
func netValveDue(now time.Time) bool {
	if !netOffline.Load() || !torParked.Load() || netValveOpen.Load() || !modeNeedsTor() || torIsPaused() {
		return false
	}
	// each try marks guards down: only when the two calls disagree, or
	// one of them never spoke. none by both is none
	least := time.Duration(0)
	if _, known := netDetailNow(); known {
		switch connSaid.Load() {
		case connOff:
			return false
		case connUnsaid:
			least = netValveUnsaid
		}
	}
	netGoneMu.Lock()
	defer netGoneMu.Unlock()
	if netGoneAt.IsZero() {
		return false
	}
	wait := netValveAfter << uint(netValveN)
	if netValveN > 6 || wait > netValveMost {
		wait = netValveMost
	}
	if wait < least {
		wait = least
	}
	from := netGoneAt
	if !netValveLast.IsZero() {
		from = netValveLast
	}
	if now.Sub(from) < wait {
		return false
	}
	netValveN++
	netValveLast = now
	return true
}

// how long the valve takes a network as there: a bounce or automatic's
// pass gets that long to bring a relay through
var netValveFor = 3 * time.Minute

// the network taken as there for netValveFor, as on any change: the bounce
// or automatic's pass tries tor. a relay through it means the network was
// there after all. otherwise tor is parked again. a var for the tests, set
// in init as the others
var netValveTry func()

func init() { netValveTry = valveTryTor }

func valveTryTor() {
	if !netValveOpen.CompareAndSwap(false, true) {
		return
	}
	log.Println("halo: no network for long, trying tor anyway")
	networkChanged()
	autoKick()
	ok := netValveProven()
	netValveOpen.Store(false)
	if ok {
		log.Println("halo: a relay got through, the network is there")
		netDisprove()
		setOffline(false)
		kickRelays()
		return
	}
	if netAway() {
		netPark()
	}
}

// a relay through tor while the valve is open, before netValveFor is out
// and while the app has not spoken
func netValveProven() bool {
	gen := routeBump()
	step := netKnobsNow().step
	end := time.Now().Add(netValveFor)
	for time.Now().Before(end) {
		if !netOffline.Load() || !modeNeedsTor() || torIsPaused() {
			return false
		}
		routeMu.Lock()
		ok := okGen >= gen
		routeMu.Unlock()
		if ok {
			return true
		}
		time.Sleep(step)
	}
	return false
}

func networkChanged() {
	// direct was welcome on the old network, maybe not on this one. a
	// check-in under way puts this network's way back at once. both wait on
	// tor's control port, so neither holds up the caller
	if autoDirectOK.Swap(false) {
		go netLeaveDirect(netOns.Load())
	}
	if inCheckIn() {
		putCheckInStepSoon()
	}
	// a snowflake client keeps the nat type it found on the old network
	dropSnowflakeClients()
	routeFreshNetwork()
	// what proved the old network proves nothing about this one
	routeBump()
	netEpoch.Add(1)
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
		now, _ := netDetailNow()
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
		netWorker = false
		// tor went on the network after the last change, on the network that
		// is there now: all it holds was made on this one. a bounce asked for
		// before tor came up has nothing left to do
		if netOnAt.After(netChangedAt) && !torParked.Load() && sameNetwork(netOnNet, now) {
			netMu.Unlock()
			log.Println("halo: tor went on this network after the change, no bounce")
			return
		}
		lastNetBounce = time.Now()
		bounce := netBounce
		netMu.Unlock()

		// floors and back-offs were reset with the change. offline, the
		// bounce and its check wait for the change that brings a network
		if !modeNeedsTor() || torIsPaused() || netAway() {
			return
		}
		// automatic starts its own pass on the new network
		if autoGateHeld() {
			log.Println("halo: network bounce left to automatic")
			return
		}
		bounce()
		return
	}
}

// automatic's direct step was out on the old network: tor leaves the
// network at once, as this one may be where direct is blocked, and the
// bounce or automatic's pass puts it back with this network's way. a var
// for the tests
var netLeaveDirect = func(ons int64) {
	if mode, _, _ := bridgeMode(); mode != bmAuto || !modeNeedsTor() || torIsPaused() {
		return
	}
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil || t.Control == nil {
		return
	}
	err := ctrlDo(t, "DisableNetwork 1", func(c *control.Conn) error {
		// tor went on since the change, with this network's own step,
		// or a direct step was put back for it
		if netOns.Load() != ons || autoDirectOK.Load() {
			return nil
		}
		if err := c.SetConf(control.KeyVals("DisableNetwork", "1")...); err != nil {
			return err
		}
		netWentOff()
		return nil
	})
	if err != nil {
		log.Printf("halo: tor would not leave the network: %v", err)
	}
}

// a var so the debounce can be tested without a tor. set in init: the
// bounce reaches a park, and a park starts the debounce again
var netBounce func()

func init() { netBounce = bounceForNetwork }

func bounceForNetwork() {
	log.Println("halo: network changed, bouncing tor")
	epoch := netEpoch.Load()
	netKnobsNow().reconnect()
	netCheck(epoch)
}

// every change counted, so the check for a network that has gone already
// stands down for the check of the one that came
var netEpoch atomic.Int64

// the reconnect a network change gets: past the floor, the back-off and any
// reconnect still running, which began on the network that went
var netReconnect = func() string {
	routeFreshNetwork()
	return reconnectTorAs(true)
}

// how long tor gets to prove itself on a new network, and how many bounces
// it gets to do it in. after that the route watch has it
var (
	netProof      = 90 * time.Second
	netProofTries = 2
	netProofStep  = 2 * time.Second
)

// the bounce's settings as they are now. the tests change them under
// netMu, while a bounce of an earlier test may still be running
type netKnobs struct {
	proof     time.Duration
	tries     int
	step      time.Duration
	reconnect func() string
}

func netKnobsNow() netKnobs {
	netMu.Lock()
	defer netMu.Unlock()
	return netKnobs{netProof, netProofTries, netProofStep, netReconnect}
}

// a relay connected through the route the last bounce built
func routeProven() bool {
	routeMu.Lock()
	defer routeMu.Unlock()
	return okGen == routeGen
}

var netCheckOutcome atomic.Value // string, for the transport screen

func lastNetCheck() string {
	if v, ok := netCheckOutcome.Load().(string); ok {
		return v
	}
	return ""
}

// whether tor really works on the new network, bounded. no probe of its own:
// the relays the bounce kicked are the proof. "ok", "unproven", or
// "superseded" when a newer change took over
func netCheck(epoch int64) string {
	k := netKnobsNow()
	began := time.Now()
	for try := 1; ; try++ {
		end := time.Now().Add(k.proof)
		for time.Now().Before(end) {
			if netEpoch.Load() != epoch || !modeNeedsTor() || torIsPaused() || netAway() {
				return "superseded"
			}
			if routeProven() {
				netCheckOutcome.Store(fmt.Sprintf("ok after %s", time.Since(began).Round(time.Second)))
				return "ok"
			}
			time.Sleep(k.step)
		}
		if try >= k.tries {
			netCheckOutcome.Store(fmt.Sprintf("no relay through tor in %s", time.Since(began).Round(time.Second)))
			log.Printf("halo: tor not proven on the new network after %d bounces", try)
			return "unproven"
		}
		log.Printf("halo: no relay through tor %s after the bounce, bouncing again", k.proof)
		k.reconnect()
	}
}
