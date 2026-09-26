// SPDX-License-Identifier: GPL-3.0-or-later
//go:build torconf

// finds the control command tor stops answering: one at a time, each on its
// own goroutine with a timeout.
package main

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/cretz/bine/control"
)

func timed(t *testing.T, name string, f func() error) {
	t.Helper()
	done := make(chan error, 1)
	t0 := time.Now()
	go func() { done <- f() }()
	select {
	case err := <-done:
		t.Logf("%-42s %6dms  err=%v", name, time.Since(t0).Milliseconds(), err)
	case <-time.After(25 * time.Second):
		t.Fatalf("%-42s HUNG (no answer in 25s)", name)
	}
}

func TestWhichCommandHangs(t *testing.T) {
	dir := t.TempDir()
	if addr := startListener(dir); strings.HasPrefix(addr, "error:") {
		t.Fatalf("start: %s", addr)
	}
	if pct, _ := waitBoot(4 * time.Minute); pct < 100 {
		t.Skipf("only %d%% here", pct)
	}
	n := node(t)
	c := n.Control

	bridgeMu.Lock()
	bridgeList = []string{fakeBridge}
	bridgeOn = true
	bridgeMu.Unlock()
	if err := startPTListener(); err != nil {
		t.Fatal(err)
	}
	bridgeMu.RLock()
	port := ptPort
	bridgeMu.RUnlock()
	plugin := fmt.Sprintf("obfs4 socks5 127.0.0.1:%d", port)

	timed(t, "SETCONF DisableNetwork=1", func() error {
		return c.SetConf(control.KeyVals("DisableNetwork", "1")...)
	})
	timed(t, "SETCONF ClientTransportPlugin", func() error {
		return c.SetConf(control.KeyVals("ClientTransportPlugin", plugin)...)
	})
	timed(t, "SETCONF UseBridges=1 + Bridge", func() error {
		return c.SetConf(
			control.NewKeyVal("UseBridges", "1"),
			control.NewKeyVal("Bridge", fakeBridge),
		)
	})
	timed(t, "SETCONF DisableNetwork=0", func() error {
		return c.SetConf(control.KeyVals("DisableNetwork", "0")...)
	})

	// let it try the dead bridge for a while, the state a reconnect lands in
	t.Log("letting tor fail against the bridge for 20s...")
	time.Sleep(20 * time.Second)

	timed(t, "GETINFO bootstrap (while wedged)", func() error {
		_, err := c.GetInfo("status/bootstrap-phase")
		return err
	})
	timed(t, "SETCONF DisableNetwork=1 (while wedged)", func() error {
		return c.SetConf(control.KeyVals("DisableNetwork", "1")...)
	})
	timed(t, "SETCONF UseBridges=0", func() error {
		return c.SetConf(control.KeyVals("UseBridges", "0")...)
	})
	timed(t, "RESETCONF Bridge", func() error {
		return c.ResetConf(&control.KeyVal{Key: "Bridge"})
	})
	timed(t, "SETCONF DisableNetwork=0 (back to direct)", func() error {
		return c.SetConf(control.KeyVals("DisableNetwork", "0")...)
	})
}
