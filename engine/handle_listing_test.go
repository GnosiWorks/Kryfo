// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"testing"
)

// the registry verifies this exact text (server/handle, listingMsg): a
// change on one side and not the other and nobody can opt in any more
func TestHandleListingMessageMatchesTheRegistry(t *testing.T) {
	got := handleListingMsg("wren", true, 1790000000, "Wren F.")
	if got != "kryfo-handle-list-v1:wren:1:1790000000:Wren F." {
		t.Fatal(got)
	}
	if handleListingMsg("wren", false, 1, "") != "kryfo-handle-list-v1:wren:0:1:" {
		t.Fatal("opting out")
	}
}

// the body carries every field the registry reads, and its signature
// verifies against the key it names over the text the registry rebuilds
func TestHandleListingBodyVerifies(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(nil)
	var got map[string]string
	if err := json.Unmarshal(handleListingBody(priv, "wren", true, "Wren F.", 1790000000), &got); err != nil {
		t.Fatal(err)
	}
	if got["handle"] != "wren" || got["listed"] != "1" || got["name"] != "Wren F." ||
		got["ts"] != "1790000000" || got["pubkey"] != hex.EncodeToString(pub) {
		t.Fatalf("body: %v", got)
	}
	sig, _ := hex.DecodeString(got["sig"])
	if !ed25519.Verify(pub, []byte("kryfo-handle-list-v1:wren:1:1790000000:Wren F."), sig) {
		t.Fatal("signature does not verify")
	}
}
