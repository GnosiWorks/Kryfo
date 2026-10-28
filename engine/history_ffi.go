// SPDX-License-Identifier: GPL-3.0-or-later
package main

import "C"

import (
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"sync"
	"unsafe"

	"github.com/halo/engine/devices"
)

// the history stream for dart: a sender on the phone and a receiver on the
// new device, each behind a handle. binary data goes through raw buffers;
// keys, the transcript, the stream id and the identity come as hex.

var hist = struct {
	sync.Mutex
	next int64
	send map[int64]*devices.Sender
	recv map[int64]*histRecv
}{send: map[int64]*devices.Sender{}, recv: map[int64]*histRecv{}}

type histRecv struct {
	r *devices.Receiver
	// the last event, encoded, until dart reads it
	ev []byte
}

// the most any one record takes on the wire
const histMaxRecord = devices.MaxRecord + 5 + 16

func histID(cID *C.char) ([devices.IDSize]byte, bool) {
	var id [devices.IDSize]byte
	b, err := hex.DecodeString(goStr(cID))
	if err != nil || len(b) != len(id) {
		return id, false
	}
	copy(id[:], b)
	return id, true
}

func histKeys(cKey, cBind, cIdentity *C.char) (*[devices.StreamKeySize]byte, [32]byte, devices.Key, error) {
	var key [devices.StreamKeySize]byte
	var bind [32]byte
	var id devices.Key
	k, err := hex.DecodeString(goStr(cKey))
	if err != nil || len(k) != len(key) {
		return nil, bind, id, errors.New("bad key")
	}
	copy(key[:], k)
	clear(k)
	b, err := hex.DecodeString(goStr(cBind))
	if err != nil || len(b) != len(bind) {
		return nil, bind, id, errors.New("bad bind")
	}
	copy(bind[:], b)
	i, err := hex.DecodeString(goStr(cIdentity))
	if err != nil {
		return nil, bind, id, errors.New("bad identity")
	}
	id, err = devices.ParseKey(i)
	if err != nil {
		return nil, bind, id, err
	}
	return &key, bind, id, nil
}

func histBytes(p *C.uchar, n C.int, max int) ([]byte, bool) {
	if n < 0 || int(n) > max || (p == nil && n > 0) {
		return nil, false
	}
	if n == 0 {
		return []byte{}, true
	}
	return C.GoBytes(unsafe.Pointer(p), n), true
}

func histOut(out *C.uchar, cap C.int, b []byte) C.int {
	if out == nil || int(cap) < len(b) {
		return C.int(-len(b) - 1)
	}
	copy(unsafe.Slice((*byte)(unsafe.Pointer(out)), len(b)), b)
	return C.int(len(b))
}

func histAdd(s *devices.Sender, r *devices.Receiver) C.longlong {
	hist.Lock()
	defer hist.Unlock()
	hist.next++
	if s != nil {
		hist.send[hist.next] = s
	} else {
		hist.recv[hist.next] = &histRecv{r: r}
	}
	return C.longlong(hist.next)
}

func histSender(h C.longlong) *devices.Sender {
	hist.Lock()
	defer hist.Unlock()
	return hist.send[int64(h)]
}

func histReceiver(h C.longlong) *histRecv {
	hist.Lock()
	defer hist.Unlock()
	return hist.recv[int64(h)]
}

func histErr(err error) *C.char { return C.CString("error: " + err.Error()) }

func histJSON(v any) *C.char {
	b, err := json.Marshal(v)
	if err != nil {
		return histErr(err)
	}
	return C.CString(string(b))
}

// a new sender. its text is sealed into spool, a file that must not exist,
// and its media names are read under root. 0 when refused.
//
//export HaloHistSendNew
func HaloHistSendNew(cKey, cBind, cIdentity, cSpool, cRoot *C.char, skip, chunk C.int) C.longlong {
	key, bind, id, err := histKeys(cKey, cBind, cIdentity)
	if err != nil {
		return 0
	}
	defer clear(key[:])
	s, err := devices.NewSender(key, bind, id, devices.SendOptions{
		Spool: goStr(cSpool), Root: goStr(cRoot), SkipMedia: skip != 0, Chunk: int(chunk),
	})
	if err != nil {
		return 0
	}
	return histAdd(s, nil)
}

// starts a chat with its row, a json object. its number; -2 when it could
// not go and is counted as left out (its messages then go nowhere); -1.
//
//export HaloHistSendChat
func HaloHistSendChat(h C.longlong, meta *C.uchar, n C.int) C.int {
	s := histSender(h)
	b, ok := histBytes(meta, n, devices.MaxMeta)
	if s == nil || !ok {
		return -1
	}
	c, err := s.Chat(b)
	if errors.Is(err, devices.ErrLeft) {
		return -2
	}
	if err != nil {
		return -1
	}
	return C.int(c)
}

