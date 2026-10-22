// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"sort"
)

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
// directory (Pair.Dir), then fetches padding up to the bundle's size class
// (WireBytes), with one progress over all of it.
func FetchBundle(ctx context.Context, get Getter, m *Manifest, lang, dir string, prog Progress) error {
	pairs := m.Bundle(lang)
	if len(pairs) == 0 {
		return ErrNoBundle
	}
	gz, _ := m.BundleBytes(lang)
	total := gz
	if !m.bySource {
		total = PadTo(gz)
	}
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
	if total > gz {
		fetchPad(ctx, get, m.Base+PadName, total-gz, func(n int64) {
			if prog != nil {
				prog(gz+n, total)
			}
		})
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
