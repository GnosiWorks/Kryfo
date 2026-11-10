// SPDX-License-Identifier: GPL-3.0-or-later
package main

// big files go through our files service (server/files) instead of the
// relay: sealed here with a key of their own, sent up in parts, and fetched
// by each recipient with the key from the message. over tor on every route,
// each file on a circuit of its own, so the service never sees an address
// and cannot tie two files to one circuit.
//
// the id, the key, the sender's token and each recipient's token come from
// the identity key, the message id and the file's hash. a send cut off
// starts again with the same values and goes on from the parts that are
// in, and nothing about a file is kept on this phone but the file.

import "C"

import (
	"bytes"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/bits"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// the service's wire, as server/files has it
const (
	dropChunk  = 64 << 10
	dropSealed = dropChunk + 16
	dropPart   = 80 * dropSealed
	// the most recipients one file names
	dropMaxGot = 256
)

// where a file may be. a message names a host by its key, never by a url:
// a sender cannot point a phone at a server of their choosing
var dropHosts = map[string]string{"f1": "https://files.kryfo.app"}

// the service says the bits a new upload needs (server/files, bitsNow)

// the sender's token on what only the sender does, a recipient's on a
// download (server/files/main.go)
const (
	dropOwnHeader   = "X-Kryfo-Own"
	dropTokenHeader = "X-Kryfo-Token"
)

// tries per part and per download before the call gives up. the app calls
// again later and goes on from where it was
var dropTries = 4
var dropPause = 2 * time.Second

func dropPadChunks(n int) int {
	if n <= 16 {
		return n
	}
	e := bits.Len(uint(n)) - 4
	step := 1 << e
	return (n + step - 1) / step * step
}

// how a transfer dials: through tor, under a socks name of its own. tests
// stand their own in
var dropDial = func(lane string) (dialFn, error) {
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil {
		return nil, fmt.Errorf("tor not started")
	}
	d, err := torDialerAs(context.Background(), t, laneName(lane))
	if err != nil {
		return nil, err
	}
	return d.DialContext, nil
}

func dropClient(lane string) (*http.Client, error) {
	dial, err := dropDial(lane)
	if err != nil {
		return nil, err
	}
	return &http.Client{
		Transport: &http.Transport{
			DialContext:           dial,
			TLSHandshakeTimeout:   20 * time.Second,
			ResponseHeaderTimeout: 60 * time.Second,
		},
		CheckRedirect: noRedirect,
	}, nil
}

// ---- progress and cancel: "s:<message id>" for a send, "f:<file id>" for
// a fetch ----

type dropJob struct {
	done, total atomic.Int64
	// 1 while the work for a send is done, before any byte goes: the app
	// shows it as preparing
	preparing atomic.Bool
	cancel    context.CancelFunc
}

var (
	dropJobsMu sync.Mutex
	dropJobs   = map[string]*dropJob{}
)

func dropStart(key string) (*dropJob, context.Context, bool) {
	dropJobsMu.Lock()
	defer dropJobsMu.Unlock()
	if dropJobs[key] != nil {
		return nil, nil, false
	}
	ctx, cancel := context.WithCancel(context.Background())
	j := &dropJob{cancel: cancel}
	dropJobs[key] = j
	return j, ctx, true
}

func dropEnd(key string) {
	dropJobsMu.Lock()
	if j := dropJobs[key]; j != nil {
		j.cancel()
		delete(dropJobs, key)
	}
	dropJobsMu.Unlock()
}

// "<done> <total> <preparing>" in bytes for a transfer under way, or ""
//
//export HaloFileProgress
func HaloFileProgress(cKey *C.char) *C.char {
	return C.CString(dropProgress(goStr(cKey)))
}

func dropProgress(key string) string {
	dropJobsMu.Lock()
	j := dropJobs[key]
	dropJobsMu.Unlock()
	if j == nil {
		return ""
	}
	p := 0
	if j.preparing.Load() {
		p = 1
	}
	return fmt.Sprintf("%d %d %d", j.done.Load(), j.total.Load(), p)
}

// stops a transfer under way. it ends with "error: cancelled"
//
//export HaloFileCancel
func HaloFileCancel(cKey *C.char) *C.char {
	dropCancel(goStr(cKey))
	return C.CString("ok")
}

func dropCancel(key string) {
	dropJobsMu.Lock()
	if j := dropJobs[key]; j != nil {
		j.cancel()
	}
	dropJobsMu.Unlock()
}

// ---- the values a file is sent under ----

type dropValues struct {
	id, own string
	key     []byte
	seed    []byte
}

func dropMac(key []byte, parts ...string) []byte {
	m := hmac.New(sha256.New, key)
	m.Write([]byte(strings.Join(parts, "\x00")))
	return m.Sum(nil)
}

func dropDerive(secret []byte, uid string, fileSum []byte) dropValues {
	seed := dropMac(secret, "kryfo-file-seed-v1", uid, hex.EncodeToString(fileSum))
	return dropValues{
		id:   hex.EncodeToString(dropMac(seed, "id")[:16]),
		own:  hex.EncodeToString(dropMac(seed, "own")),
		key:  dropMac(seed, "key"),
		seed: seed,
	}
}

func (v dropValues) token(member string) string {
	return hex.EncodeToString(dropMac(v.seed, "got", member))
}

func sha256Hex(h string) string {
	b, _ := hex.DecodeString(h)
	s := sha256.Sum256(b)
	return hex.EncodeToString(s[:])
}

// the secret the values come from: the identity key, so they are the same
// after a restart and nobody else can make them. a var for the tests
var dropSecret = func() ([]byte, error) {
	k := handleKey()
	if len(k) == 0 {
		return nil, errors.New("no identity")
	}
	defer clear(k)
	seed := k.Seed()
	defer clear(seed)
	return dropMac(seed, "kryfo-files"), nil
}

func fileSum(path string) ([]byte, int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, 0, err
	}
	defer f.Close()
	h := sha256.New()
	n, err := io.Copy(h, f)
	if err != nil {
		return nil, 0, err
	}
	return h.Sum(nil), n, nil
}

