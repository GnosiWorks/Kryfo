// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the addresses a relay walked to the bottom of their window in this
// process. a linked computer's start waits on its phone's pair before it
// shows a chat or sends anything: a removal the phone sent while it was
// closed is read first

import "C"

import "sync"

var addrsCaught sync.Map

// a walk of rcvPk reached the bottom of its window on a relay
func noteAddrCaught(rcvPk string) { addrsCaught.Store(rcvPk, struct{}{}) }

func addrCaught(rcvPk string) bool {
	_, ok := addrsCaught.Load(rcvPk)
	return ok
}

// "1" once a relay walked the address [peerArg] names (as a listen takes
// it, a device pair's too) to the bottom of its window in this process,
// "0" before, "error: ..." for an arg that names none
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
	if addrCaught(rcvPk) {
		return "1"
	}
	return "0"
}
