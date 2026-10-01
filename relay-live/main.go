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
	startCheckpoints(db)

	fmt.Println("halo relay listening on", addr)
	srv := &http.Server{Addr: addr, Handler: relay, WriteTimeout: writeWait}
	log.Fatal(srv.ListenAndServe())
}
