// SPDX-License-Identifier: GPL-3.0-or-later
// a computer's trace (KRYFO_TRACE=1): a go panic or fatal error ends the
// whole process on a stderr nobody sees. the app names a file next to its
// trace, and the runtime writes what ended it there
package main

import "C"

import (
	"os"
	"runtime/debug"
)

// the crash output into the file at path, appended. false when it could not
// be opened or taken
func crashTraceTo(path string) bool {
	if path == "" {
		return false
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0600)
	if err != nil {
		return false
	}
	// the runtime keeps a copy of the handle
	defer f.Close()
	return debug.SetCrashOutput(f, debug.CrashOptions{}) == nil
}

//export HaloTraceCrash
func HaloTraceCrash(cPath *C.char) *C.char {
	if !crashTraceTo(goStr(cPath)) {
		return C.CString("error: not taken")
	}
	return C.CString("ok")
}
