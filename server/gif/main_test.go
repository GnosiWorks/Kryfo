// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
)

const (
	giphyKey = "test-giphy-key"
	klipyKey = "test-klipy-key"
)

var gifBytes = append([]byte("GIF89a"), bytes.Repeat([]byte{1}, 500)...)

// what the fake providers saw: every request, with its headers
type seen struct {
	mu   sync.Mutex
	reqs []*http.Request
}

func (s *seen) add(r *http.Request) {
	s.mu.Lock()
	s.reqs = append(s.reqs, r.Clone(r.Context()))
	s.mu.Unlock()
}

func (s *seen) all() []*http.Request {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]*http.Request(nil), s.reqs...)
}

type fake struct {
	t       *testing.T
	relay   *httptest.Server
	r       *relay
	media   *httptest.Server
	giphy   *httptest.Server
	klipy   *httptest.Server
	seen    *seen
	giphyUp bool
	klipyUp bool
	// what the media host answers: type and body
	mediaType string
	mediaBody []byte
}

func newFake(t *testing.T) *fake {
	t.Helper()
	apiLim, mediaLim = newLimiter(1000, 1000), newLimiter(1000, 1000)
	f := &fake{t: t, seen: &seen{}, giphyUp: true, klipyUp: true, mediaType: "image/gif", mediaBody: gifBytes}
	f.media = httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.seen.add(r)
		w.Header().Set("Content-Type", f.mediaType)
		w.Header().Set("Set-Cookie", "track=1")
		w.Header().Set("ETag", `"abc"`)
		w.Write(f.mediaBody)
	}))
	f.giphy = httptest.NewTLSServer(http.HandlerFunc(f.serveGiphy))
	f.klipy = httptest.NewTLSServer(http.HandlerFunc(f.serveKlipy))
	t.Cleanup(func() { f.media.Close(); f.giphy.Close(); f.klipy.Close() })

	f.r = newRelay(bytes.Repeat([]byte{7}, 32), giphyKey, klipyKey)
	tlsConf := f.media.Client().Transport.(*http.Transport).TLSClientConfig
	trust := func(c *http.Client) {
		c.Transport.(*http.Transport).TLSClientConfig = tlsConf.Clone()
	}
	trust(f.r.media)
	g := f.r.providers["giphy"].(*giphy)
	g.base = f.giphy.URL
	trust(g.c)
	k := f.r.providers["klipy"].(*klipy)
	k.base = f.klipy.URL
	mediaHost := strings.TrimPrefix(f.media.URL, "https://")
	f.r.hostOK = func(u *url.URL) bool { return u.Scheme == "https" && u.Host == mediaHost }

	f.relay = httptest.NewUnstartedServer(nil)
	f.relay.Config = newServer("", f.r)
	f.relay.Start()
	t.Cleanup(f.relay.Close)
	return f
}

func (f *fake) serveGiphy(w http.ResponseWriter, r *http.Request) {
	f.seen.add(r)
	if !f.giphyUp {
		http.Error(w, "down", http.StatusInternalServerError)
		return
	}
	q := r.URL.Query()
	if q.Get("api_key") != giphyKey {
		http.Error(w, "no key", http.StatusUnauthorized)
		return
	}
	off := atoi(q.Get("offset"))
	n := atoi(q.Get("limit"))
	var data []map[string]any
	for i := 0; i < n; i++ {
		id := fmt.Sprintf("g%d", off+i)
		img := func(w, h, size int) map[string]string {
			return map[string]string{
				"url":       f.media.URL + "/" + id + ".gif?cid=abc&rid=x",
				"width":     fmt.Sprint(w),
				"height":    fmt.Sprint(h),
				"size":      fmt.Sprint(size),
				"webp":      f.media.URL + "/" + id + ".webp?cid=abc",
				"webp_size": "900",
			}
		}
		data = append(data, map[string]any{
			"id": id,
			"images": map[string]any{
				"fixed_width": img(200, 150, 1500),
				"downsized":   img(480, 360, 40000),
			},
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"data":       data,
		"pagination": map[string]int{"total_count": 60, "count": len(data), "offset": off},
	})
}

func (f *fake) serveKlipy(w http.ResponseWriter, r *http.Request) {
	f.seen.add(r)
	if !f.klipyUp || !strings.HasPrefix(r.URL.Path, "/api/v1/"+klipyKey+"/gifs/") {
		http.Error(w, "down", http.StatusInternalServerError)
		return
	}
	file := func(id, ext string, w, h int) map[string]any {
		return map[string]any{"url": f.media.URL + "/" + id + "." + ext, "width": w, "height": h, "size": 2000}
	}
	data := []map[string]any{
		{"type": "ad", "content": "<html>", "width": 300, "height": 250},
		{"id": 11, "type": "gif", "file": map[string]any{
			"sm": map[string]any{"webp": file("k11", "webp", 220, 180), "gif": file("k11", "gif", 220, 180)},
			"md": map[string]any{"gif": file("k11m", "gif", 480, 392)},
		}},
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"result": true,
		"data":   map[string]any{"data": data, "current_page": 1, "per_page": 24, "has_next": true},
	})
}

