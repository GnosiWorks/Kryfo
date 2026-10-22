// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// a mirror filled from the source serves what the app fetches, padding too
func TestFillMirrorServesTheApp(t *testing.T) {
	bf := newBundleFix(t)
	m := bf.local(t)
	m.Source = m.Base
	dir := t.TempDir()
	get := HTTPGetter(bf.srv.Client())
	if err := FillMirror(context.Background(), get, m, dir, nil); err != nil {
		t.Fatal(err)
	}
	sums, err := os.ReadFile(filepath.Join(dir, SumsName))
	if err != nil {
		t.Fatal(err)
	}
	n := 0
	for _, p := range m.Pairs {
		for _, f := range p.Files {
			n++
			if err := checkFile(filepath.Join(dir, f.GzSHA256+".gz"), f.GzSize, f.GzSHA256); err != nil {
				t.Fatalf("%s: %v", f.Name, err)
			}
			if !strings.Contains(string(sums), f.GzSHA256+"  "+f.GzSHA256+".gz\n") {
				t.Fatalf("%s not listed", f.Name)
			}
		}
	}
	if st, err := os.Stat(filepath.Join(dir, PadName)); err != nil || st.Size() != PadSize {
		t.Fatalf("pad %v %v", st, err)
	}
	left, _ := filepath.Glob(filepath.Join(dir, "*"))
	if len(left) != n+2 {
		t.Fatalf("mirror holds %v", left)
	}
	// nothing is fetched again
	hits := bf.hits.Load()
	if err := FillMirror(context.Background(), get, m, dir, nil); err != nil || bf.hits.Load() != hits {
		t.Fatalf("second fill: %v, %d requests", err, bf.hits.Load()-hits)
	}

	box := httptest.NewTLSServer(http.StripPrefix("/models/", http.FileServer(http.Dir(dir))))
	t.Cleanup(box.Close)
	app, err := m.withBase(box.URL + "/models/")
	if err != nil {
		t.Fatal(err)
	}
	var last, total int64
	into := t.TempDir()
	if err := FetchBundle(context.Background(), HTTPGetter(box.Client()), app, "zh", into, func(d, n int64) { last, total = d, n }); err != nil {
		t.Fatal(err)
	}
	if !BundleInstalled(app, "zh", into) || last != total || total != app.WireBytes("zh") {
		t.Fatalf("installed %v, %d of %d", BundleInstalled(app, "zh", into), last, total)
	}
}

// a source serving other bytes leaves nothing on the mirror
func TestFillMirrorRefusesWrongBytes(t *testing.T) {
	bf := newBundleFix(t)
	m := bf.local(t)
	m.Source = m.Base
	f := m.Pairs[0].Files[0]
	bad := append([]byte(nil), bf.gz[f.Path]...)
	bad[len(bad)/2] ^= 0xff
	bf.gz[f.Path] = bad
	dir := t.TempDir()
	if err := FillMirror(context.Background(), HTTPGetter(bf.srv.Client()), m, dir, nil); err == nil {
		t.Fatal("filled from a wrong file")
	}
	if _, err := os.Stat(filepath.Join(dir, MirrorName(f))); err == nil {
		t.Fatal("a wrong file is on the mirror")
	}
}
