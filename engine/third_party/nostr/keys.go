package nostr

import (
	"crypto/rand"
	"encoding/hex"
	stdjson "encoding/json"
	"fmt"
	"io"
	"strings"
	"unsafe"

	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/btcsuite/btcd/btcec/v2/schnorr"
	"github.com/templexxx/xhex"
)

var KeyOne = SecretKey{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1}

func Generate() SecretKey {
	var sk SecretKey

	for {
		if _, err := io.ReadFull(rand.Reader, sk[:]); err != nil {
			panic(fmt.Errorf("failed to read random bytes when generating private key"))
		}

		// there is a ridiculously small probabily of the secret key not yield a valid public key, so iterate here
		pk := sk.Public()
		if _, err := schnorr.ParsePubKey(pk[:]); err != nil {
			continue
		}

		return sk
	}
}

type SecretKey [32]byte

func (sk SecretKey) String() string { return "sk::" + sk.Hex() }
func (sk SecretKey) Hex() string    { return HexEncodeToString(sk[:]) }
func (sk SecretKey) Public() PubKey { return GetPublicKey(sk) }
func (pk SecretKey) MarshalJSON() ([]byte, error) {
	res := make([]byte, 66)
	xhex.Encode(res[1:], pk[:])
	res[0] = '"'
	res[65] = '"'
	return res, nil
}

func (pk *SecretKey) UnmarshalJSON(buf []byte) error {
	if len(buf) != 66 {
		return fmt.Errorf("must be a hex string of 64 characters")
	}
	if _, err := hex.Decode(pk[:], buf[1:65]); err != nil {
		return err
	}
	return nil
}

func SecretKeyFromHex(skh string) (SecretKey, error) {
	sk := SecretKey{}

	if len(skh) < 64 {
		skh = strings.Repeat("0", 64-len(skh)) + skh
	} else if len(skh) > 64 {
		return sk, fmt.Errorf("secret key should be at most 64-char hex, got '%s'", skh)
	}

	if _, err := hex.Decode(sk[:], unsafe.Slice(unsafe.StringData(skh), 64)); err != nil {
		return sk, fmt.Errorf("'%s' is not valid hex: %w", skh, err)
	}

	if sk.Public() != ZeroPK {
		return sk, nil
	}

	return sk, fmt.Errorf("invalid secret key")
}

func MustSecretKeyFromHex(idh string) SecretKey {
	id := SecretKey{}
	if err := xhex.Decode(id[:], unsafe.Slice(unsafe.StringData(idh), 64)); err != nil {
		panic(err)
	}
	return id
}

func GetPublicKey(sk [32]byte) PubKey {
	_, pk := btcec.PrivKeyFromBytes(sk[:])
	return [32]byte(pk.SerializeCompressed()[1:])
}

var (
	ZeroPK = PubKey{}

	// this special public key doesn't have a secret key known to anyone,
	// it corresponds to the hash of the block #3 of bitcoin (the first 3 block hashes are not valid public keys)
	NUMS = MustPubKeyFromHex("0000000082b5015589a3fdf2d4baff403e6f0be035a5d9742c1cae6295464449")
)

type PubKey [32]byte

var (
	_ stdjson.Marshaler   = PubKey{}
	_ stdjson.Unmarshaler = (*PubKey)(nil)
	_ stdjson.Marshaler   = SecretKey{}
	_ stdjson.Unmarshaler = (*SecretKey)(nil)
)

func (pk PubKey) String() string { return "pk::" + pk.Hex() }
func (pk PubKey) Hex() string    { return HexEncodeToString(pk[:]) }
func (pk PubKey) MarshalJSON() ([]byte, error) {
	res := make([]byte, 66)
	xhex.Encode(res[1:], pk[:])
	res[0] = '"'
	res[65] = '"'
	return res, nil
}

func (pk *PubKey) UnmarshalJSON(buf []byte) error {
	if len(buf) != 66 {
		return fmt.Errorf("must be a hex string of 64 characters")
	}
	if err := xhex.Decode(pk[:], buf[1:65]); err != nil {
		return err
	}
	if _, err := schnorr.ParsePubKey(pk[:]); err != nil {
		return fmt.Errorf("pubkey is not valid %w", err)
	}
	return nil
}

func PubKeyFromHex(pkh string) (PubKey, error) {
	pk := PubKey{}
	if len(pkh) != 64 {
		return pk, fmt.Errorf("pubkey should be 64-char hex, got '%s'", pkh)
	}
	if err := xhex.Decode(pk[:], unsafe.Slice(unsafe.StringData(pkh), 64)); err != nil {
		return pk, fmt.Errorf("'%s' is not valid hex: %w", pkh, err)
	}
	if _, err := schnorr.ParsePubKey(pk[:]); err != nil {
		return pk, fmt.Errorf("'%s' is not a valid pubkey", pkh)
	}
	return pk, nil
}

func PubKeyFromHexCheap(pkh string) (PubKey, error) {
	pk := PubKey{}
	if len(pkh) != 64 {
		return pk, fmt.Errorf("pubkey should be 64-char hex, got '%s'", pkh)
	}
	if err := xhex.Decode(pk[:], unsafe.Slice(unsafe.StringData(pkh), 64)); err != nil {
		return pk, fmt.Errorf("'%s' is not valid hex: %w", pkh, err)
	}

	return pk, nil
}

func MustPubKeyFromHex(pkh string) PubKey {
	pk := PubKey{}
	if err := xhex.Decode(pk[:], unsafe.Slice(unsafe.StringData(pkh), 64)); err != nil {
		panic(err)
	}
	return pk
}

func ContainsPubKey(haystack []PubKey, needle PubKey) bool {
	for _, cand := range haystack {
		if cand == needle {
			return true
		}
	}
	return false
}
