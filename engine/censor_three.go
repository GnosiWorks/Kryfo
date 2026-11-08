// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torblocked && torblocked3

package main

// HALO_TOR_BLOCKED=3: no bridge gets through either, so automatic runs out
// and offers relay mode
func init() { censorLevel = 3 }
