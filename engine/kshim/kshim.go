// SPDX-License-Identifier: GPL-3.0-or-later

// Package kshim calls kryfo's libsignal shim (libkryfo_signal) from the
// engine. the app has it loaded already; the engine opens it by the same
// name or path, so the signature rules stay in one place and dart never
// vouches for a signature.
package kshim

/*
#cgo !windows LDFLAGS: -ldl
#include <stdint.h>
#include <stdlib.h>
#ifdef _WIN32
#include <windows.h>
static void *ks_open(const char *path) { return (void *)LoadLibraryA(path); }
static void *ks_sym(void *h, const char *name) {
	return (void *)GetProcAddress((HMODULE)h, name);
}
#else
#include <dlfcn.h>
static void *ks_open(const char *path) { return dlopen(path, RTLD_NOW | RTLD_LOCAL); }
static void *ks_sym(void *h, const char *name) { return dlsym(h, name); }
#endif

typedef int32_t (*ks_call_fn)(const uint8_t *, size_t, uint8_t **, size_t *);
typedef void (*ks_free_fn)(uint8_t *, size_t);
typedef uint32_t (*ks_abi_fn)(void);

static int32_t ks_run(void *fn, const uint8_t *in, size_t n, uint8_t **out, size_t *on) {
	return ((ks_call_fn)fn)(in, n, out, on);
}
static void ks_release(void *fn, uint8_t *p, size_t n) { ((ks_free_fn)fn)(p, n); }
static uint32_t ks_abi(void *fn) { return ((ks_abi_fn)fn)(); }
*/
import "C"

import (
	"encoding/binary"
	"errors"
	"fmt"
	"sync"
	"unsafe"
)

const (
	// MinABI is the first abi with ks_verify_ctx
	MinABI = 4

	errOK = 0
)

var (
	ErrOpen = errors.New("kshim: library not opened")
	ErrABI  = errors.New("kshim: library too old")
	ErrCall = errors.New("kshim: call failed")
	// ErrSignature is a signature the shim does not take, for whatever
	// reason it gives
	ErrSignature = errors.New("kshim: signature refused")
)

// Lib is the shim, open.
type Lib struct {
	h    unsafe.Pointer
	free unsafe.Pointer
	mu   sync.Mutex
	fns  map[string]unsafe.Pointer
}

// Open loads the shim at path (a file name the loader finds, or a full
// path) and checks its abi.
func Open(path string) (*Lib, error) {
	cp := C.CString(path)
	defer C.free(unsafe.Pointer(cp))
	h := C.ks_open(cp)
	if h == nil {
		return nil, ErrOpen
	}
	l := &Lib{h: h, fns: map[string]unsafe.Pointer{}}
	abi, err := l.sym("ks_abi_version")
	if err != nil {
		return nil, err
	}
	if v := uint32(C.ks_abi(abi)); v < MinABI {
		return nil, fmt.Errorf("%w: abi %d", ErrABI, v)
	}
	if l.free, err = l.sym("ks_free"); err != nil {
		return nil, err
	}
	if _, err := l.sym("ks_verify_ctx"); err != nil {
		return nil, err
	}
	return l, nil
}

func (l *Lib) sym(name string) (unsafe.Pointer, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if p, ok := l.fns[name]; ok {
		return p, nil
	}
	cn := C.CString(name)
	defer C.free(unsafe.Pointer(cn))
	p := C.ks_sym(l.h, cn)
	if p == nil {
		return nil, fmt.Errorf("%w: no %s", ErrOpen, name)
	}
	l.fns[name] = p
	return p, nil
}

// the shim's framing: each field a u32 little endian length and its bytes
func frame(fields [][]byte) []byte {
	n := 0
	for _, f := range fields {
		n += 4 + len(f)
	}
	out := make([]byte, 0, n)
	for _, f := range fields {
		out = binary.LittleEndian.AppendUint32(out, uint32(len(f)))
		out = append(out, f...)
	}
	return out
}

func unframe(b []byte) ([][]byte, error) {
	var out [][]byte
	for len(b) > 0 {
		if len(b) < 4 {
			return nil, ErrCall
		}
		n := binary.LittleEndian.Uint32(b)
		b = b[4:]
		if uint64(n) > uint64(len(b)) {
			return nil, ErrCall
		}
		out = append(out, b[:n:n])
		b = b[n:]
	}
	return out, nil
}

// Call runs the shim call name on fields and gives its output fields and
// its code (0 for ok). the engine itself only verifies; the tests sign
// through this.
func (l *Lib) Call(name string, fields ...[]byte) ([][]byte, int32, error) {
	fn, err := l.sym(name)
	if err != nil {
		return nil, 0, err
	}
	in := frame(fields)
	// c memory: the call may hold the pointer for its whole run
	cin := C.malloc(C.size_t(len(in) + 1))
	defer C.free(cin)
	if len(in) > 0 {
		copy(unsafe.Slice((*byte)(cin), len(in)), in)
	}
	var out *C.uint8_t
	var on C.size_t
	code := int32(C.ks_run(fn, (*C.uint8_t)(cin), C.size_t(len(in)), &out, &on))
	if out == nil {
		return nil, code, nil
	}
	b := C.GoBytes(unsafe.Pointer(out), C.int(on))
	C.ks_release(l.free, out, on)
	if code != errOK {
		return nil, code, nil
	}
	fs, err := unframe(b)
	if err != nil {
		return nil, code, err
	}
	return fs, code, nil
}

// Verify checks sig over body under context by pub, as ks_verify_ctx does.
// any answer but ok is ErrSignature: a key not in its one form, a body
// the shim would not sign, a signer the body does not name.
func (l *Lib) Verify(pub []byte, context string, body, sig []byte) error {
	_, code, err := l.Call("ks_verify_ctx", pub, []byte(context), body, sig)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrSignature, err)
	}
	if code != errOK {
		return fmt.Errorf("%w: code %d", ErrSignature, code)
	}
	return nil
}
