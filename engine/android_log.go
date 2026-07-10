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
	"unsafe"
)

func init() {
	log.SetFlags(log.Ltime | log.Lshortfile)
	log.SetOutput(&androidLogWriter{})
}

type androidLogWriter struct{}

func (w *androidLogWriter) Write(p []byte) (int, error) {
	// every log line used to leak two C strings. with tor debug output
	// now routed here that adds up fast, so free them.
	tag := C.CString("halo-engine")
	msg := C.CString(string(p))
	C.log_to_android(tag, msg)
	C.free(unsafe.Pointer(tag))
	C.free(unsafe.Pointer(msg))
	return len(p), nil
}
