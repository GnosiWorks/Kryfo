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
// FromSession and Proven are called only where libsignal's own answer is,
// and FromLink only where the link's own run holds what it brought.
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
	// a first own list as the link brought it: only the link's own file,
	// with the list it holds, never one handed in
	{"a link source", regexp.MustCompile(`devices\.FromLink\(`), map[string]bool{"../dev_link.go": true}},
	// a contact's list the phone held, from the history copy: only the
	// engine's copy call, which takes it on a linked device alone
	{"a copy source", regexp.MustCompile(`devices\.FromCopy\(`), map[string]bool{"../dev_ffi.go": true}},
}

var appDoors = []doorRule{
	// the one place a decrypt's remote becomes a session remote: right
	// where ks_decrypt_* returned it (and where the type is defined)
	{"a session remote", regexp.MustCompile(`SessionRemote\.opened\(`), map[string]bool{"app/signal.dart": true, "devices/device_state.dart": true}},
	// the engine's session door, bound once
	{"the session door", regexp.MustCompile(`HaloDevSession`), map[string]bool{"devices/device_state.dart": true}},
	// DeviceEngine's door stays private to its file: no caller outside
	// DeviceState reaches it
	{"the engine's door", regexp.MustCompile(`\.session\(\s*'|String session\(`), map[string]bool{}},
	// the link's calls, bound once: a list handed over as FromLink comes
	// only from what the engine's own link run holds
	{"the link calls", regexp.MustCompile(`HaloDevLink`), map[string]bool{"devices/link_calls.dart": true}},
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
		{engineDoors, "d.own.Set(id, list, key, devices.FromLink(), d.v)"},
		{engineDoors, "d.accept(id, a.List, devices.FromCopy(), out)"},
		{appDoors, "final r = SessionRemote.opened(key);"},
		{appDoors, "lookup('HaloDevSession')"},
		{appDoors, "engine.session('own_mine', {})"},
		{appDoors, "lookupFunction<_C, _D>('HaloDevLink')"},
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
