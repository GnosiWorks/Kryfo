// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// a 16 khz mono wav of a tone that comes and goes
func voiceWav(t *testing.T, path string, secs int) {
	t.Helper()
	n := secs * 16000
	b := make([]byte, 44+2*n)
	copy(b, "RIFF")
	binary.LittleEndian.PutUint32(b[4:], uint32(36+2*n))
	copy(b[8:], "WAVEfmt ")
	binary.LittleEndian.PutUint32(b[16:], 16)
	binary.LittleEndian.PutUint16(b[20:], 1)
	binary.LittleEndian.PutUint16(b[22:], 1)
	binary.LittleEndian.PutUint32(b[24:], 16000)
	binary.LittleEndian.PutUint32(b[28:], 32000)
	binary.LittleEndian.PutUint16(b[32:], 2)
	binary.LittleEndian.PutUint16(b[34:], 16)
	copy(b[36:], "data")
	binary.LittleEndian.PutUint32(b[40:], uint32(2*n))
	for i := range n {
		env := math.Abs(math.Sin(math.Pi * float64(i) / 16000))
		v := 9000 * env * math.Sin(2*math.Pi*220*float64(i)/16000)
		binary.LittleEndian.PutUint16(b[44+2*i:], uint16(int16(v)))
	}
	if err := os.WriteFile(path, b, 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestVoiceExportsRoundTrip(t *testing.T) {
	dir := t.TempDir()
	wav := filepath.Join(dir, "vn_1.wav")
	voiceWav(t, wav, 42)
	ogg := filepath.Join(dir, "vn_1.ogg")
	got := voiceToOgg(wav, ogg)
	var ms, size int
	if _, err := fmt.Sscanf(got, "ok %d %d", &ms, &size); err != nil || ms != 42000 {
		t.Fatalf("encode said %q", got)
	}
	st, err := os.Stat(ogg)
	if err != nil || st.Size() != int64(size) || size > 160*1024 {
		t.Fatalf("ogg of %d bytes, said %d", st.Size(), size)
	}
	var w struct {
		Ms int       `json:"ms"`
		P  []float64 `json:"p"`
	}
	if err := json.Unmarshal([]byte(voicePeaks(ogg, 30)), &w); err != nil {
		t.Fatal(err)
	}
	if w.Ms != 42000 || len(w.P) != 30 {
		t.Fatalf("peaks %+v", w)
	}
	back := filepath.Join(dir, "back.wav")
	if got := voiceToWav(ogg, back); got != "ok 42000" {
		t.Fatalf("decode said %q", got)
	}
	if st, _ := os.Stat(back); st.Size() != 44+42*32000 {
		t.Fatalf("wav back of %d bytes", st.Size())
	}
}

func TestVoiceExportsSayOneWord(t *testing.T) {
	dir := t.TempDir()
	junk := filepath.Join(dir, "junk")
	os.WriteFile(junk, []byte("not audio"), 0o600)
	for _, c := range [][2]string{
		{voiceToOgg(filepath.Join(dir, "none.wav"), filepath.Join(dir, "a.ogg")), "error: gone"},
		{voiceToOgg(junk, filepath.Join(dir, "b.ogg")), "error: not-wav"},
		{voiceToWav(junk, filepath.Join(dir, "c.wav")), "error: not-opus"},
		{voicePeaks(junk, 30), "error: not-opus"},
	} {
		got, want := c[0], c[1]
		if got != want {
			t.Errorf("%q, want %q", got, want)
		}
		if strings.Contains(got, dir) {
			t.Errorf("%q names a path", got)
		}
	}
}
