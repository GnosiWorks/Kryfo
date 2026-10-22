// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// WithBase is the manifest with its files fetched from base instead: a
// mirror the person set. the pins stay, so a mirror can only serve the
// same bytes. "" keeps the manifest's own.
func (m *Manifest) WithBase(base string) (*Manifest, error) {
	if base == "" {
		return m, nil
	}
	if !strings.HasSuffix(base, "/") {
		base += "/"
	}
	c := *m
	c.Base = base
	u, err := url.Parse(base)
	if err != nil || u.Scheme != "https" || u.Host == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" {
		return nil, fmt.Errorf("%w: base %q", ErrManifest, base)
	}
	return &c, nil
}

// Langs is every language there is a bundle for, english aside.
func (m *Manifest) Langs() []string {
	seen := map[string]bool{}
	for _, p := range m.Pairs {
		for _, l := range []string{p.From, p.To} {
			if l != "en" {
				seen[l] = true
			}
		}
	}
	out := make([]string, 0, len(seen))
	for l := range seen {
		out = append(out, l)
	}
	sort.Strings(out)
	return out
}

// BundleBytes is what a language's bundle costs on the wire and on disk.
func (m *Manifest) BundleBytes(lang string) (gz, disk int64) {
	for _, p := range m.Bundle(lang) {
		gz += p.GzBytes()
		disk += p.DiskBytes()
	}
	return gz, disk
}

var ErrNoBundle = errors.New("no models for this language")

// FetchBundle puts both directions of lang under dir, each pair in its own
// directory (Pair.Dir), with one progress over the whole bundle.
func FetchBundle(ctx context.Context, get Getter, m *Manifest, lang, dir string, prog Progress) error {
	pairs := m.Bundle(lang)
	if len(pairs) == 0 {
		return ErrNoBundle
	}
	total, _ := m.BundleBytes(lang)
	var done int64
	for _, p := range pairs {
		base := done
		err := FetchPair(ctx, get, m, p, filepath.Join(dir, p.Dir()), func(d, _ int64) {
			if prog != nil {
				prog(base+d, total)
			}
		})
		if err != nil {
			return err
		}
		done += p.GzBytes()
	}
	return nil
}

// BundleInstalled reports whether every file of lang's bundle is under dir
// and checks out.
func BundleInstalled(m *Manifest, lang, dir string) bool {
	pairs := m.Bundle(lang)
	if len(pairs) == 0 {
		return false
	}
	for _, p := range pairs {
		if !Installed(p, filepath.Join(dir, p.Dir())) {
			return false
		}
	}
	return true
}

// RemoveBundle takes lang's files off the phone, half-fetched ones too.
func RemoveBundle(m *Manifest, lang, dir string) error {
	for _, p := range m.Bundle(lang) {
		if err := os.RemoveAll(filepath.Join(dir, p.Dir())); err != nil {
			return err
		}
	}
	return nil
}
