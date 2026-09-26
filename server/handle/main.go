// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the handle registry and the public page it serves.
//
// what this holds, and nothing else: a handle, the invite it points at, a
// short bio someone chose to write, and the identity key that claimed it.
// the invite is already public - it is the qr code. the bio is written to be
// read.
//
// what it deliberately does not hold: any record of who looked anyone up.
// no access log, no analytics, no cookie, no referrer. a visitor arrives,
// gets html, and leaves nothing behind. that is not a policy, it is the
// absence of the code that would do it.
//
// ownership is an ed25519 signature over the handle, made with the identity
// key inside the invite. so a handle cannot be pointed at someone else's
// invite, and only whoever claimed it can release it.

import (
	"context"
	"crypto/ed25519"
	"embed"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unicode"
)

var handleOK = regexp.MustCompile(`^[a-z0-9_]{3,20}$`)

// names that would let someone pose as us, or that collide with paths we
// might want later.
var reserved = map[string]bool{
	"admin": true, "kryfo": true, "support": true, "help": true,
	"root": true, "system": true, "official": true, "team": true,
	"security": true, "abuse": true, "handle": true, "api": true,
	"well": true, "static": true, "assets": true, "about": true,
}

type entry struct {
	Handle    string `json:"handle"`
	Invite    string `json:"invite"`
	Bio       string `json:"bio"`
	Pubkey    string `json:"pubkey"`
	ClaimedAt int64  `json:"claimed_at"`
	// in search only when the owner asked for it, under a name they chose.
	// every handle claimed before search existed has none of these and
	// stays out of it until its owner opts in. ListedAt is the time on the
	// owner's last signed change, so an older one cannot be replayed.
	Listed   bool   `json:"listed,omitempty"`
	Name     string `json:"name,omitempty"`
	ListedAt int64  `json:"listed_at,omitempty"`
}

type store struct {
	mu   sync.RWMutex
	path string
	m    map[string]entry
}

func openStore(path string) *store {
	s := &store{path: path, m: map[string]entry{}}
	b, err := os.ReadFile(path)
	if err == nil {
		_ = json.Unmarshal(b, &s.m)
	}
	return s
}

func (s *store) get(h string) (entry, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	e, ok := s.m[h]
	return e, ok
}

func (s *store) put(e entry) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.m[e.Handle] = e
	return s.flush()
}

func (s *store) del(h string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.m, h)
	return s.flush()
}

// caller holds the lock. written to a temp file and renamed so a crash
// mid-write cannot leave a half-parsed registry behind.
func (s *store) flush() error {
	b, err := json.MarshalIndent(s.m, "", "  ")
	if err != nil {
		return err
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, s.path)
}

func verify(handle, pubHex, sigHex string) bool {
	pub, err := hex.DecodeString(pubHex)
	if err != nil || len(pub) != ed25519.PublicKeySize {
		return false
	}
	sig, err := hex.DecodeString(sigHex)
	if err != nil || len(sig) != ed25519.SignatureSize {
		return false
	}
	return ed25519.Verify(pub, []byte("kryfo-handle-v1:"+handle), sig)
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	// nothing to cache and nothing to share
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

// the invite is rendered into an href on the public page, so its scheme
// matters as much as its characters. html.EscapeString stops a value breaking
// out of the attribute; it does nothing about "javascript:alert(1)", which
// would render as a working link and run on this origin when someone presses
// "message on kryfo".
//
// so only the shape the app actually builds is accepted:
//
//	kryfo://share?id=..&onion=..&xpub=..            v1
//	kryfo://share?id=..&onion=..&v=2&bundle=..      v2
//	kryfo://share?id=..&onion=..&v=3&bundle=..&fc=..  v3
//
// anything else is a 400. run `handle -check-invites <file>` over the live
// store before deploying this, or a stricter rule than reality locks someone
// out of their own page.
func inviteOK(s string) bool {
	if s == "" || len(s) > 8000 {
		return false
	}
	u, err := url.Parse(s)
	if err != nil || u.Scheme != "kryfo" || u.Host != "share" {
		return false
	}
	q := u.Query()
	if q.Get("id") == "" || q.Get("onion") == "" {
		return false
	}
	switch q.Get("v") {
	case "", "1":
		return q.Get("xpub") != ""
	case "2", "3":
		return q.Get("bundle") != ""
	}
	return false
}

func refuseCode(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]any{"ok": false, "error": msg})
}

