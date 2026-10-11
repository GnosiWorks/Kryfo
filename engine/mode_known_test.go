// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the tests written before modes drive tor as if the app had said how it
// connects. boot_mode_test.go starts from an unknown mode itself.
func init() { modeSet.Store(true) }
