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
	data := env("FILES_DATA", "/var/lib/kryfo-files")
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
	s.sweepOrphans(blobs)
	go func() {
		for range time.Tick(10 * time.Minute) {
			s.sweep()
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
		maxPlain:       envInt("FILES_MAX_MB", 50) << 20,
		floor:          uint64(envInt("FILES_FLOOR_GB", 5)) << 30,
		quota:          envInt("FILES_QUOTA_GB", 0) << 30,
		senderDayBytes: envInt("FILES_SENDER_DAY_MB", 1024) << 20,
		senderDayFiles: int(envInt("FILES_SENDER_DAY_FILES", 300)),
		dayBytes:       envInt("FILES_DAY_GB", 150) << 30,
		keep:           time.Duration(envInt("FILES_KEEP_DAYS", 7)) * 24 * time.Hour,
		unfinished:     24 * time.Hour,
		powBits:        int(envInt("FILES_POW_BITS", 20)),
		streams:        int(envInt("FILES_STREAMS", 16)),
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
	code, word := http.StatusBadRequest, "bad"
	switch {
	case errors.Is(err, errBig):
		code, word = http.StatusRequestEntityTooLarge, "big"
	case errors.Is(err, errClash):
		code, word = http.StatusConflict, "clash"
	case errors.Is(err, errLimit):
		code, word = http.StatusTooManyRequests, "limit"
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

func (s *service) handleNew(w http.ResponseWriter, r *http.Request) {
	var req newReq
	if err := readSmall(r, &req); err != nil {
		fail(w, err)
		return
	}
	d, err := s.begin(req)
	if err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"part": partSize, "have": d.have(), "end": d.Ended})
}

func (s *service) handlePart(w http.ResponseWriter, r *http.Request) {
	id, ok := idOf(r)
	n, err := strconv.Atoi(r.PathValue("n"))
	if !ok || err != nil || strings.HasPrefix(r.PathValue("n"), "+") {
		fail(w, errShape)
		return
	}
	want, err := s.partSlot(id, n)
	if err != nil {
		fail(w, err)
		return
	}
	if r.ContentLength != want {
		fail(w, errShape)
		return
	}
	// a part waits for room in memory, never more than streams at once
	select {
	case s.parts <- struct{}{}:
		defer func() { <-s.parts }()
	case <-r.Context().Done():
		return
	}
	b := make([]byte, want)
	if _, err := io.ReadFull(r.Body, b); err != nil {
		fail(w, errShape)
		return
	}
	s.countIO(want, 0)
	if err := s.putPart(id, n, b); err != nil {
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
	d, err := s.have(id)
	if err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"have": d.have(), "end": d.Ended, "size": d.Size})
}

func (s *service) handleEnd(w http.ResponseWriter, r *http.Request) {
	id, ok := idOf(r)
	if !ok {
		fail(w, errShape)
		return
	}
	d, err := s.end(id)
	if errors.Is(err, errClash) && d != nil {
		writeJSON(w, http.StatusConflict, map[string]any{"e": "parts", "have": d.have()})
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
	size, err := s.whole(id)
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
	s.countIO(0, cw.n)
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
	left, err := s.taken(id, req.T)
	if err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"left": left})
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
