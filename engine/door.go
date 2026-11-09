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
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"strings"
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

// a stream failure from the door's side: it shut, reset or would not take
// a write, as against an ack that never came
type doorShut struct{ error }

func (d doorShut) Unwrap() error { return d.error }

type doorStream struct {
	onion string
	ready chan struct{} // closed once the dial is done
	conn  net.Conn      // set before ready closes, nil when the dial failed
	slot  *doorSlot     // its place in the queue, set with conn

	wmu sync.Mutex // one line on the wire at a time

	// the dial gave up on the budget of the line that started it, not on
	// the door: a line that waited on it with time left dials again
	cutShort bool

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
func doorGet(ctx context.Context, t *tor.Tor, onion string, pri int) (*doorStream, bool, error) {
	for {
		s, fresh, err := doorGetOnce(ctx, t, onion, pri)
		if s == nil && !fresh && errors.Is(err, errDialCutShort) && ctx.Err() == nil {
			continue
		}
		return s, fresh, err
	}
}

var errDialCutShort = errors.New("dial ran out of its line's budget")

func doorGetOnce(ctx context.Context, t *tor.Tor, onion string, pri int) (*doorStream, bool, error) {
	resting := pri != doorOpenChat && doorResting(onion) > 0
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
			// a line that joins a dial still waiting takes it to its place
			select {
			case <-s.ready:
			default:
				doorRaise(onion, pri)
			}
			select {
			case <-s.ready:
			case <-ctx.Done():
				s.done()
				return nil, false, ctx.Err()
			}
			if s.conn == nil {
				s.done()
				if s.cutShort {
					return nil, false, errDialCutShort
				}
				return nil, false, s.err
			}
			return s, false, nil
		}
		delete(doorStreams, onion)
	}
	if resting {
		doorMu.Unlock()
		return nil, false, errDoorResting
	}
	s := &doorStream{onion: onion, busy: 1, ready: make(chan struct{})}
	doorStreams[onion] = s
	doorMu.Unlock()

	conn, slot, err := doorDialQueued(ctx, t, onion, pri)
	if err != nil {
		s.mu.Lock()
		s.err = err
		s.mu.Unlock()
		// read by waiters only after ready closes. a line with more time
		// left than this one's queues again
		s.cutShort = ctx.Err() != nil || errors.Is(err, errDoorBusy)
		doorMu.Lock()
		if doorStreams[onion] == s {
			delete(doorStreams, onion)
		}
		doorMu.Unlock()
		close(s.ready)
		return nil, true, err
	}
	s.mu.Lock()
	s.slot = slot
	s.mu.Unlock()
	s.conn = conn
	close(s.ready)
	go s.readAcks()
	return s, true, nil
}

// a dial in its turn (doorq.go): a slot first, then at most doorDialMost.
// the slot's dial part is given back when the dial ends, the stream part
// when the stream closes
func doorDialQueued(ctx context.Context, t *tor.Tor, onion string, pri int) (net.Conn, *doorSlot, error) {
	// a raise is for this dial alone
	defer func() {
		doorQMu.Lock()
		delete(doorRaisedOpen, onion)
		doorQMu.Unlock()
	}()
	slot, err := doorSlotFor(ctx, onion, pri)
	if err != nil {
		return nil, nil, err
	}
	pri = doorPlaceNow(onion, pri)
	// the turn ends with time left for the dial, as the queue's wait does
	turn := ctx
	if d, ok := ctx.Deadline(); ok {
		var cancel context.CancelFunc
		turn, cancel = context.WithDeadline(ctx, d.Add(-doorDialLeast))
		defer cancel()
	}
	ok := doorPace(turn, onion, pri)
	if !ok {
		slot.closed()
		return nil, nil, errDoorBusy
	}
	gen := routeGeneration()
	dctx, cancel := context.WithTimeout(ctx, doorDialMost)
	defer cancel()
	conn, err := doorDial(dctx, t, onion)
	slot.dialDone()
	if err != nil {
		slot.closed()
		// the line's own budget running out says nothing of the onion
		if ctx.Err() == nil {
			doorDialFailed(onion, gen)
		}
		return nil, nil, err
	}
	doorDialOK(onion)
	return conn, slot, nil
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
	return s.sendWithin(line, 10*time.Second, 15*time.Second, true)
}

