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

// the file that wraps ks_decrypt_* results, once linking is wired. it is
// the only place a session's remote identity turns into a From or a proof
var sessionDoor = map[string]bool{}

// a remote read out of a message would let anyone vouch for anyone, so
// FromSession and Proven are called only where libsignal's own answer is
func TestOnlyTheSessionLayerNamesARemote(t *testing.T) {
	call := regexp.MustCompile(`devices\.FromSession\(|\.Proven\(`)
	var seen []string
	err := filepath.WalkDir("..", func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			switch d.Name() {
			case "vendor", "devices", ".gocache", "testdata":
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(p, ".go") || sessionDoor[filepath.ToSlash(p)] {
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		if call.Match(b) {
			seen = append(seen, p)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(seen) > 0 {
		t.Fatalf("a remote named outside the session layer: %v", seen)
	}
}
