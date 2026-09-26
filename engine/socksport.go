// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
)

// bine starts tor with "--SocksPort auto", so every DisableNetwork bounce
// reopens the socks listener on a new port, while t.Dialer caches the port
// once at build time. so the port is chosen here at process start and handed
// to tor, and a dialer built before a bounce keeps working. the cache resets
// in reconnectOn, torResume and startListener are the fallback if the pin
// fails.

var pinnedSocks int32

// a port nobody is using, found by letting the kernel choose one and handing
// it straight back. there is a race between closing this and tor binding it,
// which is why startListener can fall back to auto.
func choosePinnedSocks() int {
	if p := int(atomic.LoadInt32(&pinnedSocks)); p != 0 {
		return p
	}
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Printf("halo: could not pick a socks port (%v) - tor will choose", err)
		return 0
	}
	p := l.Addr().(*net.TCPAddr).Port
	l.Close()
	atomic.StoreInt32(&pinnedSocks, int32(p))
	log.Printf("halo: socks port pinned to %d for this process", p)
	return p
}

func socksPin() int { return int(atomic.LoadInt32(&pinnedSocks)) }

// give up on the pin for the rest of the process and let tor choose. the
// cache resets carry it from here.
func dropSocksPin(why string) {
	if p := socksPin(); p != 0 {
		log.Printf("halo: giving up the pinned socks port %d (%s) - "+
			"falling back to auto, the client resets have to carry it", p, why)
	}
	atomic.StoreInt32(&pinnedSocks, 0)
}

// where tor's socks listener is, for dialers. bine's Dialer asks tor over the
// shared control connection and re-enables the network on the way (see
// control_events.go). the pin answers without asking tor at all. when tor
// chose the port itself it is asked once, over the engine's own connection
// and under its deadline, and remembered until the next client reset.
var (
	socksAddrMu     sync.Mutex
	socksAddrCached string
)

func socksAddr(t *tor.Tor) (string, error) {
	if p := socksPin(); p != 0 {
		return fmt.Sprintf("127.0.0.1:%d", p), nil
	}
	socksAddrMu.Lock()
	defer socksAddrMu.Unlock()
	if socksAddrCached != "" {
		return socksAddrCached, nil
	}
	var kv []*control.KeyVal
	err := ctrlDo(t, "GETINFO net/listeners/socks", func(c *control.Conn) error {
		var e error
		kv, e = c.GetInfo("net/listeners/socks")
		return e
	})
	if err != nil {
		return "", err
	}
	if len(kv) == 0 || kv[0].Val == "" {
		return "", fmt.Errorf("tor has no socks listener")
	}
	a := strings.Trim(strings.Fields(kv[0].Val)[0], "\"")
	socksAddrCached = a
	log.Printf("halo: socks listener at %s", a)
	return a, nil
}

func dropSocksAddr() {
	socksAddrMu.Lock()
	socksAddrCached = ""
	socksAddrMu.Unlock()
}

// a dialer through tor that never touches the control port and never
// changes tor's configuration. it is built in microseconds.
func torDialer(ctx context.Context, t *tor.Tor) (*tor.Dialer, error) {
	a, err := socksAddr(t)
	if err != nil {
		return nil, err
	}
	return t.Dialer(ctx, &tor.DialConf{
		SkipEnableNetwork: true,
		ProxyNetwork:      "tcp",
		ProxyAddress:      a,
	})
}
