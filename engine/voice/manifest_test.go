// SPDX-License-Identifier: GPL-3.0-or-later
package voice

import (
	"strings"
	"testing"
)

const mirror = "http://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion/"

func TestPinnedModels(t *testing.T) {
	m, err := Pinned()
	if err != nil {
		t.Fatal(err)
	}
	// our own mirror, the one the translation packs come from
	if m.Base != mirror+"voice/" {
		t.Fatalf("base %q", m.Base)
	}
	if !strings.HasPrefix(m.Source, "https://huggingface.co/ggerganov/whisper.cpp/resolve/") {
		t.Fatalf("source %q", m.Source)
	}
	// a branch name in the url would let the files change under the pin
	if strings.Contains(m.Source, "/main/") {
		t.Fatalf("source %q is not pinned to a revision", m.Source)
	}
	if len(m.Models) != 1 {
		t.Fatalf("%d models, the base one only", len(m.Models))
	}
	base, ok := m.Model("base")
	if !ok || base.File != "ggml-base-q5_1.bin" || base.Size != 59707625 ||
		base.SHA256 != "422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898" {
		t.Fatalf("base model %+v", base)
	}
	if _, ok := m.Model("small"); ok {
		t.Fatal("a model nobody pinned")
	}
	if got := m.URL(base); got != m.Base+base.SHA256 {
		t.Fatalf("url %q", got)
	}
}

func TestParseRefuses(t *testing.T) {
	const sha = "422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898"
	good := `{"base":"https://h.example/m/","source":"https://s.example/r/","models":[{"id":"a","file":"a.bin","size":1,"sha256":"` + sha + `"}]}`
	if _, err := Parse([]byte(good)); err != nil {
		t.Fatalf("good manifest: %v", err)
	}
	onion := strings.Replace(good, "https://h.example/", mirror, 1)
	if _, err := Parse([]byte(onion)); err != nil {
		t.Fatalf("onion manifest: %v", err)
	}
	for name, s := range map[string]string{
		"not json":       `{`,
		"no models":      `{"base":"https://h.example/m/","source":"https://s.example/r/","models":[]}`,
		"plain http":     strings.Replace(good, "https://h.example", "http://h.example", 1),
		"short onion":    strings.Replace(good, "https://h.example", "http://abcdefghijklmnop.onion", 1),
		"onion source":   strings.Replace(good, "https://s.example/", mirror, 1),
		"no source":      strings.Replace(good, `"source":"https://s.example/r/",`, "", 1),
		"redirect hosts": strings.Replace(good, `"models"`, `"redirect_hosts":["hf.co"],"models"`, 1),
		"trailing":       good + `{}`,
		"no slash":       strings.Replace(good, "/m/", "/m", 1),
		"query":          strings.Replace(good, "/m/", "/m/?x=1", 1),
		"path in file":   strings.Replace(good, `"a.bin"`, `"../a.bin"`, 1),
		"dot file":       strings.Replace(good, `"a.bin"`, `".a.bin"`, 1),
		"slash file":     strings.Replace(good, `"a.bin"`, `"x/a.bin"`, 1),
		"no size":        strings.Replace(good, `"size":1`, `"size":0`, 1),
		"short hash":     strings.Replace(good, sha, sha[:62], 1),
		"upper hash":     strings.Replace(good, sha, strings.ToUpper(sha), 1),
		"no id":          strings.Replace(good, `"id":"a"`, `"id":""`, 1),
		"twice":          strings.Replace(good, `]}`, `,{"id":"a","file":"b.bin","size":1,"sha256":"`+sha+`"}]}`, 1),
	} {
		if _, err := Parse([]byte(s)); err == nil {
			t.Errorf("%s: parsed", name)
		}
	}
}
