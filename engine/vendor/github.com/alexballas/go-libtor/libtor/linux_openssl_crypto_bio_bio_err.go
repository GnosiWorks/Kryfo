// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Peter Szilagyi. All rights reserved.
//go:build linux || android
// +build linux || android

package libtor

/*
#define DSO_NONE
#define OPENSSLDIR "/usr/local/ssl"
#define ENGINESDIR "/usr/local/lib/engines"

#include <../crypto/bio/bio_err.c>
*/
import "C"
