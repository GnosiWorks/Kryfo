// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the one door's spy over the link channel: the rendezvous relays and the onion door see nothing of the account
// in the clear. no key of the phone or the new device, no key number, no
// onion of the phone in any form: only the link's own one-off keys and what
// is sealed under them

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"strings"
	"sync"
	"testing"

	"github.com/halo/engine/devices"
)

// every form a key takes on a wire: hex both cases, base64 and base64url
// at each of the three places a key can start in a longer run
func spyForms(k []byte) []string {
	out := []string{hex.EncodeToString(k), strings.ToUpper(hex.EncodeToString(k))}
	for lead := 0; lead < 3; lead++ {
		b := append(make([]byte, lead), k...)
		for _, enc := range []*base64.Encoding{base64.StdEncoding, base64.URLEncoding, base64.RawStdEncoding, base64.RawURLEncoding} {
			s := enc.EncodeToString(b)
			from := (lead*8+5)/6 + 1
			out = append(out, s[from:from+36])
		}
	}
	return out
}

func TestTheLinkChannelShowsNothingOfTheAccount(t *testing.T) {
	w := newLinkWorld(t)
	var mu sync.Mutex
	var lines []string
	door := linkDialNow
	linkDialNow = func(ctx context.Context, onion, line string) error {
		mu.Lock()
		lines = append(lines, line)
		mu.Unlock()
		return door(ctx, onion, line)
	}
	jid, pid, _ := w.toDigits(t)
	waitState(t, jid, lsDigits)
	waitState(t, pid, lsDigits)
	_, dev := w.toBundles(t, jid, pid)
	// the phone keeps it and both runs end, as an app does
	pt := link(t, "take", map[string]any{"link": pid})
	if pt.Err != "" {
		t.Fatalf("take: %s", pt.Err)
	}
	w.as(w.pState)
	var o devOut
	call(t, devSessionJSON("own_mine", jsonOf(t, map[string]any{"ident": 0, "list": pt.List})), &o)
	if o.Err != "" {
		t.Fatalf("own_mine: %s", o.Err)
	}
	if k := link(t, "kept", map[string]any{"link": pid}); k.Err != "" {
		t.Fatalf("kept: %s", k.Err)
	}
	waitState(t, jid, lsDone)
	if jt := link(t, "take", map[string]any{"link": jid}); jt.Err != "" {
		t.Fatalf("take: %s", jt.Err)
	}
	if len(lines) == 0 {
		t.Fatal("nothing went to the phone's door")
	}

	marks := map[string]string{
		testPhoneOnion:                    "the phone's onion",
		testPhoneOnion + ".onion":         "the phone's onion",
		devices.KeyNumber(w.phone.id.pub): "the phone's key number",
		devices.KeyNumber(w.devKey.pub):   "the device's key number",
	}
	for name, k := range map[string][]byte{
		"the phone's identity key": w.phone.id.pub[:],
		"the device's key":         w.devKey.pub[:],
		// the bare 32 bytes, as a v4 address or an x key carries them
		"the phone's x key":  w.phone.id.pub[1:],
		"the device's x key": w.devKey.pub[1:],
	} {
		for _, f := range spyForms(k) {
			marks[f] = name
		}
	}
	look := func(where, s string) {
		low := strings.ToLower(s)
		for m, name := range marks {
			if strings.Contains(low, strings.ToLower(m)) {
				t.Errorf("%s carries %s", where, name)
			}
		}
	}

	w.relay.mu.Lock()
	var n int
	for pk, evs := range w.relay.evs {
		look("a rendezvous address", pk)
		for _, ev := range evs {
			n++
			raw, err := json.Marshal(ev)
			if err != nil {
				t.Fatal(err)
			}
			look("an event on the rendezvous", string(raw))
			if ev.PubKey.Hex() == hex.EncodeToString(w.phone.id.pub[1:]) {
				t.Error("an event signed by the phone's own key")
			}
		}
	}
	w.relay.mu.Unlock()
	if n < 4 {
		t.Fatalf("only %d events on the rendezvous", n)
	}
	mu.Lock()
	for _, l := range lines {
		look("a line to the phone's door", l)
	}
	mu.Unlock()
	if dev.ID < 2 {
		t.Fatalf("placed as %d", dev.ID)
	}
}
