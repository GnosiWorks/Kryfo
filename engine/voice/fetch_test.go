// SPDX-License-Identifier: GPL-3.0-or-later
package voice

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
)

// a model of a few chunks, with its pins
func fakeModel(n int) ([]byte, Model) {
	b := make([]byte, n)
	for i := range b {
		b[i] = byte(i*7 + i/1000)
	}
	h := sha256.Sum256(b)
	return b, Model{ID: "t", File: "t.bin", Size: int64(n), SHA256: hex.EncodeToString(h[:])}
}

type fakeHost struct {
	data     []byte
	requests atomic.Int32
	// answer the whole file to every range
	noRange bool
	// after this many requests, cut each body halfway
	cutAfter int32
	// extra bytes on every body
	extra int
}

func (f *fakeHost) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	n := f.requests.Add(1)
	if r.Header.Get("User-Agent") != "" || r.Header.Get("Accept-Encoding") != "identity" {
		http.Error(w, "headers", http.StatusBadRequest)
		return
	}
	body := f.data
	if rg := r.Header.Get("Range"); rg != "" && !f.noRange {
		var a, b int
		if _, err := fmt.Sscanf(rg, "bytes=%d-%d", &a, &b); err != nil || a >= len(f.data) {
			http.Error(w, "range", http.StatusRequestedRangeNotSatisfiable)
			return
		}
		b = min(b, len(f.data)-1)
		body = f.data[a : b+1]
		w.Header().Set("Content-Range", "bytes "+strconv.Itoa(a)+"-"+strconv.Itoa(b)+"/"+strconv.Itoa(len(f.data)))
		w.WriteHeader(http.StatusPartialContent)
	}
	if f.cutAfter > 0 && n > f.cutAfter {
		body = body[:len(body)/2]
	}
	w.Write(body)
	if f.extra > 0 {
		w.Write(bytes.Repeat([]byte{1}, f.extra))
	}
}

func serve(t *testing.T, h http.Handler) (*Manifest, Getter) {
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	return &Manifest{Base: srv.URL + "/m/"}, HTTPGetter(srv.Client())
}

func TestFetchWhole(t *testing.T) {
	data, md := fakeModel(2*Chunk + 12345)
	host := &fakeHost{data: data}
	m, get := serve(t, host)
	dir := t.TempDir()
	var last, total int64
	err := Fetch(context.Background(), get, m, md, dir, func(d, tot int64) { last, total = d, tot })
	if err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(Path(dir, md))
	if !bytes.Equal(got, data) {
		t.Fatal("bytes differ")
	}
	if last != md.Size || total != md.Size {
		t.Fatalf("progress %d/%d", last, total)
	}
	if host.requests.Load() != 3 {
		t.Fatalf("%d requests for three chunks", host.requests.Load())
	}
	if _, err := os.Stat(Path(dir, md) + ".part"); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("part file left behind")
	}
	if st, _ := os.Stat(Path(dir, md)); st.Mode().Perm() != 0o600 {
		t.Fatalf("model mode %v", st.Mode().Perm())
	}
	// in place and checked: nothing is asked again
	if err := Fetch(context.Background(), get, m, md, dir, nil); err != nil {
		t.Fatal(err)
	}
	if host.requests.Load() != 3 {
		t.Fatal("fetched a model already in place")
	}
}

func TestFetchResumes(t *testing.T) {
	data, md := fakeModel(3*Chunk + 7)
	host := &fakeHost{data: data, cutAfter: 1}
	m, get := serve(t, host)
	dir := t.TempDir()
	if err := Fetch(context.Background(), get, m, md, dir, nil); err == nil {
		t.Fatal("a cut body finished the download")
	}
	part := Path(dir, md) + ".part"
	st, err := os.Stat(part)
	if err != nil || st.Size() == 0 || st.Size() >= md.Size {
		t.Fatalf("part after the cut: %v %v", st, err)
	}
	host.cutAfter = 0
	before := host.requests.Load()
	if err := Fetch(context.Background(), get, m, md, dir, nil); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(Path(dir, md))
	if !bytes.Equal(got, data) {
		t.Fatal("resumed bytes differ")
	}
	// it went on from the part, not from the top
	if n := host.requests.Load() - before; n >= 4 {
		t.Fatalf("%d requests after the cut", n)
	}
}

func TestFetchWrongHash(t *testing.T) {
	data, md := fakeModel(Chunk + 10)
	md.SHA256 = strings.Repeat("0", 64)
	m, get := serve(t, &fakeHost{data: data})
	dir := t.TempDir()
	err := Fetch(context.Background(), get, m, md, dir, nil)
	if !errors.Is(err, ErrHash) {
		t.Fatalf("err %v", err)
	}
	for _, p := range []string{Path(dir, md), Path(dir, md) + ".part"} {
		if _, err := os.Stat(p); !errors.Is(err, os.ErrNotExist) {
			t.Fatalf("%s kept after a wrong hash", p)
		}
	}
}

