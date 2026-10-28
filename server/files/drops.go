// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what the service keeps about each file: its size, which parts are in,
// the hash of each recipient's token and of the sender's. no sender key,
// no address, no name: the sender's key for the day lives in memory only,
// for the daily limit, and goes with the day.

import (
	"encoding/json"
	"errors"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type drop struct {
	ID    string   `json:"id"`
	Size  int64    `json:"size"`
	Parts []bool   `json:"parts"`
	Ended bool     `json:"ended"`
	Got   []string `json:"got"`
	Taken []bool   `json:"taken"`
	Own   string   `json:"own"`
	At    int64    `json:"at"`
}

func (d *drop) have() []int {
	out := []int{}
	for i, ok := range d.Parts {
		if ok {
			out = append(out, i)
		}
	}
	return out
}

// how long part n of a file this size is
func partLen(size int64, n int) int64 {
	left := size - int64(n)*partSize
	if left > partSize {
		return partSize
	}
	return left
}

type config struct {
	// the most a file may be before sealing. the free size; a paid size
	// would be a second value checked here, nothing else changes
	maxPlain int64
	// below this much free space no new file is taken
	floor uint64
	// what all files together may hold, 0 for no cap but the disk
	quota int64
	// what one sender's key may send in a day
	senderDayBytes int64
	senderDayFiles int
	// what everyone together may send in a day
	dayBytes int64
	// a file goes this long after it came, taken or not
	keep time.Duration
	// a file whose parts never all came goes after this
	unfinished time.Duration
	powBits    int
	// parts held in memory at once, each up to partSize
	streams int
}

type usage struct {
	bytes int64
	files int
}

type counts struct {
	made, ended, taken, gone, swept, full, limit, busy int
	in, out                                            int64
}

type service struct {
	cfg   config
	store blobStore
	index string
	now   func() time.Time
	parts chan struct{}

	mu      sync.Mutex
	drops   map[string]*drop
	day     string
	senders map[string]*usage
	today   int64
	c       counts
}

func newService(cfg config, store blobStore, stateDir string) (*service, error) {
	s := &service{
		cfg:     cfg,
		store:   store,
		index:   filepath.Join(stateDir, "index"),
		now:     time.Now,
		parts:   make(chan struct{}, max(cfg.streams, 1)),
		drops:   map[string]*drop{},
		senders: map[string]*usage{},
	}
	if err := os.MkdirAll(s.index, 0o700); err != nil {
		return nil, err
	}
	ents, err := os.ReadDir(s.index)
	if err != nil {
		return nil, err
	}
	for _, e := range ents {
		id, ok := strings.CutSuffix(e.Name(), ".json")
		if !ok || !idShape.MatchString(id) {
			continue
		}
		b, err := os.ReadFile(filepath.Join(s.index, e.Name()))
		var d drop
		if err != nil || json.Unmarshal(b, &d) != nil || d.ID != id || len(d.Got) != len(d.Taken) {
			// a record cut short by a crash: its file goes with it
			_ = os.Remove(filepath.Join(s.index, e.Name()))
			_ = store.remove(id)
			continue
		}
		s.drops[id] = &d
	}
	return s, nil
}

// written aside and moved over, so a crash leaves the old record or the
// new one
func (s *service) save(d *drop) error {
	b, err := json.Marshal(d)
	if err != nil {
		return err
	}
	p := filepath.Join(s.index, d.ID+".json")
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, p)
}

// the record and the bytes, in that order: bytes without a record are
// swept at the next start, a record without bytes is a file that is gone
func (s *service) forget(id string) {
	delete(s.drops, id)
	_ = os.Remove(filepath.Join(s.index, id+".json"))
	if err := s.store.remove(id); err != nil {
		log.Printf("files: a file did not go: %v", err)
	}
}

func (s *service) rollDay(now time.Time) {
	day := now.UTC().Format("2006-01-02")
	if day != s.day {
		s.day = day
		s.senders = map[string]*usage{}
		s.today = 0
	}
}

