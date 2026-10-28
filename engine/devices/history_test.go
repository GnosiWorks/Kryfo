// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"sync"
	"testing"
)

var smallShape = histShape{chats: 5, rows: 9, files: 2, size: 2500, chunk: MinChunk}

func TestHistoryRoundTrip(t *testing.T) {
	w := newHistWorld(t, histShape{chats: 7, rows: 40, files: 3, size: 3000, chunk: MinChunk})
	s := w.send()
	recs := w.all()
	r := w.recv()
	k := newSink()
	pump(t, recs, r, k, w.sh, uint64(len(recs)))
	w.same(t, k)
	if !r.Done() {
		t.Fatal("not done")
	}
	h, _ := s.Head()
	var size uint64
	for _, b := range recs {
		size += uint64(len(b))
	}
	if h.Bytes != size {
		t.Fatalf("head says %d bytes, stream is %d", h.Bytes, size)
	}
	mm, err := r.Check(k.counts())
	if err != nil || len(mm) != 0 {
		t.Fatalf("check: %v %v", mm, err)
	}
	tally, err := r.Tally(k.counts())
	if err != nil {
		t.Fatal(err)
	}
	mm, err = s.CheckTally(tally)
	if err != nil || len(mm) != 0 {
		t.Fatalf("tally: %v %v", mm, err)
	}
	if _, err := r.Take(recs[len(recs)-1]); !errors.Is(err, ErrDone) {
		t.Fatalf("a record after the end: %v", err)
	}
}

// text first, then the files newest first across every chat
func TestHistoryOrder(t *testing.T) {
	w := newHistWorld(t, histShape{chats: 6, rows: 5, files: 4, size: 1500, chunk: MinChunk})
	w.send()
	recs := w.all()
	k := newSink()
	pump(t, recs, w.recv(), k, w.sh, uint64(len(recs)))
	seenData := false
	for _, kind := range k.kinds {
		switch kind {
		case EvData, EvGone:
			seenData = true
		case EvChat, EvMessages, EvMedia:
			if seenData {
				t.Fatal("text after media")
			}
		}
	}
	for i := 1; i < len(k.media); i++ {
		if k.media[i].At > k.media[i-1].At {
			t.Fatalf("file %d newer than the one before it", i)
		}
	}
	// the files reach the device in the list's order, each whole before the next
	for i := 1; i < len(k.files); i++ {
		if k.files[i] < k.files[i-1] {
			t.Fatal("files out of order")
		}
	}
	if len(k.files) == 0 {
		t.Fatal("no chunks")
	}
}

func TestHistoryInRecordsOfTheBackup(t *testing.T) {
	w := newHistWorld(t, smallShape)
	w.send()
	for i, rec := range w.all() {
		if rec[0] < recHead || rec[0] > recGone {
			t.Fatalf("record %d type %d", i, rec[0])
		}
		if int(binary.BigEndian.Uint32(rec[1:])) != len(rec)-5 {
			t.Fatalf("record %d length", i)
		}
		if rec[0] == recGone {
			t.Fatal("a gone record from a phone that has every file")
		}
	}
}

// a transfer cut before every record, then taken up from the state the app
// stored, ends exactly as one never cut
func TestHistoryCutAtEveryRecordThenResume(t *testing.T) {
	w := newHistWorld(t, smallShape)
	w.send()
	recs := w.all()
	whole := newSink()
	pump(t, recs, w.recv(), whole, w.sh, uint64(len(recs)))
	for cut := 0; cut <= len(recs); cut++ {
		r := w.recv()
		k := newSink()
		pump(t, recs, r, k, w.sh, uint64(cut))
		if cut > 0 {
			plan, err := r.Plan()
			if err != nil {
				t.Fatal(err)
			}
			st, err := r.State()
			if err != nil {
				t.Fatal(err)
			}
			r, err = ResumeReceiver(w.key, w.bind, w.id.pub, plan, st)
			if err != nil {
				t.Fatalf("resume at %d: %v", cut, err)
			}
			if r.Next() != uint64(cut) {
				t.Fatalf("resumed at %d, cut at %d", r.Next(), cut)
			}
		}
		pump(t, recs, r, k, w.sh, uint64(len(recs)))
		w.same(t, k)
		if !reflect.DeepEqual(k.kinds, whole.kinds) {
			t.Fatalf("cut at %d: other events", cut)
		}
		if mm, err := r.Check(k.counts()); err != nil || len(mm) != 0 {
			t.Fatalf("cut at %d: %v %v", cut, mm, err)
		}
	}
}

