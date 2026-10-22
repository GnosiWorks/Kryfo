// SPDX-License-Identifier: GPL-3.0-or-later

// Package voice holds what the engine knows of voice note transcripts: the
// speech models it may download, their pins, and the download itself. the
// models run in a separate library (voice/native), never in the engine.
package voice

import (
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"sync"
)

//go:embed models.json
var modelsJSON []byte

// Model is one downloadable speech model, pinned by size and sha256.
type Model struct {
	ID     string `json:"id"`
	File   string `json:"file"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
}

// Manifest is where the models are and what they must hash to.
type Manifest struct {
	Base string `json:"base"`
	// hosts the base may send a download on to, a name or any name under
	// it. empty: a redirect is not followed
	RedirectHosts []string `json:"redirect_hosts"`
	Models        []Model  `json:"models"`
}

var (
	pinnedOnce sync.Once
	pinned     *Manifest
	pinnedErr  error
)

// Pinned is the manifest built into the engine.
func Pinned() (*Manifest, error) {
	pinnedOnce.Do(func() { pinned, pinnedErr = Parse(modelsJSON) })
	return pinned, pinnedErr
}

// Parse reads and checks a manifest.
func Parse(b []byte) (*Manifest, error) {
	var m Manifest
	if err := json.Unmarshal(b, &m); err != nil {
		return nil, err
	}
	if err := checkBase(m.Base); err != nil {
		return nil, err
	}
	if len(m.Models) == 0 {
		return nil, errors.New("no models")
	}
	seen := map[string]bool{}
	for _, md := range m.Models {
		if md.ID == "" || seen[md.ID] {
			return nil, fmt.Errorf("model id %q", md.ID)
		}
		seen[md.ID] = true
		if !safeName(md.File) {
			return nil, fmt.Errorf("model file %q", md.File)
		}
		if md.Size <= 0 {
			return nil, fmt.Errorf("%s: size %d", md.ID, md.Size)
		}
		if h, err := hex.DecodeString(md.SHA256); err != nil || len(h) != 32 || md.SHA256 != strings.ToLower(md.SHA256) {
			return nil, fmt.Errorf("%s: sha256 %q", md.ID, md.SHA256)
		}
	}
	return &m, nil
}

// a plain file name: the model lands in the directory it is fetched to and
// nowhere else
func safeName(s string) bool {
	if s == "" || s == "." || s == ".." || strings.HasPrefix(s, ".") {
		return false
	}
	for _, r := range s {
		ok := r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-' || r == '_' || r == '.'
		if !ok {
			return false
		}
	}
	return true
}

// https anywhere, or plain http to an onion, which tor already encrypts
// end to end
func checkBase(base string) error {
	u, err := url.Parse(base)
	if err != nil {
		return err
	}
	if !strings.HasSuffix(u.Path, "/") || u.RawQuery != "" || u.Fragment != "" || u.User != nil {
		return fmt.Errorf("base %q", base)
	}
	switch {
	case u.Scheme == "https" && u.Host != "":
		return nil
	case u.Scheme == "http" && strings.HasSuffix(u.Hostname(), ".onion"):
		return nil
	}
	return fmt.Errorf("base %q: https or an onion only", base)
}

// WithBase is the manifest fetched from base instead, with the same pins.
// "" keeps the built-in host. another host serves the files itself, so it
// gets no redirects.
func (m *Manifest) WithBase(base string) (*Manifest, error) {
	if base == "" || base == m.Base {
		return m, nil
	}
	if err := checkBase(base); err != nil {
		return nil, err
	}
	c := *m
	c.Base = base
	c.RedirectHosts = nil
	return &c, nil
}

// Model is the model with id.
func (m *Manifest) Model(id string) (Model, bool) {
	for _, md := range m.Models {
		if md.ID == id {
			return md, true
		}
	}
	return Model{}, false
}

// URL is where md is fetched from.
func (m *Manifest) URL(md Model) string { return m.Base + md.File }

// RedirectOK says whether a download may follow a redirect to u: https,
// and a host the manifest names.
func (m *Manifest) RedirectOK(u *url.URL) bool {
	if u == nil || u.Scheme != "https" || u.User != nil {
		return false
	}
	host := strings.ToLower(u.Hostname())
	for _, h := range m.RedirectHosts {
		if host == h || strings.HasSuffix(host, "."+h) {
			return true
		}
	}
	return false
}