// leftOr is 1 for a row or file left out and counted, -1 for a refusal
func leftOr(err error) C.int {
	switch {
	case err == nil:
		return 0
	case errors.Is(err, devices.ErrLeft):
		return 1
	}
	return -1
}

// a message of the chat started last. 0; 1 when it was left out and
// counted; -1.
//
//export HaloHistSendMessage
func HaloHistSendMessage(h C.longlong, row *C.uchar, n C.int) C.int {
	s := histSender(h)
	if s == nil || n < 0 {
		return -1
	}
	// a row too big to copy in is not a row: counted as left out
	b, ok := histBytes(row, n, 2*devices.MaxRecord)
	if !ok {
		b = []byte("{")
	}
	return leftOr(s.Message(b))
}

// a file under root for chat, at its time in ms. 0; 1 when its name could
// not be one and it is counted as left out; -1.
//
//export HaloHistSendMedia
func HaloHistSendMedia(h C.longlong, chat C.int, at C.longlong, cName *C.char) C.int {
	s := histSender(h)
	if s == nil || chat < 0 {
		return -1
	}
	return leftOr(s.Media(uint32(chat), int64(at), goStr(cName)))
}

// a file of chat the app could not hand over, counted as left out. 0, or -1.
//
//export HaloHistSendLeft
func HaloHistSendLeft(h C.longlong, chat C.int) C.int {
	s := histSender(h)
	if s == nil || chat < 0 || s.Left(uint32(chat)) != nil {
		return -1
	}
	return 0
}

// the sender's stream id as hex, for the device with the first answer.
//
//export HaloHistSendID
func HaloHistSendID(h C.longlong) *C.char {
	s := histSender(h)
	if s == nil {
		return histErr(errors.New("no sender"))
	}
	id := s.ID()
	return C.CString(hex.EncodeToString(id[:]))
}

// closes the text, reads the files once and seals the head. "" or "error: ...".
//
//export HaloHistSendPlan
func HaloHistSendPlan(h C.longlong) *C.char {
	s := histSender(h)
	if s == nil {
		return histErr(errors.New("no sender"))
	}
	if err := s.Plan(); err != nil {
		return histErr(err)
	}
	return C.CString("")
}

type histCountJSON struct {
	M  uint32 `json:"m"`
	F  uint32 `json:"f"`
	B  uint64 `json:"b"`
	LR uint32 `json:"lr,omitempty"`
	LF uint32 `json:"lf,omitempty"`
}

func countsJSON(c []devices.Count) []histCountJSON {
	out := make([]histCountJSON, len(c))
	for i, x := range c {
		out[i] = histCountJSON{x.Messages, x.Media, x.MediaBytes, x.LeftRows, x.LeftFiles}
	}
	return out
}

func countsFrom(s string) ([]devices.Count, error) {
	var in []histCountJSON
	if err := json.Unmarshal([]byte(s), &in); err != nil {
		return nil, err
	}
	out := make([]devices.Count, len(in))
	for i, x := range in {
		out[i] = devices.Count{Messages: x.M, Media: x.F, MediaBytes: x.B}
	}
	return out, nil
}

type histHeadJSON struct {
	Records   uint64          `json:"records"`
	Bytes     uint64          `json:"bytes"`
	Text      uint64          `json:"text"`
	Files     uint32          `json:"files"`
	Skip      bool            `json:"skip"`
	LeftChats uint32          `json:"leftChats"`
	Chats     []histCountJSON `json:"chats"`
}

func headJSON(h *devices.Head) histHeadJSON {
	return histHeadJSON{Records: h.Records, Bytes: h.Bytes, Text: h.Text, Files: h.Files, Skip: h.SkipMedia, LeftChats: h.LeftChats, Chats: countsJSON(h.Chats)}
}

// what the planned stream holds: sizes and the counts chat by chat.
//
//export HaloHistSendHead
func HaloHistSendHead(h C.longlong) *C.char {
	s := histSender(h)
	if s == nil {
		return histErr(errors.New("no sender"))
	}
	hd, err := s.Head()
	if err != nil {
		return histErr(err)
	}
	return histJSON(headJSON(&hd))
}

// record index into out. its length; below -1 when out is too small (the
// length needed is -n-1); -1 when there is no such record.
//
//export HaloHistSendRecord
func HaloHistSendRecord(h C.longlong, index C.ulonglong, out *C.uchar, cap C.int) C.int {
	s := histSender(h)
	if s == nil {
		return -1
	}
	b, err := s.Record(uint64(index))
	if err != nil {
		return -1
	}
	if int(cap) < len(b) {
		return C.int(-len(b) - 1)
	}
	return histOut(out, cap, b)
}

