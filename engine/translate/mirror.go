// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"context"
	"crypto/rand"
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

// FillMirror puts what the mirror serves into dir: every pinned file's
// gzip, fetched from the manifest's source and checked against its pins
// both packed and unpacked, named by its hash; the padding file; and the
// list of hashes. what is already there and checks out is kept.
func FillMirror(ctx context.Context, get Getter, m *Manifest, dir string, say func(string)) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	src := m.FromSource()
	var sums []string
	for _, p := range m.Pairs {
		for _, f := range p.Files {
			name := MirrorName(f)
			sums = append(sums, f.GzSHA256+"  "+name)
			final := filepath.Join(dir, name)
			if checkFile(final, f.GzSize, f.GzSHA256) == nil {
				continue
			}
			if say != nil {
				say(fmt.Sprintf("%s-%s %s", p.From, p.To, f.Name))
			}
			part := final + ".part"
			if err := fetchPart(ctx, get, src.URL(f), f, part, nil); err != nil {
				return fmt.Errorf("%s: %w", f.Name, err)
			}
			if err := checkFile(part, f.GzSize, f.GzSHA256); err != nil {
				os.Remove(part)
				return fmt.Errorf("%s: %w", f.Name, err)
			}
			// what it unpacks to is checked too, then thrown away
			tmp := filepath.Join(dir, ".check-"+f.Name)
			err := unpack(part, tmp, f)
			os.Remove(tmp)
			if err != nil {
				return fmt.Errorf("%s: %w", f.Name, err)
			}
			if err := os.Rename(part, final); err != nil {
				return err
			}
		}
	}
	if err := writePad(filepath.Join(dir, PadName)); err != nil {
		return err
	}
	sort.Strings(sums)
	return os.WriteFile(filepath.Join(dir, SumsName), []byte(strings.Join(sums, "\n")+"\n"), 0o644)
}

// noise, so nothing on the way could shrink it
func writePad(p string) error {
	if st, err := os.Stat(p); err == nil && st.Size() == PadSize {
		return nil
	}
	fh, err := os.CreateTemp(filepath.Dir(p), ".pad-*")
	if err != nil {
		return err
	}
	_, err = io.CopyN(fh, rand.Reader, PadSize)
	if cerr := fh.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Chmod(fh.Name(), 0o644)
	}
	if err == nil {
		err = os.Rename(fh.Name(), p)
	}
	if err != nil {
		os.Remove(fh.Name())
	}
	return err
}