func (f *fake) post(path string, body any, hdr ...string) (int, map[string]any) {
	f.t.Helper()
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest(http.MethodPost, f.relay.URL+path, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	for i := 0; i+1 < len(hdr); i += 2 {
		req.Header.Set(hdr[i], hdr[i+1])
	}
	return f.do(req)
}

func (f *fake) get(path string) (int, map[string]any) {
	f.t.Helper()
	req, _ := http.NewRequest(http.MethodGet, f.relay.URL+path, nil)
	return f.do(req)
}

func (f *fake) do(req *http.Request) (int, map[string]any) {
	f.t.Helper()
	resp, err := f.relay.Client().Do(req)
	if err != nil {
		f.t.Fatal(err)
	}
	defer resp.Body.Close()
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp.StatusCode, out
}

func items(t *testing.T, p map[string]any) []map[string]any {
	t.Helper()
	raw, ok := p["items"].([]any)
	if !ok {
		t.Fatalf("no items: %v", p)
	}
	var out []map[string]any
	for _, r := range raw {
		out = append(out, r.(map[string]any))
	}
	return out
}

func TestSearchAsksGiphyWithTheRatingAndNothingOfTheCaller(t *testing.T) {
	f := newFake(t)
	code, p := f.post("/gif/v1/search", map[string]any{"q": "happy  seal", "lang": "de", "limit": 200},
		"X-Forwarded-For", "203.0.113.9", "X-Real-IP", "203.0.113.9", "Cookie", "a=b", "User-Agent", "phone/1")
	if code != 200 {
		t.Fatalf("%d %v", code, p)
	}
	if p["provider"] != "giphy" || p["attribution"] != "GIPHY" || p["next"] != float64(24) {
		t.Fatalf("page: %v", p)
	}
	its := items(t, p)
	if len(its) != maxLimit {
		t.Fatalf("%d items, want the cap", len(its))
	}
	for _, it := range its {
		for _, k := range []string{"preview", "full"} {
			u := it[k].(map[string]any)["url"].(string)
			if !strings.HasPrefix(u, "/gif/v1/m/") || strings.Contains(u, "seal") {
				t.Fatalf("%s url %q", k, u)
			}
		}
	}
	reqs := f.seen.all()
	if len(reqs) != 1 {
		t.Fatalf("%d upstream calls", len(reqs))
	}
	r := reqs[0]
	q := r.URL.Query()
	if r.URL.Path != "/v1/gifs/search" || q.Get("q") != "happy seal" || q.Get("rating") != "pg-13" ||
		q.Get("lang") != "de" || q.Get("limit") != "24" {
		t.Fatalf("asked %s", r.URL)
	}
	for _, k := range []string{"random_id", "user_id", "customer_id"} {
		if q.Has(k) {
			t.Errorf("%s went upstream", k)
		}
	}
	checkClean(t, r)
}

// no address, no cookie and no user agent of the phone's reach a provider
func checkClean(t *testing.T, r *http.Request) {
	t.Helper()
	for _, h := range []string{"X-Forwarded-For", "X-Real-Ip", "Forwarded", "Cookie", "Referer", "Via"} {
		if v := r.Header.Get(h); v != "" {
			t.Errorf("%s: %q went upstream", h, v)
		}
	}
	if ua := r.Header.Get("User-Agent"); ua != userAgent {
		t.Errorf("user agent %q", ua)
	}
}

func TestQuestionOnlyInTheBody(t *testing.T) {
	f := newFake(t)
	if code, _ := f.get("/gif/v1/search?q=seal"); code != http.StatusMethodNotAllowed {
		t.Fatalf("get: %d", code)
	}
	if code, _ := f.post("/gif/v1/search?q=seal", map[string]any{"q": "seal"}); code != http.StatusMethodNotAllowed {
		t.Fatalf("query string: %d", code)
	}
	if n := len(f.seen.all()); n != 0 {
		t.Fatalf("%d upstream calls", n)
	}
}

func TestQueriesThatAreRefused(t *testing.T) {
	f := newFake(t)
	for _, q := range []string{
		"", "   ", strings.Repeat("a", 51), "seal\x00", "seal\u202e", "a<b>", "%2e%2e",
		"https://x.y/z",
	} {
		if code, _ := f.post("/gif/v1/search", map[string]any{"q": q}); code != http.StatusBadRequest {
			t.Errorf("%q: %d", q, code)
		}
	}
	for _, q := range []string{"seal", "öl", "猫", "кот", "😂", "👍🏽", "rock & roll", "it's 5 o'clock", "قطة"} {
		if code, p := f.post("/gif/v1/search", map[string]any{"q": q}); code != 200 {
			t.Errorf("%q: %d %v", q, code, p)
		}
	}
	if code, _ := f.post("/gif/v1/search", map[string]any{"q": "seal", "offset": -1}); code != 400 {
		t.Errorf("negative offset: %d", code)
	}
	if code, _ := f.post("/gif/v1/search", map[string]any{"q": "seal", "offset": 5000}); code != 400 {
		t.Errorf("offset past the end: %d", code)
	}
	// a language that is not one is dropped, not passed on
	f.post("/gif/v1/search", map[string]any{"q": "seal", "lang": "de&x=1"})
	reqs := f.seen.all()
	if q := reqs[len(reqs)-1].URL.Query(); q.Has("lang") || q.Has("x") {
		t.Errorf("lang went up: %v", q)
	}
}

func TestFirstPageFallsBackToKlipy(t *testing.T) {
	f := newFake(t)
	f.giphyUp = false
	code, p := f.post("/gif/v1/search", map[string]any{"q": "seal", "lang": "pt"})
	if code != 200 || p["provider"] != "klipy" || p["attribution"] != "Klipy" {
		t.Fatalf("%d %v", code, p)
	}
	its := items(t, p)
	if len(its) != 1 || its[0]["id"] != "11" {
		t.Fatalf("the ad was shown or the gif lost: %v", its)
	}
	if its[0]["w"] != float64(480) {
		t.Fatalf("size from the full gif: %v", its[0])
	}
	var kq url.Values
	for _, r := range f.seen.all() {
		if strings.HasPrefix(r.URL.Path, "/api/v1/") {
			kq = r.URL.Query()
			checkClean(t, r)
		}
	}
	if kq.Get("rating") != "pg-13" || kq.Get("locale") != "pt_BR" || kq.Has("customer_id") {
		t.Fatalf("klipy asked %v", kq)
	}
	// a later page stays with the provider it started on
	code, p = f.post("/gif/v1/search", map[string]any{"q": "seal", "offset": 24})
	if code != http.StatusBadGateway {
		t.Fatalf("later page: %d %v", code, p)
	}
	if strings.Contains(fmt.Sprint(p), giphyKey) {
		t.Fatal("the key came back in an error")
	}
	code, p = f.post("/gif/v1/search", map[string]any{"q": "seal", "offset": 24, "provider": "klipy"})
	if code != 200 || p["provider"] != "klipy" {
		t.Fatalf("klipy page two: %d %v", code, p)
	}
}

func TestBothDown(t *testing.T) {
	f := newFake(t)
	f.giphyUp, f.klipyUp = false, false
	code, p := f.post("/gif/v1/search", map[string]any{"q": "seal"})
	if code != http.StatusBadGateway {
		t.Fatalf("%d", code)
	}
	s := fmt.Sprint(p)
	if strings.Contains(s, giphyKey) || strings.Contains(s, klipyKey) || strings.Contains(s, "127.0.0.1") {
		t.Fatalf("an upstream detail came back: %s", s)
	}
}

func TestTrendingIsKeptAWhile(t *testing.T) {
	f := newFake(t)
	for i := 0; i < 3; i++ {
		code, p := f.get("/gif/v1/trending?lang=en")
		if code != 200 || len(items(t, p)) != 24 {
			t.Fatalf("%d %v", code, p)
		}
	}
	if n := len(f.seen.all()); n != 1 {
		t.Fatalf("%d upstream calls for one trending page", n)
	}
	r := f.seen.all()[0]
	if r.URL.Path != "/v1/gifs/trending" || r.URL.Query().Get("rating") != "pg-13" {
		t.Fatalf("asked %s", r.URL)
	}
	if code, _ := f.get("/gif/v1/trending?offset=x"); code != 400 {
		t.Fatalf("bad offset: %d", code)
	}
}

func mediaURL(t *testing.T, f *fake, which string) string {
	t.Helper()
	_, p := f.post("/gif/v1/search", map[string]any{"q": "seal"})
	return items(t, p)[0][which].(map[string]any)["url"].(string)
}

func fetch(t *testing.T, f *fake, path string) (*http.Response, []byte, error) {
	t.Helper()
	resp, err := f.relay.Client().Get(f.relay.URL + path)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(resp.Body)
	return resp, b, err
}

func TestMediaStreamsThroughWithNothingOfTheProvider(t *testing.T) {
	f := newFake(t)
	path := mediaURL(t, f, "full")
	resp, b, err := fetch(t, f, path)
	if err != nil || resp.StatusCode != 200 || !bytes.Equal(b, gifBytes) {
		t.Fatalf("%v %d %d bytes", err, resp.StatusCode, len(b))
	}
	if resp.Header.Get("Content-Type") != "image/gif" || resp.Header.Get("Cache-Control") != "no-store" {
		t.Fatalf("headers %v", resp.Header)
	}
	for _, h := range []string{"Set-Cookie", "Etag", "Last-Modified"} {
		if resp.Header.Get(h) != "" {
			t.Errorf("%s passed through", h)
		}
	}
	reqs := f.seen.all()
	last := reqs[len(reqs)-1]
	if last.URL.RawQuery != "" {
		t.Errorf("giphy's call id went with the media request: %s", last.URL)
	}
	checkClean(t, last)
}

func TestMediaTokenIsNoOpenProxy(t *testing.T) {
	f := newFake(t)
	path := mediaURL(t, f, "preview")
	tok := strings.TrimPrefix(path, "/gif/v1/m/")
	a, s, _ := strings.Cut(tok, ".")
	other := f.r.token("https://example.com/x.gif")
	for name, p := range map[string]string{
		"tampered": "/gif/v1/m/" + a + "x." + s,
		"no mac":   "/gif/v1/m/" + a,
		"garbage":  "/gif/v1/m/!!!",
	} {
		if resp, _, _ := fetch(t, f, p); resp.StatusCode != http.StatusNotFound {
			t.Errorf("%s: %d", name, resp.StatusCode)
		}
	}
	// signed, but not a provider's host
	if resp, _, _ := fetch(t, f, "/gif/v1/m/"+other); resp.StatusCode != http.StatusForbidden {
		t.Errorf("foreign host: %d", resp.StatusCode)
	}
	// another secret signs nothing here
	r2 := newRelay(bytes.Repeat([]byte{8}, 32), "k", "")
	u, _ := f.r.untoken(tok)
	if resp, _, _ := fetch(t, f, "/gif/v1/m/"+r2.token(u)); resp.StatusCode != http.StatusNotFound {
		t.Errorf("other secret: %d", resp.StatusCode)
	}
}

func TestMediaOnlyGifWebpMp4(t *testing.T) {
	f := newFake(t)
	path := mediaURL(t, f, "full")
	f.mediaType, f.mediaBody = "text/html", []byte("<html><script>")
	if resp, _, _ := fetch(t, f, path); resp.StatusCode != http.StatusBadGateway {
		t.Errorf("html: %d", resp.StatusCode)
	}
	f.mediaType, f.mediaBody = "image/gif", []byte("<html><script>")
	if resp, _, _ := fetch(t, f, path); resp.StatusCode != http.StatusBadGateway {
		t.Errorf("html called a gif: %d", resp.StatusCode)
	}
	f.mediaType, f.mediaBody = "image/webp", append([]byte("RIFF\x10\x00\x00\x00WEBPVP8 "), 1, 2, 3)
	if resp, _, _ := fetch(t, f, path); resp.StatusCode != 200 || resp.Header.Get("Content-Type") != "image/webp" {
		t.Errorf("webp: %d", resp.StatusCode)
	}
	f.mediaType, f.mediaBody = "video/mp4", []byte("\x00\x00\x00\x18ftypmp42....")
	if resp, _, _ := fetch(t, f, path); resp.StatusCode != 200 {
		t.Errorf("mp4: %d", resp.StatusCode)
	}
}

func TestMediaSizeCap(t *testing.T) {
	f := newFake(t)
	path := mediaURL(t, f, "full")
	f.mediaBody = append([]byte("GIF89a"), make([]byte, maxMedia)...)
	resp, b, err := fetch(t, f, path)
	if resp.StatusCode == 200 && err == nil && len(b) > maxMedia {
		t.Fatalf("%d bytes came through", len(b))
	}
}

func TestLimitsForEveryoneTogether(t *testing.T) {
	f := newFake(t)
	apiLim = newLimiter(0.001, 2)
	codes := []int{}
	for i := 0; i < 3; i++ {
		c, _ := f.post("/gif/v1/search", map[string]any{"q": "seal"})
		codes = append(codes, c)
	}
	if codes[0] != 200 || codes[1] != 200 || codes[2] != http.StatusTooManyRequests {
		t.Fatalf("codes %v", codes)
	}
	apiLim = newLimiter(1000, 1000)
	path := mediaURL(t, f, "full")
	mediaLim = newLimiter(0.001, 1)
	fetch(t, f, path)
	if resp, _, _ := fetch(t, f, path); resp.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("media: %d", resp.StatusCode)
	}
}

