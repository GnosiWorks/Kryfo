package main

import (
	"crypto/tls"
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// halo fast relay — forwards opaque, end-to-end-encrypted blobs between two
// connected clients. it never sees plaintext: payload is libsignal ciphertext.
// it DOES see metadata — which routing keys talk to each other, timing, ip.
// that is the fast-mode tradeoff. tor mode never touches this server.
//
// addressing: a client registers a routing key (its x25519 pubkey hex, the
// same value the app already uses for nostr). senders address a recipient by
// that key. offline recipients get a short store-and-forward queue.
//
// NOT DONE YET: signed-hello auth. right now a client is trusted to declare
// its own key, so a bad actor could register someone else's key to intercept
// their queued (still-encrypted) blobs or deny delivery. content stays
// unreadable, but this must be closed before any public use. see README.

var (
	addr     = flag.String("addr", ":8443", "listen address")
	certFile = flag.String("cert", "", "TLS cert file (plain ws if empty — dev only)")
	keyFile  = flag.String("key", "", "TLS key file")
)

const (
	writeWait   = 10 * time.Second
	pongWait    = 60 * time.Second
	pingPeriod  = 50 * time.Second
	maxMsgBytes = 256 * 1024
	queueTTL    = 24 * time.Hour
	maxQueued   = 200
)

type frame struct {
	Type    string `json:"type"`              // hello | send | (out: msg)
	Key     string `json:"key,omitempty"`     // hello: my key. out: sender key.
	To      string `json:"to,omitempty"`      // send: recipient key
	Payload string `json:"payload,omitempty"` // base64 ciphertext, opaque to us
}

type client struct {
	key  string
	conn *websocket.Conn
	out  chan []byte
}

type queued struct {
	data []byte
	at   time.Time
}

type hub struct {
	mu      sync.Mutex
	clients map[string]*client
	queue   map[string][]queued
}

func newHub() *hub {
	return &hub{clients: map[string]*client{}, queue: map[string][]queued{}}
}

func (h *hub) register(c *client) {
	h.mu.Lock()
	if old := h.clients[c.key]; old != nil && old != c {
		close(old.out)
	}
	h.clients[c.key] = c
	pending := h.queue[c.key]
	delete(h.queue, c.key)
	h.mu.Unlock()

	cutoff := time.Now().Add(-queueTTL)
	for _, q := range pending {
		if q.at.Before(cutoff) {
			continue
		}
		select {
		case c.out <- q.data:
		default:
		}
	}
}

func (h *hub) unregister(c *client) {
	h.mu.Lock()
	if h.clients[c.key] == c {
		delete(h.clients, c.key)
	}
	h.mu.Unlock()
}

func (h *hub) route(to string, data []byte) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if c := h.clients[to]; c != nil {
		select {
		case c.out <- data:
			return
		default:
		}
	}
	q := append(h.queue[to], queued{data: data, at: time.Now()})
	if len(q) > maxQueued {
		q = q[len(q)-maxQueued:]
	}
	h.queue[to] = q
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	CheckOrigin:     func(*http.Request) bool { return true },
}

func (h *hub) serveWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	c := &client{conn: conn, out: make(chan []byte, 32)}
	go c.writePump()
	c.readPump(h)
}

func (c *client) readPump(h *hub) {
	defer func() {
		h.unregister(c)
		c.conn.Close()
	}()
	c.conn.SetReadLimit(maxMsgBytes)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	for {
		_, raw, err := c.conn.ReadMessage()
		if err != nil {
			return
		}
		var f frame
		if json.Unmarshal(raw, &f) != nil {
			continue
		}
		switch f.Type {
		case "hello":
			if f.Key == "" {
				return
			}
			c.key = f.Key
			h.register(c)
		case "send":
			if c.key == "" || f.To == "" {
				continue
			}
			out, _ := json.Marshal(frame{Type: "msg", Key: c.key, Payload: f.Payload})
			h.route(f.To, out)
		}
	}
}

func (c *client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case data, ok := <-c.out:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, nil)
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, data); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (h *hub) reaper() {
	for range time.Tick(time.Hour) {
		cutoff := time.Now().Add(-queueTTL)
		h.mu.Lock()
		for k, qs := range h.queue {
			kept := qs[:0]
			for _, q := range qs {
				if q.at.After(cutoff) {
					kept = append(kept, q)
				}
			}
			if len(kept) == 0 {
				delete(h.queue, k)
			} else {
				h.queue[k] = kept
			}
		}
		h.mu.Unlock()
	}
}

func main() {
	flag.Parse()
	h := newHub()
	go h.reaper()

	mux := http.NewServeMux()
	mux.HandleFunc("/ws", h.serveWS)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })

	srv := &http.Server{Addr: *addr, Handler: mux}
	if *certFile != "" && *keyFile != "" {
		srv.TLSConfig = &tls.Config{MinVersion: tls.VersionTLS12}
		log.Printf("halo relay (wss) on %s", *addr)
		log.Fatal(srv.ListenAndServeTLS(*certFile, *keyFile))
	}
	log.Printf("halo relay (ws, NO TLS — dev only) on %s", *addr)
	log.Fatal(srv.ListenAndServe())
}
