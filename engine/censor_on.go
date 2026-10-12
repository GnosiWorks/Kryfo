// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torblocked

package main

// the censor. tor reaches every relay through it with Socks5Proxy, and it
// answers the way censors do: the tls hello is seen and the connection
// reset, or everything is swallowed and nothing comes back. bridges reach
// tor through their own listeners and get past it, unless the level also
// cuts the built-in obfs4 bridges off.

import (
	"encoding/binary"
	"errors"
	"fmt"
	"hash/fnv"
	"io"
	"log"
	"net"
	"runtime"
	"strconv"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

const censorBuild = true

// release.sh looks for this in the shipped engine and refuses it
const censorMarker = "kryfo test censor build"

// reset, stall, or mixed: each relay gets one of the two, the same every time
var censorHow = "mixed"

// 1 cuts direct tor off, 2 the built-in obfs4 bridges too (censor_two.go)
var censorLevel = 1

var (
	censorMu    sync.Mutex
	censorAddr  string
	censorSeen  atomic.Int64
	censorStall = 5 * time.Minute
)

func censorStart() string {
	censorMu.Lock()
	defer censorMu.Unlock()
	if censorAddr != "" {
		return censorAddr
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Printf("censor: %v", err)
		return ""
	}
	censorAddr = ln.Addr().String()
	log.Printf("censor: %s, tor is cut off (%s, level %d)", censorMarker, censorHow, censorLevel)
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				if errors.Is(err, net.ErrClosed) {
					return
				}
				time.Sleep(50 * time.Millisecond)
				continue
			}
			go censorConn(c)
		}
	}()
	return censorAddr
}

// the socks5 request tor sends, taken apart: the target, "" when it is not
// one
func censorHandshake(c net.Conn) string {
	var b [262]byte
	if _, err := io.ReadFull(c, b[:2]); err != nil || b[0] != 5 {
		return ""
	}
	if _, err := io.ReadFull(c, b[:b[1]]); err != nil {
		return ""
	}
	if _, err := c.Write([]byte{5, 0}); err != nil {
		return ""
	}
	if _, err := io.ReadFull(c, b[:4]); err != nil || b[0] != 5 || b[1] != 1 {
		return ""
	}
	var host string
	switch b[3] {
	case 1:
		if _, err := io.ReadFull(c, b[:4]); err != nil {
			return ""
		}
		host = net.IP(b[:4]).String()
	case 4:
		if _, err := io.ReadFull(c, b[:16]); err != nil {
			return ""
		}
		host = net.IP(b[:16]).String()
	case 3:
		if _, err := io.ReadFull(c, b[:1]); err != nil {
			return ""
		}
		n := int(b[0])
		if _, err := io.ReadFull(c, b[:n]); err != nil {
			return ""
		}
		host = string(b[:n])
	default:
		return ""
	}
	if _, err := io.ReadFull(c, b[:2]); err != nil {
		return ""
	}
	port := binary.BigEndian.Uint16(b[:2])
	if _, err := c.Write([]byte{5, 0, 0, 1, 0, 0, 0, 0, 0, 0}); err != nil {
		return ""
	}
	return net.JoinHostPort(host, strconv.Itoa(int(port)))
}

func censorWay(target string) string {
	if censorHow != "mixed" {
		return censorHow
	}
	h := fnv.New32a()
	h.Write([]byte(target))
	if h.Sum32()%2 == 0 {
		return "reset"
	}
	return "stall"
}

func censorConn(c net.Conn) {
	defer c.Close()
	_ = c.SetDeadline(time.Now().Add(10 * time.Second))
	target := censorHandshake(c)
	if target == "" {
		return
	}
	censorSeen.Add(1)
	switch censorWay(target) {
	case "reset":
		// the hello goes by, then a reset, as dpi does it
		_ = c.SetDeadline(time.Now().Add(30 * time.Second))
		var b [512]byte
		_, _ = c.Read(b[:])
		if tc, ok := c.(*net.TCPConn); ok {
			_ = tc.SetLinger(0)
		}
	default:
		// dropped on the floor: tor waits for an answer that never comes
		_ = c.SetDeadline(time.Now().Add(censorStall))
		_, _ = io.Copy(io.Discard, c)
	}
}

// at level 2 the built-in obfs4 bridges are cut off too
func censorPTDial(transport, target string) error {
	if censorLevel < 2 || transport != "obfs4" || !censorAllowed(procName(), runtime.GOOS) {
		return nil
	}
	want := bridgeAddrKey(target)
	for _, ln := range builtinBundled["obfs4"] {
		if b, err := parseBridgeLine(ln); err == nil && bridgeAddrKey(b.addr) == want {
			return fmt.Errorf("censor: %w", syscall.ECONNRESET)
		}
	}
	return nil
}
