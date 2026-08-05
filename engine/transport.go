// SPDX-License-Identifier: GPL-3.0-or-later
package main

// one place to ask what the transport is doing. the state was always there,
// scattered across three files, and nothing could read all of it at once - so
// each part inferred the rest and got it wrong. the runner did not know the
// relay list was empty. the benching did not know tor was still warming up.
// the send did not know the peer had no subscription. every one of those
// failed silently, which is the expensive kind.

import "C"

import (
	"encoding/json"
	"sync"
	"time"
)

var (
	txMu      sync.RWMutex
	lastSend  time.Time
	lastRecv  time.Time
	lastBoot  time.Time
	lastBootP int
)

func noteSend() {
	txMu.Lock()
	lastSend = time.Now()
	txMu.Unlock()
}

func noteRecv() {
	txMu.Lock()
	lastRecv = time.Now()
	txMu.Unlock()
}

// called every time tor reports a new bootstrap percentage. the watchdog
// checks it before killing anything: a bootstrap that is still climbing is
// slow, not wedged, and restarting it throws away the progress.
func noteBootstrapProgress(pct int) {
	txMu.Lock()
	if pct != lastBootP {
		lastBootP = pct
		lastBoot = time.Now()
	}
	txMu.Unlock()
}

func bootstrapMovingRecently() bool {
	txMu.RLock()
	defer txMu.RUnlock()
	return !lastBoot.IsZero() && time.Since(lastBoot) < 45*time.Second
}

// tor can carry traffic. the single test - callers used to each keep their
// own copy of this and they drifted.
func torReadyNow() bool {
	statusMu.RLock()
	defer statusMu.RUnlock()
	return torStatus == "bootstrapped" ||
		torStatus == "publishing" ||
		torStatus == "reachable"
}

type relayView struct {
	URL      string `json:"url"`
	Fails    int    `json:"fails"`
	Benched  bool   `json:"benched"`
	BenchFor int    `json:"bench_for_s"`
}

type transportView struct {
	TorStatus    string      `json:"tor_status"`
	BootstrapPct int         `json:"bootstrap_pct"`
	TorReady     bool        `json:"tor_ready"`
	HsdirUploads int         `json:"hsdir_uploads"`
	OnionAddr    string      `json:"onion_addr"`
	Relays       []relayView `json:"relays"`
	Subs         []string    `json:"subs"`
	SubCount     int         `json:"sub_count"`
	SecsSinceTx  int         `json:"secs_since_send"`
	SecsSinceRx  int         `json:"secs_since_recv"`
	InboxDepth   int         `json:"inbox_depth"`
}

func transportSnapshot() transportView {
	statusMu.RLock()
	v := transportView{
		TorStatus:    torStatus,
		BootstrapPct: bootstrapPct,
		HsdirUploads: hsdirUploads,
	}
	statusMu.RUnlock()
	v.TorReady = torReadyNow()

	mu.Lock()
	v.OnionAddr = myAddr
	mu.Unlock()

	nostrMu.Lock()
	urls := append([]string(nil), nostrRelays...)
	for tag := range nostrSubs {
		v.Subs = append(v.Subs, tag)
	}
	v.InboxDepth = len(nostrInbox)
	nostrMu.Unlock()
	v.SubCount = len(v.Subs)

	now := time.Now()
	relayHealthMu.Lock()
	for _, u := range urls {
		rv := relayView{URL: u, Fails: relayFails[u]}
		if till, ok := relayCoolTill[u]; ok && now.Before(till) {
			rv.Benched = true
			rv.BenchFor = int(time.Until(till).Seconds())
		}
		v.Relays = append(v.Relays, rv)
	}
	relayHealthMu.Unlock()

	txMu.RLock()
	v.SecsSinceTx = -1
	v.SecsSinceRx = -1
	if !lastSend.IsZero() {
		v.SecsSinceTx = int(now.Sub(lastSend).Seconds())
	}
	if !lastRecv.IsZero() {
		v.SecsSinceRx = int(now.Sub(lastRecv).Seconds())
	}
	txMu.RUnlock()

	return v
}

//export HaloTransportState
func HaloTransportState() *C.char {
	b, err := json.Marshal(transportSnapshot())
	if err != nil {
		return C.CString("{}")
	}
	return C.CString(string(b))
}
