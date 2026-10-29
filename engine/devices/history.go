// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hkdf"
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"errors"
	"unicode/utf8"
)

// the history stream a phone sends a newly linked device. records are the
// backup file's: type 1, length 4, then aes-256-gcm with the record's index
// as its nonce and its type as additional data. the key comes from the
// link's stream key and transcript and the sender's own stream id, so a
// record opens only in its own link, from its own sender, at its own place.
// nothing in it is signed: the stream key already says it is the phone's,
// and only the two ends hold it
//
//	0          head: what follows and its counts
//	1..text    chats, their messages, then the media list
//	..end-1    media chunks, newest file first
//	end        empty

const (
	headMagic      = "KHC1"
	tallyMagic     = "KHT1"
	stateMagic     = "KHR1"
	planMagic      = "KHP1"
	historyVersion = 1

	// the backup's three record types, and a chunk the phone could no
	// longer read, under a key of its own so it never shares a nonce with
	// the chunk it stands in for
	recHead = 1
	recBody = 2
	recEnd  = 3
	recGone = 4

	kindChat     = 1
	kindMessages = 2
	kindMedia    = 3
	kindData     = 4

	// MinChunk and MaxChunk bound a media chunk; MaxChunk is the backup's
	MinChunk     = 1 << 10
	MaxChunk     = 1 << 20
	DefaultChunk = 256 << 10
	// MaxRecord is the most plaintext any record holds
	MaxRecord = MaxChunk + 64
	// MaxMeta is the most a chat's own row may take
	MaxMeta = 64 << 10
	// MaxChats keeps the head inside one record
	MaxChats = 40000
	// MaxName is the longest media file name
	MaxName = 255

	recHeaderSize = 5
	tagSize       = 16
	hashSize      = 32

	// IDSize is a sender's stream id
	IDSize = 32

	headFixed = 4 + 1 + KeySize + 32 + IDSize + 1 + 4 + 8 + 8 + 8 + hashSize + 4 + 4 + 4
	countSize = 4 + 4 + 8 + 4 + 4
	// what the tally carries per chat
	tallyCount = 4 + 4 + 8
	dataHead   = 1 + 4 + 8
	goneSize   = 4 + 8
	// a media entry before its name and chunk hashes
	mediaFixed = 4 + 8 + 8 + 1

	labelRecords = "kryfo-history-v1 records"
	labelGone    = "kryfo-history-v1 gone"
	labelTally   = "kryfo-history-v1 tally"
	labelText    = "kryfo-history-v1 text"
	labelSalt    = "kryfo-history-v1 salt"

	flagSkipMedia = 1
)

var (
	ErrRecord  = errors.New("devices: history record out of place or changed")
	ErrHead    = errors.New("devices: history head does not hold")
	ErrText    = errors.New("devices: history text does not match its head")
	ErrDone    = errors.New("devices: history stream already whole")
	ErrUsable  = errors.New("devices: history source not usable")
	ErrPlanned = errors.New("devices: history already planned")
	ErrTally   = errors.New("devices: tally does not open or fit")
	ErrUsed    = errors.New("devices: a stream key serves one sender only")
)

// Count is one chat's share of a stream: its messages, its media files
// and their bytes, and what the phone left out of it.
type Count struct {
	Messages   uint32
	Media      uint32
	MediaBytes uint64
	// rows and files the phone could not send: too big, unreadable, a name
	// that cannot be one, a file outside its media folder
	LeftRows  uint32
	LeftFiles uint32
}

// what both ends count after an import: the left-out counts are the
// phone's word, not something the device can count again
func (c Count) sameAs(o Count) bool {
	return c.Messages == o.Messages && c.Media == o.Media && c.MediaBytes == o.MediaBytes
}

// Head is record 0: everything the device checks the rest against.
type Head struct {
	Identity Key
	Bind     [32]byte
	// ID is the sender's own random stream id
	ID [IDSize]byte
	// SkipMedia says the person chose to leave photos, videos and files out
	SkipMedia bool
	Chunk     uint32
	// Records counts every record, head and end included
	Records uint64
	// Bytes is the whole stream on the wire, as planned
	Bytes uint64
	// Text is how many records follow the head before the first chunk
	Text     uint64
	TextHash [32]byte
	Files    uint32
	// LeftChats counts chats the phone could not send at all
	LeftChats uint32
	Chats     []Count
}

// Media is one file in the media list.
type Media struct {
	Chat uint32
	// At orders the list, newest first
	At   int64
	Size uint64
	Name string
	sums [][hashSize]byte
}

