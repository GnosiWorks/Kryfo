// SPDX-License-Identifier: GPL-3.0-or-later
// a linked device's tor: a client only. it reaches relays, the phone's
// onion and the fast route, and publishes no onion of its own (decision 4
// of the linked devices plan). the same one tor per process as a phone's,
// never closed: only the onion service is left out, or taken down.

package main

import "C"

import (
	"log"
	"sync/atomic"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// what a start answers in place of an onion while tor runs as a client
const torClientAddr = "client"

// on for the rest of the process once set: a linked device stays one until
// it is wiped, and a wipe ends the process
var torClient atomic.Bool

// a start asked for on a client tor: nothing to publish, and a tor that runs
// (or ran) in this process is never started again
func torClientOnly() bool { return torClient.Load() }

// the status a tor at 100% has: publishing on a phone, while its onion goes
// up; bootstrapped on a client, which has none
func upStatus() string {
	if torClientOnly() {
		return "bootstrapped"
	}
	return "publishing"
}

// HaloTorClientOnly makes this process's tor a client from here on. called
// before the first start on a linked device, and right after a link, whose
// process published the new device's onion already: that onion goes down.
// "ok", or "error: ..." when tor did not answer the take-down; the address
// is forgotten either way and the next start tries again.
//
//export HaloTorClientOnly
func HaloTorClientOnly() *C.char { return C.CString(torClientOn()) }

func torClientOn() string {
	torClient.Store(true)
	// a start under way sees the flag before its listen, or drops what it
	// listened on after it: either way it is not waited for here
	if !startMu.TryLock() {
		return "ok"
	}
	defer startMu.Unlock()
	return dropOnion()
}

// takes this process's onion service down, with startMu held. tor removes a
// service only on the control connection that added it, bine's, which has
// no deadline of its own: ctrlFallback bounds the wait. the local listener
// closes first, so nothing more is let in whatever tor does
func dropOnion() string {
	mu.Lock()
	t, l := torNode, listener
	had := myAddr != ""
	myAddr = ""
	mu.Unlock()
	if had {
		forgetPublished()
	}
	o, _ := l.(*tor.OnionService)
	if o == nil {
		mu.Lock()
		if listener == l {
			listener = nil
		}
		mu.Unlock()
		return "ok"
	}
	if o.LocalListener != nil {
		_ = o.LocalListener.Close()
	}
	id := o.ID
	err := ctrlFallback(t, "DEL_ONION", func(c *control.Conn) error {
		return c.DelOnion(id)
	})
	// tor saying no means it holds no such service: nothing is published
	if err != nil && !torRefused(err) {
		log.Printf("halo: the onion stays up until tor answers: %v", err)
		return "error: " + err.Error()
	}
	mu.Lock()
	if listener == l {
		listener = nil
	}
	mu.Unlock()
	log.Println("halo: tor runs as a client, no onion of its own")
	return "ok"
}

// a tor whose onion went: the status a published onion gave is taken back
func forgetPublished() {
	publishedOnce.Store(false)
	notePublished()
	statusMu.Lock()
	hsdirUploads = 0
	back := torStatus == "publishing" || torStatus == "reachable"
	statusMu.Unlock()
	if back {
		setStatus("bootstrapped")
	}
}
