# relays

three directories here look like relays. only one of them runs.

## `relay-live/` — this is production

khatru + sqlite, about forty lines, listening on `127.0.0.1:3334` behind
nginx at `relay.kryfo.app`. no auth, no kind policy, no size limit: it takes
what it is given and hands it back to whoever asks.

it holds gift wraps for **14 days** and then deletes them (`retention.go`).
that is the whole retention story - there is no delete-on-delivery, because
noticing deliveries means wrapping the store's query channel, and when khatru
stops draining early the store never closes its cursor and every subscription
stalls. time alone is enough to stop being an archive and it cannot deadlock.

**built with cgo.** `go-sqlite3` is a cgo package; `CGO_ENABLED=0` compiles
fine and then panics at startup with a stub driver. build it:

    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -trimpath -o halo-relay .

this source lived only on the server until aug 25. it is here now.

## `dmrelay/` — the next one, NOT deployable yet

badger instead of sqlite, expiration validation, kind allow-list, and
**nip-42 gated reads**: you only receive wraps for an address you have proved
you own, which stops anyone hoovering the whole wrap firehose.

that last part is why it cannot be dropped in. the engine does not speak
nip-42, so subscriptions connect, fail to authenticate, and die - publishes
keep succeeding, so it looks like messages send and never arrive. this
happened four times in one day before anyone noticed the two binaries print
different startup lines.

**before deploying it:** teach the engine nip-42 auth, then test against it on
a spare box, not production.

## `relay/` — dead

the original store-and-forward over a bespoke websocket protocol, from before
the move to nostr. kept for reference only. nothing talks to it.

---

## deploying

    cd relay-live
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -trimpath -o halo-relay .
    scp halo-relay ubuntu@57.129.122.187:/tmp/

then on the box:

    sudo systemctl stop halo-relay
    sudo cp /opt/halo-relay/halo-relay /opt/halo-relay/halo-relay.bak
    sudo mv /tmp/halo-relay /opt/halo-relay/
    sudo chmod +x /opt/halo-relay/halo-relay
    sudo systemctl restart halo-relay

**check the startup line before believing it worked:**

    sudo journalctl -u halo-relay -n 3 --no-pager

`halo relay listening on 127.0.0.1:3334` is production. anything else is the
wrong binary.

### the socat bridge

the relay binds `127.0.0.1`, so docker cannot reach it. `halo-relay-bridge`
forwards `172.18.0.1:3335` to it, and nginx proxies to that.

it used to be `Requires=halo-relay.service`, which stops the bridge with the
relay but does **not** bring it back on a fresh `start` - so every deploy
silently killed messaging until someone restarted it by hand. it is `PartOf=`
now, and the rule is **always `systemctl restart`, never stop-then-start**.

the same trap applies to `kryfo-handles-bridge`.