// Chunks is how many records carry the file; an empty file still takes one.
func (m *Media) Chunks(chunk uint32) uint64 { return chunksOf(m.Size, chunk) }

func chunksOf(size uint64, chunk uint32) uint64 {
	if size == 0 {
		return 1
	}
	return (size + uint64(chunk) - 1) / uint64(chunk)
}

func sealedSize(plain int) uint64 { return uint64(recHeaderSize + plain + tagSize) }

func (h *Head) encode() []byte {
	b := make([]byte, 0, headSize(len(h.Chats)))
	b = append(b, headMagic...)
	b = append(b, historyVersion)
	b = append(b, h.Identity[:]...)
	b = append(b, h.Bind[:]...)
	b = append(b, h.ID[:]...)
	var f byte
	if h.SkipMedia {
		f |= flagSkipMedia
	}
	b = append(b, f)
	b = binary.BigEndian.AppendUint32(b, h.Chunk)
	b = binary.BigEndian.AppendUint64(b, h.Records)
	b = binary.BigEndian.AppendUint64(b, h.Bytes)
	b = binary.BigEndian.AppendUint64(b, h.Text)
	b = append(b, h.TextHash[:]...)
	b = binary.BigEndian.AppendUint32(b, h.Files)
	b = binary.BigEndian.AppendUint32(b, h.LeftChats)
	b = binary.BigEndian.AppendUint32(b, uint32(len(h.Chats)))
	for _, c := range h.Chats {
		b = binary.BigEndian.AppendUint32(b, c.Messages)
		b = binary.BigEndian.AppendUint32(b, c.Media)
		b = binary.BigEndian.AppendUint64(b, c.MediaBytes)
		b = binary.BigEndian.AppendUint32(b, c.LeftRows)
		b = binary.BigEndian.AppendUint32(b, c.LeftFiles)
	}
	return b
}

func headSize(chats int) int { return headFixed + countSize*chats }

// ParseHead reads a head's plaintext strictly: one encoding only, counts
// that add up, and a chunk size in bounds.
func ParseHead(b []byte) (*Head, error) {
	if len(b) < headFixed || string(b[:4]) != headMagic || b[4] != historyVersion {
		return nil, ErrHead
	}
	h := &Head{}
	at := 5
	k, err := ParseKey(b[at : at+KeySize])
	if err != nil {
		return nil, ErrHead
	}
	h.Identity = k
	at += KeySize
	copy(h.Bind[:], b[at:at+32])
	at += 32
	copy(h.ID[:], b[at:at+IDSize])
	at += IDSize
	f := b[at]
	at++
	if f&^flagSkipMedia != 0 {
		return nil, ErrHead
	}
	h.SkipMedia = f&flagSkipMedia != 0
	h.Chunk = binary.BigEndian.Uint32(b[at:])
	at += 4
	h.Records = binary.BigEndian.Uint64(b[at:])
	at += 8
	h.Bytes = binary.BigEndian.Uint64(b[at:])
	at += 8
	h.Text = binary.BigEndian.Uint64(b[at:])
	at += 8
	copy(h.TextHash[:], b[at:at+hashSize])
	at += hashSize
	h.Files = binary.BigEndian.Uint32(b[at:])
	at += 4
	h.LeftChats = binary.BigEndian.Uint32(b[at:])
	at += 4
	n := binary.BigEndian.Uint32(b[at:])
	at += 4
	if n > MaxChats || len(b) != headSize(int(n)) {
		return nil, ErrHead
	}
	if h.Chunk < MinChunk || h.Chunk > MaxChunk {
		return nil, ErrHead
	}
	h.Chats = make([]Count, n)
	var files uint64
	for i := range h.Chats {
		c := &h.Chats[i]
		c.Messages = binary.BigEndian.Uint32(b[at:])
		c.Media = binary.BigEndian.Uint32(b[at+4:])
		c.MediaBytes = binary.BigEndian.Uint64(b[at+8:])
		c.LeftRows = binary.BigEndian.Uint32(b[at+16:])
		c.LeftFiles = binary.BigEndian.Uint32(b[at+20:])
		at += countSize
		files += uint64(c.Media)
		if c.Media == 0 && c.MediaBytes != 0 {
			return nil, ErrHead
		}
	}
	if files != uint64(h.Files) {
		return nil, ErrHead
	}
	// head, text, at least a chunk a file, end. chats and files need text
	if (n > 0 || h.Files > 0) && h.Text == 0 {
		return nil, ErrHead
	}
	if h.Records < h.Text+2 || h.Records-h.Text-2 < uint64(h.Files) ||
		(h.Files == 0 && h.Records != h.Text+2) {
		return nil, ErrHead
	}
	if h.Bytes < sealedSize(len(b)) {
		return nil, ErrHead
	}
	return h, nil
}

