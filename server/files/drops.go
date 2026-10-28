// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what the service keeps about each file: its size, which parts are in,
// the hash of each recipient's token and of the sender's. nothing of the
// sender at all: no key, no address, no name. a sender's own daily limit
// is counted on the phone; here there are only caps for everyone together.
//
// nothing a request declares costs anyone else for long: the day's bytes
// count what came in, a file that stops sending parts lets its room go in
// minutes, and the records, the files still coming and each record's size
// have caps, so neither a flood of begins nor a restart on a full index can
// shut the service.

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"math"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// a file as it is kept on disk
type dropDisk struct {
	ID    string `json:"id"`
	Size  int64  `json:"size,omitempty"`
	Parts []bool `json:"parts,omitempty"`
	Ended bool   `json:"ended,omitempty"`
	// a record of the round before the delivered set: dropped at start
	Gone  bool     `json:"gone,omitempty"`
	Got   []string `json:"got,omitempty"`
	Taken []bool   `json:"taken,omitempty"`
	Own   string   `json:"own,omitempty"`
	At    int64    `json:"at"`
	Last  int64    `json:"last,omitempty"`
}

// a file as it is held in memory
type drop struct {
	id    string
	size  int64
	parts []bool
	ended bool
	got   [][32]byte
	taken []bool
	own   [32]byte
	at    int64
	// when a part last came
	last int64
	// bytes of its parts in, counted once a part
	written int64
	// bytes served to each recipient's token: past three times the file,
	// nobody is fetching it for themselves
	served map[[32]byte]int64
	// the part being written: one writer a file, and the owner's next PUT
	// takes over from one that stalled
	w *writer
}

// a part being written, and how to stop it: its request's body is cut
type writer struct {
	kill func()
	done chan struct{}
}

func (d *drop) have() []int {
	out := []int{}
	for i, ok := range d.parts {
		if ok {
			out = append(out, i)
		}
	}
	return out
}

func (d *drop) toDisk() dropDisk {
	out := dropDisk{
		ID: d.id, Size: d.size, Parts: d.parts, Ended: d.ended,
		Taken: d.taken, Own: hex.EncodeToString(d.own[:]), At: d.at, Last: d.last,
	}
	for _, g := range d.got {
		out.Got = append(out.Got, hex.EncodeToString(g[:]))
	}
	return out
}

func unhash(s string) ([32]byte, bool) {
	var out [32]byte
	b, err := hex.DecodeString(s)
	if err != nil || len(b) != 32 {
		return out, false
	}
	copy(out[:], b)
	return out, true
}

func fromDisk(r dropDisk) (*drop, bool) {
	if r.Gone {
		return nil, false
	}
	own, ok := unhash(r.Own)
	if !ok || !idShape.MatchString(r.ID) || r.Size <= 0 || r.Size%chunkSealed != 0 {
		return nil, false
	}
	if int64(len(r.Parts)) != (r.Size+partSize-1)/partSize || len(r.Got) != len(r.Taken) || len(r.Got) > maxGot {
		return nil, false
	}
	d := &drop{id: r.ID, size: r.Size, parts: r.Parts, ended: r.Ended, taken: r.Taken, own: own, at: r.At, last: r.Last}
	for _, g := range r.Got {
		h, ok := unhash(g)
		if !ok {
			return nil, false
		}
		d.got = append(d.got, h)
	}
	for i, in := range d.parts {
		if in {
			d.written += partLen(d.size, i)
		}
	}
	return d, true
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
	// bytes that came in today, and files begun in the last hour, for
	// everyone together
	dayBytes  int64
	hourFiles int
	// files every recipient has, kept for their week, at most
	maxDelivered int
	// a file goes this long after it came, taken or not
	keep time.Duration
	// a file whose parts never all came goes after this
	unfinished time.Duration
	// and one that has sent no part for this long, so a begin with nothing
	// behind it holds its room for minutes, not a day. a file of one part
	// sends it at once or not at all
	idle      time.Duration
	idleSmall time.Duration
	// records kept at most, a hard cap: each is memory
	maxFiles int
	// bytes still coming at which the work starts to rise
	maxComing int64
	// the work an upload costs: this many bits for a file under 1 MB, one
	// more for each doubling, at most powCap. past half of any cap the
	// service asks one more bit for each tenth over
	powBase, powCap int
}