func refuse(w http.ResponseWriter, msg string) {
	writeJSON(w, http.StatusOK, map[string]any{"ok": false, "error": msg})
}

// the three faces the page is set in, served from here. they came from
// google's font host before, which put every visitor's address in front of
// google on a page whose whole promise is that nobody is told who looked.
// the same files the app ships, under the open font license beside them.
//
//go:embed fonts/*.ttf
var fontFS embed.FS

// a pre-deploy gate. the invite rule below is new, and a rule stricter than
// the store locks people out of their own pages, so read the live file and
// say so before swapping the binary:
//
//	handle -check-invites /opt/kryfo-handles/handles.json
//
// exits 0 when every invite passes, 1 when any does not, naming them.
func checkInvites(path string) int {
	b, err := os.ReadFile(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "cannot read %s: %v\n", path, err)
		return 2
	}
	var all map[string]entry
	if err := json.Unmarshal(b, &all); err != nil {
		fmt.Fprintf(os.Stderr, "cannot parse %s: %v\n", path, err)
		return 2
	}
	bad := 0
	names := make([]string, 0, len(all))
	for h := range all {
		names = append(names, h)
	}
	sort.Strings(names)
	for _, h := range names {
		if !inviteOK(all[h].Invite) {
			bad++
			inv := all[h].Invite
			if len(inv) > 70 {
				inv = inv[:70] + "…"
			}
			fmt.Printf("  WOULD REJECT @%s  %q\n", h, inv)
		}
	}
	fmt.Printf("%d handles, %d would be rejected by the new invite rule\n",
		len(all), bad)
	if bad > 0 {
		return 1
	}
	return 0
}

func main() {
	if len(os.Args) == 3 && os.Args[1] == "-check-invites" {
		os.Exit(checkInvites(os.Args[2]))
	}
	addr := os.Getenv("HANDLE_ADDR")
	if addr == "" {
		addr = "127.0.0.1:3336"
	}
	dir := os.Getenv("HANDLE_DIR")
	if dir == "" {
		dir = "/opt/kryfo-handles"
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		log.Fatal(err)
	}
	st := openStore(filepath.Join(dir, "handles.json"))

	log.Printf("handles: listening on %s, store in %s", addr, dir)
	log.Fatal(newServer(addr, st, newLimiter(2, 20)).ListenAndServe())
}

// the server: the routes, and a counter on every connection so search can
// be limited per connection. no address is kept, only the count.
func newServer(addr string, st *store, lim *limiter) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           routes(st, lim),
		ReadHeaderTimeout: 10 * time.Second,
		ConnContext: func(ctx context.Context, _ net.Conn) context.Context {
			return context.WithValue(ctx, connKey{}, new(atomic.Int32))
		},
		// deliberately no ErrorLog: a request that fails should not leave a
		// line behind with an address in it.
		ErrorLog: log.New(discard{}, "", 0),
	}
}

