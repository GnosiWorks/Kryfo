# Relays

two directories look like relays. only one runs.

## `relay-live/`: production

khatru and sqlite, listening on `127.0.0.1:3334` behind nginx at
`relay.kryfo.app`. no auth. gift wraps are deleted after 14 days
(`retention.go`).

`limits.go` keeps it to what the app does: gift wraps with one address and at
most 8 tags of 4 values, messages up to 256 kB, stamped at most 2 hours ahead,
reads by address or by id only (a filter without an address would dump
everyone's post box), limit 0 reads included. every event and every read is
paced per connection, refused or not. sockets (`RELAY_MAX_CONNS`, 20000) and
stored bytes (`RELAY_MAX_MB_PER_MIN`, 240 MB a minute, four minutes of it at
once) are capped for everyone together, and wraps stop being taken below 2 GB
of free disk, read every 30 s and again after every 32 MB taken. nothing is
counted per ip: behind tor every caller looks the same. kind 5 deletion
requests are refused before they reach the store: wraps go when they expire.
there is no delete on delivery: watching deliveries means wrapping khatru's
query channel, and that can stall every subscription.

a sender gets its ok once the wrap is stored. listeners get it from a queue
per connection, so a slow one holds up no one. queues count what their
wraps hold in memory. a listener more than 8 MB behind, one that takes
over 10 s to take a frame, or one whose next wrap would take all queues
together past 256 MB (`RELAY_MAX_QUEUED_MB`), is closed and reads the rest
from the store when it comes back. a page of stored wraps gets 2 minutes
in all, since the store's read stays open while it is written. khatru is a
fork for this, see `relay-live/VENDOR_PATCHES.md`.

the store runs in wal mode, so `data/` holds `halo.sqlite`,
`halo.sqlite-wal` and `halo.sqlite-shm`. copy all three, or stop the relay
first.

it needs cgo (`go-sqlite3`). with `CGO_ENABLED=0` it builds and then panics at
start.

### two of them

the same `relay-live` runs on a second box at another hosting company,
`relay2.kryfo.app`, with a store of its own. the boxes never copy from each
other: a feed of every wrap between them is what `limits.go` refuses anyone.
the app's fast route writes to both and reads both. the first ok ends a send,
the first copy is the one shown, and a wrap one store missed waits on the
phone, sealed, and goes to that store once it answers, for up to 14 days: the
same wrap within a few minutes, after that a fresh wrap around the same seal,
so a reader whose window moved on still asks for it (`engine/topup.go`,
`engine/rewrap.go`). a send the first store missed also goes to the public
relays through tor at once, as a private sender's does. each store keeps its
own catch-up anchor per address (`engine/stores.go`), so a back-dated wrap only
one of them holds is never stepped over because the other moved on. while the
first store is down the fast route also reads the public relays, through tor
only. a relay is ours by its name alone, and one that is not ours is never
dialled in the clear on the fast route. the private route lists both stores
too, each through its own onion (the first also through its clearnet name over
tor), with its own anchor per store, writes every wrap to both and to the
public relays, and queues nothing.

## `dmrelay/`: next, not deployable yet

badger instead of sqlite, expiration checks, a kind allow-list, and nip-42
gated reads, so you only get wraps for an address you proved you own. the
engine doesn't speak nip-42 yet: subscriptions fail to authenticate while
publishes still succeed, so messages look sent and never arrive. teach the
engine nip-42 first, then test on a spare box.

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