type counts struct {
	made, ended, taken, gone, swept, full, busy int
	in, out                                     int64
}

type service struct {
	cfg   config
	store blobStore
	index string
	now   func() time.Time

	mu    sync.Mutex
	drops map[string]*drop
	day   string
	today int64
	// files begun in each of the last sixty minutes, by the minute
	begunIn [60]int
	begunAt [60]int64
	// the files every recipient has (delivered.go)
	delivered *deliveredSet
	// running sums: the bytes every file holds, what the files
	// still coming may yet write, and how many are still coming
	held, coming int64
	open         int
	c            counts
}

// the most one record may take on disk: anything larger is not one of ours
const maxRecord = 16 << 10

func newService(cfg config, store blobStore, stateDir string) (*service, error) {
	s := &service{
		cfg:   cfg,
		store: store,
		index: filepath.Join(stateDir, "index"),
		now:   time.Now,
		drops: map[string]*drop{},
	}
	if err := os.MkdirAll(s.index, 0o700); err != nil {
		return nil, err
	}
	var err error
	s.delivered, err = openDelivered(filepath.Join(stateDir, "delivered.log"), cfg.maxDelivered, cfg.keep, s.now())
	if err != nil {
		return nil, err
	}
	ents, err := os.ReadDir(s.index)
	if err != nil {
		return nil, err
	}
	now := s.now()
	for _, e := range ents {
		id, ok := strings.CutSuffix(e.Name(), ".json")
		if !ok || !idShape.MatchString(id) {
			continue
		}
		p := filepath.Join(s.index, e.Name())
		d := s.load(p, id)
		// past the cap or past its time, a record goes before anything is
		// served: a start never holds more than it may
		if d == nil || len(s.drops) >= cfg.maxFiles || s.expired(d, now) {
			_ = os.Remove(p)
			_ = store.remove(id)
			continue
		}
		s.add(d)
	}
	return s, nil
}

// one record, or nil for one cut short, too large or out of shape
func (s *service) load(p, id string) *drop {
	f, err := os.Open(p)
	if err != nil {
		return nil
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, maxRecord+1))
	if err != nil || len(b) > maxRecord {
		return nil
	}
	var r dropDisk
	if json.Unmarshal(b, &r) != nil || r.ID != id {
		return nil
	}
	d, ok := fromDisk(r)
	if !ok {
		return nil
	}
	return d
}

func (s *service) add(d *drop) {
	s.drops[d.id] = d
	s.held += d.size
	if !d.ended {
		s.coming += d.size - d.written
		s.open++
	}
}

// written aside and moved over, so a crash leaves the old record or the
// new one
func (s *service) save(d *drop) error {
	b, err := json.Marshal(d.toDisk())
	if err != nil {
		return err
	}
	p := filepath.Join(s.index, d.id+".json")
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, p)
}

// what an error was, without the path in it: a path names a file
func errKind(err error) string {
	var pe *fs.PathError
	if errors.As(err, &pe) {
		return pe.Op + ": " + pe.Err.Error()
	}
	return fmt.Sprintf("%T", err)
}

// the bytes go and the sums with them. the record stays when [tomb], so a
// send of the same message again is told it went
func (s *service) letBytesGo(d *drop) {
	s.held -= d.size
	if !d.ended {
		s.coming -= d.size - d.written
		s.open--
	}
	if err := s.store.remove(d.id); err != nil {
		log.Printf("files: a file did not go: %s", errKind(err))
	}
}

// the record and the bytes, in that order: bytes without a record are
// swept, a record without bytes is a file that is gone
func (s *service) forget(id string) {
	d := s.drops[id]
	if d == nil {
		return
	}
	delete(s.drops, id)
	_ = os.Remove(filepath.Join(s.index, id+".json"))
	s.letBytesGo(d)
}

func (s *service) rollDay(now time.Time) {
	day := now.UTC().Format("2006-01-02")
	if day != s.day {
		s.day = day
		s.today = 0
	}
}

type newReq struct {
	ID   string   `json:"id"`
	Size int64    `json:"size"`
	Got  []string `json:"got"`
	Own  string   `json:"own"`
	Pow  uint64   `json:"pow"`
}

