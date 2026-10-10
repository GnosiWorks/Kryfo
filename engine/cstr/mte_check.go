// SPDX-License-Identifier: GPL-3.0-or-later

//go:build mtecheck

package cstr

/*
#include <stdlib.h>
#include <sys/prctl.h>

// PR_GET_TAGGED_ADDR_CTRL
static long tagctl(void) { return prctl(56, 0, 0, 0, 0); }
*/
import "C"

import "unsafe"

func tagCtl() int64 { return int64(C.tagctl()) }

// malloc(n+1) and a copy, like dart's toNativeUtf8
func heapCopy(s string) unsafe.Pointer { return unsafe.Pointer(C.CString(s)) }

func heapFree(p unsafe.Pointer) { C.free(p) }

// the conversion cstr replaces, kept here to prove the check catches it
func oldString(p unsafe.Pointer) string { return C.GoString((*C.char)(p)) }
