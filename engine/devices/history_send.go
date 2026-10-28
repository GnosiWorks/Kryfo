// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"io"
	"os"
	"path/filepath"
	"sort"
	"sync"
)

// SendOptions says where the sender keeps its text and reads its media.
type SendOptions struct {
	// Spool is a new file for the sealed text records, so a resent record
	// is the same bytes and memory stays flat
	Spool string
	// Root is the folder media names are read under
	Root      string
	SkipMedia bool
	// Chunk is the media chunk size, DefaultChunk when zero
	Chunk int
}

// Sender builds a stream once and then serves any record of it, as often as
// a cut transfer asks for it.
type Sender struct {
	mu       sync.RWMutex
	keys     *streamKeys
	identity Key
	bind     [32]byte
	opt      SendOptions
	chunk    uint32

	spool   *os.File
	offs    []int64 // where text record i+1 starts in the spool
	lens    []int32
	spoolAt int64
	next    uint64
	text    interface {
		Write([]byte) (int, error)
		Sum([]byte) []byte
	}
	textBytes uint64

	counts []Count
	cur    int // the chat taking messages, -1 before the first
	batch  []byte
	nrows  int

	media []*Media
	names map[string]bool
	// first data record of each file, by its place in the list
	starts []uint64

	head    *Head
	sealed0 []byte
	signed  bool
	closed  bool
	// Skipped counts files the phone could not read while planning
	Skipped int
}

var errClosed = errors.New("devices: history sender closed")

func NewSender(key *[StreamKeySize]byte, bind [32]byte, identity Key, opt SendOptions) (*Sender, error) {
	if _, err := ParseKey(identity[:]); err != nil {
		return nil, err
	}
	chunk := opt.Chunk
	if chunk == 0 {
		chunk = DefaultChunk
	}
	if chunk < MinChunk || chunk > MaxChunk || opt.Spool == "" {
		return nil, ErrUsable
	}
	keys, err := newStreamKeys(key, bind)
	if err != nil {
		return nil, err
	}
	f, err := os.OpenFile(opt.Spool, os.O_RDWR|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return nil, err
	}
	return &Sender{
		keys: keys, identity: identity, bind: bind, opt: opt, chunk: uint32(chunk),
		spool: f, next: 1, text: newTextHash(), cur: -1, names: map[string]bool{},
	}, nil
}

func (s *Sender) planned() bool { return s.head != nil }

// seals the next text record into the spool
func (s *Sender) put(plain []byte) error {
	if len(plain) > MaxRecord {
		return ErrUsable
	}
	rec := s.keys.seal(s.next, recBody, plain)
	if _, err := s.spool.WriteAt(rec, s.spoolAt); err != nil {
		return err
	}
	textHashUpdate(s.text, s.next, plain)
	s.offs = append(s.offs, s.spoolAt)
	s.lens = append(s.lens, int32(len(rec)))
	s.spoolAt += int64(len(rec))
	s.textBytes += uint64(len(rec))
	s.next++
	return nil
}

func (s *Sender) flush() error {
	if s.nrows == 0 {
		return nil
	}
	binary.BigEndian.PutUint16(s.batch[5:], uint16(s.nrows))
	err := s.put(s.batch)
	s.batch, s.nrows = s.batch[:0], 0
	return err
}

// Chat starts a chat. meta is its row as a json object; the messages added
// after it are its own.
func (s *Sender) Chat(meta []byte) (uint32, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return 0, errClosed
	}
	if s.planned() {
		return 0, ErrPlanned
	}
	if !rowOK(meta, MaxMeta) || len(s.counts) >= MaxChats {
		return 0, ErrUsable
	}
	if err := s.flush(); err != nil {
		return 0, err
	}
	n := uint32(len(s.counts))
	p := append([]byte{kindChat}, binary.BigEndian.AppendUint32(nil, n)...)
	if err := s.put(append(p, meta...)); err != nil {
		return 0, err
	}
	s.counts = append(s.counts, Count{})
	s.cur = int(n)
	return n, nil
}

// the most a row may take: one row alone in a messages record
const maxRow = MaxRecord - 7 - 4

