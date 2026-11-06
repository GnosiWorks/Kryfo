package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/fiatjaf/khatru"
)

func main() {
	relay := khatru.NewRelay()
	relay.Info.Name = "kryfo relay"
	relay.Info.Description = "private relay for kryfo messenger"
	relay.Info.Software = "khatru"

	db, err := openStore("./data/halo.sqlite")
	if err != nil {
		panic(err)
	}

	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	relay.CountEvents = append(relay.CountEvents, db.CountEvents)
	relay.DeleteEvent = append(relay.DeleteEvent, db.DeleteEvent)

	l := applyLimits(relay, "./data")
	if _, err := startKnocks(relay, l, "./data"); err != nil {
		panic(err)
	}

	addr := "127.0.0.1:3334"
	if v := os.Getenv("RELAY_ADDR"); v != "" {
		addr = v
	}
	startSweeper(db)
	startCheckpoints(db)
	db.startFill()

	onion, what, err := onionServer(relay)
	if err != nil {
		panic(err)
	}
	if onion != nil {
		fmt.Println("kryfo relay onion listener on", onion.Addr+",", what)
		go func() { log.Fatal(onion.ListenAndServe()) }()
	}

	fmt.Println("kryfo relay listening on", addr)
	log.Fatal(relayServer(addr, relay).ListenAndServe())
}

// both listeners: headers come within headerWait and a kept-alive
// connection idles idleWait at most, so slow or idle streams over tor are
// closed. after a websocket upgrade only the socket's own deadlines count
var (
	headerWait = 30 * time.Second
	idleWait   = 2 * time.Minute
)

func relayServer(addr string, h http.Handler) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           h,
		WriteTimeout:      writeWait,
		ReadHeaderTimeout: headerWait,
		IdleTimeout:       idleWait,
		// net/http's own lines (a handler's panic, a bad request) name the
		// peer: they go nowhere, like the other services'
		ErrorLog: log.New(io.Discard, "", 0),
	}
}
