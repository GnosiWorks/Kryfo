// SPDX-License-Identifier: GPL-3.0-or-later
//go:build android
// +build android

package main

/*
#include <android/log.h>
#include <stdlib.h>
#include <string.h>

static void log_to_android(const char* tag, const char* msg) {
    __android_log_print(ANDROID_LOG_INFO, tag, "%s", msg);
}
*/
import "C"

import (
	"log"
	"sync/atomic"
	"unsafe"
)

func init() {
	log.SetFlags(log.Ltime | log.Lshortfile)
	log.SetOutput(&androidLogWriter{})
}

type androidLogWriter struct{}

func (w *androidLogWriter) Write(p []byte) (int, error) {
	// silent unless debug is on, so a release build leaks nothing to logcat -
	// no onion address, no peer ids, no tor timing.
	if atomic.LoadInt32(&debugOn) == 0 {
		return len(p), nil
	}
	// both C strings get freed - with tor's debug output routed here the
	// leak added up fast.
	tag := C.CString("halo-engine")
	msg := C.CString(string(p))
	C.log_to_android(tag, msg)
	C.free(unsafe.Pointer(tag))
	C.free(unsafe.Pointer(msg))
	return len(p), nil
}
