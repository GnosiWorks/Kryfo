// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/ecdh"
	"crypto/rand"
	"encoding/binary"
	"encoding/hex"
	"os"
	"path/filepath"
	"testing"

	"github.com/halo/engine/devices"
)

// a history record is a backup record: the backup's own cipher opens it
// under the stream's record key, at its index, with its type
func TestHistoryRecordsOpenAsBackupRecords(t *testing.T) {
	p, _ := ecdh.X25519().GenerateKey(rand.Reader)
	var id devices.Key
	id[0] = 5
	copy(id[1:], p.PublicKey().Bytes())
	key, _ := devices.NewStreamKey()
	var bind [32]byte
	rand.Read(bind[:])
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "a.jpg"), make([]byte, 3000), 0o600)
	s, err := devices.NewSender(key, bind, id, devices.SendOptions{Spool: filepath.Join(dir, "spool"), Root: dir, Chunk: devices.MinChunk})
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	s.Chat([]byte(`{"halo_id":"a"}`))
	s.Message([]byte(`{"plaintext":"hi"}`))
	s.Media(0, 1, "a.jpg")
	if err := s.Plan(); err != nil {
		t.Fatal(err)
	}
	rk, _ := devices.RecordKey(key, bind, s.ID())
	gcm, err := backupGCM(hex.EncodeToString(rk))
	if err != nil {
		t.Fatal(err)
	}
	h, _ := s.Head()
	for i := uint64(0); i < h.Records; i++ {
		rec, _ := s.Record(i)
		typ := rec[0]
		if typ < 1 || typ > 3 || int(binary.BigEndian.Uint32(rec[1:])) != len(rec)-5 {
			t.Fatalf("record %d is not framed as a backup record", i)
		}
		if _, err := gcm.Open(nil, backupNonce(i), rec[5:], []byte{typ}); err != nil {
			t.Fatalf("record %d does not open as a backup record", i)
		}
	}
}
