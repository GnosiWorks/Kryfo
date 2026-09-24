// SPDX-License-Identifier: GPL-3.0-or-later
package main

// public handles. @wren instead of three words, for people who want to be
// findable on purpose - a creator putting one link in a bio, someone who
// would rather say a name than read out neon-tiger-saturn.
//
// this is the one part of kryfo with a central registry, and it is worth
// being precise about what that costs. the registry holds a handle, the
// invite it points at, and the identity key that claimed it. the invite is
// the same blob already printed on the qr code and pasted into chats - it is
// meant to be public. what the registry does NOT hold is who you talk to,
// what you said, or who looked you up: the page is static and the server is
// configured not to log visitors.
//
// off by default, and released as easily as claimed. a handle nobody claimed
// is a handle nobody can be compelled to hand over.
//
// ownership is proved by signing the handle with the identity key the invite
// already carries, so nobody can claim a name that points at someone else's
// invite, and only the original claimer can release or repoint it.

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"
)

import "C"

// the service lives on the same box as the relay. reached through whatever
// route the current mode uses, so it works where tor does not.
const handleBase = "https://relay.kryfo.app"

// lowercase, digits and underscore, 3-20. no unicode: a handle that can be
// spelled two ways is a handle someone can impersonate.
var handleOK = regexp.MustCompile(`^[a-z0-9_]{3,20}$`)

func handleSign(h string) (sig, pub string, err error) {
	mu.Lock()
	priv := myEdPriv
	mu.Unlock()
	if priv == nil {
		return "", "", fmt.Errorf("no identity yet")
	}
	s := ed25519.Sign(priv, []byte("kryfo-handle-v1:"+h))
	return hex.EncodeToString(s),
		hex.EncodeToString(priv.Public().(ed25519.PublicKey)),
		nil
}

func handleHTTP() (*http.Client, error) { return torNostrClient() }

//export HaloHandleCheck
//
// is this handle free? returns "free", "taken", or an error string.
func HaloHandleCheck(cHandle *C.char) *C.char {
	h := strings.ToLower(strings.TrimSpace(C.GoString(cHandle)))
	if !handleOK.MatchString(h) {
		return C.CString("error: 3-20 characters, letters numbers underscore")
	}
	client, err := handleHTTP()
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	req, _ := http.NewRequest("GET", handleBase+"/handle/check?h="+h, nil)
	req.Header.Set("User-Agent", "")
	resp, err := client.Do(req)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	var out struct {
		Free bool `json:"free"`
	}
	if json.Unmarshal(b, &out) != nil {
		return C.CString("error: bad answer from the registry")
	}
	if out.Free {
		return C.CString("free")
	}
	return C.CString("taken")
}

//export HaloHandleClaim
//
// claim a handle for an invite. the signature is over the handle alone, made
// with the identity key, so the registry can check the claimer is the person
// the invite describes.
func HaloHandleClaim(cHandle *C.char, cInvite *C.char, cBio *C.char) *C.char {
	h := strings.ToLower(strings.TrimSpace(C.GoString(cHandle)))
	invite := C.GoString(cInvite)
	bio := C.GoString(cBio)
	if !handleOK.MatchString(h) {
		return C.CString("error: 3-20 characters, letters numbers underscore")
	}
	if invite == "" {
		return C.CString("error: no invite to point at")
	}
	if len(bio) > 200 {
		bio = bio[:200]
	}
	sig, pub, err := handleSign(h)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	body, _ := json.Marshal(map[string]string{
		"handle": h,
		"invite": invite,
		"bio":    bio,
		"pubkey": pub,
		"sig":    sig,
	})
	return C.CString(handlePost("/handle/claim", body))
}

//export HaloHandleRelease
//
// give it back. the same signature proves it was yours to release.
func HaloHandleRelease(cHandle *C.char) *C.char {
	h := strings.ToLower(strings.TrimSpace(C.GoString(cHandle)))
	sig, pub, err := handleSign(h)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	body, _ := json.Marshal(map[string]string{
		"handle": h,
		"pubkey": pub,
		"sig":    sig,
	})
	return C.CString(handlePost("/handle/release", body))
}

func handlePost(path string, body []byte) string {
	client, err := handleHTTP()
	if err != nil {
		return "error: " + err.Error()
	}
	req, err := http.NewRequest("POST", handleBase+path, strings.NewReader(string(body)))
	if err != nil {
		return "error: " + err.Error()
	}
	req.Header.Set("Content-Type", "application/json")
	// nothing identifying in the headers - the body already says who we are,
	// and only because it has to.
	req.Header.Set("User-Agent", "")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return "error: " + err.Error()
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	var out struct {
		OK  bool   `json:"ok"`
		Err string `json:"error"`
	}
	if json.Unmarshal(b, &out) != nil {
		return "error: bad answer from the registry"
	}
	if !out.OK {
		if out.Err == "" {
			out.Err = "refused"
		}
		return "error: " + out.Err
	}
	return "ok"
}

// the text an owner signs to go into search or out of it. the registry
// builds the same one (server/handle, listingMsg); a test on each side pins
// it to the same line.
func handleListingMsg(h string, listed bool, ts int64, name string) string {
	l := "0"
	if listed {
		l = "1"
	}
	return fmt.Sprintf("kryfo-handle-list-v1:%s:%s:%d:%s", h, l, ts, name)
}

//export HaloHandleListing
//
// in search or out of it: "1" puts the handle in the registry's search
// under name, "0" takes it out. a handle and being findable are separate:
// claiming one never lists it. signed with the identity key, with the time,
// so the registry takes each change once and in order.
func HaloHandleListing(cHandle *C.char, cListed *C.char, cName *C.char) *C.char {
	h := strings.ToLower(strings.TrimSpace(C.GoString(cHandle)))
	if !handleOK.MatchString(h) {
		return C.CString("error: 3-20 characters, letters numbers underscore")
	}
	listed := C.GoString(cListed) == "1"
	name := ""
	if listed {
		r := []rune(strings.TrimSpace(C.GoString(cName)))
		if len(r) > 40 {
			r = r[:40]
		}
		name = string(r)
	}
	mu.Lock()
	priv := myEdPriv
	mu.Unlock()
	if priv == nil {
		return C.CString("error: no identity yet")
	}
	body := handleListingBody(priv, h, listed, name, time.Now().Unix())
	return C.CString(handlePost("/handle/listing", body))
}

// the request the registry takes (server/handle, listingHandler)
func handleListingBody(priv ed25519.PrivateKey, h string, listed bool, name string, ts int64) []byte {
	sig := ed25519.Sign(priv, []byte(handleListingMsg(h, listed, ts, name)))
	l := "0"
	if listed {
		l = "1"
	}
	body, _ := json.Marshal(map[string]string{
		"handle": h,
		"listed": l,
		"name":   name,
		"ts":     fmt.Sprint(ts),
		"pubkey": hex.EncodeToString(priv.Public().(ed25519.PublicKey)),
		"sig":    hex.EncodeToString(sig),
	})
	return body
}
