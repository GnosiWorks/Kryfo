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

//export HaloPinCheck
func HaloPinCheck(cPin, cTable, cLegacy, cWrapped *C.char) *C.char {
	pin := pinBytes(cPin)
	defer zero(pin)
	var t pinTable
	var old pinLegacy
	if json.Unmarshal([]byte(C.GoString(cTable)), &t) != nil {
		return C.CString("error: bad table")
	}
	if s := C.GoString(cLegacy); s != "" && json.Unmarshal([]byte(s), &old) != nil {
		return C.CString("error: bad legacy")
	}
	wrapped, _ := hex.DecodeString(C.GoString(cWrapped))
	r, err := pinCheck(pin, t, old, wrapped)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return pinJSON(r)
}

// {"t": the new table, "w": the wrapped key or ""}, or "error: collision"
// when the pin already opens another entry
//
//export HaloPinSetup
func HaloPinSetup(cPin, cTable, cLegacy *C.char, index, kind C.int, cContainer, cWrapPlain *C.char) *C.char {
	pin := pinBytes(cPin)
	defer zero(pin)
	var t pinTable
	var old pinLegacy
	if json.Unmarshal([]byte(C.GoString(cTable)), &t) != nil {
		return C.CString("error: bad table")
	}
	if s := C.GoString(cLegacy); s != "" && json.Unmarshal([]byte(s), &old) != nil {
		return C.CString("error: bad legacy")
	}
	container, err := hex.DecodeString(C.GoString(cContainer))
	if err != nil {
		return C.CString("error: bad container")
	}
	plain, _ := hex.DecodeString(C.GoString(cWrapPlain))
	defer zero(plain)
	out, wrapped, err := pinSetup(pin, t, old, int(index), int(kind), container, plain)
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return pinJSON(map[string]any{"t": out, "w": hex.EncodeToString(wrapped)})
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
