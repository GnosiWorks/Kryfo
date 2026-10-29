// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"html"
	"io"
	"net/http"
	"strings"
	"testing"
)

const goodQuery = `id=food-october-trial&onion=2dlpakwswmp5sgkbvu667hhmv6i5rd4flpdeq2z5rhnhs43afkwr3kad.onion&v=3&bundle=eyJyZWdpc3RyYXRpb25JZCI6MTI0ODV9&fc=035655278b6c21ce09a7222f7aa6abe398edbb0d7fca1c28e566d7938b08b15c`

func fetch(t *testing.T, c *http.Client, u string) (*http.Response, string) {
	t.Helper()
	resp, err := c.Get(u)
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
	if strings.Contains(b, "<script") || strings.Contains(b, " style=") {
		t.Errorf("%s: a script or a style attribute", what)
	}
}

func TestInvitePageOpensTheApp(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	resp, b := fetch(t, srv.Client(), srv.URL+"/i?"+goodQuery)
	if resp.StatusCode != 200 {
		t.Fatalf("status %d", resp.StatusCode)
	}
	want := `<a class=btn href="` + html.EscapeString("kryfo://share?"+goodQuery) + `">Open in Kryfo</a>`
	if !strings.Contains(b, want) || !strings.Contains(b, "&amp;onion=") {
		t.Fatalf("no escaped open link:\n%s", b)
	}
	if !strings.Contains(b, ">food-october-trial<") {
		t.Error("the three words are not shown")
	}
	hasGetKryfo(t, "invite", b)
	for k, v := range map[string]string{
		"Cache-Control":   "no-store",
		"Referrer-Policy": "no-referrer",
	} {
		if resp.Header.Get(k) != v {
			t.Errorf("%s: %q", k, resp.Header.Get(k))
		}
	}
	if resp.Header.Get("Set-Cookie") != "" {
		t.Error("a cookie")
	}
}

// a bad query gets the page without a button, and none of it comes back
func TestInvitePageRefusesBadQueries(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	bad := []string{
		"",
		"javascript:alert(1)",
		"id=food-october-trial&onion=x.onion&v=3",                  // no bundle
		"onion=x.onion&v=3&bundle=zz",                              // no id
		"id=food-october-trial&v=3&bundle=zz",                      // no onion
		"id=%3Cscript%3Ezzmark%3C/script%3E&onion=x&v=3&bundle=zz", // html in the id
		"id=zzmark-october-trial&onion=x&v=3&bundle=zz",            // not a list word
		"id=food-october&onion=x&v=3&bundle=zz",                    // two words
		"id=food-october-trial&onion=x&v=9&bundle=zzmark",
		"id=food-october-trial&onion=x&v=3&bundle=zz\"zzmark",
	}
	for _, q := range bad {
		resp, b := fetch(t, srv.Client(), srv.URL+"/i?"+q)
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("%q: status %d", q, resp.StatusCode)
		}
		if strings.Contains(b, "class=btn") || strings.Contains(b, "kryfo://") {
			t.Errorf("%q: a button", q)
		}
		if strings.Contains(b, "zzmark") || strings.Contains(b, "script") || strings.Contains(b, "javascript") {
			t.Errorf("%q: reflected", q)
		}
		hasGetKryfo(t, q, b)
	}
}

func TestPlayLinkOnlyWithTheFlag(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	claim(t, c, srv.URL, "wren", newOwner(t))
	for _, p := range []string{"/i?" + goodQuery, "/@wren"} {
		if _, b := fetch(t, c, srv.URL+p); strings.Contains(b, "Google Play") {
			t.Errorf("%s: a play link without the flag", p)
		}
	}
	t.Setenv("HANDLE_PLAY_URL", "javascript:alert(1)")
	if _, b := fetch(t, c, srv.URL+"/i?"+goodQuery); strings.Contains(b, "Google Play") {
		t.Error("took a play link that is not play")
	}
	t.Setenv("HANDLE_PLAY_URL", "https://play.google.com/store/apps/details?id=app.kryfo")
	for _, p := range []string{"/i?" + goodQuery, "/@wren"} {
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
	_, b = fetch(t, c, srv.URL+"/@nobody")
	hasGetKryfo(t, "/@nobody", b)
}
