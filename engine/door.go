// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the onion door's streams. a file to a peer is a hundred and more lines to
// one onion, and a stream per line pays the stream's setup through the
// rendezvous circuit before each one. so while lines are going to an onion
// they share one stream: written one after another, acked in order.
//
// only lines to the same onion share a stream. the onion is the recipient,
// who reads every line anyway, and all streams to it already ride one
// rendezvous circuit, so a shared stream shows nobody anything new.
//
// an older door reads one line per stream and closes. a stream it closes
// right after its first ack marks that onion for a stream per line.

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"sync"
	"time"

	"github.com/cretz/bine/tor"
)

// how long a sender keeps a quiet stream. below the door's own wait for the
// next line, so the sender is the one to close it.
var doorKeep = 5 * time.Second

// how long the door waits for the next line on a stream, and how long one
// stream may hold a slot at all
var (
	doorNextLine = 10 * time.Second
	doorLife     = time.Minute
)

// lines one stream may carry before the door closes it
const doorLinesPerStream = inboxMaxLines

// how long an onion that closed after one line gets a stream per line
const doorSingleFor = 10 * time.Minute

var errDoorClosed = errors.New("door closed the stream")

type doorStream struct {
	onion string
	ready chan struct{} // closed once the dial is done
	conn  net.Conn      // set before ready closes, nil when the dial failed

	wmu sync.Mutex // one line on the wire at a time

	mu      sync.Mutex
	waiting []chan error // one per line written, in order
	acks    int
	lastAck time.Time
	err     error
	busy    int
	idle    *time.Timer
}

var (
	doorMu      sync.Mutex
	doorStreams = map[string]*doorStream{}
	doorSingle  = map[string]time.Time{}
)

func doorOneLineOnly(onion string) bool {
	doorMu.Lock()
	defer doorMu.Unlock()
	until, ok := doorSingle[onion]
	if ok && time.Now().After(until) {
		delete(doorSingle, onion)
		return false
	}
	return ok
}

// the kept stream to onion, or a new one. fresh says it was dialled for
// this line. lines that come while it is being dialled wait for it.
func doorGet(ctx context.Context, t *tor.Tor, onion string) (*doorStream, bool, error) {
	doorMu.Lock()
	if s := doorStreams[onion]; s != nil {
		s.mu.Lock()
		ok := s.err == nil
		if ok {
			s.busy++
			if s.idle != nil {
				s.idle.Stop()
			}
		}
		s.mu.Unlock()
		if ok {
			doorMu.Unlock()
			select {
			case <-s.ready:
			case <-ctx.Done():
				s.done()
				return nil, false, ctx.Err()
			}
			if s.conn == nil {
				s.done()
				return nil, false, s.err
			}
			return s, false, nil
		}
		delete(doorStreams, onion)
	}
	s := &doorStream{onion: onion, busy: 1, ready: make(chan struct{})}
	doorStreams[onion] = s
	doorMu.Unlock()

	conn, err := doorDial(ctx, t, onion)
	if err != nil {
		s.mu.Lock()
		s.err = err
		s.mu.Unlock()
		doorMu.Lock()
		if doorStreams[onion] == s {
			delete(doorStreams, onion)
		}
		doorMu.Unlock()
		close(s.ready)
		return nil, true, err
	}
	s.conn = conn
	close(s.ready)
	go s.readAcks()
	return s, true, nil
}

func doorDial(ctx context.Context, t *tor.Tor, onion string) (net.Conn, error) {
	dialer, err := torDialer(ctx, t)
	if err != nil {
		return nil, fmt.Errorf("dialer: %v", err)
	}
	conn, err := dialer.DialContext(ctx, "tcp", onion+":80")
	if err != nil {
		return nil, fmt.Errorf("dial: %v", err)
	}
	return conn, nil
}

// one line, and its ack
func (s *doorStream) send(line string) error {
	ch := make(chan error, 1)
	s.wmu.Lock()
	s.mu.Lock()
	if s.err != nil {
		err := s.err
		s.mu.Unlock()
		s.wmu.Unlock()
		return err
	}
	s.waiting = append(s.waiting, ch)
	s.mu.Unlock()
	s.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	_, err := s.conn.Write([]byte(line + "\n"))
	s.wmu.Unlock()
	if err != nil {
		s.fail(fmt.Errorf("write: %v", err), true)
		return <-ch
	}
	select {
	case err := <-ch:
		return err
	case <-time.After(15 * time.Second):
		s.fail(errors.New("no ack: timeout"), false)
		return <-ch
	}
}