func routes(st *store, lim *limiter) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/handle/check", func(w http.ResponseWriter, r *http.Request) {
		var raw string
		switch {
		case r.Method == http.MethodPost && r.URL.RawQuery == "":
			var body struct {
				H string `json:"h"`
			}
			if json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<10)).Decode(&body) != nil {
				refuseCode(w, http.StatusBadRequest, "bad request")
				return
			}
			raw = body.H
		case r.Method == http.MethodGet:
			// apps up to 0.4.1 still ask in the url. drop this once they are gone
			raw = r.URL.Query().Get("h")
		default:
			refuseCode(w, http.StatusMethodNotAllowed, "post the name in the body")
			return
		}
		h := strings.ToLower(strings.TrimSpace(raw))
		if !handleOK.MatchString(h) || reserved[h] {
			writeJSON(w, http.StatusOK, map[string]any{"free": false})
			return
		}
		_, taken := st.get(h)
		writeJSON(w, http.StatusOK, map[string]any{"free": !taken})
	})

	mux.HandleFunc("/handle/claim", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			refuse(w, "post only")
			return
		}
		var in entry
		var sig string
		var raw map[string]string
		if json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10)).Decode(&raw) != nil {
			refuse(w, "bad request")
			return
		}
		in = entry{
			Handle: strings.ToLower(strings.TrimSpace(raw["handle"])),
			Invite: raw["invite"],
			Bio:    raw["bio"],
			Pubkey: raw["pubkey"],
		}
		sig = raw["sig"]
		if !handleOK.MatchString(in.Handle) || reserved[in.Handle] {
			refuse(w, "that handle is not available")
			return
		}
		if !inviteOK(in.Invite) {
			refuseCode(w, http.StatusBadRequest, "bad invite")
			return
		}
		if len(in.Bio) > 200 {
			in.Bio = in.Bio[:200]
		}
		if !verify(in.Handle, in.Pubkey, sig) {
			refuse(w, "signature does not match")
			return
		}
		// re-claiming your own handle repoints it, which is how someone
		// updates an invite after a reinstall. anyone else is refused.
		if old, ok := st.get(in.Handle); ok {
			if old.Pubkey != in.Pubkey {
				refuse(w, "that handle is taken")
				return
			}
			// the app repoints on every start; that must not take someone
			// out of search, or put them back into it
			in.Listed, in.Name, in.ListedAt = old.Listed, old.Name, old.ListedAt
		}
		in.ClaimedAt = time.Now().Unix()
		if err := st.put(in); err != nil {
			refuse(w, "could not save")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	})

	mux.HandleFunc("/handle/release", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			refuse(w, "post only")
			return
		}
		var raw map[string]string
		if json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10)).Decode(&raw) != nil {
			refuse(w, "bad request")
			return
		}
		h := strings.ToLower(strings.TrimSpace(raw["handle"]))
		e, ok := st.get(h)
		if !ok {
			writeJSON(w, http.StatusOK, map[string]any{"ok": true})
			return
		}
		if e.Pubkey != raw["pubkey"] || !verify(h, raw["pubkey"], raw["sig"]) {
			refuse(w, "not yours to release")
			return
		}
		if err := st.del(h); err != nil {
			refuse(w, "could not save")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	})

	// nip-05 shaped, so other nostr clients can resolve a kryfo handle too
	mux.HandleFunc("/handle/font/", func(w http.ResponseWriter, r *http.Request) {
		name := strings.TrimPrefix(r.URL.Path, "/handle/font/")
		b, err := fontFS.ReadFile("fonts/" + filepath.Base(name))
		if err != nil || !strings.HasSuffix(name, ".ttf") {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "font/ttf")
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		_, _ = w.Write(b)
	})

	mux.HandleFunc("/.well-known/kryfo.json", func(w http.ResponseWriter, r *http.Request) {
		h := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("name")))
		e, ok := st.get(h)
		if !ok {
			writeJSON(w, http.StatusNotFound, map[string]any{})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"names":  map[string]string{h: e.Pubkey},
			"invite": e.Invite,
		})
	})

	// the public page. one link for a bio, opening straight into a private
	// chat. static, no analytics, nothing recorded about whoever reads it.
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.URL.Path, "/@") {
			writeHTMLHeaders(w)
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprint(w, page("not found", "", "", ""))
			return
		}
		h := strings.ToLower(strings.TrimPrefix(r.URL.Path, "/@"))
		h = strings.Trim(h, "/")
		e, ok := st.get(h)
		if !ok {
			writeHTMLHeaders(w)
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprint(w, page("not found", "", "", ""))
			return
		}
		writeHTMLHeaders(w)
		w.Header().Set("Cache-Control", "no-store")
		fmt.Fprint(w, page(h, e.Bio, e.Invite, fingerprint(e.Pubkey)))
	})

	mux.HandleFunc("/handle/listing", listingHandler(st))
	mux.HandleFunc("/handle/search", searchHandler(st, lim))
	return mux
}