// the app took a record but its state never reached the disk: the state it
// has is one record back, and the record comes again without doubling
func TestHistoryCutBetweenRecordAndState(t *testing.T) {
	w := newHistWorld(t, smallShape)
	w.send()
	recs := w.all()
	for cut := 1; cut < len(recs); cut++ {
		r := w.recv()
		k := newSink()
		pump(t, recs, r, k, w.sh, uint64(cut))
		plan, _ := r.Plan()
		st, _ := r.State()
		committed := len(k.kinds)
		// the next record is taken, then the process dies before its commit
		if _, err := r.Take(recs[cut]); err != nil {
			t.Fatal(err)
		}
		r2, err := ResumeReceiver(w.key, w.bind, w.id.pub, plan, st)
		if err != nil {
			t.Fatal(err)
		}
		k.kinds = k.kinds[:committed]
		pump(t, recs, r2, k, w.sh, uint64(len(recs)))
		w.same(t, k)
	}
}

func TestHistoryRefusesRecordsOutOfPlace(t *testing.T) {
	w := newHistWorld(t, smallShape)
	w.send()
	recs := w.all()
	other := newHistWorld(t, smallShape)
	other.send()
	foreign := other.all()
	// same stream key, another link
	relinked := *w
	rand32(&relinked.bind)
	relinked.opt.Spool += "2"
	relinked.send()
	rebound := relinked.all()
	for i := range recs {
		r := w.recv()
		k := newSink()
		pump(t, recs, r, k, w.sh, uint64(i))
		bad := map[string][]byte{
			"from another stream": foreign[min(i, len(foreign)-1)],
			"from another link":   rebound[min(i, len(rebound)-1)],
			"cut short":           recs[i][:len(recs[i])-1],
			"with a byte more":    append(bytes.Clone(recs[i]), 0),
			"empty":               nil,
		}
		if i+1 < len(recs) {
			bad["dropped one"] = recs[i+1]
		}
		if i > 0 {
			bad["repeated"] = recs[i-1]
		}
		if i+2 < len(recs) {
			bad["moved back"] = recs[i+2]
		}
		retyped := bytes.Clone(recs[i])
		retyped[0] = retyped[0]%4 + 1
		bad["retyped"] = retyped
		long := bytes.Clone(recs[i])
		binary.BigEndian.PutUint32(long[1:], binary.BigEndian.Uint32(long[1:])+1)
		bad["length changed"] = long
		for why, b := range bad {
			if _, err := r.Take(b); err == nil {
				t.Fatalf("record %d %s taken", i, why)
			}
		}
		// nothing refused moved it: the right record is still taken
		pump(t, recs, r, k, w.sh, uint64(len(recs)))
		w.same(t, k)
	}
}

func rand32(b *[32]byte) {
	for i := range b {
		b[i] ^= byte(i*31 + 7)
	}
}

func TestHistoryEveryFlippedBitRefused(t *testing.T) {
	w := newHistWorld(t, histShape{chats: 3, rows: 3, files: 1, size: 700, chunk: MinChunk})
	w.send()
	recs := w.all()
	r := w.recv()
	k := newSink()
	for i, rec := range recs {
		for bit := 0; bit < len(rec)*8; bit++ {
			b := bytes.Clone(rec)
			b[bit/8] ^= 1 << (bit % 8)
			if _, err := r.Take(b); err == nil {
				t.Fatalf("record %d bit %d flipped and taken", i, bit)
			}
		}
		pump(t, recs, r, k, w.sh, uint64(i+1))
	}
	w.same(t, k)
}

