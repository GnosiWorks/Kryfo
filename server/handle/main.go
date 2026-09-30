// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the handle registry and the public page it serves.
// it holds a handle, its invite, a short bio and the identity key that
// claimed it. nothing about who looked anyone up: no access log, no
// analytics, no cookie, no referrer.
// ownership is an ed25519 signature by the identity key the invite's three
// words come from, so only whoever claimed a handle can repoint or release
// it, and nobody can point a handle at someone else's invite. a claim signs
// the handle, the invite and the time; a release signs the handle and the
// time under its own prefix. neither is taken once it is old, and neither
// stands in for the other.

import (
	"crypto/ed25519"
	"crypto/sha256"
	"embed"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"log"
	"maps"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
	"unicode"
)

var handleOK = regexp.MustCompile(`^[a-z0-9_]{3,20}$`)

// bytes an invite may take, a little over the longest the app builds
const maxInvite = 1024

// names that would let someone pose as us, or that collide with paths we
// might want later.
var reserved = map[string]bool{
	"admin": true, "kryfo": true, "support": true, "help": true,
	"root": true, "system": true, "official": true, "team": true,
	"security": true, "abuse": true, "handle": true, "api": true,
	"well": true, "static": true, "assets": true, "about": true,
}

// limits for everyone together: behind tor there is no caller to tell
// apart. older apps repoint their handle on every start, so writes are sized
// for that. a key costs nothing to make, so new names get a slower pace and
// a ceiling on top. reads are the check, the json lookup and the page.
var (
	readLim    = newLimiter(50, 200)
	writeLim   = newLimiter(5, 50)
	newNameLim = newLimiter(0.2, 20)
	maxHandles = 100000
)

type entry struct {
	Handle    string `json:"handle"`
	Invite    string `json:"invite"`
	Bio       string `json:"bio"`
	Pubkey    string `json:"pubkey"`
	ClaimedAt int64  `json:"claimed_at"`
	// the time on its last v2 claim. a handle that has one takes only v2
	// from then on, and nothing signed before it
	SignedAt int64 `json:"signed_at,omitempty"`
	// in search only when the owner opts in, under a name they chose.
	// ListedAt is the time on their last signed change, so an older one
	// cannot be replayed
	Listed   bool   `json:"listed,omitempty"`
	Name     string `json:"name,omitempty"`
	ListedAt int64  `json:"listed_at,omitempty"`
}

type store struct {
	mu   sync.RWMutex
	path string
	m    map[string]entry
	// handles released in the last while, with the time on the release, so
	// a claim signed before it cannot bring the handle back. in memory only:
	// past the clock window no such claim is taken anyway
	gone map[string]int64
	// one more with every change
	gen uint64

	// one file write at a time, and the last change it holds
	wmu   sync.Mutex
	saved uint64
}

// the store as the file holds it. only a file that is not there yet starts
// empty: one that cannot be read or parsed stops the registry, or the next
// write would replace every handle with what is left in memory
func loadStore(path string) (*store, error) {
	s := &store{path: path, m: map[string]entry{}, gone: map[string]int64{}}
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(b, &s.m); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return s, nil
}

func (s *store) get(h string) (entry, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	e, ok := s.m[h]
	return e, ok
}

// one handle as a change sees it, under the store's write lock
type tx struct {
	s       *store
	h       string
	changed bool
}

func (t *tx) get() (entry, bool) {
	e, ok := t.s.m[t.h]
	return e, ok
}

// the time on the handle's release in the last while, or 0
func (t *tx) goneAt() int64 { return t.s.gone[t.h] }

func (t *tx) count() int { return len(t.s.m) }

func (t *tx) put(e entry) {
	e.Handle = t.h
	t.s.m[t.h] = e
	t.changed = true
}

// takes the handle out, remembering the time on the release
func (t *tx) del(ts int64) {
	delete(t.s.m, t.h)
	old := time.Now().Unix() - 2*signSkew
	for k, v := range t.s.gone {
		if v < old {
			delete(t.s.gone, k)
		}
	}
	t.s.gone[t.h] = ts
	t.changed = true
}

// reads, checks and changes one handle under one lock, so nothing else
// changes it in between. the file is written after, outside that lock.
func (s *store) update(h string, f func(t *tx) error) error {
	s.mu.Lock()
	t := &tx{s: s, h: h}
	err := f(t)
	if t.changed {
		s.gen++
	}
	gen := s.gen
	s.mu.Unlock()
	if err != nil && !t.changed {
		return err
	}
	// an ok waits for the file even when nothing changed here: a retry after
	// a failed write finds its change in memory, not yet on disk
	if serr := s.save(gen); err == nil {
		err = serr
	}
	return err
}

