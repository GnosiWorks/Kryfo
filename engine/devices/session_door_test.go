// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// a remote read out of a message would let anyone vouch for anyone, so
// FromSession and Proven are called only where libsignal's own answer is.
// libsignal binds the two device keys, not the contact: the identity given
// to Proven is the one the pair address and session record belong to,
// never one a message names. each rule names the one place allowed to
// make the call
type doorRule struct {
	what  string
	call  *regexp.Regexp
	where map[string]bool
}

var engineDoors = []doorRule{
	// the engine's session door, called only by dart's
	{"a remote", regexp.MustCompile(`devices\.FromSession\(|\.Proven\(`), map[string]bool{"../dev_session.go": true}},
	// proofs put back from the rows the engine wrote, at the start
	{"a stored proof", regexp.MustCompile(`devices\.Kept\{`), map[string]bool{"../dev_state.go": true}},
}

var appDoors = []doorRule{
	// the one place a decrypt's remote becomes a session remote: right
	// where ks_decrypt_* returned it (and where the type is defined)
	{"a session remote", regexp.MustCompile(`SessionRemote\.opened\(`), map[string]bool{"app/signal.dart": true, "devices/device_state.dart": true}},
	// the engine's session door, bound once
	{"the session door", regexp.MustCompile(`HaloDevSession`), map[string]bool{"devices/device_state.dart": true}},
}

func walkDoors(t *testing.T, root, ext string, skip map[string]bool, rules []doorRule) {
	t.Helper()
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if skip[d.Name()] {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(p, ext) {
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		rel := filepath.ToSlash(p)
		if root != ".." {
			r, _ := filepath.Rel(root, p)
			rel = filepath.ToSlash(r)
		}
		for _, r := range rules {
			if r.call.Match(b) && !r.where[rel] {
				t.Errorf("%s named outside its door: %s", r.what, rel)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func TestOnlyTheSessionLayerNamesARemote(t *testing.T) {
	walkDoors(t, "..", ".go", map[string]bool{"vendor": true, "devices": true, ".gocache": true, "testdata": true}, engineDoors)
	lib := filepath.Join("..", "..", "mobile", "lib")
	if _, err := os.Stat(lib); err != nil {
		t.Skip("no app sources beside the engine")
	}
	walkDoors(t, lib, ".dart", nil, appDoors)
}

// the rules catch what they are for
func TestTheDoorRulesMatch(t *testing.T) {
	for _, c := range []struct {
		rules []doorRule
		src   string
	}{
		{engineDoors, "x := devices.FromSession(k)"},
		{engineDoors, "book.Proven(id, remote)"},
		{engineDoors, "devices.Kept{Identity: id}"},
		{appDoors, "final r = SessionRemote.opened(key);"},
		{appDoors, "lookup('HaloDevSession')"},
	} {
		hit := false
		for _, r := range c.rules {
			hit = hit || r.call.MatchString(c.src)
		}
		if !hit {
			t.Errorf("not caught: %s", c.src)
		}
	}
}