// a chunk spoilt on the way is refused; the same chunk sent again is taken
func TestHistoryCorruptedChunkSentAgain(t *testing.T) {
	w := newHistWorld(t, smallShape)
	w.send()
	recs := w.all()
	r := w.recv()
	k := newSink()
	at := w.s.head.Text + 2
	pump(t, recs, r, k, w.sh, at)
	b := bytes.Clone(recs[at])
	b[len(b)/2] ^= 0x40
	if _, err := r.Take(b); !errors.Is(err, ErrRecord) {
		t.Fatalf("spoilt chunk: %v", err)
	}
	again, err := w.s.Record(at)
	if err != nil || !bytes.Equal(again, recs[at]) {
		t.Fatal("a record sent again is other bytes")
	}
	pump(t, recs, r, k, w.sh, uint64(len(recs)))
	w.same(t, k)
}

func TestHistoryHeadMustBeSignedByTheIdentity(t *testing.T) {
	w := newHistWorld(t, smallShape)
	w.send()
	recs := w.all()
	r := w.recv()
	if _, err := r.Take(recs[0]); err != nil {
		t.Fatal(err)
	}
	if _, err := r.Take(recs[1]); !errors.Is(err, ErrTrust) {
		t.Fatalf("text before the head was checked: %v", err)
	}
	// a verifier that knows no such key
	if err := r.Trust(newShim()); !errors.Is(err, ErrSignature) {
		t.Fatalf("trust under a stranger's shim: %v", err)
	}
	if _, err := r.Take(recs[1]); err == nil {
		t.Fatal("a stream whose head failed goes on")
	}

	// another identity's signature over the same body
	s2, err := NewSender(w.key, w.bind, w.id.pub, SendOptions{Spool: filepath.Join(w.dir, "s2"), Root: w.root, Chunk: MinChunk})
	if err != nil {
		t.Fatal(err)
	}
	defer s2.Close()
	body, err := s2.Plan()
	if err != nil {
		t.Fatal(err)
	}
	mallory := w.sh.identity(t)
	if _, err := mallory.Sign(ContextHistory, body); err == nil {
		t.Fatal("the stand-in signs a head that names another identity")
	}
	if err := s2.Sign(mallory); !errors.Is(err, ErrWrongIdentity) {
		t.Fatalf("sign with another identity: %v", err)
	}
	sig, _ := w.id.Sign(ContextHistory, body)
	sig[3] ^= 1
	if err := s2.Signed(sig); err != nil {
		t.Fatal(err)
	}
	rec, _ := s2.Record(0)
	r2 := w.recv()
	if _, err := r2.Take(rec); err != nil {
		t.Fatal(err)
	}
	if err := r2.Trust(w.sh); !errors.Is(err, ErrSignature) {
		t.Fatalf("a changed signature: %v", err)
	}

	// a head that names another identity than the welcome did
	r3, _ := NewReceiver(w.key, w.bind, mallory.pub)
	if _, err := r3.Take(recs[0]); !errors.Is(err, ErrHead) {
		t.Fatalf("head for another identity: %v", err)
	}

	// nothing is served before it is signed
	s3, _ := NewSender(w.key, w.bind, w.id.pub, SendOptions{Spool: filepath.Join(w.dir, "s3"), Root: w.root, Chunk: MinChunk})
	defer s3.Close()
	if _, err := s3.Record(0); !errors.Is(err, ErrState) {
		t.Fatalf("unsigned record 0: %v", err)
	}
	s3.Plan()
	if _, err := s3.Record(0); !errors.Is(err, ErrState) {
		t.Fatalf("planned but unsigned record 0: %v", err)
	}
	if err := s3.Signed(make([]byte, 10)); err == nil {
		t.Fatal("a short signature taken")
	}
}

