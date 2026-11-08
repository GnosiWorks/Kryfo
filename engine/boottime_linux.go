// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"sync/atomic"
	"time"

	"golang.org/x/sys/unix"
)

// the last time read, for a read that fails
var bootLast atomic.Int64

// time since boot, sleep included: go's monotonic clock stops while the
// phone sleeps, and an outage slept through is time that counts. never 0
func bootClock() time.Duration {
	var ts unix.Timespec
	if unix.ClockGettime(unix.CLOCK_BOOTTIME, &ts) != nil {
		// one clock throughout: the last good value, not the wall clock
		return time.Duration(max(bootLast.Load(), 1))
	}
	n := max(ts.Nano(), 1)
	bootLast.Store(n)
	return time.Duration(n)
}
