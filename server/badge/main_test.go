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
	"sync"
	"testing"
	"time"
)

// a btcpay that says whatever the test tells it to about one invoice
type fakeBTCPay struct {
	status, amount, currency, tier string
	made                           int
	// the first reads of a new invoice that find no address yet
	emptyReads, reads int
	// the payment method waits to be switched on, as on a lazy store
	lazy, activated bool
	// what the last invoice was made with
	created map[string]any
	mu      sync.Mutex
}

func (f *fakeBTCPay) serve(t *testing.T) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		if r.Header.Get("Authorization") != "token k" {
			t.Errorf("no api key on %s", r.URL.Path)
		}
		switch {
		case r.Method == "POST" && strings.HasSuffix(r.URL.Path, "/invoices"):
			f.made++
			f.created = nil
			_ = json.NewDecoder(r.Body).Decode(&f.created)
			fmt.Fprintf(w, `{"id":"INV%05d","checkoutLink":"https://pay.example/i/x","expirationTime":%d}`,
				f.made, time.Now().Add(time.Hour).Unix())
		case r.Method == "POST" && strings.HasSuffix(r.URL.Path, "/payment-methods/BTC-CHAIN/activate"):
			f.activated = true
		case strings.HasSuffix(r.URL.Path, "/payment-methods"):
			f.reads++
			switch {
			case f.lazy && !f.activated:
				fmt.Fprint(w, `[{"paymentMethodId":"BTC-CHAIN","activated":false,"destination":null,"due":"0.00021"}]`)
			case f.reads <= f.emptyReads:
				fmt.Fprint(w, `[{"paymentMethodId":"BTC-CHAIN","activated":true,"destination":"","due":"0.00021"}]`)
			default:
				fmt.Fprint(w, `[{"paymentMethodId":"BTC-CHAIN","activated":true,"destination":"bc1qexample","due":"0.00021"}]`)
			}
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
	receipts = newRate(5, 60)
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

func TestAmountCoversTier(t *testing.T) {
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

func TestReceiptIDAllowList(t *testing.T) {
	setup(t, &fakeBTCPay{status: "Settled", amount: "20", currency: "USD", tier: "supporter"})
	for _, id := range []string{"", "..%2F..%2Fstores", "a/b", "INV 00001", "short", "x\x00y12345", strings.Repeat("A", 65)} {
		if code, _ := receipt(t, id); code != 400 {
			t.Fatalf("id %q got %d, want 400", id, code)
		}
	}
}

func TestInvoiceRateLimit(t *testing.T) {
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

func TestInvoiceHidesCheckoutLink(t *testing.T) {
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

func TestReceiptsAreLimited(t *testing.T) {
	setup(t, &fakeBTCPay{status: "New"})
	receipts = newRate(1, 3)
	for i := 0; i < 3; i++ {
		if code, _ := receipt(t, "INV00001"); code != http.StatusAccepted {
			t.Fatalf("check %d: %d, want 202", i, code)
		}
	}
	if code, _ := receipt(t, "INV00001"); code != http.StatusTooManyRequests {
		t.Fatalf("over the burst: %d, want 429", code)
	}
	// a malformed id is refused before it costs a token
	receipts = newRate(1, 1)
	if code, _ := receipt(t, "../x"); code != 400 {
		t.Fatalf("bad id: %d", code)
	}
	if code, _ := receipt(t, "INV00001"); code != http.StatusAccepted {
		t.Fatalf("after a bad id: %d, want 202", code)
	}
}

func TestUpstreamCallsAreCapped(t *testing.T) {
	release := make(chan struct{})
	var inFlight, most int
	var mu sync.Mutex
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		inFlight++
		if inFlight > most {
			most = inFlight
		}
		mu.Unlock()
		<-release
		mu.Lock()
		inFlight--
		mu.Unlock()
		fmt.Fprint(w, `{}`)
	}))
	defer srv.Close()
	btcpayURL, apiKey, storeID = srv.URL, "k", "s"
	var wg sync.WaitGroup
	for i := 0; i < 3*cap(upstream); i++ {
		wg.Add(1)
		go func() { defer wg.Done(); _, _ = btcpay("GET", "/x", nil) }()
	}
	time.Sleep(300 * time.Millisecond)
	close(release)
	wg.Wait()
	if most > cap(upstream) {
		t.Fatalf("%d calls to btcpay at once, cap is %d", most, cap(upstream))
	}
}

func invoice(t *testing.T, tier string) (int, map[string]any) {
	t.Helper()
	w := httptest.NewRecorder()
	handleInvoice(w, httptest.NewRequest("POST", "/invoice", strings.NewReader(`{"tier":"`+tier+`"}`)))
	var m map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &m)
	return w.Code, m
}

func quickWait(t *testing.T, wait time.Duration) {
	t.Helper()
	oldWait, oldStep := addrWait, addrStep
	addrWait, addrStep = wait, 20*time.Millisecond
	t.Cleanup(func() { addrWait, addrStep = oldWait, oldStep })
}

