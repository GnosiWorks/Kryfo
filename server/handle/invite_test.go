// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"
)

// the invite goes into an href on the public page, and html escaping does
// nothing about the scheme.
func TestInviteRefusesBadSchemes(t *testing.T) {
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

// every shape the app builds has to pass, or someone loses a published page
func TestInviteAcceptsAppShapes(t *testing.T) {
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

// an invite is url text: printable ascii with no quote or backslash, which
// covers every character the app puts in one
func TestInviteTakesOnlyURLCharacters(t *testing.T) {
	base := `kryfo://share?id=a-b-c&onion=b.onion&v=3&bundle=`
	if !inviteOK(base + `AZaz09+/=-._~%20:@!$'()*,` + "&fc=ff") {
		t.Error("url characters were refused")
	}
	for _, c := range []string{`"`, `\`, " ", "\t", "\x7f", "\u00e9", "\u2028", "\xff"} {
		if inviteOK(base + "zz" + c + "zz") {
			t.Errorf("took %q", c)
		}
	}
}

// the longest invite the app builds: v3, eight-letter words, a five digit
// registration id and the bundle as makePreKeyBundleB64 (mobile/lib/main.dart)
// writes it
func longestInvite() string {
	key := base64.StdEncoding.EncodeToString(make([]byte, 33))
	bundle, _ := json.Marshal(struct {
		RegistrationID        int    `json:"registrationId"`
		DeviceID              int    `json:"deviceId"`
		PreKeyID              int    `json:"preKeyId"`
		PreKeyPublic          string `json:"preKeyPublic"`
		SignedPreKeyID        int    `json:"signedPreKeyId"`
		SignedPreKeyPublic    string `json:"signedPreKeyPublic"`
		SignedPreKeySignature string `json:"signedPreKeySignature"`
		IdentityKey           string `json:"identityKey"`
	}{16380, 1, 999999, key, 1, key, base64.StdEncoding.EncodeToString(make([]byte, 64)), key})
	return "kryfo://share?id=absolute-abstract-category&onion=" + strings.Repeat("a", 56) +
		".onion&v=3&bundle=" + base64.StdEncoding.EncodeToString(bundle) +
		"&fc=" + strings.Repeat("f", 64)
}

// every invite the app builds fits, and not much more
func TestInviteLength(t *testing.T) {
	inv := longestInvite()
	if len(inv) != 700 {
		t.Fatalf("the longest app invite is %d bytes, the ceiling was sized for 700", len(inv))
	}
	if !inviteOK(inv) {
		t.Error("the longest app invite was refused")
	}
	base := `kryfo://share?id=a&onion=b.onion&v=3&bundle=`
	if !inviteOK(base + str(maxInvite-len(base))) {
		t.Error("an invite at the ceiling was refused")
	}
	if inviteOK(base + str(maxInvite-len(base)+1)) {
		t.Error("an invite past the ceiling was taken")
	}
}

func str(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = 'a'
	}
	return string(b)
}