type histMismatchJSON struct {
	Chat uint32        `json:"chat"`
	Want histCountJSON `json:"want"`
	Got  histCountJSON `json:"got"`
}

func mismatchJSON(mm []devices.Mismatch) []histMismatchJSON {
	out := []histMismatchJSON{}
	for _, m := range mm {
		w := countsJSON([]devices.Count{m.Want, m.Got})
		out = append(out, histMismatchJSON{m.Chat, w[0], w[1]})
	}
	return out
}

// the device's tally, checked against the head this phone signed: a json
// list of the chats that differ, [] when none does.
//
//export HaloHistSendTally
func HaloHistSendTally(h C.longlong, in *C.uchar, n C.int) *C.char {
	s := histSender(h)
	b, ok := histBytes(in, n, devices.TallyMax)
	if s == nil || !ok {
		return histErr(errors.New("no tally"))
	}
	mm, err := s.CheckTally(b)
	if err != nil {
		return histErr(err)
	}
	return histJSON(mismatchJSON(mm))
}

// forgets the keys and removes the spool.
//
//export HaloHistSendClose
func HaloHistSendClose(h C.longlong) {
	hist.Lock()
	s := hist.send[int64(h)]
	delete(hist.send, int64(h))
	hist.Unlock()
	if s != nil {
		s.Close()
	}
}

// a new receiver for the stream the welcome's key opens, from the sender
// whose stream id the phone gave. 0 when refused.
//
//export HaloHistRecvNew
func HaloHistRecvNew(cKey, cBind, cID, cIdentity *C.char) C.longlong {
	key, bind, ident, err := histKeys(cKey, cBind, cIdentity)
	if err != nil {
		return 0
	}
	defer clear(key[:])
	sid, ok := histID(cID)
	if !ok {
		return 0
	}
	r, err := devices.NewReceiver(key, bind, sid, ident)
	if err != nil {
		return 0
	}
	return histAdd(nil, r)
}

// a receiver taken up from its stored plan and state. 0 when refused.
//
//export HaloHistRecvResume
func HaloHistRecvResume(cKey, cBind, cID, cIdentity *C.char, plan *C.uchar, pn C.int, state *C.uchar, sn C.int) C.longlong {
	key, bind, ident, err := histKeys(cKey, cBind, cIdentity)
	if err != nil {
		return 0
	}
	defer clear(key[:])
	sid, ok := histID(cID)
	if !ok {
		return 0
	}
	p, ok1 := histBytes(plan, pn, 64<<20)
	st, ok2 := histBytes(state, sn, 1<<10)
	if !ok1 || !ok2 {
		return 0
	}
	r, err := devices.ResumeReceiver(key, bind, sid, ident, p, st)
	if err != nil {
		return 0
	}
	return histAdd(nil, r)
}

type histEventJSON struct {
	K     string            `json:"k"`
	I     uint64            `json:"i"`
	Chat  uint32            `json:"chat"`
	Meta  json.RawMessage   `json:"meta,omitempty"`
	Rows  []json.RawMessage `json:"rows,omitempty"`
	Media []histMediaJSON   `json:"media,omitempty"`
	First uint32            `json:"first"`
	File  uint32            `json:"file"`
	Off   uint64            `json:"off"`
	Last  bool              `json:"last"`
	Ok    bool              `json:"ok"`
	Text  bool              `json:"text"`
	Plan  bool              `json:"plan"`
	Head  *histHeadJSON     `json:"head,omitempty"`
}

type histMediaJSON struct {
	Chat uint32 `json:"chat"`
	At   int64  `json:"at"`
	Size uint64 `json:"size"`
	Name string `json:"name"`
}

var evNames = map[devices.EventKind]string{
	devices.EvHead: "head", devices.EvChat: "chat", devices.EvMessages: "messages",
	devices.EvMedia: "media", devices.EvData: "data", devices.EvGone: "gone", devices.EvEnd: "end",
}

// the event as dart reads it: the json's length in four bytes, the json,
// then a chunk's bytes
func encodeEvent(ev *devices.Event) ([]byte, error) {
	j := histEventJSON{
		K: evNames[ev.Kind], I: ev.Index, Chat: ev.Chat, First: ev.First, File: ev.File,
		Off: ev.Offset, Last: ev.Last, Ok: ev.Ok, Text: ev.TextDone, Plan: ev.PlanChanged,
	}
	if ev.Meta != nil {
		j.Meta = ev.Meta
	}
	for _, r := range ev.Rows {
		j.Rows = append(j.Rows, r)
	}
	for _, m := range ev.Media {
		j.Media = append(j.Media, histMediaJSON{m.Chat, m.At, m.Size, m.Name})
	}
	if ev.Head != nil {
		hj := headJSON(ev.Head)
		j.Head = &hj
	}
	b, err := json.Marshal(j)
	if err != nil {
		return nil, err
	}
	out := binary.BigEndian.AppendUint32(nil, uint32(len(b)))
	out = append(out, b...)
	return append(out, ev.Bytes...), nil
}