type newReq struct {
	ID   string   `json:"id"`
	Size int64    `json:"size"`
	Got  []string `json:"got"`
	Own  string   `json:"own"`
	Day  string   `json:"day"`
	Who  string   `json:"who"`
	Pow  uint64   `json:"pow"`
}

var (
	errShape = errors.New("bad request")
	errBig   = errors.New("too big")
	errClash = errors.New("taken")
	errLimit = errors.New("limit")
	errBusy  = errors.New("busy")
	errFull  = errors.New("full")
	errGone  = errors.New("gone")
	errWork  = errors.New("pow")
)

func (r newReq) valid(cfg config, now time.Time) error {
	if !idShape.MatchString(r.ID) || !keyShape.MatchString(r.Own) || !keyShape.MatchString(r.Who) {
		return errShape
	}
	if len(r.Got) == 0 || len(r.Got) > maxGot {
		return errShape
	}
	for _, g := range r.Got {
		if !keyShape.MatchString(g) {
			return errShape
		}
	}
	if r.Size <= 0 || r.Size%chunkSealed != 0 {
		return errShape
	}
	n := int(r.Size / chunkSealed)
	if padChunks(n) != n {
		return errShape
	}
	if r.Size > maxSealed(cfg.maxPlain) {
		return errBig
	}
	if !dayOK(r.Day, now) || !powOK(r.Day, r.Who, r.Pow, cfg.powBits) {
		return errWork
	}
	return nil
}

// a new file, or the one already begun under this id by the same sender:
// what it has so far, so a send cut off goes on from there
func (s *service) begin(r newReq) (*drop, error) {
	now := s.now()
	if err := r.valid(s.cfg, now); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if d := s.drops[r.ID]; d != nil {
		if d.Size != r.Size || d.Own != r.Own {
			return nil, errClash
		}
		return d, nil
	}
	s.rollDay(now)
	u := s.senders[r.Day+":"+r.Who]
	if u == nil {
		u = &usage{}
	}
	if u.bytes+r.Size > s.cfg.senderDayBytes || u.files+1 > s.cfg.senderDayFiles {
		s.c.limit++
		return nil, errLimit
	}
	if s.today+r.Size > s.cfg.dayBytes {
		s.c.busy++
		return nil, errBusy
	}
	if !s.roomFor(r.Size) {
		s.c.full++
		return nil, errFull
	}
	n := int((r.Size + partSize - 1) / partSize)
	d := &drop{
		ID:    r.ID,
		Size:  r.Size,
		Parts: make([]bool, n),
		Got:   append([]string(nil), r.Got...),
		Taken: make([]bool, len(r.Got)),
		Own:   r.Own,
		At:    now.Unix(),
	}
	if err := s.save(d); err != nil {
		log.Printf("files: a record was not written: %v", err)
		return nil, errBusy
	}
	s.drops[r.ID] = d
	u.bytes += r.Size
	u.files++
	s.senders[r.Day+":"+r.Who] = u
	s.today += r.Size
	s.c.made++
	return d, nil
}

// the guard: the quota, and the floor of free disk with every file still
// coming in counted as if it were whole already. a disk that cannot be
// read takes nothing
func (s *service) roomFor(size int64) bool {
	var held, coming int64
	for _, d := range s.drops {
		held += d.Size
		if !d.Ended {
			coming += d.Size
		}
	}
	if s.cfg.quota > 0 && held+size > s.cfg.quota {
		return false
	}
	free, err := s.store.free()
	if err != nil {
		log.Printf("files: free space not read: %v", err)
		return false
	}
	need := s.cfg.floor + uint64(coming) + uint64(size)
	return free >= need
}

// the part's length the file expects, or an error
func (s *service) partSlot(id string, n int) (int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil {
		return 0, errGone
	}
	if d.Ended {
		return 0, errClash
	}
	if n < 0 || n >= len(d.Parts) {
		return 0, errShape
	}
	return partLen(d.Size, n), nil
}

