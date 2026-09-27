package nostr

import (
	"strconv"
	"strings"
	"sync"
	"unsafe"

	jsoniter "github.com/json-iterator/go"
	"github.com/templexxx/xhex"
	"golang.org/x/exp/constraints"
)

const MAX_LOCKS = 50

var (
	namedMutexPool = make([]sync.Mutex, MAX_LOCKS)
	json           = jsoniter.ConfigFastest
)

//go:noescape
//go:linkname memhash runtime.memhash
func memhash(p unsafe.Pointer, h, s uintptr) uintptr

func namedLock(name string) (unlock func()) {
	sptr := unsafe.StringData(name)
	idx := uint64(memhash(unsafe.Pointer(sptr), 0, uintptr(len(name)))) % MAX_LOCKS
	namedMutexPool[idx].Lock()
	return namedMutexPool[idx].Unlock
}

func similar[E constraints.Ordered](as, bs []E) bool {
	if len(as) != len(bs) {
		return false
	}

	for _, a := range as {
		for _, b := range bs {
			if b == a {
				goto next
			}
		}
		// didn't find a B that corresponded to the current A
		return false

	next:
		continue
	}

	return true
}

func similarID(as, bs []ID) bool {
	if len(as) != len(bs) {
		return false
	}

	for _, a := range as {
		for _, b := range bs {
			if b == a {
				goto next
			}
		}
		// didn't find a B that corresponded to the current A
		return false

	next:
		continue
	}

	return true
}

func similarPublicKey(as, bs []PubKey) bool {
	if len(as) != len(bs) {
		return false
	}

	for _, a := range as {
		for _, b := range bs {
			if b == a {
				goto next
			}
		}
		// didn't find a B that corresponded to the current A
		return false

	next:
		continue
	}

	return true
}

func subIdToSerial(subId string) int64 {
	n := strings.Index(subId, ":")
	if n < 0 || n > len(subId) {
		return -1
	}
	serialId, _ := strconv.ParseInt(subId[0:n], 10, 64)
	return serialId
}

func isLowerHex(thing string) bool {
	for _, charNumber := range thing {
		if (charNumber >= 48 && charNumber <= 57) || (charNumber >= 97 && charNumber <= 102) {
			continue
		}
		return false
	}
	return true
}

func extractSubID(jsonStr string) string {
	// look for "EVENT" pattern
	start := strings.Index(jsonStr, `"EVENT"`)
	if start == -1 {
		return ""
	}

	// move to the next quote
	offset := strings.Index(jsonStr[start+7:], `"`)
	if offset == -1 {
		return ""
	}

	start += 7 + offset + 1

	// find the ending quote
	end := strings.Index(jsonStr[start:], `"`)

	// get the contents
	return jsonStr[start : start+end]
}

func extractEventID(jsonStr string) ID {
	// look for "id" pattern
	start := strings.Index(jsonStr, `"id"`)
	if start == -1 {
		return [32]byte{}
	}

	// move to the next quote
	offset := strings.IndexByte(jsonStr[start+4:], '"')
	start += 4 + offset + 1

	// get 64 characters of the id
	var id [32]byte
	xhex.Decode(id[:], unsafe.Slice(unsafe.StringData(jsonStr[start:start+64]), 64))
	return id
}

func extractEventPubKey(jsonStr string) PubKey {
	// look for "pubkey" pattern
	start := strings.Index(jsonStr, `"pubkey"`)
	if start == -1 {
		return PubKey{}
	}

	// move to the next quote
	offset := strings.IndexByte(jsonStr[start+8:], '"')
	start += 8 + offset + 1

	// get 64 characters of the pubkey
	var pk [32]byte
	xhex.Decode(pk[:], unsafe.Slice(unsafe.StringData(jsonStr[start:start+64]), 64))
	return pk
}

func extractDTag(jsonStr string) string {
	// look for ["d", pattern
	start := strings.Index(jsonStr, `["d"`)
	if start == -1 {
		return ""
	}

	// move to the next quote
	offset := strings.IndexByte(jsonStr[start+4:], '"')
	start += 4 + offset + 1

	// find the ending quote
	end := strings.IndexByte(jsonStr[start:], '"')
	if end == -1 {
		return ""
	}

	// get the contents
	return jsonStr[start : start+end]
}

func extractTimestamp(jsonStr string) Timestamp {
	// look for "created_at": pattern
	start := strings.Index(jsonStr, `"created_at"`)
	if start == -1 {
		return 0
	}

	// move to the next number
	offset := strings.IndexAny(jsonStr[start+12:], "9876543210")
	if offset == -1 {
		return 0
	}
	start += 12 + offset

	// find the end
	end := strings.IndexAny(jsonStr[start:], ",} ")
	if end == -1 {
		return 0
	}

	// get the contents
	ts, _ := strconv.ParseInt(jsonStr[start:start+end], 10, 64)
	return Timestamp(ts)
}
