// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// the three transport plugins against a real tor: setting them again never
// hangs, every switch reaches the listener of the transport it names, and
// how long tor waits before it dials a bridge that failed earlier.
//
//	./torconf-tests.sh TestPluginSwitching
package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"runtime"
	"runtime/pprof"
	"strings"
	"testing"
	"time"

	"github.com/cretz/bine/control"
)

// a local port nothing listens on, so a dial there fails at once
func closedPort(t *testing.T) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	a := ln.Addr().String()
	ln.Close()
	return a
}

// lines that fail at once, each with a fingerprint tor has never seen
func fakeLines(t *testing.T) map[string]string {
	sf := randomFP()
	return map[string]string{
		"obfs4": fmt.Sprintf("obfs4 %s %s cert=%s iat-mode=0",
			closedPort(t), randomFP(), randomCert()),
		"webtunnel": fmt.Sprintf("webtunnel %s %s url=https://%s/x ver=0.0.1",
			closedPort(t), randomFP(), closedPort(t)),
		"snowflake": fmt.Sprintf("snowflake 192.0.2.3:80 %s fingerprint=%s url=http://%s/ ice=stun:%s",
			sf, sf, closedPort(t), closedPort(t)),
	}
}

func randomFP() string {
	b := make([]byte, 20)
	rand.Read(b)
	return strings.ToUpper(hex.EncodeToString(b))
}

func bootDirect(t *testing.T) {
	t.Helper()
	if addr := startListener(t.TempDir()); strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	if pct, _ := waitBoot(4 * time.Minute); pct < 100 {
		t.Skipf("tor only reached %d%% here", pct)
	}
	if err := startPTListeners(); err != nil {
		t.Fatal(err)
	}
}

func setLines(on bool, lines ...string) {
	bridgeMu.Lock()
	bridgeList, bridgeOn = lines, on
	bridgeMu.Unlock()
}

// reconnectTor with a hard limit: a stuck control port fails the test
// instead of hanging it
func switchTor(t *testing.T, what string) time.Duration {
	t.Helper()
	atomic_store_lastRestart(0)
	done := make(chan string, 1)
	t0 := time.Now()
	go func() { done <- reconnectTor() }()
	select {
	case r := <-done:
		if r != "ok" {
			t.Fatalf("%s: %s", what, r)
		}
	case <-time.After(60 * time.Second):
		t.Fatalf("%s: HUNG, reconnect still at %q after 60s", what, lastReconnectStep())
	}
	return time.Since(t0)
}

// how long until tor makes a socks request on this transport's listener
func waitDial(name string, since time.Time, limit time.Duration) (time.Duration, bool) {
	r := ptReg(name)
	for time.Since(since) < limit {
		if last := r.lastReq.Load(); last > since.UnixNano() {
			return time.Unix(0, last).Sub(since), true
		}
		time.Sleep(100 * time.Millisecond)
	}
	return 0, false
}

func checkConf(t *testing.T, what string, on bool, line string) {
	t.Helper()
	got := conf(t, "UseBridges", "Bridge", "ClientTransportPlugin", "DisableNetwork")
	if got["DisableNetwork"] != "0" {
		t.Fatalf("%s: network left off", what)
	}
	if !on {
		if got["UseBridges"] == "1" || got["Bridge"] != "" {
			t.Fatalf("%s: bridges left behind: %q %q", what, got["UseBridges"], got["Bridge"])
		}
		return
	}
	if got["UseBridges"] != "1" {
		t.Fatalf("%s: UseBridges=%q", what, got["UseBridges"])
	}
	if !strings.Contains(got["Bridge"], strings.Fields(line)[1]) || strings.Contains(got["Bridge"], "|") {
		t.Fatalf("%s: tor holds %q", what, got["Bridge"])
	}
	for _, p := range ptPlugins() {
		if !strings.Contains(got["ClientTransportPlugin"], p) {
			t.Fatalf("%s: plugin %q missing from %q", what, p, got["ClientTransportPlugin"])
		}
	}
}

