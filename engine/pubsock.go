// SPDX-License-Identifier: GPL-3.0-or-later
package main

// publish sockets. a file goes out as a hundred and more wraps to one
// address, and a fresh websocket per wrap pays a tor stream, tls and the
// upgrade before each one. so a burst keeps one socket per lane, relay and
// recipient address, and lets it go once the burst is over.
//
// every wrap to one address carries that address in its p tag, so a relay
// already knows they belong together, and a socket shared among them tells
// it nothing more. a socket is never shared across addresses or lanes: that
// would show a relay who else this phone writes to. nor with a subscription,
// which carries this phone's own receive address.

import (
	"context"
	"log"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"fiatjaf.com/nostr"
)

// how long a publish socket stays open after its last wrap
var pubIdle = 30 * time.Second

// how long a socket with wraps waiting may go without a single ok. a circuit
// can die without the socket noticing; its wraps then go out again on a new
// one. a slow socket still hands back an ok now and then and is kept.
// atomic: a socket's watch may still read it while a test sets it.
var pubQuiet = func() *atomic.Int64 {
	var d atomic.Int64
	d.Store(int64(20 * time.Second))
	return &d
}()

type pubKey struct{ lane, url, addr string }

type pubSock struct {
	key    pubKey
	client *http.Client
	ready  chan struct{} // closed once the dial is done
	r      *nostr.Relay
	err    error
	busy   int
	idle   *time.Timer
	heard  atomic.Int64 // unix nanos of the dial or the last ok
}

var (
	pubMu    sync.Mutex
	pubSocks = map[pubKey]*pubSock{}
)

// the one recipient a wrap is for, or "" when it names none or several
func wrapAddr(ev nostr.Event) string {
	addr := ""
	for _, tag := range ev.Tags {
		if len(tag) >= 2 && tag[0] == "p" {
			if addr != "" {
				return ""
			}
			addr = tag[1]
		}
	}
	return addr
}

// the socket for key, dialled now when there is none. fresh says it was
// dialled for this call. every sock handed out goes back through pubDone.
func pubGet(ctx context.Context, key pubKey, client *http.Client) (s *pubSock, fresh bool, err error) {
	pubMu.Lock()
	s = pubSocks[key]
	if s != nil && s.client == client && (!s.dialled() || s.r.IsConnected()) {
		// a socket that sat idle has had nothing to answer; its quiet
		// clock starts with this burst
		if s.busy == 0 && s.r != nil {
			s.heard.Store(time.Now().UnixNano())
		}
		s.busy++
		if s.idle != nil {
			s.idle.Stop()
		}
		pubMu.Unlock()
		select {
		case <-s.ready:
		case <-ctx.Done():
			pubDone(s)
			return nil, false, ctx.Err()
		}
		if s.err != nil {
			pubDone(s)
			return nil, false, s.err
		}
		return s, false, nil
	}
	if s != nil {
		pubDropLocked(s)
	}
	s = &pubSock{key: key, client: client, ready: make(chan struct{}), busy: 1}
	pubSocks[key] = s
	pubMu.Unlock()

	// the dial is shared by every wrap that comes while it runs, so it is
	// not tied to this caller's context, only to the route its client is of
	// a burst can outlast a minute, and over a busy circuit the library's
	// 800ms pong wait closes a socket that is only slow
	r := nostr.NewRelay(context.Background(), key.url, subscribeRelayOptions())
	base, bcancel := context.Background(), context.CancelFunc(func() {})
	if route := routeOf(ctx); route != nil {
		base, bcancel = onRoute(base, route)
	}
	dctx, dcancel := relayDialCtx(base, key.url)
	err = r.ConnectWithClient(dctx, client)
	dcancel()
	bcancel()
	if err != nil {
		// a relay that never connected still waits on its context
		r.Close()
	}
	pubMu.Lock()
	if err != nil {
		s.err = err
		if pubSocks[key] == s {
			delete(pubSocks, key)
		}
	} else {
		s.r = r
		s.heard.Store(time.Now().UnixNano())
	}
	close(s.ready)
	pubMu.Unlock()
	if err != nil {
		pubDone(s)
		return nil, true, err
	}
	return s, true, nil
}

