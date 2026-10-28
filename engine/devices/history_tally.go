// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"io"
)

// the tally goes the other way: the device's own counts after its import,
// sealed back to the phone under a key of the same stream, so the phone
// shows a mismatch too. a random nonce, as a device may send it twice.

func tallyPlain(head []byte, got []Count) []byte {
	sum := sha256.Sum256(head)
	b := append([]byte(tallyMagic), sum[:]...)
	b = binary.BigEndian.AppendUint32(b, uint32(len(got)))
	for _, c := range got {
		b = binary.BigEndian.AppendUint32(b, c.Messages)
		b = binary.BigEndian.AppendUint32(b, c.Media)
		b = binary.BigEndian.AppendUint64(b, c.MediaBytes)
	}
	return b
}

// Tally seals the counts the app found in its database, chat by chat in the
// head's order, for the phone.
func (r *Receiver) Tally(got []Count) ([]byte, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if !r.done || r.keys == nil {
		return nil, ErrState
	}
	if len(got) != len(r.head.Chats) {
		return nil, ErrTally
	}
	nonce := make([]byte, 12)
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	return r.keys.tally.Seal(nonce, nonce, tallyPlain(r.headPlain, got), []byte(tallyMagic)), nil
}

// CheckTally opens the device's tally and compares it with the head this
// phone signed. every chat that differs is returned.
func (s *Sender) CheckTally(b []byte) ([]Mismatch, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.closed {
		return nil, errClosed
	}
	if !s.signed {
		return nil, ErrState
	}
	if len(b) < 12+tagSize || len(b) > 12+tagSize+4+32+4+countSize*MaxChats {
		return nil, ErrTally
	}
	p, err := s.keys.tally.Open(nil, b[:12], b[12:], []byte(tallyMagic))
	if err != nil {
		return nil, ErrTally
	}
	want := s.head.Chats
	if len(p) != 4+32+4+countSize*len(want) {
		return nil, ErrTally
	}
	sum := sha256.Sum256(s.head.encode())
	if string(p[:4]) != tallyMagic || string(p[4:36]) != string(sum[:]) ||
		binary.BigEndian.Uint32(p[36:]) != uint32(len(want)) {
		return nil, ErrTally
	}
	got := make([]Count, len(want))
	at := 40
	for i := range got {
		got[i] = Count{
			Messages:   binary.BigEndian.Uint32(p[at:]),
			Media:      binary.BigEndian.Uint32(p[at+4:]),
			MediaBytes: binary.BigEndian.Uint64(p[at+8:]),
		}
		at += countSize
	}
	return compareCounts(want, got)
}
