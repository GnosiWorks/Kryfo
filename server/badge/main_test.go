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
	// every invoice made, oldest first, as the store's list shows them
	invs []*fakeInv
	// the list read fails
	listDown bool
	lists    int
	mu       sync.Mutex
}

type fakeInv struct {
	ID         string `json:"id"`
	Status     string `json:"status"`
	Additional string `json:"additionalStatus"`
	Amount     string `json:"amount"`
	Currency   string `json:"currency"`
	Created    int64  `json:"createdTime"`
	Expiration int64  `json:"expirationTime"`
	Metadata   struct {
		Tier string `json:"tier"`
	} `json:"metadata"`
}

func (f *fakeBTCPay) find(id string) *fakeInv {
	for _, i := range f.invs {
		if i.ID == id {
			return i
		}
	}
	return nil
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
			inv := &fakeInv{ID: fmt.Sprintf("INV%05d", f.made), Status: "New", Additional: "None",
				Amount: fmt.Sprint(f.created["amount"]), Currency: "USD",
				Created: time.Now().Unix() + int64(f.made), Expiration: time.Now().Add(time.Hour).Unix()}
			if md, ok := f.created["metadata"].(map[string]any); ok {
				inv.Metadata.Tier, _ = md["tier"].(string)
			}
			f.invs = append(f.invs, inv)
			fmt.Fprintf(w, `{"id":%q,"checkoutLink":"https://pay.example/i/x","expirationTime":%d}`,
				inv.ID, inv.Expiration)
		case r.Method == "GET" && strings.HasSuffix(r.URL.Path, "/invoices"):
			f.lists++
			if f.listDown {
				http.Error(w, "down", 500)
				return
			}
			if r.URL.Query().Get("includeArchived") != "true" {
				t.Errorf("the list leaves out archived invoices")
			}
			out := []*fakeInv{}
			for i := len(f.invs) - 1; i >= 0; i-- {
				out = append(out, f.invs[i])
			}
			_ = json.NewEncoder(w).Encode(out)
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
			id := r.URL.Path[strings.LastIndex(r.URL.Path, "/")+1:]
			if inv := f.find(id); inv != nil && f.status == "" {
				_ = json.NewEncoder(w).Encode(inv)
				return
			}
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
	gap, gapSince = &gapGuard{}, time.Time{}
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
	gap, gapSince = &gapGuard{}, time.Time{}
}

// the store's list, empty, for the fakes that answer one invoice only
func emptyList(w http.ResponseWriter, r *http.Request) bool {
	if r.Method == "GET" && strings.HasSuffix(r.URL.Path, "/invoices") {
		fmt.Fprint(w, `[]`)
		return true
	}
	return false
}

