package main

import (
go.mod "crypto/tls"
go.mod "encoding/json"
go.mod "flag"
go.mod "log"
go.mod "net/http"
go.mod "sync"
go.mod "time"

go.mod "github.com/gorilla/websocket"
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
go.mod addr     = flag.String("addr", ":8443", "listen address")
go.mod certFile = flag.String("cert", "", "TLS cert file (plain ws if empty — dev only)")
go.mod keyFile  = flag.String("key", "", "TLS key file")
)

const (
go.mod writeWait   = 10 * time.Second
go.mod pongWait    = 60 * time.Second
go.mod pingPeriod  = 50 * time.Second
go.mod maxMsgBytes = 256 * 1024
go.mod queueTTL    = 24 * time.Hour
go.mod maxQueued   = 200
)

type frame struct {
go.mod Type    string `json:"type"`              // hello | send | (out: msg)
go.mod Key     string `json:"key,omitempty"`     // hello: my key. out: sender key.
go.mod To      string `json:"to,omitempty"`      // send: recipient key
go.mod Payload string `json:"payload,omitempty"` // base64 ciphertext, opaque to us
}

type client struct {
go.mod key  string
go.mod conn *websocket.Conn
go.mod out  chan []byte
}

type queued struct {
go.mod data []byte
go.mod at   time.Time
}

type hub struct {
go.mod mu      sync.Mutex
go.mod clients map[string]*client
go.mod queue   map[string][]queued
}

func newHub() *hub {
go.mod return &hub{clients: map[string]*client{}, queue: map[string][]queued{}}
}

func (h *hub) register(c *client) {
go.mod h.mu.Lock()
go.mod if old := h.clients[c.key]; old != nil && old != c {
go.mod go.mod close(old.out)
go.mod }
go.mod h.clients[c.key] = c
go.mod pending := h.queue[c.key]
go.mod delete(h.queue, c.key)
go.mod h.mu.Unlock()

go.mod cutoff := time.Now().Add(-queueTTL)
go.mod for _, q := range pending {
go.mod go.mod if q.at.Before(cutoff) {
go.mod go.mod go.mod continue
go.mod go.mod }
go.mod go.mod select {
go.mod go.mod case c.out <- q.data:
go.mod go.mod default:
go.mod go.mod }
go.mod }
}

func (h *hub) unregister(c *client) {
go.mod h.mu.Lock()
go.mod if h.clients[c.key] == c {
go.mod go.mod delete(h.clients, c.key)
go.mod }
go.mod h.mu.Unlock()
}

func (h *hub) route(to string, data []byte) {
go.mod h.mu.Lock()
go.mod defer h.mu.Unlock()
go.mod if c := h.clients[to]; c != nil {
go.mod go.mod select {
go.mod go.mod case c.out <- data:
go.mod go.mod go.mod return
go.mod go.mod default:
go.mod go.mod }
go.mod }
go.mod q := append(h.queue[to], queued{data: data, at: time.Now()})
go.mod if len(q) > maxQueued {
go.mod go.mod q = q[len(q)-maxQueued:]
go.mod }
go.mod h.queue[to] = q
}

var upgrader = websocket.Upgrader{
go.mod ReadBufferSize:  4096,
go.mod WriteBufferSize: 4096,
go.mod CheckOrigin:     func(*http.Request) bool { return true },
}

func (h *hub) serveWS(w http.ResponseWriter, r *http.Request) {
go.mod conn, err := upgrader.Upgrade(w, r, nil)
go.mod if err != nil {
go.mod go.mod return
go.mod }
go.mod c := &client{conn: conn, out: make(chan []byte, 32)}
go.mod go c.writePump()
go.mod c.readPump(h)
}

