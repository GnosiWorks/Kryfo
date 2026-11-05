// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the steps of this process's first start, for a computer's trace: tor's
// percent, tor ready, the route proven, the first relay socket up, the
// first batch and every batch caught up. times since the engine started
// and counts only, never an address, a relay or an id

import (
	"fmt"
	"strings"
	"sync"
	"time"
)

import "C"

type startLog struct {
	mu   sync.Mutex
	t0   time.Time
	pct  int
	seen map[string]bool
	// batch lane -> its addresses, and the addresses caught up once
	members map[string]map[string]bool
	caught  map[string]bool
	done    map[string]bool
	all     bool
	lines   []string
	// the route first proven, and the start's new messages in: the batch
	// of the chats on top of the list, or the first batch when none was told
	routeAt time.Time
	inNow   bool
	// the relays a first-contact listener connected to, and its lines in
	fcRelays map[string]bool
	fcLines  int
}

// how long after the route was proven a start reads as caught up anyway
var startCaughtMost = 90 * time.Second

var startSteps = &startLog{}

// a new process start, at t
func (s *startLog) reset(t time.Time) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.t0, s.pct, s.all = t, -1, false
	s.routeAt, s.inNow = time.Time{}, false
	s.fcRelays, s.fcLines = nil, 0
	s.seen = map[string]bool{}
	s.members = map[string]map[string]bool{}
	s.caught = map[string]bool{}
	s.done = map[string]bool{}
	s.lines = nil
}

// the first start only: a bounce later is not this start's
func (s *startLog) begin() {
	s.mu.Lock()
	zero := s.t0.IsZero()
	s.mu.Unlock()
	if zero {
		s.reset(time.Now())
	}
}

// under mu
func (s *startLog) addLocked(line string) {
	if s.t0.IsZero() || len(s.lines) >= 64 {
		return
	}
	s.lines = append(s.lines, fmt.Sprintf("%s +%.1fs", line, time.Since(s.t0).Seconds()))
}

// once per start
func (s *startLog) once(key, line string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.t0.IsZero() || s.seen[key] {
		return
	}
	s.seen[key] = true
	s.addLocked(line)
}

func (s *startLog) torPct(p int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.t0.IsZero() || s.seen["tor ready"] || p <= s.pct {
		return
	}
	s.pct = p
	s.addLocked(fmt.Sprintf("tor %d%%", p))
}

func (s *startLog) torReady() { s.once("tor ready", "tor ready") }
func (s *startLog) relayUp()  { s.once("relay", "first relay connected") }

func (s *startLog) routeProven() {
	s.once("route", "route proven")
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.t0.IsZero() || !s.routeAt.IsZero() {
		return
	}
	s.routeAt = time.Now()
	// nobody to catch up on
	if len(s.members) == 0 {
		s.inNow = true
	}
}

// the start's new messages are in, as far as the home's line goes
func (s *startLog) caughtNow() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.t0.IsZero() || s.inNow || s.all ||
		(!s.routeAt.IsZero() && time.Since(s.routeAt) > startCaughtMost)
}

// a first-contact listener's socket came up on another relay, or a line
// came in on it: counts only, for the trace of a scan that seems lost
func (s *startLog) fcUp(u string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.t0.IsZero() || s.fcRelays[u] {
		return
	}
	if s.fcRelays == nil {
		s.fcRelays = map[string]bool{}
	}
	s.fcRelays[u] = true
	s.addLocked(fmt.Sprintf("first-contact listener connected (%d relays)", len(s.fcRelays)))
}

func (s *startLog) fcIn() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.t0.IsZero() {
		return
	}
	s.fcLines++
	s.addLocked(fmt.Sprintf("first contact came in by relay (%d so far)", s.fcLines))
}

// rcvPk listens in the batch on lane
func (s *startLog) member(lane, rcvPk string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.t0.IsZero() || s.all {
		return
	}
	m := s.members[lane]
	if m == nil {
		m = map[string]bool{}
		s.members[lane] = m
	}
	m[rcvPk] = true
}

// rcvPk's window is in from a relay
func (s *startLog) caughtUp(rcvPk string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.t0.IsZero() || s.all || s.caught[rcvPk] {
		return
	}
	s.caught[rcvPk] = true
	for lane, m := range s.members {
		if s.done[lane] || !m[rcvPk] {
			continue
		}
		in := true
		for a := range m {
			if !s.caught[a] {
				in = false
				break
			}
		}
		if !in {
			continue
		}
		s.done[lane] = true
		if first := startFirstLane(); first == "" || first == lane {
			s.inNow = true
		}
		if len(s.done) == 1 {
			s.addLocked(fmt.Sprintf("first batch caught up (%d of %d addresses)", len(m), s.countLocked()))
		}
	}
	if len(s.members) > 0 && len(s.done) == len(s.members) {
		s.all = true
		s.addLocked(fmt.Sprintf("all batches caught up (%d batches, %d addresses)", len(s.members), s.countLocked()))
	}
}

// under mu: the addresses in every batch
func (s *startLog) countLocked() int {
	n := 0
	for _, m := range s.members {
		n += len(m)
	}
	return n
}

// what came since the last call, one step a line
func (s *startLog) take() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := strings.Join(s.lines, "\n")
	s.lines = nil
	return out
}

// the start's steps since the last call, one a line, "" for none
//
//export HaloStartSteps
func HaloStartSteps() *C.char { return C.CString(startSteps.take()) }

// "1" once the start's new messages are in (the home says getting new
// messages until then), "0" before
//
//export HaloStartCaught
func HaloStartCaught() *C.char {
	if startSteps.caughtNow() {
		return C.CString("1")
	}
	return C.CString("0")
}

// the address of a catch-up key
func rcvOfKey(k string) string {
	if i := strings.IndexByte(k, ' '); i >= 0 {
		return k[i+1:]
	}
	return ""
}
