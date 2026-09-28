# relays

three directories look like relays. only one runs.

## `relay-live/`: production

khatru and sqlite, listening on `127.0.0.1:3334` behind nginx at
`relay.kryfo.app`. no auth. gift wraps are deleted after 14 days
(`retention.go`).

`limits.go` keeps it to what the app does: gift wraps with one address,
messages up to 256 kB, stamped at most 2 hours ahead, reads by address or by
id only (a filter without an address would dump everyone's post box). events and reads are paced per
connection, sockets are capped for everyone together (`RELAY_MAX_CONNS`,
20000), and wraps stop being taken below 2 GB of free disk. nothing is
counted per ip: behind tor every caller looks the same. there is no delete on delivery:
watching deliveries means wrapping khatru's query channel, and that can stall
every subscription.

it needs cgo (`go-sqlite3`). with `CGO_ENABLED=0` it builds and then panics at
start.

## `dmrelay/`: next, not deployable yet

badger instead of sqlite, expiration checks, a kind allow-list, and nip-42
gated reads, so you only get wraps for an address you proved you own. the
engine doesn't speak nip-42 yet: subscriptions fail to authenticate while
publishes still succeed, so messages look sent and never arrive. teach the
engine nip-42 first, then test on a spare box.

## `relay/`: dead

the old store-and-forward protocol from before nostr. nothing uses it.

## deploying relay-live

    cd relay-live
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -trimpath -o halo-relay .
    scp halo-relay ubuntu@relay.kryfo.app:/tmp/

on the box:

    sudo cp /opt/halo-relay/halo-relay /opt/halo-relay/halo-relay.bak
    sudo install -m 0755 /tmp/halo-relay /opt/halo-relay/halo-relay
    sudo systemctl restart halo-relay
    sudo journalctl -u halo-relay -n 3 --no-pager

the last line must say `halo relay listening on 127.0.0.1:3334`, anything
else is the wrong binary.

the relay binds 127.0.0.1, so `halo-relay-bridge` (socat) forwards
`172.18.0.1:3335` to it for nginx in docker. the bridge is `PartOf=` the
relay: always `systemctl restart`, never stop then start, or the bridge stays
down. same for `kryfo-handles-bridge`.
