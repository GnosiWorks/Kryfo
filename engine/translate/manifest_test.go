// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"
)

func TestPinnedParses(t *testing.T) {
	m, err := Pinned()
	if err != nil {
		t.Fatal(err)
	}
	for _, k := range [][2]string{{"zh", "en"}, {"en", "zh"}} {
		p, ok := m.Pair(k[0], k[1])
		if !ok {
			t.Fatalf("no %s-%s", k[0], k[1])
		}
		// a pair this size is a download to ask about first, not a surprise
		if p.GzBytes() < 30<<20 || p.GzBytes() > 80<<20 {
			t.Errorf("%s-%s fetches %d bytes", k[0], k[1], p.GzBytes())
		}
		if p.DiskBytes() <= p.GzBytes() {
			t.Errorf("%s-%s unpacks smaller than it fetches", k[0], k[1])
		}
	}
	if b := m.Bundle("zh"); len(b) != 2 || b[0].From != "zh" || b[1].To != "zh" {
		t.Fatalf("bundle %+v", b)
	}
	if b := m.Bundle("fr"); len(b) != 0 {
		t.Fatalf("bundle for a language with no models: %+v", b)
	}
}

func pinnedCopy(t *testing.T) map[string]any {
	t.Helper()
	var v map[string]any
	if err := json.Unmarshal(pinnedJSON, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func firstFile(v map[string]any) map[string]any {
	return v["pairs"].([]any)[0].(map[string]any)["files"].([]any)[0].(map[string]any)
}

func TestManifestRefuses(t *testing.T) {
	cases := map[string]func(v map[string]any){
		"plain http base": func(v map[string]any) { v["base"] = "http://example.org/m/" },
		"base with query": func(v map[string]any) { v["base"] = "https://example.org/m/?a=b" },
		"base not a dir":  func(v map[string]any) { v["base"] = "https://example.org/m" },
		"version":         func(v map[string]any) { v["version"] = 2 },
		"unknown field":   func(v map[string]any) { v["extra"] = true },
		"path escapes":    func(v map[string]any) { firstFile(v)["path"] = "../x.gz" },
		"absolute path":   func(v map[string]any) { firstFile(v)["path"] = "/x.gz" },
		"unclean path":    func(v map[string]any) { firstFile(v)["path"] = "a/./x.gz" },
		"query in path":   func(v map[string]any) { firstFile(v)["path"] = "a/x.gz?y" },
		"not a gzip":      func(v map[string]any) { firstFile(v)["path"] = "a/x.bin" },
		"name with slash": func(v map[string]any) { firstFile(v)["name"] = "a/b" },
		"dot name":        func(v map[string]any) { firstFile(v)["name"] = ".." },
		"short hash":      func(v map[string]any) { firstFile(v)["sha256"] = "abcd" },
		"upper hash": func(v map[string]any) {
			firstFile(v)["sha256"] = strings.ToUpper(firstFile(v)["sha256"].(string))
		},
		"zero size": func(v map[string]any) { firstFile(v)["size"] = 0 },
		"huge":      func(v map[string]any) { firstFile(v)["gzSize"] = int64(1 << 40) },
		"kind":      func(v map[string]any) { firstFile(v)["kind"] = "script" },
		"no model": func(v map[string]any) {
			firstFile(v)["kind"] = KindLex
		},
		"two vocabs kinds": func(v map[string]any) {
			p := v["pairs"].([]any)[1].(map[string]any)
			p["files"].([]any)[2].(map[string]any)["kind"] = KindVocab
		},
		"same pair twice": func(v map[string]any) {
			ps := v["pairs"].([]any)
			v["pairs"] = append(ps, ps[0])
		},
		"same lang both sides": func(v map[string]any) {
			v["pairs"].([]any)[0].(map[string]any)["to"] = "zh"
		},
		"bad lang": func(v map[string]any) {
			v["pairs"].([]any)[0].(map[string]any)["from"] = "zh-Hans"
		},
	}
	for name, mut := range cases {
		t.Run(name, func(t *testing.T) {
			v := pinnedCopy(t)
			mut(v)
			b, err := json.Marshal(v)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := Parse(b); !errors.Is(err, ErrManifest) {
				t.Fatalf("took it: %v", err)
			}
		})
	}
	if _, err := Parse(append(append([]byte{}, pinnedJSON...), []byte(`{}`)...)); !errors.Is(err, ErrManifest) {
		t.Fatalf("took trailing data: %v", err)
	}
}

func TestConfig(t *testing.T) {
	m, err := Pinned()
	if err != nil {
		t.Fatal(err)
	}
	zh, _ := m.Pair("zh", "en")
	c := zh.Config("/data/models/zhen")
	for _, want := range []string{
		"models:\n  - '/data/models/zhen/model.zhen.intgemm.alphas.bin'\n",
		"vocabs:\n  - '/data/models/zhen/vocab.zhen.spm'\n  - '/data/models/zhen/vocab.zhen.spm'\n",
		"shortlist:\n  - '/data/models/zhen/lex.50.50.zhen.s2t.bin'\n  - false\n",
		"gemm-precision: int8shiftAlphaAll\n",
		"beam-size: 1\n",
	} {
		if !strings.Contains(c, want) {
			t.Errorf("config lacks %q:\n%s", want, c)
		}
	}
	en, _ := m.Pair("en", "zh")
	c = en.Config("/m/it's")
	if !strings.Contains(c, "  - '/m/it''s/srcvocab.enzh.spm'\n  - '/m/it''s/trgvocab.enzh.spm'\n") {
		t.Errorf("split vocabs or quoting:\n%s", c)
	}
}
