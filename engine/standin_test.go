// SPDX-License-Identifier: GPL-3.0-or-later
package main

// stand-ins for a relay and for tor's socks port, so the relay runners can be
// driven on the host: what each connection asked for, the ids it used, its
// pings, and which socks name it came in under.

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"encoding/binary"
	"encoding/hex"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	ws "github.com/coder/websocket"
	"github.com/cretz/bine/tor"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"golang.org/x/crypto/curve25519"
)

// one websocket as the relay saw it
type siConn struct {
	remote    string
	opened    time.Time
	closed    time.Time
	subIDs    []string
	addrs     map[string]bool // p tags asked for
	published map[string]bool // p tags of events it published
	pings     []time.Time
	kill      context.CancelFunc
}

type relayStandIn struct {
	srv *httptest.Server

	mu        sync.Mutex
	pongDelay time.Duration
	conns     []*siConn
	events    []nostr.Event
	resent    int // stored events sent in answer to a req
	resentB   int
}

func newRelayStandIn(t *testing.T, pongDelay time.Duration) *relayStandIn {
	s := &relayStandIn{pongDelay: pongDelay}
	s.srv = httptest.NewServer(http.HandlerFunc(s.handle))
	t.Cleanup(s.srv.Close)
	return s
}

func (s *relayStandIn) url() string { return "ws" + strings.TrimPrefix(s.srv.URL, "http") }

func (s *relayStandIn) store(evs ...nostr.Event) {
	s.mu.Lock()
	s.events = append(s.events, evs...)
	s.mu.Unlock()
}

func (s *relayStandIn) handle(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()
	c := &siConn{remote: r.RemoteAddr, opened: time.Now(), addrs: map[string]bool{},
		published: map[string]bool{}, kill: cancel}
	s.mu.Lock()
	s.conns = append(s.conns, c)
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		c.closed = time.Now()
		s.mu.Unlock()
	}()
	conn, err := ws.Accept(w, r, &ws.AcceptOptions{
		OnPingReceived: func(context.Context, []byte) bool {
			s.mu.Lock()
			c.pings = append(c.pings, time.Now())
			d := s.pongDelay
			s.mu.Unlock()
			time.Sleep(d)
			return true
		},
	})
	if err != nil {
		return
	}
	defer conn.CloseNow()
	for {
		_, data, err := conn.Read(ctx)
		if err != nil {
			return
		}
		env, err := nostr.ParseMessage(string(data))
		if err != nil {
			continue
		}
		switch e := env.(type) {
		case *nostr.ReqEnvelope:
			f := e.Filters[0]
			s.mu.Lock()
			c.subIDs = append(c.subIDs, e.SubscriptionID)
			for _, p := range f.Tags["p"] {
				c.addrs[p] = true
			}
			var match []nostr.Event
			for _, ev := range s.events {
				if f.Matches(ev) {
					match = append(match, ev)
				}
			}
			s.mu.Unlock()
			sort.Slice(match, func(i, j int) bool { return match[i].CreatedAt > match[j].CreatedAt })
			if f.Limit > 0 && len(match) > f.Limit {
				match = match[:f.Limit]
			}
			id := e.SubscriptionID
			for _, ev := range match {
				b, _ := nostr.EventEnvelope{SubscriptionID: &id, Event: ev}.MarshalJSON()
				if conn.Write(ctx, ws.MessageText, b) != nil {
					return
				}
				s.mu.Lock()
				s.resent++
				s.resentB += len(b)
				s.mu.Unlock()
			}
			b, _ := nostr.EOSEEnvelope(id).MarshalJSON()
			if conn.Write(ctx, ws.MessageText, b) != nil {
				return
			}
		case *nostr.EventEnvelope:
			s.mu.Lock()
			for p := range e.Event.Tags.FindAll("p") {
				c.published[p[1]] = true
			}
			s.mu.Unlock()
			b, _ := nostr.OKEnvelope{EventID: e.Event.ID, OK: true}.MarshalJSON()
			if conn.Write(ctx, ws.MessageText, b) != nil {
				return
			}
		}
	}
}