// Message adds a message of the chat started last, its row a json object.
func (s *Sender) Message(row []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return errClosed
	}
	if s.planned() {
		return ErrPlanned
	}
	if s.cur < 0 || !rowOK(row, maxRow) || s.counts[s.cur].Messages == ^uint32(0) {
		return ErrUsable
	}
	// a full batch goes before the row that would overfill it
	if s.nrows > 0 && (len(s.batch)+4+len(row) > int(s.chunk) || s.nrows == 0xffff) {
		if err := s.flush(); err != nil {
			return err
		}
	}
	if s.nrows == 0 {
		s.batch = append(s.batch[:0], kindMessages)
		s.batch = binary.BigEndian.AppendUint32(s.batch, uint32(s.cur))
		s.batch = append(s.batch, 0, 0)
	}
	s.batch = binary.BigEndian.AppendUint32(s.batch, uint32(len(row)))
	s.batch = append(s.batch, row...)
	s.nrows++
	s.counts[s.cur].Messages++
	return nil
}

// Media adds a file under Root to go with a chat; at orders the files,
// newest first. refused when the stream skips media.
func (s *Sender) Media(chat uint32, at int64, name string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return errClosed
	}
	if s.planned() {
		return ErrPlanned
	}
	if s.opt.SkipMedia || int(chat) >= len(s.counts) || !safeName(name) || s.names[name] {
		return ErrUsable
	}
	s.names[name] = true
	s.media = append(s.media, &Media{Chat: chat, At: at, Name: name})
	return nil
}

func (s *Sender) path(name string) string {
	return filepath.Join(s.opt.Root, filepath.FromSlash(name))
}

// reads a file once for its size and chunk hashes. false when it cannot be
// read whole or its hashes would not fit one record
func (s *Sender) measure(m *Media, buf []byte) bool {
	f, err := os.Open(s.path(m.Name))
	if err != nil {
		return false
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil || !st.Mode().IsRegular() || st.Size() < 0 {
		return false
	}
	m.Size = uint64(st.Size())
	c := chunksOf(m.Size, s.chunk)
	if c > MaxRecord/hashSize || 3+mediaFixed+len(m.Name)+int(c)*hashSize > MaxRecord {
		return false
	}
	m.sums = make([][hashSize]byte, c)
	for i := range m.sums {
		n := chunkLen(m.Size, s.chunk, uint64(i))
		if _, err := io.ReadFull(f, buf[:n]); err != nil {
			return false
		}
		m.sums[i] = sha256.Sum256(buf[:n])
	}
	return true
}

func chunkLen(size uint64, chunk uint32, i uint64) int {
	off := i * uint64(chunk)
	if off >= size {
		return 0
	}
	if size-off < uint64(chunk) {
		return int(size - off)
	}
	return int(chunk)
}

// Plan closes the text, reads each file once for its hashes, seals the
// media list newest first, and gives the head's body for the identity to
// sign. files that cannot be read are left out and counted in Skipped.
func (s *Sender) Plan() ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return nil, errClosed
	}
	if s.planned() {
		return nil, ErrPlanned
	}
	if err := s.flush(); err != nil {
		return nil, err
	}
	buf := make([]byte, s.chunk)
	kept := s.media[:0]
	for _, m := range s.media {
		if s.measure(m, buf) {
			kept = append(kept, m)
		} else {
			s.Skipped++
		}
	}
	s.media = kept
	sort.SliceStable(s.media, func(i, j int) bool { return s.media[i].At > s.media[j].At })
	// the list in records of about one chunk each
	var rec []byte
	n := 0
	flushList := func() error {
		if n == 0 {
			return nil
		}
		binary.BigEndian.PutUint16(rec[1:], uint16(n))
		err := s.put(rec)
		rec, n = nil, 0
		return err
	}
	for _, m := range s.media {
		if n > 0 && (len(rec)+mediaSize(m) > int(s.chunk) || n == 0xffff) {
			if err := flushList(); err != nil {
				return nil, err
			}
		}
		if n == 0 {
			rec = []byte{kindMedia, 0, 0}
		}
		rec = encodeMedia(rec, m)
		n++
	}
	if err := flushList(); err != nil {
		return nil, err
	}
	if err := s.spool.Sync(); err != nil {
		return nil, err
	}
	h := &Head{
		Identity: s.identity, Bind: s.bind, SkipMedia: s.opt.SkipMedia, Chunk: s.chunk,
		Text: s.next - 1, Files: uint32(len(s.media)), Chats: append([]Count(nil), s.counts...),
	}
	copy(h.TextHash[:], s.text.Sum(nil))
	data := uint64(0)
	bytes := sealedSize(headSize(len(s.counts))) + s.textBytes + sealedSize(0)
	for _, m := range s.media {
		s.starts = append(s.starts, h.Text+1+data)
		c := m.Chunks(s.chunk)
		data += c
		bytes += uint64(dataHead+tagSize+recHeaderSize)*c + m.Size
		h.Chats[m.Chat].Media++
		h.Chats[m.Chat].MediaBytes += m.Size
	}
	h.Records = h.Text + data + 2
	h.Bytes = bytes
	s.head = h
	return h.Body(), nil
}

