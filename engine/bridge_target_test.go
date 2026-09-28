// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the obfs4 listener dials a bridge tor was given and nothing else, and
// nothing at all while bridges are off

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"strings"
	"testing"
	"time"

	"gitlab.com/yawning/obfs4.git/common/socks5"
	"gitlab.com/yawning/obfs4.git/transports/obfs4"
)

// a listener that counts what reaches it
func knocks(t *testing.T) (net.Listener, chan struct{}) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	came := make(chan struct{}, 8)
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			came <- struct{}{}
			c.Close()
		}
	}()
	return ln, came
}

// a socks5 connect through servePTConn, as tor makes it: the bridge's
// arguments in the username. the reply code comes back
func socksConnect(t *testing.T, target, args string) byte {
	t.Helper()
	factory, err := (&obfs4.Transport{}).ClientFactory("")
	if err != nil {
		t.Fatal(err)
	}
	c, s := net.Pipe()
	defer c.Close()
	go servePTConn(s, factory)
	c.SetDeadline(time.Now().Add(20 * time.Second))
	must := func(b []byte) {
		if _, err := c.Write(b); err != nil {
			t.Fatal(err)
		}
	}
	read := func(n int) []byte {
		b := make([]byte, n)
		if _, err := io.ReadFull(c, b); err != nil {
			t.Fatal(err)
		}
		return b
	}
	must([]byte{5, 1, 2})
	read(2)
	must(append(append([]byte{1, byte(len(args))}, args...), 1, 0))
	read(2)
	host, port, _ := net.SplitHostPort(target)
	ip := net.ParseIP(host).To4()
	var p int
	fmt.Sscanf(port, "%d", &p)
	must(append(append([]byte{5, 1, 0, 1}, ip...), byte(p>>8), byte(p)))
	return read(10)[1]
}

func TestPTListenerDialsOnlyConfiguredBridges(t *testing.T) {
	bridgeMu.Lock()
	oldList, oldOn, oldFails := bridgeList, bridgeOn, bridgeFails
	bridgeFails = map[string]int{}
	bridgeMu.Unlock()
	t.Cleanup(func() {
		bridgeMu.Lock()
		bridgeList, bridgeOn, bridgeFails = oldList, oldOn, oldFails
		bridgeMu.Unlock()
	})
	bridge, toBridge := knocks(t)
	other, toOther := knocks(t)
	raw := make([]byte, 52)
	rand.Read(raw)
	cert := strings.TrimSuffix(base64.StdEncoding.EncodeToString(raw), "==")
	bridgeMu.Lock()
	bridgeList = []string{fmt.Sprintf(
		"obfs4 %s 0123456789ABCDEF0123456789ABCDEF01234567 cert=%s iat-mode=0",
		bridge.Addr(), cert,
	)}
	bridgeOn = true
	bridgeMu.Unlock()
	args := "cert=" + cert + ";iat-mode=0"

	if code := socksConnect(t, other.Addr().String(), args); code != byte(socks5.ReplyConnectionNotAllowed) {
		t.Fatalf("another address answered %d", code)
	}
	socksConnect(t, bridge.Addr().String(), args)
	select {
	case <-toBridge:
	case <-time.After(10 * time.Second):
		t.Fatal("the bridge was never dialled")
	}
	select {
	case <-toOther:
		t.Fatal("an address that is no bridge was dialled")
	default:
	}

	// bridges off: not even the bridge
	bridgeMu.Lock()
	bridgeOn = false
	bridgeMu.Unlock()
	if code := socksConnect(t, bridge.Addr().String(), args); code != byte(socks5.ReplyConnectionNotAllowed) {
		t.Fatalf("with bridges off the bridge answered %d", code)
	}
}

func TestBridgeAddressesCompareWhateverTheirSpelling(t *testing.T) {
	for _, c := range [][2]string{
		{"1.2.3.4:443", "1.2.3.4:443"},
		{"[2001:DB8::1]:443", "[2001:db8::1]:443"},
		{"[2001:db8:0::1]:443", "[2001:db8::1]:443"},
	} {
		if bridgeAddrKey(c[0]) != bridgeAddrKey(c[1]) {
			t.Errorf("%s and %s differ", c[0], c[1])
		}
	}
	if bridgeAddrKey("1.2.3.4") != "" || bridgeAddrKey("") != "" {
		t.Error("an address without a port has a key")
	}
}
