// SPDX-License-Identifier: GPL-3.0-or-later
//go:build relay

// against a real relay: go test -tags relay ./catchup/ with RELAY_URL set to
// a relay-live started on localhost with an empty database.
package catchup

import (
	"context"
	"math"
	"os"
	"testing"
	"time"

	"fiatjaf.com/nostr"
)

func TestAgainstARealRelay(t *testing.T) {
	url := os.Getenv("RELAY_URL")
	if url == "" {
		t.Skip("RELAY_URL not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, url, nostr.RelayOptions{})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()

	rcv := nostr.Generate().Public()
	now := nostr.Now()
	const total = 437
	sent := map[nostr.ID]bool{}
	for i := 0; i < total; i++ {
		sk := nostr.Generate()
		ev := nostr.Event{
			Kind:      1059,
			CreatedAt: now - nostr.Timestamp(i*97),
			Tags:      nostr.Tags{{"p", rcv.Hex()}},
			Content:   "x",
		}
		if err := ev.Sign(sk); err != nil {
			t.Fatal(err)
		}
		if err := r.Publish(ctx, ev); err != nil {
			t.Fatalf("publish %d: %v", i, err)
		}
		sent[ev.ID] = true
	}

	page := func(pc context.Context, since, until nostr.Timestamp, limit int) ([]nostr.Event, error) {
		sub, err := r.Subscribe(pc, nostr.Filter{
			Kinds: []nostr.Kind{1059},
			Tags:  nostr.TagMap{"p": []string{rcv.Hex()}},
			Since: since, Until: until, Limit: limit,
		}, nostr.SubscriptionOptions{MaxWaitForEOSE: time.Duration(math.MaxInt64)})
		if err != nil {
			return nil, err
		}
		defer sub.Unsub()
		var out []nostr.Event
		for {
			select {
			case ev := <-sub.Events:
				out = append(out, ev)
			case <-sub.EndOfStoredEvents:
				return out, nil
			case <-pc.Done():
				return nil, pc.Err()
			}
		}
	}

	since := now - nostr.Timestamp(total*97+3600)
	first, err := page(ctx, since, 0, 100)
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("first answer: %d events", len(first))
	got := map[nostr.ID]bool{}
	var oldest nostr.Timestamp
	for _, e := range first {
		got[e.ID] = true
		if oldest == 0 || e.CreatedAt < oldest {
			oldest = e.CreatedAt
		}
	}
	if len(first) >= total {
		t.Fatalf("the relay has no cap to test against: %d", len(first))
	}
	res := Back(ctx, page, since, oldest, 100, 200, func(e nostr.Event) bool {
		if got[e.ID] {
			return false
		}
		got[e.ID] = true
		return true
	})
	t.Logf("paged: %+v", res)
	missing := 0
	for id := range sent {
		if !got[id] {
			missing++
		}
	}
	if !res.Complete || missing != 0 {
		t.Fatalf("complete=%v missing=%d of %d", res.Complete, missing, total)
	}
}
