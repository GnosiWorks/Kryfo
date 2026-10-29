// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html"
	"image/png"
	"io"
	"net/http"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"testing"
)

const goodQuery = `id=food-october-trial&onion=2dlpakwswmp5sgkbvu667hhmv6i5rd4flpdeq2z5rhnhs43afkwr3kad.onion&v=3&bundle=eyJyZWdpc3RyYXRpb25JZCI6MTI0ODV9&fc=035655278b6c21ce09a7222f7aa6abe398edbb0d7fca1c28e566d7938b08b15c`

func randB64(t *testing.T, n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		t.Fatal(err)
	}
	return base64.StdEncoding.EncodeToString(b)
}

// a v3 query as the app builds it, with the kyber prekey in its card
func fullV3(t *testing.T) string {
	card, _ := json.Marshal(map[string]any{
		"registrationId": 16380, "deviceId": 1, "preKeyId": 16777215,
		"preKeyPublic": randB64(t, 33), "signedPreKeyId": 1,
		"signedPreKeyPublic": randB64(t, 33), "signedPreKeySignature": randB64(t, 64),
		"kyberPreKeyId": 16777215, "kyberPreKeyPublic": randB64(t, 1569),
		"kyberPreKeySignature": randB64(t, 64), "identityKey": randB64(t, 33),
	})
	fc := make([]byte, 32)
	_, _ = rand.Read(fc)
	return "id=coconut-umbrella-squirrel&onion=" + strings.Repeat("a", 56) + ".onion&v=3&bundle=" +
		base64.StdEncoding.EncodeToString(card) + "&fc=" + hex.EncodeToString(fc)
}

// a v4 link's query with a face, an onion, a bundle and six devices
func fullV4(t *testing.T) string {
	b := make([]byte, 2460)
	_, _ = rand.Read(b)
	return "v=4&i=" + base64.RawURLEncoding.EncodeToString(b)
}

func fetch(t *testing.T, c *http.Client, u string) (*http.Response, string) {
	return fetchIn(t, c, u, "")
}

func fetchIn(t *testing.T, c *http.Client, u, lang string) (*http.Response, string) {
	t.Helper()
	req, _ := http.NewRequest("GET", u, nil)
	if lang != "" {
		req.Header.Set("Accept-Language", lang)
	}
	resp, err := c.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	return resp, string(b)
}

func hasGetKryfo(t *testing.T, what, b string) {
	t.Helper()
	for _, s := range []string{
		"It is on Android for now.",
		`href="https://kryfo.app/download"`,
		`href="https://f-droid.org/packages/app.kryfo/"`,
		"No analytics, no cookies, no logs",
	} {
		if !strings.Contains(b, s) {
			t.Errorf("%s: no %q", what, s)
		}
	}
	if strings.Contains(b, " style=") {
		t.Errorf("%s: a style attribute", what)
	}
}

func scriptOf(b string) []string {
	var out []string
	for _, m := range regexp.MustCompile(`(?s)<script>(.*?)</script>`).FindAllStringSubmatch(b, -1) {
		out = append(out, m[1])
	}
	return out
}

// the browser never sends the part after the '#': a full-size invite link
// asks the server for /i alone, and that is a page with the button's script
func TestInvitePageServesTheScript(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	resp, b := fetch(t, srv.Client(), srv.URL+"/i")
	if resp.StatusCode != 200 {
		t.Fatalf("status %d", resp.StatusCode)
	}
	if !strings.Contains(b, `<a class=btn id=go hidden>Open in Kryfo</a>`) ||
		!strings.Contains(b, `id=bad hidden>This link is missing a part.`) {
		t.Fatalf("no hidden button and line:\n%s", b)
	}
	if s := scriptOf(b); len(s) != 1 || s[0] != inviteJS {
		t.Fatalf("scripts: %q", s)
	}
	hasGetKryfo(t, "invite", b)
	for k, v := range map[string]string{
		"Cache-Control":   "no-store",
		"Referrer-Policy": "no-referrer",
		"Vary":            "Accept-Language",
	} {
		if resp.Header.Get(k) != v {
			t.Errorf("%s: %q", k, resp.Header.Get(k))
		}
	}
	if resp.Header.Get("Set-Cookie") != "" {
		t.Error("a cookie")
	}
}

