package main

// the pin table, from dart. json in, json out, "error: ..." on failure. the
// pin arrives as bytes so it can be zeroed here once used; dart zeroes its
// own copy.

/*
#include <string.h>
*/
import "C"

import (
	"encoding/hex"
	"encoding/json"
	"unsafe"
)

func pinBytes(p *C.char) []byte {
	return C.GoBytes(unsafe.Pointer(p), C.int(C.strlen(p)))
}

func pinJSON(v any) *C.char {
	b, err := json.Marshal(v)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString(string(b))
}

// {"n": cost, "ms": what one check took here}
//
//export HaloPinCalibrate
func HaloPinCalibrate() *C.char {
	n, ms := pinCalibrate(memAvailable())
	return pinJSON(map[string]int64{"n": int64(n), "ms": ms})
}

//export HaloPinNewTable
func HaloPinNewTable(logN C.int) *C.char {
	if int(logN) < pinLogNLow || int(logN) > pinLogNHigh {
		return C.CString("error: cost out of range")
	}
	return pinJSON(newPinTable(int(logN)))
}

func pinArgs(cTable, cLegacy *C.char) (pinTable, pinLegacy, *C.char) {
	var t pinTable
	var old pinLegacy
	if json.Unmarshal([]byte(C.GoString(cTable)), &t) != nil {
		return t, old, C.CString("error: bad table")
	}
	if s := C.GoString(cLegacy); s != "" && json.Unmarshal([]byte(s), &old) != nil {
		return t, old, C.CString("error: bad legacy")
	}
	return t, old, nil
}

// {"i", "k", "c", "la", "lw", "u"}. u is the key the matched entry wraps, hex,
// or ""
//
//export HaloPinCheck
func HaloPinCheck(cPin, cTable, cLegacy *C.char) *C.char {
	pin := pinBytes(cPin)
	defer zero(pin)
	t, old, bad := pinArgs(cTable, cLegacy)
	if bad != nil {
		return bad
	}
	r, err := pinCheck(pin, t, old)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return pinJSON(r)
}

// {"t": the new table}, or "error: collision" when the pin already opens
// another entry. wrapPlain is a 32-byte key in hex, sealed into the entry, or
// "" for none
//
//export HaloPinSetup
func HaloPinSetup(cPin, cTable, cLegacy *C.char, index, kind C.int, cContainer, cWrapPlain *C.char) *C.char {
	pin := pinBytes(cPin)
	defer zero(pin)
	t, old, bad := pinArgs(cTable, cLegacy)
	if bad != nil {
		return bad
	}
	container, err := hex.DecodeString(C.GoString(cContainer))
	if err != nil {
		return C.CString("error: bad container")
	}
	plain, err := hex.DecodeString(C.GoString(cWrapPlain))
	defer zero(plain)
	if err != nil {
		return C.CString("error: bad key")
	}
	out, err := pinSetup(pin, t, old, int(index), int(kind), container, plain)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return pinJSON(map[string]any{"t": out})
}

// a new pin for entry index, keeping what it opens and the key it wraps.
// {"t": the new table}, or "error: wrong pin" when the old pin does not open
// that entry, "error: collision" when the new one opens another
//
//export HaloPinRewrap
func HaloPinRewrap(cOld, cNew, cTable, cLegacy *C.char, index C.int) *C.char {
	oldPin, newPin := pinBytes(cOld), pinBytes(cNew)
	defer zero(oldPin)
	defer zero(newPin)
	t, old, bad := pinArgs(cTable, cLegacy)
	if bad != nil {
		return bad
	}
	out, err := pinRewrap(oldPin, newPin, t, old, int(index))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return pinJSON(map[string]any{"t": out})
}

// the table as v2, the same pins opening the same entries. a v2 table comes
// back as it is
//
//export HaloPinUpgrade
func HaloPinUpgrade(cTable *C.char) *C.char {
	var t pinTable
	if json.Unmarshal([]byte(C.GoString(cTable)), &t) != nil {
		return C.CString("error: bad table")
	}
	out, err := t.upgrade()
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return pinJSON(out)
}

//export HaloPinClear
func HaloPinClear(cTable *C.char, index C.int) *C.char {
	var t pinTable
	if json.Unmarshal([]byte(C.GoString(cTable)), &t) != nil {
		return C.CString("error: bad table")
	}
	out, err := pinClear(t, int(index))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return pinJSON(out)
}
