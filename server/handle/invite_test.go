// SPDX-License-Identifier: GPL-3.0-or-later
package main

import "testing"

// the invite goes into an href on the public page. html.EscapeString stops it
// breaking out of the attribute and does nothing about the scheme, so
// "javascript:alert(1)" used to render as a working link and run on this
// origin the moment someone pressed "message on kryfo".
func TestInviteSchemesThatMustBeRefused(t *testing.T) {
	bad := []struct{ why, s string }{
		{"the bug", `javascript:alert(document.domain)`},
		{"upper case scheme", `JavaScript:alert(1)`},
		{"with a newline in it", "java\nscript:alert(1)"},
		{"data url", `data:text/html,<script>alert(1)</script>`},
		{"vbscript", `vbscript:msgbox(1)`},
		{"an ordinary web link", `https://example.com/`},
		{"a different app's scheme", `otherapp://share?id=a&onion=b&xpub=c`},
		{"right scheme, wrong host", `kryfo://evil?id=a&onion=b&xpub=c`},
		{"no id", `kryfo://share?onion=b&xpub=c`},
		{"no onion", `kryfo://share?id=a&xpub=c`},
		{"v1 with no xpub", `kryfo://share?id=a&onion=b`},
		{"v2 with no bundle", `kryfo://share?id=a&onion=b&v=2`},
		{"v3 with no bundle", `kryfo://share?id=a&onion=b&v=3&fc=ff`},
		{"a version we never made", `kryfo://share?id=a&onion=b&v=9&bundle=x`},
		{"empty", ``},
	}
	for _, c := range bad {
		if inviteOK(c.s) {
			t.Errorf("accepted %s: %q", c.why, c.s)
		}
	}
}

// and everything the app has ever built has to keep working, or someone loses
// the page they already published.
func TestEveryInviteTheAppBuildsIsAccepted(t *testing.T) {
	good := []struct{ why, s string }{
		{"v1, buildHaloUri", `kryfo://share?id=chronic-army-absurd&onion=cztqhsmfhvlt5oit4em6bijxgyvhetqbspdyme6sj6dse2qrxdmef2qd.onion&xpub=BV4MAvcjaZl4VhBvEKPbMMRDEDX8F9xG3YNi`},
		{"v2, buildHaloUriV2", `kryfo://share?id=a-b-c&onion=2dlpakwswmp5sgkbvu667hhmv6i5rd4flpdeq2z5rhnhs43afkwr3kad.onion&v=2&bundle=eyJyZWdpc3RyYXRpb25JZCI6MX0=`},
		{"v3, buildHaloUriV3", `kryfo://share?id=food-october-trial&onion=2dlpakwswmp5sgkbvu667hhmv6i5rd4flpdeq2z5rhnhs43afkwr3kad.onion&v=3&bundle=eyJyZWdpc3RyYXRpb25JZCI6MTI0ODV9&fc=035655278b6c21ce09a7222f7aa6abe398edbb0d7fca1c28e566d7938b08b15c`},
		{"v3 without the optional fc", `kryfo://share?id=x&onion=y.onion&v=3&bundle=zz`},
	}
	for _, c := range good {
		if !inviteOK(c.s) {
			t.Errorf("refused %s: %q", c.why, c.s)
		}
	}
}

// 8000 is the existing ceiling and a v3 bundle is not small; keep both ends.
func TestInviteLength(t *testing.T) {
	base := `kryfo://share?id=a&onion=b.onion&v=3&bundle=`
	if !inviteOK(base + str(7000)) {
		t.Error("a real-sized v3 bundle was refused")
	}
	if inviteOK(base + str(9000)) {
		t.Error("something past the 8000 ceiling was accepted")
	}
}

func str(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = 'a'
	}
	return string(b)
}
