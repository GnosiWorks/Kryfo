// SPDX-License-Identifier: GPL-3.0-or-later
package voice

import (
	"fmt"
	"path/filepath"
	"runtime"
	"strings"
)

// shared storage every app with the permission can read
var sharedRoots = []string{"/sdcard", "/storage", "/mnt", "/data/media", "/data/local"}

// on a phone the app's own storage is under one of these
var appRoots = []string{"/data/user/", "/data/data/", "/data/user_de/"}

// AppDir refuses a directory a model may not live in: anything relative,
// anything shared, and on android anything outside the app's own storage.
func AppDir(dir string) error { return appDirOn(dir, runtime.GOOS) }

func appDirOn(dir, goos string) error {
	if dir == "" || !filepath.IsAbs(dir) || filepath.Clean(dir) != dir {
		return fmt.Errorf("dir %q: not a clean absolute path", dir)
	}
	for _, r := range sharedRoots {
		if dir == r || strings.HasPrefix(dir, r+"/") {
			return fmt.Errorf("dir %q: shared storage", dir)
		}
	}
	if goos != "android" {
		return nil
	}
	for _, r := range appRoots {
		if strings.HasPrefix(dir, r) {
			return nil
		}
	}
	return fmt.Errorf("dir %q: not the app's storage", dir)
}
