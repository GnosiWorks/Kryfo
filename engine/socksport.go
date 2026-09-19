// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"log"
	"net"
	"sync/atomic"
)

// bine starts tor with "--SocksPort auto", and tor picks a fresh ephemeral
// port every time it opens that listener. DisableNetwork=1 closes it and
// DisableNetwork=0 opens a new one somewhere else - so every bounce moves the
// port. t.Dialer asks the control port for net/listeners/socks once, at build
// time, and caches the answer, which means every http.Client built before a
// bounce dials a port that is refusing connections afterwards.
//
// that cost a handle claim its whole 30s timeout on a phone whose relays were
// perfectly healthy, because relays heal through relaysAllDead() and a
// one-shot request has nothing to heal it.
//
// so the port is chosen once here, at process start, and handed to tor
// explicitly. a listener that reopens on the same port survives a bounce, and
// a dialer built before one keeps working. the cache resets in reconnectOn,
// torResume and startListener stay as the second line: if this pin ever fails
// they are what still makes it recover.

var pinnedSocks int32

// a port nobody is using, found by letting the kernel choose one and handing
// it straight back. there is a race between closing this and tor binding it,
// which is why startListener can fall back to auto.
func choosePinnedSocks() int {
	if p := int(atomic.LoadInt32(&pinnedSocks)); p != 0 {
		return p
	}
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Printf("halo: could not pick a socks port (%v) - tor will choose", err)
		return 0
	}
	p := l.Addr().(*net.TCPAddr).Port
	l.Close()
	atomic.StoreInt32(&pinnedSocks, int32(p))
	log.Printf("halo: socks port pinned to %d for this process", p)
	return p
}

func socksPin() int { return int(atomic.LoadInt32(&pinnedSocks)) }

// give up on the pin for the rest of the process and let tor choose. the
// cache resets carry it from here.
func dropSocksPin(why string) {
	if p := socksPin(); p != 0 {
		log.Printf("halo: giving up the pinned socks port %d (%s) - "+
			"falling back to auto, the client resets have to carry it", p, why)
	}
	atomic.StoreInt32(&pinnedSocks, 0)
}
