// SPDX-License-Identifier: GPL-3.0-or-later

// Package voice holds what the engine knows of voice note transcripts: the
// speech models it may download, their pins, and the download itself. the
// models run in a separate library (voice/native), never in the engine.
package voice

import (
	"bytes"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"regexp"
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

// Manifest is where the models are and what they must hash to. Base is
// our mirror, the only host the app asks; it serves each model under its
// sha256. Source is where the files were first published, which the mirror
// is filled from; the app never asks it.
type Manifest struct {
	Base   string  `json:"base"`
	Source string  `json:"source"`
	Models []Model `json:"models"`
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

// Parse reads and checks a manifest, refusing a field it does not know.
func Parse(b []byte) (*Manifest, error) {
	d := json.NewDecoder(bytes.NewReader(b))
	d.DisallowUnknownFields()
	var m Manifest
	if err := d.Decode(&m); err != nil {
		return nil, err
	}
	if d.More() {
		return nil, errors.New("trailing data")
	}
	if err := checkBase(m.Base); err != nil {
		return nil, err
	}
	if u, err := url.Parse(m.Source); err != nil || u.Scheme != "https" || checkBase(m.Source) != nil {
		return nil, fmt.Errorf("source %q", m.Source)
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

var onionRe = regexp.MustCompile(`^[a-z2-7]{56}\.onion$`)

// https anywhere, or plain http to an onion, which tor already encrypts
// end to end and authenticates by its name
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
	case u.Scheme == "http" && onionRe.MatchString(u.Host):
		return nil
	}
	return fmt.Errorf("base %q: https or an onion only", base)
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

// URL is where md is fetched from: the mirror names it by its hash, so
// the request says no more than the pin does
func (m *Manifest) URL(md Model) string { return m.Base + md.SHA256 }
