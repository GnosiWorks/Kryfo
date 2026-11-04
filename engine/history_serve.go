// SPDX-License-Identifier: GPL-3.0-or-later
package main

import "C"

import (
	"bufio"
	"context"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/halo/engine/devices"
)

// the history copy over the phone's onion (decision D3). the device asks,
// one line at a time on the phone's door: "KHQ1 <tag> <op> <arg> <mac>",
// the mac under a key only the two ends of the link hold. the phone answers
// one line: "KHA1 ..." with what was asked, or "KHN1 <why>". records are
// the sender's, sealed already; nothing here opens them. an ask whose tag
// or mac does not hold is not a history line, and the door treats it as it
// treats any line that is not a message. nothing here runs unless the app
// opened a copy, which it does only with the switch on

const (
	histAskPrefix = "KHQ1 "
	histAnswerYes = "KHA1"
	histAnswerNo  = "KHN1"

	// the copy is still being made, ended by a hide, or done
	histWhyMaking = "making"
	histWhyEnded  = "ended"
	histWhyDone   = "done"
	histWhyNone   = "none"

	// a tally goes in lines of this many bytes at most
	histTallyChunk = 48 << 10
)

// one copy the phone serves
type histServe struct {
	ask   *devices.Ask
	gen   uint32
	send  int64
	id    string
	why   string
	asked uint64
	// the device's tally, in its lines until whole
	parts map[int]string
	nPart int
	tally []byte
}

var histServes = struct {
	sync.Mutex
	m map[[devices.AskTagSize]byte]*histServe
}{m: map[[devices.AskTagSize]byte]*histServe{}}

type histServeArgs struct {
	Key   string `json:"key"`
	Bind  string `json:"bind"`
	Tag   string `json:"tag"`
	Gen   uint32 `json:"gen"`
	Send  int64  `json:"send"`
	Why   string `json:"why"`
	Onion string `json:"onion"`
	I     uint64 `json:"i"`
	Tally []byte `json:"tally"`
}

type histServeOut struct {
	Err   string `json:"err,omitempty"`
	Tag   string `json:"tag,omitempty"`
	Key   string `json:"key,omitempty"`
	Why   string `json:"why,omitempty"`
	Gen   uint32 `json:"gen"`
	ID    string `json:"id,omitempty"`
	Asked uint64 `json:"asked"`
	Tally []byte `json:"tally,omitempty"`
	Rec   []byte `json:"rec,omitempty"`
	Ok    bool   `json:"ok,omitempty"`
}

func histStreamKey(keyHex, bindHex string) (*[devices.StreamKeySize]byte, [32]byte, error) {
	var bind [32]byte
	k, err := hex.DecodeString(keyHex)
	if err != nil || len(k) != devices.StreamKeySize {
		return nil, bind, errors.New("bad key")
	}
	b, err := hex.DecodeString(bindHex)
	if err != nil || len(b) != len(bind) {
		clear(k)
		return nil, bind, errors.New("bad bind")
	}
	key := &[devices.StreamKeySize]byte{}
	copy(key[:], k)
	clear(k)
	copy(bind[:], b)
	return key, bind, nil
}

func histTagOf(s string) ([devices.AskTagSize]byte, bool) {
	var t [devices.AskTagSize]byte
	b, err := hex.DecodeString(s)
	if err != nil || len(b) != len(t) {
		return t, false
	}
	copy(t[:], b)
	return t, true
}

// HaloHistServe runs one of the phone's calls for the copies it serves:
// op, and its args as json.
//
//export HaloHistServe
func HaloHistServe(cOp, cArgs *C.char) *C.char {
	return C.CString(histServeJSON(goStr(cOp), goStr(cArgs)))
}

func histServeJSON(op, raw string) string {
	out := &histServeOut{}
	var a histServeArgs
	err := json.Unmarshal([]byte(raw), &a)
	if err == nil {
		err = histServeCall(op, &a, out)
	}
	if err != nil {
		out.Err = err.Error()
	}
	b, _ := json.Marshal(out)
	return string(b)
}