// pubMu must be held
func (s *pubSock) dialled() bool {
	select {
	case <-s.ready:
		return true
	default:
		return false
	}
}

// a wrap is through with the socket. the last one out starts the idle clock.
func pubDone(s *pubSock) {
	pubMu.Lock()
	defer pubMu.Unlock()
	s.busy--
	if s.busy > 0 {
		return
	}
	if s.r == nil || pubSocks[s.key] != s {
		pubCloseLocked(s)
		return
	}
	if s.idle == nil {
		s.idle = time.AfterFunc(pubIdle, func() {
			pubMu.Lock()
			defer pubMu.Unlock()
			if s.busy == 0 && pubSocks[s.key] == s {
				delete(pubSocks, s.key)
				pubCloseLocked(s)
			}
		})
	} else {
		s.idle.Reset(pubIdle)
	}
}

// out of the map, closed once nobody is using it. pubMu must be held.
func pubDropLocked(s *pubSock) {
	if pubSocks[s.key] == s {
		delete(pubSocks, s.key)
	}
	if s.idle != nil {
		s.idle.Stop()
	}
	if s.busy == 0 {
		pubCloseLocked(s)
	}
}

func pubCloseLocked(s *pubSock) {
	if s.r != nil {
		s.r.Close()
	}
}

// a socket that failed a wrap is not handed out again
func pubDrop(s *pubSock) {
	pubMu.Lock()
	defer pubMu.Unlock()
	if pubSocks[s.key] == s {
		delete(pubSocks, s.key)
	}
	if s.r != nil {
		s.r.Close()
	}
}

// every publish socket, or one lane's, closed now: a mode change, a tor
// bounce or a room that is gone
func pubCloseAll(lane string) {
	pubMu.Lock()
	defer pubMu.Unlock()
	for k, s := range pubSocks {
		if lane != "" && k.lane != lane {
			continue
		}
		delete(pubSocks, k)
		if s.idle != nil {
			s.idle.Stop()
		}
		if s.r != nil {
			s.r.Close()
		}
	}
}

// one wrap to one relay: on the burst's socket for its address, once more on
// a new one when the kept socket turns out dead. a wrap without a single
// recipient gets a socket of its own.
func publishTo(ctx context.Context, lane, u string, client *http.Client, ev nostr.Event) error {
	addr := wrapAddr(ev)
	if addr == "" {
		r := nostr.NewRelay(ctx, u, nostr.RelayOptions{})
		dctx, dcancel := relayDialCtx(ctx, u)
		err := r.ConnectWithClient(dctx, client)
		dcancel()
		defer r.Close()
		if err != nil {
			return err
		}
		return r.Publish(ctx, ev)
	}
	key := pubKey{lane: lane, url: u, addr: addr}
	for try := 0; ; try++ {
		s, fresh, err := pubGet(ctx, key, client)
		if err != nil {
			return err
		}
		// the route may have ended while the dial ran: nothing goes out on it
		if ctx.Err() != nil {
			pubDone(s)
			return ctx.Err()
		}
		quiet := make(chan struct{})
		stop := make(chan struct{})
		go func() {
			quietAfter := time.Duration(pubQuiet.Load())
			t := time.NewTicker(quietAfter / 4)
			defer t.Stop()
			for {
				select {
				case <-stop:
					return
				case <-t.C:
					if time.Since(time.Unix(0, s.heard.Load())) > quietAfter {
						close(quiet)
						pubDrop(s)
						return
					}
				}
			}
		}()
		err = s.r.Publish(ctx, ev)
		close(stop)
		if err == nil {
			s.heard.Store(time.Now().UnixNano())
			pubDone(s)
			return nil
		}
		wentQuiet := false
		select {
		case <-quiet:
			wentQuiet = true
		default:
		}
		// the relay said no, or this wrap ran out of time behind the others:
		// the socket is fine and stays for the rest of the burst
		if s.r.IsConnected() && !wentQuiet {
			pubDone(s)
			return err
		}
		pubDrop(s)
		pubDone(s)
		if ctx.Err() != nil || try > 0 || (fresh && !wentQuiet) {
			return err
		}
		log.Printf("nostr: kept socket to %s is gone, publishing on a new one", u)
	}
}