// a query (older test builds put the invite there) is never read back
func TestInvitePageReadsNoQuery(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	_, plain := fetch(t, srv.Client(), srv.URL+"/i")
	for _, q := range []string{
		goodQuery,
		fullV3(t),
		"javascript:alert(1)",
		"id=%3Cscript%3Ezzmark%3C/script%3E&onion=x&v=3&bundle=zz",
	} {
		resp, b := fetch(t, srv.Client(), srv.URL+"/i?"+q)
		if resp.StatusCode != 200 || b != plain {
			t.Errorf("%.40q: the page changed with the query", q)
		}
		if strings.Contains(b, "food-october") || strings.Contains(b, "zzmark") ||
			strings.Contains(b, "kryfo://share?id") || strings.Contains(b, "javascript:") {
			t.Errorf("%.40q: reflected", q)
		}
	}
	req, _ := http.NewRequest("POST", srv.URL+"/i", nil)
	if resp, err := srv.Client().Do(req); err != nil || resp.StatusCode != http.StatusMethodNotAllowed {
		t.Errorf("post: %v %v", resp, err)
	}
}

// the script: no request of any kind, the button only ever kryfo://share?,
// and the checks pass the invites the app makes at their real sizes
func TestInviteScriptTakesRealInvites(t *testing.T) {
	for _, bad := range []string{
		"fetch", "XMLHttpRequest", "WebSocket", "sendBeacon", "import", "eval",
		"Function(", "innerHTML", "outerHTML", "write(", ".src", "location.href",
		"location.assign", "location.replace", "open(", "Image", "setTimeout", "cookie", "Storage",
	} {
		if strings.Contains(inviteJS, bad) {
			t.Errorf("the script has %q", bad)
		}
	}
	if n := strings.Count(inviteJS, ".href="); n != 1 || !strings.Contains(inviteJS, `a.href="kryfo://share?"+h;`) {
		t.Errorf("the button is not only kryfo://share?: %d", n)
	}
	if !strings.Contains(inviteCSP, "default-src 'none'") || strings.Contains(inviteCSP, "connect-src") {
		t.Errorf("csp lets the page connect: %s", inviteCSP)
	}
	// the shape check, as the script runs it
	m := regexp.MustCompile(`h\.length<=(\d+)&&/(\^\[[^\]]+\]\+\$)/\.test\(h\)`).FindStringSubmatch(inviteJS)
	if m == nil {
		t.Fatal("no shape check in the script")
	}
	max, _ := strconv.Atoi(m[1])
	shape := regexp.MustCompile(m[2])
	v3, v4 := fullV3(t), fullV4(t)
	if len(v3) < 3500 || len(v4) < 3200 {
		t.Fatalf("fixtures too small: %d %d", len(v3), len(v4))
	}
	for _, q := range []string{goodQuery, v3, v4, "id=a-b-c&onion=x.onion&xpub=ab"} {
		if len(q) > max || !shape.MatchString(q) {
			t.Errorf("refuses a real invite of %d: %.60q", len(q), q)
		}
	}
	for _, q := range []string{
		"", "javascript:alert(1)", `id=a"b`, "id=a<b", "id=a b", "id=a'b", "id=a\\b",
		"id=a#b", "id=a⁩", strings.Repeat("a", max+1),
	} {
		if len(q) <= max && shape.MatchString(q) {
			t.Errorf("takes %.40q", q)
		}
	}
}

func TestPreviewCardIsGenericAndLocal(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	_, b := fetchIn(t, c, srv.URL+"/i?"+goodQuery, "")
	for _, s := range []string{
		`<title>Message me on Kryfo</title>`,
		`<meta property=og:title content="Message me on Kryfo">`,
		`<meta property=og:description content="Private messenger, no phone number, open source">`,
		`<meta property=og:image content="https://relay.kryfo.app/handle/card.png">`,
		`<meta name=twitter:card content=summary_large_image>`,
		`<html lang=en>`,
	} {
		if !strings.Contains(b, s) {
			t.Errorf("no %q", s)
		}
	}
	for lang, want := range map[string]string{
		"de-DE,de;q=0.9,en;q=0.8": `<html lang=de><meta charset=utf-8>
<title>Schreib mir auf Kryfo</title>`,
		"fa":                 `<html lang=fa dir=rtl>`,
		"zh-TW":              `content="在 Kryfo 傳訊息給我"`,
		"zh-CN,zh;q=0.9":     `content="在 Kryfo 上给我发消息"`,
		"xx-YY, en;q=0.1":    `<html lang=en>`,
		"en;q=0.5, ar;q=0.9": `<html lang=ar dir=rtl>`,
		"fr;q=0, it":         `<html lang=it>`,
		"pt-BR":              `href="https://kryfo.app/pt/download"`,
		"hi-IN":              `href="https://kryfo.app/download"`,
	} {
		if _, b := fetchIn(t, c, srv.URL+"/i", lang); !strings.Contains(b, want) {
			t.Errorf("%s: no %q", lang, want)
		}
	}
	resp, err := c.Get(srv.URL + "/handle/card.png")
	if err != nil {
		t.Fatal(err)
	}
	img, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.Header.Get("Content-Type") != "image/png" ||
		!strings.HasPrefix(resp.Header.Get("Cache-Control"), "public, max-age=") {
		t.Errorf("card headers: %v", resp.Header)
	}
	cfg, err := png.DecodeConfig(bytes.NewReader(img))
	if err != nil || cfg.Width != 1200 || cfg.Height != 630 || len(img) > 300_000 {
		t.Errorf("card: %v %dx%d %d bytes", err, cfg.Width, cfg.Height, len(img))
	}
}

