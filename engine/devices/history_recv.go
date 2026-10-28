// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/sha256"
	"encoding"
	"encoding/binary"
	"hash"
	"sync"
)

// EventKind says what a record brought.
type EventKind int

const (
	EvHead EventKind = iota + 1
	EvChat
	EvMessages
	EvMedia
	EvData
	EvGone
	EvEnd
)

// Event is one record's contents, for the app to put in its database.
type Event struct {
	Kind  EventKind
	Index uint64
	Head  *Head
	Chat  uint32
	Meta  []byte
	Rows  [][]byte
	// a media list part: its files, the first numbered First
	Media []Media
	First uint32
	// a chunk of file File at Offset. Last is its final chunk, and Ok says
	// with it that every chunk of the file came as planned
	File   uint32
	Offset uint64
	Bytes  []byte
	Last   bool
	Ok     bool
	// the text is whole and matches the signed head
	TextDone bool
	// Plan changed and is kept again with State
	PlanChanged bool
}

// Receiver takes a stream one record at a time, each only at its own index.
// a record that does not open changes nothing and may be sent again; a
// record that opens but breaks the plan fails the stream for good.
type Receiver struct {
	mu        sync.Mutex
	keys      *streamKeys
	identity  Key
	bind      [32]byte
	id        [IDSize]byte
	head      *Head
	headPlain []byte
	next      uint64
	text      hash.Hash
	textBytes uint64
	chats     uint32
	curMsgs   uint32
	media     []*Media
	names     map[string]bool
	starts    []uint64
	failed    bool
	done      bool
	broken    error
}

// NewReceiver takes the stream of the sender whose stream id is id, as the
// phone gives it with its first answer.
func NewReceiver(key *[StreamKeySize]byte, bind [32]byte, id [IDSize]byte, identity Key) (*Receiver, error) {
	if _, err := ParseKey(identity[:]); err != nil {
		return nil, err
	}
	keys, err := newStreamKeys(key, bind, id)
	if err != nil {
		return nil, err
	}
	return &Receiver{keys: keys, identity: identity, bind: bind, id: id, text: newTextHash().(hash.Hash), names: map[string]bool{}}, nil
}

// Next is the index the receiver takes next: where a cut transfer resumes.
func (r *Receiver) Next() uint64 {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.next
}

// Done is true once the end record came.
func (r *Receiver) Done() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.done
}

// Head is the head taken, nil before it.
func (r *Receiver) Head() *Head {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.head == nil {
		return nil
	}
	h := *r.head
	h.Chats = append([]Count(nil), h.Chats...)
	return &h
}

// Broken is why the stream failed for good, nil while it may go on.
func (r *Receiver) Broken() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.broken
}

func (r *Receiver) fail(err error) error {
	r.broken = err
	return err
}

// Take checks record rec as the next one and gives what it holds.
func (r *Receiver) Take(rec []byte) (*Event, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.broken != nil {
		return nil, r.broken
	}
	if r.done {
		return nil, ErrDone
	}
	typ, p, err := r.keys.open(r.next, rec)
	if err != nil {
		return nil, err
	}
	ev := &Event{Index: r.next}
	switch h := r.head; {
	case h == nil:
		err = r.takeHead(typ, p, ev)
	case r.next <= h.Text:
		err = r.takeText(typ, p, ev)
	case r.next < h.Records-1:
		err = r.takeChunk(typ, p, ev)
	default:
		if typ != recEnd || len(p) != 0 {
			err = ErrRecord
		}
		ev.Kind = EvEnd
		r.done = true
	}
	if err != nil {
		return nil, r.fail(err)
	}
	r.next++
	if r.head != nil && r.next == r.head.Text+1 {
		if err := r.finishText(); err != nil {
			return nil, r.fail(err)
		}
		ev.TextDone = true
	}
	return ev, nil
}

