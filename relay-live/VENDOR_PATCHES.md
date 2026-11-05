# Patched dependencies

## khatru: a fork, not a hand patch

khatru lives in `third_party/khatru` and go.mod points at it with a
`replace`. it holds upstream v0.19.1's files for the root package, tests
left out, and upstream's go.mod. five files differ, the new lines marked
`kryfo`:

- `listener.go`: `notifyListeners` puts a new event in each listener's
  queue and returns. upstream writes it to every listener's socket before
  the sender gets its ok, with no deadline, so one slow listener held up
  every sender to its address. the listeners are read under
  `clientsMutex`, which upstream skips, as a reader so publishers do not
  wait for each other. a listener that goes is cleared from the list's
  array: upstream only shortens the list, and the slot past its end keeps
  the closed connection and its buffers until a new listener takes it.
- `websocket.go`: every write gets `Relay.WriteWait` (upstream's field, set
  to 10s and never used), and a write that fails closes the connection.
  each connection has a queue for new events, written by a goroutine that
  runs while the queue holds something. a queued event counts what it
  holds in memory: content with room for the allocator's rounding, about
  100 bytes per tag and 16 per string. a listener past its own bound, or
  one whose event would take all queues together past theirs, is closed:
  it reconnects and reads the rest from the store. `closeAfter` is the
  page deadline below, `Relay.Queued` the bytes queued now.
- `websocket.go`: `hold` and `release` keep a subscription's live events
  back until its eose is written. upstream writes them among its stored
  events, where a reader takes one for a stored event, and a wrap is
  stamped up to two days back, so a catch-up judged by its stamp would step
  over stored wraps it never got. held events count toward the bounds like
  queued ones.
- `websocket.go`: `Close` ends a connection for the relay's own bounds
  (pages.go closes the oldest pages' sockets when the page budget is full).
- `responding.go`: a page of stored events gets `Relay.PageWait` in all,
  then the connection is closed with no eose. each write has its own
  deadline, so a reader taking a frame just inside it could keep the page,
  and what it holds in memory, for 100 of them. the overwrite and reject
  hooks run in `checkRequest`, apart from the query.
- `handlers.go`: each connection keeps its relay, for the bounds. a
  request holds its live events from before its listeners are added until
  its eose is written, or until it is refused. a filter is checked, then
  its listener added, then its stored events read: upstream adds the
  listener after the read, so an event saved during the read reached
  neither. a refused filter gets no listener, and the request's earlier
  ones are removed. an unexpected close is logged without the caller's
  address (upstream logs X-Forwarded-For or the remote address).
- `relay.go`: `MaxQueuedSize` (8 MB unless set), `MaxQueuedTotal` and
  `PageWait` (no bound unless set), `clientsMutex` as a read-write lock,
  and a deadline on the handshake answer.

the change against upstream:

    go mod download github.com/fiatjaf/khatru@v0.19.1
    up="$(go env GOMODCACHE)/github.com/fiatjaf/khatru@v0.19.1"
    for f in handlers.go listener.go relay.go responding.go websocket.go; do
        diff -u "$up/$f" "third_party/khatru/$f"
    done

to move to a newer upstream: save that diff as a patch, copy the new
version's go.mod and the non-test files of its root over
`third_party/khatru`, apply the patch and put the new version in go.mod's
require. if the new go.mod moves any dependency, go.sum needs its sums.
