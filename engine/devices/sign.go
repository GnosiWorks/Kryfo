// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import "errors"

// ContextList is the shim's signature context for a KDL2 body.
const ContextList = "device-list"

var ErrSignature = errors.New("devices: bad signature")

// Signer signs with one identity's key through the libsignal shim:
// ks_sign(identity, context, body), xeddsa over "kryfo-sig-v1" 0x00 context
// 0x00 body. the private key never comes into the engine.
type Signer interface {
	// Public is the 33-byte key the signer signs with.
	Public() Key
	// Sign gives a 64-byte signature. xeddsa is randomised, so two
	// signatures of one body differ.
	Sign(context string, body []byte) ([]byte, error)
}

// Verifier checks a signature the way ks_verify_ctx does, and fails with
// ErrSignature on any signature that does not hold.
type Verifier interface {
	Verify(pub Key, context string, body, sig []byte) error
}

// SigSize is an xeddsa signature.
const SigSize = 64
