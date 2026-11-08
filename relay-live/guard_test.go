package main

import (
	"bytes"
	"context"
	"log"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/fiatjaf/eventstore/slicestore"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

// the tag shapes a sender can write that a careless index would fall over
var oddTags = map[string]nostr.Tag{
	"an empty tag":          {},
	"a bare p":              {"p"},
	"an empty p":            {"p", ""},
	"a short p":             {"p", "zz"},
	"a bare expiration":     {"expiration"},
	"an empty expiration":   {"expiration", ""},
	"a word expiration":     {"expiration", "abc"},
	"a negative expiration": {"expiration", "-5"},
	"a huge expiration":     {"expiration", "99999999999999999999"},
	"the largest int64":     {"expiration", "9223372036854775807"},
	"a past expiration":     {"expiration", "1000"},
}

// a wrap with only an odd tag is refused, one with an odd tag beside its
// own address is not looked at further, and the relay keeps going
func TestOddTagsDoNotStopTheRelay(t *testing.T) {
	url, tk := testKnockRelay(t)
	r := connect(t, url)
	for name, tag := range oddTags {
		if err := publish(t, r, wrap(t, addr(), func(e *nostr.Event) { e.Tags = nostr.Tags{tag} })); err == nil {
			t.Errorf("a wrap with only %s was taken", name)
		}
		if tag.Key() == "p" {
			if err := publish(t, r, wrap(t, addr(), func(e *nostr.Event) { e.Tags = append(e.Tags, tag) })); err == nil {
				t.Errorf("a wrap with %s beside its address was taken", name)
			}
			continue
		}
		_ = publish(t, r, wrap(t, addr(), func(e *nostr.Event) { e.Tags = append(e.Tags, tag) }))
	}
	// the saved hook reads the p tags too
	for _, tag := range oddTags {
		ev := wrap(t, addr(), func(e *nostr.Event) { e.Tags = append(e.Tags, tag) })
		tk.stored(&ev)
	}
	to := addr()
	if err := publish(t, r, wrap(t, to, nil)); err != nil {
		t.Fatalf("a good wrap after the odd ones was refused: %v", err)
	}
}

func panicRelay(t *testing.T) (string, *bytes.Buffer) {
	t.Helper()
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
	explode := func(tags nostr.Tags) {
		if tags.Find("boom") != nil {
			var none []string
			_ = none[1]
		}
	}
	relay.RejectEvent = append(relay.RejectEvent, func(_ context.Context, ev *nostr.Event) (bool, string) {
		explode(ev.Tags)
		return false, ""
	})
	relay.OnEventSaved = append(relay.OnEventSaved, func(_ context.Context, ev *nostr.Event) {
		if ev.Tags.Find("late") != nil {
			panic("late")
		}
	})
	relay.RejectFilter = append(relay.RejectFilter, func(_ context.Context, f nostr.Filter) (bool, string) {
		if f.Search == "boom" {
			panic("boom")
		}
		return false, ""
	})
	// ahead of the limits, so they are reached
	applyLimits(relay, "")
	guardHooks(relay)
	srv := httptest.NewServer(relay)
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http"), &logged
}

// a hook that panics refuses what it was given, logs its name and nothing
// else, and the relay goes on serving
func TestAPanickingHookRefusesAndTheRelayServes(t *testing.T) {
	url, logged := panicRelay(t)
	r := connect(t, url)
	to := addr()
	bad := wrap(t, to, func(e *nostr.Event) { e.Tags = append(e.Tags, nostr.Tag{"boom", "secret-content"}) })
	err := publish(t, r, bad)
	if err == nil || !strings.Contains(err.Error(), "could not check") {
		t.Fatalf("the event a hook panicked on: %v", err)
	}
	late := wrap(t, to, func(e *nostr.Event) { e.Tags = append(e.Tags, nostr.Tag{"late", "x"}) })
	if err := publish(t, r, late); err != nil {
		t.Fatalf("a panic after the save failed the save: %v", err)
	}
	if _, why := ask(t, r, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}, Search: "boom"}); why == "" {
		t.Error("the filter a hook panicked on was served")
	}
	good := wrap(t, to, nil)
	if err := publish(t, r, good); err != nil {
		t.Fatalf("a good wrap after the panics was refused: %v", err)
	}
	// a second connection still gets in
	r2 := connect(t, url)
	got, why := ask(t, r2, nostr.Filter{Kinds: []int{wrapKind}, Tags: nostr.TagMap{"p": {to}}})
	if why != "" || len(got) != 2 {
		t.Fatalf("after the panics: %d wraps, closed %q", len(got), why)
	}
	time.Sleep(50 * time.Millisecond)
	out := logged.String()
	for _, hook := range []string{"panic in RejectEvent", "panic in OnEventSaved", "panic in RejectFilter"} {
		if !strings.Contains(out, hook) {
			t.Errorf("no %q in the log", hook)
		}
	}
	for _, leak := range []string{"secret-content", to, bad.ID, "127.0.0.1", "index out of range"} {
		if strings.Contains(out, leak) {
			t.Errorf("the log holds %q", leak)
		}
	}
}
