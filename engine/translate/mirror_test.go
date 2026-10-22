// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// the mirror holds one file per language, the class's size, named from the
// pins, and the same bytes whoever fills it
func TestFillMirror(t *testing.T) {
	bf := newBundleFix(t)
	m := bf.local(t)
	sums, err := os.ReadFile(filepath.Join(bf.mirror, SumsName))
	if err != nil {
		t.Fatal(err)
	}
	left, _ := filepath.Glob(filepath.Join(bf.mirror, "*"))
	if len(left) != len(m.Langs())+1 {
		t.Fatalf("mirror holds %v", left)
	}
	for _, lang := range m.Langs() {
		p := filepath.Join(bf.mirror, m.BundleName(lang))
		st, err := os.Stat(p)
		if err != nil || st.Size() != m.WireBytes(lang) {
			t.Fatalf("%s: %v %v", lang, st, err)
		}
		if !bundleOK(m, lang, p) {
			t.Fatalf("%s: parts do not check out", lang)
		}
		sum, _ := fileSum(p)
		if !strings.Contains(string(sums), sum+"  "+m.BundleName(lang)+"\n") {
			t.Fatalf("%s not listed", lang)
		}
	}
	// nothing is fetched again
	hits := bf.hits.Load()
	if err := FillMirror(context.Background(), bf.get(), m, bf.mirror, nil); err != nil || bf.hits.Load() != hits {
		t.Fatalf("second fill: %v, %d requests", err, bf.hits.Load()-hits)
	}
	// a second mirror is the same, byte for byte
	other := t.TempDir()
	if err := FillMirror(context.Background(), bf.get(), m, other, nil); err != nil {
		t.Fatal(err)
	}
	for _, lang := range m.Langs() {
		a, _ := os.ReadFile(filepath.Join(bf.mirror, m.BundleName(lang)))
		b, _ := os.ReadFile(filepath.Join(other, m.BundleName(lang)))
		if !bytes.Equal(a, b) {
			t.Fatalf("%s differs between two fills", lang)
		}
	}
}

// a source serving other bytes leaves nothing on the mirror
func TestFillMirrorRefusesWrongBytes(t *testing.T) {
	bf := newBundleFix(t)
	m := bf.local(t)
	f := m.Pairs[0].Files[0]
	bad := append([]byte(nil), bf.gz[f.Path]...)
	bad[len(bad)/2] ^= 0xff
	bf.gz[f.Path] = bad
	dir := t.TempDir()
	if err := FillMirror(context.Background(), bf.get(), m, dir, nil); err == nil {
		t.Fatal("filled from a wrong file")
	}
	if _, err := os.Stat(filepath.Join(dir, m.BundleName("zh"))); err == nil {
		t.Fatal("a wrong bundle is on the mirror")
	}
}