func TestHistorySkipMedia(t *testing.T) {
	sh := smallShape
	sh.skip = true
	w := newHistWorld(t, sh)
	s := w.send()
	if err := s.Media(0, 1, "c0/f0.jpg"); err == nil {
		t.Fatal("a file added to a stream that skips media")
	}
	recs := w.all()
	k := newSink()
	pump(t, recs, w.recv(), k, w.sh, uint64(len(recs)))
	w.same(t, k)
	h, _ := s.Head()
	if !h.SkipMedia || h.Files != 0 || h.Records != h.Text+2 {
		t.Fatalf("head %+v", h)
	}
	for _, c := range h.Chats {
		if c.Media != 0 || c.MediaBytes != 0 {
			t.Fatal("media counted in a stream without media")
		}
	}
	for _, kind := range k.kinds {
		if kind == EvMedia || kind == EvData || kind == EvGone {
			t.Fatal("media in a stream without media")
		}
	}
	// no byte of any file is in the stream, sealed or not
	for name, f := range w.files {
		probe := f[:min(len(f), 64)]
		if len(probe) < 16 {
			continue
		}
		for _, rec := range recs {
			if bytes.Contains(rec, probe) {
				t.Fatalf("%s in the stream", name)
			}
		}
	}
	// a forged stream that says skip and lists a file anyway
	m := &Media{Chat: 0, At: 1, Size: 10, Name: "a.jpg"}
	f := forgeStream(t, w, []Count{{}}, [][]byte{chatRec(0, `{}`), mediaRec(MinChunk, m)}, nil, nil, true)
	if err := takeForged(t, w, f); err == nil {
		t.Fatal("a skip stream with a media list")
	}
}

