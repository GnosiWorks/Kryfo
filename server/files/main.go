// SPDX-License-Identifier: GPL-3.0-or-later
package main

// kryfo-files: big files waiting for their recipients. a phone seals a
// file with a key of its own and sends the key inside the message; this
// service holds the sealed bytes until every recipient has them, a week at
// most. phones reach it over tor only, so it never sees an address, and
// whatever store sits behind it sees this box and nothing else.

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

func main() {
	addr := env("FILES_ADDR", "127.0.0.1:3342")
	data := env("FILES_DATA", "/var/lib/kryfo-files/data")
	cfg := configFromEnv()
	blobs := filepath.Join(data, "blobs")
	store, err := newDiskStore(blobs)
	if err != nil {
		log.Fatalf("files: %v", err)
	}
	s, err := newService(cfg, store, data)
	if err != nil {
		log.Fatalf("files: %v", err)
	}
	// what a stop left past its time goes before anything is served
	s.sweep()
	s.sweepOrphans(blobs)
	go func() {
		for range time.Tick(time.Minute) {
			s.sweep()
			s.sweepOrphans(blobs)
		}
	}()
	go func() {
		for range time.Tick(time.Hour) {
			s.report()
		}
	}()
	log.Printf("files: listening on %s, up to %d MB a file, floor %d GB", addr, cfg.maxPlain>>20, cfg.floor>>30)
	log.Fatal(newServer(addr, s).ListenAndServe())
}

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func envInt(k string, d int64) int64 {
	if n, err := strconv.ParseInt(os.Getenv(k), 10, 64); err == nil && n >= 0 {
		return n
	}
	return d
}

func configFromEnv() config {
	return config{
		maxPlain:     envInt("FILES_MAX_MB", 50) << 20,
		floor:        uint64(envInt("FILES_FLOOR_GB", 5)) << 30,
		quota:        envInt("FILES_QUOTA_GB", 0) << 30,
		dayBytes:     envInt("FILES_DAY_GB", 150) << 30,
		hourFiles:    int(envInt("FILES_HOUR_FILES", 1500)),
		maxDelivered: int(envInt("FILES_MAX_DELIVERED", 200000)),
		keep:         time.Duration(envInt("FILES_KEEP_DAYS", 7)) * 24 * time.Hour,
		unfinished:   24 * time.Hour,
		idle:         time.Duration(envInt("FILES_IDLE_MIN", 15)) * time.Minute,
		maxFiles:     int(envInt("FILES_MAX_FILES", 50000)),
		idleSmall:    2 * time.Minute,
		maxComing:    envInt("FILES_MAX_COMING_GB", 20) << 30,
		powBase:      int(envInt("FILES_POW_BASE", 16)),
		powCap:       int(envInt("FILES_POW_CAP", 20)),
	}
}

func newServer(addr string, s *service) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           s.routes(),
		ReadHeaderTimeout: 20 * time.Second,
		// a part is 5 MB, and a slow circuit carries 30 kB/s
		ReadTimeout: 5 * time.Minute,
		// a whole file at that speed
		WriteTimeout:   45 * time.Minute,
		IdleTimeout:    60 * time.Second,
		MaxHeaderBytes: 8 << 10,
		// no ErrorLog: a request that fails leaves no line about it
		ErrorLog: log.New(io.Discard, "", 0),
	}
}

func (s *service) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /files/new", s.handleNew)
	mux.HandleFunc("PUT /files/{id}/{n}", s.handlePart)
	mux.HandleFunc("GET /files/{id}/have", s.handleHave)
	mux.HandleFunc("POST /files/{id}/end", s.handleEnd)
	mux.HandleFunc("GET /files/{id}", s.handleGet)
	mux.HandleFunc("POST /files/{id}/got", s.handleGot)
	mux.HandleFunc("POST /files/{id}/drop", s.handleDrop)
	return mux
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

// the words the engine reads, one per refusal
func fail(w http.ResponseWriter, err error) {
	var more errMoreWork
	if errors.As(err, &more) {
		// the work asked now: the sender works again and asks again
		writeJSON(w, http.StatusTooManyRequests, map[string]any{"e": "work", "bits": more.bits})
		return
	}
	code, word := http.StatusBadRequest, "bad"
	switch {
	case errors.Is(err, errBig):
		code, word = http.StatusRequestEntityTooLarge, "big"
	case errors.Is(err, errClash):
		code, word = http.StatusConflict, "clash"
	case errors.Is(err, errBusy):
		code, word = http.StatusServiceUnavailable, "busy"
	case errors.Is(err, errFull):
		code, word = http.StatusInsufficientStorage, "full"
	case errors.Is(err, errGone):
		code, word = http.StatusNotFound, "gone"
	case errors.Is(err, errWork):
		code, word = http.StatusForbidden, "denied"
	}
	writeJSON(w, code, map[string]string{"e": word})
}

func readSmall(r *http.Request, v any) error {
	b, err := io.ReadAll(io.LimitReader(r.Body, 32<<10))
	if err != nil {
		return errShape
	}
	if json.Unmarshal(b, v) != nil {
		return errShape
	}
	return nil
}

func idOf(r *http.Request) (string, bool) {
	id := r.PathValue("id")
	return id, idShape.MatchString(id)
}