// the keys a stream key and its link's transcript give
type streamKeys struct {
	records cipher.AEAD
	gone    cipher.AEAD
	tally   cipher.AEAD
}

// the salt binds the link's transcript and this sender's stream id, so two
// senders on one stream key never share a key
func keyFor(key *[StreamKeySize]byte, bind [32]byte, id [IDSize]byte, label string) ([]byte, error) {
	salt := sha256.Sum256(append(append([]byte(labelSalt), bind[:]...), id[:]...))
	return hkdf.Key(sha256.New, key[:], salt[:], label, 32)
}

func aeadOf(k []byte) (cipher.AEAD, error) {
	defer wipe(k)
	c, err := aes.NewCipher(k)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(c)
}

func newStreamKeys(key *[StreamKeySize]byte, bind [32]byte, id [IDSize]byte) (*streamKeys, error) {
	if key == nil {
		return nil, ErrUsable
	}
	out := &streamKeys{}
	for _, p := range []struct {
		label string
		to    *cipher.AEAD
	}{{labelRecords, &out.records}, {labelGone, &out.gone}, {labelTally, &out.tally}} {
		k, err := keyFor(key, bind, id, p.label)
		if err != nil {
			return nil, err
		}
		a, err := aeadOf(k)
		if err != nil {
			return nil, err
		}
		*p.to = a
	}
	return out, nil
}

// RecordKey is the key the records are sealed under, as the backup's
// record cipher takes it. for tests that hold the two formats together.
func RecordKey(key *[StreamKeySize]byte, bind [32]byte, id [IDSize]byte) ([]byte, error) {
	return keyFor(key, bind, id, labelRecords)
}

// the backup's nonce: the record's index, big-endian in twelve bytes
func indexNonce(i uint64) []byte {
	n := make([]byte, 12)
	binary.BigEndian.PutUint64(n[4:], i)
	return n
}

func (k *streamKeys) seal(index uint64, typ byte, plain []byte) []byte {
	a := k.records
	if typ == recGone {
		a = k.gone
	}
	out := make([]byte, recHeaderSize, recHeaderSize+len(plain)+tagSize)
	out[0] = typ
	binary.BigEndian.PutUint32(out[1:], uint32(len(plain)+tagSize))
	return a.Seal(out, indexNonce(index), plain, []byte{typ})
}

// opens one framed record at its index: exactly one record, nothing after
func (k *streamKeys) open(index uint64, rec []byte) (byte, []byte, error) {
	if len(rec) < recHeaderSize+tagSize || len(rec) > recHeaderSize+MaxRecord+tagSize {
		return 0, nil, ErrRecord
	}
	typ := rec[0]
	n := binary.BigEndian.Uint32(rec[1:])
	if uint64(n) != uint64(len(rec)-recHeaderSize) {
		return 0, nil, ErrRecord
	}
	a := k.records
	switch typ {
	case recHead, recBody, recEnd:
	case recGone:
		a = k.gone
	default:
		return 0, nil, ErrRecord
	}
	p, err := a.Open(nil, indexNonce(index), rec[recHeaderSize:], []byte{typ})
	if err != nil {
		return 0, nil, ErrRecord
	}
	return typ, p, nil
}

// the text hash: every text record's index, length and plaintext in order
func textHashUpdate(h interface{ Write([]byte) (int, error) }, index uint64, plain []byte) {
	var n [12]byte
	binary.BigEndian.PutUint64(n[:], index)
	binary.BigEndian.PutUint32(n[8:], uint32(len(plain)))
	h.Write(n[:])
	h.Write(plain)
}

func newTextHash() interface {
	Write([]byte) (int, error)
	Sum([]byte) []byte
} {
	h := sha256.New()
	h.Write([]byte(labelText))
	return h
}

// a relative name that can only land inside the device's media folder: the
// rule backup_stream.dart's safeBackupName keeps
func safeName(n string) bool {
	if n == "" || len(n) > MaxName || !utf8.ValidString(n) || n[0] == '/' {
		return false
	}
	seg := 0
	for i := 0; i <= len(n); i++ {
		if i == len(n) || n[i] == '/' {
			s := n[seg:i]
			if s == "" || s == "." || s == ".." {
				return false
			}
			seg = i + 1
			continue
		}
		if n[i] < 32 || n[i] == '\\' || n[i] == 0x7f {
			return false
		}
	}
	return true
}

