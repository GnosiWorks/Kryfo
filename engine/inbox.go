// SPDX-License-Identifier: GPL-3.0-or-later
// the onion door's limits. anyone holding the onion address can open a
// connection to it, so the door takes only what a real message looks like,
// only so much of it, and only so many at once. before this a flood of junk
// lines cost the phone a trial decrypt each against every session it held,
// with no cap on connections, bytes or repeats.
package main

import (
	"crypto/sha256"
	"encoding/base64"
)

const (
	inboxMaxConns = 8
	inboxMaxLines = 256
	inboxMaxBytes = 4 << 20
	// a wrapped 16k media slice is about 40k on the wire; nothing honest
	// comes near this
	inboxMaxLine = 128 * 1024
)

var (
	inboxSlots = make(chan struct{}, inboxMaxConns)
	// both guarded by mu, both reset when dart drains
	inboxBytes  int
	inboxRecent = map[[32]byte]struct{}{}
)

// what a line has to look like before it may cost a trial decrypt: standard
// base64 that opens to a signal message, first byte whisper (2) or prekey
// (3), with a body behind it. json control frames never ride this lane.
func inboxShapeOK(line string) bool {
	if len(line) < 8 || len(line) > inboxMaxLine {
		return false
	}
	raw, err := base64.StdEncoding.DecodeString(line)
	if err != nil || len(raw) < 2 {
		return false
	}
	return raw[0] == 2 || raw[0] == 3
}

// queue a line if there is room and it is not already waiting. reports
// whether it was taken; the caller acks only then.
func inboxPut(line string) bool {
	h := sha256.Sum256([]byte(line))
	mu.Lock()
	defer mu.Unlock()
	if _, dup := inboxRecent[h]; dup {
		return false
	}
	if len(inbox) >= inboxMaxLines || inboxBytes+len(line) > inboxMaxBytes {
		return false
	}
	inbox = append(inbox, line)
	inboxBytes += len(line)
	inboxRecent[h] = struct{}{}
	return true
}

// called under mu when dart takes the inbox
func inboxDrained() {
	inbox = inbox[:0]
	inboxBytes = 0
	for k := range inboxRecent {
		delete(inboxRecent, k)
	}
}
