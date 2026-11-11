// SPDX-License-Identifier: GPL-3.0-or-later
package main

// windows has no folder in memory: there the onion key, the relay marks
// and the wrap queue live in this process alone, and the app seals them
// between runs (mobile/lib/desktop/sealed_setup.dart). everywhere else
// these calls are the disk's

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
)

var (
	memFolderMu sync.Mutex
	memFolderOn bool
	memFolder   = map[string][]byte{}
)

// the files kept in memory when it is on, by name: the onion key and every
// nostr_ file the engine writes
func memName(p string) (string, bool) {
	memFolderMu.Lock()
	on := memFolderOn
	memFolderMu.Unlock()
	if !on {
		return "", false
	}
	n := filepath.Base(p)
	return n, n == "onion.key" || strings.HasPrefix(n, "nostr_")
}

// on or off; off zeroes and drops what memory held
func setMemFolder(on bool) {
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	memFolderOn = on
	if !on {
		for n, b := range memFolder {
			clear(b)
			delete(memFolder, n)
		}
	}
}

func notInMem(p string) error {
	return &fs.PathError{Op: "open", Path: p, Err: fs.ErrNotExist}
}

func vRead(p string) ([]byte, error) {
	n, ok := memName(p)
	if !ok {
		return os.ReadFile(p)
	}
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	b, has := memFolder[n]
	if !has {
		return nil, notInMem(p)
	}
	return append([]byte(nil), b...), nil
}

func vExists(p string) bool {
	n, ok := memName(p)
	if !ok {
		_, err := os.Stat(p)
		return err == nil
	}
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	_, has := memFolder[n]
	return has
}

func vWrite(p string, b []byte) error {
	n, ok := memName(p)
	if !ok {
		return os.WriteFile(p, b, 0600)
	}
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	clear(memFolder[n])
	memFolder[n] = append([]byte(nil), b...)
	return nil
}

// b added at the end; with create false only to a file that is there
func vAppend(p string, b []byte, create bool) error {
	n, ok := memName(p)
	if !ok {
		flag := os.O_APPEND | os.O_WRONLY
		if create {
			flag |= os.O_CREATE
		}
		f, err := os.OpenFile(p, flag, 0600)
		if err != nil {
			return err
		}
		_, err = f.Write(b)
		if cerr := f.Close(); err == nil {
			err = cerr
		}
		return err
	}
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	old, has := memFolder[n]
	if !has && !create {
		return notInMem(p)
	}
	grown := make([]byte, len(old)+len(b))
	copy(grown, old)
	copy(grown[len(old):], b)
	clear(old)
	memFolder[n] = grown
	return nil
}

func vRename(from, to string) error {
	nf, okf := memName(from)
	nt, okt := memName(to)
	if !okf && !okt {
		return os.Rename(from, to)
	}
	if okf != okt {
		return errors.New("rename across the memory folder")
	}
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	b, has := memFolder[nf]
	if !has {
		return notInMem(from)
	}
	if nf == nt {
		return nil
	}
	clear(memFolder[nt])
	memFolder[nt] = b
	delete(memFolder, nf)
	return nil
}

func vRemove(p string) {
	n, ok := memName(p)
	if !ok {
		os.Remove(p)
		return
	}
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	clear(memFolder[n])
	delete(memFolder, n)
}

// the app's side: a file put in before the start, read back to be sealed
func memPut(name string, b []byte) bool {
	if name == "" || strings.ContainsAny(name, `/\`) {
		return false
	}
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	clear(memFolder[name])
	memFolder[name] = append([]byte(nil), b...)
	return true
}

func memGet(name string) ([]byte, bool) {
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	b, has := memFolder[name]
	if !has {
		return nil, false
	}
	return append([]byte(nil), b...), true
}

func memNames() []string {
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	out := make([]string, 0, len(memFolder))
	for n := range memFolder {
		out = append(out, n)
	}
	sort.Strings(out)
	return out
}

// one file zeroed and gone, or every one for ""
func memDrop(name string) {
	memFolderMu.Lock()
	defer memFolderMu.Unlock()
	for n, b := range memFolder {
		if name == "" || n == name {
			clear(b)
			delete(memFolder, n)
		}
	}
}
