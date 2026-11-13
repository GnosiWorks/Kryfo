// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a linked computer that is not confirmed as linked, or that its phone
// removed, sends nothing: no wrap to a relay, no line to a door, no file
// to the service, nothing the engine sends again on its own (topup.go).
// the app holds its own sends too; this is what nothing in the app reaches

import "C"

import (
	"errors"
	"sync/atomic"
)

var sendHeld atomic.Bool

var errSendHeld = errors.New("held: not confirmed as linked")

// 1 holds every send from here on, 0 lets them go again
//
//export HaloSendHold
func HaloSendHold(on C.int) *C.char {
	sendHeld.Store(on != 0)
	return C.CString("ok")
}