type discard struct{}

func (discard) Write(p []byte) (int, error) { return len(p), nil }

// the first eight hex characters of the identity key, spaced, so someone can
// read it out and compare against what the app shows.
func fingerprint(pub string) string {
	p := strings.ToUpper(pub)
	if len(p) < 8 {
		return ""
	}
	return p[0:4] + " " + p[4:8]
}

func page(handle, bio, invite, fp string) string {
	if invite == "" {
		return `<!doctype html><meta charset=utf-8>` + head + `
<div class=wrap><div class=card>
<div class=name>not here</div>
<p class=bio>no one has claimed this handle.</p>
</div></div>`
	}
	return `<!doctype html><meta charset=utf-8>` + head + `
<div class=wrap><div class=card>
  <div class=seal>` + html.EscapeString(strings.ToUpper(handle[:1])) + `</div>
  <div class=name>@` + html.EscapeString(handle) + `</div>
  <div class=verified>verified handle</div>
  <p class=bio>` + html.EscapeString(bio) + `</p>
  <a class=btn href="` + html.EscapeString(invite) + `">message on kryfo</a>
  <div class=fp>key fingerprint · ` + html.EscapeString(fp) + `<br><span>check it matches in the app before you trust it</span></div>
  <div class=foot>this page learns nothing about you · no analytics, no cookies, no log</div>
</div></div>`
}

// no script-src at all, so nothing on this page can execute - not an inline
// block, not a src, and not a javascript: url in an href. the fonts and the
// one inline <style> below are the only things allowed, and both are ours.
const csp = "default-src 'none'; style-src 'self' 'unsafe-inline'; " +
	"font-src 'self'; base-uri 'none'; form-action 'none'; " +
	"frame-ancestors 'none'"

func writeHTMLHeaders(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Content-Security-Policy", csp)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Referrer-Policy", "no-referrer")
	w.Header().Set("X-Frame-Options", "DENY")
}

const head = `<meta name=viewport content="width=device-width,initial-scale=1">
<meta name=referrer content=no-referrer>
<title>kryfo</title>
<style>
@font-face{font-family:Fraunces;font-weight:100 900;font-display:swap;src:url(/handle/font/Fraunces.ttf) format('truetype')}
@font-face{font-family:'Instrument Sans';font-weight:400 700;font-display:swap;src:url(/handle/font/InstrumentSans.ttf) format('truetype')}
@font-face{font-family:'JetBrains Mono';font-weight:100 800;font-display:swap;src:url(/handle/font/JetBrainsMono.ttf) format('truetype')}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;background:#0D0B09;color:#F5F1EA;
     font-family:'Instrument Sans',system-ui,sans-serif;
     display:flex;align-items:center;justify-content:center;padding:24px}
.wrap{width:100%;max-width:400px}
.card{background:#161310;border:1px solid #2F2922;border-radius:20px;padding:32px 26px;text-align:center}
.seal{width:60px;height:60px;margin:0 auto 18px;border-radius:50%;
      background:linear-gradient(145deg,#F8BC5C,#6E2F07);
      display:flex;align-items:center;justify-content:center;
      font-family:Fraunces,serif;font-size:26px;color:#2A1400}
.name{font-family:Fraunces,serif;font-size:25px;font-weight:300}
.verified{font-family:'JetBrains Mono',monospace;font-size:10.5px;letter-spacing:.1em;
          color:#34D399;margin-top:7px}
.bio{color:#C8C0B5;font-size:14px;line-height:1.6;margin:20px 0 24px}
.btn{display:block;padding:13px;border-radius:999px;background:#F59E0B;color:#0D0B09;
     text-decoration:none;font-weight:600;font-size:14.5px}
.fp{font-family:'JetBrains Mono',monospace;font-size:10.5px;color:#A79E92;
    margin-top:22px;line-height:1.7}
.fp span{color:#8F8579}
.foot{margin-top:20px;padding-top:18px;border-top:1px solid #2F2922;
      font-size:11px;color:#A79E92}
</style>`

