// SPDX-License-Identifier: GPL-3.0-or-later
// offline translation models: which files make up a language pair, where
// they come from and the hash each one must have. the hashes are pinned in
// the app, so whoever serves the files, a mirror or an exit in between,
// can make a download fail but cannot make it load something else.
package translate

import (
	"bytes"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"path"
	"regexp"
	"strings"
)

// the kinds of file bergamot takes for a pair
const (
	KindModel    = "model"
	KindLex      = "lex"
	KindVocab    = "vocab"
	KindSrcVocab = "srcvocab"
	KindTrgVocab = "trgvocab"
)

// the largest file a manifest may name. the biggest released model is
// about 60mb; this leaves room without letting a bad manifest fill a phone.
const maxFile = 256 << 20

// File is one file of a pair. Path is where the gzip of it lives under the
// manifest's base; Name is what it is called on disk once unpacked.
type File struct {
	Kind     string `json:"kind"`
	Name     string `json:"name"`
	Path     string `json:"path"`
	Size     int64  `json:"size"`
	SHA256   string `json:"sha256"`
	GzSize   int64  `json:"gzSize"`
	GzSHA256 string `json:"gzSha256"`
}

// Pair is one direction: zh to en and en to zh are two pairs.
type Pair struct {
	From  string `json:"from"`
	To    string `json:"to"`
	Arch  string `json:"arch"`
	Files []File `json:"files"`
}

type Manifest struct {
	Version int    `json:"version"`
	Base    string `json:"base"`
	Pairs   []Pair `json:"pairs"`
}

var ErrManifest = errors.New("bad manifest")

//go:embed models.json
var pinnedJSON []byte

// Pinned is the manifest built into the app.
func Pinned() (*Manifest, error) { return Parse(pinnedJSON) }

