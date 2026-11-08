// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"crypto/ed25519"
	"errors"
	"fmt"
	"log"
	"net"
	"net/textproto"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// our onion service lives on a control connection of its own. tor ties a
// service to the connection that added it and takes it down when that
// connection closes, so ctrlDo's, which is dropped on any late reply, cannot
// carry it, and bine's has no deadline. this one carries ADD_ONION and
// DEL_ONION alone, each under a deadline: a late reply closes it, and the
// service tor may have added on it goes with it, so a retry never meets a
// second one

var (
	// held for one bounded call. never taken with ctrlMu or evMu held
	onionMu   sync.Mutex
	onionConn *control.Conn
	onionSock net.Conn
	onionPort int // the control port it was dialled on
)

// how long an ADD_ONION may take. tor answers at once when it is well; a
// slow phone loading its cache can hold tor's loop for a few seconds
func onionAddDeadline() time.Duration { return 3 * ctrlDeadline() }

// closes the connection, and with it any service on it. onionMu held
func onionDrop() {
	if onionSock != nil {
		_ = onionSock.Close()
	}
	onionConn, onionSock, onionPort = nil, nil, 0
}

// for a new tor: the old one's connection goes
func onionReset() {
	onionMu.Lock()
	defer onionMu.Unlock()
	onionDrop()
}

// runs f on the onion connection, dialled if there is none, under deadline
// d. f gets a copy of t whose Control is that connection, so bine's Listen
// and the service it hands back use it
func onionDo(t *tor.Tor, what string, d time.Duration, f func(*tor.Tor) error) error {
	if t == nil || t.ControlPort == 0 {
		return fmt.Errorf("no control port to dial")
	}
	onionMu.Lock()
	defer onionMu.Unlock()
	if onionConn != nil && onionPort != t.ControlPort {
		onionDrop()
	}
	if onionConn == nil {
		c, nc, err := ctrlDial(t)
		if err != nil {
			return err
		}
		onionConn, onionSock, onionPort = c, nc, t.ControlPort
		log.Printf("halo: onion connection open on 127.0.0.1:%d", t.ControlPort)
	}
	tc := *t
	tc.Control = onionConn
	_ = onionSock.SetDeadline(time.Now().Add(d))
	err := f(&tc)
	var te *textproto.Error
	switch {
	case err == nil || errors.As(err, &te):
		_ = onionSock.SetDeadline(time.Time{})
		atomic.StoreInt64(&ctrlSilent, 0)
		return err
	case isTimeout(err):
		atomic.AddInt64(&ctrlTimeouts, 1)
		atomic.AddInt64(&ctrlSilent, 1)
		log.Printf("halo: control port did not answer %s within %s, dropping the onion connection", what, d)
		onionDrop()
		return fmt.Errorf("control port timeout on %s", what)
	}
	log.Printf("halo: onion connection broke on %s: %v", what, err)
	onionDrop()
	return err
}

// takes service id down. no onion connection means none is up: it went
// with the connection that carried it
func onionDel(t *tor.Tor, id string) error {
	onionMu.Lock()
	none := onionConn == nil
	onionMu.Unlock()
	if none {
		return nil
	}
	return onionDo(t, "DEL_ONION", ctrlDeadline(), func(tc *tor.Tor) error {
		return tc.Control.DelOnion(id)
	})
}

// the waits between tries of an onion that did not go up, doubling to the
// last. vars for the tests
var (
	onionRetryFirst = 15 * time.Second
	onionRetryMax   = 2 * time.Minute
)

// one retry loop at a time. set and cleared with startMu held
var onionRetrying atomic.Bool

// the onion did not go up on tor t: it is tried again later on t, never on
// another tor. startMu held. meanwhile tor runs without it: sends and
// receives go by the relays over socks, and the status stays publishing
func onionLater(t *tor.Tor, key ed25519.PrivateKey) {
	if !onionRetrying.CompareAndSwap(false, true) {
		return
	}
	gone := torGoneCh()
	go func() {
		wait := onionRetryFirst
		for {
			select {
			case <-gone:
				gone = nil
			case <-time.After(wait):
			}
			if onionRetry(t, key) {
				return
			}
			if wait *= 2; wait > onionRetryMax {
				wait = onionRetryMax
			}
		}
	}()
}

// one try. true once there is nothing left to do: the address is up, t is
// not this process's tor any more, or it is a client's
func onionRetry(t *tor.Tor, key ed25519.PrivateKey) bool {
	startMu.Lock()
	defer startMu.Unlock()
	mu.Lock()
	cur, have := torNode, myAddr != ""
	mu.Unlock()
	if cur != t || have || torClientOnly() {
		onionRetrying.Store(false)
		return true
	}
	// asleep: the wake's start listens again
	if torIsPaused() {
		return false
	}
	log.Println("halo: trying the onion again on the same tor")
	if r := onionOn(t, key, false); strings.HasPrefix(r, "error:") {
		log.Printf("halo: onion still not up: %s", r)
		return false
	}
	onionRetrying.Store(false)
	return true
}
