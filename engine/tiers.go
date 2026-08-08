// SPDX-License-Identifier: GPL-3.0-or-later
package main

// transport tiers. mandatory tor is the single biggest thing that makes kryfo
// slow, and in places where tor is blocked outright it makes it useless. the
// answer is not to abandon tor - it stays the default - but to let someone
// knowingly trade it away.
//
//	private   tor for everything. nobody learns your ip. slow first connect.
//	balanced  plain tls to our own relay, and nothing else. our relay sees
//	          your ip. your contacts do not, other relays do not, and the
//	          message is still sealed the same way.
//	fast      plain tls to every relay. all of them see your ip.
//
// the engine only decides whether to route through tor. which relays to talk
// to is chosen on the dart side, because that is where the list already
// lives.

import "C"

import (
	"log"
	"net"
	"net/http"
	"sync/atomic"
	"time"
)

const (
	modePrivate  = "private"
	modeBalanced = "balanced"
	modeFast     = "fast"
)

var transportMode atomic.Value // string

func currentMode() string {
	if v, ok := transportMode.Load().(string); ok && v != "" {
		return v
	}
	return modePrivate
}

// tor is only required when we are actually routing through it. in the other
// modes the app must not wait on a bootstrap that may never finish - that is
// the whole point of the tier.
func modeNeedsTor() bool {
	return currentMode() == modePrivate
}

// a plain client for the non-tor tiers. no proxy, ordinary tls, so the
// connection looks like any other https to anyone watching the wire.
func directNostrClient() *http.Client {
	return &http.Client{
		Transport: &http.Transport{
			DialContext: (&net.Dialer{
				Timeout:   15 * time.Second,
				KeepAlive: 30 * time.Second,
			}).DialContext,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 15 * time.Second,
			ForceAttemptHTTP2:     true,
		},
		Timeout: 60 * time.Second,
	}
}

// private, balanced or fast. anything else is treated as private, because a
// typo must never quietly drop someone out of tor.
//
//export HaloSetTransportMode
func HaloSetTransportMode(cMode *C.char) *C.char {
	m := C.GoString(cMode)
	switch m {
	case modePrivate, modeBalanced, modeFast:
	default:
		m = modePrivate
	}
	prev := currentMode()
	transportMode.Store(m)
	if prev != m {
		log.Printf("transport: mode %s -> %s", prev, m)
		// the cached client is bound to one route; drop it so the next
		// connection is built the new way.
		nostrResetClient()
	}
	return C.CString(m)
}

//export HaloTransportMode
func HaloTransportMode() *C.char {
	return C.CString(currentMode())
}
