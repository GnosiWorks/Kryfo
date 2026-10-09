// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the gif relay. it asks giphy or klipy for the app and passes their media
// through, so neither ever sees a phone. nothing about a caller is kept or
// sent on: no access log, no address, no per-user id upstream, one fixed
// user agent. the provider keys and the media secret come from the
// environment only.

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"
	"unicode/utf8"
)

const (
	// what every upstream request says it is, whoever asked
	userAgent = "kryfo-gif/1"
	// the rating every request carries
	rating = "pg-13"
	// items a page may hold
	maxLimit = 24
	// giphy answers nothing past this offset
	maxOffset = 4999
	// one media file, preview or full
	maxMedia = 6 << 20
	// media streams at once, so a flood cannot take all the bandwidth
	maxStreams = 48
	// a query, in characters and in bytes
	maxQueryRunes = 50
	maxQueryBytes = 200
	// how long a trending page is kept: it holds nothing of anyone's
	trendingFor = 5 * time.Minute
)

// limits for everyone together: behind tor there is no caller to tell
// apart. a page of results costs one api call and up to 24 previews
var (
	apiLim   = newLimiter(20, 60)
	mediaLim = newLimiter(150, 400)
)

type media struct {
	URL   string `json:"url"`
	W     int    `json:"w"`
	H     int    `json:"h"`
	Bytes int64  `json:"bytes,omitempty"`
}

type item struct {
	ID      string `json:"id"`
	W       int    `json:"w"`
	H       int    `json:"h"`
	Preview media  `json:"preview"`
	Full    media  `json:"full"`
}

type page struct {
	Provider    string `json:"provider"`
	Attribution string `json:"attribution"`
	// the offset of the next page, null at the end
	Next  *int   `json:"next"`
	Items []item `json:"items"`
}

// one question for a provider
type ask struct {
	trending bool
	q        string
	lang     string
	offset   int
	limit    int
}

type provider interface {
	name() string
	// how the attribution names it
	brand() string
	fetch(ctx context.Context, a ask) (items []item, more bool, err error)
}

type relay struct {
	secret    []byte
	providers map[string]provider
	order     []string
	media     *http.Client
	// whether a media url may be fetched. the token already makes the
	// endpoint no open proxy, this keeps it to the providers' own hosts
	hostOK  func(u *url.URL) bool
	streams chan struct{}

	tmu      sync.Mutex
	trending map[string]cached
}

type cached struct {
	p  page
	at time.Time
}

func main() {
	addr := env("GIF_ADDR", "127.0.0.1:3338")
	secret, err := hex.DecodeString(os.Getenv("GIF_SECRET"))
	if err != nil || len(secret) < 32 {
		log.Fatal("gif: GIF_SECRET must be at least 32 bytes in hex")
	}
	r := newRelay(secret, os.Getenv("GIPHY_KEY"), os.Getenv("KLIPY_KEY"))
	if len(r.order) == 0 {
		log.Fatal("gif: neither GIPHY_KEY nor KLIPY_KEY is set")
	}
	log.Printf("gif: listening on %s, providers %s", addr, strings.Join(r.order, ", "))
	log.Fatal(newServer(addr, r).ListenAndServe())
}

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func newRelay(secret []byte, giphyKey, klipyKey string) *relay {
	r := &relay{
		secret:    secret,
		providers: map[string]provider{},
		media:     mediaClient(),
		hostOK:    providerHost,
		streams:   make(chan struct{}, maxStreams),
		trending:  map[string]cached{},
	}
	api := apiClient()
	if giphyKey != "" {
		r.add(&giphy{base: "https://api.giphy.com", key: giphyKey, c: api})
	}
	if klipyKey != "" {
		r.add(&klipy{base: "https://api.klipy.com", key: klipyKey, c: api})
	}
	return r
}

func (r *relay) add(p provider) {
	r.providers[p.name()] = p
	r.order = append(r.order, p.name())
}

