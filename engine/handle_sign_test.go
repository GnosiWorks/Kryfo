// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

const signInvite = "kryfo://share?id=a-b-c&onion=x.onion&v=3&bundle=zz&fc=ff"

// the registry verifies these exact texts (server/handle, claimMsgV2 and
// releaseMsgV2, with the same vectors in its tests)
func TestHandleMessagesMatchRegistry(t *testing.T) {
	if got := handleClaimMsg("wren", signInvite, 1790000000); got !=
		"kryfo-handle-claim-v2:wren:530f32c83efc284e4c58096111b3b3109892d39404fe0bc18aa9f141e5b77d1d:1790000000" {
		t.Fatal(got)
	}
	if got := handleReleaseMsg("wren", 1790000000); got != "kryfo-handle-release-v2:wren:1790000000" {
		t.Fatal(got)
	}
}

// the words an invite names come from the key that signs for it; the
// registry derives them the same way (server/handle, wordsOf)
func TestWordsMatchRegistry(t *testing.T) {
	pub := make([]byte, 32)
	for i := range pub {
		pub[i] = byte(i)
	}
	if got := idFromPubkey(pub); got != "manage-cruise-coast" {
		t.Fatal(got)
	}
}

func bodyOf(t *testing.T, b []byte) map[string]string {
	t.Helper()
	var m map[string]string
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func verifies(t *testing.T, body map[string]string, msg string) bool {
	t.Helper()
	pub, _ := hex.DecodeString(body["pubkey"])
	sig, _ := hex.DecodeString(body["sig"])
	return len(pub) == ed25519.PublicKeySize && ed25519.Verify(pub, []byte(msg), sig)
}

// a claim carries the time and the version, and its signature covers the
// handle, the invite and the time, and nothing a release or an old claim is
func TestHandleClaimBody(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(nil)
	got := bodyOf(t, handleClaimBody(priv, "wren", signInvite, "hi", 1790000000))
	if got["handle"] != "wren" || got["invite"] != signInvite || got["bio"] != "hi" ||
		got["ts"] != "1790000000" || got["v"] != "2" || got["pubkey"] != hex.EncodeToString(pub) {
		t.Fatalf("body: %v", got)
	}
	if !verifies(t, got, handleClaimMsg("wren", signInvite, 1790000000)) {
		t.Fatal("the claim does not verify")
	}
	for _, other := range []string{
		handleReleaseMsg("wren", 1790000000),
		"kryfo-handle-v1:wren",
		handleClaimMsg("wren", signInvite+"x", 1790000000),
		handleClaimMsg("wren", signInvite, 1790000001),
		handleClaimMsg("kite", signInvite, 1790000000),
	} {
		if verifies(t, got, other) {
			t.Errorf("the claim also verifies as %q", other)
		}
	}
}

func TestHandleReleaseBody(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(nil)
	got := bodyOf(t, handleReleaseBody(priv, "wren", 1790000000))
	if got["handle"] != "wren" || got["ts"] != "1790000000" || got["v"] != "2" ||
		got["pubkey"] != hex.EncodeToString(pub) {
		t.Fatalf("body: %v", got)
	}
	if !verifies(t, got, handleReleaseMsg("wren", 1790000000)) {
		t.Fatal("the release does not verify")
	}
	for _, other := range []string{
		handleClaimMsg("wren", signInvite, 1790000000),
		"kryfo-handle-v1:wren",
		handleReleaseMsg("wren", 1790000001),
	} {
		if verifies(t, got, other) {
			t.Errorf("the release also verifies as %q", other)
		}
	}
}

// whatever the registry writes in a refusal, the app gets one of a few
// fixed answers
func TestHandleRefusalsAreFixed(t *testing.T) {
	useStandIns(t, modeBalanced, nil)
	var answer string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(answer))
	}))
	defer srv.Close()
	oldBase := handleBase
	handleBase = srv.URL
	defer func() { handleBase = oldBase }()
	_, priv, _ := ed25519.GenerateKey(nil)
	mu.Lock()
	oldEd := myEdPriv
	myEdPriv = priv
	mu.Unlock()
	defer func() {
		mu.Lock()
		myEdPriv = oldEd
		mu.Unlock()
	}()

	for _, c := range []struct{ answer, want string }{
		{`{"ok":true}`, "ok"},
		{`{"ok":false,"error":"that handle is taken"}`, "error: taken"},
		{`{"ok":false,"error":"that handle is not available"}`, "error: taken"},
		{`{"ok":false,"error":"not yours to release"}`, "error: not yours"},
		{`{"ok":false,"error":"check the phone's clock"}`, "error: clock"},
		{`{"ok":false,"error":"Update now at https://example.com"}`, "error: refused"},
		{`{"ok":false}`, "error: refused"},
		{`<html>busy</html>`, "error: bad answer from the registry"},
	} {
		answer = c.answer
		if got := handleClaim("wren", signInvite, ""); got != c.want {
			t.Errorf("claim answered %s: got %q, want %q", c.answer, got, c.want)
		}
		if got := handleRelease("wren"); got != c.want {
			t.Errorf("release answered %s: got %q, want %q", c.answer, got, c.want)
		}
	}
}