var (
	langRe = regexp.MustCompile(`^[a-z]{2,3}(_[a-z]{4})?$`)
	hashRe = regexp.MustCompile(`^[0-9a-f]{64}$`)
	nameRe = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`)
	archRe = regexp.MustCompile(`^[a-z][a-z-]{0,31}$`)
)

// Parse reads a manifest and refuses anything it does not fully understand.
func Parse(b []byte) (*Manifest, error) {
	d := json.NewDecoder(bytes.NewReader(b))
	d.DisallowUnknownFields()
	var m Manifest
	if err := d.Decode(&m); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrManifest, err)
	}
	if d.More() {
		return nil, fmt.Errorf("%w: trailing data", ErrManifest)
	}
	if err := m.check(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrManifest, err)
	}
	return &m, nil
}

func (m *Manifest) check() error {
	if m.Version != 1 {
		return fmt.Errorf("version %d", m.Version)
	}
	u, err := url.Parse(m.Base)
	if err != nil || u.Scheme != "https" || u.Host == "" || u.RawQuery != "" || u.Fragment != "" || !strings.HasSuffix(u.Path, "/") {
		return fmt.Errorf("base %q", m.Base)
	}
	if len(m.Pairs) == 0 {
		return errors.New("no pairs")
	}
	seen := map[string]bool{}
	for _, p := range m.Pairs {
		k := p.From + "-" + p.To
		if seen[k] {
			return fmt.Errorf("pair %s twice", k)
		}
		seen[k] = true
		if err := p.check(); err != nil {
			return fmt.Errorf("pair %s: %v", k, err)
		}
	}
	return nil
}

func (p *Pair) check() error {
	if !langRe.MatchString(p.From) || !langRe.MatchString(p.To) || p.From == p.To {
		return errors.New("languages")
	}
	if !archRe.MatchString(p.Arch) {
		return fmt.Errorf("arch %q", p.Arch)
	}
	count := map[string]int{}
	names := map[string]bool{}
	for _, f := range p.Files {
		if err := f.check(); err != nil {
			return fmt.Errorf("%s: %v", f.Name, err)
		}
		if names[f.Name] {
			return fmt.Errorf("%s twice", f.Name)
		}
		names[f.Name] = true
		count[f.Kind]++
	}
	// one shared vocab or a source and a target one, never both
	shared := count[KindVocab] == 1 && count[KindSrcVocab] == 0 && count[KindTrgVocab] == 0
	split := count[KindVocab] == 0 && count[KindSrcVocab] == 1 && count[KindTrgVocab] == 1
	switch {
	case count[KindModel] != 1:
		return errors.New("needs one model")
	case count[KindLex] > 1:
		return errors.New("more than one lex")
	case !shared && !split:
		return errors.New("vocabs")
	}
	return nil
}

func (f *File) check() error {
	switch f.Kind {
	case KindModel, KindLex, KindVocab, KindSrcVocab, KindTrgVocab:
	default:
		return fmt.Errorf("kind %q", f.Kind)
	}
	if !nameRe.MatchString(f.Name) || strings.HasSuffix(f.Name, ".part") {
		return errors.New("name")
	}
	// a relative path that stays under the base once joined
	if f.Path == "" || path.Clean(f.Path) != f.Path || strings.HasPrefix(f.Path, "/") ||
		strings.HasPrefix(f.Path, "../") || f.Path == ".." || strings.ContainsAny(f.Path, "?#%\\ ") {
		return fmt.Errorf("path %q", f.Path)
	}
	if !strings.HasSuffix(f.Path, ".gz") {
		return fmt.Errorf("path %q is not a gzip", f.Path)
	}
	if f.Size <= 0 || f.Size > maxFile || f.GzSize <= 0 || f.GzSize > maxFile {
		return errors.New("size")
	}
	if !hashRe.MatchString(f.SHA256) || !hashRe.MatchString(f.GzSHA256) {
		return errors.New("hash")
	}
	return nil
}

// Pair finds one direction.
func (m *Manifest) Pair(from, to string) (Pair, bool) {
	for _, p := range m.Pairs {
		if p.From == from && p.To == to {
			return p, true
		}
	}
	return Pair{}, false
}

// Bundle is what to fetch for a language: both directions with english.
// fetching them together means a download says "this person reads or
// writes lang", which it says anyway, and not which way they translate.
func (m *Manifest) Bundle(lang string) []Pair {
	var out []Pair
	for _, k := range [][2]string{{lang, "en"}, {"en", lang}} {
		if p, ok := m.Pair(k[0], k[1]); ok {
			out = append(out, p)
		}
	}
	return out
}

// URL is where a file's gzip lives.
func (m *Manifest) URL(f File) string { return m.Base + f.Path }

// GzBytes is what fetching the pair costs on the wire.
func (p Pair) GzBytes() int64 {
	var n int64
	for _, f := range p.Files {
		n += f.GzSize
	}
	return n
}

// DiskBytes is what the pair takes once unpacked.
func (p Pair) DiskBytes() int64 {
	var n int64
	for _, f := range p.Files {
		n += f.Size
	}
	return n
}

// Dir is the pair's directory name under the models directory.
func (p Pair) Dir() string { return p.From + p.To + "-" + p.Arch }

func (p Pair) file(kind string) (File, bool) {
	for _, f := range p.Files {
		if f.Kind == kind {
			return f, true
		}
	}
	return File{}, false
}

// Config is the bergamot model config for the pair's files in dir. the
// options are the ones firefox runs with: greedy search, int8 with alphas,
// the lexical shortlist when there is one.
func (p Pair) Config(dir string) string {
	q := func(s string) string { return "'" + strings.ReplaceAll(s, "'", "''") + "'" }
	j := func(name string) string { return q(path.Join(dir, name)) }
	var b strings.Builder
	mod, _ := p.file(KindModel)
	fmt.Fprintf(&b, "models:\n  - %s\n", j(mod.Name))
	b.WriteString("vocabs:\n")
	if v, ok := p.file(KindVocab); ok {
		fmt.Fprintf(&b, "  - %s\n  - %s\n", j(v.Name), j(v.Name))
	} else {
		s, _ := p.file(KindSrcVocab)
		t, _ := p.file(KindTrgVocab)
		fmt.Fprintf(&b, "  - %s\n  - %s\n", j(s.Name), j(t.Name))
	}
	if l, ok := p.file(KindLex); ok {
		fmt.Fprintf(&b, "shortlist:\n  - %s\n  - false\n", j(l.Name))
	}
	b.WriteString(engineOptions)
	return b.String()
}

const engineOptions = `beam-size: 1
normalize: 1.0
word-penalty: 0
max-length-break: 128
mini-batch-words: 1024
workspace: 128
max-length-factor: 2.0
skip-cost: true
cpu-threads: 0
quiet: true
quiet-translation: true
gemm-precision: int8shiftAlphaAll
alignment: soft
`

// hexSum is how hashes are written in a manifest
func hexSum(b []byte) string { return hex.EncodeToString(b) }