// returns once the file holds change gen. reads go on while it is written,
// and changes made meanwhile go out together in the next write.
func (s *store) save(gen uint64) error {
	s.wmu.Lock()
	defer s.wmu.Unlock()
	if s.saved >= gen {
		return nil
	}
	s.mu.RLock()
	snap := maps.Clone(s.m)
	at := s.gen
	s.mu.RUnlock()
	if err := writeStore(s.path, snap); err != nil {
		return err
	}
	s.saved = at
	return nil
}

// written to a temp file, synced and renamed, so a crash mid-write cannot
// leave a half-parsed registry behind, then the folder is synced so the
// rename itself outlives a crash. no html escaping: an invite's & is one
// byte on disk, not six.
func writeStore(path string, m map[string]entry) error {
	tmp := path + ".tmp"
	f, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	enc := json.NewEncoder(f)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(m); err != nil {
		f.Close()
		return err
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		return err
	}
	d, err := os.Open(filepath.Dir(path))
	if err != nil {
		return err
	}
	if err := d.Sync(); err != nil {
		d.Close()
		return err
	}
	return d.Close()
}

// an answer other than ok, with its status
type refusal struct {
	code int
	msg  string
}

func (r refusal) Error() string { return r.msg }

// answers an update that did not go through: its refusal, or could not
// save. false when it did go through
func refused(w http.ResponseWriter, err error) bool {
	var r refusal
	switch {
	case err == nil:
		return false
	case errors.As(err, &r):
		refuseCode(w, r.code, r.msg)
	default:
		refuse(w, "could not save")
	}
	return true
}

// older apps sign the handle alone, for a claim and a release alike. taken
// while those apps are about; off, and only v2 is taken
var acceptV1 = true

// seconds a signed change may be off the registry's clock, either way
const signSkew = 10 * 60

func verify(handle, pubHex, sigHex string) bool {
	return verifyMsg(pubHex, sigHex, "kryfo-handle-v1:"+handle)
}

// what the app signs to claim or repoint a handle (engine/handle.go,
// handleClaimMsg): the invite goes in as its hash
func claimMsgV2(h, invite string, ts int64) string {
	sum := sha256.Sum256([]byte(invite))
	return fmt.Sprintf("kryfo-handle-claim-v2:%s:%s:%d", h, hex.EncodeToString(sum[:]), ts)
}

// and to release one (engine/handle.go, handleReleaseMsg)
func releaseMsgV2(h string, ts int64) string {
	return fmt.Sprintf("kryfo-handle-release-v2:%s:%d", h, ts)
}

// the signature on a claim or a release. v2 carries its time, which must be
// near the registry's clock; v1 carries none and gives ts 0. a non-empty why
// is the refusal.
func checkSig(raw map[string]string, h string, msgV2 func(int64) string) (ts int64, v2 bool, why string) {
	switch raw["v"] {
	case "2":
		if _, err := fmt.Sscan(raw["ts"], &ts); err != nil {
			return 0, true, "bad request"
		}
		now := time.Now().Unix()
		if ts < now-signSkew || ts > now+signSkew {
			return 0, true, "check the phone's clock"
		}
		if !verifyMsg(raw["pubkey"], raw["sig"], msgV2(ts)) {
			return 0, true, "signature does not match"
		}
		return ts, true, ""
	case "", "1":
		if !acceptV1 {
			return 0, false, "update the app"
		}
		if !verify(h, raw["pubkey"], raw["sig"]) {
			return 0, false, "signature does not match"
		}
		return 0, false, ""
	}
	return 0, false, "bad request"
}

// the three words a key is known by, the way the app derives them
// (engine/bridge.go, idFromPubkey). words.txt is the bip-39 english list
//
//go:embed words.txt
var wordsTxt string

var wordList = strings.Fields(wordsTxt)

func wordsOf(pubHex string) string {
	pub, err := hex.DecodeString(pubHex)
	if err != nil || len(pub) != ed25519.PublicKeySize || len(wordList) != 2048 {
		return ""
	}
	h := sha256.Sum256(pub)
	bits := uint64(h[0])<<32 | uint64(h[1])<<24 | uint64(h[2])<<16 | uint64(h[3])<<8 | uint64(h[4])
	return wordList[(bits>>22)&0x7FF] + "-" + wordList[(bits>>11)&0x7FF] + "-" + wordList[bits&0x7FF]
}