func histServeCall(op string, a *histServeArgs, out *histServeOut) error {
	if op == "open" {
		// a copy of the link stream a.Key at generation a.Gen: its key for
		// the sender, and its tag. while the sender is made, a device that
		// asks hears "making"
		key, bind, err := histStreamKey(a.Key, a.Bind)
		if err != nil {
			return err
		}
		defer clear(key[:])
		ask, err := devices.AskFor(key, bind)
		if err != nil {
			return err
		}
		g, err := devices.AgainKey(key, bind, a.Gen)
		if err != nil {
			ask.Wipe()
			return err
		}
		out.Key = hex.EncodeToString(g[:])
		clear(g[:])
		histServes.Lock()
		if o := histServes.m[ask.Tag]; o != nil {
			o.ask.Wipe()
		}
		histServes.m[ask.Tag] = &histServe{ask: ask, gen: a.Gen, why: histWhyMaking}
		histServes.Unlock()
		out.Tag, out.Gen = hex.EncodeToString(ask.Tag[:]), a.Gen
		return nil
	}
	tag, ok := histTagOf(a.Tag)
	if !ok {
		return errors.New("bad tag")
	}
	histServes.Lock()
	defer histServes.Unlock()
	s := histServes.m[tag]
	if s == nil {
		return devices.ErrUnknown
	}
	switch op {
	case "serve":
		snd := histSender(C.longlong(a.Send))
		if snd == nil || a.Gen != s.gen {
			return devices.ErrState
		}
		id := snd.ID()
		s.send, s.id, s.why = a.Send, hex.EncodeToString(id[:]), ""
		return nil
	case "end":
		// ended by a hide, or done: the sender is dart's to close
		if a.Why != histWhyEnded && a.Why != histWhyDone {
			return errors.New("bad why")
		}
		s.why, s.send = a.Why, 0
		return nil
	case "state":
		out.Why, out.Gen, out.ID, out.Asked = s.why, s.gen, s.id, s.asked
		out.Tally = s.tally
		return nil
	case "drop":
		s.ask.Wipe()
		delete(histServes.m, tag)
		return nil
	}
	return errors.New("no such call")
}

// the door's side: an ask for a copy this phone serves, and its answer;
// false for any line that is not one
func histDoorTake(line string) (string, bool) {
	if !strings.HasPrefix(line, histAskPrefix) {
		return "", false
	}
	f := strings.Fields(line[len(histAskPrefix):])
	if len(f) != 4 {
		return "", false
	}
	tag, ok := histTagOf(f[0])
	if !ok {
		return "", false
	}
	mac, err := hex.DecodeString(f[3])
	if err != nil || len(mac) != devices.AskMACSize {
		return "", false
	}
	op, arg := f[1], f[2]
	histServes.Lock()
	s := histServes.m[tag]
	if s == nil || !s.ask.Check(op, arg, mac) {
		histServes.Unlock()
		return "", false
	}
	why, send, gen, id := s.why, s.send, s.gen, s.id
	switch op {
	case "hello":
		histServes.Unlock()
		if why != "" {
			return histAnswerNo + " " + why, true
		}
		return histAnswerYes + " " + strconv.FormatUint(uint64(gen), 10) + " " + id, true
	case "tally":
		ans := s.takeTally(arg)
		histServes.Unlock()
		return ans, true
	case "rec":
		i, err := strconv.ParseUint(arg, 10, 64)
		if err != nil || arg != strconv.FormatUint(i, 10) {
			histServes.Unlock()
			return histAnswerNo + " " + histWhyNone, true
		}
		if why == "" && i+1 > s.asked {
			s.asked = i + 1
		}
		histServes.Unlock()
		if why != "" {
			return histAnswerNo + " " + why, true
		}
		snd := histSender(C.longlong(send))
		if snd == nil {
			return histAnswerNo + " " + histWhyEnded, true
		}
		b, err := snd.Record(i)
		if err != nil {
			return histAnswerNo + " " + histWhyNone, true
		}
		return histAnswerYes + " " + base64.StdEncoding.EncodeToString(b), true
	}
	histServes.Unlock()
	return histAnswerNo + " " + histWhyNone, true
}

