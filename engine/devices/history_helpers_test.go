// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// a phone's history as the tests build it: chats, their rows, and files
// under a media folder
type histChat struct {
	meta  []byte
	rows  [][]byte
	files []string
}

type histWorld struct {
	t     testing.TB
	sh    *shim
	id    *identity
	key   *[StreamKeySize]byte
	bind  [32]byte
	root  string
	dir   string
	chats []histChat
	files map[string][]byte
	ats   map[string]int64
	opt   SendOptions
	s     *Sender
}

type histShape struct {
	chats, rows, files, size, chunk int
	skip                            bool
}

func newHistWorld(t testing.TB, sh histShape) *histWorld {
	t.Helper()
	w := &histWorld{t: t, sh: newShim(), files: map[string][]byte{}, ats: map[string]int64{}}
	w.id = w.sh.identity(t)
	k, err := NewStreamKey()
	if err != nil {
		t.Fatal(err)
	}
	w.key = k
	rand.Read(w.bind[:])
	w.dir = t.TempDir()
	w.root = filepath.Join(w.dir, "media")
	os.MkdirAll(w.root, 0o700)
	at := int64(1_700_000_000_000)
	for c := 0; c < sh.chats; c++ {
		hc := histChat{meta: fmt.Appendf(nil, `{"halo_id":"chat-%d","nickname":"Chat %d"}`, c, c)}
		// chats of different sizes, the first with none
		for m := 0; m < sh.rows*(c%3); m++ {
			hc.rows = append(hc.rows, fmt.Appendf(nil, `{"msg_uid":"u%d-%d","plaintext":"message %d of chat %d %s"}`, c, m, m, c, bytes.Repeat([]byte("x"), m%7*20)))
		}
		for f := 0; f < sh.files; f++ {
			name := fmt.Sprintf("c%d/f%d.jpg", c, f)
			size := (sh.size*(f+1) + c*13) % (sh.size*3 + 1)
			b := make([]byte, size)
			rand.Read(b)
			w.files[name] = b
			// newest first must sort across chats, not by chat
			w.ats[name] = at + int64((f*7+c*3)%11)*1000
			full := filepath.Join(w.root, filepath.FromSlash(name))
			os.MkdirAll(filepath.Dir(full), 0o700)
			if err := os.WriteFile(full, b, 0o600); err != nil {
				t.Fatal(err)
			}
			hc.files = append(hc.files, name)
		}
		w.chats = append(w.chats, hc)
	}
	w.opt = SendOptions{Spool: filepath.Join(w.dir, "spool"), Root: w.root, SkipMedia: sh.skip, Chunk: sh.chunk}
	return w
}

// builds and signs the sender
func (w *histWorld) send() *Sender {
	w.t.Helper()
	s, err := NewSender(w.key, w.bind, w.id.pub, w.opt)
	if err != nil {
		w.t.Fatal(err)
	}
	for _, c := range w.chats {
		n, err := s.Chat(c.meta)
		if err != nil {
			w.t.Fatal(err)
		}
		for _, r := range c.rows {
			if err := s.Message(r); err != nil {
				w.t.Fatal(err)
			}
		}
		if w.opt.SkipMedia {
			continue
		}
		for _, f := range c.files {
			if err := s.Media(n, w.ats[f], f); err != nil {
				w.t.Fatal(err)
			}
		}
	}
	if err := s.Plan(); err != nil {
		w.t.Fatal(err)
	}
	w.s = s
	w.t.Cleanup(func() { s.Close() })
	return s
}

func (w *histWorld) recv() *Receiver {
	w.t.Helper()
	return w.recvFor(w.s.ID())
}

func (w *histWorld) recvFor(id [IDSize]byte) *Receiver {
	w.t.Helper()
	r, err := NewReceiver(w.key, w.bind, id, w.id.pub)
	if err != nil {
		w.t.Fatal(err)
	}
	return r
}

