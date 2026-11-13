// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// a file an older registry wrote: claim times on every handle, one change
// long past the clock window and one inside it
func TestTidyDropsClaimTimesAndSettlesOldOnes(t *testing.T) {
	now := time.Now().Unix()
	recent, long := now-60, now-3*3600
	path := filepath.Join(t.TempDir(), "handles.json")
	file := fmt.Sprintf(`{
  "kite": {"handle": "kite", "invite": "a", "bio": "", "pubkey": "p1", "claimed_at": %d, "signed_at": %d, "listed": true, "name": "Kite", "listed_at": %d},
  "wren": {"handle": "wren", "invite": "b", "bio": "", "pubkey": "p2", "claimed_at": %d, "signed_at": %d, "listed_at": %d}
}`, long, long, long, recent, recent, recent)
	if err := os.WriteFile(path, []byte(file), 0o600); err != nil {
		t.Fatal(err)
	}
	st := openStore(path)
	if err := st.tidy(time.Unix(now, 0)); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(b, []byte("claimed_at")) {
		t.Fatalf("claim times still on disk:\n%s", b)
	}
	kite, wren := openStore(path).m["kite"], openStore(path).m["wren"]
	if kite.SignedAt != settled || kite.ListedAt != settled || !kite.Listed || kite.Name != "Kite" {
		t.Fatalf("kite not settled: %+v", kite)
	}
	if wren.SignedAt != recent || wren.ListedAt != recent {
		t.Fatalf("a time inside the window was settled: %+v", wren)
	}

	// nothing left to settle: no write
	before, _ := os.Stat(path)
	time.Sleep(10 * time.Millisecond)
	if err := st.tidy(time.Unix(now, 0)); err != nil {
		t.Fatal(err)
	}
	if after, _ := os.Stat(path); !after.ModTime().Equal(before.ModTime()) {
		t.Fatal("a tidy with nothing to do wrote the file")
	}
}

// a settled handle takes its owner's next change, still refuses v1, and a
// claim signed before the settled time is past the window anyway
func TestSettledHandleKeepsTheRules(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o, other := newOwner(t), newOwner(t)
	now := time.Now().Unix()
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("wren", "first", o, now)); out["ok"] != true {
		t.Fatal(out)
	}
	if out := list(t, c, srv.URL, "wren", o, true, "Wren", now); out["ok"] != true {
		t.Fatal(out)
	}
	// an hour on, as the registry's clock sees it
	st.settle(now + 3600)
	if e, _ := st.get("wren"); e.SignedAt != settled || e.ListedAt != settled {
		t.Fatalf("not settled: %+v", e)
	}
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("wren", "second", o, now+1)); out["ok"] != true {
		t.Fatalf("the owner's next change: %v", out)
	}
	if e, _ := st.get("wren"); e.Bio != "second" || e.SignedAt != now+1 {
		t.Fatalf("change not taken: %+v", e)
	}
	st.settle(now + 3600)
	if out := list(t, c, srv.URL, "wren", o, false, "", now+2); out["ok"] != true {
		t.Fatalf("listing change after settle: %v", out)
	}
	v1 := map[string]string{"handle": "wren", "invite": o.invite(), "pubkey": o.hexPub(), "sig": o.sign("kryfo-handle-v1:wren")}
	if out := post(t, c, srv.URL, "/handle/claim", v1); out["ok"] == true {
		t.Fatalf("a v1 claim was taken on a v2 handle: %v", out)
	}
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("wren", "x", other, now)); out["ok"] == true {
		t.Fatalf("someone else took it: %v", out)
	}
	old := now - 2*signSkew
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("wren", "replay", o, old)); out["ok"] == true {
		t.Fatalf("a claim from before the window was taken: %v", out)
	}
}