func dropValuesFor(path, uid string) (dropValues, []byte, int64, error) {
	secret, err := dropSecret()
	if err != nil {
		return dropValues{}, nil, 0, err
	}
	sum, size, err := fileSum(path)
	if err != nil {
		return dropValues{}, nil, 0, err
	}
	return dropDerive(secret, uid, sum), sum, size, nil
}

// ---- sealing ----

func dropAEAD(key []byte) (cipher.AEAD, error) {
	b, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(b)
}

// the nonce is the chunk's place; the extra data is how many chunks the
// file has, so a file cut short or put together out of order does not open
func dropNonce(i int) []byte {
	n := make([]byte, 12)
	binary.BigEndian.PutUint64(n[4:], uint64(i))
	return n
}

func dropAAD(chunks int) []byte { return []byte("kryfo-file-v1:" + strconv.Itoa(chunks)) }

// chunk i of the file at f, sealed. past the end it is zeros, so every
// chunk is the same size and the last says nothing of where the file ends
func sealChunk(a cipher.AEAD, f io.ReaderAt, size int64, i, chunks int, buf []byte) ([]byte, error) {
	plain := buf[:dropChunk]
	clear(plain)
	off := int64(i) * dropChunk
	if off < size {
		n := min(int64(dropChunk), size-off)
		if _, err := f.ReadAt(plain[:n], off); err != nil && !errors.Is(err, io.EOF) {
			return nil, err
		}
	}
	return a.Seal(nil, dropNonce(i), plain, dropAAD(chunks)), nil
}

// ---- send ----

type dropSendJob struct {
	Path    string   `json:"path"`
	UID     string   `json:"uid"`
	Members []string `json:"members"`
	Host    string   `json:"host"`
	// a take back by the values alone, read from the file before it went
	ID  string `json:"id"`
	Own string `json:"own"`
}

