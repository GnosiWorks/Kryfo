// SPDX-License-Identifier: GPL-3.0-or-later
package main

// addresses of a device pair (identity v4 3.6, section 5 R9): one of my
// devices of an identity with one device of a contact's identity, or with
// another device of my own. the seeded pair is 3.6's formula with the two
// device keys; the identity pair (device 1 to device 1, D = I) is today's
// v4 pair and keeps its form byte for byte.
//
// the first opener of a device pair goes before the receiver holds the
// pair's seed, so it goes to an opener address with no seed in it (D1):
//
//   ikm  = X25519(my device key, their device key)
//   salt = sha256(min(u_Ia, u_Ib) || max(u_Ia, u_Ib))[0:16]
//   info = "kryfo-conv-v4:" || owner device key (33) || other device key
//          (33) || role (3) || ctr (1)
//   role "opn", owner the receiver: the address
//   role "ops", owner the sender: the opener's seal key, never an address
//
// a receiver watches its opener address only for listed devices it has
// not heard yet. the opener carries the pair's seed; everything after it
// goes on the seeded pair.
//
// a pair arg names a device pair as "peer/their/my" with the device ids
// (1..127, 1 the phone) and ".seed" for the seeded pair. "peer/1/1.seed"
// is "peer.seed". without a seed it is the opener address, which only
// listens: an opener goes with its seed (nostrSendDeviceOpener).

import "C"

import (
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync/atomic"

	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
	"github.com/nbd-wtf/go-nostr/nip59"
)

const (
	roleOpn = "opn"
	roleOps = "ops"
)

// the device id of a phone in every list, and the highest a list holds
const (
	phoneDevice = 1
	maxDevice   = 127
)

// off until the linked-devices switch: every device-pair arg is refused,
// so the engine runs exactly today's pairs
var devicePairsOn atomic.Bool

var errDevicePairsOff = errors.New("device pairs are off")

// the linked-devices switch, from the app (0 off, anything else on)
//
//export HaloDevicePairsOn
func HaloDevicePairsOn(on C.int) *C.char {
	devicePairsOn.Store(on != 0)
	return C.CString("ok")
}

// the x keys of a contact's devices as the lists held now name them, and
// of my own devices when [peer] is my identity. device 1 never comes here:
// its key is the identity's. job 2 sets this from devices.Book and
// devices.Own (Current(I).Find(dev)); while nil, a pair with another
// device than the phone on their side is refused
type deviceKeySource interface {
	deviceKey(ident int, peer [32]byte, dev uint8) ([32]byte, bool)
}

var deviceKeys atomic.Pointer[deviceKeySource]

func setDeviceKeys(s deviceKeySource) {
	if s == nil {
		deviceKeys.Store(nil)
		return
	}
	deviceKeys.Store(&s)
}

// what a linked container holds of an identity besides its device key:
// the identity key I and this device's id. a phone holds neither (its
// device key is I, its id 1). job 6 (the linked container) sets it
type linkedIdent struct {
	pub [32]byte
	dev uint8
}

// by identity, under identsMu
var linkedIdents = map[int]linkedIdent{}

func putLinkedIdent(ident int, pub [32]byte, dev uint8) error {
	if dev <= phoneDevice || dev > maxDevice {
		return errors.New("a linked device is 2..127")
	}
	identsMu.Lock()
	linkedIdents[ident] = linkedIdent{pub: pub, dev: dev}
	identsMu.Unlock()
	return nil
}

// my identity key and my device id on [ident]: on a phone the device key
// itself and 1
func myDeviceOf(ident int, me xid) ([32]byte, uint8) {
	identsMu.Lock()
	defer identsMu.Unlock()
	if l, ok := linkedIdents[ident]; ok {
		return l.pub, l.dev
	}
	return me.pub, phoneDevice
}

func isLinked(ident int) bool {
	identsMu.Lock()
	defer identsMu.Unlock()
	_, ok := linkedIdents[ident]
	return ok
}

// the device side of a convPair: nil on the identity pair
type devPair struct {
	their, my uint8
	theirKey  [32]byte
	myIdent   [32]byte
	// no seed: the receiver's opener address
	opener bool
}

