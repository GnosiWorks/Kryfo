package main

import (
	"testing"

	"github.com/nbd-wtf/go-nostr"
)

// the app listens on each address over a socket of its own, so a big inbox
// is many sockets with a req and a probe each. the per-connection req
// budget never turns one of them away, however many addresses there are
func TestABigInboxIsNotRateLimited(t *testing.T) {
	url, _ := testRelay(t)
	now := nostr.Now()
	for i := 0; i < 271; i++ {
		r := connect(t, url)
		a := addr()
		if _, why := ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {a}}, Limit: 100}); why != "" {
			t.Fatalf("address %d asking: %q", i, why)
		}
		probe := nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {a}}, Since: &now, LimitZero: true}
		if _, why := ask(t, r, probe); why != "" {
			t.Fatalf("address %d probing: %q", i, why)
		}
	}
}

// the same addresses on one socket, one req each, run past the burst. ten
// to a filter, as maxAddrs allows, they fit
func TestOneSocketForManyAddresses(t *testing.T) {
	url, _ := testRelay(t)
	r := connect(t, url)
	refused := 0
	for i := 0; i < 271; i++ {
		if _, why := ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {addr()}}}); why != "" {
			refused++
		}
	}
	// the refill gives back a couple a second while the test runs
	if refused < 271-reqBurst-20 {
		t.Fatalf("%d of 271 refused, want about %d", refused, 271-reqBurst)
	}
	r = connect(t, url)
	for i := 0; i < 28; i++ {
		var ps []string
		for j := 0; j < maxAddrs; j++ {
			ps = append(ps, addr())
		}
		if _, why := ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": ps}}); why != "" {
			t.Fatalf("merged req %d: %q", i, why)
		}
	}
}