func (r *Receiver) takeHead(typ byte, p []byte, ev *Event) error {
	if typ != recHead {
		return ErrRecord
	}
	h, err := ParseHead(p)
	if err != nil {
		return err
	}
	if h.Identity != r.identity || h.Bind != r.bind || h.ID != r.id {
		return ErrHead
	}
	r.head, r.headPlain = h, append([]byte(nil), p...)
	ev.Kind, ev.PlanChanged = EvHead, true
	hc := *h
	hc.Chats = append([]Count(nil), h.Chats...)
	ev.Head = &hc
	return nil
}

func (r *Receiver) takeText(typ byte, p []byte, ev *Event) error {
	h := r.head
	if typ != recBody || len(p) == 0 {
		return ErrRecord
	}
	switch p[0] {
	case kindChat:
		n, meta, err := parseChatRecord(p)
		if err != nil {
			return err
		}
		if n != r.chats || int(n) >= len(h.Chats) || len(r.media) > 0 {
			return ErrRecord
		}
		if n > 0 && r.curMsgs != h.Chats[n-1].Messages {
			return ErrText
		}
		r.chats++
		r.curMsgs = 0
		ev.Kind, ev.Chat, ev.Meta = EvChat, n, meta
	case kindMessages:
		chat, rows, err := parseMessagesRecord(p)
		if err != nil {
			return err
		}
		if r.chats == 0 || chat != r.chats-1 || len(r.media) > 0 {
			return ErrRecord
		}
		if uint64(r.curMsgs)+uint64(len(rows)) > uint64(h.Chats[chat].Messages) {
			return ErrText
		}
		r.curMsgs += uint32(len(rows))
		ev.Kind, ev.Chat, ev.Rows = EvMessages, chat, rows
	case kindMedia:
		list, err := parseMediaRecord(p, h.Chunk)
		if err != nil {
			return err
		}
		// every chat and its messages come before the list
		if int(r.chats) != len(h.Chats) || (r.chats > 0 && r.curMsgs != h.Chats[r.chats-1].Messages) {
			return ErrText
		}
		if uint64(len(r.media))+uint64(len(list)) > uint64(h.Files) {
			return ErrText
		}
		if err := r.addMedia(list); err != nil {
			return err
		}
		ev.Kind, ev.First, ev.PlanChanged = EvMedia, uint32(len(r.media)-len(list)), true
		for _, m := range list {
			ev.Media = append(ev.Media, Media{Chat: m.Chat, At: m.At, Size: m.Size, Name: m.Name})
		}
	default:
		return ErrRecord
	}
	textHashUpdate(r.text, r.next, p)
	r.textBytes += sealedSize(len(p))
	return nil
}

// files join the list only newest first, each name once, each in a chat
func (r *Receiver) addMedia(list []*Media) error {
	for i, m := range list {
		if int(m.Chat) >= len(r.head.Chats) || r.names[m.Name] {
			return ErrRecord
		}
		prev := (*Media)(nil)
		if i > 0 {
			prev = list[i-1]
		} else if len(r.media) > 0 {
			prev = r.media[len(r.media)-1]
		}
		if prev != nil && m.At > prev.At {
			return ErrRecord
		}
		for _, q := range list[:i] {
			if q.Name == m.Name {
				return ErrRecord
			}
		}
	}
	for _, m := range list {
		r.names[m.Name] = true
		r.media = append(r.media, m)
	}
	return nil
}

// the text is all in: its counts, its hash and the plan's size must be the
// head's, and the media chunks get their places
func (r *Receiver) finishText() error {
	h := r.head
	if int(r.chats) != len(h.Chats) || uint64(len(r.media)) != uint64(h.Files) {
		return ErrText
	}
	if r.chats > 0 && r.curMsgs != h.Chats[r.chats-1].Messages {
		return ErrText
	}
	got := make([]Count, len(h.Chats))
	for i := range got {
		got[i].Messages = h.Chats[i].Messages
	}
	data := uint64(0)
	bytes := sealedSize(len(r.headPlain)) + r.textBytes + sealedSize(0)
	r.starts = r.starts[:0]
	for _, m := range r.media {
		r.starts = append(r.starts, h.Text+1+data)
		c := m.Chunks(h.Chunk)
		data += c
		bytes += uint64(dataHead+tagSize+recHeaderSize)*c + m.Size
		got[m.Chat].Media++
		got[m.Chat].MediaBytes += m.Size
	}
	for i := range got {
		if !got[i].sameAs(h.Chats[i]) {
			return ErrText
		}
	}
	if h.Records != h.Text+data+2 || h.Bytes != bytes {
		return ErrText
	}
	var sum [32]byte
	copy(sum[:], r.text.Sum(nil))
	if sum != h.TextHash {
		return ErrText
	}
	return nil
}

