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
	pushVectorSealed = "AX4ZIJFmHcY44puFSkf2E5Q9IphFdswYnHBChNO9B8xziubrOBUxYXDNDOh20tbhE_jYRV2Qss7L1iseaZJQkfx-R0YchsjzEYbSrtA7OQBs3mR3RexKcsnooe65EIC9hQuOnp8ZnnP8H78fHuAVqIYpp1aTxnWFYsI5Rs5pU8p5o2_FArSt8W4XxyeQl4tEBA1upoU4lHg9_DimSsH9gbqFENXtCuXpSYOnI7m1qdFnMjFW8Zihk0AIk-WnqWh-vxRxvWtgU4Wa_bR5n4rdOKT0C7IPhTyAuamc-E9BnCILh9Y08Pot_jcyTr1VvMMknVud__gcEpTPOcTbLvm0fK13SO3YSFnd3OJQU0lmZhOdMR6Z9LiNOp8IionfZKc3DHDScTwirBWfkpssyH6qgMjx5TCXlpoFmGw2fGiyi5D5pkDPcJ6ThrmMVV9HSD2lmQgd1A2m9n4b0rBI3-A6heduo0EmnHak"
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
	if len(pt) != pushPadded {
		t.Fatalf("plaintext of %d bytes, want the padded %d", len(pt), pushPadded)
	}
	return strings.TrimRight(string(pt), ".")
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
		// the endpoint fits the relay's limit
		if n := len("https://relay.kryfo.app/push/") + len(s); n > 512 {
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

// a seal's length says nothing of its token's: short and long seal alike
func TestPushSealHidesTheTokenLength(t *testing.T) {
	short, err := pushSeal(pushVectorPub, strings.Repeat("a", 140))
	if err != nil {
		t.Fatal(err)
	}
	long, err := pushSeal(pushVectorPub, strings.Repeat("b", 300))
	if err != nil {
		t.Fatal(err)
	}
	if len(short) != len(long) || len(short) != 480 {
		t.Fatalf("seals of %d and %d characters, want 480 both", len(short), len(long))
	}
	k := pushTestKey(t)
	if pushOpen(t, k, short) != strings.Repeat("a", 140) || pushOpen(t, k, long) != strings.Repeat("b", 300) {
		t.Fatal("the padding does not come off")
	}
}