// ---- search ----
//
// people who asked to be found can be found by their handle or the name they
// gave. nobody else: a handle and being searchable are separate choices, and
// every handle claimed before this existed stays out until its owner opts
// in. what a search asked for is never written down anywhere: there is no
// log line in this file, the server's error log is discarded, and the
// answer is marked not to be stored.
//
// scraping the list is made slow rather than impossible: at least three
// characters, no wildcards, twenty answers at most, a cap per connection and
// one for the whole service. the requests come in over tor, so there is no
// address to limit by, and none is kept.

const (
	searchMax       = 20
	perConnSearches = 30
	nameMax         = 40
	bioInSearch     = 120
	listingSkew     = 10 * 60 // seconds a listing change may be off the clock
)

type connKey struct{}

// the message an owner signs to go into search or out of it. the time
// makes each change once only, the name is signed with it so nobody else
// can change what the search shows.
func listingMsg(h string, listed bool, ts int64, name string) string {
	l := "0"
	if listed {
		l = "1"
	}
	return fmt.Sprintf("kryfo-handle-list-v1:%s:%s:%d:%s", h, l, ts, name)
}

func verifyMsg(pubHex, sigHex, msg string) bool {
	pub, err := hex.DecodeString(pubHex)
	if err != nil || len(pub) != ed25519.PublicKeySize {
		return false
	}
	sig, err := hex.DecodeString(sigHex)
	if err != nil || len(sig) != ed25519.SignatureSize {
		return false
	}
	return ed25519.Verify(pub, []byte(msg), sig)
}

// a name as search shows it: no control characters, single spaces, forty
// characters at most
func cleanName(s string) string {
	var b strings.Builder
	space := false
	n := 0
	for _, r := range strings.TrimSpace(s) {
		// a tab or a line break is a space; anything else invisible goes
		if unicode.IsSpace(r) {
			if !space && b.Len() > 0 {
				b.WriteRune(' ')
				n++
			}
			space = true
			continue
		}
		if unicode.IsControl(r) || r == '\u200e' || r == '\u200f' ||
			(r >= '\u202a' && r <= '\u202e') || (r >= '\u2066' && r <= '\u2069') {
			continue
		}
		space = false
		b.WriteRune(r)
		n++
		if n >= nameMax {
			break
		}
	}
	return strings.TrimSpace(b.String())
}

func listingHandler(st *store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			refuse(w, "post only")
			return
		}
		var raw map[string]string
		if json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10)).Decode(&raw) != nil {
			refuse(w, "bad request")
			return
		}
		h := strings.ToLower(strings.TrimSpace(raw["handle"]))
		e, ok := st.get(h)
		if !ok {
			refuse(w, "no such handle")
			return
		}
		var ts int64
		if _, err := fmt.Sscan(raw["ts"], &ts); err != nil {
			refuse(w, "bad request")
			return
		}
		now := time.Now().Unix()
		if ts < now-listingSkew || ts > now+listingSkew {
			refuse(w, "check the phone's clock")
			return
		}
		if ts <= e.ListedAt {
			refuse(w, "an older change")
			return
		}
		listed := raw["listed"] == "1"
		if raw["listed"] != "1" && raw["listed"] != "0" {
			refuse(w, "bad request")
			return
		}
		name := raw["name"]
		if e.Pubkey != raw["pubkey"] ||
			!verifyMsg(raw["pubkey"], raw["sig"], listingMsg(h, listed, ts, name)) {
			refuse(w, "not yours to change")
			return
		}
		e.Listed = listed
		e.ListedAt = ts
		e.Name = ""
		if listed {
			e.Name = cleanName(name)
		}
		if err := st.put(e); err != nil {
			refuse(w, "could not save")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	}
}

