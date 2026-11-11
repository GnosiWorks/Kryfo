// SPDX-License-Identifier: GPL-3.0-or-later
package main

// with the memory folder on (windows), the onion key, the relay marks and
// the wrap queue never reach the disk, and what the app puts back after a
// restart is read as the files were

import (
	"bytes"
	"context"
	"encoding/hex"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func memFolderForTest(t *testing.T) {
	t.Helper()
	setMemFolder(true)
	t.Cleanup(func() { setMemFolder(false) })
}

func diskMarks(t *testing.T, dir string) []string {
	t.Helper()
	var out []string
	filepath.WalkDir(dir, func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			n := d.Name()
			if n == "onion.key" || strings.HasPrefix(n, "nostr_") {
				out = append(out, n)
			}
		}
		return nil
	})
	return out
}

func TestTheMemoryFolderKeepsTheMarksOffTheDisk(t *testing.T) {
	a, b := newRelayStandIn(t, 0), newRelayStandIn(t, 0)
	useTwoStores(t, a, b)
	memFolderForTest(t)
	oldSpread := kickSpread
	kickSpread = 0
	t.Cleanup(func() { kickSpread = oldSpread })
	dir := savedDataDir()

	key := bytes.Repeat([]byte{7}, 64)
	if !memPut("onion.key", key) {
		t.Fatal("the key was not taken")
	}
	if got, err := vRead(dir + "/onion.key"); err != nil || !bytes.Equal(got, key) {
		t.Fatalf("the engine reads %d bytes (%v)", len(got), err)
	}

	peer := newXid(t)
	tag := hex.EncodeToString(peer.pub[:])
	rcv := mustRcv(t, peer)
	ck := catchupKey(a.url(), rcv)
	forgetCatchup(ck)
	t.Cleanup(func() { forgetCatchup(ck); dropHeard(rcv) })
	a.store(wrapTo(t, peer, myXPub, "stored"))
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go nostrSubscribeRunner(ctx, tag, mainPair(peer.pub), rcv)
	waitFor(t, "the stored one", 10*time.Second, func() bool { return inboxHas(tag + "|stored") })
	waitFor(t, "the catch-up ran to its end", 10*time.Second, func() bool { return heardOf(ck) > 0 })
	seen, last := addressFiles(rcv)
	waitFor(t, "the marks written", 10*time.Second, func() bool {
		pollAcked(time.Now())
		return vExists(seen) && vExists(last) && vExists(heardFile(rcv))
	})
	topupAdd(storeFirst, laneEveryday, wrapKeptAt(t, testMain(), peer.pub, "waits", time.Now()))
	topupSync()
	cancel()
	runnersGone(t)

	if left := diskMarks(t, dir); len(left) > 0 {
		t.Fatalf("on the disk: %v", left)
	}
	names := strings.Join(memNames(), " ")
	for _, n := range []string{"onion.key", filepath.Base(seen), filepath.Base(last), filepath.Base(heardFile(rcv)), "nostr_topup"} {
		if !strings.Contains(names, n) {
			t.Fatalf("%s not in memory: %s", n, names)
		}
	}

	// the app keeps them sealed and puts them back at the next start
	kept := map[string][]byte{}
	for _, n := range memNames() {
		kept[n], _ = memGet(n)
	}
	setMemFolder(false)
	setMemFolder(true)
	if vExists(seen) || vExists(dir+"/onion.key") {
		t.Fatal("memory kept a file after it was turned off")
	}
	for n, b := range kept {
		memPut(n, b)
	}
	topupForget()
	if n := len(topupFor(storeFirst)); n != 1 {
		t.Fatalf("%d waiting after the start, want the one", n)
	}
	if s := loadSeen(seen); s.lines == 0 {
		t.Fatal("the ids seen did not come back")
	}
	if left := diskMarks(t, dir); len(left) > 0 {
		t.Fatalf("on the disk after the start: %v", left)
	}
}

func TestTheMemoryFolderActsAsTheDisk(t *testing.T) {
	memFolderForTest(t)
	dir := t.TempDir()
	p := dir + "/nostr_seen_ab"
	if vAppend(p, []byte("a\n"), false) == nil {
		t.Fatal("an append made a file it was told not to")
	}
	vAppend(p, []byte("a\n"), true)
	vAppend(p, []byte("b\n"), false)
	held := memFolder["nostr_seen_ab"]
	if got, _ := vRead(p); string(got) != "a\nb\n" {
		t.Fatalf("read %q", got)
	}
	vWrite(p+".tmp", []byte("c\n"))
	if err := vRename(p+".tmp", p); err != nil {
		t.Fatal(err)
	}
	if got, _ := vRead(p); string(got) != "c\n" || vExists(p+".tmp") {
		t.Fatalf("after the rename %q", got)
	}
	if !bytes.Equal(held, make([]byte, len(held))) {
		t.Fatal("the bytes replaced were not zeroed")
	}
	if vRename(p, dir+"/other") == nil {
		t.Fatal("a rename out of memory went through")
	}
	// tor's and any other file stay on the disk
	vWrite(dir+"/torrc", []byte("x"))
	if _, err := os.Stat(dir + "/torrc"); err != nil {
		t.Fatal("a file outside the set did not reach the disk")
	}
	if memPut("../x", nil) || memPut("a/b", nil) {
		t.Fatal("a name with a folder was taken")
	}
	vRemove(p)
	if vExists(p) {
		t.Fatal("removed, still there")
	}
}
