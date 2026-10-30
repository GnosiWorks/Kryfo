// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the decoy's identity, from pure functions that touch no engine state and
// log nothing. the decoy never goes online: its keys are only shown, and
// carried by a backup made there. its read-only lookups have a lane of
// their own, below.

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"sync"

	bed25519 "github.com/cretz/bine/torutil/ed25519"

	"github.com/cretz/bine/torutil"
	"golang.org/x/crypto/curve25519"
)

type quietIdentity struct {
	EdPriv   string `json:"ed_priv"`
	XPriv    string `json:"x_priv"`
	OnionKey string `json:"onion_key"`
	ID       string `json:"id"`
	EdPub    string `json:"ed_pub"`
	XPub     string `json:"x_pub"`
	Onion    string `json:"onion"`
}

// everything an identity shows, from its three private keys
func quietDescribe(ed ed25519.PrivateKey, xPriv []byte, onion ed25519.PrivateKey) (quietIdentity, error) {
	if len(ed) != ed25519.PrivateKeySize || len(xPriv) != 32 ||
		len(onion) != ed25519.PrivateKeySize {
		return quietIdentity{}, errors.New("bad key")
	}
	var xp, xpub [32]byte
	copy(xp[:], xPriv)
	curve25519.ScalarBaseMult(&xpub, &xp)
	pub := ed.Public().(ed25519.PublicKey)
	opub := onion.Public().(ed25519.PublicKey)
	return quietIdentity{
		EdPriv:   hex.EncodeToString(ed),
		XPriv:    hex.EncodeToString(xPriv),
		OnionKey: hex.EncodeToString(onion),
		ID:       idFromPubkey(pub),
		EdPub:    hex.EncodeToString(pub),
		XPub:     hex.EncodeToString(xpub[:]),
		Onion:    torutil.OnionServiceIDFromV3PublicKey(bed25519.FromCryptoPublicKey(opub)) + ".onion",
	}, nil
}

func quietNew() (quietIdentity, error) {
	_, ed, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return quietIdentity{}, err
	}
	x := make([]byte, 32)
	if _, err := rand.Read(x); err != nil {
		return quietIdentity{}, err
	}
	_, onion, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return quietIdentity{}, err
	}
	return quietDescribe(ed, x, onion)
}

func quietOut(q quietIdentity, err error) *C.char {
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	b, _ := json.Marshal(q)
	return C.CString(string(b))
}

// a new identity for the decoy, as json, or a line starting with "error:"
//
//export HaloQuietIdentity
func HaloQuietIdentity() *C.char {
	return quietOut(quietNew())
}

// what an identity kept in a decoy's database shows, from its private keys
//
//export HaloQuietDescribe
func HaloQuietDescribe(cEd, cX, cOnion *C.char) *C.char {
	ed, err1 := hex.DecodeString(goStr(cEd))
	x, err2 := hex.DecodeString(goStr(cX))
	onion, err3 := hex.DecodeString(goStr(cOnion))
	if err := errors.Join(err1, err2, err3); err != nil {
		return C.CString("error: bad hex")
	}
	return quietOut(quietDescribe(ed25519.PrivateKey(ed), x, ed25519.PrivateKey(onion)))
}

// the first-contact address an invite of this identity carries
//
//export HaloQuietFirstContactPk
func HaloQuietFirstContactPk(cX *C.char, counter C.int) *C.char {
	x, err := hex.DecodeString(goStr(cX))
	if err != nil || len(x) != 32 {
		return C.CString("error: bad x priv")
	}
	var priv [32]byte
	copy(priv[:], x)
	_, pk, err := fcKeysFrom(priv, int(counter))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(pk)
}

// the decoy's read-only lookups (a handle, people search, its check) go on a
// lane of their own, under a socks name made again for every decoy session:
// nothing they ask shares a circuit or a connection with the everyday app's
// registry calls, nor with an earlier decoy session's
var (
	decoyLaneMu sync.Mutex
	decoyLaneID string
)

func decoyLane() (lane, name string) {
	decoyLaneMu.Lock()
	defer decoyLaneMu.Unlock()
	if decoyLaneID == "" {
		decoyLaneID = decoyName()
	}
	return "decoy:" + decoyLaneID, decoyLaneID
}

func decoyName() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// a new decoy session: a new socks name, and the last one's client gone
func decoyLaneNew() {
	decoyLaneMu.Lock()
	old := "decoy:" + decoyLaneID
	decoyLaneID = decoyName()
	decoyLaneMu.Unlock()
	cachedNostrClientMu.Lock()
	if c := cachedNostrClients["tor:"+old]; c != nil {
		c.CloseIdleConnections()
	}
	delete(cachedNostrClients, "tor:"+old)
	cachedNostrClientMu.Unlock()
}

func decoyClient(ctx context.Context) (*http.Client, error) {
	return servicesClientOf(ctx, func() (*http.Client, error) {
		return servicesTorClientAs(decoyLane())
	})
}

//export HaloDecoyLaneNew
func HaloDecoyLaneNew() *C.char {
	decoyLaneNew()
	return C.CString("ok")
}

//export HaloDecoyHandleCheck
func HaloDecoyHandleCheck(cHandle *C.char) *C.char {
	return C.CString(handleCheckOn(goStr(cHandle), decoyClient))
}

//export HaloDecoyTorGetJSON
func HaloDecoyTorGetJSON(cUrl *C.char) *C.char {
	return C.CString(torGetJSONOn(goStr(cUrl), decoyClient))
}

//export HaloDecoyTorPost
func HaloDecoyTorPost(cUrl, cBody *C.char) *C.char {
	return C.CString(torPostOn(goStr(cUrl), goStr(cBody), decoyClient))
}
