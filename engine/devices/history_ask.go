// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/hkdf"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"errors"
)

// asking the phone for the history over its onion. the device asks with a
// mac under a key only the two ends hold, so nobody else who knows the
// phone's onion can make it read its spool. the phone finds the copy by a
// tag of that key. a copy the phone had to make again (its app restarted)
// runs under a key of its own generation, so no two senders ever share a
// stream key, in one process or across restarts

const (
	labelAskSalt = "kryfo-history-v1 ask salt"
	labelAsk     = "kryfo-history-v1 ask"
	labelAskTag  = "kryfo-history-v1 ask tag"
	labelAgain   = "kryfo-history-v1 again"

	// AskTagSize is the tag the phone finds a copy by
	AskTagSize = 16
	// AskMACSize is the mac on each ask
	AskMACSize = 32
)

var ErrAsk = errors.New("devices: history ask does not hold")

// Ask is what both ends derive from the link's stream key for the asks.
type Ask struct {
	key [32]byte
	Tag [AskTagSize]byte
}

// AskFor derives the ask key and its tag from the link's stream key and
// transcript; the same on the phone and the device, whatever generation
// the copy is in.
func AskFor(stream *[StreamKeySize]byte, bind [32]byte) (*Ask, error) {
	if stream == nil {
		return nil, ErrUsable
	}
	salt := sha256.Sum256(append([]byte(labelAskSalt), bind[:]...))
	k, err := hkdf.Key(sha256.New, stream[:], salt[:], labelAsk, 32)
	if err != nil {
		return nil, err
	}
	a := &Ask{}
	copy(a.key[:], k)
	wipe(k)
	m := hmac.New(sha256.New, a.key[:])
	m.Write([]byte(labelAskTag))
	copy(a.Tag[:], m.Sum(nil))
	return a, nil
}

// MAC is the mac over one ask: its op and its argument, each with its
// length, so no two asks share one.
func (a *Ask) MAC(op, arg string) [AskMACSize]byte {
	m := hmac.New(sha256.New, a.key[:])
	var n [4]byte
	for _, s := range []string{labelAsk, op, arg} {
		binary.BigEndian.PutUint32(n[:], uint32(len(s)))
		m.Write(n[:])
		m.Write([]byte(s))
	}
	var out [AskMACSize]byte
	copy(out[:], m.Sum(nil))
	return out
}

// Check says whether mac is the ask's for op and arg, in constant time.
func (a *Ask) Check(op, arg string, mac []byte) bool {
	want := a.MAC(op, arg)
	return hmac.Equal(want[:], mac)
}

// Wipe forgets the ask key.
func (a *Ask) Wipe() { clear(a.key[:]) }

// AgainKey is the stream key of a copy's generation gen: the link's own for
// 0, then one of its own for each copy the phone had to make again.
func AgainKey(stream *[StreamKeySize]byte, bind [32]byte, gen uint32) (*[StreamKeySize]byte, error) {
	if stream == nil {
		return nil, ErrUsable
	}
	out := &[StreamKeySize]byte{}
	if gen == 0 {
		*out = *stream
		return out, nil
	}
	var info [len(labelAgain) + 4]byte
	copy(info[:], labelAgain)
	binary.BigEndian.PutUint32(info[len(labelAgain):], gen)
	salt := sha256.Sum256(append([]byte(labelAskSalt), bind[:]...))
	k, err := hkdf.Key(sha256.New, stream[:], salt[:], string(info[:]), StreamKeySize)
	if err != nil {
		return nil, err
	}
	copy(out[:], k)
	wipe(k)
	return out, nil
}