// every connection the relay has seen so far, copied
func (s *relayStandIn) snapshot() []siConn {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]siConn, 0, len(s.conns))
	for _, c := range s.conns {
		cp := *c
		cp.subIDs = append([]string(nil), c.subIDs...)
		cp.pings = append([]time.Time(nil), c.pings...)
		out = append(out, cp)
	}
	return out
}

// drop every open connection from the relay's side
func (s *relayStandIn) dropAll() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, c := range s.conns {
		if c.closed.IsZero() {
			c.kill()
		}
	}
}

// waits for cond, polling, and fails the test when it does not come
func waitFor(t *testing.T, what string, limit time.Duration, cond func() bool) {
	t.Helper()
	end := time.Now().Add(limit)
	for time.Now().Before(end) {
		if cond() {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("%s: not within %s", what, limit)
}

// a socks5 server that takes any name, the way tor does, and remembers which
// name each stream came in under
type socksStandIn struct {
	ln net.Listener

	mu      sync.Mutex
	byLocal map[string]string // the stream's own address towards the target -> name
	streams int
}

func newSocksStandIn(t *testing.T) *socksStandIn {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	s := &socksStandIn{ln: ln, byLocal: map[string]string{}}
	t.Cleanup(func() { ln.Close() })
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go s.serve(c)
		}
	}()
	return s
}

func (s *socksStandIn) port() int { return s.ln.Addr().(*net.TCPAddr).Port }

func (s *socksStandIn) serve(c net.Conn) {
	defer c.Close()
	br := bufio.NewReader(c)
	read := func(n int) []byte {
		b := make([]byte, n)
		if _, err := io.ReadFull(br, b); err != nil {
			return nil
		}
		return b
	}
	h := read(2)
	if h == nil || h[0] != 5 {
		return
	}
	methods := read(int(h[1]))
	name := ""
	// like tor with its default IsolateSOCKSAuth: a name when one is offered
	if bytes.IndexByte(methods, 2) >= 0 {
		c.Write([]byte{5, 2})
		v := read(2)
		if v == nil {
			return
		}
		name = string(read(int(v[1])))
		pl := read(1)
		if pl == nil {
			return
		}
		read(int(pl[0]))
		c.Write([]byte{1, 0})
	} else {
		c.Write([]byte{5, 0})
	}
	req := read(4)
	if req == nil {
		return
	}
	var host string
	switch req[3] {
	case 1:
		host = net.IP(read(4)).String()
	case 3:
		l := read(1)
		host = string(read(int(l[0])))
	case 4:
		host = net.IP(read(16)).String()
	}
	p := read(2)
	if p == nil {
		return
	}
	out, err := net.Dial("tcp", net.JoinHostPort(host, strconv.Itoa(int(binary.BigEndian.Uint16(p)))))
	if err != nil {
		c.Write([]byte{5, 5, 0, 1, 0, 0, 0, 0, 0, 0})
		return
	}
	defer out.Close()
	s.mu.Lock()
	s.byLocal[out.LocalAddr().String()] = name
	s.streams++
	s.mu.Unlock()
	c.Write([]byte{5, 0, 0, 1, 0, 0, 0, 0, 0, 0})
	done := make(chan struct{}, 2)
	go func() { io.Copy(out, br); done <- struct{}{} }()
	go func() { io.Copy(c, out); done <- struct{}{} }()
	<-done
}

// the socks name a relay connection came in under, and whether it came
// through socks at all
func (s *socksStandIn) nameOf(remote string) (string, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	n, ok := s.byLocal[remote]
	return n, ok
}

func (s *socksStandIn) count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.streams
}

