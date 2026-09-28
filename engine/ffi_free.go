// SPDX-License-Identifier: GPL-3.0-or-later
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"log"
	"sync/atomic"
	"unsafe"

	"fiatjaf.com/nostr"
)

// every string the engine returns is malloc'd here by C.CString. dart copies
// it and hands it back through this, so the allocator that made it frees it.
//
//export HaloFree
func HaloFree(p *C.char) {
	if p != nil {
		C.free(unsafe.Pointer(p))
	}
}

// the app is about to delete its files: every relay subscription stops, tor
// leaves the network and the engine writes nothing more into the data dir,
// so nothing the wipe removes comes back before the process ends. "ok", or
// "error: ..." when tor would not take the setting.
//
//export HaloWipeHold
func HaloWipeHold() *C.char { return C.CString(wipeHold()) }

func wipeHold() string {
	engineHeld.Store(true)
	nostrMu.Lock()
	for k, cancel := range nostrSubs {
		cancel()
		delete(nostrSubs, k)
	}
	nostrInbox, nostrInboxDone = nil, nil
	nostrMu.Unlock()
	return torStop()
}

// the relay library's own log lines pass the same gate as the engine's
func init() {
	nostr.InfoLogger.SetOutput(libLog{})
	nostr.DebugLogger.SetOutput(libLog{})
}

type libLog struct{}

func (libLog) Write(p []byte) (int, error) {
	if atomic.LoadInt32(&debugOn) == 0 {
		return len(p), nil
	}
	return log.Writer().Write(p)
}
