// SPDX-License-Identifier: GPL-3.0-or-later
package main

// bridges. in countries that filter tor, a direct connection to a relay is
// recognisable and gets dropped - so kryfo simply does not work there, which
// is exactly where it is needed most.
//
// the usual fix ships obfs4proxy as a separate executable and lets tor launch
// it. android will not execute binaries from app storage, so that means
// shipping a native lib and exec'ing it, which is awkward and hostile to a
// reproducible build.
//
// instead this runs the obfs4 client inside the engine and exposes it as a
// plain socks5 proxy on localhost. tor supports that natively:
//
//	ClientTransportPlugin obfs4 socks5 127.0.0.1:<port>
//
// no executable, no exec, nothing extra in the apk. tor hands us the per
// bridge arguments (cert, iat-mode) in the socks handshake, the same way it
// would to the real obfs4proxy, and obfs4's own socks5 package parses them.

import "C"

import (
	"fmt"
	"io"
	"log"
	"net"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"gitlab.com/yawning/obfs4.git/common/socks5"
	"gitlab.com/yawning/obfs4.git/transports/base"
	"gitlab.com/yawning/obfs4.git/transports/obfs4"
	pt "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/goptlib"
)

var (
	bridgeMu   sync.RWMutex
	bridgeOn   bool
	bridgeList []string
	ptPort     int
	ptListener net.Listener

	// when a bridge last carried a connection, and how many times each has
	// failed in a row. a list usually contains one or two that no longer
	// work, which is normal and must not look like tor being broken.
	lastBridgeOK time.Time
	bridgeFails  = map[string]int{}
)

const bridgeDeadAfter = 4

// true if any bridge worked in the last three minutes. the dialer watchdog
// checks this before blaming tor.
func bridgeWorkingRecently() bool {
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return !lastBridgeOK.IsZero() && time.Since(lastBridgeOK) < 3*time.Minute
}

func noteBridgeOK(target string) {
	bridgeMu.Lock()
	lastBridgeOK = time.Now()
	delete(bridgeFails, target)
	bridgeMu.Unlock()
}

func noteBridgeFail(target string) {
	bridgeMu.Lock()
	bridgeFails[target]++
	n := bridgeFails[target]
	bridgeMu.Unlock()
	if n == bridgeDeadAfter {
		log.Printf("bridges: %s has failed %d times, skipping it", target, n)
	}
}

// a bridge that has failed this many times in a row is not coming back this
// session. tor still has the line, but we stop wasting dials on it.
func bridgeIsDead(target string) bool {
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return bridgeFails[target] >= bridgeDeadAfter
}

// a bridge line looks like:
//
//	obfs4 1.2.3.4:443 FINGERPRINT cert=... iat-mode=0
//
// we only check the shape. a wrong cert fails at connect time with a real
// error, and pretending to validate it here would just be theatre.
func validBridgeLine(s string) bool {
	f := strings.Fields(strings.TrimSpace(s))
	if len(f) < 3 || !strings.EqualFold(f[0], "obfs4") {
		return false
	}
	host, port, err := net.SplitHostPort(f[1])
	if err != nil || host == "" || port == "" {
		return false
	}
	return strings.Contains(strings.Join(f[3:], " "), "cert=")
}

func bridgesEnabled() bool {
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return bridgeOn && len(bridgeList) > 0
}

func bridgeLines() []string {
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return append([]string(nil), bridgeList...)
}

// the extra torrc arguments tor needs to route through us. empty when bridges
// are off, so the normal path is untouched.
func bridgeTorArgs() []string {
	if !bridgesEnabled() {
		return nil
	}
	bridgeMu.RLock()
	port := ptPort
	bridgeMu.RUnlock()
	if port == 0 {
		log.Println("bridges: no pt listener, starting direct instead")
		return nil
	}
	args := []string{
		"--UseBridges", "1",
		"--ClientTransportPlugin", fmt.Sprintf("obfs4 socks5 127.0.0.1:%d", port),
	}
	lines := bridgeLines()
	for _, b := range lines {
		args = append(args, "--Bridge", b)
	}
	log.Printf("bridges: handing tor %d bridge lines via 127.0.0.1:%d", len(lines), port)
	return args
}

// startPTListener brings up the local socks5 endpoint that tor will dial.
// idempotent: if one is already running we keep it, since restarting tor must
// not orphan the port it was told to use.
func startPTListener() error {
	bridgeMu.Lock()
	if ptListener != nil {
		bridgeMu.Unlock()
		return nil
	}
	bridgeMu.Unlock()

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return fmt.Errorf("pt listen: %w", err)
	}
	port := ln.Addr().(*net.TCPAddr).Port

	factory, err := (&obfs4.Transport{}).ClientFactory("")
	if err != nil {
		ln.Close()
		return fmt.Errorf("obfs4 client factory: %w", err)
	}

	bridgeMu.Lock()
	ptListener = ln
	ptPort = port
	bridgeMu.Unlock()

	log.Printf("bridges: obfs4 socks5 listening on 127.0.0.1:%d", port)

	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				bridgeMu.Lock()
				closed := ptListener == nil
				bridgeMu.Unlock()
				if closed {
					return
				}
				log.Printf("bridges: accept: %v", err)
				return
			}
			go servePTConn(conn, factory)
		}
	}()
	return nil
}

