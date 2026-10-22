// SPDX-License-Identifier: GPL-3.0-or-later
package main

// offline translation's side of the engine: the language guess, the pinned
// models, and their download. the download goes over tor and nothing else,
// whatever the send mode, each one under a socks name of its own so two
// languages fetched on different days do not share a circuit. the models
// themselves run in a separate library (translate/native), not here.

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

	"github.com/halo/engine/translate"
)

// how a model download dials; tests stand their own in. never a plain
// connection: no tor, no download
var translateDial = func(name string) (dialFn, error) { return updateDial(name) }

// nil, the system's roots; tests trust their own server
var translateTLS *tls.Config

// one chunk of 1 MiB over a slow circuit, with room to spare
const translateChunkWait = 60 * time.Second

var translateJobs translate.Jobs

// a fresh client per download, on a circuit nothing else uses
func translateClient() (*http.Client, error) {
	b := make([]byte, 16)
	rand.Read(b)
	dial, err := translateDial("translate:" + hex.EncodeToString(b))
	if err != nil {
		return nil, err
	}
	return &http.Client{
		Transport: &http.Transport{
			DialContext:           dial,
			TLSClientConfig:       translateTLS,
			TLSHandshakeTimeout:   20 * time.Second,
			ResponseHeaderTimeout: 30 * time.Second,
		},
		Timeout: translateChunkWait,
		// the files are where the manifest says: a redirect is not followed
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}, nil
}

func jsonStr(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	return string(b)
}

// the script-based guess for one message: {"lang":"zh","share":0.9}, with
// lang "" when there is no guess
//
//export HaloTranslateDetect
func HaloTranslateDetect(cText *C.char) *C.char {
	return C.CString(translateDetect(goStr(cText)))
}

func translateDetect(s string) string {
	g := translate.Detect(s)
	return jsonStr(map[string]any{"lang": g.Lang, "share": g.Share})
}

type bundleInfo struct {
	Lang  string   `json:"lang"`
	Gz    int64    `json:"gz"`
	Disk  int64    `json:"disk"`
	Pairs []string `json:"pairs"`
	Dirs  []string `json:"dirs"`
}

// what can be downloaded: the manifest's host, and each language's bundle
// with its size on the wire and on disk
//
//export HaloTranslateCatalog
func HaloTranslateCatalog() *C.char { return C.CString(translateCatalog()) }

func translateCatalog() string {
	m, err := translate.Pinned()
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	out := struct {
		Base  string       `json:"base"`
		Langs []bundleInfo `json:"langs"`
	}{Base: m.Base}
	for _, l := range m.Langs() {
		gz, disk := m.BundleBytes(l)
		b := bundleInfo{Lang: l, Gz: gz, Disk: disk}
		for _, p := range m.Bundle(l) {
			b.Pairs = append(b.Pairs, p.From+"-"+p.To)
			b.Dirs = append(b.Dirs, p.Dir())
		}
		out.Langs = append(out.Langs, b)
	}
	return jsonStr(out)
}

// start fetching lang's bundle into dir, from base or the manifest's own
// host when base is "". "ok" when it runs (or already ran), "error: ..."
// when it could not start. progress is polled with HaloTranslateProgress.
//
//export HaloTranslateFetch
func HaloTranslateFetch(cLang, cDir, cBase *C.char) *C.char {
	return C.CString(translateFetch(goStr(cLang), goStr(cDir), goStr(cBase)))
}

func translateFetch(lang, dir, base string) string {
	if dir == "" {
		return "error: no dir"
	}
	pinned, err := translate.Pinned()
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	m, err := pinned.WithBase(base)
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	if len(m.Bundle(lang)) == 0 {
		return "error: no models for " + lang
	}
	c, err := translateClient()
	if err != nil {
		return fmt.Sprintf("error: tor: %v", err)
	}
	translateJobs.Start(lang, func(ctx context.Context, prog translate.Progress) error {
		defer c.CloseIdleConnections()
		return translate.FetchBundle(ctx, translate.HTTPGetter(c), m, lang, dir, prog)
	})
	return "ok"
}

//export HaloTranslateProgress
func HaloTranslateProgress(cLang *C.char) *C.char {
	return C.CString(jsonStr(translateJobs.Status(goStr(cLang))))
}

// stop lang's download; what it fetched stays for the next start
//
//export HaloTranslateCancel
func HaloTranslateCancel(cLang *C.char) *C.char {
	translateJobs.Cancel(goStr(cLang))
	return C.CString("ok")
}

// whether lang's bundle is in dir and every file matches its pin. reads
// every byte, so the app asks off the ui thread
//
//export HaloTranslateInstalled
func HaloTranslateInstalled(cLang, cDir *C.char) *C.char {
	m, err := translate.Pinned()
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	if translate.BundleInstalled(m, goStr(cLang), goStr(cDir)) {
		return C.CString("yes")
	}
	return C.CString("no")
}

// lang's bundle off the phone, part files too
//
//export HaloTranslateRemove
func HaloTranslateRemove(cLang, cDir *C.char) *C.char {
	lang := goStr(cLang)
	m, err := translate.Pinned()
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	if translateJobs.Status(lang).State == translate.StateRunning {
		return C.CString("error: downloading")
	}
	if err := translate.RemoveBundle(m, lang, goStr(cDir)); err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	translateJobs.Forget(lang)
	return C.CString("ok")
}

// the bergamot config for one direction whose files are in dir, for the
// translation library to open
//
//export HaloTranslateConfig
func HaloTranslateConfig(cFrom, cTo, cDir *C.char) *C.char {
	m, err := translate.Pinned()
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	p, ok := m.Pair(goStr(cFrom), goStr(cTo))
	if !ok {
		return C.CString("error: no such pair")
	}
	return C.CString(p.Config(goStr(cDir) + "/" + p.Dir()))
}