type dropSent struct {
	ID     string `json:"id"`
	Key    string `json:"key"`
	Size   int64  `json:"size"`
	Chunks int    `json:"chunks"`
	// the file's sha256, which the recipient checks once it is opened
	Sum    string            `json:"sum"`
	Tokens map[string]string `json:"tokens"`
	// its parts went up in this call: false for a file the service had
	// whole already, or every recipient has
	Sent bool `json:"sent"`
}

// seals the file at path and sends it up, going on from what a send before
// left. the values for the message as json, or "error: <word>": full,
// limit, busy, big, gone, cancelled, read, net, tor
//
//export HaloFileSend
func HaloFileSend(cJob *C.char) *C.char {
	return C.CString(dropSend(goStr(cJob)))
}

func dropSend(jobJSON string) string {
	var job dropSendJob
	if json.Unmarshal([]byte(jobJSON), &job) != nil || job.Path == "" || job.UID == "" {
		return "error: bad"
	}
	base, ok := dropHosts[job.Host]
	if !ok {
		return "error: bad"
	}
	if len(job.Members) == 0 || len(job.Members) > dropMaxGot {
		return "error: bad"
	}
	v, sum, size, err := dropValuesFor(job.Path, job.UID)
	if err != nil {
		return "error: read"
	}
	if size == 0 {
		return "error: read"
	}
	// the file's lane goes with the send: a name a file is never kept
	defer dropLane("files:" + v.id)
	// the app follows and stops a send by its message, a fetch by its file
	key := "s:" + job.UID
	j, ctx, ok := dropStart(key)
	if !ok {
		return "error: busy"
	}
	defer dropEnd(key)
	chunks := dropPadChunks(int((size + dropChunk - 1) / dropChunk))
	sealed := int64(chunks) * dropSealed
	j.total.Store(sealed)
	c, err := dropClient("files:" + v.id)
	if err != nil {
		return "error: tor"
	}
	defer c.CloseIdleConnections()
	out := dropSent{ID: v.id, Key: hex.EncodeToString(v.key), Size: size, Chunks: chunks, Sum: hex.EncodeToString(sum), Tokens: map[string]string{}}
	got := []string{}
	for _, m := range job.Members {
		t := v.token(m)
		out.Tokens[m] = t
		got = append(got, sha256Hex(t))
	}
	word, sent := dropUpload(ctx, c, base, job, v, size, chunks, sealed, got, j)
	out.Sent = sent
	if word != "" {
		if word == "cancelled" {
			// what went up of it goes too
			dropTakeBack(c, base, v)
		}
		return "error: " + word
	}
	b, _ := json.Marshal(out)
	return string(b)
}

func dropUpload(ctx context.Context, c *http.Client, base string, job dropSendJob, v dropValues, size int64, chunks int, sealed int64, got []string, j *dropJob) (string, bool) {
	w := dropUploadParts(ctx, c, base, job, v, size, chunks, sealed, got, j)
	if w == "whole" {
		return "", false
	}
	return w, true
}

