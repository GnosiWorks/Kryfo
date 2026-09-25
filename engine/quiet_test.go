package main

import (
	"bytes"
	"crypto/ed25519"
	"encoding/hex"
	"log"
	"os"
	"strings"
	"testing"

	bed25519 "github.com/cretz/bine/torutil/ed25519"

	"github.com/cretz/bine/torutil"
)

func TestQuietIdentityIsSilentAndLeavesTheEngineAlone(t *testing.T) {
	var logged bytes.Buffer
	log.SetOutput(&logged)
	defer log.SetOutput(os.Stderr)
	mu.Lock()
	before, beforeX := myId, myXPub
	mu.Unlock()

	a, err := quietNew()
	if err != nil {
		t.Fatal(err)
	}
	b, err := quietNew()
	if err != nil {
		t.Fatal(err)
	}

	mu.Lock()
	after, afterX := myId, myXPub
	mu.Unlock()
	if before != after || beforeX != afterX {
		t.Fatal("making a quiet identity moved the engine's own")
	}
	if logged.Len() != 0 {
		t.Fatalf("a quiet identity logged: %q", logged.String())
	}
	if a.ID == b.ID || a.XPub == b.XPub || a.Onion == b.Onion {
		t.Fatal("two quiet identities share a value")
	}
	if len(strings.Split(a.ID, "-")) != 3 {
		t.Fatalf("id is not three words: %s", a.ID)
	}
	if !strings.HasSuffix(a.Onion, ".onion") || len(a.Onion) != 56+6 {
		t.Fatalf("not a v3 onion: %s", a.Onion)
	}
}

func TestQuietDescribeGivesBackTheSameIdentity(t *testing.T) {
	a, err := quietNew()
	if err != nil {
		t.Fatal(err)
	}
	ed, _ := hex.DecodeString(a.EdPriv)
	x, _ := hex.DecodeString(a.XPriv)
	on, _ := hex.DecodeString(a.OnionKey)
	b, err := quietDescribe(ed25519.PrivateKey(ed), x, ed25519.PrivateKey(on))
	if err != nil {
		t.Fatal(err)
	}
	if a != b {
		t.Fatalf("described differently:\n%+v\n%+v", a, b)
	}
	// the address tor itself would publish for that key
	want := torutil.OnionServiceIDFromPrivateKey(
		bed25519.FromCryptoPrivateKey(ed25519.PrivateKey(on)),
	)
	if a.Onion != want+".onion" {
		t.Fatalf("onion %s, tor says %s", a.Onion, want)
	}
	// and the id the engine gives the same key when it restores it
	if a.ID != idFromPubkey(ed25519.PrivateKey(ed).Public().(ed25519.PublicKey)) {
		t.Fatal("id differs from the engine's")
	}
	if _, err := quietDescribe(ed25519.PrivateKey(ed[:10]), x, ed25519.PrivateKey(on)); err == nil {
		t.Fatal("a short key was described")
	}
}

func TestQuietFirstContactMatchesTheEngines(t *testing.T) {
	a, err := quietNew()
	if err != nil {
		t.Fatal(err)
	}
	x, _ := hex.DecodeString(a.XPriv)
	var priv [32]byte
	copy(priv[:], x)
	_, want, err := fcKeysFrom(priv, 3)
	if err != nil {
		t.Fatal(err)
	}
	if want == "" {
		t.Fatal("no first-contact key")
	}
}