// an id from btcpay that is not one never goes into a url
func TestInvoiceRefusesABadIDFromBTCPay(t *testing.T) {
	var paths []string
	var mu sync.Mutex
	serveRaw(t, func(w http.ResponseWriter, r *http.Request) {
		if emptyList(w, r) {
			return
		}
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
		if emptyList(w, r) {
			return
		}
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
		if emptyList(w, r) {
			return
		}
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

func invoiceAgain(t *testing.T, tier, again string) (int, map[string]any) {
	t.Helper()
	body := fmt.Sprintf(`{"tier":%q,"again":%q}`, tier, again)
	w := httptest.NewRecorder()
	handleInvoice(w, httptest.NewRequest("POST", "/invoice", strings.NewReader(body)))
	var m map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &m)
	return w.Code, m
}

// room for more invoices than the guard allows, so the guard is what stops them
func roomyBucket() { invoices = &bucket{tokens: 100, max: 100, perSec: 1, last: time.Now()} }

// a phone that comes back with its open invoice gets that one, and no new address
func TestReuseHandsBackTheSameInvoice(t *testing.T) {
	f := &fakeBTCPay{}
	setup(t, f)
	_, first := invoice(t, "patron")
	id, _ := first["id"].(string)
	invoices = newBucket(1)
	invoices.tokens = 0
	code, again := invoiceAgain(t, "patron", id)
	if code != 200 || again["id"] != id || again["address"] != first["address"] || again["btc"] != first["btc"] {
		t.Fatalf("code=%d %v, want %v back", code, again, first)
	}
	if left, _ := again["expiresIn"].(float64); left < 3500 || left > 3600 {
		t.Fatalf("expiresIn %v", again["expiresIn"])
	}
	if f.made != 1 {
		t.Fatalf("made %d invoices, the second ask was the same phone", f.made)
	}
}

// an invoice goes only to whoever names it: a phone without the id gets its own
func TestNoReuseAcrossPhones(t *testing.T) {
	f := &fakeBTCPay{}
	setup(t, f)
	_, a := invoice(t, "supporter")
	_, b := invoice(t, "supporter")
	if a["id"] == b["id"] || a["id"] == nil || f.made != 2 {
		t.Fatalf("a second phone got %v, the first %v", b["id"], a["id"])
	}
	// an id nobody was given, or one for another tier, is not handed out either
	_, c := invoiceAgain(t, "supporter", "NOSUCHINVOICE1")
	_, d := invoiceAgain(t, "guardian", a["id"].(string))
	if c["id"] == a["id"] || d["id"] == a["id"] || f.made != 4 {
		t.Fatalf("handed back %v and %v, made %d", c["id"], d["id"], f.made)
	}
	if d["tier"] != "guardian" {
		t.Fatalf("tier %v", d["tier"])
	}
	// a malformed id is ignored and a fresh invoice made
	if code, e := invoiceAgain(t, "supporter", "../x"); code != 200 || e["id"] == a["id"] {
		t.Fatalf("code=%d %v", code, e)
	}
}

// an invoice that expired, took money, or is about to run out is never handed back
func TestExpiredInvoiceIsNeverHandedBack(t *testing.T) {
	cases := []func(i *fakeInv){
		func(i *fakeInv) { i.Status = "Expired" },
		func(i *fakeInv) { i.Status = "Invalid" },
		func(i *fakeInv) { i.Status = "Processing" },
		func(i *fakeInv) { i.Status = "Settled" },
		func(i *fakeInv) { i.Additional = "PaidPartial" },
		// still new to btcpay, but past its time or too close to it
		func(i *fakeInv) { i.Expiration = time.Now().Add(-time.Minute).Unix() },
		func(i *fakeInv) { i.Expiration = time.Now().Add(5 * time.Minute).Unix() },
		// not one this service made for that tier
		func(i *fakeInv) { i.Amount = "1.00" },
	}
	for n, change := range cases {
		f := &fakeBTCPay{}
		setup(t, f)
		_, first := invoice(t, "supporter")
		id := first["id"].(string)
		change(f.find(id))
		code, again := invoiceAgain(t, "supporter", id)
		if code != 200 || again["id"] == id || f.made != 2 {
			t.Fatalf("case %d: code=%d got %v back, made %d", n, code, again["id"], f.made)
		}
	}
}

// at the limit no invoice is made, a phone's own is still handed back, and a
// payment opens it again
func TestGapGuardTripsAndRecovers(t *testing.T) {
	f := &fakeBTCPay{}
	setup(t, f)
	roomyBucket()
	var ids []string
	for i := 0; i < gapLimit; i++ {
		code, m := invoice(t, "supporter")
		if code != 200 {
			t.Fatalf("invoice %d: %d", i+1, code)
		}
		ids = append(ids, m["id"].(string))
	}
	if code, _ := invoice(t, "supporter"); code != http.StatusTooManyRequests {
		t.Fatalf("invoice %d: %d, want 429", gapLimit+1, code)
	}
	if f.made != gapLimit {
		t.Fatalf("made %d, the limit is %d", f.made, gapLimit)
	}
	// held, a returning phone still gets its own
	if code, m := invoiceAgain(t, "supporter", ids[3]); code != 200 || m["id"] != ids[3] {
		t.Fatalf("held, reuse got code=%d %v", code, m["id"])
	}
	// held stays held without asking btcpay on every tap
	lists := f.lists
	for i := 0; i < 5; i++ {
		invoice(t, "supporter")
	}
	if f.lists != lists || f.made != gapLimit {
		t.Fatalf("held: %d list reads, %d made", f.lists-lists, f.made)
	}
	// time alone does not reopen it: the unpaid ones are still there
	gap.checked = time.Now().Add(-gapRecheck)
	if code, _ := invoice(t, "supporter"); code != http.StatusTooManyRequests {
		t.Fatalf("reopened with nothing paid: %d", code)
	}
	// someone pays the tenth: five unpaid after it, room again
	f.find(ids[9]).Status = "Settled"
	gap.checked = time.Now().Add(-gapRecheck)
	if code, _ := invoice(t, "supporter"); code != 200 {
		t.Fatalf("after a payment: %d, want 200", code)
	}
	if f.made != gapLimit+1 {
		t.Fatalf("made %d", f.made)
	}
}

// a payment seen but not yet in a block, or money sent late, counts as paid
func TestGapGuardCountsSeenAndLatePayments(t *testing.T) {
	for _, change := range []func(i *fakeInv){
		func(i *fakeInv) { i.Status = "Processing" },
		func(i *fakeInv) { i.Status, i.Additional = "Expired", "PaidLate" },
	} {
		f := &fakeBTCPay{}
		setup(t, f)
		roomyBucket()
		for i := 0; i < gapLimit; i++ {
			invoice(t, "supporter")
		}
		change(f.invs[gapLimit-1])
		gap.checked = time.Now().Add(-gapRecheck)
		if code, _ := invoice(t, "supporter"); code != 200 {
			t.Fatalf("code %d", code)
		}
	}
}

// invoices before the baseline are not counted
func TestGapGuardBaseline(t *testing.T) {
	f := &fakeBTCPay{}
	setup(t, f)
	roomyBucket()
	for i := 0; i < gapLimit; i++ {
		invoice(t, "supporter")
	}
	gapSince = time.Unix(f.invs[gapLimit-1].Created, 0)
	gap.checked = time.Now().Add(-gapRecheck)
	if code, _ := invoice(t, "supporter"); code != 200 {
		t.Fatalf("code %d, one unpaid since the baseline", code)
	}
}

// no count, no invoice: an address is never made blind
func TestGapGuardFailsClosed(t *testing.T) {
	f := &fakeBTCPay{listDown: true}
	setup(t, f)
	if code, _ := invoice(t, "supporter"); code != 502 || f.made != 0 {
		t.Fatalf("code %d, made %d", code, f.made)
	}
	// once the list answers, invoices are made again
	f.listDown = false
	if code, _ := invoice(t, "supporter"); code != 200 || f.made != 1 {
		t.Fatalf("code %d, made %d", code, f.made)
	}
}

// asks at once while the list is stale still stop at the limit
func TestGapGuardHoldsUnderConcurrentAsks(t *testing.T) {
	f := &fakeBTCPay{}
	setup(t, f)
	roomyBucket()
	var wg sync.WaitGroup
	for i := 0; i < 3*gapLimit; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); invoice(t, "supporter") }()
	}
	wg.Wait()
	if f.made != gapLimit {
		t.Fatalf("made %d at once, the limit is %d", f.made, gapLimit)
	}
}

