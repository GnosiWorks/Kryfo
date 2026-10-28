// SPDX-License-Identifier: GPL-3.0-or-later
// badge service: turns a paid btcpay invoice into an ed25519-signed receipt
// the app verifies offline. no database and no accounts: the invoice id is
// the state and btcpay holds it, nothing about a donor is stored here.
// the app pins the public key, so a badge outlives this server.
// stdlib only, nothing to download on a bad connection.
package main

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"sync"
	"time"
)

var (
	btcpayURL = env("BTCPAY_URL", "http://127.0.0.1")
	apiKey    = os.Getenv("BTCPAY_APIKEY")  // Greenfield API key, store-scoped
	storeID   = os.Getenv("BTCPAY_STOREID") // BTCPay store id
	listen    = env("BADGE_ADDR", "127.0.0.1:8899")
	keyPath   = env("BADGE_KEY", "/opt/halo-badge/badge.key")
	priv      ed25519.PrivateKey
)

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

// tiers the app may request. amounts in USD; BTCPay converts to BTC at the
// current rate when it builds the invoice.
var tiers = map[string]float64{
	"supporter": 20,
	"patron":    50,
	"guardian":  100,
}

// invoices an hour, for everyone together: behind an onion there is no
// caller to tell apart. each invoice costs btcpay a fresh address, and a
// flood walks the wallet past its gap limit, so a restore from seed stops
// looking before the addresses real money went to.
var perHour = envInt("BADGE_INVOICES_PER_HOUR", 30)

// a token bucket: a burst of ten, refilled evenly across the hour
type bucket struct {
	mu     sync.Mutex
	tokens float64
	max    float64
	perSec float64
	last   time.Time
}

func newBucket(perHour int) *bucket {
	max := 10.0
	if float64(perHour) < max {
		max = float64(perHour)
	}
	return &bucket{tokens: max, max: max, perSec: float64(perHour) / 3600, last: time.Now()}
}

func (b *bucket) take(now time.Time) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.tokens += now.Sub(b.last).Seconds() * b.perSec
	if b.tokens > b.max {
		b.tokens = b.max
	}
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

var invoices = newBucket(perHour)

// receipt checks, for everyone together. each one is a call to btcpay, and
// a waiting phone asks a few times a minute at most.
var receipts = newRate(envInt("BADGE_RECEIPTS_PER_SEC", 5), 60)

func newRate(perSec, burst int) *bucket {
	return &bucket{tokens: float64(burst), max: float64(burst), perSec: float64(perSec), last: time.Now()}
}

// calls to btcpay in flight. a flood waits here instead of opening
// connections to it without end
var upstream = make(chan struct{}, 8)

func envInt(k string, d int) int {
	if n, err := strconv.Atoi(os.Getenv(k)); err == nil && n > 0 {
		return n
	}
	return d
}

func main() {
	if apiKey == "" || storeID == "" {
		log.Fatal("set BTCPAY_APIKEY and BTCPAY_STOREID")
	}
	if gapSinceErr != nil {
		log.Fatal(gapSinceErr)
	}
	loadOrCreateKey()
	pub := base64.RawURLEncoding.EncodeToString(priv.Public().(ed25519.PublicKey))
	log.Printf("badge pubkey (pin this in the app): %s", pub)

	http.HandleFunc("/pubkey", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{"pubkey": pub})
	})
	http.HandleFunc("/invoice", handleInvoice)
	http.HandleFunc("/receipt", handleReceipt)

	log.Printf("halo badge service on %s, %d invoices an hour, %d unpaid in a row at most, "+
		"counted since %s", listen, perHour, gapLimit, gapSinceLine())
	// timeouts, so a client that opens a connection and says nothing does
	// not hold it for ever
	srv := &http.Server{
		Addr:              listen,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       20 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       90 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}

func loadOrCreateKey() {
	if b, err := os.ReadFile(keyPath); err == nil && len(b) == ed25519.PrivateKeySize {
		priv = ed25519.PrivateKey(b)
		return
	}
	_, p, err := ed25519.GenerateKey(nil)
	if err != nil {
		log.Fatal(err)
	}
	priv = p
	_ = os.MkdirAll(filepath.Dir(keyPath), 0o700)
	if err := os.WriteFile(keyPath, priv, 0o600); err != nil {
		log.Fatal(err)
	}
	log.Printf("generated a new signing key at %s, back it up: losing it "+
		"invalidates every badge you've ever issued", keyPath)
}