// a line of the device's tally, "<i>/<n>:<base64>": whole once every line
// came. s held locked
func (s *histServe) takeTally(arg string) string {
	no := histAnswerNo + " " + histWhyNone
	pos, b64, found := strings.Cut(arg, ":")
	if !found || s.tally != nil {
		if s.tally != nil {
			return histAnswerYes + " ok"
		}
		return no
	}
	i, n, ok := chunkOf(pos)
	if !ok || n > devices.TallyMax/histTallyChunk+1 || len(b64) > base64.StdEncoding.EncodedLen(histTallyChunk) {
		return no
	}
	if s.parts == nil || s.nPart != n {
		s.parts, s.nPart = map[int]string{}, n
	}
	s.parts[i] = b64
	if len(s.parts) < n {
		return histAnswerYes + " more"
	}
	var all []byte
	for k := 0; k < n; k++ {
		b, err := base64.StdEncoding.DecodeString(s.parts[k])
		if err != nil {
			s.parts = nil
			return no
		}
		all = append(all, b...)
	}
	s.parts = nil
	if len(all) > devices.TallyMax {
		return no
	}
	s.tally = all
	return histAnswerYes + " ok"
}

// ---- the device ----

// how the device reaches the phone's door: a stream to the onion
type histDialer func(ctx context.Context, onion string) (net.Conn, error)

var (
	histDialNow histDialer = func(ctx context.Context, onion string) (net.Conn, error) {
		mu.Lock()
		t := torNode
		mu.Unlock()
		if t == nil {
			return nil, errLinkUnreached
		}
		return doorDial(ctx, t, onion+".onion")
	}
	// one ask and its answer, a whole media chunk over tor included
	histAskWait = 90 * time.Second
)

// the most an answer line takes: a record in base64, and its word
var histAnswerMost = base64.StdEncoding.EncodedLen(histMaxRecord) + 64

// the device keeps one stream to its phone's door while it asks
var histCli struct {
	sync.Mutex
	onion string
	conn  net.Conn
	r     *bufio.Reader
}

func histDropConn() {
	if histCli.conn != nil {
		histCli.conn.Close()
	}
	histCli.conn, histCli.r, histCli.onion = nil, nil, ""
}

// one line out and its answer back, on the kept stream or a new one. the
// door shuts a stream after a minute or a quiet while, so a stream that
// fails is dialed once more
func histAsk(onion, line string) (string, error) {
	histCli.Lock()
	defer histCli.Unlock()
	for try := 0; try < 2; try++ {
		if histCli.conn == nil || histCli.onion != onion {
			histDropConn()
			ctx, cancel := context.WithTimeout(context.Background(), histAskWait)
			c, err := histDialNow(ctx, onion)
			cancel()
			if err != nil {
				return "", errLinkUnreached
			}
			histCli.conn, histCli.r, histCli.onion = c, bufio.NewReaderSize(c, 64<<10), onion
		}
		c := histCli.conn
		c.SetDeadline(time.Now().Add(histAskWait))
		if _, err := c.Write([]byte(line + "\n")); err != nil {
			histDropConn()
			continue
		}
		ans, err := histReadLine(histCli.r)
		if err != nil {
			histDropConn()
			continue
		}
		return ans, nil
	}
	return "", errLinkUnreached
}

func histReadLine(r *bufio.Reader) (string, error) {
	var b []byte
	for {
		frag, err := r.ReadSlice('\n')
		b = append(b, frag...)
		if len(b) > histAnswerMost {
			return "", errLineTooLong
		}
		if err == bufio.ErrBufferFull {
			continue
		}
		if err != nil {
			return "", err
		}
		return strings.TrimRight(string(b), "\r\n"), nil
	}
}

func histAskLine(ask *devices.Ask, op, arg string) string {
	mac := ask.MAC(op, arg)
	return histAskPrefix + hex.EncodeToString(ask.Tag[:]) + " " + op + " " + arg + " " + hex.EncodeToString(mac[:])
}