// Signed takes the identity's signature over the body Plan gave.
func (s *Sender) Signed(sig []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return errClosed
	}
	if !s.planned() || s.signed || len(sig) != SigSize {
		return ErrState
	}
	s.head.Sig = append([]byte(nil), sig...)
	s.sealed0 = s.keys.seal(0, recHead, s.head.encode())
	s.signed = true
	return nil
}

// Sign plans and signs in one go, for a signer the engine holds.
func (s *Sender) Sign(sg Signer) error {
	if sg.Public() != s.identity {
		return ErrWrongIdentity
	}
	body, err := s.Plan()
	if err != nil {
		return err
	}
	sig, err := sg.Sign(ContextHistory, body)
	if err != nil {
		return err
	}
	return s.Signed(sig)
}

// Head is a copy of the planned head.
func (s *Sender) Head() (Head, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if !s.planned() {
		return Head{}, ErrState
	}
	h := *s.head
	h.Chats = append([]Count(nil), h.Chats...)
	h.Sig = append([]byte(nil), h.Sig...)
	return h, nil
}

// Record is record i, framed and sealed. a text record is the spool's
// bytes; a media chunk is read again and checked against its hash, and one
// that changed goes as a gone record. safe to call from several goroutines.
func (s *Sender) Record(i uint64) ([]byte, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.closed {
		return nil, errClosed
	}
	if !s.signed {
		return nil, ErrState
	}
	h := s.head
	switch {
	case i == 0:
		return append([]byte(nil), s.sealed0...), nil
	case i <= h.Text:
		out := make([]byte, s.lens[i-1])
		if _, err := s.spool.ReadAt(out, s.offs[i-1]); err != nil {
			return nil, err
		}
		return out, nil
	case i == h.Records-1:
		return s.keys.seal(i, recEnd, nil), nil
	case i < h.Records-1:
		k := sort.Search(len(s.starts), func(k int) bool { return s.starts[k] > i }) - 1
		m := s.media[k]
		c := i - s.starts[k]
		return s.chunkRecord(i, uint32(k), m, c), nil
	}
	return nil, ErrRecord
}

func (s *Sender) chunkRecord(i uint64, k uint32, m *Media, c uint64) []byte {
	off := c * uint64(s.chunk)
	n := chunkLen(m.Size, s.chunk, c)
	plain := make([]byte, dataHead+n)
	plain[0] = kindData
	binary.BigEndian.PutUint32(plain[1:], k)
	binary.BigEndian.PutUint64(plain[5:], off)
	if s.readChunk(m, off, plain[dataHead:]) {
		return s.keys.seal(i, recBody, plain)
	}
	return s.keys.seal(i, recGone, plain[1:dataHead])
}

// true when the chunk reads whole and is still what was planned
func (s *Sender) readChunk(m *Media, off uint64, dst []byte) bool {
	f, err := os.Open(s.path(m.Name))
	if err != nil {
		return false
	}
	defer f.Close()
	if st, err := f.Stat(); err != nil || uint64(st.Size()) != m.Size {
		return false
	}
	if n, _ := f.ReadAt(dst, int64(off)); n != len(dst) {
		return false
	}
	return sha256.Sum256(dst) == m.sums[off/uint64(s.chunk)]
}

// Close forgets the keys and removes the spool.
func (s *Sender) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return nil
	}
	s.closed = true
	s.keys = nil
	s.sealed0 = nil
	err := s.spool.Close()
	if e := os.Remove(s.opt.Spool); err == nil {
		err = e
	}
	return err
}