// which file and chunk record i carries
func (r *Receiver) place(i uint64) (uint32, *Media, uint64) {
	lo, hi := 0, len(r.starts)
	for lo+1 < hi {
		mid := (lo + hi) / 2
		if r.starts[mid] <= i {
			lo = mid
		} else {
			hi = mid
		}
	}
	return uint32(lo), r.media[lo], i - r.starts[lo]
}

func (r *Receiver) takeChunk(typ byte, p []byte, ev *Event) error {
	h := r.head
	k, m, c := r.place(r.next)
	off := c * uint64(h.Chunk)
	last := c == m.Chunks(h.Chunk)-1
	failed := r.failed && c > 0
	switch typ {
	case recBody:
		file, at, data, err := parseDataRecord(p)
		if err != nil || file != k || at != off || len(data) != chunkLen(m.Size, h.Chunk, c) {
			return ErrRecord
		}
		if sha256.Sum256(data) != m.sums[c] {
			return ErrRecord
		}
		ev.Kind, ev.Bytes = EvData, data
	case recGone:
		file, at, err := parseGoneRecord(p)
		if err != nil || file != k || at != off {
			return ErrRecord
		}
		ev.Kind = EvGone
		failed = true
	default:
		return ErrRecord
	}
	r.failed = failed
	ev.File, ev.Offset, ev.Last = k, off, last
	ev.Ok = last && !failed
	return nil
}

// Plan is what the receiver keeps of the head and the media list, stored
// again whenever an event says PlanChanged.
func (r *Receiver) Plan() ([]byte, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.head == nil {
		return nil, ErrState
	}
	b := []byte(planMagic)
	b = binary.BigEndian.AppendUint32(b, uint32(len(r.headPlain)))
	b = append(b, r.headPlain...)
	b = binary.BigEndian.AppendUint32(b, uint32(len(r.media)))
	for _, m := range r.media {
		b = encodeMedia(b, m)
	}
	return b, nil
}

const (
	hsFailed = 2
	hsDone   = 4
)

// State is the receiver's place in the stream, small enough to store with
// every record the app takes in, in the same transaction.
func (r *Receiver) State() ([]byte, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.head == nil || r.broken != nil {
		return nil, ErrState
	}
	hs, err := r.text.(encoding.BinaryMarshaler).MarshalBinary()
	if err != nil {
		return nil, err
	}
	var f byte
	if r.failed {
		f |= hsFailed
	}
	if r.done {
		f |= hsDone
	}
	b := append([]byte(stateMagic), f)
	b = binary.BigEndian.AppendUint64(b, r.next)
	b = binary.BigEndian.AppendUint64(b, r.textBytes)
	b = binary.BigEndian.AppendUint32(b, r.chats)
	b = binary.BigEndian.AppendUint32(b, r.curMsgs)
	b = binary.BigEndian.AppendUint32(b, uint32(len(r.media)))
	b = binary.BigEndian.AppendUint16(b, uint16(len(hs)))
	return append(b, hs...), nil
}

