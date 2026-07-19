// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build linux || android
// +build linux || android

package libtor

/*
#include <compat/sys/queue.h>
#include <../evutil_time.c>
*/
import "C"