// what the device checks in the text, each broken on its own
func TestHistoryTextRules(t *testing.T) {
	w := newHistWorld(t, histShape{chats: 1, rows: 1, chunk: MinChunk})
	one := []Count{{Messages: 1}}
	two := []Count{{Messages: 1}, {Messages: 1}}
	m1 := &Media{Chat: 0, At: 5, Size: 3, Name: "a"}
	m2 := &Media{Chat: 0, At: 9, Size: 3, Name: "b"}
	cases := map[string]*forged{
		"messages before their chat": forgeStream(t, w, one, [][]byte{msgsRec(0, `{"a":1}`), chatRec(0, `{}`)}, nil, nil, false),
		"a chat skipped":             forgeStream(t, w, two, [][]byte{chatRec(1, `{}`), msgsRec(1, `{"a":1}`)}, nil, nil, false),
		"an earlier chat again": forgeStream(t, w, []Count{{Messages: 1}, {Messages: 1}}, [][]byte{chatRec(0, `{}`),
			msgsRec(0, `{"a":1}`), chatRec(1, `{}`), msgsRec(0, `{"a":1}`)}, nil, nil, false),
		"fewer messages than counted": forgeStream(t, w, []Count{{Messages: 2}}, [][]byte{chatRec(0, `{}`), msgsRec(0, `{"a":1}`)}, nil, nil, false),
		"more messages than counted":  forgeStream(t, w, one, [][]byte{chatRec(0, `{}`), msgsRec(0, `{"a":1}`, `{"b":2}`)}, nil, nil, false),
		"a chat the head lacks":       forgeStream(t, w, one, [][]byte{chatRec(0, `{}`), msgsRec(0, `{"a":1}`), chatRec(1, `{}`)}, nil, nil, false),
		"a row that is not json":      forgeStream(t, w, one, [][]byte{chatRec(0, `{}`), msgsRec(0, `{"a":`)}, nil, nil, false),
		"a chat row that is not json": forgeStream(t, w, []Count{{}}, [][]byte{chatRec(0, `[1]`)}, nil, nil, false),
		"an unknown kind":             forgeStream(t, w, []Count{{}}, [][]byte{chatRec(0, `{}`), {9, 1, 2}}, nil, nil, false),
		"media before the last messages": forgeStream(t, w, []Count{{Messages: 1, Media: 1, MediaBytes: 3}},
			[][]byte{chatRec(0, `{}`), mediaRec(MinChunk, m1), msgsRec(0, `{"a":1}`)}, []*Media{m1}, [][]byte{dataOf(m1, 0, "abc")}, false),
		"older file before a newer": forgeStream(t, w, []Count{{Media: 2, MediaBytes: 6}},
			[][]byte{chatRec(0, `{}`), mediaRec(MinChunk, m1, m2)}, []*Media{m1, m2}, [][]byte{dataOf(m1, 0, "abc"), dataOf(m2, 1, "abc")}, false),
		"one name twice": forgeStream(t, w, []Count{{Media: 2, MediaBytes: 6}},
			[][]byte{chatRec(0, `{}`), mediaRec(MinChunk, &Media{At: 9, Size: 3, Name: "a"}, &Media{At: 5, Size: 3, Name: "a"})},
			[]*Media{m1, m1}, nil, false),
		"a name that climbs out": forgeStream(t, w, []Count{{Media: 1, MediaBytes: 3}},
			[][]byte{chatRec(0, `{}`), mediaRec(MinChunk, &Media{At: 9, Size: 3, Name: "../x"})}, []*Media{m1}, nil, false),
		"a file of no chat": forgeStream(t, w, []Count{{Media: 1, MediaBytes: 3}},
			[][]byte{chatRec(0, `{}`), mediaRec(MinChunk, &Media{Chat: 4, At: 9, Size: 3, Name: "x"})}, []*Media{m1}, nil, false),
		"media counted under another chat": forgeStream(t, w, []Count{{}, {Media: 1, MediaBytes: 3}},
			[][]byte{chatRec(0, `{}`), chatRec(1, `{}`), mediaRec(MinChunk, withSums(&Media{Chat: 0, At: 9, Size: 3, Name: "x"}, "abc"))},
			[]*Media{m1}, [][]byte{dataOf(m1, 0, "abc")}, false),
		"chats in another order": forgeStream(t, w, []Count{{}, {}}, [][]byte{chatRec(1, `{}`), chatRec(0, `{}`)}, nil, nil, false),
		"messages for a chat already closed": forgeStream(t, w, []Count{{}, {Messages: 1}},
			[][]byte{chatRec(0, `{}`), chatRec(1, `{}`), msgsRec(0, `{"a":1}`)}, nil, nil, false),
		"a chat after the media list": forgeStream(t, w, []Count{{Media: 1, MediaBytes: 3}, {}},
			[][]byte{chatRec(0, `{}`), mediaRec(MinChunk, withSums(&Media{At: 9, Size: 3, Name: "y"}, "abc")), chatRec(1, `{}`)},
			[]*Media{m1}, [][]byte{dataOf(m1, 0, "abc")}, false),
		"messages after the media list": forgeStream(t, w, []Count{{Messages: 1, Media: 1, MediaBytes: 3}},
			[][]byte{chatRec(0, `{}`), mediaRec(MinChunk, withSums(&Media{At: 9, Size: 3, Name: "y"}, "abc")), msgsRec(0, `{"a":1}`)},
			[]*Media{m1}, [][]byte{dataOf(m1, 0, "abc")}, false),
	}
	for why, f := range cases {
		err := takeForged(t, w, f)
		if err == nil {
			t.Errorf("%s: taken", why)
		}
		t.Logf("%s: %v", why, err)
	}
	// the forger itself is sound: the same pieces in order are taken
	good := forgeStream(t, w, []Count{{Messages: 1, Media: 1, MediaBytes: 3}},
		[][]byte{chatRec(0, `{}`), msgsRec(0, `{"a":1}`), mediaRec(MinChunk, withSums(m1, "abc"))}, []*Media{m1}, [][]byte{dataOf(m1, 0, "abc")}, false)
	if err := takeForged(t, w, good); err != nil {
		t.Fatalf("a sound forged stream: %v", err)
	}
}

func withSums(m *Media, content string) *Media {
	m.sums = [][hashSize]byte{sha256.Sum256([]byte(content))}
	return m
}

func dataOf(m *Media, file uint32, content string) []byte {
	if m.sums == nil {
		withSums(m, content)
	}
	b := binary.BigEndian.AppendUint32([]byte{kindData}, file)
	b = binary.BigEndian.AppendUint64(b, 0)
	return append(b, content...)
}