// btcpay can answer a new invoice's payment methods before the address is
// in them: read again instead of failing the donor
func TestInvoiceWaitsForTheAddress(t *testing.T) {
	quickWait(t, 2*time.Second)
	f := &fakeBTCPay{emptyReads: 3}
	setup(t, f)
	code, m := invoice(t, "supporter")
	if code != 200 || m["address"] != "bc1qexample" || m["btc"] != "0.00021" {
		t.Fatalf("code=%d body=%v; the address came on the fourth read", code, m)
	}
	if f.made != 1 || f.reads != 4 {
		t.Fatalf("made %d invoices and read %d times, want 1 and 4", f.made, f.reads)
	}
}

// a store that makes addresses only when asked gets asked
func TestInvoiceSwitchesOnALazyPaymentMethod(t *testing.T) {
	quickWait(t, 2*time.Second)
	f := &fakeBTCPay{lazy: true}
	setup(t, f)
	code, m := invoice(t, "patron")
	if code != 200 || m["address"] != "bc1qexample" || !f.activated {
		t.Fatalf("code=%d body=%v activated=%v", code, m, f.activated)
	}
}

// an address that never comes is given up on in time, with one invoice
func TestInvoiceWithoutAddressGivesUp(t *testing.T) {
	quickWait(t, 300*time.Millisecond)
	f := &fakeBTCPay{emptyReads: 1 << 30}
	setup(t, f)
	t0 := time.Now()
	code, _ := invoice(t, "supporter")
	if took := time.Since(t0); took > 2*time.Second {
		t.Fatalf("took %v, the wait is 300ms", took)
	}
	if code != 502 || f.made != 1 || f.reads < 2 {
		t.Fatalf("code=%d made=%d reads=%d", code, f.made, f.reads)
	}
}

// the wait stays under what the app gives the answer's first byte
func TestAddressWaitFitsTheApp(t *testing.T) {
	if addrWait > 8*time.Second || addrStep <= 0 || addrStep > addrWait {
		t.Fatalf("addrWait %v, addrStep %v", addrWait, addrStep)
	}
}

// an hour to pay, a little under the amount still counts, the address is
// made with the invoice, and the app learns how long it has
func TestInvoiceCheckoutOptions(t *testing.T) {
	f := &fakeBTCPay{}
	setup(t, f)
	code, m := invoice(t, "guardian")
	if code != 200 {
		t.Fatalf("code=%d", code)
	}
	c, _ := f.created["checkout"].(map[string]any)
	if c["expirationMinutes"] != 60.0 || c["paymentTolerance"] != 1.5 || c["lazyPaymentMethods"] != false {
		t.Fatalf("checkout: %v", c)
	}
	if md, _ := f.created["metadata"].(map[string]any); len(md) != 1 || md["tier"] != "guardian" {
		t.Fatalf("metadata holds more than the tier: %v", md)
	}
	if left, _ := m["expiresIn"].(float64); left < 3590 || left > 3600 {
		t.Fatalf("expiresIn %v, want about an hour", m["expiresIn"])
	}
}

// a btcpay that answers every call with h
func serveRaw(t *testing.T, h http.HandlerFunc) {
	t.Helper()
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	btcpayURL, apiKey, storeID = srv.URL, "k", "s"
	invoices = newBucket(30)
	receipts = newRate(5, 60)
}

// an id from btcpay that is not one never goes into a url
func TestInvoiceRefusesABadIDFromBTCPay(t *testing.T) {
	var paths []string
	var mu sync.Mutex
	serveRaw(t, func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		paths = append(paths, r.Method+" "+r.URL.Path)
		mu.Unlock()
		fmt.Fprint(w, `{"id":"../../x","expirationTime":0}`)
	})
	if code, _ := invoice(t, "supporter"); code != 502 {
		t.Fatalf("code %d, want 502", code)
	}
	if len(paths) != 1 {
		t.Fatalf("calls after a bad id: %v", paths)
	}
}

// a payment method id from btcpay that is not one is never switched on
func TestInvoiceRefusesABadMethodFromBTCPay(t *testing.T) {
	quickWait(t, 200*time.Millisecond)
	var paths []string
	var mu sync.Mutex
	serveRaw(t, func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		paths = append(paths, r.Method+" "+r.URL.Path)
		mu.Unlock()
		if r.Method == "POST" && strings.HasSuffix(r.URL.Path, "/invoices") {
			fmt.Fprint(w, `{"id":"INV00001"}`)
			return
		}
		fmt.Fprint(w, `[{"paymentMethodId":"../../users/me","activated":false,"destination":null}]`)
	})
	if code, _ := invoice(t, "supporter"); code != 502 {
		t.Fatalf("code %d, want 502", code)
	}
	for _, p := range paths {
		if strings.Contains(p, "activate") || strings.Contains(p, "users") {
			t.Fatalf("used the bad method id: %s", p)
		}
	}
}

// a btcpay that is slow on every read does not stretch the wait
func TestAddressWaitHoldsWithSlowReads(t *testing.T) {
	quickWait(t, 500*time.Millisecond)
	serveRaw(t, func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			fmt.Fprint(w, `{"id":"INV00001"}`)
			return
		}
		select {
		case <-time.After(3 * time.Second):
		case <-r.Context().Done():
			return
		}
		fmt.Fprint(w, `[{"paymentMethodId":"BTC-CHAIN","activated":true,"destination":"","due":"0.1"}]`)
	})
	t0 := time.Now()
	code, _ := invoice(t, "supporter")
	if took := time.Since(t0); code != 502 || took > 1500*time.Millisecond {
		t.Fatalf("code %d after %v, the wait is 500ms", code, took)
	}
}