// whether the invite names the key that signs for it: its id is the three
// words that key makes
func inviteIsKeys(invite, pubHex string) bool {
	u, err := url.Parse(invite)
	if err != nil {
		return false
	}
	w := wordsOf(pubHex)
	return w != "" && u.Query().Get("id") == w
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	// nothing to cache and nothing to share
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

// the invite goes into an href on the public page, and html escaping does
// nothing about a "javascript:" url, so only the shapes the app builds pass:
//
//	kryfo://share?id=..&onion=..&xpub=..            v1
//	kryfo://share?id=..&onion=..&v=2&bundle=..      v2
//	kryfo://share?id=..&onion=..&v=3&bundle=..&fc=..  v3
//
// the longest the app builds is a v3 invite of 700 bytes (the longest words,
// a five digit registration id), so each handle stays small on disk.
func inviteOK(s string) bool {
	if s == "" || len(s) > maxInvite {
		return false
	}
	// a url is printable ascii, and with no quote or backslash in it the
	// file holds it at its own length
	for i := 0; i < len(s); i++ {
		if c := s[i]; c <= ' ' || c > '~' || c == '"' || c == '\\' {
			return false
		}
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

// the page's fonts, served from here so no visitor's address reaches a font
// host. the same files the app ships, under the open font license beside them.
//
//go:embed fonts/*.ttf
var fontFS embed.FS

// a pre-deploy gate: an invite rule stricter than the store locks people out
// of their own pages, so run this over the live file before a new binary:
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
	st, err := loadStore(filepath.Join(dir, "handles.json"))
	if err != nil {
		log.Fatalf("handles: %v", err)
	}
	// once no app in use signs v1 any more
	if os.Getenv("HANDLE_REFUSE_V1") == "1" {
		acceptV1 = false
	}

	log.Printf("handles: listening on %s, store in %s", addr, dir)
	log.Fatal(newServer(addr, st, newLimiter(2, 20)).ListenAndServe())
}

func newServer(addr string, st *store, lim *limiter) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           routes(st, lim),
		ReadHeaderTimeout: 10 * time.Second,
		// deliberately no ErrorLog: a request that fails should not leave a
		// line behind with an address in it.
		ErrorLog: log.New(discard{}, "", 0),
	}
}

