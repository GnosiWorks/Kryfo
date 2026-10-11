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
	netInfoNow = n
	netInfoMu.Unlock()
	// runners asleep through an outage dial again, whichever call says so first
	if netOffline.Swap(!n.On) && n.On {
		kickRelays()
	}
	// signed in past a portal, or android got its answer at last: what
	// failed before may get through now
	if prev.known && n.On && n.Validated && !n.Limited && (!prev.Validated || prev.Limited) {
		autoValidFlips.Add(1)
	}
	autoKick()
}

func currentNet() netInfo {
	netInfoMu.Lock()
	defer netInfoMu.Unlock()
	n := netInfoNow
	// the older call says only whether a network is there
	if netOffline.Load() {
		n.On, n.Validated, n.Limited = false, false, false
	} else if !n.On {
		// a network after all, of which android has said nothing yet
		n.On = true
	}
	return n
}

// the default network as android sees it, as json:
// {"on":true,"validated":true,"limited":false,"vpn":false,"kind":"wifi"}.
// it changes no state of tor: the bounce on a network change stays with
// HaloNetworkState.
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
