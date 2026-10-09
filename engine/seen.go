// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what a relay runner remembers of the events it has finished with, so a
// reconnect or a restart does not open them again. bounded in memory and on
// disk whatever a relay sends: the newest ids stay, the oldest go first.
// an event that opened is remembered only once the app confirms it kept it,
// so what never reached the app, or did not go in, is fetched again.

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"fiatjaf.com/nostr"
)

const (
	// ids of events that opened: more than a day of media on one address
	seenKeep = 3000
	// ids of events that did not open. kept apart, so the ids of events that
	// opened stay whatever else arrives
	seenUnopenedKeep = 500
	// what the app left on the relay for later, a full shelf's, in groups:
	// a text is one, a file one however many slices. past this an address's
	// next one is taken as kept, so a flood costs a start nothing
	seenHeldKeep = 200
	// slices of one file held, the most the shelf keeps of a file
	seenHeldPerGroup = 512
	// ids held on an address, all groups together
	seenHeldMost = 2000
	// a relay keeps a wrap this long (its expiration tag), and no longer
	seenHeldFor = 14 * 24 * time.Hour
	// the file is rewritten to what is kept once it holds this many lines
	seenFileMax = seenKeep + seenUnopenedKeep + seenHeldMost + 100
)

// a held id is written as "+id stamp group". after a "!" line every id held
// before it is fetched again, after a "~" line every one goes as kept
const (
	seenHeldMark = "+"
	seenFreeMark = "!"
	seenDropMark = "~"
)

// an event left on the relay, whether it is wanted back now, and the group
// it is held in
type heldAt struct {
	at    nostr.Timestamp
	free  bool
	group string
}

// the group a held id is kept in: the app's name for it, hashed, or the id
// itself for a text
func heldGroup(id nostr.ID, name string) string {
	if name == "" {
		return id.Hex()[:16]
	}
	h := sha256.Sum256([]byte(name))
	return hex.EncodeToString(h[:8])
}

// whether one more id of group fits beside what is held: a group already
// there takes it up to its most, a new one only while there are fewer
// groups than seenHeldKeep
func heldRoom(held map[nostr.ID]heldAt, group string) bool {
	if len(held) >= seenHeldMost {
		return false
	}
	groups := map[string]bool{}
	in := 0
	for _, h := range held {
		groups[h.group] = true
		if h.group == group {
			in++
		}
	}
	if in > 0 {
		return in < seenHeldPerGroup
	}
	return len(groups) < seenHeldKeep
}

// moves on each time an address's held ids are let go of, by its file. a
// hold from a batch polled before that is not taken
var (
	heldFreedMu sync.Mutex
	heldFreed   = map[string]uint64{}
)

func heldGen(path string) uint64 {
	heldFreedMu.Lock()
	defer heldFreedMu.Unlock()
	return heldFreed[path]
}

// an unopened id is written with this in front, so a restart keeps the two
// apart.
// an older build reads it as an id nothing has
const seenUnopenedMark = "-"

// one seen-file operation at a time: a subscription that is replaced can
// still be finishing on the same file as the one replacing it
var seenFileMu sync.Mutex

// set while the app wipes itself: nothing is written into the data dir
var engineHeld atomic.Bool

// the files of receive addresses that were let go of: nothing still
// finishing on one writes it again, until a subscription on the address
// starts anew
var goneFiles sync.Map

func fileGone(path string) bool {
	_, ok := goneFiles.Load(path)
	return ok
}

// where a receive address keeps the ids it has seen and how far it got
func addressFiles(rcvPk string) (seenPath, lastPath string) {
	if savedDataDir == "" {
		return "", ""
	}
	short := rcvPk
	if len(short) > 16 {
		short = short[:16]
	}
	return savedDataDir + "/nostr_seen_" + short, savedDataDir + "/nostr_last_" + short
}

// the files of a receive address, off the disk and never written again by
// what is still finishing on them
func dropAddressFiles(rcvPk string) {
	seenPath, lastPath := addressFiles(rcvPk)
	if seenPath == "" {
		return
	}
	seenFileMu.Lock()
	defer seenFileMu.Unlock()
	for _, p := range []string{seenPath, seenPath + ".tmp", lastPath} {
		goneFiles.Store(p, struct{}{})
		os.Remove(p)
	}
}

// a fixed number of ids, the oldest dropped first
type idRing struct {
	ids  map[nostr.ID]struct{}
	ring []nostr.ID
	next int
}

