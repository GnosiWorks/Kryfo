// SPDX-License-Identifier: GPL-3.0-or-later
package agefile

import (
	"bytes"
	"crypto/rand"
	"io"
	"strings"
	"testing"

	"filippo.io/age"
	"filippo.io/age/armor"
)

func lockBytes(t *testing.T, plain []byte, pass string) []byte {
	t.Helper()
	var out bytes.Buffer
	if err := Lock(bytes.NewReader(plain), &out, pass, nil, nil, nil); err != nil {
		t.Fatal(err)
	}
	return out.Bytes()
}

func openBytes(locked []byte, pass string) ([]byte, error) {
	s, err := Begin(bytes.NewReader(locked), pass, nil)
	if err != nil {
		return nil, err
	}
	var out bytes.Buffer
	err = s.Finish(&out, nil, nil)
	return out.Bytes(), err
}

func TestRoundTrip(t *testing.T) {
	plain := make([]byte, 3*64*1024+17)
	rand.Read(plain)
	locked := lockBytes(t, plain, "four plain words here")
	if !bytes.HasPrefix(locked, []byte(intro)) {
		t.Fatal("not an age file")
	}
	if !bytes.Contains(locked[:200], []byte("-> scrypt ")) || !bytes.Contains(locked[:200], []byte(" 18\n")) {
		t.Fatal("not scrypt at work factor 18")
	}
	got, err := openBytes(locked, "four plain words here")
	if err != nil || !bytes.Equal(got, plain) {
		t.Fatalf("round trip: %v", err)
	}
}

func TestOpensFilesFromAge(t *testing.T) {
	r, _ := age.NewScryptRecipient("pw")
	r.SetWorkFactor(12)
	var buf bytes.Buffer
	w, _ := age.Encrypt(&buf, r)
	io.WriteString(w, "from upstream")
	w.Close()
	got, err := openBytes(buf.Bytes(), "pw")
	if err != nil || string(got) != "from upstream" {
		t.Fatalf("%v %q", err, got)
	}

	var arm bytes.Buffer
	aw := armor.NewWriter(&arm)
	aw.Write(buf.Bytes())
	aw.Close()
	got, err = openBytes(arm.Bytes(), "pw")
	if err != nil || string(got) != "from upstream" {
		t.Fatalf("armored: %v %q", err, got)
	}
}

func TestAgeOpensOurFiles(t *testing.T) {
	locked := lockBytes(t, []byte("from kryfo"), "pw")
	id, _ := age.NewScryptIdentity("pw")
	r, err := age.Decrypt(bytes.NewReader(locked), id)
	if err != nil {
		t.Fatal(err)
	}
	got, _ := io.ReadAll(r)
	if string(got) != "from kryfo" {
		t.Fatalf("%q", got)
	}
}

func TestWrongPassword(t *testing.T) {
	locked := lockBytes(t, []byte("secret"), "right")
	if _, err := openBytes(locked, "wrong"); err != ErrWrongPassword {
		t.Fatalf("got %v", err)
	}
	if _, err := openBytes(locked, ""); err != ErrWrongPassword {
		t.Fatalf("empty: got %v", err)
	}
}

func TestLockedToAKey(t *testing.T) {
	id, _ := age.GenerateX25519Identity()
	var buf bytes.Buffer
	w, _ := age.Encrypt(&buf, id.Recipient())
	io.WriteString(w, "for a key")
	w.Close()
	if _, err := openBytes(buf.Bytes(), "anything"); err != ErrLockedToKey {
		t.Fatalf("got %v", err)
	}
}

func TestNotAge(t *testing.T) {
	for _, b := range [][]byte{nil, []byte("%PDF-1.7"), []byte("age-encryption.org/v2\n")} {
		if _, err := openBytes(b, "pw"); err != ErrNotAge {
			t.Fatalf("%q: got %v", b, err)
		}
	}
}

func TestCorrupt(t *testing.T) {
	plain := make([]byte, 200*1024)
	rand.Read(plain)
	locked := lockBytes(t, plain, "pw")

	// a flipped byte in the header's wrapped key or mac
	head := bytes.Clone(locked)
	i := bytes.Index(head, []byte("\n--- "))
	head[i+8] ^= 1
	if _, err := openBytes(head, "pw"); err != ErrCorrupt {
		t.Fatalf("header: got %v", err)
	}

	// a flipped byte deep in the body: the password is right, the file is not
	body := bytes.Clone(locked)
	body[len(body)-100] ^= 1
	s, err := Begin(bytes.NewReader(body), "pw", nil)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	if err := s.Finish(io.Discard, nil, nil); err != ErrCorrupt {
		t.Fatalf("body: got %v", err)
	}

	// cut short
	if _, err := openBytes(locked[:len(locked)-10], "pw"); err != ErrCorrupt {
		t.Fatalf("cut: got %v", err)
	}
	if _, err := openBytes(locked[:30], "pw"); err != ErrCorrupt && err != ErrLockedToKey {
		t.Fatalf("cut header: got %v", err)
	}
}

func TestMemoryIsCheckedBeforeScrypt(t *testing.T) {
	locked := lockBytes(t, []byte("x"), "pw")
	low := func() int64 { return 100 << 20 }
	if _, err := Begin(bytes.NewReader(locked), "pw", low); err != ErrNeedsMemory {
		t.Fatalf("open: got %v", err)
	}
	var out bytes.Buffer
	if err := Lock(strings.NewReader("x"), &out, "pw", nil, nil, low); err != ErrNeedsMemory || out.Len() != 0 {
		t.Fatalf("lock: got %v, wrote %d", err, out.Len())
	}
	// a header that asks for a gigabyte is turned away, not tried
	huge := bytes.Replace(locked, []byte(" 18\n"), []byte(" 20\n"), 1)
	mid := func() int64 { return 600 << 20 }
	if _, err := Begin(bytes.NewReader(huge), "pw", mid); err != ErrNeedsMemory {
		t.Fatalf("huge: got %v", err)
	}
	absurd := bytes.Replace(locked, []byte(" 18\n"), []byte(" 40\n"), 1)
	if _, err := Begin(bytes.NewReader(absurd), "pw", nil); err != ErrNeedsMemory {
		t.Fatalf("absurd: got %v", err)
	}
}

func TestProgressAndCancel(t *testing.T) {
	plain := make([]byte, 1<<20)
	var done int64
	var out bytes.Buffer
	if err := Lock(bytes.NewReader(plain), &out, "pw", &done, nil, nil); err != nil || done != 1<<20 {
		t.Fatalf("%v %d", err, done)
	}
	stop := int32(1)
	if err := Lock(bytes.NewReader(plain), io.Discard, "pw", nil, &stop, nil); err != ErrCancelled {
		t.Fatalf("got %v", err)
	}
	if err := Lock(bytes.NewReader(plain), io.Discard, "", nil, nil, nil); err != ErrEmptyPassword {
		t.Fatalf("got %v", err)
	}
}