// one line, its write and its ack each given their own wait. giveUp says a
// late ack ends the stream; without it the line just stops waiting and the
// ack, when it comes, is read off in its turn
func (s *doorStream) sendWithin(line string, write, ack time.Duration, giveUp bool) error {
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
	s.conn.SetWriteDeadline(time.Now().Add(write))
	_, err := s.conn.Write([]byte(line + "\n"))
	s.wmu.Unlock()
	if err != nil {
		s.fail(fmt.Errorf("write: %v", err), true)
		return <-ch
	}
	select {
	case err := <-ch:
		return err
	case <-time.After(ack):
		if !giveUp {
			return errors.New("no ack: timeout")
		}
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
			s.fail(fmt.Errorf("no ack: %w", err), true)
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
	if byDoor {
		err = doorShut{err}
	}
	s.mu.Lock()
	first := s.err == nil
	if first {
		s.err = err
	}
	oneLine := first && byDoor && s.acks == 1 && time.Since(s.lastAck) < 3*time.Second
	waiting := s.waiting
	s.waiting = nil
	slot := s.slot
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
	slot.closed()
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
		s.slot.closed()
		return
	}
	// lines wait for a slot: no keep, the stream gives way now
	select {
	case <-s.ready:
		if doorRoomWanted() {
			go s.fail(errors.New("gave way to a waiting line"), false)
			return
		}
	default:
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
	return sendToAs(t, onion, line, doorMessage)
}

// sendTo with the line's place in the queue (doorq.go)
func sendToAs(t *tor.Tor, onion, line string, pri int) error {
	ctx, cancel := context.WithTimeout(context.Background(), doorLineBudget)
	defer cancel()
	pri = doorPlaceNow(onion, pri)
	if pri != doorOpenChat && doorResting(onion) > 0 {
		return errDoorResting
	}
	if doorOneLineOnly(onion) {
		return sendOneLine(ctx, t, onion, line, pri)
	}
	for try := 0; ; try++ {
		s, fresh, err := doorGet(ctx, t, onion, pri)
		if err != nil {
			return err
		}
		err = s.send(line)
		s.done()
		if err == nil {
			return nil
		}
		// an older door shut the stream on a line queued behind the first:
		// this one goes on a stream of its own, while the budget lasts
		var shut doorShut
		if doorOneLineOnly(onion) && ctx.Err() == nil && (!fresh && try == 0 || errors.As(err, &shut)) {
			if err2 := sendOneLine(ctx, t, onion, line, pri); err2 != nil {
				return fmt.Errorf("%v, then on its own stream: %v", err, err2)
			}
			return nil
		}
		// a line queued first on a fresh stream to an older door can shut
		// it before its ack is counted, so the door is not marked yet: once
		// more on a new stream
		if fresh && try == 0 && errors.As(err, &shut) && ctx.Err() == nil {
			continue
		}
		if fresh || try > 0 {
			return err
		}
	}
}

// a stream of its own: dial, one line, the ack, close
func sendOneLine(ctx context.Context, t *tor.Tor, onion, line string, pri int) error {
	conn, slot, err := doorDialQueued(ctx, t, onion, pri)
	if err != nil {
		return err
	}
	defer slot.closed()
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

// a line's whole time, queue and dial included: under the app's 15 s onion
// wait, so the engine has given up before the app goes on without it and
// no dial runs for a line nobody waits for
var doorLineBudget = 14 * time.Second

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

// how long a typing line may take in all, dial included
var typingBudget = 8 * time.Second

// a typing line is one short whisper message, never an opener
const typingLineMost = 4096

var (
	errTypingRoute = errors.New("not on the onion route")
	errTypingShape = errors.New("not a typing line")
	errTypingTo    = errors.New("not an onion")
)

// a typing line to a peer's door: the private route only, on the kept
// stream or one dial, inside typingBudget. it is worth nothing once late,
// so it is never kept for later. the one second try is for a kept stream
// the door shut under it, as it does each doorLife, so steady typing does
// not go dark
func sendTyping(t *tor.Tor, onion, line string) error {
	if currentMode() != modePrivate {
		return errTypingRoute
	}
	if !strings.HasSuffix(onion, ".onion") || strings.ContainsAny(onion, ":/ ") {
		return errTypingTo
	}
	if len(line) > typingLineMost || !inboxShapeOK(line) {
		return errTypingShape
	}
	if raw, _ := base64.StdEncoding.DecodeString(line); raw[0] != 2 {
		return errTypingShape
	}
	// an onion that failed lately is not dialled for a whisper
	if doorResting(onion) > 0 {
		return errDoorResting
	}
	ctx, cancel := context.WithTimeout(context.Background(), typingBudget)
	defer cancel()
	if doorOneLineOnly(onion) {
		return sendOneLineBy(ctx, t, onion, line)
	}
	s, fresh, err := doorGet(ctx, t, onion, doorOpenChat)
	if err != nil {
		return err
	}
	err = typingOn(ctx, s, line)
	var shut doorShut
	if err == nil || fresh || !errors.As(err, &shut) || ctx.Err() != nil {
		return err
	}
	if doorOneLineOnly(onion) {
		return sendOneLineBy(ctx, t, onion, line)
	}
	s, _, err = doorGet(ctx, t, onion, doorOpenChat)
	if err != nil {
		return err
	}
	return typingOn(ctx, s, line)
}

// one typing line on s, in what is left of the budget. a late ack leaves
// the stream to the lines behind it
func typingOn(ctx context.Context, s *doorStream, line string) error {
	defer s.done()
	left := time.Until(deadlineOf(ctx))
	if left <= 0 {
		return ctx.Err()
	}
	return s.sendWithin(line, left, left, false)
}

func deadlineOf(ctx context.Context) time.Time {
	d, _ := ctx.Deadline()
	return d
}

// sendOneLine held to the deadline of ctx
func sendOneLineBy(ctx context.Context, t *tor.Tor, onion, line string) error {
	conn, slot, err := doorDialQueued(ctx, t, onion, doorOpenChat)
	if err != nil {
		return err
	}
	defer slot.closed()
	defer conn.Close()
	conn.SetDeadline(deadlineOf(ctx))
	if _, err := conn.Write([]byte(line + "\n")); err != nil {
		return fmt.Errorf("write: %v", err)
	}
	if err := readAck(conn); err != nil {
		return fmt.Errorf("no ack: %v", err)
	}
	return nil
}
