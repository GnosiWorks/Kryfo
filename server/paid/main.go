// SPDX-License-Identifier: GPL-3.0-or-later
// paid: one ntfy push to the developer when a btcpay invoice settles,
// carrying the amount and nothing else. btcpay calls it through a webhook,
// signed with a shared secret. no disk state, and nothing about an invoice
// is logged: not its id, not its amount.
// stdlib only, nothing to download on a bad connection.
package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	// a settled event is a few hundred bytes; metadata can add some
	maxBody = 64 << 10
	// invoice ids kept to push each one once
	keepIDs = 1000
	title   = "Kryfo donation"
)

type config struct {
	btcpayURL string
	apiKey    string // greenfield key with btcpay.store.canviewinvoices only
	storeID   string
	secret    []byte // the webhook's secret, as typed into btcpay
	ntfyURL   string // the topic url is the only secret ntfy has
	ipv4      bool   // ntfy.sh counts a whole ipv6 /64 as one sender
}

type server struct {
	cfg      config
	btcpay   *http.Client
	ntfy     *http.Client
	seen     *idSet
	mu       sync.Mutex
	counters map[string]int
}

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func main() {
	check := flag.Bool("check", false, "check the greenfield key and send a test push, then exit")
	flag.Parse()

	cfg := config{
		btcpayURL: strings.TrimRight(env("BTCPAY_URL", "http://127.0.0.1"), "/"),
		apiKey:    os.Getenv("BTCPAY_APIKEY"),
		storeID:   os.Getenv("BTCPAY_STOREID"),
		secret:    []byte(os.Getenv("PAID_WEBHOOK_SECRET")),
		ntfyURL:   os.Getenv("NTFY_URL"),
		ipv4:      os.Getenv("NTFY_IPV4") == "1",
	}
	if cfg.apiKey == "" || cfg.storeID == "" || cfg.ntfyURL == "" {
		log.Fatal("set BTCPAY_APIKEY, BTCPAY_STOREID and NTFY_URL")
	}
	// a short secret is guessable offline from one signed delivery
	if len(cfg.secret) < 16 {
		log.Fatal("set PAID_WEBHOOK_SECRET, 16 characters or more")
	}
	s := newServer(cfg)

	if *check {
		os.Exit(s.selfCheck())
	}

	addr := env("PAID_ADDR", "127.0.0.1:3340")
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "ok\n")
	})
	mux.HandleFunc("/webhook", s.handleWebhook)
	log.Printf("kryfo paid on %s", addr)
	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       20 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       90 * time.Second,
		// go's own server messages can quote a request; none are wanted
		ErrorLog: log.New(io.Discard, "", 0),
	}
	log.Fatal(srv.ListenAndServe())
}

func newServer(cfg config) *server {
	d := &net.Dialer{Timeout: 10 * time.Second}
	dial := d.DialContext
	if cfg.ipv4 {
		dial = func(ctx context.Context, _, addr string) (net.Conn, error) {
			return d.DialContext(ctx, "tcp4", addr)
		}
	}
	tr := http.DefaultTransport.(*http.Transport).Clone()
	tr.Proxy = nil
	tr.DialContext = dial
	return &server{
		cfg:      cfg,
		btcpay:   &http.Client{Timeout: 20 * time.Second},
		ntfy:     &http.Client{Timeout: 20 * time.Second, Transport: tr},
		seen:     newIDSet(keepIDs),
		counters: map[string]int{},
	}
}

// what a btcpay invoice id looks like. it goes into a url under our key,
// so it is matched against what it can be
var invoiceID = regexp.MustCompile(`^[A-Za-z0-9]{8,64}$`)

var (
	amountRe   = regexp.MustCompile(`^[0-9]{1,15}(\.[0-9]{1,12})?$`)
	currencyRe = regexp.MustCompile(`^[A-Z]{3,5}$`)
)

func (s *server) handleWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxBody))
	if err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			s.count("too big")
			w.WriteHeader(http.StatusRequestEntityTooLarge)
			return
		}
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	if !s.signed(body, r.Header.Get("BTCPay-Sig")) {
		s.count("bad signature")
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	var ev struct {
		Type      string `json:"type"`
		StoreID   string `json:"storeId"`
		InvoiceID string `json:"invoiceId"`
	}
	if json.Unmarshal(body, &ev) != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	// anything else that is signed is answered 200, so btcpay does not
	// send it again
	if ev.Type != "InvoiceSettled" || ev.StoreID != s.cfg.storeID || !invoiceID.MatchString(ev.InvoiceID) {
		s.count("ignored")
		return
	}
	// taken before the work, so two deliveries at once push once
	if !s.seen.take(ev.InvoiceID) {
		s.count("repeat")
		return
	}
	msg, err := s.message(r.Context(), ev.InvoiceID)
	if err != nil {
		s.seen.drop(ev.InvoiceID)
		s.count(err.Error())
		if !errors.Is(err, errGone) && !errors.Is(err, errUnsettled) {
			w.WriteHeader(http.StatusBadGateway) // btcpay sends it again later
		}
		return
	}
	if err := s.push(r.Context(), msg); err != nil {
		s.seen.drop(ev.InvoiceID)
		s.count(err.Error())
		w.WriteHeader(http.StatusBadGateway)
		return
	}
	s.count("pushed")
}