// POST /invoice {"tier":"supporter", "again":"<id>"} -> {id, tier, usd, address, btc, uri, expiresIn}
// again is optional: the phone's own open invoice, handed back while it can
// still be paid, so a donor who comes back costs no new address
func handleInvoice(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "post only", 405)
		return
	}
	var req struct {
		Tier  string `json:"tier"`
		Again string `json:"again"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<12)).Decode(&req); err != nil {
		http.Error(w, "bad json", 400)
		return
	}
	amount, ok := tiers[req.Tier]
	if !ok {
		http.Error(w, "unknown tier", 400)
		return
	}
	if req.Again != "" && invoiceID.MatchString(req.Again) {
		// a read like a receipt check, so it spends from that allowance
		if !receipts.take(time.Now()) {
			http.Error(w, "busy, try again later", http.StatusTooManyRequests)
			return
		}
		if out, ok := reopen(req.Again, req.Tier); ok {
			writeJSON(w, out)
			return
		}
	}
	// a wallet restored from seed looks only so far past its last paid
	// address. no more unpaid ones than that in a row. asked before the
	// hourly allowance, so a held guard spends none of it
	ok, err := gap.reserve(time.Now())
	if err != nil {
		log.Printf("invoice refused: cannot count unpaid invoices: %v", err)
		http.Error(w, "upstream", 502)
		return
	}
	if !ok {
		http.Error(w, "busy, try again later", http.StatusTooManyRequests)
		return
	}
	if !invoices.take(time.Now()) {
		gap.giveBack()
		log.Printf("invoice refused: over %d an hour", perHour)
		http.Error(w, "busy, try again later", http.StatusTooManyRequests)
		return
	}
	defer gap.done()

	body, _ := json.Marshal(map[string]any{
		"amount":   fmt.Sprintf("%.2f", amount),
		"currency": "USD",
		"metadata": map[string]any{"tier": req.Tier},
		"checkout": map[string]any{
			"paymentMethods": []string{"BTC"},
			// donors are anonymous: never ask for anything.
			"requiresRefundEmail": false,
			// the address is made now, whatever the store's setting says
			"lazyPaymentMethods": false,
			"expirationMinutes":  invoiceMinutes,
			// a wallet that rounds or takes its fee from the amount still pays
			"paymentTolerance": paymentTolerance,
		},
	})
	resp, err := btcpay("POST", "/api/v1/stores/"+storeID+"/invoices", body)
	if err != nil {
		log.Printf("invoice create failed: %v", err)
		http.Error(w, "upstream", 502)
		return
	}

	var inv struct {
		ID         string `json:"id"`
		Expiration int64  `json:"expirationTime"`
	}
	_ = json.Unmarshal(resp, &inv)
	if !invoiceID.MatchString(inv.ID) {
		log.Printf("invoice create: no usable id in the answer")
		http.Error(w, "upstream", 502)
		return
	}

	// pull the on-chain address + exact btc amount so the app can render its
	// own QR instead of sending the donor to a web checkout.
	addr, btcAmt := waitForAddress(inv.ID)
	if addr == "" {
		// an invoice with nowhere to pay is not one. the app shows the
		// plain address instead. it cannot be archived with this key
		// (that needs canmodifyinvoices): with no address it takes no money
		// and expires by itself
		log.Printf("invoice create: no address after %v", addrWait)
		http.Error(w, "upstream", 502)
		return
	}

	left := int64(invoiceMinutes * 60)
	if inv.Expiration > 0 {
		left = inv.Expiration - time.Now().Unix()
	}
	writeJSON(w, invoiceAnswer(inv.ID, req.Tier, addr, btcAmt, left))
}

// btcpay's checkout link is not passed on: the app draws its own qr, and
// the link names wherever btcpay is hosted
func invoiceAnswer(id, tier, addr, btc string, left int64) map[string]any {
	return map[string]any{
		"id":        id,
		"tier":      tier,
		"usd":       tiers[tier],
		"address":   addr,
		"btc":       btc,
		"uri":       "bitcoin:" + addr + "?amount=" + btc,
		"expiresIn": left,
	}
}

// an invoice handed back needs this much time left to be paid in
const reopenMinLeft = 10 * time.Minute

// the phone's own invoice again, only while nothing was paid into it and
// there is time to pay. anything else gets a new one
func reopen(id, tier string) (map[string]any, bool) {
	resp, err := btcpay("GET", "/api/v1/stores/"+storeID+"/invoices/"+id, nil)
	if err != nil {
		return nil, false
	}
	var inv struct {
		ID               string `json:"id"`
		Status           string `json:"status"`
		AdditionalStatus string `json:"additionalStatus"`
		Amount           string `json:"amount"`
		Currency         string `json:"currency"`
		Expiration       int64  `json:"expirationTime"`
		Metadata         struct {
			Tier string `json:"tier"`
		} `json:"metadata"`
	}
	if json.Unmarshal(resp, &inv) != nil || inv.ID != id {
		return nil, false
	}
	left := inv.Expiration - time.Now().Unix()
	if inv.Status != "New" || touched(inv.AdditionalStatus) ||
		earned(inv.Metadata.Tier, inv.Amount, inv.Currency) != tier ||
		left < int64(reopenMinLeft/time.Second) {
		return nil, false
	}
	ctx, cancel := context.WithTimeout(context.Background(), addrWait)
	defer cancel()
	pm, err := paymentDetails(ctx, id)
	if err != nil || pm.Destination == "" {
		return nil, false
	}
	return invoiceAnswer(id, tier, pm.Destination, pm.amount(), left), true
}

// some money reached the invoice's address, early, late or short
func touched(additional string) bool {
	switch additional {
	case "PaidPartial", "PaidLate", "PaidOver":
		return true
	}
	return false
}

// unpaid invoices in a row the guard allows. every invoice takes the next
// address, and a wallet restored from seed stops looking 20 past the last
// one paid. 15 leaves room for addresses made outside this service
var gapLimit = envInt("BADGE_GAP_LIMIT", 15)

// invoices made before this time are not counted, for when the wallet is
// known to see up to there (RFC 3339, empty for all). checked in main
var gapSince, gapSinceErr = envTime("BADGE_GAP_SINCE")

// how long a count from btcpay is trusted, so a refusal does not ask again
// on every tap and a payment reopens it within minutes
var gapRecheck = 2 * time.Minute

// an unset value is no time. one that does not parse is an error: a
// baseline thought set and silently ignored keeps the guard held
func envTime(k string) (time.Time, error) {
	v := os.Getenv(k)
	if v == "" {
		return time.Time{}, nil
	}
	t, err := time.Parse(time.RFC3339, v)
	if err != nil {
		return time.Time{}, fmt.Errorf("%s=%q is not RFC 3339 (2026-11-01T12:00:00Z)", k, v)
	}
	return t, nil
}

// the baseline as the start line says it
func gapSinceLine() string {
	if gapSince.IsZero() {
		return "none"
	}
	return gapSince.UTC().Format(time.RFC3339)
}

// counts the unpaid invoices since the last paid one and refuses new
// ones at the limit
type gapGuard struct {
	mu      sync.Mutex
	unpaid  int
	checked time.Time
	// invoices asked for and not yet answered: not in btcpay's list yet
	inflight int
	held     bool
	// when the hold was last said in the journal
	said time.Time
}

// while held, the journal hears about it this often
const gapSayEvery = time.Hour

var gap = &gapGuard{}

func (g *gapGuard) reserve(now time.Time) (bool, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.checked.IsZero() || now.Sub(g.checked) >= gapRecheck {
		n, err := unpaidInARow(gapLimit)
		if err != nil {
			return false, err
		}
		g.unpaid, g.checked = n+g.inflight, now
	}
	if g.unpaid >= gapLimit {
		if !g.held || now.Sub(g.said) >= gapSayEvery {
			log.Printf("INVOICES HELD: %d unpaid in a row, the limit is %d. badges wait, the app "+
				"shows the fixed address. reopens on a payment, or set BADGE_GAP_SINCE once the "+
				"wallet sees every address", g.unpaid, gapLimit)
			g.said = now
		}
		g.held = true
		return false, nil
	}
	if g.held {
		log.Printf("invoices open again: %d unpaid in a row", g.unpaid)
	}
	g.held = false
	g.unpaid++
	g.inflight++
	return true, nil
}

// a reservation the allowance then refused: no invoice was asked for
func (g *gapGuard) giveBack() {
	g.mu.Lock()
	g.unpaid--
	g.inflight--
	g.mu.Unlock()
}

func (g *gapGuard) done() {
	g.mu.Lock()
	g.inflight--
	g.mu.Unlock()
}

// the store's newest invoices, counted back to the newest one money went
// to. archived ones are counted too: they hold an address all the same
func unpaidInARow(limit int) (int, error) {
	take := limit
	if take < 1 {
		take = 1
	}
	if take > 500 {
		take = 500
	}
	resp, err := btcpay("GET", "/api/v1/stores/"+storeID+"/invoices?includeArchived=true&take="+
		strconv.Itoa(take), nil)
	if err != nil {
		return 0, err
	}
	var list []struct {
		Created          int64  `json:"createdTime"`
		Status           string `json:"status"`
		AdditionalStatus string `json:"additionalStatus"`
	}
	if err := json.Unmarshal(resp, &list); err != nil {
		return 0, err
	}
	sort.SliceStable(list, func(i, j int) bool { return list[i].Created > list[j].Created })
	n := 0
	for _, inv := range list {
		if !gapSince.IsZero() && inv.Created < gapSince.Unix() {
			break
		}
		if paid(inv.Status) || inv.Status == "Processing" || touched(inv.AdditionalStatus) {
			break
		}
		n++
	}
	return n, nil
}

// how long an invoice stays open, and how far under the amount still
// counts as paid, in percent
const (
	invoiceMinutes   = 60
	paymentTolerance = 1.5
)

// an invoice whose address is not there yet is read again for this long.
// the app gives up on the answer's first byte 10 s after it asked, and a
// round trip over tor takes one or two of those
var (
	addrWait = 6 * time.Second
	addrStep = 500 * time.Millisecond
)

// the address and amount of a new invoice, read again until addrWait is
// over. a payment method that waits to be switched on is switched on once
func waitForAddress(id string) (addr, amount string) {
	// every call inside the wait ends with it, a slow btcpay included
	ctx, cancel := context.WithTimeout(context.Background(), addrWait)
	defer cancel()
	activated := false
	for {
		pm, err := paymentDetails(ctx, id)
		if err == nil && pm.Destination != "" {
			return pm.Destination, pm.amount()
		}
		if err == nil && !pm.Activated && methodID.MatchString(pm.PaymentMethodID) && !activated {
			activated = true
			if _, err := btcpayCtx(ctx, "POST", "/api/v1/stores/"+storeID+"/invoices/"+id+
				"/payment-methods/"+pm.PaymentMethodID+"/activate", nil); err != nil {
				log.Printf("invoice create: activate failed: %v", err)
			}
			continue
		}
		dl, _ := ctx.Deadline()
		if !time.Now().Add(addrStep).Before(dl) {
			return "", ""
		}
		time.Sleep(addrStep)
	}
}

// what a btcpay invoice id looks like. the id goes into a url on btcpay's
// api under our key, so it is matched against what it can be and not
// against a list of what it must not contain.
var invoiceID = regexp.MustCompile(`^[A-Za-z0-9]{8,64}$`)

// a payment method id as btcpay names one ("BTC-CHAIN"), before it goes into a url
var methodID = regexp.MustCompile(`^[A-Za-z0-9_-]{1,32}$`)

// paid means the money cannot be taken back. "Processing" is a transaction
// no block holds yet, and a payer could replace it and keep the badge.
// how many confirmations "settled" takes is the store's setting in btcpay,
// and it must not be "unconfirmed", or this check means nothing.
func paid(status string) bool {
	switch status {
	case "Settled", "Complete", "Confirmed": // the last two are the old api's names
		return true
	}
	return false
}

// the tier a settled invoice earns, or "" when it earns none. anything else
// that makes invoices in the same store could make a one dollar one that
// says guardian, so the amount has to cover the tier it names.
func earned(tier, amount, currency string) string {
	want, ok := tiers[tier]
	if !ok || currency != "USD" {
		return ""
	}
	got, err := strconv.ParseFloat(amount, 64)
	if err != nil || got+0.005 < want {
		return ""
	}
	return tier
}

// GET /receipt?id=...  -> 202 while unpaid, 200 + signed receipt once settled.
func handleReceipt(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if !invoiceID.MatchString(id) {
		http.Error(w, "bad id", 400)
		return
	}
	if !receipts.take(time.Now()) {
		http.Error(w, "busy, try again later", http.StatusTooManyRequests)
		return
	}
	resp, err := btcpay("GET", "/api/v1/stores/"+storeID+"/invoices/"+id, nil)
	if err != nil {
		http.Error(w, "upstream", 502)
		return
	}
	var inv struct {
		ID       string `json:"id"`
		Status   string `json:"status"`
		Amount   string `json:"amount"`
		Currency string `json:"currency"`
		Metadata struct {
			Tier string `json:"tier"`
		} `json:"metadata"`
	}
	if err := json.Unmarshal(resp, &inv); err != nil {
		http.Error(w, "upstream", 502)
		return
	}

	switch {
	case paid(inv.Status):
		tier := earned(inv.Metadata.Tier, inv.Amount, inv.Currency)
		if tier == "" {
			// paid, but not for a badge. nothing is signed
			log.Printf("receipt refused: settled invoice does not cover a tier")
			http.Error(w, "not a badge invoice", 409)
			return
		}
		// canonical payload: the app rebuilds this exact string and checks
		// the signature against its pinned pubkey. keep the format frozen.
		payload := fmt.Sprintf("halo-badge|v1|%s|%s", inv.ID, tier)
		sig := ed25519.Sign(priv, []byte(payload))
		writeJSON(w, map[string]any{
			"status":  "paid",
			"id":      inv.ID,
			"tier":    tier,
			"payload": payload,
			"sig":     base64.RawURLEncoding.EncodeToString(sig),
		})
	case inv.Status == "Expired" || inv.Status == "Invalid":
		writeJSON(w, map[string]any{"status": "expired", "id": inv.ID})
	default: // New, and Processing: seen, not yet in a block
		w.WriteHeader(http.StatusAccepted)
		writeJSON(w, map[string]any{"status": "pending", "id": inv.ID})
	}
}

type paymentMethod struct {
	PaymentMethodID string `json:"paymentMethodId"`
	Activated       bool   `json:"activated"`
	Destination     string `json:"destination"`
	Due             string `json:"due"`
	Amount          string `json:"amount"`
}

func (pm paymentMethod) amount() string {
	if pm.Due != "" {
		return pm.Due
	}
	return pm.Amount
}

// the invoice's on-chain payment method, the first one btcpay lists
func paymentDetails(ctx context.Context, invoiceID string) (paymentMethod, error) {
	resp, err := btcpayCtx(ctx, "GET",
		"/api/v1/stores/"+storeID+"/invoices/"+invoiceID+"/payment-methods", nil)
	if err != nil {
		return paymentMethod{}, err
	}
	var pms []paymentMethod
	if err := json.Unmarshal(resp, &pms); err != nil {
		return paymentMethod{}, err
	}
	if len(pms) == 0 {
		return paymentMethod{}, fmt.Errorf("no payment method")
	}
	return pms[0], nil
}

func btcpay(method, path string, body []byte) ([]byte, error) {
	return btcpayCtx(context.Background(), method, path, body)
}

// a call to btcpay that ends with ctx at the latest
func btcpayCtx(ctx context.Context, method, path string, body []byte) ([]byte, error) {
	var rdr io.Reader
	if body != nil {
		rdr = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(ctx, method, btcpayURL+path, rdr)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "token "+apiKey)
	req.Header.Set("Content-Type", "application/json")
	select {
	case upstream <- struct{}{}:
		defer func() { <-upstream }()
	case <-time.After(5 * time.Second):
		return nil, fmt.Errorf("btcpay busy")
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	cl := &http.Client{Timeout: 20 * time.Second}
	resp, err := cl.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode >= 300 {
		return nil, fmt.Errorf("btcpay %d: %s", resp.StatusCode, string(out))
	}
	return out, nil
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}
