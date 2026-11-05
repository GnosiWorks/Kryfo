package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

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

	onion, what, err := onionServer(relay)
	if err != nil {
		panic(err)
	}
	if onion != nil {
		fmt.Println("kryfo relay onion listener on", onion.Addr+",", what)
		go func() { log.Fatal(onion.ListenAndServe()) }()
	}

	fmt.Println("kryfo relay listening on", addr)
	srv := &http.Server{Addr: addr, Handler: relay, WriteTimeout: writeWait}
	log.Fatal(srv.ListenAndServe())
}
