// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
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

// Packs is every direction there is a pack for, "de-en", in manifest order.
func (m *Manifest) Packs() []string {
	out := make([]string, 0, len(m.Pairs))
	for _, p := range m.Pairs {
		out = append(out, p.From+"-"+p.To)
	}
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

// a bundle on the mirror is one file: its gzips back to back, then noise up
// to its size class. it is fetched as whole Chunks from the first byte to
// the last, in order, and checked and unpacked only once all of it is in,
// so every language of a class looks the same on the wire: the same number
// of requests, each the same size, with no pause between files.

// bundleFile is one gzip inside a bundle, where it starts
type bundleFile struct {
	dir string
	f   File
	off int64
}

func (m *Manifest) bundleFiles(lang string) ([]bundleFile, int64) {
	var out []bundleFile
	var off int64
	for _, p := range m.Bundle(lang) {
		for _, f := range p.Files {
			out = append(out, bundleFile{p.Dir(), f, off})
			off += f.GzSize
		}
	}
	return out, off
}

// BundleID names lang's bundle on the mirror. it is made from the pins, so
// the app and the mirror agree on it without a list from the box.
func (m *Manifest) BundleID(lang string) string {
	files, gz := m.bundleFiles(lang)
	h := sha256.New()
	fmt.Fprintf(h, "kryfo bundle 1\n%s\n%d\n%d\n", lang, gz, PadTo(gz))
	for _, b := range files {
		fmt.Fprintf(h, "%s %s\n", b.dir, b.f.GzSHA256)
	}
	return hexSum(h.Sum(nil))
}

// BundleName is the bundle's file on the mirror.
func (m *Manifest) BundleName(lang string) string { return m.BundleID(lang) + ".bin" }

// where a bundle under way is kept: in its first pair's directory, so the
// app counts it as on the phone. the part holds the real bytes, the mark
// how much of the whole bundle has come, padding included
const (
	partName = ".bundle.part"
	gotName  = ".bundle.got"
)

// FetchBundle puts both directions of lang under dir, each pair in its own
// directory (Pair.Dir), from the mirror's one file for it. a cut keeps what
// came, padding counted, and the next call goes on from there, so all the
// tries together send the whole class. one request at a time, and the
// first stop ends it; FetchBundleWith gets past stops by itself.
func FetchBundle(ctx context.Context, get Getter, m *Manifest, lang, dir string, prog Progress) error {
	return FetchBundleWith(ctx, Fetcher{Lane: func() (Getter, func()) { return get, nil }}, m, lang, dir, prog)
}

// FetchBundleWith is FetchBundle with f's lanes and retries.
func FetchBundleWith(ctx context.Context, f Fetcher, m *Manifest, lang, dir string, prog Progress) error {
	pairs := m.Bundle(lang)
	if len(pairs) == 0 {
		return ErrNoBundle
	}
	if BundleInstalled(m, lang, dir) {
		return nil
	}
	files, gz := m.bundleFiles(lang)
	wire := PadTo(gz)
	first := filepath.Join(dir, pairs[0].Dir())
	if err := os.MkdirAll(first, 0o700); err != nil {
		return err
	}
	part, gotPath := filepath.Join(first, partName), filepath.Join(first, gotName)
	fh, err := os.OpenFile(part, os.O_RDWR|os.O_CREATE, 0o600)
	if err != nil {
		return err
	}
	defer fh.Close()
	got, have := resumeAt(fh, gotPath, gz, wire)
	if prog != nil {
		prog(got+int64(len(have))*Chunk, wire)
	}
	if err := f.fill(ctx, m.Base+m.BundleName(lang), fh, gotPath, got, have, gz, wire, prog); err != nil {
		return err
	}
	if err := fh.Sync(); err != nil {
		return err
	}
	// all of it is in: now the checks and the unpacking, off the wire
	for _, b := range files {
		sec := io.NewSectionReader(fh, b.off, b.f.GzSize)
		if err := checkReader(sec, b.f.GzSize, b.f.GzSHA256); err != nil {
			os.Remove(part)
			os.Remove(gotPath)
			return fmt.Errorf("%s: %w", b.f.Name, err)
		}
	}
	for _, b := range files {
		into := filepath.Join(dir, b.dir)
		if err := os.MkdirAll(into, 0o700); err != nil {
			return err
		}
		sec := io.NewSectionReader(fh, b.off, b.f.GzSize)
		if err := unpackFrom(sec, filepath.Join(into, b.f.Name), b.f); err != nil {
			if errors.Is(err, ErrHash) || errors.Is(err, ErrSize) {
				os.Remove(part)
				os.Remove(gotPath)
			}
			return fmt.Errorf("%s: %w", b.f.Name, err)
		}
	}
	fh.Close()
	os.Remove(part)
	os.Remove(gotPath)
	os.Remove(gotPath + ".new")
	return nil
}

// where a bundle under way goes on from: whole Chunks only, and never past
// what the part file holds. [have]: the chunks in above that, by their
// first byte, each one the part file holds whole
func resumeAt(fh *os.File, gotPath string, gz, wire int64) (int64, map[int64]bool) {
	var got int64
	var above string
	if b, err := os.ReadFile(gotPath); err == nil {
		first, rest, _ := strings.Cut(strings.TrimSpace(string(b)), "\n")
		got, _ = strconv.ParseInt(strings.TrimSpace(first), 10, 64)
		above = strings.TrimSpace(rest)
	}
	size, err := fh.Seek(0, io.SeekEnd)
	if err != nil {
		size = 0
	}
	if got < 0 || got > wire {
		got = 0
	}
	if size < min(got, gz) {
		got = size
	}
	// all of it in is the one mark not on a chunk's edge
	if got != wire {
		got -= got % Chunk
	}
	have := map[int64]bool{}
	keep := min(got, gz)
	if above != "" {
		for _, t := range strings.Split(above, ",") {
			off, err := strconv.ParseInt(strings.TrimSpace(t), 10, 64)
			if err != nil || off < got || off%Chunk != 0 || off >= wire {
				continue
			}
			end := min(off+Chunk, gz)
			if off < gz && size < end {
				continue
			}
			have[off] = true
			keep = max(keep, end)
		}
	}
	if size > keep {
		fh.Truncate(keep)
	}
	return got, have
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