// the head's text hash and sizes hold the text to what was signed
func TestHistoryHeadHoldsTheText(t *testing.T) {
	w := newHistWorld(t, histShape{chats: 1, rows: 1, chunk: MinChunk})
	f := forgeStream(t, w, []Count{{Messages: 1}}, [][]byte{chatRec(0, `{}`), msgsRec(0, `{"a":1}`)}, nil, nil, false)
	for why, change := range map[string]func(h *Head){
		"text hash":    func(h *Head) { h.TextHash[0] ^= 1 },
		"stream bytes": func(h *Head) { h.Bytes++ },
		"one record more": func(h *Head) {
			h.Records++
		},
	} {
		g := *f
		h := *f.head
		change(&h)
		h.Sig, _ = w.id.Sign(ContextHistory, h.Body())
		g.recs = append([][]byte{f.keys.seal(0, recHead, h.encode())}, f.recs[1:]...)
		err := takeForged(t, w, &g)
		if err == nil {
			t.Errorf("%s changed: taken", why)
		}
		t.Logf("%s: %v", why, err)
	}
	if err := takeForged(t, w, f); err != nil {
		t.Fatal(err)
	}
}

func TestHistoryFileChangedAfterThePlan(t *testing.T) {
	w := newHistWorld(t, smallShape)
	s := w.send()
	h, _ := s.Head()
	recs := w.all()
	// the newest file is changed, the next one goes
	first := s.media[0]
	second := s.media[1]
	changed := bytes.Clone(w.files[first.Name])
	changed[0] ^= 1
	os.WriteFile(filepath.Join(w.root, first.Name), changed, 0o600)
	os.Remove(filepath.Join(w.root, second.Name))
	start := h.Text + 1
	again, _ := s.Record(start)
	if again[0] != recGone || bytes.Equal(again, recs[start]) {
		t.Fatal("a changed file still goes as data")
	}
	// the gone record never shares a key and nonce with the data it stands
	// in for
	if _, _, err := s.keys.open(start, append([]byte{recBody}, again[1:]...)); err == nil {
		t.Fatal("a gone record opens under the records key")
	}
	r := w.recv()
	k := newSink()
	fresh := make([][]byte, len(recs))
	for i := range recs {
		fresh[i], _ = s.Record(uint64(i))
	}
	pump(t, fresh, r, k, w.sh, uint64(len(recs)))
	if !k.gone[0] || !k.gone[1] || k.ok[0] || k.ok[1] {
		t.Fatal("lost files not reported")
	}
	mm, err := r.Check(k.counts())
	if err != nil || len(mm) == 0 {
		t.Fatalf("a lost file passes the check: %v", err)
	}
	for _, m := range mm {
		if m.Got.Media >= m.Want.Media {
			t.Fatalf("mismatch %+v", m)
		}
	}
	// the file put back as it was goes as data again
	os.WriteFile(filepath.Join(w.root, first.Name), w.files[first.Name], 0o600)
	back, _ := s.Record(start)
	if !bytes.Equal(back, recs[start]) {
		t.Fatal("the same chunk is other bytes")
	}
}

