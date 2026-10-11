// SPDX-License-Identifier: GPL-3.0-or-later
package main

// how far each relay is known to have handed over everything for a receive
// address: whatever it took before that moment has come here, as stored
// events once a catch-up ran to its end and live ones after it. unix ms by
// this phone's clock, per relay and address, kept beside the address's
// other files. a copy that is new here later reached that relay after it.
// the file holds it to a quarter hour, rounded down, so it never says when
// something came: one behind says less than was heard, never more

import (
	"context"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

// the file is written no more often than this, but on a catch-up's end
const heardSaveGap = time.Minute

// what the file holds is rounded down to this
const heardSaveStep = 15 * time.Minute

var (
	heardMu sync.Mutex
	// catchupKey to ms
	heardAt = map[string]int64{}
	// address to its last write
	heardSaved = map[string]time.Time{}
)

func heardFile(rcvPk string) string {
	if savedDataDir == "" {
		return ""
	}
	short := rcvPk
	if len(short) > 16 {
		short = short[:16]
	}
	return savedDataDir + "/nostr_heard_" + short
}

// what the file says of an address, for a runner starting on it. what is
// in memory already is as new or newer
func loadHeard(rcvPk string) {
	p := heardFile(rcvPk)
	if p == "" {
		return
	}
	b, err := os.ReadFile(p)
	if err != nil {
		return
	}
	heardMu.Lock()
	defer heardMu.Unlock()
	for _, line := range strings.Split(string(b), "\n") {
		i := strings.LastIndexByte(line, ' ')
		if i <= 0 {
			continue
		}
		v, err := strconv.ParseInt(line[i+1:], 10, 64)
		if err != nil || v <= 0 {
			continue
		}
		k := catchupKey(line[:i], rcvPk)
		if v > heardAt[k] {
			heardAt[k] = v
		}
	}
}

// 0 when nothing is known
func heardOf(key string) int64 {
	heardMu.Lock()
	defer heardMu.Unlock()
	return heardAt[key]
}

// relay u has handed over everything for the address up to at. a runner
// that was let go of says nothing more. now: written at once, as on a
// catch-up's end, so a subscribe after an unblock is on disk before a
// death could lose it
func noteHeard(ctx context.Context, u, rcvPk string, at time.Time, now bool) {
	if ctx.Err() != nil {
		return
	}
	ms := at.UnixMilli()
	k := catchupKey(u, rcvPk)
	// relays off the list are not written again
	nostrMu.Lock()
	listed := map[string]bool{}
	for _, r := range nostrRelays {
		listed[r] = true
	}
	nostrMu.Unlock()
	heardMu.Lock()
	if ms <= heardAt[k] {
		heardMu.Unlock()
		return
	}
	heardAt[k] = ms
	p := heardFile(rcvPk)
	if p == "" || (!now && at.Sub(heardSaved[rcvPk]) < heardSaveGap) {
		heardMu.Unlock()
		return
	}
	heardSaved[rcvPk] = at
	step := heardSaveStep.Milliseconds()
	var lines []string
	suffix := " " + rcvPk
	for key, v := range heardAt {
		relay, ok := strings.CutSuffix(key, suffix)
		if ok && listed[relay] {
			lines = append(lines, relay+" "+strconv.FormatInt(v/step*step, 10))
		}
	}
	heardMu.Unlock()
	if engineHeld.Load() {
		return
	}
	seenFileMu.Lock()
	defer seenFileMu.Unlock()
	if fileGone(p) || ctx.Err() != nil {
		return
	}
	tmp := p + ".tmp"
	if os.WriteFile(tmp, []byte(strings.Join(lines, "\n")+"\n"), 0600) != nil {
		return
	}
	if os.Rename(tmp, p) != nil {
		os.Remove(tmp)
	}
}

// the address was let go of: what was heard on it goes with its ids
func dropHeard(rcvPk string) {
	heardMu.Lock()
	suffix := " " + rcvPk
	for k := range heardAt {
		if strings.HasSuffix(k, suffix) {
			delete(heardAt, k)
		}
	}
	delete(heardSaved, rcvPk)
	heardMu.Unlock()
}
