package nostr

import (
	"crypto/sha256"
	"hash"
	"strconv"
	"unsafe"

	"github.com/mailru/easyjson"
	"github.com/templexxx/xhex"
)

// Event represents a Nostr event.
type Event struct {
	ID        ID
	PubKey    PubKey
	CreatedAt Timestamp
	Kind      Kind
	Tags      Tags
	Content   string
	Sig       [64]byte
}

func (evt Event) String() string {
	j, _ := easyjson.Marshal(evt)
	return string(j)
}

// GetID serializes and returns the event ID as a string.
func (evt Event) GetID() ID {
	var id ID
	evt.serializedHash(&id)
	return id
}

// SetID calculates and sets the id to the event in a single operation.
func (evt *Event) SetID() {
	evt.serializedHash(&evt.ID)
}

// CheckID checks if the implied ID matches the currently assigned ID.
func (evt Event) CheckID() bool {
	return evt.GetID() == evt.ID
}

// Serialize outputs a byte array that can be hashed to produce the canonical event "id".
func (evt Event) Serialize() []byte {
	// the serialization process is just putting everything into a JSON array
	// so the order is kept. See NIP-01
	dst := make([]byte, 0, 100+len(evt.Content)+len(evt.Tags)*80)
	return evt.appendSerialized(dst)
}

var escTable [256]bool

// pre-built escape sequences; index by the offending byte.
var escSeq [256][2]byte

// pre-built []byte slices for hash.Write calls (no per-call allocation).
var escSlice [256][]byte

var (
	jsonQuote           = []byte{'"'}
	serializedStart     = []byte(`[0,"`)
	serializedPubkeyEnd = []byte(`",`)
	serializedTagsEnd   = []byte("],")
	serializedTagStart  = []byte{'['}
	serializedTagEnd    = []byte{']'}
	serializedComma     = []byte{','}
	serializedEnd       = []byte{']'}
)

func init() {
	for _, b := range []byte{'"', '\\', '\n', '\r', '\t'} {
		escTable[b] = true
	}

	escSeq['"'] = [2]byte{'\\', '"'}
	escSeq['\\'] = [2]byte{'\\', '\\'}
	escSeq['\n'] = [2]byte{'\\', 'n'}
	escSeq['\r'] = [2]byte{'\\', 'r'}
	escSeq['\t'] = [2]byte{'\\', 't'}
	for b, seq := range escSeq {
		if escTable[b] {
			escSlice[b] = seq[:]
		}
	}
}

func (evt Event) appendSerialized(dst []byte) []byte {
	start := len(dst)
	dst = append(dst, `[0,"`...)
	dst = append(dst, make([]byte, 64)...)
	xhex.Encode(dst[start+4:start+4+64], evt.PubKey[:])
	dst = append(dst, `",`...)
	dst = strconv.AppendInt(dst, int64(evt.CreatedAt), 10)
	dst = append(dst, ',')
	dst = strconv.AppendUint(dst, uint64(evt.Kind), 10)
	dst = append(dst, ',')

	// tags
	dst = append(dst, '[')
	for i, tag := range evt.Tags {
		if i > 0 {
			dst = append(dst, ',')
		}
		// tag item
		dst = append(dst, '[')
		for i, s := range tag {
			if i > 0 {
				dst = append(dst, ',')
			}
			dst = appendJSONString(dst, s)
		}
		dst = append(dst, ']')
	}
	dst = append(dst, "],"...)

	// content needs to be escaped in general as it is user generated.
	dst = appendJSONString(dst, evt.Content)
	dst = append(dst, ']')

	return dst
}

