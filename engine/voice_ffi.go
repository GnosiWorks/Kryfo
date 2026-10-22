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
	"net/http"
	"time"

	"github.com/halo/engine/voice"
)

// how a model download dials; tests stand their own in. never a plain
// connection: no tor, no download
var voiceDial = func(name string) (dialFn, error) { return updateDial(name) }

// nil, the system's roots; tests trust their own server
var voiceTLS *tls.Config

// the manifest built in; tests stand a small one in
var voicePinned = voice.Pinned

// one chunk of 1 MiB over a slow circuit, with room to spare
const voiceChunkWait = 60 * time.Second

var voiceJobs voice.Jobs

func voiceJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	return string(b)
}

// a fresh client per download, on a circuit nothing else uses, that
// follows a redirect only where the manifest allows
func voiceClient(m *voice.Manifest) (*http.Client, error) {
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
		Timeout: voiceChunkWait,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) > 3 || !m.RedirectOK(req.URL) {
				return http.ErrUseLastResponse
			}
			return nil
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

// start fetching model id into dir, from base or the pinned host when base
// is "". "ok" when it runs (or already runs), "error: ..." when it could
// not start. progress is polled with HaloVoiceProgress.
//
//export HaloVoiceFetch
func HaloVoiceFetch(cID, cDir, cBase *C.char) *C.char {
	return C.CString(voiceFetch(goStr(cID), goStr(cDir), goStr(cBase)))
}

func voiceFetch(id, dir, base string) string {
	if err := voice.AppDir(dir); err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	pinned, err := voicePinned()
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	m, err := pinned.WithBase(base)
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
	c, err := voiceClient(m)
	if err != nil {
		return fmt.Sprintf("error: tor: %v", err)
	}
	voiceJobs.Start(id, func(ctx context.Context, prog voice.Progress) error {
		defer c.CloseIdleConnections()
		return voice.Fetch(ctx, voice.HTTPGetter(c), m, md, dir, prog)
	})
	return "ok"
}

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
	// a part file is still being written
	if voiceJobs.Running(id) {
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
	if err := voice.Remove(dir, md); err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	voiceJobs.Forget(id)
	return "ok"
}
