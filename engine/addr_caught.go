// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the addresses each of our stores walked to the bottom of their window in
// this process. a linked computer's start waits on its phone's pair before
// it shows a chat or sends anything: a removal the phone sent while it was
// closed is read first. the phone's send ends at the first store that took
// it, so one store walked says nothing of the other, and a public relay
// says nothing at all

import "C"

import "sync"

// rcvPk|store, for each of our stores that walked rcvPk
var addrsCaught sync.Map

// rcvPk to the tag its lines carry in the inbox
var addrTags sync.Map

// a walk of rcvPk reached the bottom of its window on one of our stores
func noteAddrCaught(rcvPk, store, tag string) {
	addrTags.Store(rcvPk, tag)
	addrsCaught.Store(rcvPk+"|"+store, struct{}{})
}

func addrCaughtClear() {
	addrsCaught.Clear()
	addrTags.Clear()
}

// "1" once every store of ours in the relay list walked the address [peerArg]
// names (as a listen takes it, a device pair's too) to the bottom of its
// window in this process and none of its lines waits for the app any more,
// "p" once one store did, "0" before, "error: ..." for an arg that names
// none
//
//export HaloAddrCaught
func HaloAddrCaught(cIdent C.int, cPeerArg *C.char) *C.char {
	return C.CString(addrCaughtOf(identArg(cIdent), goStr(cPeerArg)))
}

func addrCaughtOf(ident int, peerArg string) string {
	c, _, err := pairArg(ident, peerArg)
	if err != nil {
		return "error: " + err.Error()
	}
	_, rcvPk, err := c.rcvAddress()
	if err != nil {
		return "error: " + err.Error()
	}
	nostrMu.Lock()
	stores := storesIn(nostrRelays)
	nostrMu.Unlock()
	n := 0
	for _, st := range stores {
		if _, ok := addrsCaught.Load(rcvPk + "|" + st); ok {
			n++
		}
	}
	switch {
	case n == 0:
		return "0"
	case n < len(stores) || linesWaiting(rcvPk):
		return "p"
	}
	return "1"
}

// a line of rcvPk is in the inbox, held back while another relay walks it,
// or handed to the app and not kept yet
func linesWaiting(rcvPk string) bool {
	v, ok := addrTags.Load(rcvPk)
	if !ok {
		return false
	}
	tag := v.(string)
	nostrMu.Lock()
	defer nostrMu.Unlock()
	for _, l := range nostrInbox {
		if lineTag(l) == tag {
			return true
		}
	}
	for _, b := range pollInflight {
		for _, l := range b.lines {
			if lineTag(l) == tag {
				return true
			}
		}
	}
	return false
}
