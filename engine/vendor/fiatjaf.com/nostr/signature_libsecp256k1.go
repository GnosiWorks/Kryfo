//go:build libsecp256k1

package nostr

/*
#cgo CFLAGS: -I${SRCDIR}/libsecp256k1/include -I${SRCDIR}/libsecp256k1/src
#cgo CFLAGS: -DECMULT_GEN_PREC_BITS=4
#cgo CFLAGS: -DECMULT_WINDOW_SIZE=15
#cgo CFLAGS: -DENABLE_MODULE_SCHNORRSIG=1
#cgo CFLAGS: -DENABLE_MODULE_EXTRAKEYS=1

#include "./libsecp256k1/src/secp256k1.c"
#include "./libsecp256k1/src/precomputed_ecmult.c"
#include "./libsecp256k1/src/precomputed_ecmult_gen.c"
#include "./libsecp256k1/src/ecmult_gen.h"
#include "./libsecp256k1/src/ecmult.h"
#include "./libsecp256k1/src/modules/extrakeys/main_impl.h"
#include "./libsecp256k1/src/modules/schnorrsig/main_impl.h"

#include "./libsecp256k1/include/secp256k1.h"
#include "./libsecp256k1/include/secp256k1_extrakeys.h"
#include "./libsecp256k1/include/secp256k1_schnorrsig.h"
*/
import "C"

import (
	"crypto/rand"
	"errors"
	"unsafe"

	"github.com/btcsuite/btcd/btcec/v2/schnorr"
)

func (evt Event) VerifySignature() bool {
	evt.SetID()

	var xonly C.secp256k1_xonly_pubkey
	if C.secp256k1_xonly_pubkey_parse(globalSecp256k1Context, &xonly, (*C.uchar)(unsafe.Pointer(&evt.PubKey[0]))) != 1 {
		return false
	}

	res := C.secp256k1_schnorrsig_verify(globalSecp256k1Context, (*C.uchar)(unsafe.Pointer(&evt.Sig[0])), (*C.uchar)(unsafe.Pointer(&evt.ID[0])), 32, &xonly)
	return res == 1
}

// Sign signs an event with a given privateKey.
func (evt *Event) Sign(secretKey [32]byte, signOpts ...schnorr.SignOption) error {
	if evt.Tags == nil {
		evt.Tags = make(Tags, 0)
	}

	var keypair C.secp256k1_keypair
	if C.secp256k1_keypair_create(globalSecp256k1Context, &keypair, (*C.uchar)(unsafe.Pointer(&secretKey[0]))) != 1 {
		return errors.New("failed to parse private key")
	}

	var xonly C.secp256k1_xonly_pubkey
	C.secp256k1_keypair_xonly_pub(globalSecp256k1Context, &xonly, nil, &keypair)
	C.secp256k1_xonly_pubkey_serialize(globalSecp256k1Context, (*C.uchar)(unsafe.Pointer(&evt.PubKey[0])), &xonly)

	evt.SetID()

	var random [32]byte
	rand.Read(random[:])
	if C.secp256k1_schnorrsig_sign32(globalSecp256k1Context, (*C.uchar)(unsafe.Pointer(&evt.Sig[0])), (*C.uchar)(unsafe.Pointer(&evt.ID[0])), &keypair, (*C.uchar)(unsafe.Pointer(&random[0]))) != 1 {
		return errors.New("failed to sign message")
	}

	return nil
}

var globalSecp256k1Context *C.secp256k1_context

func init() {
	globalSecp256k1Context = C.secp256k1_context_create(C.SECP256K1_CONTEXT_SIGN | C.SECP256K1_CONTEXT_VERIFY)
	if globalSecp256k1Context == nil {
		panic("failed to create secp256k1 context")
	}
}