func (c *client) readPump(h *hub) {
go.mod defer func() {
go.mod go.mod h.unregister(c)
go.mod go.mod c.conn.Close()
go.mod }()
go.mod c.conn.SetReadLimit(maxMsgBytes)
go.mod c.conn.SetReadDeadline(time.Now().Add(pongWait))
go.mod c.conn.SetPongHandler(func(string) error {
go.mod go.mod c.conn.SetReadDeadline(time.Now().Add(pongWait))
go.mod go.mod return nil
go.mod })
go.mod for {
go.mod go.mod _, raw, err := c.conn.ReadMessage()
go.mod go.mod if err != nil {
go.mod go.mod go.mod return
go.mod go.mod }
go.mod go.mod var f frame
go.mod go.mod if json.Unmarshal(raw, &f) != nil {
go.mod go.mod go.mod continue
go.mod go.mod }
go.mod go.mod switch f.Type {
go.mod go.mod case "hello":
go.mod go.mod go.mod if f.Key == "" {
go.mod go.mod go.mod go.mod return
go.mod go.mod go.mod }
go.mod go.mod go.mod c.key = f.Key
go.mod go.mod go.mod h.register(c)
go.mod go.mod case "send":
go.mod go.mod go.mod if c.key == "" || f.To == "" {
go.mod go.mod go.mod go.mod continue
go.mod go.mod go.mod }
go.mod go.mod go.mod out, _ := json.Marshal(frame{Type: "msg", Key: c.key, Payload: f.Payload})
go.mod go.mod go.mod h.route(f.To, out)
go.mod go.mod }
go.mod }
}

func (c *client) writePump() {
go.mod ticker := time.NewTicker(pingPeriod)
go.mod defer func() {
go.mod go.mod ticker.Stop()
go.mod go.mod c.conn.Close()
go.mod }()
go.mod for {
go.mod go.mod select {
go.mod go.mod case data, ok := <-c.out:
go.mod go.mod go.mod c.conn.SetWriteDeadline(time.Now().Add(writeWait))
go.mod go.mod go.mod if !ok {
go.mod go.mod go.mod go.mod c.conn.WriteMessage(websocket.CloseMessage, nil)
go.mod go.mod go.mod go.mod return
go.mod go.mod go.mod }
go.mod go.mod go.mod if err := c.conn.WriteMessage(websocket.TextMessage, data); err != nil {
go.mod go.mod go.mod go.mod return
go.mod go.mod go.mod }
go.mod go.mod case <-ticker.C:
go.mod go.mod go.mod c.conn.SetWriteDeadline(time.Now().Add(writeWait))
go.mod go.mod go.mod if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
go.mod go.mod go.mod go.mod return
go.mod go.mod go.mod }
go.mod go.mod }
go.mod }
}

func (h *hub) reaper() {
go.mod for range time.Tick(time.Hour) {
go.mod go.mod cutoff := time.Now().Add(-queueTTL)
go.mod go.mod h.mu.Lock()
go.mod go.mod for k, qs := range h.queue {
go.mod go.mod go.mod kept := qs[:0]
go.mod go.mod go.mod for _, q := range qs {
go.mod go.mod go.mod go.mod if q.at.After(cutoff) {
go.mod go.mod go.mod go.mod go.mod kept = append(kept, q)
go.mod go.mod go.mod go.mod }
go.mod go.mod go.mod }
go.mod go.mod go.mod if len(kept) == 0 {
go.mod go.mod go.mod go.mod delete(h.queue, k)
go.mod go.mod go.mod } else {
go.mod go.mod go.mod go.mod h.queue[k] = kept
go.mod go.mod go.mod }
go.mod go.mod }
go.mod go.mod h.mu.Unlock()
go.mod }
}

func main() {
go.mod flag.Parse()
go.mod h := newHub()
go.mod go h.reaper()

go.mod mux := http.NewServeMux()
go.mod mux.HandleFunc("/ws", h.serveWS)
go.mod mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })

go.mod srv := &http.Server{Addr: *addr, Handler: mux}
go.mod if *certFile != "" && *keyFile != "" {
go.mod go.mod srv.TLSConfig = &tls.Config{MinVersion: tls.VersionTLS12}
go.mod go.mod log.Printf("halo relay (wss) on %s", *addr)
go.mod go.mod log.Fatal(srv.ListenAndServeTLS(*certFile, *keyFile))
go.mod }
go.mod log.Printf("halo relay (ws, NO TLS — dev only) on %s", *addr)
go.mod log.Fatal(srv.ListenAndServe())
}
