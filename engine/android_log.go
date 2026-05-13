// +build android

package main

/*
#include <android/log.h>
#include <string.h>

static void log_to_android(const char* tag, const char* msg) {
    __android_log_print(ANDROID_LOG_INFO, tag, "%s", msg);
}
*/
import "C"

import (
"log"
)

func init() {
log.SetFlags(log.Ltime | log.Lshortfile)
log.SetOutput(&androidLogWriter{})
}

type androidLogWriter struct{}

func (w *androidLogWriter) Write(p []byte) (int, error) {
msg := string(p)
C.log_to_android(C.CString("halo-engine"), C.CString(msg))
return len(p), nil
}
