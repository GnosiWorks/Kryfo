// SPDX-License-Identifier: GPL-3.0-or-later

// Package cstr reads c strings without touching memory past the nul.
package cstr

/*
#include <string.h>
*/
import "C"

import "unsafe"

// C.GoString scans ahead in 32-byte blocks and can read the next heap
// granule, which traps on mte phones. libc strlen stays inside the string.
func String(p unsafe.Pointer) string {
	if p == nil {
		return ""
	}
	c := (*C.char)(p)
	return C.GoStringN(c, C.int(C.strlen(c)))
}