// HaloHistFetch runs one of the device's asks of its phone: op, and its
// args as json. it blocks until the phone answers or the wait runs out.
//
//export HaloHistFetch
func HaloHistFetch(cOp, cArgs *C.char) *C.char {
	return C.CString(histFetchJSON(goStr(cOp), goStr(cArgs)))
}

func histFetchJSON(op, raw string) string {
	out := &histServeOut{}
	var a histServeArgs
	err := json.Unmarshal([]byte(raw), &a)
	if err == nil {
		err = histFetchCall(op, &a, out)
	}
	if err != nil {
		out.Err = whyOf(err)
		if errors.Is(err, errLinkUnreached) {
			out.Err = lsWhyReach
		}
	}
	b, _ := json.Marshal(out)
	return string(b)
}

func histFetchCall(op string, a *histServeArgs, out *histServeOut) error {
	if op == "close" {
		histCli.Lock()
		histDropConn()
		histCli.Unlock()
		return nil
	}
	if len(a.Onion) != 56 || strings.Trim(a.Onion, "abcdefghijklmnopqrstuvwxyz234567") != "" {
		return errors.New("bad onion")
	}
	key, bind, err := histStreamKey(a.Key, a.Bind)
	if err != nil {
		return err
	}
	defer clear(key[:])
	ask, err := devices.AskFor(key, bind)
	if err != nil {
		return err
	}
	defer ask.Wipe()
	switch op {
	case "hello":
		ans, err := histAsk(a.Onion, histAskLine(ask, "hello", "-"))
		if err != nil {
			return err
		}
		f := strings.Fields(ans)
		if len(f) == 2 && f[0] == histAnswerNo {
			out.Why = f[1]
			return nil
		}
		if len(f) != 3 || f[0] != histAnswerYes {
			return errors.New("not an answer")
		}
		gen, err := strconv.ParseUint(f[1], 10, 32)
		id, err2 := hex.DecodeString(f[2])
		if err != nil || err2 != nil || len(id) != devices.IDSize {
			return errors.New("not an answer")
		}
		g, err := devices.AgainKey(key, bind, uint32(gen))
		if err != nil {
			return err
		}
		out.Gen, out.ID, out.Key = uint32(gen), f[2], hex.EncodeToString(g[:])
		clear(g[:])
		return nil
	case "rec":
		ans, err := histAsk(a.Onion, histAskLine(ask, "rec", strconv.FormatUint(a.I, 10)))
		if err != nil {
			return err
		}
		f := strings.Fields(ans)
		if len(f) == 2 && f[0] == histAnswerNo {
			out.Why = f[1]
			return nil
		}
		if len(f) != 2 || f[0] != histAnswerYes {
			return errors.New("not an answer")
		}
		b, err := base64.StdEncoding.DecodeString(f[1])
		if err != nil || len(b) > histMaxRecord {
			return errors.New("not an answer")
		}
		out.Rec = b
		return nil
	case "tally":
		if len(a.Tally) == 0 || len(a.Tally) > devices.TallyMax {
			return errors.New("bad tally")
		}
		n := (len(a.Tally) + histTallyChunk - 1) / histTallyChunk
		for i := 0; i < n; i++ {
			part := a.Tally[i*histTallyChunk : min((i+1)*histTallyChunk, len(a.Tally))]
			arg := strconv.Itoa(i) + "/" + strconv.Itoa(n) + ":" + base64.StdEncoding.EncodeToString(part)
			ans, err := histAsk(a.Onion, histAskLine(ask, "tally", arg))
			if err != nil {
				return err
			}
			f := strings.Fields(ans)
			if len(f) == 2 && f[0] == histAnswerNo {
				out.Why = f[1]
				return nil
			}
			if len(f) != 2 || f[0] != histAnswerYes {
				return errors.New("not an answer")
			}
		}
		out.Ok = true
		return nil
	}
	return errors.New("no such call")
}
