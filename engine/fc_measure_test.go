// SPDX-License-Identifier: GPL-3.0-or-later
package main

// how long a first contact takes after a scan, over the real tor and the
// app's private relays, in two processes: one shows its card (listens on
// its first-contact address, its onion up), the other scans it and writes
// at once on both ways the app does (the hello lane to the first-contact
// address, and the card's onion), then waits for the answer the same two
// ways. slow and on the network, so only on request:
//
//	FC_DIR=<a folder> FC_ROLE=card go test -run TestMeasureFirstContact -v -timeout 15m . &
//	FC_DIR=<the same folder> FC_ROLE=scan go test -run TestMeasureFirstContact -v -timeout 15m .
//
// FC_COLD=1: the scan comes as its tor starts (the app opened to scan)
// rather than once its route is proven. FC_WARM=1: the scanner's hello
// lane is warmed while it looks at the card (the scan screen open), as
// HaloNostrWarmHello does. FC_LOG: a file for the engine log.

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"golang.org/x/crypto/curve25519"
)

type fcCard struct {
	X, Fc, Onion string
}

func fcWriteJSON(t *testing.T, p string, v any) {
	b, _ := json.Marshal(v)
	if err := os.WriteFile(p+".tmp", b, 0o600); err != nil {
		t.Fatal(err)
	}
	os.Rename(p+".tmp", p)
}

func fcReadJSON(p string, v any) bool {
	b, err := os.ReadFile(p)
	return err == nil && json.Unmarshal(b, v) == nil
}

// a line on the relays' inbox or the onion's that holds mark
func fcHeard(mark string) (relay, onion bool) {
	nostrMu.Lock()
	for _, l := range nostrInbox {
		if strings.Contains(l, mark) {
			relay = true
		}
	}
	nostrMu.Unlock()
	mu.Lock()
	for _, l := range inbox {
		if strings.Contains(l, mark) {
			onion = true
		}
	}
	mu.Unlock()
	return
}