// the old comment said tor hangs when ClientTransportPlugin is set twice in
// a process. set it again and again, same value and changed, network on and
// off, each with a limit.
func TestPluginResetNeverHangs(t *testing.T) {
	bootDirect(t)
	c := node(t).Control
	lines := fakeLines(t)
	plugins := ptPlugins()
	spare, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer spare.Close()
	moved := fmt.Sprintf("obfs4 socks5 %s", spare.Addr())
	set := func(vals ...string) func() error {
		return func() error {
			var kv []*control.KeyVal
			for _, v := range vals {
				kv = append(kv, control.NewKeyVal("ClientTransportPlugin", v))
			}
			return c.SetConf(kv...)
		}
	}
	for round := 1; round <= 3; round++ {
		timed(t, fmt.Sprintf("%d: plugins, network on", round), set(plugins...))
		timed(t, fmt.Sprintf("%d: same plugins again", round), set(plugins...))
		timed(t, fmt.Sprintf("%d: UseBridges 1 + Bridge", round), func() error {
			return c.SetConf(control.NewKeyVal("UseBridges", "1"),
				control.NewKeyVal("Bridge", lines["obfs4"]))
		})
		timed(t, fmt.Sprintf("%d: plugins while bridges on", round), set(plugins...))
		timed(t, fmt.Sprintf("%d: obfs4 moved to another port", round), set(append([]string{moved}, plugins[1:]...)...))
		timed(t, fmt.Sprintf("%d: back to our port", round), set(plugins...))
		timed(t, fmt.Sprintf("%d: DisableNetwork 1", round), func() error {
			return c.SetConf(control.KeyVals("DisableNetwork", "1")...)
		})
		timed(t, fmt.Sprintf("%d: plugins, network off", round), set(plugins...))
		timed(t, fmt.Sprintf("%d: UseBridges 0, RESETCONF Bridge", round), func() error {
			if err := c.SetConf(control.KeyVals("UseBridges", "0")...); err != nil {
				return err
			}
			return c.ResetConf(&control.KeyVal{Key: "Bridge"})
		})
		timed(t, fmt.Sprintf("%d: DisableNetwork 0", round), func() error {
			return c.SetConf(control.KeyVals("DisableNetwork", "0")...)
		})
		timed(t, fmt.Sprintf("%d: GETINFO bootstrap", round), func() error {
			_, err := c.GetInfo("status/bootstrap-phase")
			return err
		})
	}
	got := conf(t, "ClientTransportPlugin")
	for _, p := range plugins {
		if !strings.Contains(got["ClientTransportPlugin"], p) {
			t.Fatalf("plugin %q gone: %q", p, got["ClientTransportPlugin"])
		}
	}
}

// what turning bridges off does to the plugins, and whether tor still
// reaches a listener when bridges come back without them being named again
func TestPluginAfterOff(t *testing.T) {
	bootDirect(t)
	c := node(t).Control
	line := fakeLines(t)["obfs4"]
	setLines(true, line)
	switchTor(t, "on")
	if _, ok := waitDial("obfs4", time.Now().Add(-5*time.Second), 45*time.Second); !ok {
		t.Fatal("tor never dialled the obfs4 listener")
	}
	setLines(false)
	switchTor(t, "off")
	t.Logf("plugins after bridges off: %q", conf(t, "ClientTransportPlugin")["ClientTransportPlugin"])

	// back on with UseBridges and Bridge only
	t0 := time.Now()
	timed(t, "network off", func() error { return c.SetConf(control.KeyVals("DisableNetwork", "1")...) })
	timed(t, "UseBridges 1 + Bridge, no plugin", func() error {
		return c.SetConf(control.NewKeyVal("UseBridges", "1"), control.NewKeyVal("Bridge", line))
	})
	timed(t, "network on", func() error { return c.SetConf(control.KeyVals("DisableNetwork", "0")...) })
	if d, ok := waitDial("obfs4", t0, 45*time.Second); ok {
		t.Logf("without naming the plugin again tor dialled after %dms", d.Milliseconds())
	} else {
		t.Logf("without naming the plugin again tor never dialled in 45s")
	}

	// and the way applyBridgeConf does it
	setLines(true, line)
	t1 := time.Now()
	switchTor(t, "on with plugins")
	d, ok := waitDial("obfs4", t1, 45*time.Second)
	if !ok {
		t.Fatal("with the plugins named again tor never dialled")
	}
	t.Logf("with the plugins named again tor dialled after %dms", d.Milliseconds())
}

