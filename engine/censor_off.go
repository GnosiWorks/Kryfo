// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !torblocked

package main

const censorBuild = false

func censorStart() string { return "" }

func censorPTDial(string, string) error { return nil }