func (evt Event) serializedHash(dst *ID) {
	h := sha256.New()
	h.Write(serializedStart)

	var pubkeyHex [64]byte
	xhex.Encode(pubkeyHex[:], evt.PubKey[:])
	h.Write(pubkeyHex[:])
	h.Write(serializedPubkeyEnd)

	var numBuf [20]byte
	b := strconv.AppendInt(numBuf[:0], int64(evt.CreatedAt), 10)
	h.Write(b)
	h.Write(serializedComma)
	b = strconv.AppendUint(numBuf[:0], uint64(evt.Kind), 10)
	h.Write(b)
	h.Write(serializedComma)

	h.Write(serializedTagStart)
	for i, tag := range evt.Tags {
		if i > 0 {
			h.Write(serializedComma)
		}
		h.Write(serializedTagStart)
		for j, s := range tag {
			if j > 0 {
				h.Write(serializedComma)
			}
			writeJSONString(h, s)
		}
		h.Write(serializedTagEnd)
	}
	h.Write(serializedTagsEnd)

	writeJSONString(h, evt.Content)
	h.Write(serializedEnd)

	h.Sum((*dst)[:0])
}

// ── SWAR helper ──────────────────────────────────────────────────────────────

// hasSpecial returns non-zero if any byte in w is one of: \t 0x09, \n 0x0A,
// " 0x22, \ 0x5C. Uses the classic "hasvalue" bit-trick — no branches, no
// memory, pure ALU. Works regardless of endianness because we only care
// whether a match exists, not where.
//
//go:nosplit
func hasSpecial(w uint64) bool {
	match := func(w, v uint64) uint64 {
		x := w ^ (0x0101010101010101 * v)
		return (x - 0x0101010101010101) & ^x & 0x8080808080808080
	}
	return match(w, 0x09)|match(w, 0x0A)|match(w, 0x0D)|match(w, 0x22)|match(w, 0x5C) != 0
}

func appendJSONString(dst []byte, s string) []byte {
	dst = append(dst, '"')

	n := len(s)
	if n == 0 {
		return append(dst, '"')
	}

	base := uintptr(unsafe.Pointer(unsafe.StringData(s)))
	start, i := 0, 0

	// consume 8 bytes at a time;
	// if the whole word is clean, advance without touching dst at all;
	// but when a word is dirty, fall back to the byte loop only for that 8-byte window
	for i+8 <= n {
		w := *(*uint64)(unsafe.Pointer(base + uintptr(i)))
		if hasSpecial(w) {
			for end := i + 8; i < end; i++ {
				if escTable[s[i]] {
					// append everything since the start or the last time we did this up to here
					dst = append(dst, s[start:i]...)

					// append this special sequence
					seq := escSeq[s[i]]
					dst = append(dst, seq[0], seq[1])

					// set this as a checkpoint
					start = i + 1
				}
			}
		} else {
			i += 8
		}
	}

	// scalar tail for the remaining <8 bytes (same logic used for the hasSpecial branch above)
	for ; i < n; i++ {
		if escTable[s[i]] {
			dst = append(dst, s[start:i]...)
			seq := escSeq[s[i]]
			dst = append(dst, seq[0], seq[1])
			start = i + 1
		}
	}

	// add the remaining chunk (in a string without any specials this will add everything at once)
	dst = append(dst, s[start:]...)

	return append(dst, '"')
}

func writeJSONString(h hash.Hash, s string) {
	h.Write(jsonQuote)

	n := len(s)
	if n == 0 {
		h.Write(jsonQuote)
		return
	}

	base := uintptr(unsafe.Pointer(unsafe.StringData(s)))
	start, i := 0, 0

	for i+8 <= n {
		w := *(*uint64)(unsafe.Pointer(base + uintptr(i)))
		// apply same logic as of appendJSONString()
		if hasSpecial(w) {
			for end := i + 8; i < end; i++ {
				if escTable[s[i]] {
					if i > start {
						h.Write(unsafe.Slice(unsafe.StringData(s[start:i]), i-start))
					}
					h.Write(escSlice[s[i]])
					start = i + 1
				}
			}
		} else {
			i += 8
		}
	}

	for ; i < n; i++ {
		if escTable[s[i]] {
			if i > start {
				h.Write(unsafe.Slice(unsafe.StringData(s[start:i]), i-start))
			}
			h.Write(escSlice[s[i]])
			start = i + 1
		}
	}

	if start < n {
		h.Write(unsafe.Slice(unsafe.StringData(s[start:]), len(s)-start))
	}
	h.Write(jsonQuote)
}
