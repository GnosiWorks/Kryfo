// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"testing"
	"time"
)

// the app signs these exact texts (engine/handle.go, with the same vectors
// in its tests)
func TestMessagesMatchTheApp(t *testing.T) {
	inv := "kryfo://share?id=a-b-c&onion=x.onion&v=3&bundle=zz&fc=ff"
	if got := claimMsgV2("wren", inv, 1790000000); got !=
		"kryfo-handle-claim-v2:wren:530f32c83efc284e4c58096111b3b3109892d39404fe0bc18aa9f141e5b77d1d:1790000000" {
		t.Fatal(got)
	}
	if got := releaseMsgV2("wren", 1790000000); got != "kryfo-handle-release-v2:wren:1790000000" {
		t.Fatal(got)
	}
	pub := make([]byte, 32)
	for i := range pub {
		pub[i] = byte(i)
	}
	if got := wordsOf(fmt.Sprintf("%x", pub)); got != "manage-cruise-coast" {
		t.Fatalf("words: %q", got)
	}
}

func releaseBody(h string, o owner, ts int64) map[string]string {
	return map[string]string{
		"handle": h, "ts": fmt.Sprint(ts), "v": "2",
		"pubkey": o.hexPub(), "sig": o.sign(releaseMsgV2(h, ts)),
	}
}

func held(st *store, h string) bool {
	_, ok := st.get(h)
	return ok
}

func TestClaimV2(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	now := time.Now().Unix()
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("wren", "hi", o, now)); out["ok"] != true {
		t.Fatalf("claim: %v", out)
	}
	e, _ := st.get("wren")
	if e.Pubkey != o.hexPub() || e.Invite != o.invite() || e.Bio != "hi" || e.SignedAt != now {
		t.Fatalf("stored: %+v", e)
	}
	// someone else's key, with their own invite
	other := newOwner(t)
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("wren", "", other, now)); out["error"] != "that handle is taken" {
		t.Fatalf("a second key: %v", out)
	}
	// a claim that changes the invite is signed over the new one
	moved := claimBody("wren", "hi", o, now+1)
	moved["invite"] = o.invite() + "&x=1"
	if out := post(t, c, srv.URL, "/handle/claim", moved); out["error"] != "signature does not match" {
		t.Fatalf("an invite the signature does not name: %v", out)
	}
}

func TestReleaseV2(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	claim(t, c, srv.URL, "wren", o)
	other := newOwner(t)
	now := time.Now().Unix()
	if out := post(t, c, srv.URL, "/handle/release", releaseBody("wren", other, now)); out["error"] != "not yours to release" {
		t.Fatalf("another key's release: %v", out)
	}
	if out := post(t, c, srv.URL, "/handle/release", releaseBody("wren", o, now)); out["ok"] != true {
		t.Fatalf("release: %v", out)
	}
	if held(st, "wren") {
		t.Fatal("still held after the release")
	}
}

// a claim's signature says claim and a release's says release: neither one
// does the other's job
func TestSignaturesKeepToTheirAction(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	now := time.Now().Unix()
	claimed := claimBody("wren", "hi", o, now)
	if out := post(t, c, srv.URL, "/handle/claim", claimed); out["ok"] != true {
		t.Fatalf("claim: %v", out)
	}

	// the claim's fields and signature, sent as a release
	asRelease := map[string]string{
		"handle": "wren", "ts": claimed["ts"], "v": "2",
		"pubkey": claimed["pubkey"], "sig": claimed["sig"],
	}
	if out := post(t, c, srv.URL, "/handle/release", asRelease); out["ok"] == true {
		t.Fatal("a claim signature released the handle")
	}
	if !held(st, "wren") {
		t.Fatal("the handle is gone")
	}

	// a release's signature, sent as a claim for a released handle
	if out := post(t, c, srv.URL, "/handle/release", releaseBody("wren", o, now+1)); out["ok"] != true {
		t.Fatalf("release: %v", out)
	}
	rel := releaseBody("wren", o, now+2)
	asClaim := map[string]string{
		"handle": "wren", "invite": o.invite(), "ts": rel["ts"], "v": "2",
		"pubkey": rel["pubkey"], "sig": rel["sig"],
	}
	if out := post(t, c, srv.URL, "/handle/claim", asClaim); out["ok"] == true {
		t.Fatal("a release signature claimed the handle")
	}
	if held(st, "wren") {
		t.Fatal("the handle came back")
	}
}

func TestStaleTimeIsRefused(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	now := time.Now().Unix()
	for _, ts := range []int64{now - signSkew - 60, now + signSkew + 60} {
		if out := post(t, c, srv.URL, "/handle/claim", claimBody("wren", "", o, ts)); out["error"] != "check the phone's clock" {
			t.Fatalf("claim at %+d s: %v", ts-now, out)
		}
	}
	if held(st, "wren") {
		t.Fatal("an old claim was taken")
	}
	claim(t, c, srv.URL, "wren", o)
	for _, ts := range []int64{now - signSkew - 60, now + signSkew + 60} {
		if out := post(t, c, srv.URL, "/handle/release", releaseBody("wren", o, ts)); out["error"] != "check the phone's clock" {
			t.Fatalf("release at %+d s: %v", ts-now, out)
		}
	}
	if !held(st, "wren") {
		t.Fatal("an old release was taken")
	}
}

