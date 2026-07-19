// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build linux || android
// +build linux || android

package libtor

/*
#include <event2/event-config.h>
#include <evconfig-private.h>
#include <compat/sys/queue.h>
#if !defined(BIG_ENDIAN) && !defined(LITTLE_ENDIAN)
#if defined(__BYTE_ORDER__) && (__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)
#define BIG_ENDIAN 1
#else
#define LITTLE_ENDIAN 1
#endif
#endif
#include <../sha1.c>
*/
import "C"
