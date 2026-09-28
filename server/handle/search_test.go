// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type owner struct {
	pub  ed25519.PublicKey
	priv ed25519.PrivateKey
}

func newOwner(t *testing.T) owner {
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatal(err)
	}
	return owner{pub, priv}
}

func (o owner) hexPub() string { return hex.EncodeToString(o.pub) }

func (o owner) sign(msg string) string {
	return hex.EncodeToString(ed25519.Sign(o.priv, []byte(msg)))
}

const invite = "kryfo://share?id=a-b-c&onion=x.onion&v=3&bundle=zz&fc=ff"

// the real server on a scratch store, so connection counting works
func service(t *testing.T, lim *limiter) (*httptest.Server, *store) {
	t.Helper()
	st := openStore(filepath.Join(t.TempDir(), "handles.json"))
	readLim, writeLim, newNameLim = newLimiter(1000, 1000), newLimiter(1000, 1000), newLimiter(1000, 1000)
	srv := httptest.NewUnstartedServer(nil)
	real := newServer("", st, lim)
	srv.Config = real
	srv.Start()
	t.Cleanup(srv.Close)
	return srv, st
}

func post(t *testing.T, c *http.Client, base, path string, body map[string]string) map[string]any {
	t.Helper()
	b, _ := json.Marshal(body)
	resp, err := c.Post(base+path, "application/json", bytes.NewReader(b))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return out
}

func claim(t *testing.T, c *http.Client, base, h string, o owner) {
	t.Helper()
	out := post(t, c, base, "/handle/claim", map[string]string{
		"handle": h, "invite": invite, "bio": "bio of " + h,
		"pubkey": o.hexPub(), "sig": o.sign("kryfo-handle-v1:" + h),
	})
	if out["ok"] != true {
		t.Fatalf("claim %s: %v", h, out)
	}
}

func list(t *testing.T, c *http.Client, base, h string, o owner, on bool, name string, ts int64) map[string]any {
	t.Helper()
	l := "0"
	if on {
		l = "1"
	}
	return post(t, c, base, "/handle/listing", map[string]string{
		"handle": h, "listed": l, "name": name, "ts": fmt.Sprint(ts),
		"pubkey": o.hexPub(), "sig": o.sign(listingMsg(h, on, ts, name)),
	})
}

type answer struct {
	code    int
	results []hit
}

