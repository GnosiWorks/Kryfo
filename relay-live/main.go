package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/fiatjaf/eventstore/sqlite3"
	"github.com/fiatjaf/khatru"
)

func main() {
	relay := khatru.NewRelay()
	relay.Info.Name = "halo relay"
	relay.Info.Description = "private relay for halo messenger"
	relay.Info.Software = "khatru"

	db := sqlite3.SQLite3Backend{DatabaseURL: "./data/halo.sqlite"}
	if err := db.Init(); err != nil {
		panic(err)
	}

	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	relay.CountEvents = append(relay.CountEvents, db.CountEvents)
	relay.DeleteEvent = append(relay.DeleteEvent, db.DeleteEvent)

	// keep it minimal + working first. size/kind policies come in a later
	// pass once we confirm the relay runs and halo talks to it.

	addr := "127.0.0.1:3334"
	if v := os.Getenv("RELAY_ADDR"); v != "" {
		addr = v
	}
	startSweeper(&db)

	fmt.Println("halo relay listening on", addr)
	log.Fatal(http.ListenAndServe(addr, relay))
}