func TestFetchServerIgnoresRange(t *testing.T) {
	data, md := fakeModel(Chunk + 99)
	dir := t.TempDir()
	// half a file from before, then a host that always sends all of it
	os.WriteFile(Path(dir, md)+".part", data[:500], 0o600)
	m, get := serve(t, &fakeHost{data: data, noRange: true})
	if err := Fetch(context.Background(), get, m, md, dir, nil); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(Path(dir, md))
	if !bytes.Equal(got, data) {
		t.Fatal("bytes differ")
	}
}

func TestFetchTooLong(t *testing.T) {
	data, md := fakeModel(1000)
	m, get := serve(t, &fakeHost{data: data, extra: 10, noRange: true})
	dir := t.TempDir()
	if err := Fetch(context.Background(), get, m, md, dir, nil); !errors.Is(err, ErrSize) {
		t.Fatalf("err %v", err)
	}
	if _, err := os.Stat(Path(dir, md)); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("an oversized body became the model")
	}
}

func TestFetchStatus(t *testing.T) {
	_, md := fakeModel(10)
	m, get := serve(t, http.NotFoundHandler())
	if err := Fetch(context.Background(), get, m, md, t.TempDir(), nil); !errors.Is(err, ErrStatus) {
		t.Fatalf("err %v", err)
	}
}

func TestFetchCancelled(t *testing.T) {
	data, md := fakeModel(Chunk)
	m, get := serve(t, &fakeHost{data: data})
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := Fetch(ctx, get, m, md, t.TempDir(), nil); !errors.Is(err, context.Canceled) {
		t.Fatalf("err %v", err)
	}
}

// a stop that comes with the last chunk leaves the part, never the model
func TestFetchStoppedAtTheEndLandsNothing(t *testing.T) {
	data, md := fakeModel(Chunk + 10)
	m, get := serve(t, &fakeHost{data: data})
	ctx, cancel := context.WithCancel(context.Background())
	last := func(c context.Context, url string, off, n int64) (io.ReadCloser, int64, error) {
		if off+n == md.Size {
			cancel()
		}
		return get(context.Background(), url, off, n)
	}
	dir := t.TempDir()
	if err := Fetch(ctx, last, m, md, dir, nil); !errors.Is(err, context.Canceled) {
		t.Fatalf("err %v", err)
	}
	if _, err := os.Stat(Path(dir, md)); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("the model landed after the stop")
	}
	// the next start finds the whole part and only checks it
	if err := Fetch(context.Background(), get, m, md, dir, nil); err != nil {
		t.Fatal(err)
	}
}

func TestFetchRefusesSharedDir(t *testing.T) {
	_, md := fakeModel(10)
	called := false
	get := func(context.Context, string, int64, int64) (io.ReadCloser, int64, error) {
		called = true
		return nil, 0, errors.New("no")
	}
	for _, d := range []string{"/sdcard/Download", "/storage/emulated/0/x", "relative/dir", ""} {
		if err := Fetch(context.Background(), get, &Manifest{Base: "https://x/"}, md, d, nil); err == nil {
			t.Errorf("fetched into %q", d)
		}
	}
	if called {
		t.Fatal("asked the network for a dir it refused")
	}
}

func TestCheckDeletesCorrupt(t *testing.T) {
	data, md := fakeModel(4096)
	dir := t.TempDir()
	p := Path(dir, md)
	if err := Check(dir, md); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("missing model: %v", err)
	}
	os.WriteFile(p, data, 0o600)
	if err := Check(dir, md); err != nil {
		t.Fatal(err)
	}
	bad := bytes.Clone(data)
	bad[100] ^= 1
	os.WriteFile(p, bad, 0o600)
	if err := Check(dir, md); !errors.Is(err, ErrHash) {
		t.Fatalf("flipped byte: %v", err)
	}
	if _, err := os.Stat(p); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("a corrupt model stayed")
	}
	os.WriteFile(p, data[:4000], 0o600)
	if err := Check(dir, md); !errors.Is(err, ErrSize) {
		t.Fatalf("short model: %v", err)
	}
	if _, err := os.Stat(p); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("a partial model stayed")
	}
}

func TestRemove(t *testing.T) {
	data, md := fakeModel(100)
	dir := t.TempDir()
	os.WriteFile(Path(dir, md), data, 0o600)
	os.WriteFile(Path(dir, md)+".part", data, 0o600)
	keep := filepath.Join(dir, "other.bin")
	os.WriteFile(keep, data, 0o600)
	if err := Remove(dir, md); err != nil {
		t.Fatal(err)
	}
	if err := Remove(dir, md); err != nil {
		t.Fatalf("second remove: %v", err)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 || entries[0].Name() != "other.bin" {
		t.Fatalf("left %v", entries)
	}
	if err := Remove("/sdcard/x", md); err == nil {
		t.Fatal("removed from shared storage")
	}
}

func TestRangeStart(t *testing.T) {
	for h, want := range map[string]int64{"bytes 0-9/10": 0, "bytes 1048576-2097151/3000000": 1048576} {
		if got, ok := rangeStart(h); !ok || got != want {
			t.Errorf("%q: %d %v", h, got, ok)
		}
	}
	for _, h := range []string{"", "bytes x-1/2", "items 0-1/2", "bytes -5-1/2", "bytes 5"} {
		if _, ok := rangeStart(h); ok {
			t.Errorf("%q parsed", h)
		}
	}
}
