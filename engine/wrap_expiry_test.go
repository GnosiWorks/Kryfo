// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strconv"
	"testing"
	"time"

	nostr2 "github.com/nbd-wtf/go-nostr"
)

const (
	twoWeeks = 14 * 24 * 3600
	oneDay   = 24 * 3600
)

func expiryOf(t *testing.T, ev nostr2.Event) int64 {
	t.Helper()
	tg := ev.Tags.Find("expiration")
	if len(tg) < 2 {
		t.Fatal("wrap has no expiration")
	}
	v, err := strconv.ParseInt(tg[1], 10, 64)
	if err != nil {
		t.Fatal(err)
	}
	return v
}

// the tag must never undercut two weeks, and must not carry the send second
func TestWrapExpiryHidesSendTime(t *testing.T) {
	aPriv, aPub := newIdentity(t)
	_, bPub := newIdentity(t)
	_, fcPk, err := fcKeysFrom(aPriv, 0)
	if err != nil {
		t.Fatal(err)
	}
	me := xid{priv: aPriv, pub: aPub}
	var offs []int64
	for i := 0; i < 40; i++ {
		before := time.Now().Unix()
		var ev nostr2.Event
		if i%2 == 0 {
			ev, err = nip17WrapAs(me, bPub, "hi")
		} else {
			ev, err = nip17WrapFirstContactAs(me, bPub, fcPk, "hi")
		}
		if err != nil {
			t.Fatal(err)
		}
		after := time.Now().Unix()
		exp := expiryOf(t, ev)
		if exp < after+twoWeeks {
			t.Fatalf("expiration %d is under two weeks", exp)
		}
		if exp > after+twoWeeks+oneDay {
			t.Fatalf("expiration %d is past two weeks and a day", exp)
		}
		offs = append(offs, exp-before-twoWeeks)
	}
	// with no spread every offset sits within a second or two of zero
	lo, hi := offs[0], offs[0]
	for _, o := range offs {
		lo, hi = min(lo, o), max(hi, o)
	}
	if hi-lo < int64(time.Hour/time.Second) {
		t.Fatalf("expirations spread over %d s only", hi-lo)
	}
}
