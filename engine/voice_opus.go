// SPDX-License-Identifier: GPL-3.0-or-later
package main

// voice notes in opus (./opus): the wav the mic made, encoded as it goes
// out, and an ogg that came, decoded for its wave and for transcripts. the
// paths are the app's own files; each call is one file, start to end

import "C"

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"math"
	"sync"

	"github.com/halo/engine/opus"
)

// what the app reads of an error: one word, never a path
func voiceWord(err error) string {
	switch {
	case errors.Is(err, opus.ErrNotWav):
		return "error: not-wav"
	case errors.Is(err, opus.ErrRate):
		return "error: rate"
	case errors.Is(err, opus.ErrNotOpus):
		return "error: not-opus"
	case errors.Is(err, opus.ErrEmpty):
		return "error: empty"
	case errors.Is(err, opus.ErrLong):
		return "error: long"
	case errors.Is(err, opus.ErrStopped):
		return "error: stopped"
	case errors.Is(err, fs.ErrNotExist):
		return "error: gone"
	}
	return "error: io"
}

// the encodes asked to stop, by the path they write. a stop may come
// before its encode starts; paths are a message's own, never reused
var (
	voiceStopMu sync.Mutex
	voiceStops  = map[string]bool{}
)

func voiceStopped(out string) bool {
	voiceStopMu.Lock()
	defer voiceStopMu.Unlock()
	return voiceStops[out]
}

// what a crafted file might still make go wrong in here answers as an
// error, never takes the app down
func voiceSafe(ret *string) {
	if p := recover(); p != nil {
		log.Printf("voice: panicked: %v", p)
		*ret = "error: io"
	}
}

// "ok <ms> <bytes>" once the wav at [in] is ogg opus at [out]
func voiceToOgg(in, out string) (ret string) {
	defer voiceSafe(&ret)
	defer func() {
		voiceStopMu.Lock()
		delete(voiceStops, out)
		voiceStopMu.Unlock()
	}()
	n, err := opus.EncodeFile(in, out, func() bool { return voiceStopped(out) })
	if err != nil {
		return voiceWord(err)
	}
	return fmt.Sprintf("ok %d %d", n.Ms(), n.Bytes)
}

// "ok <ms>" once the ogg opus at [in] is a 16 khz wav at [out]
func voiceToWav(in, out string) (ret string) {
	defer voiceSafe(&ret)
	n, err := opus.DecodeFile(in, out)
	if err != nil {
		return voiceWord(err)
	}
	return fmt.Sprintf("ok %d", n.Ms())
}

// {"ms":..,"p":[..]}: how long the ogg opus at [path] plays and its wave
func voicePeaks(path string, bars int) (ret string) {
	defer voiceSafe(&ret)
	p, n, err := opus.PeaksFile(path, bars)
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

// HaloVoiceOgg writes the 16-bit pcm wav at inPath to outPath as ogg opus
// at 24 kbit/s. nothing is left at outPath when it fails
//
//export HaloVoiceOgg
func HaloVoiceOgg(inPath, outPath *C.char) *C.char {
	return C.CString(voiceToOgg(goStr(inPath), goStr(outPath)))
}

// HaloVoiceWav writes the ogg opus at inPath to outPath as 16 khz wav
//
//export HaloVoiceWav
func HaloVoiceWav(inPath, outPath *C.char) *C.char {
	return C.CString(voiceToWav(goStr(inPath), goStr(outPath)))
}

// HaloVoicePeaks is the length and the wave, in bars steps, of the ogg
// opus at path
//
//export HaloVoicePeaks
func HaloVoicePeaks(path *C.char, bars C.int) *C.char {
	return C.CString(voicePeaks(goStr(path), int(bars)))
}

// HaloVoiceStop stops the encode writing outPath, now or as it starts
//
//export HaloVoiceStop
func HaloVoiceStop(outPath *C.char) {
	out := goStr(outPath)
	voiceStopMu.Lock()
	voiceStops[out] = true
	voiceStopMu.Unlock()
}
