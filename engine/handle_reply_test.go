// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/ed25519"
	"io"
	"net/http"
	"strings"
	"testing"
)

// answers with a body of its own
type bodyTrip struct{ body string }

func (b bodyTrip) RoundTrip(r *http.Request) (*http.Response, error) {
	return &http.Response{
		StatusCode: 200,
		Header:     http.Header{},
		Body:       io.NopCloser(strings.NewReader(b.body)),
	}, nil
}

// an answer past the old 4 KiB is read whole; one past the ceiling is cut
// and reads as a bad answer
func TestHandleRepliesTakeAV4Invite(t *testing.T) {
	was := handleHTTP
	defer func() { handleHTTP = was }()
	_, priv, _ := ed25519.GenerateKey(nil)
	mu.Lock()
	key := myEdPriv
	myEdPriv = priv
	mu.Unlock()
	defer func() {
		mu.Lock()
		myEdPriv = key
		mu.Unlock()
	}()
	answer := func(pad int) string {
		return `{"ok":true,"free":true,"invite":"kryfo://share?v=4&i=` + strings.Repeat("A", pad) + `"}`
	}
	use := func(body string) {
		handleHTTP = func() (*http.Client, error) {
			return &http.Client{Transport: bodyTrip{body}}, nil
		}
	}
	use(answer(4200))
	if len(answer(4200)) <= 4096 {
		t.Fatal("the answer is not past the old ceiling")
	}
	if r := handleCheck("wren"); r != "free" {
		t.Fatal(r)
	}
	if r := handleClaim("wren", "kryfo://x", ""); r != "ok" {
		t.Fatal(r)
	}
	use(answer(handleReplyMax))
	if r := handleClaim("wren", "kryfo://x", ""); r != "error: bad answer from the registry" {
		t.Fatal(r)
	}
}
