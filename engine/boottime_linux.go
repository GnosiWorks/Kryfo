// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"time"

	"golang.org/x/sys/unix"
)

// time since boot, sleep included: go's monotonic clock stops while the
// phone sleeps, and an outage slept through is time that counts.
// a var for the tests
var ownClock = func() time.Duration {
	var ts unix.Timespec
	if unix.ClockGettime(unix.CLOCK_BOOTTIME, &ts) != nil {
		return time.Duration(time.Now().UnixNano())
	}
	return time.Duration(ts.Nano())
}
