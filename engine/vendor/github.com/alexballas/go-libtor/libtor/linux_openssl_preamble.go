// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Peter Szilagyi. All rights reserved.
//go:build linux || android
// +build linux || android

package libtor

/*
#cgo CFLAGS: -I${SRCDIR}/../openssl_config
#cgo CFLAGS: -I${SRCDIR}/../linux/openssl
#cgo CFLAGS: -I${SRCDIR}/../linux/openssl/include
#cgo CFLAGS: -I${SRCDIR}/../linux/openssl/crypto/ec/curve448
#cgo CFLAGS: -I${SRCDIR}/../linux/openssl/crypto/ec/curve448/arch_32
#cgo CFLAGS: -I${SRCDIR}/../linux/openssl/crypto/modes
#cgo CFLAGS: -I${SRCDIR}/../linux/openssl/include/openssl
#cgo CFLAGS: -I${SRCDIR}/../linux/openssl/providers/common/include
#cgo CFLAGS: -I${SRCDIR}/../linux/openssl/providers/fips/include
#cgo CFLAGS: -I${SRCDIR}/../linux/openssl/providers/implementations/include
#cgo CFLAGS: -include ${SRCDIR}/../openssl_config/gotor_extra.h
*/
import "C"