// inside the window, the time still orders changes: nothing signed before
// the last one is taken
func TestOlderChangesAreRefused(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	now := time.Now().Unix()
	first := claimBody("wren", "first", o, now-60)
	if out := post(t, c, srv.URL, "/handle/claim", first); out["ok"] != true {
		t.Fatal(out)
	}
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("wren", "second", o, now)); out["ok"] != true {
		t.Fatal(out)
	}
	if out := post(t, c, srv.URL, "/handle/claim", first); out["error"] != "an older change" {
		t.Fatalf("the first claim again: %v", out)
	}
	if out := post(t, c, srv.URL, "/handle/release", releaseBody("wren", o, now-30)); out["error"] != "an older change" {
		t.Fatalf("a release from before the last claim: %v", out)
	}
	if out := post(t, c, srv.URL, "/handle/release", releaseBody("wren", o, now)); out["ok"] != true {
		t.Fatal(out)
	}
	// a claim from before the release does not bring it back
	if out := post(t, c, srv.URL, "/handle/claim", first); out["ok"] == true {
		t.Fatal("a claim from before the release was taken")
	}
	if held(st, "wren") {
		t.Fatal("the handle came back")
	}
	// a new one does
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("wren", "again", o, now+1)); out["ok"] != true {
		t.Fatalf("claiming it again: %v", out)
	}
}

// the invite's three words come from the claimer's own key, or nothing is
// written
func TestInviteMustBeTheClaimers(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	someone := newOwner(t)
	now := time.Now().Unix()
	b := map[string]string{
		"handle": "wren", "invite": someone.invite(), "ts": fmt.Sprint(now), "v": "2",
		"pubkey": o.hexPub(), "sig": o.sign(claimMsgV2("wren", someone.invite(), now)),
	}
	if out := post(t, c, srv.URL, "/handle/claim", b); out["error"] != "the invite is not yours" {
		t.Fatalf("v2 with someone else's invite: %v", out)
	}
	v1 := map[string]string{
		"handle": "wren", "invite": someone.invite(),
		"pubkey": o.hexPub(), "sig": o.sign("kryfo-handle-v1:wren"),
	}
	if out := post(t, c, srv.URL, "/handle/claim", v1); out["error"] != "the invite is not yours" {
		t.Fatalf("v1 with someone else's invite: %v", out)
	}
	if held(st, "wren") {
		t.Fatal("written with someone else's invite")
	}
	// and a repoint cannot move a held handle onto someone else's invite
	claim(t, c, srv.URL, "wren", o)
	b["ts"] = fmt.Sprint(now + 1)
	b["sig"] = o.sign(claimMsgV2("wren", someone.invite(), now+1))
	if out := post(t, c, srv.URL, "/handle/claim", b); out["error"] != "the invite is not yours" {
		t.Fatalf("repointed onto someone else's invite: %v", out)
	}
	if e, _ := st.get("wren"); e.Invite != o.invite() {
		t.Fatalf("invite now %q", e.Invite)
	}
}

// older apps sign the handle alone: taken for now, until the switch is off,
// and never for a handle that has been claimed under v2
func TestV1StillAccepted(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	v1 := func(path, h string, o owner) map[string]any {
		return post(t, c, srv.URL, path, map[string]string{
			"handle": h, "invite": o.invite(), "bio": "old app",
			"pubkey": o.hexPub(), "sig": o.sign("kryfo-handle-v1:" + h),
		})
	}
	if out := v1("/handle/claim", "wren", o); out["ok"] != true {
		t.Fatalf("v1 claim: %v", out)
	}
	if e, _ := st.get("wren"); e.SignedAt != 0 || e.Bio != "old app" {
		t.Fatalf("stored: %+v", e)
	}
	if out := v1("/handle/release", "wren", o); out["ok"] != true {
		t.Fatalf("v1 release: %v", out)
	}
	if held(st, "wren") {
		t.Fatal("still held after a v1 release")
	}

	// the app updates: its first v2 claim moves the handle to v2 for good,
	// even when it changes nothing else
	if out := v1("/handle/claim", "kite", o); out["ok"] != true {
		t.Fatalf("v1 claim: %v", out)
	}
	now := time.Now().Unix()
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("kite", "old app", o, now)); out["ok"] != true {
		t.Fatalf("v2 over v1: %v", out)
	}
	if e, _ := st.get("kite"); e.SignedAt != now {
		t.Fatalf("stored: %+v", e)
	}
	if out := v1("/handle/claim", "kite", o); out["error"] != "update the app" {
		t.Fatalf("v1 claim of a v2 handle: %v", out)
	}
	if out := v1("/handle/release", "kite", o); out["error"] != "update the app" {
		t.Fatalf("v1 release of a v2 handle: %v", out)
	}
	if !held(st, "kite") {
		t.Fatal("a v1 release took a v2 handle")
	}

	// the switch
	acceptV1 = false
	t.Cleanup(func() { acceptV1 = true })
	if out := v1("/handle/claim", "lark", o); out["error"] != "update the app" {
		t.Fatalf("v1 with the switch off: %v", out)
	}
	if out := post(t, c, srv.URL, "/handle/claim", claimBody("lark", "", o, now)); out["ok"] != true {
		t.Fatalf("v2 with the switch off: %v", out)
	}
}

// a version nobody sends is not guessed at
func TestUnknownVersionIsRefused(t *testing.T) {
	srv, _ := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	b := claimBody("wren", "", o, time.Now().Unix())
	b["v"] = "3"
	if out := post(t, c, srv.URL, "/handle/claim", b); out["ok"] == true {
		t.Fatalf("v3: %v", out)
	}
	b["v"] = "2"
	b["ts"] = "soon"
	if out := post(t, c, srv.URL, "/handle/claim", b); out["error"] != "bad request" {
		t.Fatalf("a time that is not a number: %v", out)
	}
}
