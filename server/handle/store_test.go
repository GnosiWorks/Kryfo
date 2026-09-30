// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// post from any goroutine: failures come back instead of stopping the test
func postAsync(c *http.Client, base, path string, body map[string]string) (map[string]any, error) {
	b, _ := json.Marshal(body)
	resp, err := c.Post(base+path, "application/json", bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var out map[string]any
	err = json.NewDecoder(resp.Body).Decode(&out)
	return out, err
}

// a claim of h pointing at inv, signed by o
func claimWith(h, inv string, o owner, ts int64) map[string]string {
	return map[string]string{
		"handle": h, "invite": inv, "ts": fmt.Sprint(ts), "v": "2",
		"pubkey": o.hexPub(), "sig": o.sign(claimMsgV2(h, inv, ts)),
	}
}

// many keys asking for one free name at once, while another write is on
// its way to disk: one is told ok, and the name is that one's
func TestOneClaimTakesAFreeName(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	fill(st)
	c := srv.Client()
	now := time.Now().Unix()
	for round := 0; round < 5; round++ {
		h := fmt.Sprintf("wren%d", round)
		other := newOwner(t)
		owners := make([]owner, 12)
		for i := range owners {
			owners[i] = newOwner(t)
		}
		won := make([]bool, len(owners))
		start := make(chan struct{})
		var wg sync.WaitGroup
		wg.Add(1)
		go func() {
			defer wg.Done()
			out, err := postAsync(c, srv.URL, "/handle/claim", claimBody(fmt.Sprintf("kite%d", round), "", other, now))
			if err != nil || out["ok"] != true {
				t.Errorf("the other write: %v %v", out, err)
			}
		}()
		for i, o := range owners {
			wg.Add(1)
			go func(i int, o owner) {
				defer wg.Done()
				<-start
				out, err := postAsync(c, srv.URL, "/handle/claim", claimBody(h, "", o, now))
				if err != nil {
					t.Error(err)
					return
				}
				won[i] = out["ok"] == true
				if !won[i] && out["error"] != "that handle is taken" {
					t.Errorf("%s: %v", h, out)
				}
			}(i, o)
		}
		time.Sleep(2 * time.Millisecond)
		close(start)
		wg.Wait()
		winners := 0
		e, _ := st.get(h)
		for i, ok := range won {
			if ok {
				winners++
				if e.Pubkey != owners[i].hexPub() {
					t.Fatalf("%s: told ok, held by another key", h)
				}
			}
		}
		if winners != 1 {
			t.Fatalf("%s: %d claims told ok", h, winners)
		}
	}
}

// a registry big enough that a write takes a moment
func fill(st *store) {
	for i := 0; i < 4000; i++ {
		h := fmt.Sprintf("zz%05d", i)
		st.m[h] = entry{Handle: h, Invite: strings.Repeat("x", 600), Pubkey: strings.Repeat("0", 64)}
	}
}

// a listing change and a repoint of the same handle at once, while another
// write is on its way to disk: each keeps what the other wrote
func TestListingAndRepointKeepEachOther(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	fill(st)
	c := srv.Client()
	o, other := newOwner(t), newOwner(t)
	base := time.Now().Unix() - 300
	if out := post(t, c, srv.URL, "/handle/claim", claimWith("wren", o.invite(), o, base)); out["ok"] != true {
		t.Fatal(out)
	}
	inv := func(i int) string { return fmt.Sprintf("%s&n=%d", o.invite(), i) }
	for i := 1; i <= 5; i++ {
		ts := base + int64(i)
		on := i%2 == 1
		l := map[bool]string{true: "1", false: "0"}[on]
		start := make(chan struct{})
		var wg sync.WaitGroup
		wg.Add(3)
		go func() {
			defer wg.Done()
			out, err := postAsync(c, srv.URL, "/handle/claim", claimBody(fmt.Sprintf("kite%d", i), "", other, base))
			if err != nil || out["ok"] != true {
				t.Errorf("the other write: %v %v", out, err)
			}
		}()
		go func() {
			defer wg.Done()
			<-start
			out, err := postAsync(c, srv.URL, "/handle/claim", claimWith("wren", inv(i), o, ts))
			if err != nil || out["ok"] != true {
				t.Errorf("repoint %d: %v %v", i, out, err)
			}
		}()
		go func() {
			defer wg.Done()
			<-start
			out, err := postAsync(c, srv.URL, "/handle/listing", map[string]string{
				"handle": "wren", "listed": l, "name": "Wren", "ts": fmt.Sprint(ts),
				"pubkey": o.hexPub(), "sig": o.sign(listingMsg("wren", on, ts, "Wren")),
			})
			if err != nil || out["ok"] != true {
				t.Errorf("listing %d: %v %v", i, out, err)
			}
		}()
		time.Sleep(2 * time.Millisecond)
		close(start)
		wg.Wait()
		e, _ := st.get("wren")
		if e.Invite != inv(i) {
			t.Fatalf("round %d: the repoint was undone: %q", i, e.Invite)
		}
		if e.ListedAt != ts || e.Listed != on {
			t.Fatalf("round %d: the listing change was undone: %+v", i, e)
		}
	}
}

// a change is seen at once, and reads never wait on the file being written
func TestReadsDoNotWaitForTheFile(t *testing.T) {
	st := openStore(filepath.Join(t.TempDir(), "handles.json"))
	// a file write that takes its time
	st.wmu.Lock()
	done := make(chan error, 2)
	for _, h := range []string{"wren", "kite"} {
		go func(h string) {
			done <- st.update(h, func(t *tx) error {
				t.put(entry{Invite: "kryfo://share?id=" + h})
				return nil
			})
		}(h)
	}
	deadline := time.Now().Add(5 * time.Second)
	for !held(st, "wren") || !held(st, "kite") {
		if time.Now().After(deadline) {
			t.Fatal("a read waited for the file")
		}
		time.Sleep(time.Millisecond)
	}
	select {
	case <-done:
		t.Fatal("a change was answered before the file held it")
	default:
	}
	st.wmu.Unlock()
	for i := 0; i < 2; i++ {
		if err := <-done; err != nil {
			t.Fatal(err)
		}
	}
	back := openStore(st.path)
	if !held(back, "wren") || !held(back, "kite") {
		t.Fatal("the file is missing a change it answered for")
	}
}

// one handle costs about its own size on disk: an invite at the ceiling is
// written as sent, and only a bio can grow, at most six times, when it is
// made of control characters
func TestOneHandleStaysSmallOnDisk(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	pad := func(with string) string {
		return o.invite() + strings.Repeat(with, (maxInvite-len(o.invite()))/len(with))
	}
	// characters the file would have to write longer are not in any invite
	for _, with := range []string{`"`, `\`, "\u2028", " ", "\u00e9"} {
		b := claimWith("wren", pad(with), o, time.Now().Unix())
		if out := post(t, c, srv.URL, "/handle/claim", b); out["error"] != "bad invite" {
			t.Fatalf("an invite padded with %q: %v", with, out)
		}
	}
	inv := pad("&")
	if len(inv) != maxInvite {
		t.Fatalf("the invite is %d bytes, not at the ceiling", len(inv))
	}
	b := claimWith("wren", inv, o, time.Now().Unix())
	b["bio"] = strings.Repeat("\x01", 200)
	if out := post(t, c, srv.URL, "/handle/claim", b); out["ok"] != true {
		t.Fatal(out)
	}
	raw, err := os.ReadFile(st.path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Contains(raw, []byte(inv)) {
		t.Fatal("the invite is not on disk as sent")
	}
	// the key, the times and the field names
	if len(raw) > maxInvite+6*200+400 {
		t.Fatalf("one handle takes %d bytes on disk", len(raw))
	}
	back := openStore(st.path)
	if e, _ := back.get("wren"); e.Invite != inv || e.Bio != b["bio"] {
		t.Fatalf("read back: %+v", e)
	}
}

// a write that cannot finish leaves the file as it was, and nothing half
// written beside it
func TestFailedWriteKeepsTheFile(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root writes into a read-only folder")
	}
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	dir := filepath.Dir(st.path)
	if err := os.Chmod(dir, 0o500); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(dir, 0o700) })
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("kite", "", o, time.Now().Unix())); out["error"] != "could not save" {
		t.Fatalf("a claim that could not be written: %v", out)
	}
	os.Chmod(dir, 0o700)
	if _, err := os.Stat(st.path + ".tmp"); !os.IsNotExist(err) {
		t.Fatal("a temp file was left behind")
	}
	back := openStore(st.path)
	if !held(back, "wren") || held(back, "kite") {
		t.Fatal("the file changed")
	}
}

// a retry after a failed write finds its change in memory already, and is
// told ok only once the file holds it: a reopened store holds what was
// answered ok and nothing that was not
func TestNoOkBeforeTheFileHoldsIt(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root writes into a read-only folder")
	}
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	dir := filepath.Dir(st.path)
	t.Cleanup(func() { os.Chmod(dir, 0o700) })
	lock := func() {
		if err := os.Chmod(dir, 0o500); err != nil {
			t.Fatal(err)
		}
	}
	unlock := func() {
		if err := os.Chmod(dir, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	on := func(want bool, what string) {
		t.Helper()
		if held(openStore(st.path), "kite") != want {
			t.Fatalf("%s: the file does not match the answers", what)
		}
	}
	now := time.Now().Unix()
	kite := claimBody("kite", "", o, now)
	gone := releaseBody("kite", o, now+1)

	lock()
	for i := 0; i < 2; i++ {
		if out := post(t, c, srv.URL, "/handle/claim", kite); out["error"] != "could not save" {
			t.Fatalf("claim %d while the folder takes no writes: %v", i, out)
		}
	}
	on(false, "claims that could not be saved")
	unlock()
	if out := post(t, c, srv.URL, "/handle/claim", kite); out["ok"] != true {
		t.Fatalf("the claim once the folder takes writes: %v", out)
	}
	on(true, "a claim answered ok")

	lock()
	for i := 0; i < 2; i++ {
		if out := post(t, c, srv.URL, "/handle/release", gone); out["error"] != "could not save" {
			t.Fatalf("release %d while the folder takes no writes: %v", i, out)
		}
	}
	on(true, "releases that could not be saved")
	unlock()
	if out := post(t, c, srv.URL, "/handle/release", gone); out["ok"] != true {
		t.Fatalf("the release once the folder takes writes: %v", out)
	}
	on(false, "a release answered ok")
	if !held(openStore(st.path), "wren") {
		t.Fatal("the file lost a handle it held")
	}
}

// a folder that cannot be opened to sync the rename is a write that did not
// finish, and is not answered ok
func TestTheFolderIsSyncedBeforeOk(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root opens any folder")
	}
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	dir := filepath.Dir(st.path)
	// files can be made and renamed in it, but it cannot be opened
	if err := os.Chmod(dir, 0o300); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(dir, 0o700) })
	kite := claimBody("kite", "", o, time.Now().Unix())
	if out := post(t, c, srv.URL, "/handle/claim", kite); out["error"] != "could not save" {
		t.Fatalf("a claim whose folder could not be synced: %v", out)
	}
	if err := os.Chmod(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if out := post(t, c, srv.URL, "/handle/claim", kite); out["ok"] != true {
		t.Fatalf("the claim once the folder opens: %v", out)
	}
	if !held(openStore(st.path), "kite") {
		t.Fatal("the file does not hold a claim answered ok")
	}
}

// a test store, from a file that is fine or not there yet
func openStore(path string) *store {
	s, err := loadStore(path)
	if err != nil {
		panic(err)
	}
	return s
}

// only a file that is not there yet starts empty: one the registry cannot
// read or parse stops it before any write can replace the handles
func TestStoreStartsOnlyFromAFileItCanRead(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "handles.json")
	if s, err := loadStore(path); err != nil || len(s.m) != 0 {
		t.Fatalf("no file yet: %v, %d handles", err, len(s.m))
	}
	if err := os.WriteFile(path, []byte(`{"wren":{`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := loadStore(path); err == nil {
		t.Fatal("a file cut short was taken as an empty store")
	}
	if err := os.WriteFile(path, []byte(`{}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(path, 0); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(path, 0o600) })
	if _, err := os.ReadFile(path); err == nil {
		t.Skip("running with rights that read any file")
	}
	if _, err := loadStore(path); err == nil {
		t.Fatal("a file that cannot be read was taken as an empty store")
	}
}