func (s *service) putPart(id string, n int, b []byte) error {
	if err := s.store.writePart(id, n, b); err != nil {
		log.Printf("files: a part was not written: %v", err)
		return errBusy
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil || d.Ended {
		// dropped or swept while the part came in
		return errGone
	}
	d.Parts[n] = true
	if err := s.save(d); err != nil {
		log.Printf("files: a record was not written: %v", err)
		return errBusy
	}
	return nil
}

func (s *service) have(id string) (*drop, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil {
		return nil, errGone
	}
	cp := *d
	cp.Parts = append([]bool(nil), d.Parts...)
	return &cp, nil
}

func (s *service) end(id string) (*drop, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil {
		return nil, errGone
	}
	if d.Ended {
		return d, nil
	}
	for _, ok := range d.Parts {
		if !ok {
			return d, errClash
		}
	}
	if err := s.store.seal(id); err != nil {
		log.Printf("files: a file was not sealed: %v", err)
		return nil, errBusy
	}
	d.Ended = true
	if err := s.save(d); err != nil {
		d.Ended = false
		return nil, errBusy
	}
	s.c.ended++
	return d, nil
}

// a whole file, or errGone
func (s *service) whole(id string) (int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil || !d.Ended {
		return 0, errGone
	}
	return d.Size, nil
}

// one recipient has the whole file. once every recipient has said so, it
// goes. a token said twice counts once. how many have not said it yet
func (s *service) taken(id, token string) (int, error) {
	h := hashHex(token)
	if h == "" {
		return 0, errShape
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil {
		return 0, errGone
	}
	known := false
	left := 0
	for i, g := range d.Got {
		if g == h && !d.Taken[i] {
			d.Taken[i] = true
			s.c.taken++
		}
		if g == h {
			known = true
		}
		if !d.Taken[i] {
			left++
		}
	}
	if !known {
		return 0, errWork
	}
	if left == 0 {
		s.forget(id)
		s.c.gone++
		return 0, nil
	}
	if err := s.save(d); err != nil {
		log.Printf("files: a record was not written: %v", err)
	}
	return left, nil
}

// the sender takes the file back: a cancel, or a message unsent
func (s *service) dropBy(id, token string) error {
	h := hashHex(token)
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil {
		return errGone
	}
	if h == "" || h != d.Own {
		return errWork
	}
	s.forget(id)
	s.c.gone++
	return nil
}

// files past their week, and uploads that never finished
func (s *service) sweep() int {
	now := s.now()
	s.mu.Lock()
	defer s.mu.Unlock()
	n := 0
	for id, d := range s.drops {
		age := now.Sub(time.Unix(d.At, 0))
		if age > s.cfg.keep || (!d.Ended && age > s.cfg.unfinished) {
			s.forget(id)
			n++
		}
	}
	s.c.swept += n
	return n
}

// bytes a store holds that no record names: a crash between the two
func (s *service) sweepOrphans(dir string) {
	ents, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, e := range ents {
		if s.drops[e.Name()] == nil {
			_ = s.store.remove(e.Name())
		}
	}
}

// one line an hour, counts only
func (s *service) report() {
	s.mu.Lock()
	c := s.c
	s.c = counts{}
	var held int64
	for _, d := range s.drops {
		held += d.Size
	}
	files := len(s.drops)
	s.mu.Unlock()
	log.Printf("files: %d new, %d whole, %d taken, %d gone, %d swept, refused %d full %d limit %d busy, %d MB in, %d MB out, holding %d files %d MB",
		c.made, c.ended, c.taken, c.gone, c.swept, c.full, c.limit, c.busy, c.in>>20, c.out>>20, files, held>>20)
}

func (s *service) countIO(in, out int64) {
	s.mu.Lock()
	s.c.in += in
	s.c.out += out
	s.mu.Unlock()
}