func TestNothingIsLogged(t *testing.T) {
	var buf bytes.Buffer
	log.SetOutput(&buf)
	defer log.SetOutput(io.Discard)
	f := newFake(t)
	f.post("/gif/v1/search", map[string]any{"q": "secret seal"})
	f.post("/gif/v1/search", map[string]any{"q": "bad\u202e"})
	fetch(t, f, mediaURL(t, f, "full"))
	fetch(t, f, "/gif/v1/m/nope")
	f.giphyUp, f.klipyUp = false, false
	f.post("/gif/v1/search", map[string]any{"q": "secret seal"})
	if buf.Len() != 0 {
		t.Fatalf("logged: %s", buf.String())
	}
}

func TestProviderHosts(t *testing.T) {
	for s, want := range map[string]bool{
		"https://media.giphy.com/media/x/giphy.gif":  true,
		"https://media2.giphy.com/media/x/giphy.gif": true,
		"https://i.giphy.com/x.webp":                 true,
		"https://static.klipy.com/ii/x.gif":          true,
		"http://media.giphy.com/x.gif":               false,
		"https://media.giphy.com:8443/x.gif":         false,
		"https://api.giphy.com/v1/gifs":              false,
		"https://evil.com/media.giphy.com":           false,
		"https://media.giphy.com.evil.com/x.gif":     false,
		"https://u:p@media.giphy.com/x.gif":          false,
		"https://klipy.com/x.gif":                    false,
	} {
		u, _ := url.Parse(s)
		if providerHost(u) != want {
			t.Errorf("%s: want %v", s, want)
		}
	}
}

func TestHealth(t *testing.T) {
	f := newFake(t)
	code, p := f.get("/gif/v1/health")
	if code != 200 || p["ok"] != true {
		t.Fatalf("%d %v", code, p)
	}
}