func newIDRing(max int) *idRing {
	return &idRing{ids: make(map[nostr.ID]struct{}), ring: make([]nostr.ID, 0, max)}
}

func (r *idRing) has(id nostr.ID) bool {
	_, ok := r.ids[id]
	return ok
}

func (r *idRing) add(id nostr.ID) {
	if r.has(id) {
		return
	}
	if len(r.ring) < cap(r.ring) {
		r.ring = append(r.ring, id)
	} else {
		delete(r.ids, r.ring[r.next])
		r.ring[r.next] = id
		r.next = (r.next + 1) % len(r.ring)
	}
	r.ids[id] = struct{}{}
}

func (r *idRing) len() int { return len(r.ring) }

type seenIDs struct {
	mu       sync.Mutex
	path     string
	opened   *idRing
	unopened *idRing
	// taken by a runner and opened, not yet handed to the app, or being
	// opened right now
	queued map[nostr.ID]struct{}
	held   map[nostr.ID]heldAt
	lines  int
}

// the ids a runner starts with. path "" keeps them in memory only.
func loadSeen(path string) *seenIDs {
	s := &seenIDs{path: path, opened: newIDRing(seenKeep), unopened: newIDRing(seenUnopenedKeep),
		queued: map[nostr.ID]struct{}{}, held: map[nostr.ID]heldAt{}}
	if path == "" {
		return s
	}
	seenFileMu.Lock()
	defer seenFileMu.Unlock()
	b, err := os.ReadFile(path)
	if err != nil {
		return s
	}
	for _, line := range strings.Split(string(b), "\n") {
		if line == "" {
			continue
		}
		s.lines++
		s.readLine(line)
	}
	s.pruneHeld(time.Now())
	if s.lines > seenFileMax {
		s.compactLocked()
	}
	return s
}

// one line of the file, in the order it was written
func (s *seenIDs) readLine(line string) {
	switch {
	case line == seenFreeMark:
		for id, h := range s.held {
			h.free = true
			s.held[id] = h
		}
	case line == seenDropMark:
		for id := range s.held {
			s.opened.add(id)
			delete(s.held, id)
		}
	case strings.HasPrefix(line, seenHeldMark):
		id, at, group, ok := parseHeldLine(line)
		if !ok {
			return
		}
		if _, had := s.held[id]; had || heldRoom(s.held, group) {
			s.held[id] = heldAt{at: at, group: group}
		}
	case strings.HasPrefix(line, seenUnopenedMark):
		if id, ok := parseSeenID(line[len(seenUnopenedMark):]); ok {
			s.unopened.add(id)
			delete(s.held, id)
		}
	default:
		if id, ok := parseSeenID(line); ok {
			s.opened.add(id)
			delete(s.held, id)
		}
	}
}

func parseHeldLine(line string) (nostr.ID, nostr.Timestamp, string, bool) {
	f := strings.Fields(strings.TrimPrefix(line, seenHeldMark))
	if len(f) < 2 {
		return nostr.ID{}, 0, "", false
	}
	id, ok := parseSeenID(f[0])
	at, err := strconv.ParseInt(f[1], 10, 64)
	if !ok || err != nil {
		return nostr.ID{}, 0, "", false
	}
	group := id.Hex()[:16]
	if len(f) > 2 {
		group = f[2]
	}
	return id, nostr.Timestamp(at), group, true
}

func heldLine(id nostr.ID, h heldAt) string {
	return seenHeldMark + id.Hex() + " " + strconv.FormatInt(int64(h.at), 10) + " " + h.group
}

// what the relays no longer keep is not waited for
func heldGone(at nostr.Timestamp, now time.Time) bool {
	return int64(at) < now.Add(-seenHeldFor).Unix()
}

func (s *seenIDs) pruneHeld(now time.Time) {
	for id, h := range s.held {
		if heldGone(h.at, now) {
			delete(s.held, id)
		}
	}
}

func parseSeenID(h string) (nostr.ID, bool) {
	var id nostr.ID
	if len(h) != 64 {
		return id, false
	}
	if _, err := hex.Decode(id[:], []byte(h)); err != nil {
		return id, false
	}
	return id, true
}