func TestMeasureFirstContact(t *testing.T) {
	dir, role := os.Getenv("FC_DIR"), os.Getenv("FC_ROLE")
	if dir == "" || (role != "card" && role != "scan") {
		t.Skip("FC_DIR and FC_ROLE not set")
	}
	var logTo io.Writer = io.Discard
	if p := os.Getenv("FC_LOG"); p != "" {
		if f, err := os.Create(p); err == nil {
			defer f.Close()
			logTo = f
		}
	}
	log.SetFlags(log.Ltime | log.Lmicroseconds)
	log.SetOutput(logTo)
	defer log.SetOutput(os.Stderr)
	transportMode.Store(modePrivate)
	oldSpread, oldKick := subSpread, kickSpread
	subSpread, kickSpread = time.Minute, time.Minute
	defer func() { subSpread, kickSpread = oldSpread, oldKick }()

	data, err := os.MkdirTemp("", "halo-fc-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(data)
	// a warm tor, as a phone or a computer has after its first start
	cache := filepath.Join(dir, "torcache-"+role)
	cached := []string{"cached-certs", "cached-microdesc-consensus", "cached-microdescs", "cached-microdescs.new", "state"}
	os.MkdirAll(filepath.Join(data, "tor"), 0o700)
	for _, f := range cached {
		if b, err := os.ReadFile(filepath.Join(cache, f)); err == nil {
			os.WriteFile(filepath.Join(data, "tor", f), b, 0o600)
		}
	}
	keepCache := func() {
		os.MkdirAll(cache, 0o700)
		for _, f := range cached {
			if b, err := os.ReadFile(filepath.Join(data, "tor", f)); err == nil {
				os.WriteFile(filepath.Join(cache, f), b, 0o600)
			}
		}
	}

	var priv, pub [32]byte
	rand.Read(priv[:])
	curve25519.ScalarBaseMult(&pub, &priv)
	mu.Lock()
	setMainForTest(priv, pub)
	mu.Unlock()
	relays := strings.Split(measureRelays+",ws://cvwpee5zgbargtxd5wtbtnc6lkbgzxj5byfig3e53ic4t7su7r45n4yd.onion", ",")
	nostrMu.Lock()
	nostrRelays = relays
	nostrMu.Unlock()

	cardP, scanP := filepath.Join(dir, "card.json"), filepath.Join(dir, "scan.json")
	resP := filepath.Join(dir, "result-"+role+".json")
	cold := os.Getenv("FC_COLD") == "1"
	if role == "scan" && cold {
		// the card is up before the scanner's app is opened
		var c fcCard
		for !fcReadJSON(cardP, &c) {
			time.Sleep(200 * time.Millisecond)
		}
	}
	t0 := time.Now()
	addr := make(chan string, 1)
	go func() { addr <- startListener(data) }()
	if err := subscribeFirstContact(mainIdent, 0); err != nil {
		t.Fatal(err)
	}
	_, fcPk, _ := mainFirstContactKeys(mainIdent, 0)
	onion := strings.TrimSuffix(<-addr, ".onion")
	me := fcCard{X: hex.EncodeToString(pub[:]), Fc: fcPk, Onion: onion + ".onion"}
	waitUp := func() time.Duration {
		for !(torReadyNow() && routeOK() && directOpen()) {
			time.Sleep(100 * time.Millisecond)
		}
		return time.Since(t0)
	}
	res := map[string]float64{}
	at := func(k string, d time.Duration) { res[k] = d.Seconds() }

	if role == "card" {
		os.Remove(scanP)
		at("card up", waitUp())
		keepCache()
		if os.Getenv("FC_WARM") == "1" {
			// the card is on screen while it is scanned
			warmHello()
		}
		fcWriteJSON(t, cardP, me)
		var s fcCard
		for !fcReadJSON(scanP, &s) {
			time.Sleep(100 * time.Millisecond)
		}
		// the hello came: answer it both ways, as a receipt goes to someone
		// not added back yet
		end := time.Now().Add(5 * time.Minute)
		var relayAt, onionAt time.Time
		for time.Now().Before(end) && (relayAt.IsZero() || onionAt.IsZero()) {
			r, o := fcHeard("hello-from-" + s.X[:8])
			if r && relayAt.IsZero() {
				relayAt = time.Now()
			}
			if o && onionAt.IsZero() {
				onionAt = time.Now()
			}
			if !relayAt.IsZero() && time.Since(relayAt) > 90*time.Second {
				break
			}
			time.Sleep(50 * time.Millisecond)
		}
		res["hello in by relay (unix)"] = float64(relayAt.UnixMilli()) / 1000
		res["hello in by onion (unix)"] = float64(onionAt.UnixMilli()) / 1000
		ans := "answer-from-" + me.X[:8]
		go func() {
			b := time.Now()
			if r := sendDirect(s.Onion, ans); strings.HasPrefix(r, "error") {
				log.Printf("measure: answer by onion: %s", r)
			} else {
				res["answer by onion took"] = time.Since(b).Seconds()
			}
		}()
		b := time.Now()
		if r := nostrSendFirstContact(mainIdent, s.X, s.Fc, ans); r == "ok" {
			res["answer to relays took"] = time.Since(b).Seconds()
		} else {
			t.Logf("answer to relays: %s", r)
		}
		time.Sleep(60 * time.Second)
		fcWriteJSON(t, resP, res)
		t.Logf("CARD %v", res)
		return
	}

	var c fcCard
	for !fcReadJSON(cardP, &c) {
		time.Sleep(100 * time.Millisecond)
	}
	if os.Getenv("FC_WARM") == "1" {
		warmHello()
	}
	if !cold {
		at("scanner up", waitUp())
		keepCache()
		if os.Getenv("FC_WARM") == "1" {
			// the scan screen stays open a moment while the card is aimed at
			time.Sleep(3 * time.Second)
		}
	}
	scanAt := time.Now()
	res["scan at (unix)"] = float64(scanAt.UnixMilli()) / 1000
	fcWriteJSON(t, scanP, me)
	hello := "hello-from-" + me.X[:8]
	go func() {
		b := time.Now()
		for {
			r := sendDirect(c.Onion, hello)
			if !strings.HasPrefix(r, "error") {
				res["hello by onion took"] = time.Since(b).Seconds()
				return
			}
			log.Printf("measure: hello by onion: %s", r)
			if time.Since(b) > 2*time.Minute {
				return
			}
			time.Sleep(2 * time.Second)
		}
	}()
	for {
		r := nostrSendFirstContact(mainIdent, c.X, c.Fc, hello)
		if r == "ok" {
			res["hello to relays took"] = time.Since(scanAt).Seconds()
			break
		}
		log.Printf("measure: hello to relays: %s", r)
		if time.Since(scanAt) > 3*time.Minute {
			break
		}
		time.Sleep(2 * time.Second)
	}
	end := time.Now().Add(5 * time.Minute)
	for time.Now().Before(end) {
		r, o := fcHeard("answer-from-" + c.X[:8])
		if r {
			if _, ok := res["answer in by relay"]; !ok {
				res["answer in by relay"] = time.Since(scanAt).Seconds()
			}
		}
		if o {
			if _, ok := res["answer in by onion"]; !ok {
				res["answer in by onion"] = time.Since(scanAt).Seconds()
			}
		}
		if r && o {
			break
		}
		if _, ok := res["answer in by relay"]; ok && time.Since(scanAt) > 3*time.Minute {
			break
		}
		time.Sleep(50 * time.Millisecond)
	}
	var cr map[string]float64
	for i := 0; i < 900 && !fcReadJSON(resP[:len(resP)-len("scan.json")]+"card.json", &cr); i++ {
		time.Sleep(100 * time.Millisecond)
	}
	scan := float64(scanAt.UnixMilli()) / 1000
	if v := cr["hello in by relay (unix)"]; v > 0 {
		res["hello in by relay"] = v - scan
	}
	if v := cr["hello in by onion (unix)"]; v > 0 {
		res["hello in by onion"] = v - scan
	}
	fcWriteJSON(t, resP, res)
	t.Logf("SCAN cold=%v warm=%v %v", cold, os.Getenv("FC_WARM") == "1", res)
}
