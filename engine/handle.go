// SPDX-License-Identifier: GPL-3.0-or-later
package main

// public handles: @wren instead of three words, for people who want to be
// findable on purpose. the one central registry in kryfo. it holds a handle,
// the invite it points at (already public) and the key that claimed it, not
// who you talk to or who looked you up. off by default.
//
// ownership is proved with the identity key the invite's three words come
// from. a claim signs the handle, the invite and the time; a release signs
// the handle and the time under a different prefix. so a claim cannot be
// used as a release or the other way round, and the registry takes neither
// once it is old.

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
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
// route the current mode uses, so it works where tor does not. a var so
// tests can point it at a stand-in.
var handleBase = "https://relay.kryfo.app"

// lowercase, digits and underscore, 3-20. no unicode: a handle that can be
// spelled two ways is a handle someone can impersonate.
var handleOK = regexp.MustCompile(`^[a-z0-9_]{3,20}$`)

// the texts the registry verifies (server/handle, claimMsgV2 and
// releaseMsgV2). the invite goes in as its hash, so the message stays short
// and still names exactly one invite.
func handleClaimMsg(h, invite string, ts int64) string {
	sum := sha256.Sum256([]byte(invite))
	return fmt.Sprintf("kryfo-handle-claim-v2:%s:%s:%d", h, hex.EncodeToString(sum[:]), ts)
}

func handleReleaseMsg(h string, ts int64) string {
	return fmt.Sprintf("kryfo-handle-release-v2:%s:%d", h, ts)
}

func handleClaimBody(priv ed25519.PrivateKey, h, invite, bio string, ts int64) []byte {
	sig := ed25519.Sign(priv, []byte(handleClaimMsg(h, invite, ts)))
	body, _ := json.Marshal(map[string]string{
		"handle": h,
		"invite": invite,
		"bio":    bio,
		"ts":     fmt.Sprint(ts),
		"v":      "2",
		"pubkey": hex.EncodeToString(priv.Public().(ed25519.PublicKey)),
		"sig":    hex.EncodeToString(sig),
	})
	return body
}

func handleReleaseBody(priv ed25519.PrivateKey, h string, ts int64) []byte {
	sig := ed25519.Sign(priv, []byte(handleReleaseMsg(h, ts)))
	body, _ := json.Marshal(map[string]string{
		"handle": h,
		"ts":     fmt.Sprint(ts),
		"v":      "2",
		"pubkey": hex.EncodeToString(priv.Public().(ed25519.PublicKey)),
		"sig":    hex.EncodeToString(sig),
	})
	return body
}

func handleKey() ed25519.PrivateKey {
	mu.Lock()
	defer mu.Unlock()
	return myEdPriv
}

// the registry's own lane, apart from the circuits that carry the contacts
func handleHTTP() (*http.Client, error) { return torNostrClientFor(laneServices) }

// is this handle free? returns "free", "taken", or an error string.
//
//export HaloHandleCheck
func HaloHandleCheck(cHandle *C.char) *C.char {
	return C.CString(handleCheck(C.GoString(cHandle)))
}

func handleCheck(raw string) string {
	h := strings.ToLower(strings.TrimSpace(raw))
	if !handleOK.MatchString(h) {
		return "error: 3-20 characters, letters numbers underscore"
	}
	client, err := handleHTTP()
	if err != nil {
		return "error: " + err.Error()
	}
	body, _ := json.Marshal(map[string]string{"h": h})
	req, _ := http.NewRequest("POST", handleBase+"/handle/check", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "")
	resp, err := client.Do(req)
	if err != nil {
		return "error: " + err.Error()
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	var out struct {
		Free bool `json:"free"`
	}
	if json.Unmarshal(b, &out) != nil {
		return "error: bad answer from the registry"
	}
	if out.Free {
		return "free"
	}
	return "taken"
}

// claim a handle for an invite, or point a held one at a new invite. signed
// with the identity key, over the handle, the invite and the time.
//
//export HaloHandleClaim
func HaloHandleClaim(cHandle *C.char, cInvite *C.char, cBio *C.char) *C.char {
	return C.CString(handleClaim(C.GoString(cHandle), C.GoString(cInvite), C.GoString(cBio)))
}

func handleClaim(raw, invite, bio string) string {
	h := strings.ToLower(strings.TrimSpace(raw))
	if !handleOK.MatchString(h) {
		return "error: 3-20 characters, letters numbers underscore"
	}
	if invite == "" {
		return "error: no invite to point at"
	}
	if len(bio) > 200 {
		bio = bio[:200]
	}
	priv := handleKey()
	if priv == nil {
		return "error: no identity yet"
	}
	return handlePost("/handle/claim", handleClaimBody(priv, h, invite, bio, time.Now().Unix()))
}

// give it back, signed with the same key over the handle and the time.
//
//export HaloHandleRelease
func HaloHandleRelease(cHandle *C.char) *C.char {
	return C.CString(handleRelease(C.GoString(cHandle)))
}

func handleRelease(raw string) string {
	h := strings.ToLower(strings.TrimSpace(raw))
	priv := handleKey()
	if priv == nil {
		return "error: no identity yet"
	}
	return handlePost("/handle/release", handleReleaseBody(priv, h, time.Now().Unix()))
}

// the registry's words never go further than here: the app gets one of a
// few fixed answers and says them in its own words
func handleRefusal(msg string) string {
	switch msg {
	case "that handle is taken", "that handle is not available":
		return "taken"
	case "not yours to release", "not yours to change":
		return "not yours"
	case "check the phone's clock":
		return "clock"
	}
	return "refused"
}

func handlePost(path string, body []byte) string {
	client, err := handleHTTP()
	if err != nil {
		return "error: " + err.Error()
	}
	req, err := http.NewRequest("POST", handleBase+path, bytes.NewReader(body))
	if err != nil {
		return "error: " + err.Error()
	}
	req.Header.Set("Content-Type", "application/json")
	// nothing identifying in the headers: the body already says who we are,
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
		return "error: " + handleRefusal(out.Err)
	}
	return "ok"
}

// the text an owner signs to list or unlist a handle. the registry builds
// the same one (server/handle, listingMsg).
func handleListingMsg(h string, listed bool, ts int64, name string) string {
	l := "0"
	if listed {
		l = "1"
	}
	return fmt.Sprintf("kryfo-handle-list-v1:%s:%s:%d:%s", h, l, ts, name)
}

// "1" lists the handle in the registry's search under name, "0" takes it
// out. claiming a handle never lists it. signed with the time so the
// registry takes each change once and in order.
//
//export HaloHandleListing
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
	priv := handleKey()
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
