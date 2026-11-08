// SPDX-License-Identifier: GPL-3.0-or-later
package main

// offline translation's side of the engine: the pinned models and their
// download. the download goes over tor and nothing else, whatever the send
// mode, each one under a socks name of its own so two languages fetched on
// different days do not share a circuit. the models run in a separate
// library (translate/native), not here.

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
)

// how a model download dials; tests stand their own in. never a plain
// connection: no tor, no download
var translateDial = func(name string) (dialFn, error) { return updateDial(name) }

// nil, the system's roots; tests trust their own server
var translateTLS *tls.Config

// how a download gets past a slow or cut circuit. a request ends when no
// byte came for translateStall (a whole-request cap cut every chunk slower
// than 17 kB/s), or after translateChunkMax for its 1 MiB; then it is asked
// again with a backoff, from the byte the part holds, on a fresh circuit
// after two misses. it ends once no chunk came for translateGiveUp.
// translateLanes chunks at a time, each lane on a circuit of its own: one
// onion circuit carries about 0.06-0.55 MiB/s
const (
	translateStall    = 45 * time.Second
	translateChunkMax = 5 * time.Minute
	translateLanes    = 3
)

// tests make the waits short
var (
	translateWait   = translate.Backoff
	translateGiveUp = 10 * time.Minute
)

// whether tor can carry a download now
var translateNetReady = func() bool {
	mu.Lock()
	up := torNode != nil
	mu.Unlock()
	s := torStatusNow()
	return up && (s == "bootstrapped" || s == "publishing" || s == "reachable")
}

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

type bundleInfo struct {
	Lang  string   `json:"lang"`
	Gz    int64    `json:"gz"`
	Disk  int64    `json:"disk"`
	Pairs []string `json:"pairs"`
	Dirs  []string `json:"dirs"`
}

// what can be downloaded: the manifest's host, and each language's bundle
// with its size on the wire, padding included, and on disk
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
	for _, l := range m.Packs() {
		_, disk := m.BundleBytes(l)
		b := bundleInfo{Lang: l, Gz: m.WireBytes(l), Disk: disk}
		for _, p := range m.Bundle(l) {
			b.Pairs = append(b.Pairs, p.From+"-"+p.To)
			b.Dirs = append(b.Dirs, p.Dir())
		}
		out.Langs = append(out.Langs, b)
	}
	return jsonStr(out)
}

// start fetching lang's bundle into dir from the pinned mirror, the only
// host there is. "ok" when it runs (or already ran), "error: ..." when it
// could not start. progress is polled with HaloTranslateProgress.
//
//export HaloTranslateFetch
func HaloTranslateFetch(cLang, cDir *C.char) *C.char {
	return C.CString(translateFetch(goStr(cLang), goStr(cDir)))
}

// the manifest downloads use; tests stand a local host in
var translateManifest = translate.Pinned

func translateFetch(lang, dir string) string {
	if dir == "" {
		return "error: no dir"
	}
	m, err := translateManifest()
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
		return translate.FetchBundleWith(ctx, translateFetcher(c), m, lang, dir, prog)
	})
	return "ok"
}

// the first lane takes first, already dialled; every other lane and every
// fresh circuit gets a client of its own
func translateFetcher(first *http.Client) translate.Fetcher {
	var lmu sync.Mutex
	return translate.Fetcher{
		Lanes:    translateLanes,
		Retry:    true,
		Wait:     translateWait,
		Ready:    translateNetReady,
		GiveUp:   translateGiveUp,
		Stall:    translateStall,
		ChunkMax: translateChunkMax,
		Lane: func() (translate.Getter, func()) {
			lmu.Lock()
			c := first
			first = nil
			lmu.Unlock()
			if c == nil {
				var err error
				if c, err = translateClient(); err != nil {
					return func(context.Context, string, int64, int64) (io.ReadCloser, int64, error) {
						return nil, 0, err
					}, nil
				}
			}
			return translate.HTTPGetter(c), c.CloseIdleConnections
		},
		// the class of each stop, never the host or the language
		Log: func(s translate.Stop) {
			if s.Wait == 0 {
				log.Printf("translate: download stopped (%s) at %d MiB, lane %d, try %d, ended", s.Why, s.At>>20, s.Lane, s.Try)
				return
			}
			log.Printf("translate: download stopped (%s) at %d MiB, lane %d, try %d, again in %v", s.Why, s.At>>20, s.Lane, s.Try, s.Wait.Round(time.Second))
		},
	}
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
