// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// C.GoString reads past the nul and traps on mte phones, see cstr
func TestNoRawGoString(t *testing.T) {
	bad := "C.GoString" + "("
	allowed := map[string]bool{"cstr/mte_check.go": true}
	err := filepath.WalkDir(".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if path == "vendor" || strings.HasPrefix(d.Name(), ".") && path != "." {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(path, ".go") || allowed[filepath.ToSlash(path)] {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		for i, line := range strings.Split(string(b), "\n") {
			if strings.Contains(line, bad) {
				t.Errorf("%s:%d: use goStr or cstr.String", path, i+1)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}