// "" once the parts are up, "whole" for a file that needed none
func dropUploadParts(ctx context.Context, c *http.Client, base string, job dropSendJob, v dropValues, size int64, chunks int, sealed int64, got []string, j *dropJob) string {
	var begun struct {
		Have []int `json:"have"`
		End  bool  `json:"end"`
		Gone bool  `json:"gone"`
		Bits int   `json:"bits"`
	}
	// asked first with the work already done for this file, or none: a
	// file the service holds goes on with no work, and a new one is told
	// the bits it needs now
	pow, _ := dropNonceOf(v.id, sealed)
	// one budget for the work of a send, however many rounds it is asked
	until := time.Now().Add(dropPowBudget)
	for round := 0; ; round++ {
		// nothing of the sender in it: no key, no day, nothing two uploads
		// of one person share
		body, _ := json.Marshal(map[string]any{
			"id": v.id, "size": sealed, "got": got, "own": sha256Hex(v.own), "pow": pow,
		})
		word := dropAsk(ctx, c, http.MethodPost, base+"/files/new", body, &begun, nil)
		if word == "" {
			break
		}
		if word != "work" || round >= 3 || begun.Bits <= 0 || begun.Bits > dropPowMost {
			if word == "work" {
				return "busy"
			}
			return word
		}
		j.preparing.Store(true)
		n, err := dropPowWithin(ctx, v.id, sealed, begun.Bits, until)
		j.preparing.Store(false)
		if errors.Is(err, errDropPowLong) {
			// more than a phone should spend: slices, or a calm try later
			return "busy"
		}
		if err != nil {
			return "cancelled"
		}
		pow = n
	}
	// whole already, or every recipient has it: the frame goes again, the
	// file does not
	if begun.End || begun.Gone {
		j.done.Store(sealed)
		return "whole"
	}
	f, err := os.Open(job.Path)
	if err != nil {
		return "read"
	}
	defer f.Close()
	a, err := dropAEAD(v.key)
	if err != nil {
		return "read"
	}
	parts := int((sealed + dropPart - 1) / dropPart)
	have := map[int]bool{}
	for _, n := range begun.Have {
		have[n] = true
	}
	for round := 0; round < 2; round++ {
		for n := 0; n < parts; n++ {
			if have[n] {
				continue
			}
			if word := dropPutPart(ctx, c, base, v.id, v.own, f, a, size, chunks, n, j, have); word != "" {
				return word
			}
			have[n] = true
		}
		var ended struct {
			E    string `json:"e"`
			Have []int  `json:"have"`
		}
		word := dropAsk(ctx, c, http.MethodPost, base+"/files/"+v.id+"/end", nil, &ended, map[string]string{dropOwnHeader: v.own})
		if word == "" {
			j.done.Store(sealed)
			return ""
		}
		if word != "clash" {
			return word
		}
		// the service lacks a part it said it had: send what it names
		have = map[int]bool{}
		for _, n := range ended.Have {
			have[n] = true
		}
	}
	return "busy"
}

// the work for one upload, bound to its id and size
// the work for one upload, bound to its id and size, at the bits the
// service asks. what was done is kept for the process, so a resume, a
// resend or a group's owed members never do it twice
func dropPow(ctx context.Context, id string, sealed int64, want int) (uint64, error) {
	if n, bits := dropNonceOf(id, sealed); bits >= want {
		return n, nil
	}
	// 0 is no work at all, as the first ask sends it
	for n := uint64(1); ; n++ {
		if dropPowHolds(id, sealed, n, want) {
			dropNoncesMu.Lock()
			if len(dropNonces) > 4096 {
				dropNonces = map[string]workDone{}
			}
			dropNonces[id+":"+strconv.FormatInt(sealed, 10)] = workDone{n, want}
			dropNoncesMu.Unlock()
			return n, nil
		}
		if n&0xffff == 0 && ctx.Err() != nil {
			return 0, ctx.Err()
		}
	}
}

// the most bits an engine grinds: past it the service is flooded, and the
// send waits for later
const dropPowMost = 30

// and the most time: a flood, or a service that asks too much, never keeps
// a slow phone's cores busy past this. a var for the tests
var dropPowBudget = 60 * time.Second

var errDropPowLong = errors.New("work past its time")

// the grind itself, a var so the tests can make it slow
var dropGrind = dropPow

// the work done by [until], or errDropPowLong
func dropPowWithin(ctx context.Context, id string, sealed int64, want int, until time.Time) (uint64, error) {
	if !time.Now().Before(until) {
		return 0, errDropPowLong
	}
	tctx, cancel := context.WithDeadline(ctx, until)
	defer cancel()
	n, err := dropGrind(tctx, id, sealed, want)
	if err != nil && ctx.Err() == nil {
		return 0, errDropPowLong
	}
	return n, err
}

type workDone struct {
	n    uint64
	bits int
}

var (
	dropNoncesMu sync.Mutex
	dropNonces   = map[string]workDone{}
)

func dropNonceOf(id string, sealed int64) (uint64, int) {
	dropNoncesMu.Lock()
	defer dropNoncesMu.Unlock()
	d := dropNonces[id+":"+strconv.FormatInt(sealed, 10)]
	return d.n, d.bits
}

