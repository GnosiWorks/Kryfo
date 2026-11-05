// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !android

// the voice calls of voice_opus.go on bytes in memory, for a desktop whose
// files are sealed and that has no anonymous file to hand out by path.
// what comes back is C memory the caller copies and gives to HaloFreeBytes,
// which zeroes it
package main

/*
#include <stdlib.h>
#include <string.h>
*/
import "C"

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math"
	"unsafe"

	"github.com/halo/engine/opus"
)

// the caller's bytes, read in place for the length of the call
func inBytes(p *C.uchar, n C.longlong) []byte {
	if p == nil || n <= 0 {
		return nil
	}
	return unsafe.Slice((*byte)(unsafe.Pointer(p)), int(n))
}

// b copied into C memory at *out, then zeroed in go
func outBytes(b []byte, out **C.uchar, outLen *C.longlong) {
	m := C.malloc(C.size_t(max(len(b), 1)))
	copy(unsafe.Slice((*byte)(m), len(b)), b)
	clear(b)
	*out = (*C.uchar)(m)
	*outLen = C.longlong(len(b))
}

// "ok <ms> <bytes>" once the wav bytes are ogg opus
func voiceBytesToOgg(in []byte, stopKey string) (ogg []byte, ret string) {
	defer voiceSafe(&ret)
	defer func() {
		voiceStopMu.Lock()
		delete(voiceStops, stopKey)
		voiceStopMu.Unlock()
	}()
	var w bytes.Buffer
	n, err := opus.EncodeWavStop(bytes.NewReader(in), &w, func() bool { return voiceStopped(stopKey) })
	if err != nil {
		clear(w.Bytes())
		return nil, voiceWord(err)
	}
	return w.Bytes(), fmt.Sprintf("ok %d %d", n.Ms(), n.Bytes)
}

// "ok <ms>" once the ogg opus bytes are a 16 khz wav
func voiceBytesToWav(in []byte) (wav []byte, ret string) {
	defer voiceSafe(&ret)
	pcm := make([]byte, 44, 44+len(in)*8)
	note, err := opus.Decode(bytes.NewReader(in), opus.DecodeRate, func(s []int16) error {
		for _, v := range s {
			pcm = binary.LittleEndian.AppendUint16(pcm, uint16(v))
		}
		return nil
	})
	if err != nil {
		clear(pcm)
		return nil, voiceWord(err)
	}
	// the decoder may give more than the note holds, as DecodeFile cuts
	if size := 44 + note.Samples*2; size < len(pcm) {
		clear(pcm[size:])
		pcm = pcm[:size]
	}
	copy(pcm, opus.WavHead(opus.DecodeRate, (len(pcm)-44)/2))
	return pcm, fmt.Sprintf("ok %d", note.Ms())
}

// {"ms":..,"p":[..]} of the ogg opus bytes
func voiceBytesPeaks(in []byte, bars int) (ret string) {
	defer voiceSafe(&ret)
	p, n, err := opus.Peaks(bytes.NewReader(in), bars)
	if err != nil {
		return voiceWord(err)
	}
	for i, v := range p {
		p[i] = math.Round(v*1000) / 1000
	}
	b, err := json.Marshal(struct {
		Ms    int       `json:"ms"`
		Peaks []float64 `json:"p"`
	}{n.Ms(), p})
	if err != nil {
		return "error: io"
	}
	return string(b)
}

// HaloVoiceOggBytes is HaloVoiceOgg on bytes: the 16-bit pcm wav at in
// becomes ogg opus at *out. HaloVoiceStop with stopKey stops it. *out is
// set only on "ok"
//
//export HaloVoiceOggBytes
func HaloVoiceOggBytes(stopKey *C.char, in *C.uchar, inLen C.longlong, out **C.uchar, outLen *C.longlong) *C.char {
	*out, *outLen = nil, 0
	b, ret := voiceBytesToOgg(inBytes(in, inLen), goStr(stopKey))
	if b != nil {
		outBytes(b, out, outLen)
	}
	return C.CString(ret)
}

// HaloVoiceWavBytes is HaloVoiceWav on bytes. *out is set only on "ok"
//
//export HaloVoiceWavBytes
func HaloVoiceWavBytes(in *C.uchar, inLen C.longlong, out **C.uchar, outLen *C.longlong) *C.char {
	*out, *outLen = nil, 0
	b, ret := voiceBytesToWav(inBytes(in, inLen))
	if b != nil {
		outBytes(b, out, outLen)
	}
	return C.CString(ret)
}

// HaloVoicePeaksBytes is HaloVoicePeaks on bytes
//
//export HaloVoicePeaksBytes
func HaloVoicePeaksBytes(in *C.uchar, inLen C.longlong, bars C.int) *C.char {
	return C.CString(voiceBytesPeaks(inBytes(in, inLen), int(bars)))
}

// HaloFreeBytes zeroes n bytes at p and frees them
//
//export HaloFreeBytes
func HaloFreeBytes(p *C.uchar, n C.longlong) {
	if p == nil {
		return
	}
	if n > 0 {
		C.memset(unsafe.Pointer(p), 0, C.size_t(n))
	}
	C.free(unsafe.Pointer(p))
}
