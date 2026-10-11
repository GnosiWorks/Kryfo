// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torblocked

package main

import (
	"errors"
	"io"
	"net"
	"strings"
	"syscall"
	"testing"
	"time"
)

// through the censor as tor goes: a socks5 connect, then a tls hello
func censorDial(t *testing.T, target string) net.Conn {
	t.Helper()
	c, err := net.Dial("tcp", censorStart())
	if err != nil {
		t.Fatal(err)
	}
	host, port, _ := net.SplitHostPort(target)
	ip := net.ParseIP(host).To4()
	p := []byte{0, 0}
	var n int
	for _, ch := range port {
		n = n*10 + int(ch-'0')
	}
	p[0], p[1] = byte(n>>8), byte(n)
	c.Write([]byte{5, 1, 0})
	var b [10]byte
	if _, err := io.ReadFull(c, b[:2]); err != nil || b[1] != 0 {
		t.Fatalf("greeting: %v %v", err, b[:2])
	}
	c.Write(append(append([]byte{5, 1, 0, 1}, ip...), p...))
	if _, err := io.ReadFull(c, b[:10]); err != nil || b[1] != 0 {
		t.Fatalf("connect: %v %v", err, b)
	}
	return c
}

func TestCensorResetsAndStalls(t *testing.T) {
	if !censorBuild || censorTorArgs() == nil {
		t.Fatal("the test build has no censor")
	}
	a := censorTorArgs()
	if a[0] != "--Socks5Proxy" || !strings.HasPrefix(a[1], "127.0.0.1:") {
		t.Fatalf("tor args %v", a)
	}
	old := censorHow
	defer func() { censorHow = old }()

	censorHow = "reset"
	c := censorDial(t, "192.0.2.10:443")
	c.Write([]byte("\x16\x03\x01 hello"))
	c.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, err := c.Read(make([]byte, 16))
	if !errors.Is(err, syscall.ECONNRESET) {
		t.Fatalf("reset: %v", err)
	}
	c.Close()

	censorHow = "stall"
	c = censorDial(t, "192.0.2.11:443")
	c.Write([]byte("\x16\x03\x01 hello"))
	c.SetReadDeadline(time.Now().Add(time.Second))
	_, err = c.Read(make([]byte, 16))
	var ne net.Error
	if !errors.As(err, &ne) || !ne.Timeout() {
		t.Fatalf("stall: %v", err)
	}
	c.Close()

	// mixed gives each relay one way, the same every time
	censorHow = "mixed"
	seen := map[string]bool{}
	for i := 0; i < 20; i++ {
		seen[censorWay(net.JoinHostPort("192.0.2."+string(rune('a'+i)), "443"))] = true
	}
	if !seen["reset"] || !seen["stall"] {
		t.Fatalf("mixed gave %v", seen)
	}
}

func TestCensorLevelTwoCutsBuiltinObfs4(t *testing.T) {
	old := censorLevel
	defer func() { censorLevel = old }()
	b, _ := parseBridgeLine(builtinBundled["obfs4"][0])
	if err := censorPTDial("obfs4", b.addr); err != nil {
		t.Fatalf("level 1 cut a bridge: %v", err)
	}
	censorLevel = 2
	if err := censorPTDial("obfs4", b.addr); !errors.Is(err, syscall.ECONNRESET) {
		t.Fatalf("level 2: %v", err)
	}
	if err := censorPTDial("obfs4", "192.0.2.99:443"); err != nil {
		t.Fatalf("level 2 cut a bridge of someone's own: %v", err)
	}
}