// the limit leaves room under the 20 a wallet looks ahead
func TestGapLimitFitsWallets(t *testing.T) {
	if gapLimit < 1 || gapLimit > 18 {
		t.Fatalf("gapLimit %d", gapLimit)
	}
	if reopenMinLeft >= invoiceMinutes*time.Minute {
		t.Fatalf("reopenMinLeft %v", reopenMinLeft)
	}
}

func smallGap(t *testing.T, n int) {
	t.Helper()
	old := gapLimit
	gapLimit = n
	t.Cleanup(func() { gapLimit = old })
}

// a held guard spends none of the hourly allowance, so the first donors
// after a payment reopens it are not turned away
func TestHeldGuardSpendsNoAllowance(t *testing.T) {
	f := &fakeBTCPay{}
	setup(t, f)
	smallGap(t, 3)
	for i := 0; i < 3; i++ {
		invoice(t, "supporter")
	}
	left := invoices.tokens
	for i := 0; i < 5; i++ {
		if code, _ := invoice(t, "supporter"); code != http.StatusTooManyRequests {
			t.Fatalf("held: %d", code)
		}
	}
	if invoices.tokens < left-0.01 {
		t.Fatalf("held refusals took %.2f tokens", left-invoices.tokens)
	}
	f.invs[2].Status = "Settled"
	gap.checked = time.Now().Add(-gapRecheck)
	if code, _ := invoice(t, "supporter"); code != 200 {
		t.Fatalf("after a payment: %d", code)
	}
}

