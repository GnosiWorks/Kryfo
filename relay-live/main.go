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

	db, err := openStore("./data/halo.sqlite")
	if err != nil {
		panic(err)
	}

	relay.StoreEvent = append(relay.StoreEvent, db.SaveEvent)
	relay.QueryEvents = append(relay.QueryEvents, db.QueryEvents)
	relay.CountEvents = append(relay.CountEvents, db.CountEvents)
	relay.DeleteEvent = append(relay.DeleteEvent, db.DeleteEvent)

	applyLimits(relay, "./data")

	addr := "127.0.0.1:3334"
	if v := os.Getenv("RELAY_ADDR"); v != "" {
		addr = v
	}
	startSweeper(db)

	fmt.Println("halo relay listening on", addr)
	log.Fatal(http.ListenAndServe(addr, relay))
}

// the store as the relay runs it, its page size left at the backend's own
func openStore(path string) (*sqlite3.SQLite3Backend, error) {
	db := &sqlite3.SQLite3Backend{DatabaseURL: path}
	return db, db.Init()
}
