// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !android

package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

// the byte calls give what the file calls write. an ogg stream's serial is
// random, so the two encodes are compared by length and by what they decode to
func TestVoiceBytesMatchFiles(t *testing.T) {
	dir := t.TempDir()
	wav := filepath.Join(dir, "vn_2.wav")
	voiceWav(t, wav, 7)
	in, err := os.ReadFile(wav)
	if err != nil {
		t.Fatal(err)
	}
	ogg := filepath.Join(dir, "vn_2.ogg")
	fileSaid := voiceToOgg(wav, ogg)
	oggFile, _ := os.ReadFile(ogg)
	oggBytes, said := voiceBytesToOgg(in, "k1")
	if said != fileSaid || len(oggBytes) != len(oggFile) {
		t.Fatalf("ogg: bytes said %q (%d), file %q (%d)", said, len(oggBytes), fileSaid, len(oggFile))
	}
	if got, want := voiceBytesPeaks(oggFile, 30), voicePeaks(ogg, 30); got != want {
		t.Fatalf("peaks %s, file %s", got, want)
	}
	back := filepath.Join(dir, "back.wav")
	fileSaid = voiceToWav(ogg, back)
	wavFile, _ := os.ReadFile(back)
	wavBytes, said := voiceBytesToWav(oggFile)
	if said != fileSaid || !bytes.Equal(wavBytes, wavFile) {
		t.Fatalf("wav: bytes said %q (%d), file %q (%d)", said, len(wavBytes), fileSaid, len(wavFile))
	}
	// the byte encode's own ogg plays the same
	again, said := voiceBytesToWav(oggBytes)
	if said != fileSaid || !bytes.Equal(again, wavFile) {
		t.Fatalf("the byte encode decodes to %q (%d)", said, len(again))
	}
}

func TestVoiceBytesSayOneWord(t *testing.T) {
	if b, said := voiceBytesToWav([]byte("not an ogg at all")); b != nil || said != "error: not-opus" {
		t.Fatalf("got %q", said)
	}
	if b, said := voiceBytesToOgg([]byte("RIFF"), "k2"); b != nil || said[:6] != "error:" {
		t.Fatalf("got %q", said)
	}
	if said := voiceBytesPeaks(nil, 10); said[:6] != "error:" {
		t.Fatalf("got %q", said)
	}
}

func TestVoiceBytesStop(t *testing.T) {
	dir := t.TempDir()
	wav := filepath.Join(dir, "vn_3.wav")
	voiceWav(t, wav, 3)
	in, _ := os.ReadFile(wav)
	voiceStopMu.Lock()
	voiceStops["k3"] = true
	voiceStopMu.Unlock()
	if b, said := voiceBytesToOgg(in, "k3"); b != nil || said != "error: stopped" {
		t.Fatalf("got %q", said)
	}
	voiceStopMu.Lock()
	_, left := voiceStops["k3"]
	voiceStopMu.Unlock()
	if left {
		t.Fatal("the stop mark stayed")
	}
}

// a buffer that grows leaves no copy of what it held behind
func TestZeroBufGrowZeroes(t *testing.T) {
	z := zeroBuf{b: make([]byte, 0, 4)}
	z.Write([]byte{1, 2, 3, 4})
	old := z.b[:cap(z.b)]
	z.Write([]byte{5, 6})
	if !bytes.Equal(z.b, []byte{1, 2, 3, 4, 5, 6}) {
		t.Fatalf("held %v", z.b)
	}
	for _, v := range old {
		if v != 0 {
			t.Fatalf("the old array still holds %v", old)
		}
	}
	// room enough: the same array, nothing moved
	same := &z.b[:cap(z.b)][0]
	z.Write([]byte{7})
	if &z.b[0] != same {
		t.Fatal("grew with room to spare")
	}
}
