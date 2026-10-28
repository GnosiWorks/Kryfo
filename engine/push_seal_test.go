// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/ecdh"
	"crypto/hpke"
	"encoding/base64"
	"strings"
	"testing"
)

// the same vector is in server/push/main_test.go: a seal made one way must
// open the other
const (
	pushVectorSeed   = "kryfo push test vector, never a real key"
	pushVectorPub    = "SNrdb3PnM2ghYWfWaPYQZrJjXAb6T9jQFdg9Fvo_6ls"
	pushVectorToken  = "fcmTestToken:APA91b_vector-only_0123456789"
	pushVectorSealed = "AaXyvBam0p03IOjtNG0_yUPs_HH9gjKYr78eZKqAZ31YvMrawcY55G1oA0tcVibfPGbY-cL7xzQuciCnPwa_RBiQ7rp6mLk98bP-wBxw37krcfaz8Bv4wb4mHw"
)

func pushTestKey(t *testing.T) hpke.PrivateKey {
	t.Helper()
	k, err := hpke.DHKEM(ecdh.X25519()).DeriveKeyPair([]byte(pushVectorSeed))
	if err != nil {
		t.Fatal(err)
	}
	if got := base64.RawURLEncoding.EncodeToString(k.PublicKey().Bytes()); got != pushVectorPub {
		t.Fatalf("vector key %s, want %s", got, pushVectorPub)
	}
	return k
}

func pushOpen(t *testing.T, k hpke.PrivateKey, sealed string) string {
	t.Helper()
	raw, err := base64.RawURLEncoding.DecodeString(sealed)
	if err != nil || len(raw) < 1 || raw[0] != pushSealVersion {
		t.Fatalf("not a sealed token: %v", err)
	}
	pt, err := hpke.Open(k, hpke.HKDFSHA256(), hpke.ChaCha20Poly1305(), []byte(pushSealInfo), raw[1:])
	if err != nil {
		t.Fatalf("does not open: %v", err)
	}
	return string(pt)
}

func TestPushSealSixteenDiffer(t *testing.T) {
	k := pushTestKey(t)
	seen := map[string]bool{}
	for i := 0; i < 16; i++ {
		s, err := pushSeal(pushVectorPub, pushVectorToken)
		if err != nil {
			t.Fatal(err)
		}
		if seen[s] {
			t.Fatalf("seal %d repeats an earlier one", i)
		}
		seen[s] = true
		if strings.Contains(s, "APA91b") {
			t.Fatal("the token shows through the seal")
		}
		if got := pushOpen(t, k, s); got != pushVectorToken {
			t.Fatalf("opened to %q", got)
		}
		// the endpoint fits the relay's limit with room to spare
		if n := len("https://relay.kryfo.app/push/") + len(s); n > 300 {
			t.Fatalf("endpoint of %d characters", n)
		}
	}
}

func TestPushSealOpensTheVector(t *testing.T) {
	if got := pushOpen(t, pushTestKey(t), pushVectorSealed); got != pushVectorToken {
		t.Fatalf("vector opened to %q", got)
	}
}

func TestPushSealLongestTokenFits(t *testing.T) {
	s, err := pushSeal(pushVectorPub, strings.Repeat("a", pushTokenMax))
	if err != nil {
		t.Fatal(err)
	}
	if n := len("https://relay.kryfo.app/push/") + len(s); n > 512 {
		t.Fatalf("endpoint of %d characters, the relay takes 512", n)
	}
}

func TestPushSealRefuses(t *testing.T) {
	for _, c := range []struct{ pub, token string }{
		{"", pushVectorToken},
		{"not-a-key", pushVectorToken},
		{base64.RawURLEncoding.EncodeToString(make([]byte, 31)), pushVectorToken},
		{pushVectorPub, ""},
		{pushVectorPub, "short"},
		{pushVectorPub, strings.Repeat("a", pushTokenMax+1)},
		{pushVectorPub, "has space in it, a token never does"},
		{pushVectorPub, "slash/in/the/token/which/is/not/fcm"},
	} {
		if s, err := pushSeal(c.pub, c.token); err == nil {
			t.Errorf("sealed %q to %q: %s", c.token, c.pub, s)
		}
	}
}
