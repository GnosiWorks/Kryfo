// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torblocked && torblocked2

package main

// HALO_TOR_BLOCKED=2: automatic has to get past obfs4 to snowflake or
// webtunnel
func init() { censorLevel = 2 }