func search(t *testing.T, c *http.Client, base, q string) answer {
	t.Helper()
	b, _ := json.Marshal(map[string]string{"q": q})
	resp, err := c.Post(base+"/handle/search", "application/json", bytes.NewReader(b))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var out struct {
		Results []hit `json:"results"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&out)
	if resp.Header.Get("Cache-Control") != "no-store" {
		t.Errorf("search answer may be stored: %q", resp.Header.Get("Cache-Control"))
	}
	return answer{resp.StatusCode, out.Results}
}

func handles(a answer) []string {
	var out []string
	for _, h := range a.results {
		out = append(out, h.Handle)
	}
	return out
}

func TestUnlistedUntilOwnerOptsIn(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wrenfield", o)
	if a := search(t, c, srv.URL, "wren"); a.code != 200 || len(a.results) != 0 {
		t.Fatalf("unlisted handle found: %v", a)
	}
	now := time.Now().Unix()
	if out := list(t, c, srv.URL, "wrenfield", o, true, "Wren  F.", now); out["ok"] != true {
		t.Fatalf("listing refused: %v", out)
	}
	a := search(t, c, srv.URL, "wren")
	if len(a.results) != 1 || a.results[0].Handle != "wrenfield" ||
		a.results[0].Name != "Wren F." || !a.results[0].Verified ||
		a.results[0].Bio != "bio of wrenfield" || a.results[0].FP == "" {
		t.Fatalf("listed handle: %+v", a.results)
	}
	// out again, and the name goes with it
	if out := list(t, c, srv.URL, "wrenfield", o, false, "", now+1); out["ok"] != true {
		t.Fatalf("unlisting refused: %v", out)
	}
	if a := search(t, c, srv.URL, "wren"); len(a.results) != 0 {
		t.Fatalf("still found after opting out: %v", a.results)
	}
}

func TestListingOwnerOnlyNoReplay(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o, other := newOwner(t), newOwner(t)
	claim(t, c, srv.URL, "wrenfield", o)
	now := time.Now().Unix()

	// someone else's key, even signing correctly for itself
	out := post(t, c, srv.URL, "/handle/listing", map[string]string{
		"handle": "wrenfield", "listed": "1", "name": "", "ts": fmt.Sprint(now),
		"pubkey": other.hexPub(), "sig": other.sign(listingMsg("wrenfield", true, now, "")),
	})
	if out["ok"] == true {
		t.Fatal("a stranger listed someone's handle")
	}
	// the owner's key over a different name than the one sent
	out = post(t, c, srv.URL, "/handle/listing", map[string]string{
		"handle": "wrenfield", "listed": "1", "name": "Evil", "ts": fmt.Sprint(now),
		"pubkey": o.hexPub(), "sig": o.sign(listingMsg("wrenfield", true, now, "Wren")),
	})
	if out["ok"] == true {
		t.Fatal("a name the owner never signed was accepted")
	}
	// too far from the clock
	if out := list(t, c, srv.URL, "wrenfield", o, true, "", now-3600); out["ok"] == true {
		t.Fatal("an hour-old request was accepted")
	}
	if out := list(t, c, srv.URL, "wrenfield", o, true, "", now); out["ok"] != true {
		t.Fatalf("the owner was refused: %v", out)
	}
	if out := list(t, c, srv.URL, "wrenfield", o, false, "", now+5); out["ok"] != true {
		t.Fatalf("opting out refused: %v", out)
	}
	// the old opt-in, sent again, does not put them back
	if out := list(t, c, srv.URL, "wrenfield", o, true, "", now); out["ok"] == true {
		t.Fatal("a replayed opt-in was accepted")
	}
	if e, _ := st.get("wrenfield"); e.Listed {
		t.Fatal("listed after a replay")
	}
}

func TestReclaimKeepsListing(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wrenfield", o)
	now := time.Now().Unix()
	list(t, c, srv.URL, "wrenfield", o, true, "Wren", now)
	// the app repoints its handle on every start
	claim(t, c, srv.URL, "wrenfield", o)
	e, _ := st.get("wrenfield")
	if !e.Listed || e.Name != "Wren" || e.ListedAt != now {
		t.Fatalf("a re-claim changed the listing: %+v", e)
	}
}

func TestSweepQueriesRefused(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	for _, q := range []string{"", "ab", "@ab", "a b", "***", "%%%", "a*b*c", "___", "...",
		"wr%", "wren*", "?wren", strings.Repeat("a", 33), "a'b c", "<wr>"} {
		if a := search(t, c, srv.URL, q); a.code != http.StatusBadRequest {
			t.Errorf("%q: %d, wanted 400", q, a.code)
		}
	}
	for _, q := range []string{"wre", "@wren", "Wren F", "wren_f", "anna-lena", "李小龍", "مریم"} {
		if a := search(t, c, srv.URL, q); a.code != 200 {
			t.Errorf("%q: %d, wanted 200", q, a.code)
		}
	}
}

func TestSearchTwentyBestFirst(t *testing.T) {
	srv, _ := service(t, newLimiter(1000, 1000))
	c := srv.Client()
	now := time.Now().Unix()
	for i := 0; i < 30; i++ {
		o := newOwner(t)
		h := fmt.Sprintf("zzwren%02d", i)
		claim(t, c, srv.URL, h, o)
		list(t, c, srv.URL, h, o, true, "", now)
	}
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	list(t, c, srv.URL, "wren", o, true, "", now)
	o2 := newOwner(t)
	claim(t, c, srv.URL, "wrenna", o2)
	list(t, c, srv.URL, "wrenna", o2, true, "", now)
	o3 := newOwner(t)
	claim(t, c, srv.URL, "anna", o3)
	list(t, c, srv.URL, "anna", o3, true, "Wren's sister", now)

	a := search(t, c, srv.URL, "wren")
	if len(a.results) != searchMax {
		t.Fatalf("%d results, wanted %d", len(a.results), searchMax)
	}
	got := handles(a)
	if got[0] != "wren" || got[1] != "wrenna" || !strings.HasPrefix(got[2], "zzwren") {
		t.Fatalf("order: %v", got[:3])
	}
	// a name matches too, after every handle that does
	if a := search(t, c, srv.URL, "sister"); len(a.results) != 1 || a.results[0].Handle != "anna" {
		t.Fatalf("by name: %v", handles(a))
	}
}

func TestPerConnectionSearchLimit(t *testing.T) {
	srv, _ := service(t, newLimiter(1000, 1000))
	// one client, keep-alive: every request on the same connection
	c := srv.Client()
	for i := 0; i < perConnSearches; i++ {
		if a := search(t, c, srv.URL, "wren"); a.code != 200 {
			t.Fatalf("search %d: %d", i+1, a.code)
		}
	}
	if a := search(t, c, srv.URL, "wren"); a.code != http.StatusTooManyRequests {
		t.Fatalf("search %d on one connection: %d, wanted 429", perConnSearches+1, a.code)
	}
	// the server closed it; a new connection starts again
	if a := search(t, c, srv.URL, "wren"); a.code != 200 {
		t.Fatalf("a fresh connection: %d", a.code)
	}
}

func TestServiceWideLimit(t *testing.T) {
	srv, _ := service(t, newLimiter(0.001, 5))
	for i := 0; i < 5; i++ {
		c := &http.Client{Transport: &http.Transport{DisableKeepAlives: true}}
		if a := search(t, c, srv.URL, "wren"); a.code != 200 {
			t.Fatalf("search %d: %d", i+1, a.code)
		}
	}
	c := &http.Client{Transport: &http.Transport{DisableKeepAlives: true}}
	if a := search(t, c, srv.URL, "wren"); a.code != http.StatusTooManyRequests {
		t.Fatalf("past the burst: %d, wanted 429", a.code)
	}
}

func TestNamesAreCleaned(t *testing.T) {
	for in, want := range map[string]string{
		"  Wren   F. ":          "Wren F.",
		"a‮evil‬":               "aevil",
		"tab\there":             "tab here",
		strings.Repeat("x", 60): strings.Repeat("x", nameMax),
		"‏مریم‏":                "مریم",
		"line\nbreak":           "line break",
	} {
		if got := cleanName(in); got != want {
			t.Errorf("cleanName(%q) = %q, want %q", in, got, want)
		}
	}
}

// the app signs this exact text; engine/handle.go builds the same string
func TestListingMessageIsStable(t *testing.T) {
	got := listingMsg("wren", true, 1790000000, "Wren F.")
	if got != "kryfo-handle-list-v1:wren:1:1790000000:Wren F." {
		t.Fatal(got)
	}
}

func TestSearchQueryNotInURL(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c, base := srv.Client(), srv.URL
	for _, u := range []string{
		base + "/handle/search?q=wren",
		base + "/handle/search",
	} {
		resp, err := c.Get(u)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		if resp.StatusCode != http.StatusMethodNotAllowed {
			t.Errorf("GET %s: %d, want 405", u, resp.StatusCode)
		}
	}
	// a post that also carries it in the url is refused too
	resp, err := c.Post(base+"/handle/search?q=wren", "application/json",
		strings.NewReader(`{"q":"wren"}`))
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusMethodNotAllowed {
		t.Errorf("POST with a query: %d, want 405", resp.StatusCode)
	}
}

func TestCheckTakesPostBody(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c, base := srv.Client(), srv.URL
	claim(t, c, base, "wren", newOwner(t))
	if out := post(t, c, base, "/handle/check", map[string]string{"h": "wren"}); out["free"] != false {
		t.Errorf("post, taken name: %v", out)
	}
	if out := post(t, c, base, "/handle/check", map[string]string{"h": "heron"}); out["free"] != true {
		t.Errorf("post, free name: %v", out)
	}
	// older apps ask with a get
	resp, err := c.Get(base + "/handle/check?h=wren")
	if err != nil {
		t.Fatal(err)
	}
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK || out["free"] != false {
		t.Errorf("get from an old app: %d %v", resp.StatusCode, out)
	}
	// a post that also carries the name in the url is refused
	resp, err = c.Post(base+"/handle/check?h=wren", "application/json",
		strings.NewReader(`{"h":"wren"}`))
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusMethodNotAllowed {
		t.Errorf("post with a query: %d, want 405", resp.StatusCode)
	}
}
