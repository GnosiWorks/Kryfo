// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/halo/engine/translate"
)

// retries in milliseconds, and a download that ends soon without chunks
func shortTranslateWaits(t *testing.T) {
	oldWait, oldGive := translateWait, translateGiveUp
	translateWait = func(int) time.Duration { return 5 * time.Millisecond }
	translateGiveUp = 300 * time.Millisecond
	t.Cleanup(func() { translateWait, translateGiveUp = oldWait, oldGive })
}

// what the engine logged while fn ran
func translateLogs(t *testing.T, fn func()) string {
	var b strings.Builder
	var bmu sync.Mutex
	log.SetOutput(writerFunc(func(p []byte) (int, error) {
		bmu.Lock()
		defer bmu.Unlock()
		return b.Write(p)
	}))
	defer log.SetOutput(os.Stderr)
	fn()
	bmu.Lock()
	defer bmu.Unlock()
	return b.String()
}

type writerFunc func([]byte) (int, error)

func (f writerFunc) Write(p []byte) (int, error) { return f(p) }

func TestTranslateCatalog(t *testing.T) {
	var c struct {
		Base  string       `json:"base"`
		Langs []bundleInfo `json:"langs"`
	}
	if err := json.Unmarshal([]byte(translateCatalog()), &c); err != nil {
		t.Fatal(err)
	}
	// our mirror, over its onion
	if !strings.HasPrefix(c.Base, "http://") || !strings.HasSuffix(c.Base, ".onion/models/") ||
		len(c.Langs) != 1 || c.Langs[0].Lang != "zh" {
		t.Fatalf("%+v", c)
	}
	// the size on the wire is the padded one
	if b := c.Langs[0]; len(b.Pairs) != 2 || b.Gz != 96<<20 || b.Disk <= b.Gz {
		t.Fatalf("%+v", b)
	}
}

// no tor, no download: nothing is dialled another way
func TestTranslateFetchNeedsTor(t *testing.T) {
	old := translateDial
	translateDial = func(string) (dialFn, error) { return nil, fmt.Errorf("not started") }
	t.Cleanup(func() { translateDial = old })
	if out := translateFetch("zh", t.TempDir()); !strings.HasPrefix(out, "error: tor") {
		t.Fatalf("got %q", out)
	}
	if st := translateJobs.Status("zh"); st.State != translate.StateIdle {
		t.Fatalf("a job started: %+v", st)
	}
}

// packs come from the pinned onion mirror and nowhere else: the only
// address a download dials is the mirror's
func TestTranslateFetchOnlyThePinnedMirror(t *testing.T) {
	pinned, err := translate.Pinned()
	if err != nil {
		t.Fatal(err)
	}
	u, err := url.Parse(pinned.Base)
	if err != nil {
		t.Fatal(err)
	}
	var mu sync.Mutex
	var addrs []string
	old := translateDial
	translateDial = func(string) (dialFn, error) {
		return func(_ context.Context, _, addr string) (net.Conn, error) {
			mu.Lock()
			addrs = append(addrs, addr)
			mu.Unlock()
			return nil, fmt.Errorf("refused")
		}, nil
	}
	t.Cleanup(func() { translateDial = old })
	shortTranslateWaits(t)
	logs := translateLogs(t, func() {
		if out := translateFetch("zh", t.TempDir()); out != "ok" {
			t.Fatalf("got %q", out)
		}
		deadline := time.Now().Add(10 * time.Second)
		for translateJobs.Status("zh").State == translate.StateRunning {
			if time.Now().After(deadline) {
				t.Fatal("still running")
			}
			time.Sleep(5 * time.Millisecond)
		}
	})
	if st := translateJobs.Status("zh"); st.State != translate.StateFailed || st.Kind != "net" {
		t.Fatalf("%+v", st)
	}
	translateJobs.Forget("zh")
	mu.Lock()
	defer mu.Unlock()
	if len(addrs) == 0 {
		t.Fatal("nothing dialled")
	}
	// every stop is logged by its class, never with the mirror's name
	if !strings.Contains(logs, "translate: download stopped (") || !strings.Contains(logs, ", ended") ||
		strings.Contains(logs, u.Hostname()) || strings.Contains(logs, "onion") || strings.Contains(logs, "zh") {
		t.Fatalf("logs %q", logs)
	}
	for _, a := range addrs {
		if a != u.Host+":80" {
			t.Fatalf("dialled %q, not the mirror %q", a, u.Host)
		}
	}
	if out := translateFetch("fr", t.TempDir()); !strings.HasPrefix(out, "error: no models") {
		t.Fatalf("got %q", out)
	}
}

// each download dials under a fresh socks name of its own, asks for a
// range and says nothing about itself. the stand-in serves the wrong
// bytes, so the pins stop it
func TestTranslateFetchOwnCircuit(t *testing.T) {
	var mu sync.Mutex
	var names, ua, ranges []string
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		ua = append(ua, r.Header.Get("User-Agent"))
		ranges = append(ranges, r.Header.Get("Range"))
		mu.Unlock()
		w.Header().Set("Content-Range", "bytes 0-9/10")
		w.WriteHeader(http.StatusPartialContent)
		w.Write([]byte("0123456789"))
	}))
	defer srv.Close()
	pool := x509.NewCertPool()
	pool.AddCert(srv.Certificate())
	oldDial, oldTLS := translateDial, translateTLS
	translateTLS = &tls.Config{RootCAs: pool, ServerName: "example.com"}
	translateDial = func(name string) (dialFn, error) {
		mu.Lock()
		names = append(names, name)
		mu.Unlock()
		addr := srv.Listener.Addr().String()
		return func(ctx context.Context, network, _ string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, network, addr)
		}, nil
	}
	oldManifest := translateManifest
	translateManifest = func() (*translate.Manifest, error) {
		m, err := translate.Pinned()
		if err == nil {
			m.Base = "https://example.com/m/"
		}
		return m, err
	}
	t.Cleanup(func() { translateDial, translateTLS, translateManifest = oldDial, oldTLS, oldManifest })
	shortTranslateWaits(t)

	run := func() translate.Status {
		dir := t.TempDir()
		if out := translateFetch("zh", dir); out != "ok" {
			t.Fatalf("got %q", out)
		}
		deadline := time.Now().Add(10 * time.Second)
		for translateJobs.Status("zh").State == translate.StateRunning {
			if time.Now().After(deadline) {
				t.Fatal("still running")
			}
			time.Sleep(5 * time.Millisecond)
		}
		return translateJobs.Status("zh")
	}
	if st := run(); st.State != translate.StateFailed {
		t.Fatalf("%+v", st)
	}
	mu.Lock()
	firstRun := len(names)
	mu.Unlock()
	run()
	translateJobs.Forget("zh")
	mu.Lock()
	defer mu.Unlock()
	// a lane each, more after misses, and never one name twice
	if firstRun < translateLanes || len(names) < firstRun+translateLanes {
		t.Fatalf("socks names %q", names)
	}
	seen := map[string]bool{}
	for _, n := range names {
		if seen[n] || !strings.HasPrefix(n, "translate:") {
			t.Fatalf("socks names %q", names)
		}
		seen[n] = true
		for _, other := range []string{"", laneName(laneUpdate), laneName(laneGifs), laneName(laneEveryday)} {
			if n == other {
				t.Fatalf("a download shares an isolation key: %q", other)
			}
		}
	}
	for i := range ua {
		if ua[i] != "" || !strings.HasPrefix(ranges[i], "bytes=") {
			t.Fatalf("request %d: ua %q range %q", i, ua[i], ranges[i])
		}
	}
}