// ResumeReceiver takes up a stream where State left it, with the Plan kept
// beside it. both are checked as strictly as the records were.
func ResumeReceiver(key *[StreamKeySize]byte, bind [32]byte, id [IDSize]byte, identity Key, plan, state []byte) (*Receiver, error) {
	r, err := NewReceiver(key, bind, id, identity)
	if err != nil {
		return nil, err
	}
	if len(plan) < 8 || string(plan[:4]) != planMagic {
		return nil, ErrState
	}
	hl := binary.BigEndian.Uint32(plan[4:])
	rest := plan[8:]
	if uint64(hl) > uint64(len(rest)) || hl > MaxRecord {
		return nil, ErrState
	}
	h, err := ParseHead(rest[:hl])
	if err != nil || h.Identity != identity || h.Bind != bind || h.ID != id {
		return nil, ErrState
	}
	r.head, r.headPlain = h, append([]byte(nil), rest[:hl]...)
	rest = rest[hl:]
	if len(rest) < 4 {
		return nil, ErrState
	}
	nm := binary.BigEndian.Uint32(rest)
	rest = rest[4:]
	if uint64(nm) > uint64(h.Files) {
		return nil, ErrState
	}
	list := make([]*Media, 0, nm)
	for i := uint32(0); i < nm; i++ {
		m, more, err := parseMedia(rest, h.Chunk)
		if err != nil {
			return nil, ErrState
		}
		list = append(list, m)
		rest = more
	}
	if len(rest) != 0 {
		return nil, ErrState
	}
	if len(list) > 0 {
		if err := r.addMedia(list); err != nil {
			return nil, ErrState
		}
	}
	const fixed = 4 + 1 + 8 + 8 + 4 + 4 + 4 + 2
	if len(state) < fixed || string(state[:4]) != stateMagic {
		return nil, ErrState
	}
	f := state[4]
	if f&^(hsFailed|hsDone) != 0 {
		return nil, ErrState
	}
	r.failed = f&hsFailed != 0
	r.done = f&hsDone != 0
	r.next = binary.BigEndian.Uint64(state[5:])
	r.textBytes = binary.BigEndian.Uint64(state[13:])
	r.chats = binary.BigEndian.Uint32(state[21:])
	r.curMsgs = binary.BigEndian.Uint32(state[25:])
	sm := binary.BigEndian.Uint32(state[29:])
	hl2 := int(binary.BigEndian.Uint16(state[33:]))
	if len(state) != fixed+hl2 || sm != nm {
		return nil, ErrState
	}
	if err := r.text.(encoding.BinaryUnmarshaler).UnmarshalBinary(state[fixed:]); err != nil {
		return nil, ErrState
	}
	// the place must be one the records could have left
	switch {
	case r.next < 1 || r.next > h.Records || (r.done != (r.next == h.Records)):
		return nil, ErrState
	case int(r.chats) > len(h.Chats) || (r.chats > 0 && r.curMsgs > h.Chats[r.chats-1].Messages) || (r.chats == 0 && r.curMsgs != 0):
		return nil, ErrState
	case r.next <= h.Text && r.failed:
		return nil, ErrState
	case r.textBytes > h.Bytes:
		return nil, ErrState
	}
	if r.next > h.Text {
		if err := r.finishText(); err != nil {
			return nil, ErrState
		}
	}
	return r, nil
}

// Mismatch is a chat whose count on the device is not the head's.
type Mismatch struct {
	Chat      uint32
	Want, Got Count
}

// Check compares what the app counts in its database once the stream is
// whole with what the head promised, chat by chat: messages, files and
// their bytes. every difference is returned; none means nothing was lost
// or doubled on the way. what the phone left out is in the head's counts.
func (r *Receiver) Check(got []Count) ([]Mismatch, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if !r.done {
		return nil, ErrState
	}
	return compareCounts(r.head.Chats, got)
}

func compareCounts(want, got []Count) ([]Mismatch, error) {
	if len(got) != len(want) {
		return nil, ErrTally
	}
	var out []Mismatch
	for i := range want {
		if !want[i].sameAs(got[i]) {
			out = append(out, Mismatch{Chat: uint32(i), Want: want[i], Got: got[i]})
		}
	}
	return out, nil
}

// Close forgets the keys.
func (r *Receiver) Close() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.keys = nil
	r.broken = ErrDone
}
