// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"context"
	"log"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/fiatjaf/eventstore/slicestore"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

func wrapTagged(tags ...nostr.Tag) *nostr.Event {
	return &nostr.Event{Kind: 1059, CreatedAt: nostr.Now(), Tags: tags}
}

func refusedSafely(t *testing.T, name string, ev *nostr.Event) {
	t.Helper()
	defer func() {
		if recover() != nil {
			t.Errorf("%s panicked", name)
		}
	}()
	if bad, _ := rejectEvent(context.Background(), ev); !bad {
		t.Errorf("%s was taken", name)
	}
}

func TestOddExpirationsAreRefused(t *testing.T) {
	p := nostr.Tag{"p", "aa"}
	past := strconv.FormatInt(time.Now().Add(-time.Minute).Unix(), 10)
	now := strconv.FormatInt(time.Now().Unix(), 10)
	for name, exp := range map[string]nostr.Tag{
		"a bare expiration":    {"expiration"},
		"an empty expiration":  {"expiration", ""},
		"a word":               {"expiration", "abc"},
		"a negative":           {"expiration", "-5"},
		"an overflow":          {"expiration", "99999999999999999999"},
		"the largest int64":    {"expiration", "9223372036854775807"},
		"the smallest int64":   {"expiration", "-9223372036854775808"},
		"a fraction":           {"expiration", "1.5"},
		"a past second":        {"expiration", past},
		"this second":          {"expiration", now},
		"an empty tag":         {},
		"no expiration at all": {"x", "y"},
		"a spaced number":      {"expiration", " 1900000000"},
	} {
		refusedSafely(t, name, wrapTagged(p, exp))
	}
}

func TestOddPTagsAreRefused(t *testing.T) {
	exp := nostr.Tag{"expiration", strconv.FormatInt(time.Now().Add(wrapTTL).Unix(), 10)}
	for name, tags := range map[string]nostr.Tags{
		"a bare p":     {{"p"}, exp},
		"no p":         {exp},
		"an empty tag": {{}, exp},
		"no tags":      {},
	} {
		refusedSafely(t, name, wrapTagged(tags...))
	}
}

func TestOddFiltersAreRefused(t *testing.T) {
	for name, f := range map[string]nostr.Filter{
		"no kinds":     {},
		"an empty p":   {Kinds: []int{1059}, Tags: nostr.TagMap{"p": {}}},
		"no p":         {Kinds: []int{1059}},
		"a nil p list": {Kinds: []int{1059}, Tags: nostr.TagMap{"p": nil}},
	} {
		func() {
			defer func() {
				if recover() != nil {
					t.Errorf("%s panicked", name)
				}
			}()
			if bad, _ := rejectFilter(context.Background(), f); !bad {
				t.Errorf("%s was served", name)
			}
		}()
	}
}

func TestSweepSkipsOddExpirations(t *testing.T) {
	for _, tag := range []nostr.Tag{{"expiration"}, {"expiration", ""}, {"expiration", "abc"}, {"expiration", "99999999999999999999"}} {
		func() {
			defer func() {
				if recover() != nil {
					t.Errorf("%v panicked", tag)
				}
			}()
			if _, ok := expiredAt(wrapTagged(tag)); ok {
				t.Errorf("%v read as an expiration", tag)
			}
		}()
	}
}

// a hook that panics refuses the event, logs its name and nothing else, and
// the relay goes on serving
func TestAPanickingHookRefusesAndTheRelayServes(t *testing.T) {
	var logged bytes.Buffer
	log.SetOutput(&logged)
	t.Cleanup(func() { log.SetOutput(os.Stderr) })

	relay := khatru.NewRelay()
	db := &slicestore.SliceStore{}
	if err := db.Init(); err != nil {
		t.Fatal(err)
	}
	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	relay.RejectEvent = append(relay.RejectEvent, func(_ context.Context, ev *nostr.Event) (bool, string) {
		if ev.Tags.Find("boom") != nil {
			var none []string
			_ = none[1]
		}
		return false, ""
	}, rejectEvent)
	relay.RejectFilter = append(relay.RejectFilter, rejectFilter)
	guardHooks(relay)
	srv := httptest.NewServer(relay)
	t.Cleanup(srv.Close)
	url := "ws" + strings.TrimPrefix(srv.URL, "http")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	r, err := nostr.RelayConnect(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	sign := func(extra ...nostr.Tag) nostr.Event {
		ev := *wrapExpiring(time.Now().Add(wrapTTL))
		ev.Tags = append(ev.Tags, extra...)
		if err := ev.Sign(nostr.GeneratePrivateKey()); err != nil {
			t.Fatal(err)
		}
		return ev
	}
	bad := sign(nostr.Tag{"boom", "secret-content"})
	if err := r.Publish(ctx, bad); err == nil || !strings.Contains(err.Error(), "could not check") {
		t.Fatalf("the event a hook panicked on: %v", err)
	}
	if err := r.Publish(ctx, sign()); err != nil {
		t.Fatalf("a good wrap after the panic was refused: %v", err)
	}
	// a fresh connection still gets in
	r2, err := nostr.RelayConnect(ctx, url)
	if err != nil {
		t.Fatalf("no connection after the panic: %v", err)
	}
	if err := r2.Publish(ctx, sign()); err != nil {
		t.Fatalf("a second connection's wrap was refused: %v", err)
	}
	out := logged.String()
	if !strings.Contains(out, "panic in RejectEvent") {
		t.Errorf("no panic line in the log: %q", out)
	}
	for _, leak := range []string{"secret-content", bad.ID, "127.0.0.1", "index out of range"} {
		if strings.Contains(out, leak) {
			t.Errorf("the log holds %q", leak)
		}
	}
}
