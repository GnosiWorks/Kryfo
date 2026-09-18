// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

package main

import "sync/atomic"

func atomic_store_lastRestart(v int64) { atomic.StoreInt64(&lastTorRestart, v) }
