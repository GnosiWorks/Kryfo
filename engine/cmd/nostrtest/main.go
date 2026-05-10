package main

import (
"context"
"fmt"
"time"

"fiatjaf.com/nostr"
)

func main() {
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()

sk := nostr.Generate()
pk := sk.Public()
fmt.Println("ephemeral pubkey:", pk.Hex())

relayURL := "wss://relay.damus.io"
fmt.Println("connecting to", relayURL, "...")
relay, err := nostr.RelayConnect(ctx, relayURL, nostr.RelayOptions{})
if err != nil {
fmt.Println("connect err:", err)
return
}
defer relay.Close()
fmt.Println("connected ✓")

ev := nostr.Event{
PubKey:    pk,
CreatedAt: nostr.Now(),
Kind:      30078,
Tags:      nostr.Tags{{"d", "halo-probe"}},
Content:   "halo nostr probe roundtrip " + fmt.Sprint(time.Now().Unix()),
}
ev.Sign(sk)
fmt.Println("event id:", ev.ID.Hex())

if err := relay.Publish(ctx, ev); err != nil {
fmt.Println("publish err:", err)
return
}
fmt.Println("published ✓")

time.Sleep(2 * time.Second)

filter := nostr.Filter{
Authors: []nostr.PubKey{pk},
Kinds:   []nostr.Kind{30078},
Limit:   5,
}

fmt.Println("subscribing to read it back...")
sub, err := relay.Subscribe(ctx, filter, nostr.SubscriptionOptions{})
if err != nil {
fmt.Println("subscribe err:", err)
return
}

select {
case event := <-sub.Events:
fmt.Println("got back:", event.Content)
fmt.Println("ROUNDTRIP OK ✓✓✓")
case <-time.After(15 * time.Second):
fmt.Println("timeout waiting for event")
}
}
