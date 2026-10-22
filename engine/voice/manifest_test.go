// SPDX-License-Identifier: GPL-3.0-or-later
package voice

import (
	"net/url"
	"strings"
	"testing"
)

func TestPinnedModels(t *testing.T) {
	m, err := Pinned()
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(m.Base, "https://huggingface.co/ggerganov/whisper.cpp/resolve/") {
		t.Fatalf("base %q", m.Base)
	}
	// a branch name in the url would let the files change under the pin
	if strings.Contains(m.Base, "/main/") {
		t.Fatalf("base %q is not pinned to a revision", m.Base)
	}
	base, ok := m.Model("base")
	if !ok || base.File != "ggml-base-q5_1.bin" || base.Size != 59707625 {
		t.Fatalf("base model %+v", base)
	}
	if _, ok := m.Model("small"); !ok {
		t.Fatal("no small model")
	}
	if _, ok := m.Model("large"); ok {
		t.Fatal("a model nobody pinned")
	}
	if got := m.URL(base); got != m.Base+"ggml-base-q5_1.bin" {
		t.Fatalf("url %q", got)
	}
}

func TestParseRefuses(t *testing.T) {
	const sha = "422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898"
	good := `{"base":"https://h.example/m/","models":[{"id":"a","file":"a.bin","size":1,"sha256":"` + sha + `"}]}`
	if _, err := Parse([]byte(good)); err != nil {
		t.Fatalf("good manifest: %v", err)
	}
	for name, s := range map[string]string{
		"not json":     `{`,
		"no models":    `{"base":"https://h.example/m/","models":[]}`,
		"plain http":   strings.Replace(good, "https://h.example", "http://h.example", 1),
		"no slash":     strings.Replace(good, "/m/", "/m", 1),
		"query":        strings.Replace(good, "/m/", "/m/?x=1", 1),
		"path in file": strings.Replace(good, `"a.bin"`, `"../a.bin"`, 1),
		"dot file":     strings.Replace(good, `"a.bin"`, `".a.bin"`, 1),
		"slash file":   strings.Replace(good, `"a.bin"`, `"x/a.bin"`, 1),
		"no size":      strings.Replace(good, `"size":1`, `"size":0`, 1),
		"short hash":   strings.Replace(good, sha, sha[:62], 1),
		"upper hash":   strings.Replace(good, sha, strings.ToUpper(sha), 1),
		"no id":        strings.Replace(good, `"id":"a"`, `"id":""`, 1),
		"twice":        strings.Replace(good, `]}`, `,{"id":"a","file":"b.bin","size":1,"sha256":"`+sha+`"}]}`, 1),
	} {
		if _, err := Parse([]byte(s)); err == nil {
			t.Errorf("%s: parsed", name)
		}
	}
}

func TestWithBase(t *testing.T) {
	m, _ := Pinned()
	same, err := m.WithBase("")
	if err != nil || same != m {
		t.Fatal("empty base changed the manifest")
	}
	o, err := m.WithBase("http://abcdefghijklmnop.onion/voice/")
	if err != nil {
		t.Fatal(err)
	}
	if o.Base != "http://abcdefghijklmnop.onion/voice/" || len(o.RedirectHosts) != 0 {
		t.Fatalf("onion manifest %+v", o)
	}
	md, _ := o.Model("base")
	if want, _ := m.Model("base"); md != want {
		t.Fatal("pins changed with the host")
	}
	if m.Base == o.Base {
		t.Fatal("the pinned manifest was changed in place")
	}
	for _, b := range []string{"http://kryfo.app/voice/", "ftp://x/", "https:///", "https://x/y", "https://u:p@x/"} {
		if _, err := m.WithBase(b); err == nil {
			t.Errorf("base %q accepted", b)
		}
	}
}

func TestRedirectOK(t *testing.T) {
	m, _ := Pinned()
	for s, want := range map[string]bool{
		"https://us.aws.cdn.hf.co/xet-bridge-us/abc": true,
		"https://cdn-lfs.huggingface.co/x":           true,
		"https://huggingface.co/x":                   true,
		"http://us.aws.cdn.hf.co/x":                  false,
		"https://evilhf.co/x":                        false,
		"https://hf.co.evil.example/x":               false,
		"https://example.com/x":                      false,
		"https://u:p@cdn.hf.co/x":                    false,
	} {
		u, _ := url.Parse(s)
		if got := m.RedirectOK(u); got != want {
			t.Errorf("%s: %v", s, got)
		}
	}
	o, _ := m.WithBase("http://abcdefghijklmnop.onion/v/")
	u, _ := url.Parse("https://cdn.hf.co/x")
	if o.RedirectOK(u) {
		t.Fatal("our own host followed a redirect")
	}
	if m.RedirectOK(nil) {
		t.Fatal("nil url")
	}
}