// the upstream http: no proxy from the environment, no cookies, no referrer,
// short timeouts. api answers are never redirected
func apiClient() *http.Client {
	return &http.Client{
		Transport: transport(),
		Timeout:   10 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
}

func mediaClient() *http.Client {
	return &http.Client{
		Transport: transport(),
		Timeout:   30 * time.Second,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) > 2 || !providerHost(req.URL) {
				return errors.New("redirect refused")
			}
			req.Header.Set("User-Agent", userAgent)
			return nil
		},
	}
}

func transport() *http.Transport {
	return &http.Transport{
		Proxy:                 nil,
		DialContext:           (&net.Dialer{Timeout: 5 * time.Second}).DialContext,
		TLSHandshakeTimeout:   5 * time.Second,
		ResponseHeaderTimeout: 8 * time.Second,
		MaxIdleConnsPerHost:   16,
		IdleConnTimeout:       60 * time.Second,
		ForceAttemptHTTP2:     true,
	}
}

var (
	giphyMedia = regexp.MustCompile(`^(i|media[0-9]?)\.giphy\.com$`)
	klipyMedia = regexp.MustCompile(`^static[0-9]*\.klipy\.com$`)
)

// the providers' media hosts, over https on the default port only
func providerHost(u *url.URL) bool {
	if u.Scheme != "https" || u.Port() != "" || u.User != nil {
		return false
	}
	h := u.Hostname()
	return giphyMedia.MatchString(h) || klipyMedia.MatchString(h)
}

func newServer(addr string, r *relay) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           r.routes(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    16 << 10,
		// no ErrorLog: a request that fails leaves no line with an address
		ErrorLog: log.New(io.Discard, "", 0),
	}
}

func (r *relay) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/gif/v1/search", r.search)
	mux.HandleFunc("/gif/v1/trending", r.trendingPage)
	mux.HandleFunc("/gif/v1/m/", r.stream)
	mux.HandleFunc("/gif/v1/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "providers": r.order})
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		refuse(w, http.StatusNotFound, "not here")
	})
	return mux
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func refuse(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}

// the question comes in the body, never in the url: a url can end up in a
// proxy's log, a body does not
func (r *relay) search(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost || req.URL.RawQuery != "" {
		refuse(w, http.StatusMethodNotAllowed, "post the question in the body")
		return
	}
	var body struct {
		Q        string `json:"q"`
		Lang     string `json:"lang"`
		Offset   int    `json:"offset"`
		Limit    int    `json:"limit"`
		Provider string `json:"provider"`
	}
	if json.NewDecoder(http.MaxBytesReader(w, req.Body, 1<<10)).Decode(&body) != nil {
		refuse(w, http.StatusBadRequest, "bad request")
		return
	}
	q, ok := cleanQuery(body.Q)
	if !ok {
		refuse(w, http.StatusBadRequest, "letters, digits and a few signs, 50 at most")
		return
	}
	a, ok := asked(body.Lang, body.Offset, body.Limit)
	if !ok {
		refuse(w, http.StatusBadRequest, "bad request")
		return
	}
	a.q = q
	r.answer(w, req.Context(), a, body.Provider)
}

func (r *relay) trendingPage(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		refuse(w, http.StatusMethodNotAllowed, "get only")
		return
	}
	v := req.URL.Query()
	num := func(k string) int {
		n, err := strconv.Atoi(v.Get(k))
		if err != nil {
			return -1
		}
		return n
	}
	off, lim := 0, maxLimit
	if v.Has("offset") {
		off = num("offset")
	}
	if v.Has("limit") {
		lim = num("limit")
	}
	a, ok := asked(v.Get("lang"), off, lim)
	if !ok {
		refuse(w, http.StatusBadRequest, "bad request")
		return
	}
	a.trending = true
	r.answer(w, req.Context(), a, v.Get("provider"))
}

var langOK = regexp.MustCompile(`^[a-z]{2}(-[A-Za-z]{2,4})?$`)

// a language that is not one is left out rather than refused
func asked(lang string, offset, limit int) (ask, bool) {
	if offset < 0 || offset > maxOffset || limit < 0 {
		return ask{}, false
	}
	if limit == 0 || limit > maxLimit {
		limit = maxLimit
	}
	if !langOK.MatchString(lang) {
		lang = ""
	}
	return ask{lang: lang, offset: offset, limit: limit}, true
}

