// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

// a btcpay that says whatever the test tells it to about one invoice
type fakeBTCPay struct {
	status, amount, currency, tier string
	made                           int
}

func (f *fakeBTCPay) serve(t *testing.T) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "token k" {
			t.Errorf("no api key on %s", r.URL.Path)
		}
		switch {
		case r.Method == "POST" && strings.HasSuffix(r.URL.Path, "/invoices"):
			f.made++
			fmt.Fprintf(w, `{"id":"INV%05d","checkoutLink":"https://pay.example/i/x"}`, f.made)
		case strings.HasSuffix(r.URL.Path, "/payment-methods"):
			fmt.Fprint(w, `[{"destination":"bc1qexample","due":"0.00021"}]`)
		default:
			fmt.Fprintf(w, `{"id":"INV00001","status":%q,"amount":%q,"currency":%q,"metadata":{"tier":%q}}`,
				f.status, f.amount, f.currency, f.tier)
		}
	}))
}

func setup(t *testing.T, f *fakeBTCPay) {
	t.Helper()
	srv := f.serve(t)
	t.Cleanup(srv.Close)
	btcpayURL, apiKey, storeID = srv.URL, "k", "s"
	_, p, _ := ed25519.GenerateKey(nil)
	priv = p
	invoices = newBucket(30)
}

func receipt(t *testing.T, id string) (int, map[string]any) {
	t.Helper()
	w := httptest.NewRecorder()
	// escaped on the way in, as a client would; the handler sees it decoded
	handleReceipt(w, httptest.NewRequest("GET", "/receipt?id="+url.QueryEscape(id), nil))
	var m map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &m)
	return w.Code, m
}

func TestSeenIsNotPaid(t *testing.T) {
	f := &fakeBTCPay{status: "Processing", amount: "20.00", currency: "USD", tier: "supporter"}
	setup(t, f)
	code, m := receipt(t, "INV00001")
	if code != http.StatusAccepted || m["status"] != "pending" || m["sig"] != nil {
		t.Fatalf("an unconfirmed payment got code=%d body=%v; it must be pending and unsigned", code, m)
	}
	for _, s := range []string{"New", "Expired", "Invalid"} {
		f.status = s
		if _, m := receipt(t, "INV00001"); m["sig"] != nil {
			t.Fatalf("%s was signed for", s)
		}
	}
}

func TestSettledIsSignedAndVerifies(t *testing.T) {
	f := &fakeBTCPay{status: "Settled", amount: "20.00", currency: "USD", tier: "supporter"}
	setup(t, f)
	code, m := receipt(t, "INV00001")
	if code != 200 || m["status"] != "paid" {
		t.Fatalf("code=%d body=%v", code, m)
	}
	// the format the released apps rebuild and check. frozen.
	if m["payload"] != "halo-badge|v1|INV00001|supporter" {
		t.Fatalf("payload changed: %v", m["payload"])
	}
	sig, _ := base64.RawURLEncoding.DecodeString(m["sig"].(string))
	if !ed25519.Verify(priv.Public().(ed25519.PublicKey), []byte(m["payload"].(string)), sig) {
		t.Fatal("signature does not verify")
	}
}

func TestAmountMustCoverTheTier(t *testing.T) {
	cases := []struct{ amount, currency, tier string }{
		{"1.00", "USD", "guardian"},   // a dollar that says guardian
		{"100.00", "EUR", "guardian"}, // not the currency tiers are priced in
		{"100.00", "USD", "emperor"},  // not a tier
		{"100.00", "USD", ""},         // an invoice this service did not make
		{"abc", "USD", "supporter"},
	}
	for _, c := range cases {
		setup(t, &fakeBTCPay{status: "Settled", amount: c.amount, currency: c.currency, tier: c.tier})
		if code, m := receipt(t, "INV00001"); m["sig"] != nil || code == 200 {
			t.Fatalf("%+v was signed for", c)
		}
	}
	setup(t, &fakeBTCPay{status: "Settled", amount: "100", currency: "USD", tier: "guardian"})
	if _, m := receipt(t, "INV00001"); m["sig"] == nil {
		t.Fatal("a guardian who paid in full got nothing")
	}
}

func TestReceiptIDIsAnAllowList(t *testing.T) {
	setup(t, &fakeBTCPay{status: "Settled", amount: "20", currency: "USD", tier: "supporter"})
	for _, id := range []string{"", "..%2F..%2Fstores", "a/b", "INV 00001", "short", "x\x00y12345", strings.Repeat("A", 65)} {
		if code, _ := receipt(t, id); code != 400 {
			t.Fatalf("id %q got %d, want 400", id, code)
		}
	}
}

func TestInvoicesAreLimited(t *testing.T) {
	f := &fakeBTCPay{}
	setup(t, f)
	post := func(body string) int {
		w := httptest.NewRecorder()
		handleInvoice(w, httptest.NewRequest("POST", "/invoice", strings.NewReader(body)))
		return w.Code
	}
	// a bad request does not spend the allowance
	for i := 0; i < 50; i++ {
		if post(`{"tier":"emperor"}`) != 400 {
			t.Fatal("unknown tier should be a 400")
		}
	}
	ok := 0
	for i := 0; i < 40; i++ {
		if post(`{"tier":"supporter"}`) == 200 {
			ok++
		}
	}
	if ok != 10 || f.made != 10 {
		t.Fatalf("a burst of 40 made %d invoices at btcpay (%d answered ok); the burst is 10", f.made, ok)
	}
	if post(`{"tier":"supporter"}`) != http.StatusTooManyRequests {
		t.Fatal("over the limit should be a 429")
	}
	// two minutes later one more fits: thirty an hour is one every two minutes
	if !invoices.take(time.Now().Add(2*time.Minute + time.Second)) {
		t.Fatal("the bucket did not refill")
	}
}

func TestInvoiceDoesNotPassOnTheCheckoutLink(t *testing.T) {
	setup(t, &fakeBTCPay{})
	w := httptest.NewRecorder()
	handleInvoice(w, httptest.NewRequest("POST", "/invoice", strings.NewReader(`{"tier":"patron"}`)))
	if strings.Contains(w.Body.String(), "pay.example") {
		t.Fatalf("btcpay's host is in the answer: %s", w.Body.String())
	}
	var m map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &m)
	if m["address"] != "bc1qexample" || m["uri"] != "bitcoin:bc1qexample?amount=0.00021" || m["tier"] != "patron" {
		t.Fatalf("the app needs id, tier, address, btc, uri: %v", m)
	}
}
