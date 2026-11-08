// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !linux

package main

import "time"

// the wall clock where there is no boot clock
func bootClock() time.Duration { return time.Duration(time.Now().UnixNano()) }
