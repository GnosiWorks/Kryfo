// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the app fills every frame out to one of five sizes inside its encryption
// (mobile/lib/wire_pad.dart). each size is a range of rumor lengths: a
// plain message, an opener and a room or bundle frame of that size all fall
// inside it, and every length in it wraps to one gift wrap. one past either
// end wraps to another.

import (
	"strings"
	"testing"

	nostr2 "github.com/nbd-wtf/go-nostr"
)

var padSizes = []struct {
	lo, hi, wrap int
	// a plain message's signal wire, an opener's, a room frame's rumor
	at []int
}{
	{819, 1330, 3949, []int{1200, 1312, 1200}},
	{2867, 3890, 8729, []int{3760, 3872, 3760}},
	{10035, 14130, 27841, []int{14000, 14112, 14000}},
	{20275, 28466, 55149, []int{28252, 28364, 28340}},
	{32563, 40754, 76993, []int{40604, 40716, 40604}},
}

func padPair(t *testing.T) (xid, xid, string) {
	t.Helper()
	me, err := xidFromPrivHex(strings.Repeat("11", 32))
	if err != nil {
		t.Fatal(err)
	}
	other, err := xidFromPrivHex(strings.Repeat("22", 32))
	if err != nil {
		t.Fatal(err)
	}
	_, fcPk, err := fcKeysFrom(other.priv, 0)
	if err != nil {
		t.Fatal(err)
	}
	return me, other, fcPk
}

func TestPadSizesWrapAsOne(t *testing.T) {
	me, other, fcPk := padPair(t)
	size := func(n int) (int, int) {
		msg := strings.Repeat("A", n)
		gw, err := nip17WrapAs(me, other.pub, msg)
		if err != nil {
			return -1, -1
		}
		fc, err := nip17WrapFirstContactAs(me, other.pub, fcPk, msg)
		if err != nil {
			t.Fatal(err)
		}
		return len(gw.String()), len(fc.String())
	}
	for _, s := range padSizes {
		for _, n := range append([]int{s.lo, s.hi}, s.at...) {
			if n < s.lo || n > s.hi {
				t.Fatalf("%d is outside %d..%d", n, s.lo, s.hi)
			}
			pair, first := size(n)
			if pair != s.wrap || first != s.wrap {
				t.Fatalf("rumor of %d wraps to %d and %d, want %d", n, pair, first, s.wrap)
			}
		}
		for _, n := range []int{s.lo - 1, s.hi + 1} {
			if pair, _ := size(n); pair == s.wrap {
				t.Fatalf("rumor of %d still wraps to %d", n, s.wrap)
			}
		}
	}
}

func TestPadFillerIsSealed(t *testing.T) {
	me, other, _ := padPair(t)
	frame := `halo/1:{"pz":"` + strings.Repeat("0", 900) + `","m":"meet at noon"}`
	gw, err := nip17WrapAs(me, other.pub, frame)
	if err != nil {
		t.Fatal(err)
	}
	out := gw.String()
	for _, w := range []string{`"pz"`, "000000", "meet at noon"} {
		if strings.Contains(out, w) {
			t.Fatalf("the wrap shows %q", w)
		}
	}
	back, err := nip17UnwrapAs(other, me.pub, gw)
	if err != nil || back != frame {
		t.Fatalf("unwrap: %v", err)
	}
}

// the app counts a rumor's length as this json escapes it
func TestPadRumorEscapes(t *testing.T) {
	rumor := func(c string) int {
		return len(nostr2.Event{Kind: 14, Content: c}.String())
	}
	if n := rumor("a\"b\\c\x01é😀") - rumor(""); n != 19 {
		t.Fatalf("escaped to %d, want 19", n)
	}
}