// the query as it goes upstream: spaces folded, letters, digits, marks,
// emoji and a few signs only. no control or direction characters
func cleanQuery(raw string) (string, bool) {
	q := strings.Join(strings.Fields(raw), " ")
	if q == "" || len(q) > maxQueryBytes || !utf8.ValidString(q) ||
		utf8.RuneCountInString(q) > maxQueryRunes {
		return "", false
	}
	some := false
	for _, c := range q {
		switch {
		case unicode.IsLetter(c), unicode.IsNumber(c), unicode.In(c, unicode.So, unicode.Sk):
			some = true
		case unicode.IsMark(c), c == ' ', c == 0x200D, c == 0xFE0F:
		case strings.ContainsRune("'-_.,!?&#@:+", c):
		default:
			return "", false
		}
	}
	return q, some
}

// giphy unless asked otherwise. a first page falls back to the other
// provider when the first fails; a later one stays where it started, its
// offsets mean nothing elsewhere
func (r *relay) answer(w http.ResponseWriter, ctx context.Context, a ask, want string) {
	if !apiLim.allow() {
		refuse(w, http.StatusTooManyRequests, "slow down")
		return
	}
	if want == "" {
		want = "giphy"
	}
	var tries []string
	if _, ok := r.providers[want]; ok {
		tries = append(tries, want)
	}
	if a.offset == 0 || len(tries) == 0 {
		for _, n := range r.order {
			if n != want {
				tries = append(tries, n)
			}
		}
	}
	if len(tries) == 0 {
		refuse(w, http.StatusServiceUnavailable, "no gif service is set up")
		return
	}
	for _, n := range tries {
		p, err := r.pageFrom(ctx, r.providers[n], a)
		if err != nil {
			continue
		}
		writeJSON(w, http.StatusOK, p)
		return
	}
	// never the error itself: an upstream url carries the key
	refuse(w, http.StatusBadGateway, "the gif service did not answer")
}

func (r *relay) pageFrom(ctx context.Context, p provider, a ask) (page, error) {
	key := ""
	if a.trending {
		key = fmt.Sprintf("%s|%s|%d|%d", p.name(), a.lang, a.offset, a.limit)
		r.tmu.Lock()
		c, ok := r.trending[key]
		r.tmu.Unlock()
		if ok && time.Since(c.at) < trendingFor {
			return c.p, nil
		}
	}
	ctx, cancel := context.WithTimeout(ctx, 12*time.Second)
	defer cancel()
	items, more, err := p.fetch(ctx, a)
	if err != nil {
		return page{}, err
	}
	out := page{Provider: p.name(), Attribution: p.brand(), Items: []item{}}
	for _, it := range items {
		if len(out.Items) == a.limit {
			break
		}
		if r.sign(&it.Preview) && r.sign(&it.Full) {
			out.Items = append(out.Items, it)
		}
	}
	if more && a.offset+a.limit <= maxOffset {
		n := a.offset + a.limit
		out.Next = &n
	}
	if a.trending {
		r.tmu.Lock()
		now := time.Now()
		for k, c := range r.trending {
			if now.Sub(c.at) >= trendingFor {
				delete(r.trending, k)
			}
		}
		if len(r.trending) < 500 {
			r.trending[key] = cached{out, now}
		}
		r.tmu.Unlock()
	}
	return out, nil
}

// swaps a provider's url for one of ours. false: not a url we would fetch
func (r *relay) sign(m *media) bool {
	u, err := url.Parse(m.URL)
	if err != nil || !r.hostOK(u) || m.W <= 0 || m.H <= 0 || m.Bytes > maxMedia {
		return false
	}
	m.URL = "/gif/v1/m/" + r.token(u.String())
	return true
}

func (r *relay) mac(u string) []byte {
	h := hmac.New(sha256.New, r.secret)
	h.Write([]byte("kryfo-gif-media-v1\x00" + u))
	return h.Sum(nil)[:16]
}

func (r *relay) token(u string) string {
	b := base64.RawURLEncoding
	return b.EncodeToString([]byte(u)) + "." + b.EncodeToString(r.mac(u))
}

