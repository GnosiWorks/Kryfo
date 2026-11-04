// SPDX-License-Identifier: GPL-3.0-or-later
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/hex"
	"log"
	"sync/atomic"
	"unsafe"

	"fiatjaf.com/nostr"
	"github.com/halo/engine/cstr"
)

// every c string from dart goes through this, never C.GoString
func goStr(p *C.char) string { return cstr.String(unsafe.Pointer(p)) }

// a secret c string from dart, as bytes the caller clears once used
func goSecret(p *C.char) []byte { return cstr.Bytes(unsafe.Pointer(p)) }

// [h] as exactly [n] bytes, decoded without a go string: false for
// anything else
func hexSecret(h []byte, n int) ([]byte, bool) {
	if len(h) != 2*n {
		return nil, false
	}
	out := make([]byte, n)
	if _, err := hex.Decode(out, h); err != nil {
		clear(out)
		return nil, false
	}
	return out, true
}

// a key back to dart as hex, written straight into c memory: no go string
// holds it. dart zeroes the copy it takes and frees it with HaloFree
func cHexSecret(b []byte) *C.char {
	const digits = "0123456789abcdef"
	p := C.malloc(C.size_t(2*len(b) + 1))
	out := unsafe.Slice((*byte)(p), 2*len(b)+1)
	for i, v := range b {
		out[2*i] = digits[v>>4]
		out[2*i+1] = digits[v&15]
	}
	out[2*len(b)] = 0
	return (*C.char)(p)
}

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
	clear(pollInflight)
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
