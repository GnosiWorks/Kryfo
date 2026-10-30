// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// how long a start takes from tor up to the onion published, and when the
// relays carry meanwhile, against the real network:
//
//	go test -tags torconf -run TestPublishTimes -v .
//
// HALO_PUBLISH_COLD and HALO_PUBLISH_WARM set the number of starts (3 each),
// HALO_PUBLISH_RUNNERS the relay listeners beside the start (3).
// each start is a child process, as tor survives one start per process: the
// cold ones on a fresh data dir, the warm ones on the last cold one's.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/cretz/bine/control"
)

// the moments a start goes through, in ms from the call to start tor
var publishMarks = []string{
	"listen", "tor100", "seen100", "relay", "intro1", "intro3",
	"est1", "est3", "upload1", "reachable", "uploaded1",
}

func TestPublishChild(t *testing.T) {
	dir := os.Getenv("HALO_PUBLISH_DIR")
	if dir == "" {
		t.Skip("run by TestPublishTimes")
	}
	t0 := time.Now()
	marks := map[string]int64{}
	mark := func(k string) {
		if _, ok := marks[k]; !ok {
			marks[k] = time.Since(t0).Milliseconds()
		}
	}
	if addr := startListener(dir); strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	mark("listen")
	runners := 3
	if n, err := strconv.Atoi(os.Getenv("HALO_PUBLISH_RUNNERS")); err == nil && n > 0 {
		runners = n
	}
	startRunners(t, runners)
	ch := make(chan control.Event, 512)
	c, err := eventConn(node(t))
	if err != nil {
		t.Fatalf("event connection: %v", err)
	}
	codes := []control.EventCode{control.EventCodeStatusClient, control.EventCodeCircuit,
		control.EventCodeCircuitMinor, control.EventCodeHSDesc}
	if err := c.AddEventListener(ch, codes...); err != nil {
		t.Fatalf("events: %v", err)
	}
	defer c.RemoveEventListener(ch, codes...)
	intro, est, fails := 0, 0, 0
	tick := time.NewTicker(50 * time.Millisecond)
	defer tick.Stop()
	limit := time.After(4 * time.Minute)
	done := func() bool {
		for _, k := range []string{"relay", "reachable", "uploaded1"} {
			if _, ok := marks[k]; !ok {
				return false
			}
		}
		return true
	}
wait:
	for !done() {
		select {
		case ev := <-ch:
			switch e := ev.(type) {
			case *control.StatusEvent:
				if e.Action == "BOOTSTRAP" && e.Arguments["PROGRESS"] == "100" {
					mark("tor100")
				}
			case *control.CircuitEvent:
				if e.Status == "BUILT" && e.Purpose == "HS_SERVICE_INTRO" {
					intro++
					mark(fmt.Sprintf("intro%d", intro))
				}
			case *control.CircuitMinorEvent:
				if e.HSState == "HSSI_ESTABLISHED" && e.OldHSState != "HSSI_ESTABLISHED" {
					est++
					mark(fmt.Sprintf("est%d", est))
				}
			case *control.HSDescEvent:
				switch e.Action {
				case "UPLOAD":
					mark("upload1")
				case "UPLOADED":
					mark("uploaded1")
				case "FAILED":
					fails++
				}
			}
		case <-tick.C:
			if bootPct() >= 100 {
				mark("seen100")
			}
			if routeOK() {
				mark("relay")
			}
			if status() == "reachable" {
				mark("reachable")
			}
		case <-limit:
			break wait
		}
	}
	var b strings.Builder
	for _, k := range publishMarks {
		v, ok := marks[k]
		if !ok {
			v = -1
		}
		fmt.Fprintf(&b, " %s=%d", k, v)
	}
	fmt.Printf("publish run:%s fails=%d\n", b.String(), fails)
}

var publishLine = regexp.MustCompile(`publish run:((?: \w+=-?\d+)+) fails=(\d+)`)

func runPublishChild(t *testing.T, dir string) map[string]int64 {
	t.Helper()
	cmd := exec.Command(os.Args[0], "-test.run", "^TestPublishChild$", "-test.v", "-test.timeout", "8m")
	cmd.Env = append(os.Environ(), "HALO_PUBLISH_DIR="+dir)
	out, err := cmd.CombinedOutput()
	if p := os.Getenv("HALO_PUBLISH_LOG"); p != "" {
		f, ferr := os.OpenFile(p, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
		if ferr == nil {
			f.Write(out)
			f.Close()
		}
	}
	if err != nil {
		t.Fatalf("child: %v\n%s", err, out)
	}
	m := publishLine.FindStringSubmatch(string(out))
	if m == nil {
		t.Fatalf("child said nothing:\n%s", out)
	}
	got := map[string]int64{}
	for _, kv := range strings.Fields(m[1]) {
		k, v, _ := strings.Cut(kv, "=")
		got[k], _ = strconv.ParseInt(v, 10, 64)
	}
	got["fails"], _ = strconv.ParseInt(m[2], 10, 64)
	return got
}

func publishRuns(env string) int {
	if n, err := strconv.Atoi(os.Getenv(env)); err == nil && n >= 0 {
		return n
	}
	return 3
}

func TestPublishTimes(t *testing.T) {
	var runs []map[string]int64
	var kinds []string
	last := ""
	for i := 0; i < publishRuns("HALO_PUBLISH_COLD"); i++ {
		last = t.TempDir()
		runs = append(runs, runPublishChild(t, last))
		kinds = append(kinds, "cold")
	}
	for i := 0; i < publishRuns("HALO_PUBLISH_WARM"); i++ {
		if last == "" {
			last = t.TempDir()
			runPublishChild(t, last)
		}
		runs = append(runs, runPublishChild(t, last))
		kinds = append(kinds, "warm")
	}
	// tor up to published, and tor up to the first relay through it
	gap := func(r map[string]int64, from, to string) string {
		if r[from] < 0 || r[to] < 0 {
			return "-"
		}
		return fmt.Sprintf("%.1fs", float64(r[to]-r[from])/1000)
	}
	byKind := map[string][]float64{}
	for i, r := range runs {
		t.Logf("%s: tor up %.1fs, seen +%s, relay +%s, intro circuits +%s, established +%s, upload +%s, reachable +%s, uploaded +%s, failed uploads %d",
			kinds[i], float64(r["tor100"])/1000, gap(r, "tor100", "seen100"), gap(r, "tor100", "relay"),
			gap(r, "tor100", "intro3"), gap(r, "tor100", "est3"), gap(r, "tor100", "upload1"),
			gap(r, "tor100", "reachable"), gap(r, "tor100", "uploaded1"), r["fails"])
		if r["tor100"] >= 0 && r["reachable"] >= 0 {
			byKind[kinds[i]] = append(byKind[kinds[i]], float64(r["reachable"]-r["tor100"])/1000)
		}
	}
	for k, v := range byKind {
		sort.Float64s(v)
		t.Logf("%s: tor up to reachable, median %.1fs of %v", k, v[len(v)/2], v)
	}
}