func (r *relay) untoken(t string) (string, bool) {
	if len(t) > 4096 {
		return "", false
	}
	a, s, ok := strings.Cut(t, ".")
	if !ok {
		return "", false
	}
	b := base64.RawURLEncoding
	u, err1 := b.DecodeString(a)
	sum, err2 := b.DecodeString(s)
	if err1 != nil || err2 != nil || !hmac.Equal(sum, r.mac(string(u))) {
		return "", false
	}
	return string(u), true
}

var kinds = map[string][]byte{
	"image/gif":  []byte("GIF8"),
	"image/webp": []byte("RIFF"),
	"video/mp4":  nil,
}

// streams one file a page of ours named. nothing a phone sent goes on, and
// nothing of the provider's comes back but the type and the bytes
func (r *relay) stream(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		refuse(w, http.StatusMethodNotAllowed, "get only")
		return
	}
	raw, ok := r.untoken(strings.TrimPrefix(req.URL.Path, "/gif/v1/m/"))
	if !ok {
		refuse(w, http.StatusNotFound, "not here")
		return
	}
	u, err := url.Parse(raw)
	if err != nil || !r.hostOK(u) {
		refuse(w, http.StatusForbidden, "not a gif host")
		return
	}
	if !mediaLim.allow() {
		refuse(w, http.StatusTooManyRequests, "slow down")
		return
	}
	select {
	case r.streams <- struct{}{}:
		defer func() { <-r.streams }()
	default:
		refuse(w, http.StatusServiceUnavailable, "busy")
		return
	}
	ctx, cancel := context.WithTimeout(req.Context(), 30*time.Second)
	defer cancel()
	up, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		refuse(w, http.StatusBadGateway, "the gif service did not answer")
		return
	}
	up.Header.Set("User-Agent", userAgent)
	up.Header.Set("Accept", "image/gif, image/webp, video/mp4")
	resp, err := r.media.Do(up)
	if err != nil {
		refuse(w, http.StatusBadGateway, "the gif service did not answer")
		return
	}
	defer resp.Body.Close()
	ct, _, _ := mime.ParseMediaType(resp.Header.Get("Content-Type"))
	magic, known := kinds[ct]
	if resp.StatusCode != http.StatusOK || !known || resp.ContentLength > maxMedia {
		refuse(w, http.StatusBadGateway, "not a gif")
		return
	}
	head := make([]byte, 12)
	n, _ := io.ReadFull(resp.Body, head)
	head = head[:n]
	if !looksLike(ct, magic, head) {
		refuse(w, http.StatusBadGateway, "not a gif")
		return
	}
	h := w.Header()
	h.Set("Content-Type", ct)
	h.Set("Cache-Control", "no-store")
	h.Set("X-Content-Type-Options", "nosniff")
	if resp.ContentLength > 0 {
		h.Set("Content-Length", strconv.FormatInt(resp.ContentLength, 10))
	}
	w.WriteHeader(http.StatusOK)
	if _, err := w.Write(head); err != nil {
		return
	}
	left := int64(maxMedia - len(head))
	copied, err := io.Copy(w, io.LimitReader(resp.Body, left+1))
	if err != nil || copied > left {
		// cut off: the phone sees a broken read, never half a file as whole
		panic(http.ErrAbortHandler)
	}
}

func looksLike(ct string, magic, head []byte) bool {
	switch ct {
	case "video/mp4":
		return len(head) >= 8 && string(head[4:8]) == "ftyp"
	case "image/webp":
		return len(head) >= 12 && bytes.HasPrefix(head, magic) && string(head[8:12]) == "WEBP"
	default:
		return bytes.HasPrefix(head, magic)
	}
}

// a token bucket for the whole service: rate a second, up to burst at once
type limiter struct {
	mu     sync.Mutex
	rate   float64
	burst  float64
	tokens float64
	last   time.Time
}

func newLimiter(rate, burst float64) *limiter {
	return &limiter{rate: rate, burst: burst, tokens: burst, last: time.Now()}
}

func (l *limiter) allow() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := time.Now()
	l.tokens += now.Sub(l.last).Seconds() * l.rate
	if l.tokens > l.burst {
		l.tokens = l.burst
	}
	l.last = now
	if l.tokens < 1 {
		return false
	}
	l.tokens--
	return true
}
