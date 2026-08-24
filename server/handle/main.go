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
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
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

func refuse(w http.ResponseWriter, msg string) {
	writeJSON(w, http.StatusOK, map[string]any{"ok": false, "error": msg})
}

func main() {
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

	mux := http.NewServeMux()

	mux.HandleFunc("/handle/check", func(w http.ResponseWriter, r *http.Request) {
		h := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("h")))
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
		if in.Invite == "" || len(in.Invite) > 8000 {
			refuse(w, "bad invite")
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
		if old, ok := st.get(in.Handle); ok && old.Pubkey != in.Pubkey {
			refuse(w, "that handle is taken")
			return
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
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprint(w, page("not found", "", "", ""))
			return
		}
		h := strings.ToLower(strings.TrimPrefix(r.URL.Path, "/@"))
		h = strings.Trim(h, "/")
		e, ok := st.get(h)
		if !ok {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprint(w, page("not found", "", "", ""))
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Referrer-Policy", "no-referrer")
		fmt.Fprint(w, page(h, e.Bio, e.Invite, fingerprint(e.Pubkey)))
	})

	log.Printf("handles: listening on %s, store in %s", addr, dir)
	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
		// deliberately no ErrorLog: a request that fails should not leave a
		// line behind with an address in it.
		ErrorLog: log.New(discard{}, "", 0),
	}
	log.Fatal(srv.ListenAndServe())
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

const head = `<meta name=viewport content="width=device-width,initial-scale=1">
<meta name=referrer content=no-referrer>
<title>kryfo</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Fraunces:ital,wght@0,300;1,300&family=Instrument+Sans:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap');
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
