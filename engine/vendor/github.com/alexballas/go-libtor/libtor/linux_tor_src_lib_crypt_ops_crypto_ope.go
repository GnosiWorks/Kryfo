// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build linux || android
// +build linux || android

package libtor

/*
#define BUILDDIR ""

#include <../src/lib/crypt_ops/crypto_ope.c>
*/
import "C"
