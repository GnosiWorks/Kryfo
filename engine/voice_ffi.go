// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the speech models for voice note transcripts: what may be downloaded and
// the download. it goes over tor and nothing else, whatever the send mode,
// each one under a socks name of its own. the files land in the app's own
// storage, checked against the pins built in. the model runs in
// libkryfo_voice, never here. when offline translation lands, its pack
// download and this one become one.

import "C"

import (
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/halo/engine/translate"
	"github.com/halo/engine/voice"
)

// how a model download dials; tests stand their own in. never a plain
// connection: no tor, no download
var voiceDial = func(name string) (dialFn, error) { return updateDial(name) }

// nil, the system's roots; tests trust their own server
var voiceTLS *tls.Config

// the manifest built in; tests stand a small one in
var voicePinned = voice.Pinned

// how a model download gets past a slow or cut circuit: as translation's
// packs do (translateStall, translateChunkMax), over voiceLanes circuits.
// a whole-request cap cut every chunk slower than 17 kB/s
const voiceLanes = 3

// tests make the waits short and stand in a network
var (
	voiceWait     = translate.Backoff
	voiceGiveUp   = 10 * time.Minute
	voiceNetReady = func() bool { return translateNetReady() }
)

var voiceJobs voice.Jobs

func voiceJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	return string(b)
}

// a fresh client per download, on a circuit nothing else uses. the mirror
// serves the files itself, so a redirect is never followed
func voiceClient() (*http.Client, error) {
	b := make([]byte, 16)
	rand.Read(b)
	dial, err := voiceDial(hex.EncodeToString(b))
	if err != nil {
		return nil, err
	}
	return &http.Client{
		Transport: &http.Transport{
			DialContext:           dial,
			TLSClientConfig:       voiceTLS,
			TLSHandshakeTimeout:   20 * time.Second,
			ResponseHeaderTimeout: 30 * time.Second,
		},
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}, nil
}

type voiceModelInfo struct {
	ID   string `json:"id"`
	File string `json:"file"`
	Size int64  `json:"size"`
}

// the models that can be downloaded, with their size
//
//export HaloVoiceModels
func HaloVoiceModels() *C.char { return C.CString(voiceModels()) }

func voiceModels() string {
	m, err := voicePinned()
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	out := struct {
		Base   string           `json:"base"`
		Models []voiceModelInfo `json:"models"`
	}{Base: m.Base}
	for _, md := range m.Models {
		out.Models = append(out.Models, voiceModelInfo{md.ID, md.File, md.Size})
	}
	return voiceJSON(out)
}

// start fetching model id into dir from the mirror the app pins; no
// caller picks the host. "ok" when it runs (or already runs), "error: ..."
// when it could not start. a download just stopped is waited for first,
// so the call can block until it lets go. progress is polled with
// HaloVoiceProgress.
//
//export HaloVoiceFetch
func HaloVoiceFetch(cID, cDir *C.char) *C.char {
	return C.CString(voiceFetch(goStr(cID), goStr(cDir)))
}

func voiceFetch(id, dir string) string {
	// a decoy session downloads nothing, nor does one the app has not
	// named yet
	if !decoyClosed() {
		return "error: decoy"
	}
	if err := voice.AppDir(dir); err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	m, err := voicePinned()
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	md, ok := m.Model(id)
	if !ok {
		return "error: no model " + id
	}
	if voiceJobs.Running(id) {
		return "ok"
	}
	c, err := voiceClient()
	if err != nil {
		return fmt.Sprintf("error: tor: %v", err)
	}
	voiceJobs.Start(id, func(ctx context.Context, prog voice.Progress) error {
		return voice.FetchWith(ctx, voiceFetcher(c), m, md, dir, prog)
	})
	// a decoy that opened while this started missed the job
	if !decoyClosed() {
		voiceJobs.Cancel(id)
		return "error: decoy"
	}
	return "ok"
}

// a decoy opening stops every model download. setDecoy runs on the app's
// thread, so this does not wait for them
func stopVoiceDownloads() { voiceJobs.StopAll() }

//export HaloVoiceProgress
func HaloVoiceProgress(cID *C.char) *C.char {
	return C.CString(voiceJSON(voiceJobs.Status(goStr(cID))))
}

// stop id's download; what it fetched stays for the next start
//
//export HaloVoiceCancel
func HaloVoiceCancel(cID *C.char) *C.char {
	voiceJobs.Cancel(goStr(cID))
	return C.CString("ok")
}

// "yes" when id is in dir and matches its pin, "no" otherwise. a file
// that does not match is deleted. reads every byte, so the app asks off
// the ui thread
//
//export HaloVoiceCheck
func HaloVoiceCheck(cID, cDir *C.char) *C.char {
	return C.CString(voiceCheck(goStr(cID), goStr(cDir)))
}

func voiceCheck(id, dir string) string {
	if err := voice.AppDir(dir); err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	m, err := voicePinned()
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	md, ok := m.Model(id)
	if !ok {
		return "error: no model " + id
	}
	// a part file is still being written, or a stopped download has not
	// let go of it yet
	if voiceJobs.Busy(id) {
		return "no"
	}
	if voice.Check(dir, md) != nil {
		return "no"
	}
	return "yes"
}

// id's model off the phone, a part file too. transcripts already made stay
//
//export HaloVoiceRemove
func HaloVoiceRemove(cID, cDir *C.char) *C.char {
	return C.CString(voiceRemove(goStr(cID), goStr(cDir)))
}

func voiceRemove(id, dir string) string {
	m, err := voicePinned()
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	md, ok := m.Model(id)
	if !ok {
		return "error: no model " + id
	}
	if voiceJobs.Running(id) {
		return "error: downloading"
	}
	// a stopped download may still be writing its part file
	voiceJobs.Wait(id)
	if err := voice.Remove(dir, md); err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	voiceJobs.Forget(id)
	return "ok"
}

// the first lane takes first, already dialled; every other lane and every
// fresh circuit gets a client of its own
func voiceFetcher(first *http.Client) translate.Fetcher {
	var lmu sync.Mutex
	return translate.Fetcher{
		Lanes:    voiceLanes,
		Retry:    true,
		Wait:     voiceWait,
		Ready:    voiceNetReady,
		GiveUp:   voiceGiveUp,
		Stall:    translateStall,
		ChunkMax: translateChunkMax,
		Lane: func() (translate.Getter, func()) {
			lmu.Lock()
			c := first
			first = nil
			lmu.Unlock()
			if c == nil {
				var err error
				if c, err = voiceClient(); err != nil {
					return func(context.Context, string, int64, int64) (io.ReadCloser, int64, error) {
						return nil, 0, err
					}, nil
				}
			}
			return translate.HTTPGetter(c), c.CloseIdleConnections
		},
		// the class of each stop, never the host or the model
		Log: func(s translate.Stop) {
			if s.Wait == 0 {
				log.Printf("voice: download stopped (%s) at %d MiB, lane %d, try %d, ended", s.Why, s.At>>20, s.Lane, s.Try)
				return
			}
			log.Printf("voice: download stopped (%s) at %d MiB, lane %d, try %d, again in %v", s.Why, s.At>>20, s.Lane, s.Try, s.Wait.Round(time.Second))
		},
	}
}
