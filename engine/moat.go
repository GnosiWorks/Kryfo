// SPDX-License-Identifier: GPL-3.0-or-later
package main

// moat. bridges are only useful if you can get some, and the obvious way -
// visit bridges.torproject.org - is blocked in most of the places that block
// tor. moat is the same bridge database reached over a plain https api, which
// is what tor browser's "request a bridge" button uses.
//
// this deliberately does NOT go through tor. tor being unreachable is the
// entire reason someone is here.
//
// it is not a complete answer: where the moat host itself is blocked you need
// domain fronting, and that is largely dead as a technique. but partial
// censorship is the common case and this covers it.

import "C"

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

const moatBase = "https://bridges.torproject.org"

// bridgedb speaks jsonapi and is picky about the content type.
const moatContentType = "application/vnd.api+json"

type moatItem struct {
	ID        string          `json:"id,omitempty"`
	Type      string          `json:"type"`
	Version   string          `json:"version"`
	Supported []string        `json:"supported,omitempty"`
	Transport json.RawMessage `json:"transport,omitempty"`
	Image     string          `json:"image,omitempty"`
	Challenge string          `json:"challenge,omitempty"`
	Solution  string          `json:"solution,omitempty"`
	QRCode    string          `json:"qrcode,omitempty"`
	Bridges   []string        `json:"bridges,omitempty"`
}

type moatEnvelope struct {
	Data   []moatItem `json:"data"`
	Errors []struct {
		Detail string `json:"detail"`
	} `json:"errors,omitempty"`
}

func moatClip(n int) int {
	if n > 200 {
		return 200
	}
	return n
}

func moatClient() *http.Client {
	return &http.Client{Timeout: 45 * time.Second}
}

func moatPost(path string, body any) (*moatEnvelope, int, error) {
	buf, err := json.Marshal(body)
	if err != nil {
		return nil, 0, err
	}
	req, err := http.NewRequest("POST", moatBase+path, bytes.NewReader(buf))
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("Content-Type", moatContentType)
	req.Header.Set("Accept", moatContentType)
	resp, err := moatClient().Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return nil, resp.StatusCode, err
	}
	var env moatEnvelope
	if uerr := json.Unmarshal(raw, &env); uerr != nil {
		// log the body for us, tell the user something they can act on
		log.Printf("moat: could not parse reply: %v / %s", uerr,
			strings.TrimSpace(string(raw[:moatClip(len(raw))])))
		return nil, resp.StatusCode, fmt.Errorf("the bridge service replied in a way kryfo did not understand")
	}
	return &env, resp.StatusCode, nil
}

// ask for a captcha. returns "ok|<base64 png>|<challenge>" or "error: ...".
// the challenge is opaque and must be handed back with the answer; it carries
// a signed timestamp and dies after thirty minutes.
//
//export HaloMoatFetch
func HaloMoatFetch() *C.char {
	env, code, err := moatPost("/moat/fetch", map[string]any{
		"data": []moatItem{{
			Version:   "0.1.0",
			Type:      "client-transports",
			Supported: []string{"obfs4"},
		}},
	})
	if err != nil {
		log.Printf("moat: fetch failed: %v", err)
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	if len(env.Errors) > 0 {
		log.Printf("moat: fetch error: %s", env.Errors[0].Detail)
		return C.CString("error: " + env.Errors[0].Detail)
	}
	if code != 200 || len(env.Data) == 0 {
		log.Printf("moat: fetch returned %d", code)
		return C.CString(fmt.Sprintf("error: moat returned %d", code))
	}
	d := env.Data[0]
	if d.Image == "" || d.Challenge == "" {
		return C.CString("error: no captcha in response")
	}
	log.Printf("moat: got captcha, %d bytes of image", len(d.Image))
	return C.CString("ok|" + d.Image + "|" + d.Challenge)
}

// send the answer back. returns "ok|<bridge lines separated by newline>",
// "wrong" if the captcha was not solved, or "error: ...".
//
//export HaloMoatSolve
func HaloMoatSolve(cChallenge, cSolution *C.char) *C.char {
	challenge := C.GoString(cChallenge)
	solution := strings.TrimSpace(C.GoString(cSolution))
	if challenge == "" || solution == "" {
		return C.CString("error: missing challenge or answer")
	}

	env, code, err := moatPost("/moat/check", map[string]any{
		"data": []moatItem{{
			ID:        "2",
			Type:      "moat-solution",
			Version:   "0.1.0",
			Transport: json.RawMessage(`"obfs4"`),
			Challenge: challenge,
			Solution:  solution,
			QRCode:    "false",
		}},
	})
	// bridgedb answers a wrong or expired captcha with 419, which is a real
	// outcome rather than a failure - the ui should just ask again.
	if code == 419 {
		log.Println("moat: captcha rejected or expired")
		return C.CString("wrong")
	}
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	if len(env.Errors) > 0 {
		return C.CString("error: " + env.Errors[0].Detail)
	}
	if code != 200 || len(env.Data) == 0 {
		return C.CString(fmt.Sprintf("error: moat returned %d", code))
	}

	var good []string
	for _, b := range env.Data[0].Bridges {
		b = strings.TrimSpace(b)
		if b == "" {
			continue
		}
		// bridgedb sometimes omits the leading transport name
		if !strings.HasPrefix(strings.ToLower(b), "obfs4 ") {
			b = "obfs4 " + b
		}
		if validBridgeLine(b) {
			good = append(good, b)
		}
	}
	if len(good) == 0 {
		log.Printf("moat: reply had %d bridges, none usable", len(env.Data[0].Bridges))
		return C.CString("error: no usable bridges in the reply")
	}
	log.Printf("moat: got %d usable bridges", len(good))
	return C.CString("ok|" + strings.Join(good, "\n"))
}