// the gate: three rounds through every transport and back to direct, each
// switch answered, each transport's listener dialled, the same tor, no
// control timeouts and flat goroutines
func TestPluginSwitching(t *testing.T) {
	bootDirect(t)
	first := node(t)
	goFirst := runtime.NumGoroutine()
	for round := 1; round <= 3; round++ {
		for _, n := range []string{"obfs4", "webtunnel", "snowflake", "obfs4", ""} {
			what := fmt.Sprintf("round %d, %q", round, n)
			if n == "" {
				setLines(false)
				took := switchTor(t, what)
				checkConf(t, what, false, "")
				t.Logf("%s: %dms", what, took.Milliseconds())
				continue
			}
			// a fresh fingerprint each time: tor's back-off for a line it
			// has seen fail is TestSnowflakeBackoff's business
			line := fakeLines(t)[n]
			setLines(true, line)
			t0 := time.Now()
			took := switchTor(t, what)
			checkConf(t, what, true, line)
			d, ok := waitDial(n, t0, 60*time.Second)
			if !ok {
				t.Fatalf("%s: tor never dialled the %s listener", what, n)
			}
			t.Logf("%s: switch %dms, first dial after %dms", what, took.Milliseconds(), d.Milliseconds())
		}
	}
	if node(t) != first {
		t.Fatal("tor was replaced")
	}
	if n := ctrlTimeoutCount(); n != 0 {
		t.Fatalf("%d control timeouts", n)
	}
	// snowflake clients wind down on their own timers
	time.Sleep(10 * time.Second)
	if n := runtime.NumGoroutine(); n > goFirst+40 {
		pprof.Lookup("goroutine").WriteTo(os.Stderr, 1)
		t.Fatalf("goroutines climbed: %d -> %d", goFirst, n)
	} else {
		t.Logf("goroutines %d -> %d", goFirst, n)
	}
}

// a bridge that keeps failing: switch away and back to the same line, and
// time its first dial against a line tor has never seen
func TestBridgeBackoff(t *testing.T) {
	bootDirect(t)
	failing := fakeLines(t)["obfs4"]
	setLines(true, failing)
	switchTor(t, "failing line")
	n0 := ptReg("obfs4").requests.Load()
	time.Sleep(90 * time.Second)
	t.Logf("tor dialled the failing line %d times in 90s", ptReg("obfs4").requests.Load()-n0)

	setLines(true, fakeLines(t)["webtunnel"])
	switchTor(t, "away")
	time.Sleep(20 * time.Second)

	setLines(true, failing)
	t0 := time.Now()
	switchTor(t, "back to the failed line")
	back, ok := waitDial("obfs4", t0, time.Minute)
	if !ok {
		t.Fatal("tor never dialled the failed line again in a minute")
	}

	setLines(true, fakeLines(t)["obfs4"])
	t1 := time.Now()
	switchTor(t, "a new line")
	fresh, ok := waitDial("obfs4", t1, 3*time.Minute)
	if !ok {
		t.Fatal("tor never dialled a new line")
	}
	t.Logf("first dial: failed line %dms, new line %dms", back.Milliseconds(), fresh.Milliseconds())
}

// snowflake's placeholder address and fingerprint never change, so a line
// that failed comes back with whatever tor remembers about it. snowflake
// answers the socks request before any proxy is found, so tor sees a
// connection that never finishes its handshake. switching back to the same
// line, after a while on it or at once, must still get a dial within a
// minute.
func TestSnowflakeBackoff(t *testing.T) {
	bootDirect(t)
	for _, stay := range []time.Duration{30 * time.Second, 0} {
		same := fakeLines(t)["snowflake"]
		var waits []string
		for i := 0; i < 5; i++ {
			setLines(true, same)
			t0 := time.Now()
			switchTor(t, "snowflake")
			d, ok := waitDial("snowflake", t0, time.Minute)
			if !ok {
				t.Fatalf("staying %s, round %d: tor never dialled the same line in a minute", stay, i)
			}
			waits = append(waits, fmt.Sprintf("%ds", int(d.Seconds())))
			time.Sleep(stay)
			setLines(true, fakeLines(t)["obfs4"])
			switchTor(t, "away")
			time.Sleep(5 * time.Second)
		}
		t.Logf("staying %s on it, first dial after each switch back: %s", stay, strings.Join(waits, ", "))
	}
}
