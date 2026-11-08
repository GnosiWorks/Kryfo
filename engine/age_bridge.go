// SPDX-License-Identifier: GPL-3.0-or-later
// the tools tab's "lock a file" and "open a locked file". dart hands over
// file descriptors it got from android's file picker (paths on windows), so
// the file streams from where it is to where it goes and no copy of it is
// ever made inside the app. the work is in ./agefile, which has no cgo and its own tests.
package main

import "C"

import (
	"bufio"
	"crypto/rand"
	"encoding/binary"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/halo/engine/agefile"
	"github.com/tyler-smith/go-bip39"
)

var (
	ageMu      sync.Mutex
	ageSession *agefile.Session
	ageIn      *os.File
	ageDone    int64
	ageStop    int32
)

// MemAvailable from /proc/meminfo, in bytes. 0 when it cannot be read, which
// the caller takes as "do not know", not as "none".
func memAvailable() int64 {
	f, err := os.Open("/proc/meminfo")
	if err != nil {
		return 0
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if !strings.HasPrefix(line, "MemAvailable:") {
			continue
		}
		parts := strings.Fields(line)
		if len(parts) < 2 {
			return 0
		}
		kb, err := strconv.ParseInt(parts[1], 10, 64)
		if err != nil {
			return 0
		}
		return kb * 1024
	}
	return 0
}

func ageResult(err error) *C.char {
	if err == nil {
		return C.CString("ok")
	}
	return C.CString("error: " + err.Error())
}

func ageDropLocked() {
	ageSession = nil
	if ageIn != nil {
		ageIn.Close()
		ageIn = nil
	}
}

// both descriptors are owned from here on and closed before returning
//
//export HaloAgeLock
func HaloAgeLock(inFd C.int, outFd C.int, cPass *C.char) *C.char {
	in := os.NewFile(uintptr(inFd), "age-in")
	out := os.NewFile(uintptr(outFd), "age-out")
	if in == nil || out == nil {
		if in != nil {
			in.Close()
		}
		if out != nil {
			out.Close()
		}
		return ageResult(agefile.ErrIO)
	}
	return ageResult(ageLockFiles(in, out, goStr(cPass)))
}

// windows has no descriptors to hand over: the same work by path. the out
// file is made new, for this user only, and goes again when the work fails
//
//export HaloAgeLockPath
func HaloAgeLockPath(cIn *C.char, cOut *C.char, cPass *C.char) *C.char {
	return ageResult(ageLockPath(goStr(cIn), goStr(cOut), goStr(cPass)))
}

func ageLockPath(inPath, outPath, pass string) error {
	in, err := os.Open(inPath)
	if err != nil {
		return agefile.ErrIO
	}
	out, err := ageCreate(outPath)
	if err != nil {
		in.Close()
		return agefile.ErrIO
	}
	err = ageLockFiles(in, out, pass)
	if err != nil {
		os.Remove(outPath)
	}
	return err
}

// a new file, never one already there
func ageCreate(path string) (*os.File, error) {
	return os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
}

// closes both
func ageLockFiles(in, out *os.File, pass string) error {
	ageMu.Lock()
	defer ageMu.Unlock()
	defer in.Close()
	atomic.StoreInt64(&ageDone, 0)
	atomic.StoreInt32(&ageStop, 0)
	w := bufio.NewWriterSize(out, 256*1024)
	err := agefile.Lock(in, w, pass, &ageDone, &ageStop, memAvailable)
	if err == nil && w.Flush() != nil {
		err = agefile.ErrIO
	}
	if cerr := out.Close(); err == nil && cerr != nil {
		err = agefile.ErrIO
	}
	return err
}

// checks the password against the header and keeps the file open. nothing
// of the body is read, so nothing needs a place to go yet.
//
//export HaloAgeOpenBegin
func HaloAgeOpenBegin(inFd C.int, cPass *C.char) *C.char {
	in := os.NewFile(uintptr(inFd), "age-in")
	if in == nil {
		HaloAgeOpenDrop()
		return ageResult(agefile.ErrIO)
	}
	return ageResult(ageOpenBeginFile(in, goStr(cPass)))
}

//export HaloAgeOpenBeginPath
func HaloAgeOpenBeginPath(cIn *C.char, cPass *C.char) *C.char {
	return ageResult(ageOpenBeginPath(goStr(cIn), goStr(cPass)))
}

func ageOpenBeginPath(inPath, pass string) error {
	in, err := os.Open(inPath)
	if err != nil {
		HaloAgeOpenDrop()
		return agefile.ErrIO
	}
	return ageOpenBeginFile(in, pass)
}

// keeps [in] open on success, closes it otherwise
func ageOpenBeginFile(in *os.File, pass string) error {
	ageMu.Lock()
	defer ageMu.Unlock()
	ageDropLocked()
	s, err := agefile.Begin(in, pass, memAvailable)
	if err != nil {
		in.Close()
		return err
	}
	ageSession = s
	ageIn = in
	return nil
}

//export HaloAgeOpenFinish
func HaloAgeOpenFinish(outFd C.int) *C.char {
	out := os.NewFile(uintptr(outFd), "age-out")
	if out == nil {
		HaloAgeOpenDrop()
		return ageResult(agefile.ErrIO)
	}
	return ageResult(ageOpenFinishFile(out))
}

// the plain file is made new at [cOut] and goes again when the work fails:
// nothing half opened is left
//
//export HaloAgeOpenFinishPath
func HaloAgeOpenFinishPath(cOut *C.char) *C.char {
	return ageResult(ageOpenFinishPath(goStr(cOut)))
}

func ageOpenFinishPath(outPath string) error {
	out, err := ageCreate(outPath)
	if err != nil {
		HaloAgeOpenDrop()
		return agefile.ErrIO
	}
	err = ageOpenFinishFile(out)
	if err != nil {
		os.Remove(outPath)
	}
	return err
}

// closes [out] and lets go of the session
func ageOpenFinishFile(out *os.File) error {
	ageMu.Lock()
	defer ageMu.Unlock()
	s := ageSession
	if s == nil {
		out.Close()
		return agefile.ErrIO
	}
	atomic.StoreInt64(&ageDone, 0)
	atomic.StoreInt32(&ageStop, 0)
	w := bufio.NewWriterSize(out, 256*1024)
	err := s.Finish(w, &ageDone, &ageStop)
	if err == nil && w.Flush() != nil {
		err = agefile.ErrIO
	}
	if cerr := out.Close(); err == nil && cerr != nil {
		err = agefile.ErrIO
	}
	ageDropLocked()
	return err
}

//export HaloAgeOpenDrop
func HaloAgeOpenDrop() {
	ageMu.Lock()
	defer ageMu.Unlock()
	ageDropLocked()
}

// read from the ui while a call above runs on another isolate
//
//export HaloAgeProgress
func HaloAgeProgress() C.longlong {
	return C.longlong(atomic.LoadInt64(&ageDone))
}

//export HaloAgeCancel
func HaloAgeCancel() {
	atomic.StoreInt32(&ageStop, 1)
}

// four words from the list the identity names come from: 44 bits, drawn
// from the system's random source, with no modulo bias (2048 is 2^11).
//
//export HaloSuggestPassphrase
func HaloSuggestPassphrase() *C.char {
	words := bip39.GetWordList()
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil || len(words) != 2048 {
		return C.CString("")
	}
	bits := binary.BigEndian.Uint64(b[:])
	out := make([]string, 4)
	for i := range out {
		out[i] = words[(bits>>(uint(i)*11))&0x7FF]
	}
	return C.CString(strings.Join(out, "-"))
}