func (w *histWorld) all() [][]byte {
	w.t.Helper()
	var out [][]byte
	for i := uint64(0); i < w.s.head.Records; i++ {
		b, err := w.s.Record(i)
		if err != nil {
			w.t.Fatal(err)
		}
		out = append(out, b)
	}
	return out
}

// what the app's database would hold, built from events alone
type histSink struct {
	head  *Head
	metas [][]byte
	rows  map[uint32][][]byte
	media []Media
	data  map[uint32][]byte
	ok    map[uint32]bool
	gone  map[uint32]bool
	kinds []EventKind
	files []uint32
	done  bool
	text  bool
}

func newSink() *histSink {
	return &histSink{rows: map[uint32][][]byte{}, data: map[uint32][]byte{}, ok: map[uint32]bool{}, gone: map[uint32]bool{}}
}

func (k *histSink) apply(t testing.TB, ev *Event) {
	t.Helper()
	k.kinds = append(k.kinds, ev.Kind)
	if ev.TextDone {
		k.text = true
	}
	switch ev.Kind {
	case EvHead:
		k.head = ev.Head
	case EvChat:
		if int(ev.Chat) != len(k.metas) {
			t.Fatalf("chat %d out of turn", ev.Chat)
		}
		k.metas = append(k.metas, bytes.Clone(ev.Meta))
	case EvMessages:
		for _, r := range ev.Rows {
			k.rows[ev.Chat] = append(k.rows[ev.Chat], bytes.Clone(r))
		}
	case EvMedia:
		if int(ev.First) != len(k.media) {
			t.Fatalf("media list part at %d, have %d", ev.First, len(k.media))
		}
		k.media = append(k.media, ev.Media...)
	case EvData:
		k.files = append(k.files, ev.File)
		// a file with a lost chunk is dropped, whatever follows of it
		if k.gone[ev.File] {
			if ev.Last && ev.Ok {
				t.Fatal("a file with a lost chunk said whole")
			}
			break
		}
		if uint64(len(k.data[ev.File])) != ev.Offset {
			t.Fatalf("file %d chunk at %d, have %d", ev.File, ev.Offset, len(k.data[ev.File]))
		}
		k.data[ev.File] = append(k.data[ev.File], ev.Bytes...)
		if ev.Last {
			k.ok[ev.File] = ev.Ok
		}
	case EvGone:
		k.files = append(k.files, ev.File)
		k.gone[ev.File] = true
		if ev.Last {
			k.ok[ev.File] = false
		}
	case EvEnd:
		k.done = true
	}
}

// the counts the app would find: rows per chat, and the files it holds whole
func (k *histSink) counts() []Count {
	out := make([]Count, len(k.metas))
	for c := range out {
		out[c].Messages = uint32(len(k.rows[uint32(c)]))
	}
	for i, m := range k.media {
		if k.ok[uint32(i)] {
			out[m.Chat].Media++
			out[m.Chat].MediaBytes += m.Size
		}
	}
	return out
}

// takes records from r's next index until upto (exclusive)
func pump(t testing.TB, recs [][]byte, r *Receiver, k *histSink, upto uint64) {
	t.Helper()
	for i := r.Next(); i < upto; i++ {
		ev, err := r.Take(recs[i])
		if err != nil {
			t.Fatalf("record %d: %v", i, err)
		}
		k.apply(t, ev)
	}
}