func (j *dropJob) progressOf(have map[int]bool, sealed int64) {
	var d int64
	for n := range have {
		d += min(int64(dropPart), sealed-int64(n)*dropPart)
	}
	j.done.Store(d)
}

func dropPutPart(ctx context.Context, c *http.Client, base, id, own string, f io.ReaderAt, a cipher.AEAD, size int64, chunks, n int, j *dropJob, have map[int]bool) string {
	first := n * 80
	last := min(first+80, chunks)
	part := make([]byte, 0, (last-first)*dropSealed)
	buf := make([]byte, dropChunk)
	for i := first; i < last; i++ {
		s, err := sealChunk(a, f, size, i, chunks, buf)
		if err != nil {
			return "read"
		}
		part = append(part, s...)
	}
	sealed := int64(chunks) * dropSealed
	j.progressOf(have, sealed)
	start := j.done.Load()
	var word string
	for try := 0; try < dropTries; try++ {
		if try > 0 && !dropWait(ctx, try) {
			return "cancelled"
		}
		pr := &progressReader{r: bytes.NewReader(part), j: j, from: start}
		req, err := http.NewRequestWithContext(ctx, http.MethodPut, fmt.Sprintf("%s/files/%s/%d", base, id, n), pr)
		if err != nil {
			return "bad"
		}
		req.ContentLength = int64(len(part))
		req.Header.Set("User-Agent", "")
		req.Header.Set(dropOwnHeader, own)
		word = dropDo(ctx, c, req, nil)
		// busy on a part: another writer still on the file, which the
		// service stops for this one. a moment later it is gone
		if word == "" || !(dropRetry(word) || word == "busy") {
			return word
		}
	}
	return word
}

type progressReader struct {
	r    io.Reader
	j    *dropJob
	from int64
	n    int64
}

func (p *progressReader) Read(b []byte) (int, error) {
	k, err := p.r.Read(b)
	p.n += int64(k)
	p.j.done.Store(p.from + p.n)
	return k, err
}

// a pause before another try, cut short by a cancel
func dropWait(ctx context.Context, try int) bool {
	t := time.NewTimer(dropPause * time.Duration(try))
	defer t.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-t.C:
		return true
	}
}

// what is worth another try at once: the network, and a service briefly
// busy. full and limit are for later, and the app says so
func dropRetry(word string) bool { return word == "net" }

func dropAsk(ctx context.Context, c *http.Client, method, url string, body []byte, into any, hdr map[string]string) string {
	var word string
	for try := 0; try < dropTries; try++ {
		if try > 0 && !dropWait(ctx, try) {
			return "cancelled"
		}
		var r io.Reader
		if body != nil {
			r = strings.NewReader(string(body))
		}
		req, err := http.NewRequestWithContext(ctx, method, url, r)
		if err != nil {
			return "bad"
		}
		req.Header.Set("User-Agent", "")
		for k, v := range hdr {
			req.Header.Set(k, v)
		}
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}
		word = dropDo(ctx, c, req, into)
		if word == "" || !dropRetry(word) {
			return word
		}
	}
	return word
}