// the allowance saying no gives the guard's place back
func TestAllowanceRefusalGivesTheReservationBack(t *testing.T) {
	f := &fakeBTCPay{}
	setup(t, f)
	invoices = newBucket(1)
	invoices.tokens = 0
	for i := 0; i < 2*gapLimit; i++ {
		if code, _ := invoice(t, "supporter"); code != http.StatusTooManyRequests {
			t.Fatalf("code %d", code)
		}
	}
	if gap.unpaid != 0 || gap.inflight != 0 || gap.held || f.made != 0 {
		t.Fatalf("unpaid %d inflight %d held %v made %d", gap.unpaid, gap.inflight, gap.held, f.made)
	}
	roomyBucket()
	if code, _ := invoice(t, "supporter"); code != 200 {
		t.Fatalf("code %d", code)
	}
}

// a baseline that does not parse is an error, never quietly no baseline
func TestGapSinceMustParse(t *testing.T) {
	t.Setenv("BADGE_GAP_SINCE_T", "")
	if v, err := envTime("BADGE_GAP_SINCE_T"); err != nil || !v.IsZero() {
		t.Fatalf("unset: %v %v", v, err)
	}
	for _, bad := range []string{"2026-11-01", "yesterday", "2026-11-01 12:00:00"} {
		t.Setenv("BADGE_GAP_SINCE_T", bad)
		if _, err := envTime("BADGE_GAP_SINCE_T"); err == nil {
			t.Fatalf("%q parsed", bad)
		}
	}
	t.Setenv("BADGE_GAP_SINCE_T", "2026-11-01T12:00:00Z")
	v, err := envTime("BADGE_GAP_SINCE_T")
	if err != nil || v.Unix() != 1793534400 {
		t.Fatalf("%v %v", v, err)
	}
	old := gapSince
	t.Cleanup(func() { gapSince = old })
	gapSince = time.Time{}
	if gapSinceLine() != "none" {
		t.Fatal(gapSinceLine())
	}
	gapSince = v
	if gapSinceLine() != "2026-11-01T12:00:00Z" {
		t.Fatal(gapSinceLine())
	}
}

// a reservation the allowance may give back is no hold: no line saying
// held, and none saying open again after it
func TestGapGuardSaysNoFalseHold(t *testing.T) {
	setup(t, &fakeBTCPay{})
	var lines []string
	old := logf
	logf = func(f string, a ...any) { lines = append(lines, fmt.Sprintf(f, a...)) }
	t.Cleanup(func() { logf = old })
	now := time.Now()
	gap = &gapGuard{unpaid: gapLimit - 1, checked: now}
	if ok, _ := gap.reserve(now); !ok {
		t.Fatal("one under the limit was refused")
	}
	// a second ask while the first is still in flight
	if ok, _ := gap.reserve(now); ok || gap.held {
		t.Fatalf("ok=%v held=%v", ok, gap.held)
	}
	gap.giveBack()
	if ok, _ := gap.reserve(now); !ok {
		t.Fatal("refused after the give back")
	}
	gap.done()
	if len(lines) != 0 {
		t.Fatalf("journal: %q", lines)
	}
	// a real hold is said once, and its end once
	if ok, _ := gap.reserve(now); ok || !gap.held || len(lines) != 1 ||
		!strings.HasPrefix(lines[0], "INVOICES HELD: 15 unpaid") {
		t.Fatalf("ok=%v held=%v %q", ok, gap.held, lines)
	}
	gap.reserve(now)
	gap.unpaid = 3
	if ok, _ := gap.reserve(now); !ok || len(lines) != 2 ||
		!strings.HasPrefix(lines[1], "invoices open again") {
		t.Fatalf("ok=%v %q", ok, lines)
	}
}
