// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"bufio"
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// SumsName is the mirror's list of what it serves, in sha256sum's format,
// so the box can check its files with sha256sum -c
const SumsName = "SHA256SUMS"

// FillMirror puts what the mirror serves into dir: for each language one
// file, BundleName, holding its gzips back to back as published, each
// fetched from the manifest's source and checked against its pins packed
// and unpacked, then noise up to the size class; and the list of hashes.
// a bundle already there whose parts check out is kept.
func FillMirror(ctx context.Context, get Getter, m *Manifest, dir string, say func(string)) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	var sums []string
	for _, lang := range m.Langs() {
		name := m.BundleName(lang)
		final := filepath.Join(dir, name)
		if !bundleOK(m, lang, final) {
			if say != nil {
				say(lang)
			}
			if err := fillBundle(ctx, get, m, lang, final); err != nil {
				return fmt.Errorf("%s: %w", lang, err)
			}
		}
		sum, err := fileSum(final)
		if err != nil {
			return err
		}
		sums = append(sums, sum+"  "+name)
	}
	sort.Strings(sums)
	return os.WriteFile(filepath.Join(dir, SumsName), []byte(strings.Join(sums, "\n")+"\n"), 0o644)
}

func fillBundle(ctx context.Context, get Getter, m *Manifest, lang, final string) error {
	files, gz := m.bundleFiles(lang)
	tmpDir, err := os.MkdirTemp(filepath.Dir(final), ".fill-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)
	out, err := os.Create(filepath.Join(tmpDir, "bundle"))
	if err != nil {
		return err
	}
	defer out.Close()
	w := bufio.NewWriterSize(out, 1<<20)
	for i, b := range files {
		part := filepath.Join(tmpDir, fmt.Sprintf("%d.gz", i))
		if err := fetchPart(ctx, get, m.SourceURL(b.f), b.f, part, nil); err != nil {
			return fmt.Errorf("%s: %w", b.f.Name, err)
		}
		if err := checkFile(part, b.f.GzSize, b.f.GzSHA256); err != nil {
			return fmt.Errorf("%s: %w", b.f.Name, err)
		}
		// what it unpacks to is checked too, then thrown away
		if err := unpack(part, filepath.Join(tmpDir, "check"), b.f); err != nil {
			return fmt.Errorf("%s: %w", b.f.Name, err)
		}
		os.Remove(filepath.Join(tmpDir, "check"))
		in, err := os.Open(part)
		if err != nil {
			return err
		}
		_, err = io.Copy(w, in)
		in.Close()
		if err != nil {
			return err
		}
		os.Remove(part)
	}
	if err := writeNoise(w, m.BundleID(lang), PadTo(gz)-gz); err != nil {
		return err
	}
	if err := w.Flush(); err != nil {
		return err
	}
	if err := out.Sync(); err != nil {
		return err
	}
	if err := out.Close(); err != nil {
		return err
	}
	if err := os.Chmod(out.Name(), 0o644); err != nil {
		return err
	}
	return os.Rename(out.Name(), final)
}

// a bundle on disk of the class's size whose parts match their pins
func bundleOK(m *Manifest, lang, p string) bool {
	fh, err := os.Open(p)
	if err != nil {
		return false
	}
	defer fh.Close()
	st, err := fh.Stat()
	files, gz := m.bundleFiles(lang)
	if err != nil || st.Size() != PadTo(gz) {
		return false
	}
	for _, b := range files {
		if checkReader(io.NewSectionReader(fh, b.off, b.f.GzSize), b.f.GzSize, b.f.GzSHA256) != nil {
			return false
		}
	}
	return true
}

func fileSum(p string) (string, error) {
	fh, err := os.Open(p)
	if err != nil {
		return "", err
	}
	defer fh.Close()
	h := sha256.New()
	if _, err := io.Copy(h, fh); err != nil {
		return "", err
	}
	return hexSum(h.Sum(nil)), nil
}
