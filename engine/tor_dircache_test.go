// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// tor's directory cache across process starts, against the real network:
//
//	go test -tags torconf -run TestDirCacheKept -v .
//
// tor survives one start per process, so each start here is a child
// process of this test on the same data dir: a cold one, then a warm one.
// the warm one has to find the cached consensus and microdescriptors and
// read far less than the cold one. a bounce inside the warm process is
// measured too, as a network change does it.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"
)

// the cached directory files and their sizes
func cacheFiles(dir string) map[string]int64 {
	out := map[string]int64{}
	ents, _ := os.ReadDir(dir)
	for _, e := range ents {
		if !strings.HasPrefix(e.Name(), "cached-") {
			continue
		}
		if fi, err := e.Info(); err == nil {
			out[e.Name()] = fi.Size()
		}
	}
	return out
}

// the child: one start on HALO_DIRCACHE_DIR, then what it read
func TestDirCacheChild(t *testing.T) {
	dir := os.Getenv("HALO_DIRCACHE_DIR")
	if dir == "" {
		t.Skip("run by TestDirCacheKept")
	}
	if addr := startListener(dir); strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	pct, took := waitBoot(5 * time.Minute)
	if pct < 100 {
		t.Fatalf("tor only reached %d%%", pct)
	}
	// what a start costs is not over at 100%: the onion's descriptor goes
	// up and tor fetches what it still lacks
	time.Sleep(45 * time.Second)
	r, w := torTraffic(t, node(t))
	fmt.Printf("dircache start: boot %dms read %d written %d\n", took.Milliseconds(), r, w)
	if os.Getenv("HALO_DIRCACHE_BOUNCE") == "1" {
		atomic_store_lastRestart(0)
		if out := reconnectTor(); out != "ok" {
			t.Fatalf("bounce: %s", out)
		}
		_, took := waitBoot(2 * time.Minute)
		time.Sleep(45 * time.Second)
		r2, w2 := torTraffic(t, node(t))
		fmt.Printf("dircache bounce: boot %dms read %d written %d\n", took.Milliseconds(), r2-r, w2-w)
	}
}

var dircacheLine = regexp.MustCompile(`dircache (start|bounce): boot (\d+)ms read (\d+) written (\d+)`)

type dircacheRun struct {
	bootMs, read, written int64
}

func runDircacheChild(t *testing.T, dir string, bounce bool) map[string]dircacheRun {
	t.Helper()
	cmd := exec.Command(os.Args[0], "-test.run", "^TestDirCacheChild$", "-test.v", "-test.timeout", "15m")
	cmd.Env = append(os.Environ(), "HALO_DIRCACHE_DIR="+dir)
	if bounce {
		cmd.Env = append(cmd.Env, "HALO_DIRCACHE_BOUNCE=1")
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("child: %v\n%s", err, out)
	}
	got := map[string]dircacheRun{}
	for _, m := range dircacheLine.FindAllStringSubmatch(string(out), -1) {
		b, _ := strconv.ParseInt(m[2], 10, 64)
		r, _ := strconv.ParseInt(m[3], 10, 64)
		w, _ := strconv.ParseInt(m[4], 10, 64)
		got[m[1]] = dircacheRun{b, r, w}
	}
	if _, ok := got["start"]; !ok {
		t.Fatalf("child said nothing:\n%s", out)
	}
	return got
}

func TestDirCacheKept(t *testing.T) {
	dir := t.TempDir()
	cold := runDircacheChild(t, dir, false)["start"]
	files := cacheFiles(filepath.Join(dir, "tor"))
	t.Logf("cold start: boot %dms, read %s, written %s", cold.bootMs, mb(cold.read), mb(cold.written))
	t.Logf("cache after it: %v", files)
	for _, f := range []string{"cached-microdesc-consensus", "cached-microdescs"} {
		if _, ok := files[f]; !ok {
			// cached-microdescs can still be only the journal after one run
			if _, ok := files[f+".new"]; !ok {
				t.Fatalf("%s not on disk after a start: %v", f, files)
			}
		}
	}
	warm := runDircacheChild(t, dir, true)
	t.Logf("warm start: boot %dms, read %s, written %s", warm["start"].bootMs, mb(warm["start"].read), mb(warm["start"].written))
	t.Logf("bounce in the warm process: boot %dms, read %s, written %s", warm["bounce"].bootMs, mb(warm["bounce"].read), mb(warm["bounce"].written))
	if warm["start"].read*2 > cold.read {
		t.Fatalf("a warm start read %s, a cold one %s: the cache did not help", mb(warm["start"].read), mb(cold.read))
	}
}
