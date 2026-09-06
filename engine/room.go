// SPDX-License-Identifier: GPL-3.0-or-later
package main

// burner rooms. a room is joined under a keypair made for that room alone:
// the other people in it learn a key that works there and nowhere else, and
// the relay sees addresses that share nothing with the identity above. the
// wrap, the addresses and the first-contact drop box are the same code as
// everything else, only the key is the room's, not ours. when the room is
// gone the key is gone, and with it every address it ever derived.

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"strings"
	"time"

	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"golang.org/x/crypto/curve25519"
)

func roomKey(privHex string) (xid, error) {
	return xidFromPrivHex(privHex)
}

func peerArr(pubHex string) ([32]byte, error) {
	var out [32]byte
	b, err := hex.DecodeString(pubHex)
	if err != nil || len(b) != 32 {
		return out, fmt.Errorf("bad peer pubkey")
	}
	copy(out[:], b)
	return out, nil
}

// publish one wrap the way HaloNostrSend does, remembering the id so our
// own subscription does not hand it back to us.
func publishWrap(gw nostr2.Event) (int, error) {
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		return 0, fmt.Errorf("wrap convert: %v", err)
	}
	nostrMu.Lock()
	nostrSentIDs[ev.ID.Hex()] = true
	if len(nostrSentIDs) > 4096 {
		nostrSentIDs = map[string]bool{}
	}
	nostrMu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	ok := nostrPublishMulti(ctx, ev)
	if ok == 0 {
		return 0, fmt.Errorf("no relays accepted")
	}
	return ok, nil
}

// a fresh x25519 keypair for one room. "priv:pub", both hex. dart keeps it
// in the room row and hands the private half back on every call.
//
//export HaloRoomKeygen
func HaloRoomKeygen() *C.char {
	var priv, pub [32]byte
	if _, err := rand.Read(priv[:]); err != nil {
		return C.CString(fmt.Sprintf("error: keygen: %v", err))
	}
	curve25519.ScalarBaseMult(&pub, &priv)
	return C.CString(hex.EncodeToString(priv[:]) + ":" + hex.EncodeToString(pub[:]))
}

// the room's first-contact address. goes in the invite so someone with the
// link can reach the creator before the creator knows them.
//
//export HaloRoomFcPk
func HaloRoomFcPk(cPriv *C.char) *C.char {
	me, err := roomKey(C.GoString(cPriv))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	_, pk, err := fcKeysFrom(me.priv, 0)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(pk)
}

//export HaloRoomSend
func HaloRoomSend(cPriv, cPeer, cMsg *C.char) *C.char {
	me, err := roomKey(C.GoString(cPriv))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	peer, err := peerArr(C.GoString(cPeer))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	gw, err := nip17WrapAs(me, peer, C.GoString(cMsg))
	if err != nil {
		return C.CString(fmt.Sprintf("error: wrap: %v", err))
	}
	n, err := publishWrap(gw)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	log.Printf("room: sent to %d relays", n)
	return C.CString("ok")
}

//export HaloRoomSendFirstContact
func HaloRoomSendFirstContact(cPriv, cPeer, cFcPk, cMsg *C.char) *C.char {
	me, err := roomKey(C.GoString(cPriv))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	peer, err := peerArr(C.GoString(cPeer))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	fcPk := C.GoString(cFcPk)
	if len(fcPk) != 64 {
		return C.CString("error: bad first-contact pubkey")
	}
	gw, err := nip17WrapFirstContactAs(me, peer, fcPk, C.GoString(cMsg))
	if err != nil {
		return C.CString(fmt.Sprintf("error: wrap: %v", err))
	}
	n, err := publishWrap(gw)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	log.Printf("room: sent first-contact to %d relays", n)
	return C.CString("ok")
}

func roomSubKey(me xid, peerHex string) string {
	return "room:" + hex.EncodeToString(me.pub[:]) + ":" + peerHex
}

func startSub(key string, run func(ctx context.Context)) {
	nostrMu.Lock()
	if cancel, exists := nostrSubs[key]; exists {
		cancel()
		delete(nostrSubs, key)
	}
	ctx, cancel := context.WithCancel(context.Background())
	nostrSubs[key] = cancel
	nostrMu.Unlock()
	go run(ctx)
}

// listen for one member of a room. the inbox line is tagged
// "room:<roompub>:<peerpub>" so dart knows both which room key received it
// and who sent it.
//
//export HaloRoomSubscribe
func HaloRoomSubscribe(cPriv, cPeer *C.char) *C.char {
	me, err := roomKey(C.GoString(cPriv))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	peerHex := C.GoString(cPeer)
	peer, err := peerArr(peerHex)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	_, rcvPk, err := nip17RcvAddressAs(me, peer)
	if err != nil {
		return C.CString(fmt.Sprintf("error: derive: %v", err))
	}
	key := roomSubKey(me, peerHex)
	startSub(key, func(ctx context.Context) {
		nostrSubscribeRunnerFn(ctx, key, rcvPk, func(gw nostr2.Event) (string, error) {
			return nip17UnwrapAs(me, peer, gw)
		})
	})
	log.Printf("room: subscribed %s... at %s...", peerHex[:12], rcvPk[:12])
	return C.CString("ok")
}

// the room's own drop box, for people joining off the link. tagged
// "roomfc:<roompub>". what lands here is unverified until the join frame
// inside it names a key we can then subscribe to properly.
//
//export HaloRoomSubscribeFirstContact
func HaloRoomSubscribeFirstContact(cPriv *C.char) *C.char {
	me, err := roomKey(C.GoString(cPriv))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	fcSk, fcPk, err := fcKeysFrom(me.priv, 0)
	if err != nil {
		return C.CString(fmt.Sprintf("error: derive: %v", err))
	}
	key := "roomfc:" + hex.EncodeToString(me.pub[:])
	startSub(key, func(ctx context.Context) {
		nostrSubscribeRunnerFn(ctx, key, fcPk, func(gw nostr2.Event) (string, error) {
			content, _, err := nip17UnwrapFirstContactWith(fcSk, gw)
			return content, err
		})
	})
	log.Printf("room: watching drop box %s...", fcPk[:12])
	return C.CString("ok")
}

// stop every subscription a room key holds. called on expiry and on leave;
// after this nothing addressed to the room can arrive.
//
//export HaloRoomUnsubscribe
func HaloRoomUnsubscribe(cPub *C.char) *C.char {
	pub := C.GoString(cPub)
	n := 0
	nostrMu.Lock()
	for key, cancel := range nostrSubs {
		if strings.HasPrefix(key, "room:"+pub+":") || key == "roomfc:"+pub {
			cancel()
			delete(nostrSubs, key)
			n++
		}
	}
	nostrMu.Unlock()
	log.Printf("room: dropped %d subscriptions", n)
	return C.CString("ok")
}