// every language has every line, and the english has no long dash
func TestPageTextsWhole(t *testing.T) {
	if len(pageTexts) != 16 {
		t.Fatalf("%d languages", len(pageTexts))
	}
	for lang, pt := range pageTexts {
		v := reflect.ValueOf(pt)
		for i := 0; i < v.NumField(); i++ {
			if s := v.Field(i).String(); strings.TrimSpace(s) == "" {
				t.Errorf("%s: no %s", lang, v.Type().Field(i).Name)
			}
		}
		if !strings.Contains(pt.Title, "Kryfo") || !strings.Contains(pt.Open, "Kryfo") {
			t.Errorf("%s: Kryfo is not named", lang)
		}
	}
	if strings.Contains(fmt.Sprint(pageTexts["en"]), "—") {
		t.Error("an em dash in english")
	}
}

func TestPlayLinkOnlyWithTheFlag(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	claim(t, c, srv.URL, "wren", newOwner(t))
	for _, p := range []string{"/i", "/@wren"} {
		if _, b := fetch(t, c, srv.URL+p); strings.Contains(b, "Google Play") {
			t.Errorf("%s: a play link without the flag", p)
		}
	}
	t.Setenv("HANDLE_PLAY_URL", "javascript:alert(1)")
	if _, b := fetch(t, c, srv.URL+"/i"); strings.Contains(b, "Google Play") {
		t.Error("took a play link that is not play")
	}
	t.Setenv("HANDLE_PLAY_URL", "https://play.google.com/store/apps/details?id=app.kryfo")
	for _, p := range []string{"/i", "/@wren"} {
		if _, b := fetch(t, c, srv.URL+p); !strings.Contains(b, `href="https://play.google.com/store/apps/details?id=app.kryfo">Get it on Google Play`) {
			t.Errorf("%s: no play link with the flag", p)
		}
	}
}

func TestHandlePageSaysWhereToGetKryfo(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	_, b := fetch(t, c, srv.URL+"/@wren")
	hasGetKryfo(t, "/@wren", b)
	if !strings.Contains(b, `<a class=btn href="`+html.EscapeString(o.invite())+`">Open in Kryfo</a>`) {
		t.Error("no open button")
	}
	if len(scriptOf(b)) != 0 {
		t.Error("a script on a handle page")
	}
	_, b = fetchIn(t, c, srv.URL+"/@wren", "uk")
	if !strings.Contains(b, ">Відкрити в Kryfo<") || !strings.Contains(b, "Підтверджене ім’я користувача") {
		t.Error("the handle page is not in the visitor's language")
	}
}

// a handle nobody holds, and any other path, get the page that says where
// to get Kryfo, kept by no cache
func TestUnknownHandleGetsTheGetKryfoPage(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	for _, p := range []string{"/@nobody", "/", "/elsewhere"} {
		resp, b := fetch(t, c, srv.URL+p)
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("%s: status %d", p, resp.StatusCode)
		}
		if resp.Header.Get("Cache-Control") != "no-store" {
			t.Errorf("%s: cache %q", p, resp.Header.Get("Cache-Control"))
		}
		hasGetKryfo(t, p, b)
		if !strings.Contains(b, "<div class=name>Kryfo</div>") ||
			!strings.Contains(b, "Private messenger, no phone number, open source") {
			t.Errorf("%s: not the get-Kryfo page", p)
		}
		if strings.Contains(b, "nobody") || strings.Contains(b, "elsewhere") || len(scriptOf(b)) != 0 {
			t.Errorf("%s: the path or a script on the page", p)
		}
	}
}

func TestPageLang(t *testing.T) {
	for h, want := range map[string]string{
		"":                  "en",
		"*":                 "en",
		"ru":                "ru",
		"RU-ru":             "ru",
		"zh-Hant-HK":        "zh_Hant",
		"zh-hk":             "zh_Hant",
		"zh-Hans":           "zh",
		"zh_TW":             "zh_Hant",
		"nl, de;q=0.3":      "de",
		"de;q=0.3, tr;q=.4": "tr",
		"de;q=abc, vi":      "vi",
		"ar;q=0":            "en",
	} {
		r, _ := http.NewRequest("GET", "/", nil)
		r.Header.Set("Accept-Language", h)
		if got := pageLang(r); got != want {
			t.Errorf("%q: %s, want %s", h, got, want)
		}
	}
}
