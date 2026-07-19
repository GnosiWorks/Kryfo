// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build linux || android
// +build linux || android

package libtor

/*
#cgo CFLAGS: -I${SRCDIR}/../tor_config
#cgo CFLAGS: -I${SRCDIR}/../linux/tor
#cgo CFLAGS: -I${SRCDIR}/../linux/tor/src
#cgo CFLAGS: -I${SRCDIR}/../linux/tor/src/core/or
#cgo CFLAGS: -I${SRCDIR}/../linux/tor/src/ext
#cgo CFLAGS: -I${SRCDIR}/../linux/tor/src/ext/equix/include
#cgo CFLAGS: -I${SRCDIR}/../linux/tor/src/ext/equix/src
#cgo CFLAGS: -I${SRCDIR}/../linux/tor/src/ext/equix/hashx/include
#cgo CFLAGS: -I${SRCDIR}/../linux/tor/src/ext/equix/hashx/src
#cgo CFLAGS: -I${SRCDIR}/../linux/tor/src/ext/trunnel
#cgo CFLAGS: -I${SRCDIR}/../linux/tor/src/feature/api

#cgo CFLAGS: -D_GNU_SOURCE
#cgo CFLAGS: -Wno-deprecated-declarations
#cgo CFLAGS: -DED25519_CUSTOMRANDOM -DED25519_CUSTOMHASH -DED25519_SUFFIX=_donna
#cgo CFLAGS: -include ${SRCDIR}/../tor_config/gotor_extra.h

#cgo LDFLAGS: -lm
#cgo windows LDFLAGS: -lshlwapi
*/
import "C"
