// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a test build can make tor act as if a censor sat on the network, so
// blocked detection and automatic can be driven on any phone or desk. it
// exists only with -tags torblocked (censor_on.go), which build.sh adds
// for HALO_TOR_BLOCKED=1 with HALO_TEST_ID=1 and nothing else. even then
// it stays off in any process that is not the test app, so a test engine
// that slipped into the real app would do nothing.

import (
	"bytes"
	"log"
	"os"
	"runtime"
	"strings"
	"sync"
)

// the application id suffix of the test app, see build.gradle.kts
const censorAppSuffix = ".bridgetest"

// whether the censor may run in this process
func censorAllowed(proc, goos string) bool {
	if goos != "android" {
		return true
	}
	return strings.HasPrefix(proc, "app.kryfo") && strings.HasSuffix(proc, censorAppSuffix)
}

func procName() string {
	b, err := os.ReadFile("/proc/self/cmdline")
	if err != nil {
		return ""
	}
	if i := bytes.IndexByte(b, 0); i >= 0 {
		b = b[:i]
	}
	return string(b)
}

var censorOnce sync.Once

// the arguments that put tor behind the censor, or none
func censorTorArgs() []string {
	if !censorBuild {
		return nil
	}
	if !censorAllowed(procName(), runtime.GOOS) {
		censorOnce.Do(func() { log.Println("censor: not the test app, left off") })
		return nil
	}
	addr := censorStart()
	if addr == "" {
		return nil
	}
	return []string{"--Socks5Proxy", addr}
}
