// SPDX-License-Identifier: GPL-3.0-or-later
// halo badge service — turns a paid BTCPay invoice into an ed25519-signed
// receipt the app can verify forever, offline.
//
// design notes (privacy first):
//   * NO database. the invoice id IS the state, and BTCPay already holds it.
//     nothing about a donor is stored here - not an address, not a time, not
//     an ip. (it's behind a tor onion, so there's no ip to log anyway.)
//   * NO accounts, no email, no PII. a supporter is "someone holding a valid
//     signature", nothing more.
//   * the receipt is signed with a key that never leaves this box; the app
//     pins the PUBLIC key at build time. once signed, the badge keeps working
//     even if this server disappears forever.
//   * stdlib only - no go modules to download (matters on a bad connection).
package main

import (
	"bytes"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
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

func main() {
	if apiKey == "" || storeID == "" {
		log.Fatal("set BTCPAY_APIKEY and BTCPAY_STOREID")
	}
	loadOrCreateKey()
	pub := base64.RawURLEncoding.EncodeToString(priv.Public().(ed25519.PublicKey))
	log.Printf("badge pubkey (pin this in the app): %s", pub)

	http.HandleFunc("/pubkey", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{"pubkey": pub})
	})
	http.HandleFunc("/invoice", handleInvoice)
	http.HandleFunc("/receipt", handleReceipt)

	log.Printf("halo badge service on %s", listen)
	log.Fatal(http.ListenAndServe(listen, nil))
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
	log.Printf("generated a new signing key at %s - BACK IT UP; losing it "+
		"invalidates every badge you've ever issued", keyPath)
}

// POST /invoice {"tier":"supporter"} -> {id, checkoutLink, btc address, amount}
func handleInvoice(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "post only", 405)
		return
	}
	var req struct {
		Tier string `json:"tier"`
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

	body, _ := json.Marshal(map[string]any{
		"amount":   fmt.Sprintf("%.2f", amount),
		"currency": "USD",
		"metadata": map[string]any{"tier": req.Tier},
		"checkout": map[string]any{
			"paymentMethods": []string{"BTC"},
			// donors are anonymous: never ask for anything.
			"requiresRefundEmail": false,
		},
	})
	resp, err := btcpay("POST", "/api/v1/stores/"+storeID+"/invoices", body)
	if err != nil {
		log.Printf("invoice create failed: %v", err)
		http.Error(w, "upstream", 502)
		return
	}

	var inv struct {
		ID           string `json:"id"`
		CheckoutLink string `json:"checkoutLink"`
	}
	_ = json.Unmarshal(resp, &inv)

	// pull the on-chain address + exact btc amount so the app can render its
	// own QR instead of sending the donor to a web checkout.
	addr, btcAmt := paymentDetails(inv.ID)

	writeJSON(w, map[string]any{
		"id":       inv.ID,
		"tier":     req.Tier,
		"usd":      amount,
		"address":  addr,
		"btc":      btcAmt,
		"uri":      "bitcoin:" + addr + "?amount=" + btcAmt,
		"checkout": inv.CheckoutLink,
	})
}

// GET /receipt?id=...  -> 202 while unpaid, 200 + signed receipt once settled.
func handleReceipt(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if id == "" || strings.ContainsAny(id, "/?&") {
		http.Error(w, "bad id", 400)
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
		Metadata struct {
			Tier string `json:"tier"`
		} `json:"metadata"`
	}
	if err := json.Unmarshal(resp, &inv); err != nil {
		http.Error(w, "upstream", 502)
		return
	}

	switch inv.Status {
	case "Settled", "Complete", "Confirmed", "Processing":
		// canonical payload: the app rebuilds this exact string and checks
		// the signature against its pinned pubkey. keep the format frozen.
		payload := fmt.Sprintf("halo-badge|v1|%s|%s", inv.ID, inv.Metadata.Tier)
		sig := ed25519.Sign(priv, []byte(payload))
		writeJSON(w, map[string]any{
			"status":  "paid",
			"id":      inv.ID,
			"tier":    inv.Metadata.Tier,
			"payload": payload,
			"sig":     base64.RawURLEncoding.EncodeToString(sig),
		})
	case "Expired", "Invalid":
		writeJSON(w, map[string]any{"status": "expired", "id": inv.ID})
	default: // New, Processing
		w.WriteHeader(http.StatusAccepted)
		writeJSON(w, map[string]any{"status": "pending", "id": inv.ID})
	}
}

func paymentDetails(invoiceID string) (addr, amount string) {
	resp, err := btcpay("GET",
		"/api/v1/stores/"+storeID+"/invoices/"+invoiceID+"/payment-methods", nil)
	if err != nil {
		return "", ""
	}
	var pms []struct {
		Destination string `json:"destination"`
		Due         string `json:"due"`
		Amount      string `json:"amount"`
	}
	if err := json.Unmarshal(resp, &pms); err != nil || len(pms) == 0 {
		return "", ""
	}
	amt := pms[0].Due
	if amt == "" {
		amt = pms[0].Amount
	}
	return pms[0].Destination, amt
}

func btcpay(method, path string, body []byte) ([]byte, error) {
	var rdr io.Reader
	if body != nil {
		rdr = bytes.NewReader(body)
	}
	req, err := http.NewRequest(method, btcpayURL+path, rdr)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "token "+apiKey)
	req.Header.Set("Content-Type", "application/json")
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