// the seed of a device pair, by identity, peer, both ids and their device
// key: a device id taken again by a new key is another pair
type devPairKey struct {
	ident     int
	peer      string
	their, my uint8
	theirKey  string
}

// under identsMu
var devSeeds = map[devPairKey][32]byte{}

func (c convPair) devKey() devPairKey {
	return devPairKey{c.ident, hex.EncodeToString(c.peer[:]), c.dev.their, c.dev.my, hex.EncodeToString(c.dev.theirKey[:])}
}

func putDevSeed(k devPairKey, s [32]byte) error {
	identsMu.Lock()
	defer identsMu.Unlock()
	if had, ok := devSeeds[k]; ok && had != s {
		return errors.New("the pair has another seed")
	}
	devSeeds[k] = s
	return nil
}

func putDevSeedAfresh(k devPairKey, s [32]byte) {
	identsMu.Lock()
	devSeeds[k] = s
	identsMu.Unlock()
}

// the device pair let go (a device off the list, a restore): its seeds,
// whatever key the id had
func forgetDevicePair(ident int, peer [32]byte, their, my uint8) {
	p := hex.EncodeToString(peer[:])
	identsMu.Lock()
	for k := range devSeeds {
		if k.ident == ident && k.peer == p && k.their == their && k.my == my {
			delete(devSeeds, k)
		}
	}
	identsMu.Unlock()
}

func deviceID(s string) (uint8, error) {
	n, err := strconv.Atoi(s)
	if err != nil || n < phoneDevice || n > maxDevice || strconv.Itoa(n) != s {
		return 0, errors.New("a device id is 1..127")
	}
	return uint8(n), nil
}

// "peer/their/my" split, ok false for a plain peer
func splitDeviceArg(base string) (peer string, their, my uint8, ok bool, err error) {
	parts := strings.Split(base, "/")
	if len(parts) == 1 {
		return base, 0, 0, false, nil
	}
	if len(parts) != 3 {
		return "", 0, 0, true, errors.New("a device pair is peer/their/my")
	}
	if their, err = deviceID(parts[1]); err != nil {
		return "", 0, 0, true, err
	}
	if my, err = deviceID(parts[2]); err != nil {
		return "", 0, 0, true, err
	}
	return parts[0], their, my, true, nil
}

// the device pair an arg names. [seedHex] is "" for the opener address
func devicePairArg(ident int, peer [32]byte, their, my uint8, seedHex string, seeded bool) (convPair, error) {
	if !devicePairsOn.Load() {
		return convPair{}, errDevicePairsOff
	}
	me, err := identityOf(ident)
	if err != nil {
		return convPair{}, err
	}
	myIdent, myDev := myDeviceOf(ident, me)
	if my != myDev {
		return convPair{}, fmt.Errorf("this is device %d of the identity, not %d", myDev, my)
	}
	if peer == myIdent && their == my {
		return convPair{}, errors.New("a device pair is two devices")
	}
	theirKey := peer
	if their != phoneDevice {
		src := deviceKeys.Load()
		if src == nil {
			return convPair{}, errors.New("no device list held")
		}
		k, ok := (*src).deviceKey(ident, peer, their)
		if !ok {
			return convPair{}, fmt.Errorf("device %d is not on the list held", their)
		}
		// only the phone's device key is the identity's
		if k == peer || k == myIdent {
			return convPair{}, errors.New("a device key is an identity key")
		}
		theirKey = k
	}
	if theirKey == me.pub {
		return convPair{}, errors.New("a device pair is two devices")
	}
	c := convPair{ident: ident, me: me, peer: peer, dev: &devPair{
		their: their, my: my, theirKey: theirKey, myIdent: myIdent, opener: !seeded,
	}}
	if !seeded {
		return c, nil
	}
	b, err := hex.DecodeString(seedHex)
	if err != nil || len(b) != 32 {
		return convPair{}, errors.New("a seed is 32 bytes")
	}
	var s [32]byte
	copy(s[:], b)
	if err := putDevSeed(c.devKey(), s); err != nil {
		return convPair{}, err
	}
	c.seed = &s
	return c, nil
}

func (c convPair) devV4() v4Pair {
	p := v4Pair{me: c.me, their: c.dev.theirKey, myIdent: c.dev.myIdent, theirIdnt: c.peer}
	if c.seed != nil {
		p.seed = c.seed[:]
	}
	return p
}

