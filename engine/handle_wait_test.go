// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/ed25519"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

// answers at once and notes how long the call was given
type deadlineTrip struct{ left []time.Duration }

func (d *deadlineTrip) RoundTrip(r *http.Request) (*http.Response, error) {
	left := time.Duration(0)
	if at, ok := r.Context().Deadline(); ok {
		left = time.Until(at)
	}
	d.left = append(d.left, left)
	return &http.Response{
		StatusCode: 200,
		Header:     http.Header{},
		Body:       io.NopCloser(strings.NewReader(`{"ok":true,"free":true}`)),
	}, nil
}

// a cold circuit takes most of a minute: no registry call gives up before
// the lane client would
func TestHandleCallsWaitForAColdCircuit(t *testing.T) {
	trip := &deadlineTrip{}
	was := handleHTTP
	handleHTTP = func() (*http.Client, error) {
		return &http.Client{Transport: trip, Timeout: 60 * time.Second}, nil
	}
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

	if r := handleCheck("wren"); r != "free" {
		t.Fatal(r)
	}
	if r := handleClaim("wren", "kryfo://x", ""); r != "ok" {
		t.Fatal(r)
	}
	if r := handleRelease("wren"); r != "ok" {
		t.Fatal(r)
	}
	if len(trip.left) != 3 {
		t.Fatal(trip.left)
	}
	for i, left := range trip.left {
		if left < 55*time.Second {
			t.Fatalf("call %d given %s", i, left)
		}
	}
}

// fetching the client can wait on tor's locks. that wait comes out of the
// same bound, so every call answers inside it
func TestHandleCallsAnswerInTimeOnASlowClient(t *testing.T) {
	was, wasWait := handleHTTP, handleWait
	handleHTTP = func() (*http.Client, error) {
		time.Sleep(2 * time.Second)
		return &http.Client{Transport: &deadlineTrip{}}, nil
	}
	handleWait = 200 * time.Millisecond
	defer func() { handleHTTP, handleWait = was, wasWait }()
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

	for name, call := range map[string]func() string{
		"check":   func() string { return handleCheck("wren") },
		"claim":   func() string { return handleClaim("wren", "kryfo://x", "") },
		"release": func() string { return handleRelease("wren") },
	} {
		start := time.Now()
		r := call()
		if !strings.HasPrefix(r, "error") {
			t.Fatalf("%s: %s", name, r)
		}
		if took := time.Since(start); took > time.Second {
			t.Fatalf("%s took %s", name, took)
		}
	}
}
