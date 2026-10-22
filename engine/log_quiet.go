// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !android

package main

import (
	"log"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
)

// off android stderr ends up in the desktop session's journal, so the log
// passes the same gate as androidLogWriter and goes only to a 0600 file in
// the data dir.
func init() {
	log.SetFlags(log.Ltime | log.Lshortfile)
	log.SetOutput(&quietLog{})
	// tor prints its notices to stdout unless told not to
	torArgsExtra = append(torArgsExtra, "--quiet")
}

const (
	debugLogName = "engine-debug.log"
	debugLogMax  = 32 << 20
)

type quietLog struct {
	dir   func() string // nil: the engine's data dir
	mu    sync.Mutex
	f     *os.File
	tried string
	n     int64
}

func (q *quietLog) Write(p []byte) (int, error) {
	if atomic.LoadInt32(&debugOn) == 0 {
		return len(p), nil
	}
	q.mu.Lock()
	defer q.mu.Unlock()
	if q.f == nil && !q.open() {
		return len(p), nil
	}
	if q.n < debugLogMax {
		n, _ := q.f.Write([]byte(scrubBridges(string(p))))
		q.n += int64(n)
	}
	return len(p), nil
}

// lines before the data dir is known are dropped
func (q *quietLog) open() bool {
	var dir string
	if q.dir != nil {
		dir = q.dir()
	} else {
		dir = dataDirPeek()
	}
	if dir == "" || dir == q.tried {
		return false
	}
	q.tried = dir
	f, err := os.OpenFile(filepath.Join(dir, debugLogName), os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return false
	}
	// an older file may have looser bits
	if f.Chmod(0600) != nil {
		f.Close()
		return false
	}
	q.f = f
	return true
}

// the caller may be logging with mu held, so never wait for it
func dataDirPeek() string {
	if !mu.TryLock() {
		return ""
	}
	defer mu.Unlock()
	return savedDataDir
}
