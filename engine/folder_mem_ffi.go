// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !android

// the memory folder's calls for the desktop app (folder_mem.go)
package main

/*
#include <stdlib.h>
*/
import "C"

import "strings"

// HaloFolderMemory turns the memory folder on (1) or off (0, all zeroed).
// on before the first start
//
//export HaloFolderMemory
func HaloFolderMemory(on C.int) { setMemFolder(on != 0) }

// HaloFolderPut keeps n bytes under name. 1 when kept
//
//export HaloFolderPut
func HaloFolderPut(cName *C.char, in *C.uchar, n C.longlong) C.int {
	if memPut(goStr(cName), inBytes(in, n)) {
		return 1
	}
	return 0
}

// HaloFolderGet copies the file into *out (HaloFreeBytes zeroes it). 1 when
// there is one
//
//export HaloFolderGet
func HaloFolderGet(cName *C.char, out **C.uchar, outLen *C.longlong) C.int {
	*out, *outLen = nil, 0
	b, ok := memGet(goStr(cName))
	if !ok {
		return 0
	}
	outBytes(b, out, outLen)
	return 1
}

// HaloFolderNames is every name held, one per line
//
//export HaloFolderNames
func HaloFolderNames() *C.char { return C.CString(strings.Join(memNames(), "\n")) }

// HaloFolderDrop zeroes one file, or all of them for ""
//
//export HaloFolderDrop
func HaloFolderDrop(cName *C.char) { memDrop(goStr(cName)) }