// acks come back in the order the lines went out
func (s *doorStream) readAcks() {
	b := make([]byte, len(doorAck))
	for {
		_, err := io.ReadFull(s.conn, b)
		if err == nil && string(b) != doorAck {
			err = errors.New("not an ack")
		}
		if err != nil {
			if err == io.EOF || errors.Is(err, io.ErrUnexpectedEOF) {
				err = errDoorClosed
			}
			s.fail(fmt.Errorf("no ack: %v", err), true)
			return
		}
		s.mu.Lock()
		s.acks++
		s.lastAck = time.Now()
		var ch chan error
		if len(s.waiting) > 0 {
			ch = s.waiting[0]
			s.waiting = s.waiting[1:]
		}
		s.mu.Unlock()
		if ch != nil {
			ch <- nil
		}
	}
}

// the stream is done for: every line still waiting fails, and it is not
// handed out again. byDoor says the door ended it rather than this side.
func (s *doorStream) fail(err error, byDoor bool) {
	s.mu.Lock()
	first := s.err == nil
	if first {
		s.err = err
	}
	oneLine := first && byDoor && s.acks == 1 && time.Since(s.lastAck) < 3*time.Second
	waiting := s.waiting
	s.waiting = nil
	s.mu.Unlock()
	if oneLine {
		doorMu.Lock()
		doorSingle[s.onion] = time.Now().Add(doorSingleFor)
		doorMu.Unlock()
		log.Printf("halo: door takes one line per stream, sending that way")
	}
	for _, ch := range waiting {
		ch <- err
	}
	if s.conn != nil {
		s.conn.Close()
	}
	doorMu.Lock()
	if doorStreams[s.onion] == s {
		delete(doorStreams, s.onion)
	}
	doorMu.Unlock()
}

// a line is through with the stream. the last one out starts the clock.
func (s *doorStream) done() {
	doorMu.Lock()
	kept := doorStreams[s.onion] == s
	doorMu.Unlock()
	s.mu.Lock()
	defer s.mu.Unlock()
	s.busy--
	if s.busy > 0 {
		return
	}
	if !kept || s.err != nil {
		if s.conn != nil {
			s.conn.Close()
		}
		return
	}
	if s.idle == nil {
		s.idle = time.AfterFunc(doorKeep, func() {
			s.mu.Lock()
			quiet := s.busy == 0
			s.mu.Unlock()
			if quiet {
				s.fail(errors.New("closed after the burst"), false)
			}
		})
	} else {
		s.idle.Reset(doorKeep)
	}
}

// every kept stream closed: tor bounced, or the process is stopping
func doorCloseAll() {
	doorMu.Lock()
	all := make([]*doorStream, 0, len(doorStreams))
	for _, s := range doorStreams {
		all = append(all, s)
	}
	doorMu.Unlock()
	for _, s := range all {
		s.fail(errors.New("closed"), false)
	}
}

// one line to a peer's door: on the kept stream, once more on a new one when
// that one had died, or on a stream of its own for a door that takes one
func sendTo(t *tor.Tor, onion, line string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if doorOneLineOnly(onion) {
		return sendOneLine(ctx, t, onion, line)
	}
	for try := 0; ; try++ {
		s, fresh, err := doorGet(ctx, t, onion)
		if err != nil {
			return err
		}
		err = s.send(line)
		s.done()
		if err == nil {
			return nil
		}
		if fresh || try > 0 {
			return err
		}
		if doorOneLineOnly(onion) {
			return sendOneLine(ctx, t, onion, line)
		}
	}
}

// a stream of its own: dial, one line, the ack, close
func sendOneLine(ctx context.Context, t *tor.Tor, onion, line string) error {
	conn, err := doorDial(ctx, t, onion)
	if err != nil {
		return err
	}
	defer conn.Close()
	conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	if _, err := conn.Write([]byte(line + "\n")); err != nil {
		return fmt.Errorf("write: %v", err)
	}
	conn.SetReadDeadline(time.Now().Add(15 * time.Second))
	if err := readAck(conn); err != nil {
		return fmt.Errorf("no ack: %v", err)
	}
	return nil
}

var errLineTooLong = errors.New("line too long")

// the next line on a door stream, newline included, refused once it runs
// past what the door takes. a last line without a newline still counts.
func readDoorLine(r *bufio.Reader) (string, error) {
	var b []byte
	for {
		frag, err := r.ReadSlice('\n')
		b = append(b, frag...)
		if len(b) > inboxMaxLine+2 {
			return "", errLineTooLong
		}
		switch {
		case err == bufio.ErrBufferFull:
			continue
		case err == io.EOF && len(b) > 0:
			return string(b), nil
		case err != nil:
			return "", err
		}
		return string(b), nil
	}
}