// true when the id is new to this runner, which then owns it until it is
// marked unopened or handed over. a second relay's copy is a repeat from here on
func (s *seenIDs) claim(id nostr.ID) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.opened.has(id) || s.unopened.has(id) {
		return false
	}
	if h, ok := s.held[id]; ok && !h.free {
		return false
	}
	if _, ok := s.queued[id]; ok {
		return false
	}
	s.queued[id] = struct{}{}
	return true
}

// an event the app left on the relay until there is room for it, in the
// group the app names (a file's slices share one): passed over from here
// without being opened, and fetched by its id once let go. false when the
// address has no room for it or the relay no longer keeps it, and the
// caller takes it as kept
func (s *seenIDs) hold(id nostr.ID, at nostr.Timestamp, name string, now time.Time) bool {
	group := heldGroup(id, name)
	s.mu.Lock()
	delete(s.queued, id)
	s.pruneHeld(now)
	_, had := s.held[id]
	if heldGone(at, now) || (!had && !heldRoom(s.held, group)) {
		s.mu.Unlock()
		return false
	}
	h := heldAt{at: at, group: group}
	s.held[id] = h
	s.mu.Unlock()
	s.write([]string{heldLine(id, h)})
	return true
}

// freed ids a relay asked for, by its own answer, did not have: by file,
// id, then relay, how many connections came back without it
var (
	heldMissMu sync.Mutex
	heldMissed = map[string]map[nostr.ID]map[string]int{}
)

// freed ids [relay] answered for without them. one every relay of
// [relays] has, on two connections each, no longer exists and is not asked
// for again: another relay may still have one a first answer lacked
func (s *seenIDs) notOnRelay(relay string, relays []string, ids []nostr.ID) {
	var gone []nostr.ID
	heldMissMu.Lock()
	m := heldMissed[s.path]
	if m == nil {
		m = map[nostr.ID]map[string]int{}
		heldMissed[s.path] = m
	}
	for _, id := range ids {
		by := m[id]
		if by == nil {
			by = map[string]int{}
			m[id] = by
		}
		by[relay]++
		all := len(relays) > 0
		for _, u := range relays {
			if by[u] < 2 {
				all = false
				break
			}
		}
		if all {
			gone = append(gone, id)
			delete(m, id)
		}
	}
	heldMissMu.Unlock()
	var lines []string
	s.mu.Lock()
	for _, id := range gone {
		if h, ok := s.held[id]; ok && h.free {
			delete(s.held, id)
			s.opened.add(id)
			lines = append(lines, id.Hex())
		}
	}
	s.mu.Unlock()
	s.write(lines)
}

// held events let go of, which a connection asks the relay for by id
func (s *seenIDs) wanted(now time.Time) []nostr.ID {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pruneHeld(now)
	var out []nostr.ID
	for id, h := range s.held {
		if h.free {
			out = append(out, id)
		}
	}
	return out
}

// how many events the address leaves on the relay
func (s *seenIDs) heldCount() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.held)
}

// true when the app kept the id, on this run or one before
func (s *seenIDs) handed(id nostr.ID) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.opened.has(id)
}

// an event that did not open: remembered now, it will never be handed over
func (s *seenIDs) notOpened(id nostr.ID) {
	s.mu.Lock()
	delete(s.queued, id)
	delete(s.held, id)
	s.unopened.add(id)
	s.mu.Unlock()
	s.write([]string{seenUnopenedMark + id.Hex()})
}

// an id the app never kept and that is no longer offered: a copy that
// comes again is taken again
func (s *seenIDs) release(id nostr.ID) {
	s.mu.Lock()
	delete(s.queued, id)
	s.mu.Unlock()
}

// events the app confirmed it kept
func (s *seenIDs) handedOver(ids []nostr.ID) {
	lines := make([]string, 0, len(ids))
	s.mu.Lock()
	for _, id := range ids {
		delete(s.queued, id)
		delete(s.held, id)
		s.opened.add(id)
		lines = append(lines, id.Hex())
	}
	s.mu.Unlock()
	s.write(lines)
}

