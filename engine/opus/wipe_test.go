// SPDX-License-Identifier: GPL-3.0-or-later
package opus

import (
	"bufio"
	"bytes"
	"io"
	"testing"
)

func allZero(b []byte) bool { return bytes.Count(b, []byte{0}) == len(b) }

// what a buffered reader or writer held of a note is zeros once wiped
func TestStagingBuffersAreZeroed(t *testing.T) {
	r := bufio.NewReaderSize(bytes.NewReader(bytes.Repeat([]byte{7}, 100)), 64)
	held, _ := r.Peek(64)
	if allZero(held) {
		t.Fatal("nothing read")
	}
	wipeReader(r)
	if !allZero(held) {
		t.Fatal("the reader kept what it read")
	}
	w := bufio.NewWriterSize(io.Discard, 64)
	buf := w.AvailableBuffer()[:64]
	w.Write(bytes.Repeat([]byte{7}, 10))
	w.Flush()
	if allZero(buf[:10]) {
		t.Fatal("nothing written")
	}
	wipeWriter(w)
	if !allZero(buf) {
		t.Fatal("the writer kept what it wrote")
	}
}

// the last packet and the last samples go with the coder
func TestCodersZeroTheirLastWords(t *testing.T) {
	enc, err := NewEncoder(16000, VoiceBitrate, voiceComplexity)
	if err != nil {
		t.Fatal(err)
	}
	pcm := make([]int16, 320)
	for i := range pcm {
		pcm[i] = int16(i * 97)
	}
	p, err := enc.Encode(pcm)
	if err != nil {
		t.Fatal(err)
	}
	packet := bytes.Clone(p)
	enc.Close()
	if !allZero(p) {
		t.Fatal("the encoder kept its last packet")
	}
	dec, err := NewDecoder(16000)
	if err != nil {
		t.Fatal(err)
	}
	s, err := dec.Decode(packet)
	if err != nil {
		t.Fatal(err)
	}
	dec.Close()
	for _, x := range s {
		if x != 0 {
			t.Fatal("the decoder kept its last samples")
		}
	}
}

// a whole encode and decode still round trip with the wipes in place
func TestWipesLeaveTheNoteWhole(t *testing.T) {
	src := make([]int16, 16000)
	for i := range src {
		src[i] = int16((i % 50) * 400)
	}
	ogg, note := encode(t, wavOf(src, 16000, 1))
	got := 0
	if _, err := Decode(bytes.NewReader(ogg), 16000, func(s []int16) error {
		got += len(s)
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if note.Samples != 16000 || got < 16000 {
		t.Fatalf("%d samples in, %d out", note.Samples, got)
	}
}