func stopPTListener() {
	bridgeMu.Lock()
	ln := ptListener
	ptListener = nil
	ptPort = 0
	bridgeMu.Unlock()
	if ln != nil {
		ln.Close()
		log.Println("bridges: obfs4 listener stopped")
	}
}

// one connection from tor: read the socks request, pull the per-bridge args
// out of it, dial the bridge through obfs4, then copy bytes both ways.
func servePTConn(conn net.Conn, factory base.ClientFactory) {
	defer conn.Close()

	req, err := socks5.Handshake(conn)
	if err != nil {
		log.Printf("bridges: socks handshake: %v", err)
		return
	}

	args, err := factory.ParseArgs(&req.Args)
	if err != nil {
		log.Printf("bridges: bad bridge args: %v", err)
		_ = req.Reply(socks5.ReplyGeneralFailure)
		return
	}

	dial := func(network, addr string) (net.Conn, error) {
		return net.Dial(network, addr)
	}
	if bridgeIsDead(req.Target) {
		// fail fast rather than making tor wait out another timeout
		_ = req.Reply(socks5.ReplyHostUnreachable)
		return
	}
	remote, err := factory.Dial("tcp", req.Target, dial, args)
	if err != nil {
		log.Printf("bridges: dial %s: %v", req.Target, err)
		noteBridgeFail(req.Target)
		_ = req.Reply(socks5.ErrorToReplyCode(err))
		return
	}
	noteBridgeOK(req.Target)
	defer remote.Close()

	if err = req.Reply(socks5.ReplySucceeded); err != nil {
		log.Printf("bridges: socks reply: %v", err)
		return
	}
	log.Printf("bridges: obfs4 connected to %s", req.Target)

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		_, _ = io.Copy(remote, conn)
		if c, ok := remote.(interface{ CloseWrite() error }); ok {
			_ = c.CloseWrite()
		}
	}()
	go func() {
		defer wg.Done()
		_, _ = io.Copy(conn, remote)
		if c, ok := conn.(interface{ CloseWrite() error }); ok {
			_ = c.CloseWrite()
		}
	}()
	wg.Wait()
}

// keep the linter honest about the goptlib import - req.Args is a pt.Args and
// we want the dependency stated rather than implied.
var _ = pt.Args{}

// takes newline separated bridge lines and whether to use them. the caller is
// expected to restart tor afterwards; changing this mid-session does nothing
// on its own, because tor reads the config once at startup.
//
//export HaloSetBridges
func HaloSetBridges(cLines *C.char, on C.int) *C.char {
	raw := C.GoString(cLines)
	var good, bad []string
	for _, ln := range strings.Split(raw, "\n") {
		ln = strings.TrimSpace(ln)
		if ln == "" {
			continue
		}
		if validBridgeLine(ln) {
			good = append(good, ln)
		} else {
			bad = append(bad, ln)
		}
	}

	bridgeMu.Lock()
	bridgeList = good
	bridgeOn = on != 0 && len(good) > 0
	enabled := bridgeOn
	bridgeMu.Unlock()

	if enabled {
		if err := startPTListener(); err != nil {
			return C.CString(fmt.Sprintf("error: %v", err))
		}
	} else {
		stopPTListener()
	}

	if len(bad) > 0 {
		return C.CString(fmt.Sprintf("ok: %d accepted, %d not understood", len(good), len(bad)))
	}
	return C.CString(fmt.Sprintf("ok: %d bridges", len(good)))
}

// what the ui needs: whether bridges are on, how many are configured, and
// whether the local transport is actually up.
//
// bounce tor so it picks up a config change. bridges are the only reason to
// call this - tor reads its arguments once and never again, so toggling them
// without a restart looks like the feature silently not working.
//
//export HaloRestartTor
func HaloRestartTor() *C.char {
	// asked for by hand, so the loop guard does not apply
	atomic.StoreInt64(&lastTorRestart, 0)
	go restartTor()
	return C.CString("ok")
}

//export HaloBridgeState
func HaloBridgeState() *C.char {
	bridgeMu.RLock()
	defer bridgeMu.RUnlock()
	return C.CString(fmt.Sprintf("%t|%d|%d", bridgeOn, len(bridgeList), ptPort))
}