// what someone typed, as it is matched: lowercase, no leading @, single
// spaces. ok when it is 3 to 32 characters of letters, digits, spaces and
// _ - . with at least three letters or digits: nothing that works as a
// wildcard, and nothing short enough to sweep the list.
func searchQuery(raw string) (string, bool) {
	q := strings.ToLower(strings.TrimSpace(raw))
	q = strings.TrimPrefix(q, "@")
	q = strings.Join(strings.Fields(q), " ")
	n, alnum := 0, 0
	for _, r := range q {
		n++
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r):
			alnum++
		case r == ' ' || r == '_' || r == '-' || r == '.':
		default:
			return "", false
		}
	}
	return q, n >= 3 && n <= 32 && alnum >= 3
}

type hit struct {
	Handle   string `json:"handle"`
	Name     string `json:"name,omitempty"`
	Bio      string `json:"bio,omitempty"`
	Verified bool   `json:"verified"`
	FP       string `json:"fp"`
}

func (s *store) search(q string) []hit {
	type ranked struct {
		rank int
		e    entry
	}
	var found []ranked
	s.mu.RLock()
	for _, e := range s.m {
		if !e.Listed {
			continue
		}
		rank := -1
		switch {
		case e.Handle == q:
			rank = 0
		case strings.HasPrefix(e.Handle, q):
			rank = 1
		case strings.Contains(e.Handle, q):
			rank = 2
		case e.Name != "" && strings.Contains(strings.ToLower(e.Name), q):
			rank = 3
		}
		if rank >= 0 {
			found = append(found, ranked{rank, e})
		}
	}
	s.mu.RUnlock()
	sort.Slice(found, func(i, j int) bool {
		if found[i].rank != found[j].rank {
			return found[i].rank < found[j].rank
		}
		return found[i].e.Handle < found[j].e.Handle
	})
	if len(found) > searchMax {
		found = found[:searchMax]
	}
	out := make([]hit, 0, len(found))
	for _, f := range found {
		bio := []rune(f.e.Bio)
		if len(bio) > bioInSearch {
			bio = append(bio[:bioInSearch], '…')
		}
		out = append(out, hit{
			Handle: f.e.Handle,
			Name:   f.e.Name,
			Bio:    string(bio),
			// the handle is held by the key that signed it: the same
			// "verified handle" its page says
			Verified: true,
			FP:       fingerprint(f.e.Pubkey),
		})
	}
	return out
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

func searchHandler(st *store, lim *limiter) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// the question comes in the body, never in the url: a url can end up
		// in a proxy's error log, a body does not
		if r.Method != http.MethodPost || r.URL.RawQuery != "" {
			refuseCode(w, http.StatusMethodNotAllowed, "post the question in the body")
			return
		}
		var body struct {
			Q string `json:"q"`
		}
		if json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<10)).Decode(&body) != nil {
			refuseCode(w, http.StatusBadRequest, "bad request")
			return
		}
		q, ok := searchQuery(body.Q)
		if !ok {
			refuseCode(w, http.StatusBadRequest, "at least three letters or digits, nothing else")
			return
		}
		if c, _ := r.Context().Value(connKey{}).(*atomic.Int32); c != nil &&
			c.Add(1) > perConnSearches {
			w.Header().Set("Connection", "close")
			refuseCode(w, http.StatusTooManyRequests, "slow down")
			return
		}
		if !lim.allow() {
			refuseCode(w, http.StatusTooManyRequests, "slow down")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"results": st.search(q)})
	}
}
