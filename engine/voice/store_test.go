// SPDX-License-Identifier: GPL-3.0-or-later
package voice

import "testing"

func TestAppDir(t *testing.T) {
	for _, c := range []struct {
		dir, goos string
		ok        bool
	}{
		{"/data/user/0/app.kryfo/files/voice", "android", true},
		{"/data/user/10/app.kryfo/files/voice", "android", true},
		{"/data/data/app.kryfo/files/voice", "android", true},
		{"/data/user_de/0/app.kryfo/files/voice", "android", true},
		{"/sdcard/Android/data/app.kryfo/files", "android", false},
		{"/storage/emulated/0/Android/data/app.kryfo", "android", false},
		{"/storage", "android", false},
		{"/mnt/media_rw/x", "android", false},
		{"/data/media/0/x", "android", false},
		{"/data/local/tmp/voice", "android", false},
		{"/data/app/x", "android", false},
		{"/tmp/voice", "android", false},
		{"/data/user/0/app.kryfo/../../media/0", "android", false},
		{"/data/user/0/app.kryfo/files/voice/", "android", false},
		{"files/voice", "android", false},
		{"", "android", false},
		{"/home/u/.local/share/app.kryfo/voice", "linux", true},
		{"/tmp/x", "linux", true},
		{"/sdcard/x", "linux", false},
		{"relative", "linux", false},
	} {
		err := appDirOn(c.dir, c.goos)
		if (err == nil) != c.ok {
			t.Errorf("%s on %s: %v", c.dir, c.goos, err)
		}
	}
}