// the sink matches the phone's history exactly
func (w *histWorld) same(t testing.TB, k *histSink) {
	t.Helper()
	if !k.done || !k.text {
		t.Fatal("stream not whole")
	}
	if len(k.metas) != len(w.chats) {
		t.Fatalf("%d chats, want %d", len(k.metas), len(w.chats))
	}
	for c, hc := range w.chats {
		if !bytes.Equal(k.metas[c], hc.meta) {
			t.Fatalf("chat %d meta", c)
		}
		if got := k.rows[uint32(c)]; !reflect.DeepEqual(got, hc.rows) && !(len(got) == 0 && len(hc.rows) == 0) {
			t.Fatalf("chat %d rows: %d, want %d", c, len(got), len(hc.rows))
		}
	}
	want := 0
	if !w.opt.SkipMedia {
		want = len(w.files)
	}
	if len(k.media) != want {
		t.Fatalf("%d files, want %d", len(k.media), want)
	}
	for i, m := range k.media {
		if !bytes.Equal(k.data[uint32(i)], w.files[m.Name]) || !k.ok[uint32(i)] {
			t.Fatalf("file %s not whole", m.Name)
		}
		if int64(m.Size) != int64(len(w.files[m.Name])) || m.At != w.ats[m.Name] {
			t.Fatalf("file %s listed wrong", m.Name)
		}
	}
}

// a stream built by hand, for records a real sender never makes. the head
// is computed from what is given, so only the broken rule is broken
type forged struct {
	keys  *streamKeys
	head  *Head
	recs  [][]byte
	plain [][]byte
}

func forgeStream(t testing.TB, w *histWorld, chats []Count, text [][]byte, media []*Media, chunks [][]byte, skip bool) *forged {
	t.Helper()
	var id [IDSize]byte
	rand.Read(id[:])
	keys, err := newStreamKeys(w.key, w.bind, id)
	if err != nil {
		t.Fatal(err)
	}
	chunk := uint32(MinChunk)
	h := &Head{Identity: w.id.pub, Bind: w.bind, ID: id, SkipMedia: skip, Chunk: chunk, Text: uint64(len(text)), Chats: chats}
	th := newTextHash()
	tb := uint64(0)
	for i, p := range text {
		textHashUpdate(th, uint64(i+1), p)
		tb += sealedSize(len(p))
	}
	copy(h.TextHash[:], th.Sum(nil))
	data := uint64(0)
	bytes := sealedSize(headSize(len(chats))) + tb + sealedSize(0)
	for _, m := range media {
		c := m.Chunks(chunk)
		data += c
		bytes += uint64(dataHead+tagSize+recHeaderSize)*c + m.Size
		h.Files++
	}
	h.Records = h.Text + data + 2
	h.Bytes = bytes
	f := &forged{keys: keys, head: h}
	f.add(recHead, h.encode())
	for _, p := range text {
		f.add(recBody, p)
	}
	for _, p := range chunks {
		f.add(recBody, p)
	}
	f.add(recEnd, nil)
	return f
}

func (f *forged) add(typ byte, plain []byte) {
	f.recs = append(f.recs, f.keys.seal(uint64(len(f.recs)), typ, plain))
	f.plain = append(f.plain, plain)
}

func chatRec(n uint32, meta string) []byte {
	return append(binary.BigEndian.AppendUint32([]byte{kindChat}, n), meta...)
}

func msgsRec(chat uint32, rows ...string) []byte {
	b := binary.BigEndian.AppendUint32([]byte{kindMessages}, chat)
	b = binary.BigEndian.AppendUint16(b, uint16(len(rows)))
	for _, r := range rows {
		b = binary.BigEndian.AppendUint32(b, uint32(len(r)))
		b = append(b, r...)
	}
	return b
}

func mediaRec(chunk uint32, list ...*Media) []byte {
	b := binary.BigEndian.AppendUint16([]byte{kindMedia}, uint16(len(list)))
	for _, m := range list {
		if m.sums == nil {
			m.sums = make([][hashSize]byte, m.Chunks(chunk))
		}
		b = encodeMedia(b, m)
	}
	return b
}

// takes a forged stream until the first refusal, which it returns
func takeForged(t testing.TB, w *histWorld, f *forged) error {
	t.Helper()
	r := w.recvFor(f.head.ID)
	for i, rec := range f.recs {
		if _, err := r.Take(rec); err != nil {
			return fmt.Errorf("record %d: %w", i, err)
		}
	}
	if !r.Done() {
		return fmt.Errorf("not done")
	}
	return nil
}