func routes(st *store, lim *limiter) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/handle/check", func(w http.ResponseWriter, r *http.Request) {
		// plain text: an answer without "free" would read as taken
		if !readLim.allow() {
			http.Error(w, "slow down", http.StatusTooManyRequests)
			return
		}
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
			// todo: older apps ask in the url, drop this once they are gone
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
		var raw map[string]string
		if json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10)).Decode(&raw) != nil {
			refuse(w, "bad request")
			return
		}
		in := entry{
			Handle: strings.ToLower(strings.TrimSpace(raw["handle"])),
			Invite: raw["invite"],
			Bio:    raw["bio"],
			Pubkey: raw["pubkey"],
		}
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
		if !writeLim.allow() {
			refuseCode(w, http.StatusTooManyRequests, "slow down")
			return
		}
		ts, v2, why := checkSig(raw, in.Handle, func(ts int64) string {
			return claimMsgV2(in.Handle, in.Invite, ts)
		})
		if why != "" {
			refuse(w, why)
			return
		}
		if !inviteIsKeys(in.Invite, in.Pubkey) {
			refuse(w, "the invite is not yours")
			return
		}
		// re-claiming your own handle repoints it, which is how someone
		// updates an invite after a reinstall. anyone else is refused.
		err := st.update(in.Handle, func(t *tx) error {
			old, ok := t.get()
			if ok {
				if old.Pubkey != in.Pubkey {
					return refusal{http.StatusOK, "that handle is taken"}
				}
				if old.SignedAt > 0 && !v2 {
					return refusal{http.StatusOK, "update the app"}
				}
				if v2 && ts < old.SignedAt {
					return refusal{http.StatusOK, "an older change"}
				}
				// nothing changed, nothing written. the first v2 claim of a
				// handle is written all the same, so it takes only v2 after
				if old.Invite == in.Invite && old.Bio == in.Bio && (!v2 || old.SignedAt > 0) {
					return nil
				}
				// and that must not take someone out of search, or put them
				// back into it
				in.Listed, in.Name, in.ListedAt = old.Listed, old.Name, old.ListedAt
				in.SignedAt = old.SignedAt
			} else {
				if gone := t.goneAt(); gone > 0 && (!v2 || ts <= gone) {
					return refusal{http.StatusOK, "an older change"}
				}
				if t.count() >= maxHandles {
					return refusal{http.StatusServiceUnavailable, "the registry is full"}
				}
				if !newNameLim.allow() {
					return refusal{http.StatusTooManyRequests, "slow down"}
				}
			}
			if v2 {
				in.SignedAt = ts
			}
			in.ClaimedAt = time.Now().Unix()
			t.put(in)
			return nil
		})
		if refused(w, err) {
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
		if !writeLim.allow() {
			refuseCode(w, http.StatusTooManyRequests, "slow down")
			return
		}
		h := strings.ToLower(strings.TrimSpace(raw["handle"]))
		ts, v2, why := checkSig(raw, h, func(ts int64) string { return releaseMsgV2(h, ts) })
		if !v2 {
			ts = time.Now().Unix()
		}
		err := st.update(h, func(t *tx) error {
			e, ok := t.get()
			switch {
			case !ok:
				return nil
			case why == "signature does not match" || e.Pubkey != raw["pubkey"]:
				return refusal{http.StatusOK, "not yours to release"}
			case why != "":
				return refusal{http.StatusOK, why}
			case e.SignedAt > 0 && !v2:
				return refusal{http.StatusOK, "update the app"}
			case v2 && ts < e.SignedAt:
				return refusal{http.StatusOK, "an older change"}
			}
			t.del(ts)
			return nil
		})
		if refused(w, err) {
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	})

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

	// nip-05 shaped, so other nostr clients can resolve a kryfo handle too
	mux.HandleFunc("/.well-known/kryfo.json", func(w http.ResponseWriter, r *http.Request) {
		if !readLim.allow() {
			refuseCode(w, http.StatusTooManyRequests, "slow down")
			return
		}
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
		if !readLim.allow() {
			writeHTMLHeaders(w)
			w.WriteHeader(http.StatusTooManyRequests)
			fmt.Fprint(w, busyPage)
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

var busyPage = `<!doctype html><meta charset=utf-8>` + head + `
<div class=wrap><div class=card>
<div class=name>busy</div>
<p class=bio>too many people are looking right now. try again in a minute.</p>
</div></div>`

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

// no script-src at all, so nothing on this page can execute, not even a
// javascript: url in an href. the fonts and the one <style> block below are
// the only things allowed: the block by its hash, so no other style can get
// onto a page, not even through a bio.
var csp = "default-src 'none'; style-src '" + styleHash(head) + "'; " +
	"font-src 'self'; base-uri 'none'; form-action 'none'; " +
	"frame-ancestors 'none'"

func styleHash(h string) string {
	i := strings.Index(h, "<style>") + len("<style>")
	j := strings.Index(h, "</style>")
	sum := sha256.Sum256([]byte(h[i:j]))
	return "sha256-" + base64.StdEncoding.EncodeToString(sum[:])
}

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
// only owners who opted in can be found, by handle or given name. a query is
// never written down: no log line here, the error log is discarded and the
// answer is marked not to be stored. going through the whole list is slowed
// by a three-character minimum, no wildcards, twenty answers and a cap for
// the whole service. no caller is told apart: the only peer here is the
// proxy in front, and no address is kept.

const (
	searchMax   = 20
	nameMax     = 40
	bioInSearch = 120
	listingSkew = 10 * 60 // seconds a listing change may be off the clock
)

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
		if !writeLim.allow() {
			refuseCode(w, http.StatusTooManyRequests, "slow down")
			return
		}
		h := strings.ToLower(strings.TrimSpace(raw["handle"]))
		var ts int64
		_, tsErr := fmt.Sscan(raw["ts"], &ts)
		now := time.Now().Unix()
		listed := raw["listed"] == "1"
		name := raw["name"]
		signed := verifyMsg(raw["pubkey"], raw["sig"], listingMsg(h, listed, ts, name))
		// the rest of the entry as it is now, so a repoint or a release that
		// lands meanwhile is kept
		err := st.update(h, func(t *tx) error {
			e, ok := t.get()
			switch {
			case !ok:
				return refusal{http.StatusOK, "no such handle"}
			case tsErr != nil:
				return refusal{http.StatusOK, "bad request"}
			case ts < now-listingSkew || ts > now+listingSkew:
				return refusal{http.StatusOK, "check the phone's clock"}
			case ts <= e.ListedAt:
				return refusal{http.StatusOK, "an older change"}
			case raw["listed"] != "1" && raw["listed"] != "0":
				return refusal{http.StatusOK, "bad request"}
			case e.Pubkey != raw["pubkey"] || !signed:
				return refusal{http.StatusOK, "not yours to change"}
			}
			e.Listed = listed
			e.ListedAt = ts
			e.Name = ""
			if listed {
				e.Name = cleanName(name)
			}
			t.put(e)
			return nil
		})
		if refused(w, err) {
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	}
}

// the query as it is matched: lowercase, no leading @, single spaces. ok
// only without wildcards and long enough not to sweep the list
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
		if !lim.allow() {
			refuseCode(w, http.StatusTooManyRequests, "slow down")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"results": st.search(q)})
	}
}
