package khatru

import (
	"context"
	"net/http"
	"sync"
	"time"

	"github.com/fasthttp/websocket"
	"github.com/nbd-wtf/go-nostr"
	"github.com/puzpuzpuz/xsync/v3"
)

type WebSocket struct {
	conn  *websocket.Conn
	mutex sync.Mutex

	// original request
	Request *http.Request

	// this Context will be canceled whenever the connection is closed from the client side or server-side.
	Context context.Context
	cancel  context.CancelFunc

	// nip42
	Challenge       string
	AuthedPublicKey string
	Authed          chan struct{}

	// nip77
	negentropySessions *xsync.MapOf[string, *NegentropySession]

	authLock sync.Mutex

	// kryfo: the relay, for its write wait and queue bounds
	rl *Relay

	// kryfo: live events waiting for this connection, and their size
	queueMutex sync.Mutex
	queue      []queuedEvent
	queued     int64
	draining   bool
	closed     bool
	// kryfo: live events held back from subscriptions whose stored events
	// are still going out, by subscription id. under queueMutex
	held map[string]*heldEvents
}

// kryfo: n counts the requests under one id still sending stored events
type heldEvents struct {
	n      int
	events []queuedEvent
}

type queuedEvent struct {
	id    string
	event *nostr.Event
	size  int64
}

func (ws *WebSocket) WriteJSON(any any) error {
	ws.mutex.Lock()
	ws.setWriteDeadline() // kryfo
	err := ws.conn.WriteJSON(any)
	ws.mutex.Unlock()
	if err != nil {
		// kryfo: a failed write breaks the connection for good, so end it now
		ws.conn.Close()
	}
	return err
}

func (ws *WebSocket) WriteMessage(t int, b []byte) error {
	ws.mutex.Lock()
	ws.setWriteDeadline() // kryfo
	err := ws.conn.WriteMessage(t, b)
	ws.mutex.Unlock()
	if err != nil {
		ws.conn.Close() // kryfo
	}
	return err
}

// kryfo: no write waits forever on a client that stopped reading
func (ws *WebSocket) setWriteDeadline() {
	if ws.rl.WriteWait > 0 {
		ws.conn.SetWriteDeadline(time.Now().Add(ws.rl.WriteWait))
	}
}

// kryfo: closes the connection after d unless the returned func runs first.
// zero never closes
func (ws *WebSocket) closeAfter(d time.Duration) func() {
	if d <= 0 {
		return func() {}
	}
	t := time.AfterFunc(d, func() { ws.conn.Close() })
	return func() { t.Stop() }
}

// kryfo: what a queued event holds in memory, counted high for any shape: a
// parsed tag costs about 100 bytes and a string 16 beside its bytes, and
// large content is rounded up to 8 kB
func queuedSize(event *nostr.Event) int64 {
	size := int64(512 + len(event.Content) + len(event.Content)/4)
	for _, tag := range event.Tags {
		size += 128
		for _, s := range tag {
			size += int64(32 + len(s))
		}
	}
	return size
}

// kryfo: queues a live event and returns at once, so a slow listener never
// holds up the publisher. one that falls MaxQueuedSize behind, or would take
// the relay's queues past MaxQueuedTotal, is closed, and it reads what it
// missed from the store when it comes back.
func (ws *WebSocket) push(id string, event *nostr.Event) {
	size := queuedSize(event)

	ws.queueMutex.Lock()
	defer ws.queueMutex.Unlock()
	if ws.closed {
		return
	}
	rl := ws.rl
	total := rl.queuedTotal.Add(size)
	if (rl.MaxQueuedSize > 0 && ws.queued+size > rl.MaxQueuedSize) ||
		(rl.MaxQueuedTotal > 0 && total > rl.MaxQueuedTotal) {
		rl.queuedTotal.Add(-size)
		ws.dropQueue()
		ws.conn.Close()
		return
	}
	ws.queued += size
	if h := ws.held[id]; h != nil {
		h.events = append(h.events, queuedEvent{id, event, size})
		return
	}
	ws.queue = append(ws.queue, queuedEvent{id, event, size})
	ws.startDrain()
}

// kryfo: with queueMutex held
func (ws *WebSocket) startDrain() {
	if !ws.draining {
		ws.draining = true
		go ws.drain()
	}
}

// kryfo: live events for the subscription id wait until release, so none
// goes out among its stored events, where a reader would take it for one
// and could judge the page by it
func (ws *WebSocket) hold(id string) {
	ws.queueMutex.Lock()
	defer ws.queueMutex.Unlock()
	if ws.closed {
		return
	}
	if ws.held == nil {
		ws.held = map[string]*heldEvents{}
	}
	h := ws.held[id]
	if h == nil {
		h = &heldEvents{}
		ws.held[id] = h
	}
	h.n++
}

// kryfo: the request's eose is written, or it was refused: what was held
// for it goes out now, behind it
func (ws *WebSocket) release(id string) {
	ws.queueMutex.Lock()
	defer ws.queueMutex.Unlock()
	h := ws.held[id]
	if h == nil {
		return
	}
	if h.n--; h.n > 0 {
		return
	}
	delete(ws.held, id)
	if len(h.events) > 0 {
		ws.queue = append(ws.queue, h.events...)
		ws.startDrain()
	}
}

// kryfo: bytes of live events waiting for all connections
func (rl *Relay) Queued() int64 { return rl.queuedTotal.Load() }

// kryfo: ends the queue for good, with queueMutex held. the event being
// written now is let go by drain
func (ws *WebSocket) dropQueue() {
	ws.closed = true
	var n int64
	for _, q := range ws.queue {
		n += q.size
	}
	for _, h := range ws.held {
		for _, q := range h.events {
			n += q.size
		}
	}
	ws.queue = nil
	ws.held = nil
	ws.queued -= n
	ws.rl.queuedTotal.Add(-n)
}

// kryfo: writes queued events in order, one goroutine per connection while
// there is something to write
func (ws *WebSocket) drain() {
	for {
		ws.queueMutex.Lock()
		if ws.closed || len(ws.queue) == 0 {
			ws.draining = false
			ws.queue = nil
			ws.queueMutex.Unlock()
			return
		}
		q := ws.queue[0]
		ws.queue[0] = queuedEvent{}
		ws.queue = ws.queue[1:]
		ws.queueMutex.Unlock()

		err := ws.WriteJSON(nostr.EventEnvelope{SubscriptionID: &q.id, Event: *q.event})

		ws.queueMutex.Lock()
		ws.queued -= q.size
		ws.rl.queuedTotal.Add(-q.size)
		if err != nil {
			ws.dropQueue()
		}
		ws.queueMutex.Unlock()
	}
}
