package nostr

import (
	stdjson "encoding/json"
	"fmt"
	"unsafe"

	"github.com/templexxx/xhex"
)

// RelayEvent represents an event received from a specific relay.
type RelayEvent struct {
	Event
	Relay *Relay
}

var ZeroID = ID{}

// ID represents an event id
type ID [32]byte

var (
	_ stdjson.Marshaler   = ID{}
	_ stdjson.Unmarshaler = (*ID)(nil)
)

func (id ID) String() string { return "id::" + id.Hex() }
func (id ID) Hex() string    { return HexEncodeToString(id[:]) }

func (id ID) MarshalJSON() ([]byte, error) {
	res := make([]byte, 66)
	xhex.Encode(res[1:], id[:])
	res[0] = '"'
	res[65] = '"'
	return res, nil
}

func (id *ID) UnmarshalJSON(buf []byte) error {
	if len(buf) != 66 {
		return fmt.Errorf("must be a quoted hex string of 64 characters")
	}
	err := xhex.Decode(id[:], buf[1:65])
	return err
}

func IDFromHex(idh string) (ID, error) {
	id := ID{}

	if len(idh) != 64 {
		return id, fmt.Errorf("pubkey should be 64-char hex, got '%s'", idh)
	}
	if err := xhex.Decode(id[:], unsafe.Slice(unsafe.StringData(idh), 64)); err != nil {
		return id, fmt.Errorf("'%s' is not valid hex: %w", idh, err)
	}

	return id, nil
}

func MustIDFromHex(idh string) ID {
	id := ID{}
	if err := xhex.Decode(id[:], unsafe.Slice(unsafe.StringData(idh), 64)); err != nil {
		panic(err)
	}
	return id
}

func ContainsID(haystack []ID, needle ID) bool {
	for _, cand := range haystack {
		if cand == needle {
			return true
		}
	}
	return false
}