// takes the next record. the event's length, to read with
// HaloHistRecvEvent; -1 when the record is refused and may come again; -2
// when the stream failed for good.
//
//export HaloHistRecvTake
func HaloHistRecvTake(h C.longlong, rec *C.uchar, n C.int) C.int {
	x := histReceiver(h)
	b, ok := histBytes(rec, n, histMaxRecord)
	if x == nil || !ok {
		return -1
	}
	ev, err := x.r.Take(b)
	if err != nil {
		if x.r.Broken() == nil {
			return -1
		}
		return -2
	}
	x.ev, err = encodeEvent(ev)
	if err != nil {
		return -2
	}
	return C.int(len(x.ev))
}

// the last event into out. its length, or below -1 when out is too small.
//
//export HaloHistRecvEvent
func HaloHistRecvEvent(h C.longlong, out *C.uchar, cap C.int) C.int {
	x := histReceiver(h)
	if x == nil || x.ev == nil {
		return -1
	}
	return histOut(out, cap, x.ev)
}

// the head taken, as json, or "error: ..." before it.
//
//export HaloHistRecvHead
func HaloHistRecvHead(h C.longlong) *C.char {
	x := histReceiver(h)
	if x == nil {
		return histErr(errors.New("no receiver"))
	}
	hd := x.r.Head()
	if hd == nil {
		return histErr(devices.ErrState)
	}
	return histJSON(headJSON(hd))
}

// the receiver's state into out, to store with the record just taken. its
// length, or below -1 when out is too small.
//
//export HaloHistRecvState
func HaloHistRecvState(h C.longlong, out *C.uchar, cap C.int) C.int {
	x := histReceiver(h)
	if x == nil {
		return -1
	}
	b, err := x.r.State()
	if err != nil {
		return -1
	}
	return histOut(out, cap, b)
}

// the receiver's plan into out, to store when an event says it changed.
//
//export HaloHistRecvPlan
func HaloHistRecvPlan(h C.longlong, out *C.uchar, cap C.int) C.int {
	x := histReceiver(h)
	if x == nil {
		return -1
	}
	b, err := x.r.Plan()
	if err != nil {
		return -1
	}
	return histOut(out, cap, b)
}

// the index the receiver takes next.
//
//export HaloHistRecvNext
func HaloHistRecvNext(h C.longlong) C.longlong {
	x := histReceiver(h)
	if x == nil {
		return -1
	}
	return C.longlong(x.r.Next())
}

// 1 once the end record came, 0 before, -1 for no receiver.
//
//export HaloHistRecvDone
func HaloHistRecvDone(h C.longlong) C.int {
	x := histReceiver(h)
	if x == nil {
		return -1
	}
	if x.r.Done() {
		return 1
	}
	return 0
}

// the counts the app found after its import, json [{m,f,b}] in the head's
// chat order, against the head: the chats that differ, [] when none does.
//
//export HaloHistRecvCheck
func HaloHistRecvCheck(h C.longlong, cCounts *C.char) *C.char {
	x := histReceiver(h)
	if x == nil {
		return histErr(errors.New("no receiver"))
	}
	got, err := countsFrom(goStr(cCounts))
	if err != nil {
		return histErr(err)
	}
	mm, err := x.r.Check(got)
	if err != nil {
		return histErr(err)
	}
	return histJSON(mismatchJSON(mm))
}

// the same counts sealed for the phone. its length, or below -1 when out
// is too small, -1 when refused.
//
//export HaloHistRecvTally
func HaloHistRecvTally(h C.longlong, cCounts *C.char, out *C.uchar, cap C.int) C.int {
	x := histReceiver(h)
	if x == nil {
		return -1
	}
	got, err := countsFrom(goStr(cCounts))
	if err != nil {
		return -1
	}
	b, err := x.r.Tally(got)
	if err != nil {
		return -1
	}
	return histOut(out, cap, b)
}

//export HaloHistRecvClose
func HaloHistRecvClose(h C.longlong) {
	hist.Lock()
	x := hist.recv[int64(h)]
	delete(hist.recv, int64(h))
	hist.Unlock()
	if x != nil {
		x.r.Close()
	}
}
