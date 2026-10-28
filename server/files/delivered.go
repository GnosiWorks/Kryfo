// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the files every recipient has: their bytes went, and only the id, the
// sender's token hash and the day stay for the week, so a send of the same
// message again is told it went and uploads nothing. a set of its own,
// outside the records' cap and the load, with a cap of its own that lets the
// oldest go first: one let go costs at most one upload again on a resend.
// kept in an append log, rewritten at each start with what is still in time.

import (
	"bufio"
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type deliveredRec struct {
	own [32]byte
	day int64
}

type deliveredSet struct {
	path  string
	most  int
	keep  time.Duration
	m     map[string]deliveredRec
	order []string
	f     *os.File
	lines int
}

func dayStart(t time.Time) int64 { return t.Unix() / 86400 * 86400 }

func openDelivered(path string, most int, keep time.Duration, now time.Time) (*deliveredSet, error) {
	s := &deliveredSet{path: path, most: max(most, 1), keep: keep, m: map[string]deliveredRec{}}
	if f, err := os.Open(path); err == nil {
		sc := bufio.NewScanner(f)
		for sc.Scan() {
			p := strings.Fields(sc.Text())
			if len(p) != 3 || !idShape.MatchString(p[0]) {
				continue
			}
			own, ok := unhash(p[1])
			day, err := strconv.ParseInt(p[2], 10, 64)
			if !ok || err != nil || s.expired(day, now) {
				continue
			}
			s.put(p[0], deliveredRec{own, day})
		}
		f.Close()
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	if err := s.rewrite(); err != nil {
		return nil, err
	}
	return s, nil
}

func (s *deliveredSet) expired(day int64, now time.Time) bool {
	return now.Sub(time.Unix(day, 0)) > s.keep+24*time.Hour
}

// in memory, the oldest let go past the cap
func (s *deliveredSet) put(id string, r deliveredRec) {
	if _, ok := s.m[id]; !ok {
		s.order = append(s.order, id)
	}
	s.m[id] = r
	for len(s.m) > s.most && len(s.order) > 0 {
		delete(s.m, s.order[0])
		s.order = s.order[1:]
	}
}

// the log as memory holds it, written aside and moved over
func (s *deliveredSet) rewrite() error {
	if s.f != nil {
		s.f.Close()
		s.f = nil
	}
	tmp := s.path + ".tmp"
	f, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	w := bufio.NewWriter(f)
	kept := s.order[:0]
	for _, id := range s.order {
		r, ok := s.m[id]
		if !ok {
			continue
		}
		kept = append(kept, id)
		fmt.Fprintf(w, "%s %s %d\n", id, hex.EncodeToString(r.own[:]), r.day)
	}
	s.order = kept
	if err := w.Flush(); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmp, s.path); err != nil {
		return err
	}
	s.lines = len(s.order)
	s.f, err = os.OpenFile(s.path, os.O_WRONLY|os.O_APPEND, 0o600)
	return err
}

func (s *deliveredSet) add(id string, own [32]byte, now time.Time) error {
	r := deliveredRec{own, dayStart(now)}
	s.put(id, r)
	if s.f == nil {
		return fmt.Errorf("delivered log not open")
	}
	if _, err := fmt.Fprintf(s.f, "%s %s %d\n", id, hex.EncodeToString(own[:]), r.day); err != nil {
		return err
	}
	s.lines++
	// a log grown well past what memory holds is written again
	if s.lines > 2*len(s.m)+1000 {
		return s.rewrite()
	}
	return nil
}

func (s *deliveredSet) has(id string) (deliveredRec, bool) {
	r, ok := s.m[id]
	return r, ok
}

// past the week and a day: the oldest are first in the order
func (s *deliveredSet) sweep(now time.Time) int {
	n := 0
	for len(s.order) > 0 {
		id := s.order[0]
		r, ok := s.m[id]
		if ok && !s.expired(r.day, now) {
			break
		}
		delete(s.m, id)
		s.order = s.order[1:]
		n++
	}
	return n
}

func (s *deliveredSet) close() {
	if s.f != nil {
		s.f.Close()
	}
}
