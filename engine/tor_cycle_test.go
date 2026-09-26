// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torcycle

// starts and stops the embedded tor over and over in one process, which is
// what a day of check-ins does. needs a network. go test -tags torcycle -run
// TestTorCycles -v .
package main

import (
	"os"
	"runtime"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func rssKB() int {
	b, err := os.ReadFile("/proc/self/status")
	if err != nil {
		return 0
	}
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "VmRSS:") {
			f := strings.Fields(line)
			n := 0
			for _, c := range f[1] {
				n = n*10 + int(c-'0')
			}
			return n
		}
	}
	return 0
}

func bootPct() int {
	statusMu.RLock()
	defer statusMu.RUnlock()
	return bootstrapPct
}

func waitBoot(limit time.Duration) (int, time.Duration) {
	t0 := time.Now()
	for time.Since(t0) < limit {
		if bootPct() >= 100 {
			break
		}
		time.Sleep(250 * time.Millisecond)
	}
	return bootPct(), time.Since(t0)
}

// one tor for the life of the process, put to sleep and woken again and
// again. tor aborts on a second shutdown in the same process.
func TestTorCycles(t *testing.T) {
	dir := t.TempDir()
	if r := torResume(); r != "start" {
		t.Fatalf("resume with no tor: %s", r)
	}
	addr := startListener(dir)
	if strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	pct, took := waitBoot(4 * time.Minute)
	if pct < 100 {
		// no usable tor network on this box: skip rather than pass
		t.Skipf("tor only bootstrapped to %d%% here, nothing to cycle", pct)
	}
	t.Logf("cold start: 100%% in %dms", took.Milliseconds())
	var first, last, goFirst, goAfter int
	cycles := 12
	for i := 0; i < cycles; i++ {
		t0 := time.Now()
		if r := torStop(); r != "ok" {
			t.Fatalf("cycle %d sleep: %s", i, r)
		}
		slept := time.Since(t0)
		statusMu.RLock()
		st := torStatus
		statusMu.RUnlock()
		if st != "off" {
			t.Fatalf("cycle %d: status asleep is %q", i, st)
		}
		if got := startListener(dir); !strings.HasPrefix(got, "error: tor is stopped") {
			t.Fatalf("cycle %d: a start while asleep was not refused: %s", i, got)
		}
		restartTor()
		time.Sleep(3 * time.Second)
		if bootPct() >= 100 {
			t.Fatalf("cycle %d: tor reports 100%% while off the network", i)
		}
		if r := torResume(); r != "ok" {
			t.Fatalf("cycle %d wake: %s", i, r)
		}
		if got := startListener(dir); got != addr {
			t.Fatalf("cycle %d: start after wake gave %q, want the same onion", i, got)
		}
		pct, woke := waitBoot(3 * time.Minute)
		if pct < 100 {
			t.Fatalf("cycle %d: awake but stopped at %d%%", i, pct)
		}
		runtime.GC()
		rss := rssKB()
		if i == 1 {
			first = rss
			goFirst = runtime.NumGoroutine()
		}
		last = rss
		goAfter = runtime.NumGoroutine()
		t.Logf("cycle %2d: asleep in %4dms, awake and at 100%% in %5dms, goroutines %d, rss %d MB",
			i, slept.Milliseconds(), woke.Milliseconds(), runtime.NumGoroutine(), rss/1024)
	}
	if first > 0 && last > first*2 {
		t.Fatalf("memory doubled over %d cycles: %d MB -> %d MB", cycles, first/1024, last/1024)
	}
	if n := atomic.LoadInt32(&torMains); n != 1 {
		t.Fatalf("tor main loops alive at the end: %d, want 1", n)
	}
	if goAfter > goFirst+3 {
		t.Fatalf("a goroutine per wake: %d -> %d over %d cycles", goFirst, goAfter, cycles)
	}
}