// the engine's relay state pointed at the stand-ins, put back afterwards.
// in private mode tor is the socks stand-in: a pinned port answers without
// asking tor anything.
func useStandIns(t *testing.T, mode string, socks *socksStandIn, relays ...*relayStandIn) {
	t.Helper()
	mu.Lock()
	oldNode, oldPriv, oldPub := torNode, myXPriv, myXPub
	torNode = &tor.Tor{}
	mu.Unlock()
	oldMode := currentMode()
	oldPin := atomic.LoadInt32(&pinnedSocks)
	oldDir := savedDataDir
	nostrMu.Lock()
	oldRelays := nostrRelays
	nostrMu.Unlock()
	t.Cleanup(func() {
		mu.Lock()
		torNode, myXPriv, myXPub = oldNode, oldPriv, oldPub
		mu.Unlock()
		transportMode.Store(oldMode)
		atomic.StoreInt32(&pinnedSocks, oldPin)
		savedDataDir = oldDir
		nostrMu.Lock()
		nostrRelays = oldRelays
		nostrMu.Unlock()
		nostrResetClient()
		relayClearBenches()
	})

	transportMode.Store(mode)
	if socks != nil {
		atomic.StoreInt32(&pinnedSocks, int32(socks.port()))
	}
	nostrResetClient()
	relayClearBenches()
	savedDataDir = t.TempDir()
	var urls []string
	for _, r := range relays {
		urls = append(urls, r.url())
	}
	nostrMu.Lock()
	nostrRelays = urls
	nostrMu.Unlock()
	me := newXid(t)
	mu.Lock()
	myXPriv, myXPub = me.priv, me.pub
	mu.Unlock()
}

func newXid(t *testing.T) xid {
	t.Helper()
	var id xid
	if _, err := rand.Read(id.priv[:]); err != nil {
		t.Fatal(err)
	}
	curve25519.ScalarBaseMult(&id.pub, &id.priv)
	return id
}

// the app's lanes as the app starts them: contacts and the first-contact
// address for the main identity, and per room its members and drop box.
// returns the addresses each lane listens on.
type lanesUp struct {
	everyday []string
	peers    []xid
	rooms    [][]string
	roomKeys []xid
}

func startLanes(t *testing.T, ctx context.Context, contacts, rooms int) lanesUp {
	t.Helper()
	var l lanesUp
	for i := 0; i < contacts; i++ {
		p := newXid(t)
		_, rcv, err := nip17RcvAddress(p.pub)
		if err != nil {
			t.Fatal(err)
		}
		l.everyday = append(l.everyday, rcv)
		l.peers = append(l.peers, p)
		go nostrSubscribeRunner(ctx, hex.EncodeToString(p.pub[:]), p.pub, rcv)
	}
	_, fcPk, err := nip17FirstContactKeys(0)
	if err != nil {
		t.Fatal(err)
	}
	l.everyday = append(l.everyday, fcPk)
	var zero [32]byte
	go nostrSubscribeRunnerMode(ctx, "firstcontact", zero, fcPk, true, 0)
	for i := 0; i < rooms; i++ {
		rk := newXid(t)
		rp := newXid(t)
		lane := roomLane(hex.EncodeToString(rk.pub[:]))
		_, rcv, err := nip17RcvAddressAs(rk, rp.pub)
		if err != nil {
			t.Fatal(err)
		}
		key := roomSubKey(rk, hex.EncodeToString(rp.pub[:]))
		go nostrSubscribeRunnerFn(ctx, lane, key, rcv, func(gw nostr2.Event) (string, error) {
			return nip17UnwrapAs(rk, rp.pub, gw)
		})
		fcSk, rfc, err := fcKeysFrom(rk.priv, 0)
		if err != nil {
			t.Fatal(err)
		}
		go nostrSubscribeRunnerFn(ctx, lane, "roomfc:"+hex.EncodeToString(rk.pub[:]), rfc, func(gw nostr2.Event) (string, error) {
			c, _, err := nip17UnwrapFirstContactWith(fcSk, gw)
			return c, err
		})
		l.rooms = append(l.rooms, []string{rcv, rfc})
		l.roomKeys = append(l.roomKeys, rk)
	}
	return l
}

// a wrap from peer to me, the way the peer's phone builds it
func wrapTo(t *testing.T, peer xid, me [32]byte, body string) nostr.Event {
	t.Helper()
	gw, err := nip17WrapAs(peer, me, body)
	if err != nil {
		t.Fatal(err)
	}
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		t.Fatal(err)
	}
	return ev
}

// the connections that listened on any of addrs
func connsOn(conns []siConn, addrs []string) []siConn {
	var out []siConn
	for _, c := range conns {
		for _, a := range addrs {
			if c.addrs[a] || c.published[a] {
				out = append(out, c)
				break
			}
		}
	}
	return out
}
