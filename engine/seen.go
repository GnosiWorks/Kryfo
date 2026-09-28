// SPDX-License-Identifier: GPL-3.0-or-later
package main

// what a relay runner remembers of the events it has finished with, so a
// reconnect or a restart does not open them again. bounded in memory and on
// disk whatever a relay sends: the newest ids stay, the oldest go first.
// an event that opened is remembered only once the app has taken it from the
// poll, so a batch that never reached the app is fetched again.

import (
	"encoding/hex"
	"os"
	"strings"
	"sync"
	"sync/atomic"

	"fiatjaf.com/nostr"
)

const (
	// ids of events that opened: more than a day of media on one address
	seenKeep = 3000
	// ids of events that did not open. kept apart, so the ids of events that
	// opened stay whatever else arrives
	seenUnopenedKeep = 500
	// the file is rewritten to what is kept once it holds this many lines
	seenFileMax = seenKeep + seenUnopenedKeep + 100
)

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
	lines  int
}

// the ids a runner starts with. path "" keeps them in memory only.
func loadSeen(path string) *seenIDs {
	s := &seenIDs{path: path, opened: newIDRing(seenKeep), unopened: newIDRing(seenUnopenedKeep),
		queued: map[nostr.ID]struct{}{}}
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
		notOpen := strings.HasPrefix(line, seenUnopenedMark)
		id, ok := parseSeenID(strings.TrimPrefix(line, seenUnopenedMark))
		if !ok {
			continue
		}
		if notOpen {
			s.unopened.add(id)
		} else {
			s.opened.add(id)
		}
	}
	if s.lines > seenFileMax {
		s.compactLocked()
	}
	return s
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
	if _, ok := s.queued[id]; ok {
		return false
	}
	s.queued[id] = struct{}{}
	return true
}

// an event that did not open: remembered now, it will never be handed over
func (s *seenIDs) notOpened(id nostr.ID) {
	s.mu.Lock()
	delete(s.queued, id)
	s.unopened.add(id)
	s.mu.Unlock()
	s.write([]string{seenUnopenedMark + id.Hex()})
}

// events the app has taken from the poll
func (s *seenIDs) handedOver(ids []nostr.ID) {
	lines := make([]string, 0, len(ids))
	s.mu.Lock()
	for _, id := range ids {
		delete(s.queued, id)
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

// rewrites the file to the newest ids of each kind it holds. it reads the
// file rather than this runner's memory, which may not hold what another
// runner on the same file wrote. seenFileMu must be held.
func (s *seenIDs) compactLocked() {
	if engineHeld.Load() || fileGone(s.path) {
		return
	}
	b, err := os.ReadFile(s.path)
	if err != nil {
		return
	}
	var opened, unopened []string
	for _, line := range strings.Split(string(b), "\n") {
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, seenUnopenedMark) {
			unopened = append(unopened, line)
		} else {
			opened = append(opened, line)
		}
	}
	if len(opened) > seenKeep {
		opened = opened[len(opened)-seenKeep:]
	}
	if len(unopened) > seenUnopenedKeep {
		unopened = unopened[len(unopened)-seenUnopenedKeep:]
	}
	keep := append(opened, unopened...)
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

// what a line in the inbox still owes once the app has taken it
type inboxDone struct {
	set *seenIDs
	id  nostr.ID
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
	for _, s := range order {
		s.handedOver(by[s])
	}
}