// the device's count after import is compared on both sides
func TestHistoryCountCheckOnBothSides(t *testing.T) {
	w := newHistWorld(t, smallShape)
	s := w.send()
	recs := w.all()
	r := w.recv()
	k := newSink()
	if _, err := r.Check(nil); !errors.Is(err, ErrState) {
		t.Fatal("a check before the stream is whole")
	}
	pump(t, recs, r, k, w.sh, uint64(len(recs)))
	for _, change := range []func(c []Count){
		func(c []Count) { c[1].Messages-- },
		func(c []Count) { c[2].Messages++ },
		func(c []Count) { c[0].Media-- },
		func(c []Count) { c[4].MediaBytes += 1 },
	} {
		got := k.counts()
		change(got)
		mm, err := r.Check(got)
		if err != nil || len(mm) != 1 {
			t.Fatalf("device side: %v %v", mm, err)
		}
		tl, err := r.Tally(got)
		if err != nil {
			t.Fatal(err)
		}
		pm, err := s.CheckTally(tl)
		if err != nil || !reflect.DeepEqual(pm, mm) {
			t.Fatalf("phone side: %v %v", pm, err)
		}
	}
	if _, err := r.Check(k.counts()[1:]); err == nil {
		t.Fatal("a count of fewer chats taken")
	}
	tl, _ := r.Tally(k.counts())
	b := bytes.Clone(tl)
	b[20] ^= 1
	if _, err := s.CheckTally(b); !errors.Is(err, ErrTally) {
		t.Fatal("a changed tally taken")
	}
	other := newHistWorld(t, smallShape)
	os2 := other.send()
	if _, err := os2.CheckTally(tl); !errors.Is(err, ErrTally) {
		t.Fatal("a tally from another stream taken")
	}
	t2, _ := r.Tally(k.counts())
	if bytes.Equal(t2, tl) {
		t.Fatal("two tallies share a nonce")
	}
}

func TestHistoryServedFromManyGoroutines(t *testing.T) {
	w := newHistWorld(t, smallShape)
	s := w.send()
	recs := w.all()
	var wg sync.WaitGroup
	for g := 0; g < 8; g++ {
		wg.Add(1)
		go func(g int) {
			defer wg.Done()
			for i := range recs {
				j := (i + g*7) % len(recs)
				b, err := s.Record(uint64(j))
				if err != nil || !bytes.Equal(b, recs[j]) {
					t.Errorf("record %d differs", j)
					return
				}
			}
		}(g)
	}
	wg.Wait()
}

func TestHistoryBuildRules(t *testing.T) {
	w := newHistWorld(t, smallShape)
	mk := func(o SendOptions) (*Sender, error) { return NewSender(w.key, w.bind, w.id.pub, o) }
	for _, c := range []int{MinChunk - 1, MaxChunk + 1, -5} {
		if _, err := mk(SendOptions{Spool: filepath.Join(w.dir, "x"), Chunk: c}); err == nil {
			t.Fatalf("chunk %d taken", c)
		}
	}
	if _, err := mk(SendOptions{}); err == nil {
		t.Fatal("no spool taken")
	}
	os.WriteFile(filepath.Join(w.dir, "held"), []byte("x"), 0o600)
	if _, err := mk(SendOptions{Spool: filepath.Join(w.dir, "held")}); err == nil {
		t.Fatal("a spool over a file taken")
	}
	if _, err := NewSender(nil, w.bind, w.id.pub, SendOptions{Spool: filepath.Join(w.dir, "y")}); err == nil {
		t.Fatal("no key taken")
	}
	s, err := mk(SendOptions{Spool: filepath.Join(w.dir, "z"), Root: w.root, Chunk: MinChunk})
	if err != nil {
		t.Fatal(err)
	}
	if err := s.Message([]byte(`{}`)); err == nil {
		t.Fatal("a message before any chat")
	}
	if _, err := s.Chat([]byte(`not json`)); err == nil {
		t.Fatal("a chat row that is not json")
	}
	if _, err := s.Chat([]byte(`{}`)); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"", "/abs", "a/../b", "a//b", "a\\b", "a\x01", "./a", "a/", string([]byte{0xff})} {
		if err := s.Media(0, 1, name); err == nil {
			t.Fatalf("name %q taken", name)
		}
	}
	if err := s.Media(3, 1, "c0/f0.jpg"); err == nil {
		t.Fatal("a file of no chat")
	}
	if err := s.Media(0, 1, "c0/f0.jpg"); err != nil {
		t.Fatal(err)
	}
	if err := s.Media(0, 2, "c0/f0.jpg"); err == nil {
		t.Fatal("one file twice")
	}
	if err := s.Media(0, 2, "missing.jpg"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Plan(); err != nil {
		t.Fatal(err)
	}
	if s.Skipped != 1 {
		t.Fatalf("skipped %d", s.Skipped)
	}
	if _, err := s.Chat([]byte(`{}`)); !errors.Is(err, ErrPlanned) {
		t.Fatal("a chat after the plan")
	}
	if _, err := s.Plan(); !errors.Is(err, ErrPlanned) {
		t.Fatal("planned twice")
	}
	s.Close()
	if _, err := os.Stat(filepath.Join(w.dir, "z")); !os.IsNotExist(err) {
		t.Fatal("the spool stays after close")
	}
	if _, err := s.Record(0); err == nil {
		t.Fatal("a record after close")
	}
}

