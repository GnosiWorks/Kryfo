// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what android says about the default network: whether there is one, which
// type it is, whether android could check it reaches the internet, whether
// a captive portal sits in front, and whether a vpn carries it. automatic
// reads it. android checks against a google host that some networks block,
// so an unvalidated network is a hint, never proof of anything.

import "C"

import (
	"encoding/json"
	"strings"
	"sync"
)

type netInfo struct {
	On        bool   `json:"on"`
	Validated bool   `json:"validated"`
	Limited   bool   `json:"limited"`
	VPN       bool   `json:"vpn"`
	Kind      string `json:"kind"`
	// whether the app has said anything yet. before it has, the network is
	// taken as present and validated, as the engine always did
	known bool
}

var (
	netInfoMu  sync.Mutex
	netInfoNow = netInfo{On: true, Validated: true, Kind: "unknown"}
)

// the network types kept apart in automatic's memory. a vpn is its own
// type: what the network in front of it blocks does not matter then.
var netKinds = map[string]bool{"wifi": true, "cellular": true, "ethernet": true, "vpn": true, "other": true}

func setNetInfo(n netInfo) {
	n.Kind = strings.ToLower(strings.TrimSpace(n.Kind))
	if n.VPN {
		n.Kind = "vpn"
	}
	if !netKinds[n.Kind] {
		n.Kind = "other"
	}
	if !n.On {
		n.Validated, n.Limited = false, false
	}
	n.known = true
	netInfoMu.Lock()
	prev := netInfoNow
	// the word a relay through tor proved wrong, said again: not taken
	stale := netDisproved != nil && sameNet(n, *netDisproved)
	if !stale {
		netDisproved = nil
	}
	netInfoNow = n
	netInfoMu.Unlock()
	if stale {
		return
	}
	was := setOffline(!n.On)
	switch {
	case was && n.On:
		netBack()
		// a network back is a new one: what was proved on the one that
		// went, a direct step above all, does not hold for it, parked or not
		networkChanged()
	case !was && !n.On:
		// what proved the network that went proves nothing now
		routeBump()
		go netPark()
	}
	// a check-in puts the way of the network that is there now
	if n.On && (was || prev.Kind != n.Kind) && inCheckIn() {
		putCheckInStepSoon()
	}
	// signed in past a portal, or android got its answer at last: what
	// failed before may get through now
	if prev.known && n.On && n.Validated && !n.Limited && (!prev.Validated || prev.Limited) {
		autoValidFlips.Add(1)
	}
	autoKick()
}

// what android last said of the default network, and whether it has said
// anything yet
func netDetailNow() (netInfo, bool) {
	netInfoMu.Lock()
	defer netInfoMu.Unlock()
	return netInfoNow, netInfoNow.known
}

// what the watch said that a relay through tor then proved wrong. the
// same word again is not taken, a new one is. netInfoMu
var netDisproved *netInfo

func sameNet(a, b netInfo) bool {
	return a.On == b.On && a.Validated == b.Validated && a.Limited == b.Limited && a.VPN == b.VPN && a.Kind == b.Kind
}

// android's word on the default network, and whether it is to be taken:
// it has spoken, and not the word a relay through tor proved wrong
func netDetailTrusted() (netInfo, bool) {
	netInfoMu.Lock()
	defer netInfoMu.Unlock()
	n := netInfoNow
	return n, n.known && (netDisproved == nil || !sameNet(n, *netDisproved))
}

// a relay got through while the watch says there is no network
func netDisprove() {
	netInfoMu.Lock()
	defer netInfoMu.Unlock()
	if n := netInfoNow; n.known && !n.On {
		netDisproved = &n
	}
}

func currentNet() netInfo {
	netInfoMu.Lock()
	defer netInfoMu.Unlock()
	n := netInfoNow
	// the older call says only whether a network is there. the valve
	// takes one as there while it tries
	if netAway() {
		n.On, n.Validated, n.Limited = false, false, false
	} else if !n.On {
		// a network after all, of which android has said nothing yet
		n.On = true
	}
	return n
}

// the default network as android sees it, as json:
// {"on":true,"validated":true,"limited":false,"vpn":false,"kind":"wifi"}.
// once it has come, whether there is a network is its word, not
// HaloNetworkState's. tor leaves the network when it says none, and a
// network back is bounced on if nothing else will.
//
//export HaloNetworkDetail
func HaloNetworkDetail(cJSON *C.char) *C.char {
	return C.CString(networkDetail(goStr(cJSON)))
}

func networkDetail(s string) string {
	var n netInfo
	if json.Unmarshal([]byte(s), &n) != nil {
		return "error: bad json"
	}
	setNetInfo(n)
	return "ok"
}