// one request: "" for a 2xx, else the service's word for it
func dropDo(ctx context.Context, c *http.Client, req *http.Request, into any) string {
	resp, err := c.Do(req)
	if err != nil {
		if ctx.Err() != nil {
			return "cancelled"
		}
		return "net"
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if resp.StatusCode/100 == 2 {
		if into != nil {
			_ = json.Unmarshal(b, into)
		}
		return ""
	}
	var e struct {
		E string `json:"e"`
	}
	_ = json.Unmarshal(b, &e)
	if into != nil {
		_ = json.Unmarshal(b, into)
	}
	switch e.E {
	case "full", "limit", "busy", "big", "gone", "clash", "denied", "work":
		return e.E
	}
	if resp.StatusCode >= 500 {
		// a proxy in front with the service down
		return "net"
	}
	return "bad"
}

// ---- the work ----

func dropPowHolds(id string, size int64, nonce uint64, want int) bool {
	h := sha256.Sum256([]byte("kryfo-files-v2:" + id + ":" + strconv.FormatInt(size, 10) + ":" + strconv.FormatUint(nonce, 10)))
	got := 0
	for _, b := range h {
		if b == 0 {
			got += 8
			continue
		}
		got += bits.LeadingZeros8(b)
		break
	}
	return got >= want
}

// ---- take back, got ----

func dropTakeBack(c *http.Client, base string, v dropValues) string {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	body, _ := json.Marshal(map[string]string{"t": v.own})
	word := dropAsk(ctx, c, http.MethodPost, base+"/files/"+v.id+"/drop", body, nil, nil)
	if word == "gone" {
		return ""
	}
	return word
}

// the sender takes a file back: a cancel after it went up, or an unsend.
// the values come from the file again. "ok" or "error: <word>"
//
//export HaloFileDrop
func HaloFileDrop(cJob *C.char) *C.char {
	return C.CString(dropDrop(goStr(cJob)))
}

func dropDrop(jobJSON string) string {
	var job dropSendJob
	if json.Unmarshal([]byte(jobJSON), &job) != nil {
		return "error: bad"
	}
	base, ok := dropHosts[job.Host]
	if !ok {
		return "error: bad"
	}
	var v dropValues
	if job.ID != "" {
		if !dropIDShape(job.ID) || !dropHexShape(job.Own) {
			return "error: bad"
		}
		v = dropValues{id: job.ID, own: job.Own}
	} else {
		var err error
		if v, _, _, err = dropValuesFor(job.Path, job.UID); err != nil {
			return "error: read"
		}
	}
	defer dropLane("files:" + v.id)
	c, err := dropClient("files:" + v.id)
	if err != nil {
		return "error: tor"
	}
	defer c.CloseIdleConnections()
	if word := dropTakeBack(c, base, v); word != "" {
		return "error: " + word
	}
	return "ok"
}

// the id and the sender's token of a file sent under this message, read
// from the file: what a take back needs once the file is gone from here.
// {"id","own"} or "error: read"
//
//export HaloFileValues
func HaloFileValues(cJob *C.char) *C.char {
	return C.CString(dropValuesJSON(goStr(cJob)))
}

func dropValuesJSON(jobJSON string) string {
	var job dropSendJob
	if json.Unmarshal([]byte(jobJSON), &job) != nil || job.Path == "" || job.UID == "" {
		return "error: bad"
	}
	v, _, _, err := dropValuesFor(job.Path, job.UID)
	if err != nil {
		return "error: read"
	}
	b, _ := json.Marshal(map[string]string{"id": v.id, "own": v.own})
	return string(b)
}

// a recipient has the whole file: the service lets it go once every
// recipient has said so. a file already gone is fine
//
//export HaloFileGot
func HaloFileGot(cHost, cID, cToken *C.char) *C.char {
	return C.CString(dropGot(goStr(cHost), goStr(cID), goStr(cToken)))
}

func dropGot(host, id, token string) string {
	base, ok := dropHosts[host]
	if !ok || !dropIDShape(id) || len(token) != 64 {
		return "error: bad"
	}
	defer dropLane("files:" + id)
	c, err := dropClient("files:" + id)
	if err != nil {
		return "error: tor"
	}
	defer c.CloseIdleConnections()
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	body, _ := json.Marshal(map[string]string{"t": token})
	word := dropAsk(ctx, c, http.MethodPost, base+"/files/"+id+"/got", body, nil, nil)
	if word == "" || word == "gone" {
		return "ok"
	}
	return "error: " + word
}

func dropIDShape(id string) bool {
	if len(id) != 32 {
		return false
	}
	_, err := hex.DecodeString(id)
	return err == nil && strings.ToLower(id) == id
}

// ---- fetch ----

type dropFetchJob struct {
	Host   string `json:"host"`
	ID     string `json:"id"`
	Key    string `json:"key"`
	Size   int64  `json:"size"`
	Chunks int    `json:"chunks"`
	Path   string `json:"path"`
	// this recipient's token, which the service asks for a download
	Token string `json:"token"`
	// the file's sha256 as the sender read it
	Sum string `json:"sum"`
	// the sealed bytes only, into path.part, with no key to open them:
	// hidden chats closed. "held" once all are in
	Blind bool `json:"blind"`
}

// a fetch whose bytes on disk do not open is fetched again from the chunk
// that failed this many times before it is given up: a power cut can leave
// a chunk that was never written
var dropOpenTries = 2

// fetches a file into path, whole and opened or not at all. the sealed
// bytes of a fetch cut off stay beside it in path.part, and the next call
// goes on from there. they are opened only once all are in, through a file
// moved over whole, so bytes a power cut left unchecked never reach the
// file. "ok", "held" for a blind fetch, or "error: <word>": gone, denied,
// bad (it does not open, or is not the file that was sent), cancelled,
// net, tor, file
//
//export HaloFileFetch
func HaloFileFetch(cJob *C.char) *C.char {
	return C.CString(dropFetch(goStr(cJob)))
}

func dropFetch(jobJSON string) string {
	var job dropFetchJob
	if json.Unmarshal([]byte(jobJSON), &job) != nil || job.Path == "" {
		return "error: bad"
	}
	base, ok := dropHosts[job.Host]
	if !ok || !dropIDShape(job.ID) || !dropHexShape(job.Token) {
		return "error: bad"
	}
	var a cipher.AEAD
	var sum []byte
	if !job.Blind {
		key, err := hex.DecodeString(job.Key)
		if err != nil || len(key) != 32 {
			return "error: bad"
		}
		if sum, err = hex.DecodeString(job.Sum); err != nil || len(sum) != 32 {
			return "error: bad"
		}
		if a, err = dropAEAD(key); err != nil {
			return "error: bad"
		}
	}
	need := int((job.Size + dropChunk - 1) / dropChunk)
	if job.Size <= 0 || job.Chunks < need || dropPadChunks(need) != job.Chunks {
		return "error: bad"
	}
	j, ctx, ok := dropStart("f:" + job.ID)
	if !ok {
		return "error: busy"
	}
	defer dropEnd("f:" + job.ID)
	defer dropLane("files:" + job.ID)
	sealed := int64(job.Chunks) * dropSealed
	j.total.Store(sealed)
	c, err := dropClient("files:" + job.ID)
	if err != nil {
		return "error: tor"
	}
	defer c.CloseIdleConnections()
	part := job.Path + ".part"
	f, err := os.OpenFile(part, os.O_RDWR|os.O_CREATE, 0o600)
	if err != nil {
		return "error: file"
	}
	word := ""
	for round := 0; round <= dropOpenTries; round++ {
		word = dropFetchRounds(ctx, c, base, job, a, f, j)
		if word != "" {
			break
		}
		if job.Blind {
			word = "held"
			break
		}
		bad, w := dropOpenInto(f, a, job, sum)
		word = w
		if word != "bad" || bad < 0 {
			break
		}
		// a chunk on disk that does not open: from it on, again
		if f.Truncate(int64(bad)*dropSealed) != nil {
			word = "file"
			break
		}
	}
	f.Close()
	switch word {
	case "held":
		return "held"
	case "", "bad", "gone", "denied":
		// a file whole or one that will not come needs its sealed bytes
		// no more
		_ = os.Remove(part)
	}
	if word != "" {
		return "error: " + word
	}
	return "ok"
}

func dropHexShape(t string) bool {
	if len(t) != 64 {
		return false
	}
	_, err := hex.DecodeString(t)
	return err == nil
}

func dropFetchRounds(ctx context.Context, c *http.Client, base string, job dropFetchJob, a cipher.AEAD, f *os.File, j *dropJob) string {
	word := ""
	for try := 0; try < dropTries; try++ {
		if try > 0 && !dropWait(ctx, try) {
			return "cancelled"
		}
		word = dropFetchFrom(ctx, c, base, job, a, f, j)
		if word == "" || !dropRetry(word) {
			return word
		}
	}
	return word
}

// the rest of the sealed bytes, from the last whole chunk on disk. each
// chunk is checked as it comes when there is a key, so a wrong key stops
// at once
func dropFetchFrom(ctx context.Context, c *http.Client, base string, job dropFetchJob, a cipher.AEAD, f *os.File, j *dropJob) string {
	st, err := f.Stat()
	if err != nil {
		return "file"
	}
	sealed := int64(job.Chunks) * dropSealed
	from := int(min(st.Size(), sealed) / dropSealed)
	if from == job.Chunks {
		j.done.Store(sealed)
		return ""
	}
	j.done.Store(int64(from) * dropSealed)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base+"/files/"+job.ID, nil)
	if err != nil {
		return "bad"
	}
	req.Header.Set("User-Agent", "")
	req.Header.Set(dropTokenHeader, job.Token)
	if from > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", int64(from)*dropSealed))
	}
	resp, err := c.Do(req)
	if err != nil {
		if ctx.Err() != nil {
			return "cancelled"
		}
		return "net"
	}
	defer resp.Body.Close()
	switch {
	case resp.StatusCode == http.StatusNotFound:
		return "gone"
	case resp.StatusCode == http.StatusForbidden:
		return "denied"
	case resp.StatusCode == http.StatusOK && from == 0, resp.StatusCode == http.StatusPartialContent && from > 0:
	default:
		// a proxy in front, a limit, a range it did not take: for later,
		// never the end of the file
		return "net"
	}
	if resp.ContentLength >= 0 && resp.ContentLength != sealed-int64(from)*dropSealed {
		return "net"
	}
	buf := make([]byte, dropSealed)
	aad := dropAAD(job.Chunks)
	for i := from; i < job.Chunks; i++ {
		if _, err := io.ReadFull(resp.Body, buf); err != nil {
			if ctx.Err() != nil {
				return "cancelled"
			}
			return "net"
		}
		if a != nil {
			if _, err := a.Open(nil, dropNonce(i), buf, aad); err != nil {
				return "bad"
			}
		}
		if _, err := f.WriteAt(buf, int64(i)*dropSealed); err != nil {
			return "file"
		}
		j.done.Store(int64(i+1) * dropSealed)
	}
	return ""
}

