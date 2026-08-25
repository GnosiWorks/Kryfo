package main

// halo dm relay. stores nip-17 gift wraps (kind 1059) and per-conversation
// relay lists (kind 10050), nothing else.
//
// writes are open: senders wrap with throwaway keys and cannot auth as the
// recipient, that is the whole point of the gift wrap.
// reads on 1059 are nip-42 gated: you only get wraps for an address you
// proved you own. stops bulk scraping of the wrap firehose.
// 10050 reads stay open, they exist to be discovered.

import (
	"crypto/tls"
	"flag"
	"log"
	"net/http"
	"context"
	"strconv"
	"time"

	"github.com/fiatjaf/eventstore/badger"
	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
	
)

var (
	addr     = flag.String("addr", ":8443", "listen address")
	certFile = flag.String("cert", "", "TLS cert file (plain ws if empty, dev only)")
	keyFile  = flag.String("key", "", "TLS key file")
	dataDir  = flag.String("data", "./dmrelay-data", "badger data dir")
)

const (
	maxContentBytes = 128 * 1024
	// we sweep at 14 days, so a longer expiration would be a promise we do
	// not keep. the extra day absorbs clock skew - a phone an hour fast
	// should not have its mail refused.
	// we sweep at 14 days; the extra day absorbs clock skew so a phone an
	// hour fast does not have its mail refused.
	maxExpiry       = wrapTTL + 24*time.Hour
	maxFutureSkew   = 15 * time.Minute
	// wraps jitter created_at into the past, spec allows up to 2 days
	maxPastSkew = 3 * 24 * time.Hour
)

func rejectEvent(ctx context.Context, ev *nostr.Event) (bool, string) {
	switch ev.Kind {
	case 1059:
		if len(ev.Content) > maxContentBytes {
			return true, "invalid: content too large"
		}
		now := time.Now()
		at := ev.CreatedAt.Time()
		if at.After(now.Add(maxFutureSkew)) {
			return true, "invalid: created_at too far in the future"
		}
		if at.Before(now.Add(-maxPastSkew)) {
			return true, "invalid: created_at too old"
		}
		if ev.Tags.Find("p") == nil {
			return true, "invalid: missing p tag"
		}
		exp := ev.Tags.Find("expiration")
		if exp == nil {
			return true, "invalid: missing expiration tag"
		}
		sec, err := strconv.ParseInt(exp[1], 10, 64)
		if err != nil || time.Unix(sec, 0).After(now.Add(maxExpiry)) {
			return true, "invalid: bad expiration"
		}
		return false, ""
	case 10050:
		if len(ev.Content) > 4096 {
			return true, "invalid: content too large"
		}
		return false, ""
	}
	return true, "blocked: kind not accepted here"
}

// a 1059 query must be authed and may only ask for the authed address.
// no kind filter counts as touching 1059.
func rejectFilter(ctx context.Context, f nostr.Filter) (bool, string) {
	touches1059 := len(f.Kinds) == 0
	only10050 := len(f.Kinds) > 0
	for _, k := range f.Kinds {
		if k == 1059 {
			touches1059 = true
		}
		if k != 10050 {
			only10050 = false
		}
	}
	if only10050 {
		return false, ""
	}
	if !touches1059 {
		return true, "blocked: kind not served here"
	}

	authed := khatru.GetAuthed(ctx)
	if authed == "" {
		return true, "auth-required: gift wraps are only served to their owner"
	}
	ps, ok := f.Tags["p"]
	if !ok || len(ps) == 0 {
		return true, "restricted: query must filter on your own p tag"
	}
	for _, p := range ps {
		if p != authed {
			return true, "restricted: can only query your own address"
		}
	}
	return false, ""
}

func main() {
	flag.Parse()

	db := badger.BadgerBackend{Path: *dataDir}
	if err := db.Init(); err != nil {
		log.Fatalf("badger init: %v", err)
	}

	relay := khatru.NewRelay()
	relay.Info.Name = "halo dm relay"
	relay.Info.Description = "nip-17 gift wrap store, auth-gated reads"

	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	relay.DeleteEvent = append(relay.DeleteEvent, db.DeleteEvent)
	relay.ReplaceEvent = append(relay.ReplaceEvent, db.ReplaceEvent)
	relay.CountEvents = append(relay.CountEvents, db.CountEvents)

	relay.RejectEvent = append(relay.RejectEvent, rejectEvent)
	relay.RejectFilter = append(relay.RejectFilter, rejectFilter)

	// a wrap that has been collected, or that nobody came for, does not stay
	startSweeper(&db)

	relay.Router().HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })

	srv := &http.Server{Addr: *addr, Handler: relay}
	if *certFile != "" && *keyFile != "" {
		srv.TLSConfig = &tls.Config{MinVersion: tls.VersionTLS12}
		log.Printf("halo dm relay (wss) on %s", *addr)
		log.Fatal(srv.ListenAndServeTLS(*certFile, *keyFile))
	}
	log.Printf("halo dm relay (ws, NO TLS, dev only) on %s", *addr)
	log.Fatal(srv.ListenAndServe())
}