// the odd sizes: an empty file, one of exactly a chunk, one a byte over,
// a row bigger than a chunk, and a stream with nothing in it
func TestHistoryEdges(t *testing.T) {
	w := newHistWorld(t, histShape{chunk: MinChunk})
	for name, size := range map[string]int{"empty": 0, "one": MinChunk, "over": MinChunk + 1, "two": 2 * MinChunk} {
		b := bytes.Repeat([]byte{byte(size)}, size)
		w.files[name] = b
		w.ats[name] = int64(size)
		os.WriteFile(filepath.Join(w.root, name), b, 0o600)
	}
	big := append([]byte(`{"plaintext":"`), bytes.Repeat([]byte("y"), 3*MinChunk)...)
	big = append(big, `"}`...)
	w.chats = []histChat{{meta: []byte(`{"k":1}`), rows: [][]byte{[]byte(`{"a":1}`), big, []byte(`{"b":2}`)},
		files: []string{"empty", "one", "over", "two"}}}
	w.send()
	recs := w.all()
	k := newSink()
	pump(t, recs, w.recv(), k, w.sh, uint64(len(recs)))
	w.same(t, k)

	e := newHistWorld(t, histShape{chunk: MinChunk})
	e.send()
	recs = e.all()
	if len(recs) != 2 {
		t.Fatalf("an empty stream has %d records", len(recs))
	}
	k = newSink()
	r := e.recv()
	pump(t, recs, r, k, e.sh, 2)
	if mm, err := r.Check(nil); err != nil || len(mm) != 0 {
		t.Fatal("an empty stream's check")
	}
}

func TestHistoryResumeRefusesBadState(t *testing.T) {
	w := newHistWorld(t, smallShape)
	w.send()
	recs := w.all()
	r := w.recv()
	if _, err := r.State(); err == nil {
		t.Fatal("a state before the head")
	}
	k := newSink()
	pump(t, recs, r, k, w.sh, w.s.head.Text+2)
	plan, _ := r.Plan()
	st, _ := r.State()
	if _, err := ResumeReceiver(w.key, w.bind, w.id.pub, plan, st); err != nil {
		t.Fatal(err)
	}
	other := w.sh.identity(t)
	if _, err := ResumeReceiver(w.key, w.bind, other.pub, plan, st); err == nil {
		t.Fatal("resumed under another identity")
	}
	b2 := w.bind
	b2[0] ^= 1
	if _, err := ResumeReceiver(w.key, b2, w.id.pub, plan, st); err == nil {
		t.Fatal("resumed under another link")
	}
	far := bytes.Clone(st)
	binary.BigEndian.PutUint64(far[5:], w.s.head.Records+1)
	if _, err := ResumeReceiver(w.key, w.bind, w.id.pub, plan, far); err == nil {
		t.Fatal("resumed past the end")
	}
	hash := bytes.Clone(st)
	hash[len(hash)-1] ^= 1
	if _, err := ResumeReceiver(w.key, w.bind, w.id.pub, plan, hash); err == nil {
		t.Fatal("resumed with a text hash that no longer matches")
	}
	short := plan[:len(plan)-1]
	if _, err := ResumeReceiver(w.key, w.bind, w.id.pub, short, st); err == nil {
		t.Fatal("resumed with a plan cut short")
	}
	for i := 0; i < len(st); i++ {
		if _, err := ResumeReceiver(w.key, w.bind, w.id.pub, plan, st[:i]); err == nil {
			t.Fatalf("resumed with %d bytes of state", i)
		}
	}
}