// the receiver's opener address of a device pair, owner the receiver
func devOpenerRcv(p v4Pair) (sk, pk string, err error) {
	p.seed = nil
	return p.role(roleOpn, true)
}

// an opener sealed with the sender's opener seal key to the receiver's
// opener address
func devOpenerWrap(p v4Pair, msg string) (nostr2.Event, error) {
	p.seed = nil
	sealSk, sealPk, err := p.role(roleOps, true)
	if err != nil {
		return nostr2.Event{}, err
	}
	_, rcvPk, err := p.role(roleOpn, false)
	if err != nil {
		return nostr2.Event{}, err
	}
	return giftWrapAs(sealSk, sealPk, rcvPk, msg)
}

func devOpenerUnwrapStamped(p v4Pair, gw nostr2.Event) (string, nostr2.Timestamp, error) {
	rcvSk, _, err := devOpenerRcv(p)
	if err != nil {
		return "", 0, err
	}
	rumor, err := nip59.GiftUnwrap(gw, func(otherPk, ct string) (string, error) {
		k, err := nip44.GenerateConversationKey(otherPk, rcvSk)
		if err != nil {
			return "", err
		}
		return nip44.Decrypt(ct, k)
	})
	if err != nil {
		return "", 0, err
	}
	p.seed = nil
	_, want, err := p.role(roleOps, false)
	if err != nil {
		return "", 0, err
	}
	if rumor.PubKey != want {
		return "", 0, fmt.Errorf("seal not from expected peer")
	}
	return rumor.Content, rumor.CreatedAt, nil
}

// the same pair, on its opener address: what an opener goes by
func (c convPair) openerOf() (convPair, error) {
	if c.dev == nil {
		return convPair{}, errors.New("an identity pair has no opener address")
	}
	d := *c.dev
	d.opener = true
	c.dev = &d
	c.seed = nil
	return c, nil
}

// the subscription of a device pair: the identity pair's key, the two ids,
// and "/opn" for the opener address. the tag every line from it carries
func (c convPair) subKey(peerHex string) string {
	k := subKey(c.ident, peerHex)
	if c.dev == nil {
		return k
	}
	k += "/" + strconv.Itoa(int(c.dev.their)) + "/" + strconv.Itoa(int(c.dev.my))
	if c.dev.opener {
		k += "/" + roleOpn
	}
	return k
}

// what a device-pair tag names, ok false for any other tag
func devTagOf(tag string) (ident int, peerHex string, their, my uint8, opener, ok bool) {
	rest := tag
	if strings.HasPrefix(rest, "i") {
		i := strings.IndexByte(rest, ':')
		if i < 2 {
			return
		}
		n, err := strconv.Atoi(rest[1:i])
		if err != nil || n <= mainIdent || strconv.Itoa(n) != rest[1:i] {
			return
		}
		ident, rest = n, rest[i+1:]
	}
	if opener = strings.HasSuffix(rest, "/"+roleOpn); opener {
		rest = strings.TrimSuffix(rest, "/"+roleOpn)
	}
	p, t, m, dev, err := splitDeviceArg(rest)
	if !dev || err != nil || !isHexKey(p) || p != strings.ToLower(p) {
		return 0, "", 0, 0, false, false
	}
	return ident, p, t, m, opener, true
}

// the first opener of a seeded device pair, to the receiver's opener
// address. [peerArg] names the pair with its seed
//
//export HaloNostrSendDeviceOpener
func HaloNostrSendDeviceOpener(cIdent C.int, cPeer, cMsg *C.char) *C.char {
	return C.CString(nostrSendDeviceOpener(identArg(cIdent), goStr(cPeer), goStr(cMsg)))
}

func nostrSendDeviceOpener(ident int, peerArg, msg string) string {
	c, _, err := pairArg(ident, peerArg)
	if err != nil {
		if errors.Is(err, errBadPeer) {
			return "error: bad peer pubkey"
		}
		return fmt.Sprintf("error: wrap: %v", err)
	}
	if c.dev == nil || c.seed == nil {
		return "error: an opener names a seeded device pair"
	}
	o, err := c.openerOf()
	if err != nil {
		return fmt.Sprintf("error: wrap: %v", err)
	}
	return nostrSendOn(o, msg)
}
