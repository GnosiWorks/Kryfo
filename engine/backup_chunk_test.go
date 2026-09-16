package main

import (
	"bytes"
	"testing"
)

// the record cipher underneath the streamed backup: a record opens only at
// its own index with its own type, and a changed byte fails.
func TestBackupChunkRoundTrip(t *testing.T) {
	gcm, err := backupGCM("00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff")
	if err != nil {
		t.Fatal(err)
	}
	plain := []byte("a slice of a photo")
	ct := gcm.Seal(nil, backupNonce(7), plain, []byte{2})
	got, err := gcm.Open(nil, backupNonce(7), ct, []byte{2})
	if err != nil || !bytes.Equal(got, plain) {
		t.Fatalf("round trip: %v", err)
	}
	if _, err := gcm.Open(nil, backupNonce(8), ct, []byte{2}); err == nil {
		t.Fatal("opened at the wrong index")
	}
	if _, err := gcm.Open(nil, backupNonce(7), ct, []byte{1}); err == nil {
		t.Fatal("opened as the wrong type")
	}
	ct[3] ^= 1
	if _, err := gcm.Open(nil, backupNonce(7), ct, []byte{2}); err == nil {
		t.Fatal("opened after a changed byte")
	}
}

func TestBackupNonceIsBigEndianIndex(t *testing.T) {
	n := backupNonce(0x0102)
	if n[10] != 1 || n[11] != 2 || n[0] != 0 {
		t.Fatalf("nonce %x", n)
	}
}
