// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"encoding/json"
	"math"
	"testing"
	"time"
)

// a day far enough back made today minus it wrap past zero, and the oldest
// day there is read as fresh
func TestFarBackDayIsNotFresh(t *testing.T) {
	today := dayOf(time.Now())
	for _, d := range []int64{math.MinInt64, math.MinInt64 + today, math.MinInt64 + 1} {
		if fresh(d, today) {
			t.Errorf("day %d is fresh on day %d", d, today)
		}
	}
	if !fresh(today, today) || !fresh(today-memDays+1, today) || fresh(today-memDays, today) || fresh(today+1, today) {
		t.Fatal("the month around today moved")
	}

	memMu.Lock()
	old := autoMem
	memMu.Unlock()
	defer func() {
		memMu.Lock()
		autoMem = old
		memMu.Unlock()
	}()
	b, _ := json.Marshal(autoMemory{V: 1,
		Last:    map[string]autoUse{"wifi": {Method: "direct", Day: math.MinInt64}},
		Blocked: map[string]int64{"cellular": math.MinInt64 + today}})
	memIn(string(b), today)
	if m := memOut(today); len(m.Last) != 0 || len(m.Blocked) != 0 {
		t.Fatalf("kept %+v", m)
	}
}

// the same for the bridge cache: lines from a day long gone are not taken
// back as this week's
func TestFarBackBridgeCacheIsDropped(t *testing.T) {
	saveBridgeCache(t)
	today := dayOf(time.Now())
	line := "obfs4 192.0.2.121:51078 211FC586C5FEBA3075AA3F38D4C50661B323AA2D cert=VqwgcLuRmanOfbUmvf+MVPWNAHAPUv19yNS55ArmwuHNuyc1+RAiCGdPlYb1OMQzQjVX2Q iat-mode=0"
	if !moatLineOK(line) {
		t.Fatal("the test line does not pass")
	}
	b, _ := json.Marshal(map[string]any{
		"v":       2,
		"builtin": map[string]any{"base": builtinBase, "day": math.MinInt64 + today, "lines": builtinBundled},
		"moat":    map[string]any{"day": math.MinInt64 + today, "lines": []string{line}},
	})
	bridgeCacheIn(string(b))
	if s := moatSettingsCached(); s != nil {
		t.Fatalf("stale moat lines read as fresh: %+v", s)
	}
	if !builtinRefreshDue() {
		t.Fatal("stale built-ins read as fresh")
	}
}

func saveBridgeCache(t *testing.T) {
	builtinMu.Lock()
	builtinFresh, builtinFreshAt = nil, time.Time{}
	builtinMu.Unlock()
	moatCacheMu.Lock()
	moatSettingsC, moatSettingsAt = nil, time.Time{}
	moatCacheMu.Unlock()
	t.Cleanup(func() {
		builtinMu.Lock()
		builtinFresh, builtinFreshAt = nil, time.Time{}
		builtinMu.Unlock()
		dropMoatSettings()
	})
}
