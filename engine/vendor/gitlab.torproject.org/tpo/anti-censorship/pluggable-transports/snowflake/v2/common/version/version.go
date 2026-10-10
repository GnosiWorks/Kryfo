package version

import (
	"fmt"
	"runtime/debug"
)

var version = func() string {
	ver := "2.14.1"
	if info, ok := debug.ReadBuildInfo(); ok {
		var revision string
		var modified string
		for _, setting := range info.Settings {
			switch setting.Key {
			case "vcs.revision":
				revision = setting.Value[:8]
			case "vcs.modified":
				if setting.Value == "true" {
					modified = "*"
				}
			}
		}
		if revision != "" {
			return fmt.Sprintf("%v (%v%v)", ver, revision, modified)
		}
	}
	return ver
}()

func GetVersion() string {
	return version
}
