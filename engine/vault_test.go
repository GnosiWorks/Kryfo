package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"log"
	"os"
	"strings"
	"testing"
)

func b64(s string) string { return base64.StdEncoding.EncodeToString([]byte(s)) }

func mustKeys(t *testing.T) vaultKeys {
	t.Helper()
	k, err := vaultNewKeys()
	if err != nil {
		t.Fatal(err)
	}
	return k
}

func TestVaultSealRoundTrip(t *testing.T) {
	a, b := mustKeys(t), mustKeys(t)
	if !strings.HasPrefix(a.Pub, "age1") || !strings.HasPrefix(a.Priv, "AGE-SECRET-KEY-1") {
		t.Fatalf("not age x25519 keys: %s", a.Pub)
	}
	if a.Pub == b.Pub || a.Priv == b.Priv {
		t.Fatal("two vaults share a key")
	}
	bin := make([]byte, 256)
	for i := range bin {
		bin[i] = byte(i)
	}
	for _, msg := range []string{
		`{"from":"a-b-c","wire":"x","bp":"","at":1}`,
		"",
		string(bin),
		strings.Repeat("slice", 200_000), // a media slice
	} {
		sealed, err := vaultSealB64(a.Pub, b64(msg))
		if err != nil {
			t.Fatal(err)
		}
		again, _ := vaultSealB64(a.Pub, b64(msg))
		if sealed == again {
			t.Fatal("sealing twice gave the same bytes")
		}
		raw, _ := base64.StdEncoding.DecodeString(sealed)
		if len(msg) > 8 && bytes.Contains(raw, []byte(msg[:8])) {
			t.Fatal("the plain text shows in the sealed bytes")
		}
		opened, err := vaultOpenB64(a.Priv, sealed)
		if err != nil {
			t.Fatal(err)
		}
		if opened != b64(msg) {
			t.Fatalf("round trip of %d bytes came back different", len(msg))
		}
	}
}

func TestVaultWrongKeyRefused(t *testing.T) {
	a, b := mustKeys(t), mustKeys(t)
	sealed, err := vaultSealB64(a.Pub, b64("hidden"))
	if err != nil {
		t.Fatal(err)
	}
	if out, err := vaultOpenB64(b.Priv, sealed); !errors.Is(err, errVaultOpen) || out != "" {
		t.Fatalf("another vault's key opened it: %q %v", out, err)
	}
	raw, _ := base64.StdEncoding.DecodeString(sealed)
	raw[len(raw)-1] ^= 1
	if _, err := vaultOpenB64(a.Priv, base64.StdEncoding.EncodeToString(raw)); err == nil {
		t.Fatal("a changed byte still opened")
	}
	if _, err := vaultOpenB64(a.Priv, sealed[:len(sealed)/2]); err == nil {
		t.Fatal("half of it opened")
	}
	if _, err := vaultOpenB64(a.Priv, "not base64!"); !errors.Is(err, errVaultData) {
		t.Fatalf("bad base64: %v", err)
	}
	if _, err := vaultSealB64(a.Pub, "not base64!"); !errors.Is(err, errVaultData) {
		t.Fatalf("bad base64 sealed: %v", err)
	}
	// a key that will not parse is refused without being quoted back
	for _, bad := range []string{a.Pub, a.Priv[:40], strings.ToLower(a.Priv) + "x", ""} {
		_, err := vaultOpenB64(bad, sealed)
		if !errors.Is(err, errVaultKey) || (bad != "" && strings.Contains(err.Error(), bad)) {
			t.Fatalf("bad private key: %v", err)
		}
	}
	for _, bad := range []string{a.Priv, a.Pub[:20], ""} {
		_, err := vaultSealB64(bad, b64("x"))
		if !errors.Is(err, errVaultKey) || (bad != "" && strings.Contains(err.Error(), bad)) {
			t.Fatalf("bad public key: %v", err)
		}
	}
}

func TestVaultOpenMany(t *testing.T) {
	a, b := mustKeys(t), mustKeys(t)
	seal := func(k vaultKeys, s string) string {
		out, err := vaultSealB64(k.Pub, b64(s))
		if err != nil {
			t.Fatal(err)
		}
		return out
	}
	in, _ := json.Marshal([]string{seal(a, "one"), "!!", seal(b, "two"), seal(a, "three"), "", seal(a, "")})
	out, err := vaultOpenManyJSON(a.Priv, string(in))
	if err != nil {
		t.Fatal(err)
	}
	var got []*string
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatal(err)
	}
	want := []*string{ptr(b64("one")), nil, nil, ptr(b64("three")), nil, ptr("")}
	if len(got) != len(want) {
		t.Fatalf("%d items out for %d in", len(got), len(want))
	}
	for i := range want {
		if (got[i] == nil) != (want[i] == nil) || (got[i] != nil && *got[i] != *want[i]) {
			t.Fatalf("item %d: %s", i, out)
		}
	}
	if out, err := vaultOpenManyJSON(a.Priv, "[]"); err != nil || out != "[]" {
		t.Fatalf("empty list: %q %v", out, err)
	}
	if _, err := vaultOpenManyJSON(a.Priv, "{"); err == nil {
		t.Fatal("a bad list was taken")
	}
	if _, err := vaultOpenManyJSON("x", string(in)); !errors.Is(err, errVaultKey) {
		t.Fatalf("bad key: %v", err)
	}
}

func ptr(s string) *string { return &s }

// sealing, opening and every pin call write nothing to the log, stdout or
// stderr, and leave the engine's identity alone
func TestVaultAndPinLogNothing(t *testing.T) {
	var logged bytes.Buffer
	log.SetOutput(&logged)
	defer log.SetOutput(os.Stderr)
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	stdout, stderr := os.Stdout, os.Stderr
	os.Stdout, os.Stderr = w, w
	mu.Lock()
	before, beforeX := myId, myXPub
	mu.Unlock()

	func() {
		defer func() { os.Stdout, os.Stderr = stdout, stderr }()
		a, b := mustKeys(t), mustKeys(t)
		sealed, _ := vaultSealB64(a.Pub, b64("hidden"))
		vaultOpenB64(a.Priv, sealed)
		vaultOpenB64(b.Priv, sealed)
		vaultOpenB64("AGE-SECRET-KEY-1BAD", sealed)
		vaultSealB64("age1bad", b64("x"))
		list, _ := json.Marshal([]string{sealed, "!!"})
		vaultOpenManyJSON(a.Priv, string(list))

		tb := vaultTable(t)
		pinCheck([]byte("246810"), tb, pinLegacy{})
		pinCheck([]byte("000000"), tb, pinLegacy{})
		pinRewrap([]byte("246810"), []byte("112233"), tb, pinLegacy{}, 3)
		pinRewrap([]byte("000000"), []byte("112233"), tb, pinLegacy{}, 3)
		pinClear(tb, 3)
		var v1 pinTable
		json.Unmarshal([]byte(pinV1Table), &v1)
		v1.upgrade()
	}()
	w.Close()
	printed, _ := io.ReadAll(r)

	mu.Lock()
	after, afterX := myId, myXPub
	mu.Unlock()
	if before != after || beforeX != afterX {
		t.Fatal("a vault or pin call moved the engine's identity")
	}
	if logged.Len() != 0 || len(printed) != 0 {
		t.Fatalf("logged %q, printed %q", logged.String(), printed)
	}
}