var (
	errShape = errors.New("bad request")
	errBig   = errors.New("too big")
	errClash = errors.New("taken")
	errBusy  = errors.New("busy")
	errFull  = errors.New("full")
	errGone  = errors.New("gone")
	errWork  = errors.New("pow")
)

func (r newReq) valid(cfg config) error {
	if !idShape.MatchString(r.ID) || !keyShape.MatchString(r.Own) {
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
	return nil
}

// a file begun now, on its minute
func (s *service) begun(now time.Time) {
	m := now.Unix() / 60
	k := m % 60
	if s.begunAt[k] != m {
		s.begunAt[k], s.begunIn[k] = m, 0
	}
	s.begunIn[k]++
}

// files begun in the sixty minutes up to now
func (s *service) begunLastHour() int {
	m := s.now().Unix() / 60
	n := 0
	for k := range s.begunIn {
		if m-s.begunAt[k] < 60 {
			n += s.begunIn[k]
		}
	}
	return n
}

// work asked of a begin: the bits it needs now
type errMoreWork struct{ bits int }

func (e errMoreWork) Error() string { return "work" }

// the bits a new file of [size] needs now: its own, and more the fuller the
// service is: its records, the files begun this hour, the bytes still
// coming, the bytes it holds of the disk it may use, and the bytes that came
// in today. a flood pays for itself, twice for each bit, and its cost to
// others ends soon after it stops
func (s *service) bitsNow(size int64) int {
	b := min(powBits(s.cfg.powBase, size), s.cfg.powCap)
	disk := 1.0
	if free, err := s.store.free(); err == nil {
		if room := float64(free) - float64(s.cfg.floor) + float64(s.held); room > 0 {
			disk = float64(s.held) / room
		}
	}
	load := max(
		float64(len(s.drops))/float64(s.cfg.maxFiles),
		float64(s.begunLastHour())/float64(s.cfg.hourFiles),
		float64(s.coming)/float64(s.cfg.maxComing),
		disk,
		float64(s.today)/float64(s.cfg.dayBytes),
	)
	if load > 0.5 {
		b += int(math.Ceil((load-0.5)*10 - 1e-9))
	}
	return min(b, 40)
}

// what a begin answers: the parts in, whether it is whole, whether every
// recipient already has it
type begun struct {
	have        []int
	ended, gone bool
}

// a new file, or the one already begun under this id by the same sender:
// what it has so far, so a send cut off goes on from there
func (s *service) begin(r newReq) (begun, error) {
	now := s.now()
	if err := r.valid(s.cfg); err != nil {
		return begun{}, err
	}
	own, _ := unhash(r.Own)
	s.mu.Lock()
	defer s.mu.Unlock()
	// one already here goes on with no work: a resume, a resend, a group's
	// owed members. one every recipient has is told so, its owner alone:
	// to anyone else it says nothing of when the last one said got
	if g, ok := s.delivered.has(r.ID); ok {
		if g.own != own {
			return begun{}, errClash
		}
		return begun{gone: true}, nil
	}
	if d := s.drops[r.ID]; d != nil {
		if d.size != r.Size || d.own != own {
			return begun{}, errClash
		}
		return begun{d.have(), d.ended, false}, nil
	}
	if len(s.drops) >= s.cfg.maxFiles {
		s.c.busy++
		return begun{}, errBusy
	}
	s.rollDay(now)
	if s.today+r.Size > s.cfg.dayBytes {
		s.c.busy++
		return begun{}, errBusy
	}
	if !s.roomFor(r.Size) {
		s.c.full++
		return begun{}, errFull
	}
	// a nonce of 0 is an ask with no work, which a new file is told to do
	if need := s.bitsNow(r.Size); r.Pow == 0 || !powOK(r.ID, r.Size, r.Pow, need) {
		return begun{}, errMoreWork{need}
	}
	n := int((r.Size + partSize - 1) / partSize)
	d := &drop{
		id:    r.ID,
		size:  r.Size,
		parts: make([]bool, n),
		taken: make([]bool, len(r.Got)),
		own:   own,
		at:    now.Unix(),
		last:  now.Unix(),
	}
	for _, g := range r.Got {
		h, _ := unhash(g)
		d.got = append(d.got, h)
	}
	if err := s.save(d); err != nil {
		log.Printf("files: a record was not written: %s", errKind(err))
		return begun{}, errBusy
	}
	s.add(d)
	s.begun(now)
	s.c.made++
	return begun{have: []int{}}, nil
}

// the guard: the quota, and the floor of free disk with every file still
// coming in counted at what it may yet write. a disk that cannot be read
// takes nothing
func (s *service) roomFor(size int64) bool {
	if s.cfg.quota > 0 && s.held+size > s.cfg.quota {
		return false
	}
	free, err := s.store.free()
	if err != nil {
		log.Printf("files: free space not read: %s", errKind(err))
		return false
	}
	return free >= s.cfg.floor+uint64(s.coming)+uint64(size)
}

func ownOf(d *drop, token string) bool {
	h, ok := unhash(hashHex(token))
	return ok && h == d.own
}

// the part's length the file expects, its writer taken. only the sender
// writes, one writer a file. a writer still on the file is a PUT whose
// circuit died: the owner's new one stops it, waits for it to let go, and
// takes over
func (s *service) partSlot(id string, n int, own string, kill func()) (int64, *writer, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for try := 0; ; try++ {
		d := s.drops[id]
		if d == nil {
			return 0, nil, errGone
		}
		if !ownOf(d, own) {
			return 0, nil, errWork
		}
		if d.ended {
			return 0, nil, errClash
		}
		if n < 0 || n >= len(d.parts) {
			return 0, nil, errShape
		}
		if d.w == nil {
			w := &writer{kill: kill, done: make(chan struct{})}
			d.w = w
			return partLen(d.size, n), w, nil
		}
		if try > 0 {
			return 0, nil, errBusy
		}
		old := d.w
		s.mu.Unlock()
		old.kill()
		select {
		case <-old.done:
		case <-time.After(5 * time.Second):
		}
		s.mu.Lock()
	}
}

// lets go of a writer taken for a part that never came
func (s *service) release(id string, w *writer) {
	s.mu.Lock()
	if d := s.drops[id]; d != nil && d.w == w {
		d.w = nil
	}
	s.mu.Unlock()
	close(w.done)
}

// the part from the body straight to its place on disk. what came counts
// toward the day as it comes; a file that went while it came takes its
// bytes with it
func (s *service) putPart(id string, n int, body io.Reader, want int64, w *writer) error {
	err := s.store.writePart(id, n, body, want)
	s.mu.Lock()
	defer s.mu.Unlock()
	defer close(w.done)
	d := s.drops[id]
	if d == nil || d.ended {
		// dropped or swept while the part came in
		if d == nil {
			_ = s.store.remove(id)
		} else if d.w == w {
			d.w = nil
		}
		return errGone
	}
	if d.w != w {
		// stopped for the owner's next PUT, which writes this part again
		return errBusy
	}
	d.w = nil
	if err != nil {
		if !errors.Is(err, errShort) {
			log.Printf("files: a part was not written: %s", errKind(err))
			return errBusy
		}
		return errShape
	}
	s.c.in += want
	s.rollDay(s.now())
	s.today += want
	if !d.parts[n] {
		d.parts[n] = true
		d.written += want
		s.coming -= want
	}
	d.last = s.now().Unix()
	if err := s.save(d); err != nil {
		log.Printf("files: a record was not written: %s", errKind(err))
		return errBusy
	}
	return nil
}

// the parts in, for the sender alone
func (s *service) have(id, own string) (begun, int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil {
		return begun{}, 0, errGone
	}
	if !ownOf(d, own) {
		return begun{}, 0, errWork
	}
	return begun{d.have(), d.ended, false}, d.size, nil
}

func (s *service) end(id, own string) ([]int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil {
		return nil, errGone
	}
	if !ownOf(d, own) {
		return nil, errWork
	}
	if d.ended {
		return nil, nil
	}
	for _, ok := range d.parts {
		if !ok {
			return d.have(), errClash
		}
	}
	if err := s.store.seal(id); err != nil {
		log.Printf("files: a file was not sealed: %s", errKind(err))
		return nil, errBusy
	}
	d.ended = true
	if err := s.save(d); err != nil {
		d.ended = false
		return nil, errBusy
	}
	s.coming -= d.size - d.written
	s.open--
	s.c.ended++
	return nil, nil
}

func (d *drop) names(token string) bool {
	h, ok := unhash(hashHex(token))
	if !ok {
		return false
	}
	for _, g := range d.got {
		if g == h {
			return true
		}
	}
	return false
}

// a whole file, for one of its recipients. each token is served three
// times the file at most, ranges and all: enough for every resume and
// refetch, not for fetching it again and again. [want] is the most this
// download may serve, taken from the budget before a byte goes, so
// downloads side by side on one token share it
func (s *service) whole(id, token string, want func(size int64) int64) (int64, int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil || !d.ended {
		return 0, 0, errGone
	}
	if !d.names(token) {
		return 0, 0, errWork
	}
	h, _ := unhash(hashHex(token))
	w := want(d.size)
	if d.served[h]+w > 3*d.size {
		return 0, 0, errGone
	}
	if d.served == nil {
		d.served = map[[32]byte]int64{}
	}
	d.served[h] += w
	return d.size, w, nil
}

// what a download served against what it took: what it did not serve
// goes back on its token's count, and anything past it is charged
func (s *service) servedTo(id, token string, took, n int64) {
	h, ok := unhash(hashHex(token))
	if !ok || n == took {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if d := s.drops[id]; d != nil && d.served != nil {
		d.served[h] += n - took
	}
}

// one recipient has the whole file. once every recipient has said so, its
// bytes go. a token said twice counts once
func (s *service) taken(id, token string) error {
	h, ok := unhash(hashHex(token))
	if !ok {
		return errShape
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil {
		return errGone
	}
	known, left := false, 0
	for i, g := range d.got {
		if g == h {
			known = true
			if !d.taken[i] {
				d.taken[i] = true
				s.c.taken++
			}
		}
		if !d.taken[i] {
			left++
		}
	}
	if !known {
		return errWork
	}
	if left == 0 {
		// its id, its owner's hash and its day stay, apart, so a send of it
		// again sends no file
		if err := s.delivered.add(id, d.own, s.now()); err != nil {
			log.Printf("files: a delivered file not noted: %s", errKind(err))
		}
		s.forget(id)
		s.c.gone++
		return nil
	}
	if err := s.save(d); err != nil {
		log.Printf("files: a record was not written: %s", errKind(err))
	}
	return nil
}

// the sender takes the file back: a cancel, or a message unsent
func (s *service) dropBy(id, token string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := s.drops[id]
	if d == nil {
		return errGone
	}
	if !ownOf(d, token) {
		return errWork
	}
	s.forget(id)
	s.c.gone++
	return nil
}

func (s *service) expired(d *drop, now time.Time) bool {
	age := now.Sub(time.Unix(d.at, 0))
	if age > s.cfg.keep {
		return true
	}
	if d.ended {
		return false
	}
	idle := s.cfg.idle
	if len(d.parts) == 1 {
		idle = s.cfg.idleSmall
	}
	return age > s.cfg.unfinished || now.Sub(time.Unix(d.last, 0)) > idle
}

// files past their week, and uploads that stopped or never finished
func (s *service) sweep() int {
	now := s.now()
	s.mu.Lock()
	defer s.mu.Unlock()
	n := 0
	for id, d := range s.drops {
		if d.w == nil && s.expired(d, now) {
			s.forget(id)
			n++
		}
	}
	s.delivered.sweep(now)
	s.c.swept += n
	return n
}

// bytes the store holds that no record names: a crash between the two, or
// a part that came after its file went
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
	held, files := s.held, len(s.drops)
	s.mu.Unlock()
	log.Printf("files: %d new, %d whole, %d taken, %d gone, %d swept, refused %d full %d busy, %d MB in, %d MB out, holding %d files %d MB",
		c.made, c.ended, c.taken, c.gone, c.swept, c.full, c.busy, c.in>>20, c.out>>20, files, held>>20)
}

func (s *service) countOut(n int64) {
	s.mu.Lock()
	s.c.out += n
	s.mu.Unlock()
}

// the sha256 of a hex string's bytes, as hex, "" for one that is not hex
func hashHex(s string) string {
	b, err := hex.DecodeString(s)
	if err != nil {
		return ""
	}
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}