func (s *seenIDs) write(lines []string) {
	if s.path == "" || len(lines) == 0 || engineHeld.Load() {
		return
	}
	seenFileMu.Lock()
	defer seenFileMu.Unlock()
	if fileGone(s.path) {
		return
	}
	f, err := os.OpenFile(s.path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	_, err = f.WriteString(strings.Join(lines, "\n") + "\n")
	f.Close()
	if err != nil {
		return
	}
	s.lines += len(lines)
	if s.lines > seenFileMax {
		s.compactLocked()
	}
}

// rewrites the file to the newest ids of each kind it holds, and to what is
// still held. it reads the file rather than this runner's memory, which may
// not hold what another runner on the same file wrote. seenFileMu must be
// held.
func (s *seenIDs) compactLocked() {
	if engineHeld.Load() || fileGone(s.path) {
		return
	}
	b, err := os.ReadFile(s.path)
	if err != nil {
		return
	}
	var opened, unopened []string
	held := map[nostr.ID]heldAt{}
	var order []nostr.ID
	for _, line := range strings.Split(string(b), "\n") {
		switch {
		case line == "":
		case line == seenFreeMark:
			for id, h := range held {
				h.free = true
				held[id] = h
			}
		case line == seenDropMark:
			for _, id := range order {
				if _, ok := held[id]; ok {
					opened = append(opened, id.Hex())
					delete(held, id)
				}
			}
			order = nil
		case strings.HasPrefix(line, seenHeldMark):
			id, at, group, ok := parseHeldLine(line)
			if !ok {
				continue
			}
			if _, had := held[id]; !had {
				if !heldRoom(held, group) {
					continue
				}
				order = append(order, id)
			}
			held[id] = heldAt{at: at, group: group}
		case strings.HasPrefix(line, seenUnopenedMark):
			unopened = append(unopened, line)
			if id, ok := parseSeenID(line[len(seenUnopenedMark):]); ok {
				delete(held, id)
			}
		default:
			opened = append(opened, line)
			if id, ok := parseSeenID(line); ok {
				delete(held, id)
			}
		}
	}
	if len(opened) > seenKeep {
		opened = opened[len(opened)-seenKeep:]
	}
	if len(unopened) > seenUnopenedKeep {
		unopened = unopened[len(unopened)-seenUnopenedKeep:]
	}
	keep := append(opened, unopened...)
	// the ones let go of first, then the mark, then the ones still held
	now := time.Now()
	var still []string
	free := false
	for _, id := range order {
		h, ok := held[id]
		if !ok || heldGone(h.at, now) {
			continue
		}
		// once each, however often it was held
		delete(held, id)
		if h.free {
			keep = append(keep, heldLine(id, h))
			free = true
		} else {
			still = append(still, heldLine(id, h))
		}
	}
	if free {
		keep = append(keep, seenFreeMark)
	}
	keep = append(keep, still...)
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, []byte(strings.Join(keep, "\n")+"\n"), 0600); err != nil {
		os.Remove(tmp)
		return
	}
	if err := os.Rename(tmp, s.path); err != nil {
		os.Remove(tmp)
		return
	}
	s.lines = len(keep)
}

// a mark for every id the address holds, on its file: "!" to fetch them
// again, "~" to take them as kept. a runner reads it when it starts
func markHeldFile(path, mark string) {
	if path == "" || engineHeld.Load() {
		return
	}
	if mark == seenFreeMark {
		heldFreedMu.Lock()
		heldFreed[path]++
		heldFreedMu.Unlock()
	}
	seenFileMu.Lock()
	defer seenFileMu.Unlock()
	if fileGone(path) {
		return
	}
	if _, err := os.Stat(path); err != nil {
		return
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	f.WriteString(mark + "\n")
	f.Close()
}

// what a line in the inbox still owes once the app has taken it
type inboxDone struct {
	set *seenIDs
	id  nostr.ID
	// times the poll offered it and the app did not keep it
	tries int
	// the event's stamp, which the anchor file stays at or below until the
	// app keeps it, and the runner's save that moves the file up after
	at     nostr.Timestamp
	resave func(int64)
	// the stamp inside the wrap, the sender's own clock, for the app
	sent int64
	// heldGen of its file when the poll handed it over
	freed uint64
}

// remembers every event of a batch the poll handed over, one write per file
func markHandedOver(done []inboxDone) {
	if len(done) == 0 {
		return
	}
	by := map[*seenIDs][]nostr.ID{}
	var order []*seenIDs
	for _, d := range done {
		if d.set == nil {
			continue
		}
		if _, ok := by[d.set]; !ok {
			order = append(order, d.set)
		}
		by[d.set] = append(by[d.set], d.id)
	}
	saves := map[*seenIDs]func(int64){}
	for _, d := range done {
		if d.resave != nil {
			saves[d.set] = d.resave
		}
	}
	for _, s := range order {
		s.handedOver(by[s])
	}
	for _, save := range saves {
		save(0)
	}
}