// sha256=<hex hmac-sha256 of the raw body>, compared in constant time
func (s *server) signed(body []byte, header string) bool {
	hexSig, ok := strings.CutPrefix(header, "sha256=")
	if !ok {
		return false
	}
	got, err := hex.DecodeString(hexSig)
	if err != nil {
		return false
	}
	m := hmac.New(sha256.New, s.cfg.secret)
	m.Write(body)
	return hmac.Equal(got, m.Sum(nil))
}

var (
	// btcpay's test deliveries name invoices that do not exist
	errGone      = errors.New("no such invoice")
	errUnsettled = errors.New("not settled")
)

// the push text. errors name a kind only: the client's own errors quote
// urls, and those hold the invoice id and the topic
func (s *server) message(ctx context.Context, id string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		s.cfg.btcpayURL+"/api/v1/stores/"+s.cfg.storeID+"/invoices/"+id, nil)
	if err != nil {
		return "", errors.New("greenfield request")
	}
	req.Header.Set("Authorization", "token "+s.cfg.apiKey)
	resp, err := s.btcpay.Do(req)
	if err != nil {
		return "", errors.New("greenfield unreachable")
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return "", errGone
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("greenfield status %d", resp.StatusCode)
	}
	var inv struct {
		Status   string `json:"status"`
		Amount   string `json:"amount"`
		Currency string `json:"currency"`
	}
	if json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&inv) != nil {
		return "", errors.New("greenfield answer")
	}
	if inv.Status != "Settled" {
		return "", errUnsettled
	}
	return text(inv.Amount, inv.Currency)
}

// "Kryfo: a donation of 50 USD settled". the amount and currency are
// checked by shape, so nothing else can ride along in them
func text(amount, currency string) (string, error) {
	if !amountRe.MatchString(amount) || !currencyRe.MatchString(currency) {
		return "", errors.New("greenfield amount")
	}
	if whole, frac, ok := strings.Cut(amount, "."); ok && strings.Trim(frac, "0") == "" {
		amount = whole
	}
	return fmt.Sprintf("Kryfo: a donation of %s %s settled", amount, currency), nil
}

func (s *server) push(ctx context.Context, msg string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.cfg.ntfyURL, strings.NewReader(msg))
	if err != nil {
		return errors.New("ntfy request")
	}
	req.Header.Set("Title", title)
	req.Header.Set("Priority", "low")
	resp, err := s.ntfy.Do(req)
	if err != nil {
		return errors.New("ntfy unreachable")
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, io.LimitReader(resp.Body, 1<<16))
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("ntfy status %d", resp.StatusCode)
	}
	return nil
}

// counts by kind, logged as a running total. nothing about an invoice
func (s *server) count(kind string) {
	s.mu.Lock()
	s.counters[kind]++
	n := s.counters[kind]
	s.mu.Unlock()
	log.Printf("%s: %d", kind, n)
}

// for the install script: the key can read the store's invoices, and a
// push gets through. prints kinds only, never a value
func (s *server) selfCheck() int {
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet,
		s.cfg.btcpayURL+"/api/v1/stores/"+s.cfg.storeID+"/invoices?take=1", nil)
	req.Header.Set("Authorization", "token "+s.cfg.apiKey)
	resp, err := s.btcpay.Do(req)
	if err != nil {
		fmt.Println("greenfield: unreachable")
		return 1
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fmt.Printf("greenfield: status %d (401 a wrong key, 403 a wrong store or permission)\n", resp.StatusCode)
		return 1
	}
	fmt.Println("greenfield: the key reads the store's invoices")
	if err := s.push(ctx, "Kryfo donation pushes are set up"); err != nil {
		fmt.Println(err)
		return 1
	}
	fmt.Println("ntfy: test push sent")
	return 0
}

// invoice ids already pushed, oldest dropped past max
type idSet struct {
	mu   sync.Mutex
	max  int
	ids  map[string]bool
	ring []string
}

func newIDSet(max int) *idSet {
	return &idSet{max: max, ids: map[string]bool{}}
}

// true when id was not there and now is
func (t *idSet) take(id string) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.ids[id] {
		return false
	}
	if len(t.ring) >= t.max {
		delete(t.ids, t.ring[0])
		t.ring = t.ring[1:]
	}
	t.ids[id] = true
	t.ring = append(t.ring, id)
	return true
}

// a failed push gives the id back, so a redelivery tries again
func (t *idSet) drop(id string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if !t.ids[id] {
		return
	}
	delete(t.ids, id)
	for i, v := range t.ring {
		if v == id {
			t.ring = append(t.ring[:i], t.ring[i+1:]...)
			break
		}
	}
}