// a chat's row and a message's row are json objects, as the app writes them
func rowOK(b []byte, max int) bool {
	if len(b) < 2 || len(b) > max || b[0] != '{' || b[len(b)-1] != '}' {
		return false
	}
	return json.Valid(b)
}

func encodeMedia(b []byte, m *Media) []byte {
	b = binary.BigEndian.AppendUint32(b, m.Chat)
	b = binary.BigEndian.AppendUint64(b, uint64(m.At))
	b = binary.BigEndian.AppendUint64(b, m.Size)
	b = append(b, byte(len(m.Name)))
	b = append(b, m.Name...)
	for _, s := range m.sums {
		b = append(b, s[:]...)
	}
	return b
}

func mediaSize(m *Media) int { return mediaFixed + len(m.Name) + hashSize*len(m.sums) }

// one media entry from b, and what is left after it
func parseMedia(b []byte, chunk uint32) (*Media, []byte, error) {
	if len(b) < mediaFixed {
		return nil, nil, ErrRecord
	}
	m := &Media{
		Chat: binary.BigEndian.Uint32(b),
		At:   int64(binary.BigEndian.Uint64(b[4:])),
		Size: binary.BigEndian.Uint64(b[12:]),
	}
	nl := int(b[20])
	b = b[mediaFixed:]
	if len(b) < nl {
		return nil, nil, ErrRecord
	}
	m.Name = string(b[:nl])
	if !safeName(m.Name) {
		return nil, nil, ErrRecord
	}
	b = b[nl:]
	// the hashes of one file must fit one record
	c := chunksOf(m.Size, chunk)
	if c > uint64(len(b)/hashSize) {
		return nil, nil, ErrRecord
	}
	m.sums = make([][hashSize]byte, c)
	for i := range m.sums {
		copy(m.sums[i][:], b[:hashSize])
		b = b[hashSize:]
	}
	return m, b, nil
}

// the media list in a text record: a count, then the entries
func parseMediaRecord(p []byte, chunk uint32) ([]*Media, error) {
	if len(p) < 3 {
		return nil, ErrRecord
	}
	n := int(binary.BigEndian.Uint16(p[1:]))
	if n == 0 {
		return nil, ErrRecord
	}
	rest := p[3:]
	out := make([]*Media, 0, n)
	for i := 0; i < n; i++ {
		m, r, err := parseMedia(rest, chunk)
		if err != nil {
			return nil, err
		}
		out = append(out, m)
		rest = r
	}
	if len(rest) != 0 {
		return nil, ErrRecord
	}
	return out, nil
}

// a messages record: chat, count, then each row with its length
func parseMessagesRecord(p []byte) (uint32, [][]byte, error) {
	if len(p) < 1+4+2 {
		return 0, nil, ErrRecord
	}
	chat := binary.BigEndian.Uint32(p[1:])
	n := int(binary.BigEndian.Uint16(p[5:]))
	if n == 0 {
		return 0, nil, ErrRecord
	}
	rest := p[7:]
	rows := make([][]byte, 0, n)
	for i := 0; i < n; i++ {
		if len(rest) < 4 {
			return 0, nil, ErrRecord
		}
		l := binary.BigEndian.Uint32(rest)
		rest = rest[4:]
		if uint64(l) > uint64(len(rest)) || !rowOK(rest[:l], MaxRecord) {
			return 0, nil, ErrRecord
		}
		rows = append(rows, rest[:l:l])
		rest = rest[l:]
	}
	if len(rest) != 0 {
		return 0, nil, ErrRecord
	}
	return chat, rows, nil
}

func parseChatRecord(p []byte) (uint32, []byte, error) {
	if len(p) < 1+4 || !rowOK(p[5:], MaxMeta) {
		return 0, nil, ErrRecord
	}
	return binary.BigEndian.Uint32(p[1:]), p[5:], nil
}

func parseDataRecord(p []byte) (uint32, uint64, []byte, error) {
	if len(p) < dataHead || p[0] != kindData {
		return 0, 0, nil, ErrRecord
	}
	return binary.BigEndian.Uint32(p[1:]), binary.BigEndian.Uint64(p[5:]), p[dataHead:], nil
}

func parseGoneRecord(p []byte) (uint32, uint64, error) {
	if len(p) != goneSize {
		return 0, 0, ErrRecord
	}
	return binary.BigEndian.Uint32(p), binary.BigEndian.Uint64(p[4:]), nil
}