// every sealed chunk opened again from disk into path, through a file
// beside it that is moved over only once it is whole and its hash is the
// sender's. the chunk that did not open, or -1
func dropOpenInto(f *os.File, a cipher.AEAD, job dropFetchJob, sum []byte) (int, string) {
	tmp := job.Path + ".open"
	out, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return -1, "file"
	}
	word, bad := "", -1
	h := sha256.New()
	buf := make([]byte, dropSealed)
	aad := dropAAD(job.Chunks)
	for i := 0; i < job.Chunks && word == ""; i++ {
		if _, err := f.ReadAt(buf, int64(i)*dropSealed); err != nil {
			word, bad = "bad", i
			break
		}
		plain, err := a.Open(nil, dropNonce(i), buf, aad)
		if err != nil {
			word, bad = "bad", i
			break
		}
		off := int64(i) * dropChunk
		switch {
		case off < job.Size:
			n := min(int64(dropChunk), job.Size-off)
			h.Write(plain[:n])
			if _, err := out.Write(plain[:n]); err != nil {
				word = "file"
			} else if !allZero(plain[n:]) {
				word = "bad"
			}
		case !allZero(plain):
			// past the end there is nothing but filler
			word = "bad"
		}
	}
	// every chunk opened, but not into the file the sender read: it
	// changed on their side while it went
	if word == "" && !hmac.Equal(h.Sum(nil), sum) {
		word = "bad"
	}
	if word == "" {
		if err := out.Sync(); err != nil {
			word = "file"
		}
	}
	if err := out.Close(); err != nil && word == "" {
		word = "file"
	}
	if word == "" && os.Rename(tmp, job.Path) != nil {
		word = "file"
	}
	if word != "" {
		_ = os.Remove(tmp)
	}
	return bad, word
}
