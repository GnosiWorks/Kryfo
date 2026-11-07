// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !windows

package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cretz/bine/tor"
)

func TestTorDirTargetFollowsALinkOnly(t *testing.T) {
	root := t.TempDir()
	real := filepath.Join(root, "docs", "tor")
	if err := os.MkdirAll(real, 0700); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(root, "engine-tor")
	if err := os.Symlink(real, link); err != nil {
		t.Fatal(err)
	}
	want, _ := filepath.EvalSymlinks(real)
	if got := torDirTarget(link); got != want {
		t.Fatalf("a link: %q, want %q", got, want)
	}
	if got := torDirTarget(real); got != real {
		t.Fatalf("a real folder: %q, want it unchanged", got)
	}
	gone := filepath.Join(root, "none")
	if got := torDirTarget(gone); got != gone {
		t.Fatalf("missing: %q", got)
	}
}

// the linux desktop layout: engine/tor a link to docs/tor. tor is handed
// the folder the link points to, never the link
func TestTorStartsInTheFolderALinkPointsTo(t *testing.T) {
	was := torLaunches.Load()
	t.Cleanup(func() { torLaunches.Store(was) })
	torLaunches.Store(0)
	mu.Lock()
	had := torNode
	torNode, myAddr = nil, ""
	mu.Unlock()
	t.Cleanup(func() { mu.Lock(); torNode = had; mu.Unlock() })
	st, dir := torStatusNow(), savedDataDir()
	t.Cleanup(func() { setStatus(st); setSavedDataDir(dir) })
	root := t.TempDir()
	docsTor := filepath.Join(root, "docs", "tor")
	engine := filepath.Join(root, "engine")
	for _, d := range []string{docsTor, engine} {
		if err := os.MkdirAll(d, 0700); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Symlink(docsTor, filepath.Join(engine, "tor")); err != nil {
		t.Fatal(err)
	}
	var dirs []string
	prev := startTor
	startTor = func(_ context.Context, c *tor.StartConf) (*tor.Tor, error) {
		dirs = append(dirs, c.DataDir)
		return nil, errors.New("stand-in")
	}
	t.Cleanup(func() { startTor = prev })
	r := startListener(engine)
	if !strings.HasPrefix(r, "error: tor start:") || len(dirs) == 0 {
		t.Fatalf("start: %q, %d starts", r, len(dirs))
	}
	want, _ := filepath.EvalSymlinks(docsTor)
	for _, d := range dirs {
		if d != want {
			t.Fatalf("tor handed %q, want %q", d, want)
		}
	}
}