// the sender's token rides in a header on what only the sender does, a
// recipient's on a download: an id alone opens nothing
const (
	ownHeader   = "X-Kryfo-Own"
	tokenHeader = "X-Kryfo-Token"
)

func (s *service) handleNew(w http.ResponseWriter, r *http.Request) {
	var req newReq
	if err := readSmall(r, &req); err != nil {
		fail(w, err)
		return
	}
	b, err := s.begin(req)
	if err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"part": partSize, "have": b.have, "end": b.ended, "gone": b.gone})
}

func (s *service) handlePart(w http.ResponseWriter, r *http.Request) {
	id, ok := idOf(r)
	n, err := strconv.Atoi(r.PathValue("n"))
	if !ok || err != nil || strings.HasPrefix(r.PathValue("n"), "+") {
		fail(w, errShape)
		return
	}
	// a later PUT of the owner's stops this one by cutting its body
	rc := http.NewResponseController(w)
	kill := func() { _ = rc.SetReadDeadline(time.Now()) }
	want, wr, err := s.partSlot(id, n, r.Header.Get(ownHeader), kill)
	if err != nil {
		fail(w, err)
		return
	}
	if r.ContentLength != want {
		s.release(id, wr)
		fail(w, errShape)
		return
	}
	if err := s.putPart(id, n, http.MaxBytesReader(w, r.Body, want), want, wr); err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *service) handleHave(w http.ResponseWriter, r *http.Request) {
	id, ok := idOf(r)
	if !ok {
		fail(w, errShape)
		return
	}
	b, size, err := s.have(id, r.Header.Get(ownHeader))
	if err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"have": b.have, "end": b.ended, "gone": b.gone, "size": size})
}

func (s *service) handleEnd(w http.ResponseWriter, r *http.Request) {
	id, ok := idOf(r)
	if !ok {
		fail(w, errShape)
		return
	}
	have, err := s.end(id, r.Header.Get(ownHeader))
	if errors.Is(err, errClash) && have != nil {
		// the parts it lacks: the sender sends those and ends again
		writeJSON(w, http.StatusConflict, map[string]any{"e": "clash", "have": have})
		return
	}
	if err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// the sealed bytes, by range so a download cut off goes on where it was
func (s *service) handleGet(w http.ResponseWriter, r *http.Request) {
	id, ok := idOf(r)
	if !ok {
		fail(w, errShape)
		return
	}
	token := r.Header.Get(tokenHeader)
	size, took, err := s.whole(id, token, func(size int64) int64 { return rangeWant(r.Header.Get("Range"), size) })
	if err != nil {
		fail(w, err)
		return
	}
	f, err := s.store.open(id)
	if err != nil {
		fail(w, errGone)
		return
	}
	defer f.Close()
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Cache-Control", "no-store")
	cw := &countingWriter{ResponseWriter: w}
	// no time and no name: nothing about the file but its bytes
	http.ServeContent(cw, r, "", time.Time{}, io.NewSectionReader(readerAt{f}, 0, size))
	s.countOut(cw.n)
	s.servedTo(id, token, took, cw.n)
}

type countingWriter struct {
	http.ResponseWriter
	n int64
}

func (c *countingWriter) Write(b []byte) (int, error) {
	n, err := c.ResponseWriter.Write(b)
	c.n += int64(n)
	return n, err
}

// a seeker read at offsets, for the section ServeContent walks
type readerAt struct{ f io.ReadSeeker }

func (r readerAt) ReadAt(p []byte, off int64) (int, error) {
	if ra, ok := r.f.(io.ReaderAt); ok {
		return ra.ReadAt(p, off)
	}
	if _, err := r.f.Seek(off, io.SeekStart); err != nil {
		return 0, err
	}
	return io.ReadFull(r.f, p)
}

type tokenReq struct {
	T string `json:"t"`
}

func (s *service) handleGot(w http.ResponseWriter, r *http.Request) {
	id, ok := idOf(r)
	var req tokenReq
	if !ok || readSmall(r, &req) != nil || !keyShape.MatchString(req.T) {
		fail(w, errShape)
		return
	}
	// nothing about the others: how many still lack it is not a
	// recipient's to know
	if err := s.taken(id, req.T); err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *service) handleDrop(w http.ResponseWriter, r *http.Request) {
	id, ok := idOf(r)
	var req tokenReq
	if !ok || readSmall(r, &req) != nil || !keyShape.MatchString(req.T) {
		fail(w, errShape)
		return
	}
	if err := s.dropBy(id, req.T); err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// what a download may serve: one range of a single span is its length, and
// anything else (none, several, one out of shape) the whole file
func rangeWant(h string, size int64) int64 {
	spec, ok := strings.CutPrefix(h, "bytes=")
	if !ok || strings.Contains(spec, ",") {
		return size
	}
	a, b, ok := strings.Cut(spec, "-")
	if !ok {
		return size
	}
	if a == "" {
		n, err := strconv.ParseInt(b, 10, 64)
		if err != nil || n <= 0 {
			return size
		}
		return min(n, size)
	}
	from, err := strconv.ParseInt(a, 10, 64)
	if err != nil || from < 0 || from >= size {
		return size
	}
	to := size - 1
	if b != "" {
		if t, err := strconv.ParseInt(b, 10, 64); err == nil && t >= from {
			to = min(t, size-1)
		}
	}
	return to - from + 1
}
