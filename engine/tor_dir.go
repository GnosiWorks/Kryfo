// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"os"
	"path/filepath"
)

// tor opens its DataDirectory with O_NOFOLLOW and will not start in a
// link: linux desktop keeps engine/tor as a link to the disk, so tor gets
// where it points. a real folder stays as it is
func torDirTarget(dir string) string {
	fi, err := os.Lstat(dir)
	if err != nil || fi.Mode()&os.ModeSymlink == 0 {
		return dir
	}
	real, err := filepath.EvalSymlinks(dir)
	if err != nil {
		return dir
	}
	return real
}
