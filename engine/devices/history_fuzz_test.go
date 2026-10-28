// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"encoding/binary"
	"testing"
)

func FuzzHistoryHead(f *testing.F) {
	w := newHistWorld(f, smallShape)
	w.send()
	f.Add(w.s.head.encode())
	f.Add([]byte(headMagic))
	f.Fuzz(func(t *testing.T, b []byte) {
		h, err := ParseHead(b)
		if err != nil {
			return
		}
		// one encoding only
		if !bytes.Equal(h.encode(), b) {
			t.Fatal("a head parsed from bytes it does not encode to")
		}
	})
}

// the text records' parsers, past the seal
func FuzzHistoryText(f *testing.F) {
	f.Add(chatRec(3, `{"a":1}`))
	f.Add(msgsRec(1, `{"a":1}`, `{}`))
	f.Add(mediaRec(MinChunk, &Media{Chat: 1, At: 7, Size: 5000, Name: "a/b.jpg"}))
	f.Fuzz(func(t *testing.T, p []byte) {
		if len(p) == 0 {
			return
		}
		switch p[0] {
		case kindChat:
			n, meta, err := parseChatRecord(p)
			if err == nil && !bytes.Equal(chatRec(n, string(meta)), p) {
				t.Fatal("chat record round trip")
			}
		case kindMessages:
			chat, rows, err := parseMessagesRecord(p)
			if err == nil {
				s := make([]string, len(rows))
				for i, r := range rows {
					s[i] = string(r)
				}
				if !bytes.Equal(msgsRec(chat, s...), p) {
					t.Fatal("messages record round trip")
				}
			}
		case kindMedia:
			list, err := parseMediaRecord(p, MinChunk)
			if err == nil {
				b := binary.BigEndian.AppendUint16([]byte{kindMedia}, uint16(len(list)))
				for _, m := range list {
					if !safeName(m.Name) {
						t.Fatal("an unsafe name parsed")
					}
					b = encodeMedia(b, m)
				}
				if !bytes.Equal(b, p) {
					t.Fatal("media record round trip")
				}
			}
		case kindData:
			parseDataRecord(p)
		}
		parseGoneRecord(p)
	})
}

// any plaintext sealed at the receiver's next place, in the text or among
// the chunks: refused or taken, never a panic, and never a file outside
// its plan
func FuzzHistoryTake(f *testing.F) {
	w := newHistWorld(f, smallShape)
	w.send()
	recs := w.all()
	text := w.s.head.Text
	f.Add(uint8(2), byte(recBody), chatRec(1, `{}`))
	f.Add(uint8(text), byte(recBody), mediaRec(MinChunk, &Media{At: 1, Size: 3, Name: "x"}))
	f.Add(uint8(text+1), byte(recGone), make([]byte, goneSize))
	f.Add(uint8(len(recs)-1), byte(recEnd), []byte{})
	keys, _ := newStreamKeys(w.key, w.bind)
	f.Fuzz(func(t *testing.T, at uint8, typ byte, p []byte) {
		if len(p) > MaxRecord {
			return
		}
		r, _ := NewReceiver(w.key, w.bind, w.id.pub)
		k := newSink()
		upto := 1 + uint64(at)%uint64(len(recs)-1)
		pump(t, recs, r, k, w.sh, upto)
		ev, err := r.Take(keys.seal(upto, typ, p))
		if err != nil {
			return
		}
		if ev.Kind == EvData && (int(ev.File) >= len(w.s.media) || ev.Offset >= w.s.media[ev.File].Size+1) {
			t.Fatal("a chunk outside the plan")
		}
	})
}

// any stored plan and state: refused, or a receiver that goes on safely
func FuzzHistoryResume(f *testing.F) {
	w := newHistWorld(f, smallShape)
	w.send()
	recs := w.all()
	r := w.recv()
	pump(f, recs, r, newSink(), w.sh, w.s.head.Text+2)
	plan, _ := r.Plan()
	st, _ := r.State()
	f.Add(plan, st)
	f.Fuzz(func(t *testing.T, plan, st []byte) {
		r, err := ResumeReceiver(w.key, w.bind, w.id.pub, plan, st)
		if err != nil {
			return
		}
		for i := r.Next(); i < uint64(len(recs)) && !r.Done(); i++ {
			if _, err := r.Take(recs[i]); err != nil {
				return
			}
		}
		r.State()
		r.Plan()
		r.Check(make([]Count, len(w.chats)))
	})
}

func FuzzHistoryTally(f *testing.F) {
	w := newHistWorld(f, smallShape)
	s := w.send()
	recs := w.all()
	r := w.recv()
	k := newSink()
	pump(f, recs, r, k, w.sh, uint64(len(recs)))
	tl, _ := r.Tally(k.counts())
	f.Add(tl)
	f.Add(tallyPlain(s.head.encode(), k.counts()))
	f.Fuzz(func(t *testing.T, b []byte) {
		s.CheckTally(b)
		// past the seal too
		nonce := make([]byte, 12)
		s.CheckTally(s.keys.tally.Seal(nonce, nonce, b, []byte(tallyMagic)))
	})
}
