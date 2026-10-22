// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/halo/engine/translate"
)

func TestTranslateCatalog(t *testing.T) {
	var c struct {
		Base  string       `json:"base"`
		Langs []bundleInfo `json:"langs"`
	}
	if err := json.Unmarshal([]byte(translateCatalog()), &c); err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(c.Base, "https://") || len(c.Langs) != 1 || c.Langs[0].Lang != "zh" {
		t.Fatalf("%+v", c)
	}
	if b := c.Langs[0]; len(b.Pairs) != 2 || b.Gz <= 0 || b.Disk <= b.Gz {
		t.Fatalf("%+v", b)
	}
}

// no tor, no download: nothing is dialled another way
func TestTranslateFetchNeedsTor(t *testing.T) {
	old := translateDial
	translateDial = func(string) (dialFn, error) { return nil, fmt.Errorf("not started") }
	t.Cleanup(func() { translateDial = old })
	if out := translateFetch("zh", t.TempDir(), ""); !strings.HasPrefix(out, "error: tor") {
		t.Fatalf("got %q", out)
	}
	if st := translateJobs.Status("zh"); st.State != translate.StateIdle {
		t.Fatalf("a job started: %+v", st)
	}
}

func TestTranslateFetchRefusesPlainHost(t *testing.T) {
	if out := translateFetch("zh", t.TempDir(), "http://mirror.example/"); !strings.HasPrefix(out, "error:") {
		t.Fatalf("got %q", out)
	}
	if out := translateFetch("fr", t.TempDir(), ""); !strings.HasPrefix(out, "error: no models") {
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
	t.Cleanup(func() { translateDial, translateTLS = oldDial, oldTLS })

	run := func() translate.Status {
		dir := t.TempDir()
		if out := translateFetch("zh", dir, "https://example.com/m/"); out != "ok" {
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
	run()
	translateJobs.Forget("zh")
	mu.Lock()
	defer mu.Unlock()
	if len(names) != 2 || names[0] == names[1] || !strings.HasPrefix(names[0], "translate:") {
		t.Fatalf("socks names %q", names)
	}
	for _, other := range []string{"", laneName(laneUpdate), laneName(laneGifs), laneName(laneEveryday)} {
		if names[0] == other {
			t.Fatalf("a download shares an isolation key: %q", other)
		}
	}
	for i := range ua {
		if ua[i] != "" || !strings.HasPrefix(ranges[i], "bytes=") {
			t.Fatalf("request %d: ua %q range %q", i, ua[i], ranges[i])
		}
	}
}
