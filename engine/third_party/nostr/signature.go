//go:build !libsecp256k1

package nostr

import (
	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/btcsuite/btcd/btcec/v2/schnorr"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
)

// Verify checks if the event signature is valid for the given event.
// It recomputes the id from the entire event body and checks the signature against that.
// kryfo: the ID field has to be that id too: an event is handled under its own id only.
// Returns true if the signature is valid, false otherwise.
func (evt Event) VerifySignature() bool {
	// read and check pubkey
	var x, y secp256k1.FieldVal
	if overflow := x.SetByteSlice(evt.PubKey[0:32]); overflow {
		return false
	}
	if !secp256k1.DecompressY(&x, false, &y) {
		return false
	}
	pubkey := secp256k1.NewPublicKey(&x, &y)

	// read signature
	var r btcec.FieldVal
	if overflow := r.SetByteSlice(evt.Sig[0:32]); overflow {
		return false
	}
	var s btcec.ModNScalar
	s.SetByteSlice(evt.Sig[32:64])
	sig := schnorr.NewSignature(&r, &s)

	// check signature
	// kryfo: the same hash checks the ID field
	claimed := evt.ID
	evt.SetID()
	if evt.ID != claimed {
		return false
	}
	return sig.Verify(evt.ID[:], pubkey)
}

// Sign signs an event with a given privateKey.
//
// It sets the event's ID, PubKey, and Sig fields.
//
// Returns an error if the private key is invalid or if signing fails.
func (evt *Event) Sign(secretKey [32]byte) error {
	if evt.Tags == nil {
		evt.Tags = make(Tags, 0)
	}

	sk, pk := btcec.PrivKeyFromBytes(secretKey[:])
	pkBytes := pk.SerializeCompressed()[1:]
	evt.PubKey = PubKey(pkBytes)

	evt.SetID()
	sig, err := schnorr.Sign(sk, evt.ID[:], schnorr.FastSign())
	if err != nil {
		return err
	}

	sigb := sig.Serialize()
	evt.Sig = [64]byte(sigb)

	return nil
}
