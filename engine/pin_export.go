package main

// the pin table, from dart. json in, json out, "error: ..." on failure. the
// pin arrives as bytes so it can be zeroed here once used; dart zeroes its
// own copy. a check is two calls: begin runs the kdf and hands back x for
// the keystore, finish takes the keystore's answer. s waits in between under
// the handle and never leaves.

/*
#include <string.h>
*/
import "C"

import (
	"encoding/hex"
	"encoding/json"
	"errors"
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

func pinErr(err error) *C.char {
	return C.CString("error: " + err.Error())
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
	if json.Unmarshal([]byte(goStr(cTable)), &t) != nil {
		return t, old, C.CString("error: bad table")
	}
	if s := goStr(cLegacy); s != "" && json.Unmarshal([]byte(s), &old) != nil {
		return t, old, C.CString("error: bad legacy")
	}
	return t, old, nil
}

// the keystore's answer, 32 bytes in hex, or "" when there is none
func pinMacArg(c *C.char) ([]byte, error) {
	s := goStr(c)
	if s == "" {
		return nil, nil
	}
	m, err := hex.DecodeString(s)
	if err != nil {
		return nil, errPinKeystore
	}
	return m, nil
}

// the key info for a table moving to v3, or nil
func pinKeyArg(c *C.char) (*pinKeyInfo, error) {
	s := goStr(c)
	if s == "" {
		return nil, nil
	}
	var k pinKeyInfo
	if json.Unmarshal([]byte(s), &k) != nil || !k.ok() {
		return nil, errors.New("bad key info")
	}
	return &k, nil
}

// {"h": handle, "x": what the keystore signs, hex}. legacy is the json the
// finish gets, for the old checks run here on the same pin
//
//export HaloPinBegin
func HaloPinBegin(cPin, cTable, cLegacy *C.char) *C.char {
	pin := pinBytes(cPin)
	defer zero(pin)
	t, old, bad := pinArgs(cTable, cLegacy)
	if bad != nil {
		return bad
	}
	h, x, err := pinBegin(pin, t, old)
	if err != nil {
		return pinErr(err)
	}
	defer zero(x)
	return pinJSON(map[string]string{"h": h, "x": hex.EncodeToString(x)})
}

// 1 when the kdf takes the pin as it is, 0 when it is refused
//
//export HaloPinFits
func HaloPinFits(cPin *C.char) C.int {
	pin := pinBytes(cPin)
	defer zero(pin)
	if pinFits(pin) {
		return 1
	}
	return 0
}

// a begun check that will not be finished: its s goes now
//
//export HaloPinDrop
func HaloPinDrop(cH *C.char) {
	pinDrop(goStr(cH))
}

// {"i", "k", "c", "la", "lw", "u", "g", "mv", "r"}. u is the key the matched
// entry wraps, hex, or "". r is the table with the pin moved under the
// keystore's key, when it can move. "error: keystore" for an answer that
// cannot be the keystore's
//
//export HaloPinFinish
func HaloPinFinish(cH, cM, cTable, cLegacy, cKey *C.char) *C.char {
	t, old, bad := pinArgs(cTable, cLegacy)
	h := goStr(cH)
	if bad != nil {
		pinDrop(h)
		return bad
	}
	m, err := pinMacArg(cM)
	defer zero(m)
	key, kerr := pinKeyArg(cKey)
	p, perr := pinTakeFor(h, t)
	if perr != nil {
		return pinErr(perr)
	}
	defer zero(p.s)
	if err != nil {
		return pinErr(err)
	}
	if kerr != nil {
		return pinErr(kerr)
	}
	r, err := pinFinish(p, m, t, old, key)
	if err != nil {
		return pinErr(err)
	}
	return pinJSON(r)
}

// {"t": the new table}, or "error: collision" when the pin already opens
// another entry. wrapPlain is a 32-byte key in hex, sealed into the entry, or
// "" for none
//
//export HaloPinSetupFinish
func HaloPinSetupFinish(cH, cM, cTable, cKey *C.char, index, kind C.int, cContainer, cWrapPlain *C.char) *C.char {
	h := goStr(cH)
	var t pinTable
	if json.Unmarshal([]byte(goStr(cTable)), &t) != nil {
		pinDrop(h)
		return C.CString("error: bad table")
	}
	p, err := pinTakeFor(h, t)
	if err != nil {
		return pinErr(err)
	}
	defer zero(p.s)
	m, err := pinMacArg(cM)
	defer zero(m)
	if err != nil {
		return pinErr(err)
	}
	key, err := pinKeyArg(cKey)
	if err != nil {
		return pinErr(err)
	}
	container, err := hex.DecodeString(goStr(cContainer))
	if err != nil {
		return C.CString("error: bad container")
	}
	plain, err := hex.DecodeString(goStr(cWrapPlain))
	defer zero(plain)
	if err != nil {
		return C.CString("error: bad key")
	}
	out, err := pinSetupFinish(p, m, t, key, int(index), int(kind), container, plain)
	if err != nil {
		return pinErr(err)
	}
	return pinJSON(map[string]any{"t": out})
}

// a new pin for entry index, keeping what it opens and the key it wraps.
// {"t": the new table}, or "error: wrong pin" when the old pin does not open
// that entry, "error: collision" when the new one opens another
//
//export HaloPinRewrapFinish
func HaloPinRewrapFinish(cHo, cMo, cHn, cMn, cTable, cKey *C.char, index C.int) *C.char {
	ho, hn := goStr(cHo), goStr(cHn)
	var t pinTable
	if json.Unmarshal([]byte(goStr(cTable)), &t) != nil {
		pinDrop(ho)
		pinDrop(hn)
		return C.CString("error: bad table")
	}
	po, err := pinTakeFor(ho, t)
	if err != nil {
		pinDrop(hn)
		return pinErr(err)
	}
	defer zero(po.s)
	pn, err := pinTakeFor(hn, t)
	if err != nil {
		return pinErr(err)
	}
	defer zero(pn.s)
	mo, err1 := pinMacArg(cMo)
	defer zero(mo)
	mn, err2 := pinMacArg(cMn)
	defer zero(mn)
	if err1 != nil || err2 != nil {
		return pinErr(errPinKeystore)
	}
	key, err := pinKeyArg(cKey)
	if err != nil {
		return pinErr(err)
	}
	out, err := pinRewrapFinish(po, mo, pn, mn, t, key, int(index))
	if err != nil {
		return pinErr(err)
	}
	return pinJSON(map[string]any{"t": out})
}

// the table as v2, the same pins opening the same entries. a v2 or v3 table
// comes back as it is
//
//export HaloPinUpgrade
func HaloPinUpgrade(cTable *C.char) *C.char {
	var t pinTable
	if json.Unmarshal([]byte(goStr(cTable)), &t) != nil {
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
	if json.Unmarshal([]byte(goStr(cTable)), &t) != nil {
		return C.CString("error: bad table")
	}
	out, err := pinClear(t, int(index))
	if err != nil {
		return C.CString("error: " + err.Error())
	}
	return pinJSON(out)
}
