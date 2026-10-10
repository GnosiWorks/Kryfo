// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
)

const (
	testSecret = "a-long-test-secret-0123456789"
	testStore  = "StoreAbc123"
	testInv    = "InvXyz7890abc"
)

type fakes struct {
	srv        *server
	greenfield *httptest.Server
	ntfy       *httptest.Server
	gfCalls    atomic.Int32
	gfStatus   atomic.Int32
	gfBody     atomic.Value
	ntfyStatus atomic.Int32
	mu         sync.Mutex
	pushes     []*http.Request
	bodies     []string
	logs       bytes.Buffer
}

// the invoice greenfield answers with, full of what must not leak
const fullInvoice = `{"id":"InvXyz7890abc","storeId":"StoreAbc123","status":"Settled",
"amount":"50.00","currency":"USD","checkoutLink":"https://pay.example/i/InvXyz7890abc",
"createdTime":1760000000,"metadata":{"buyerEmail":"donor@example.com","buyerName":"Ann Donor",
"orderId":"order-77","tier":"patron"},"additionalStatus":"None"}`

func newFakes(t *testing.T) *fakes {
	t.Helper()
	f := &fakes{}
	f.gfStatus.Store(200)
	f.ntfyStatus.Store(200)
	f.gfBody.Store(fullInvoice)
	f.greenfield = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.gfCalls.Add(1)
		if r.Header.Get("Authorization") != "token view-key" {
			w.WriteHeader(401)
			return
		}
		if r.URL.Path != "/api/v1/stores/"+testStore+"/invoices/"+testInv {
			w.WriteHeader(404)
			return
		}
		w.WriteHeader(int(f.gfStatus.Load()))
		io.WriteString(w, f.gfBody.Load().(string))
	}))
	f.ntfy = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		f.mu.Lock()
		f.pushes = append(f.pushes, r)
		f.bodies = append(f.bodies, string(b))
		f.mu.Unlock()
		w.WriteHeader(int(f.ntfyStatus.Load()))
	}))
	t.Cleanup(f.greenfield.Close)
	t.Cleanup(f.ntfy.Close)
	f.srv = newServer(config{
		btcpayURL: f.greenfield.URL,
		apiKey:    "view-key",
		storeID:   testStore,
		secret:    []byte(testSecret),
		ntfyURL:   f.ntfy.URL + "/secret-topic",
		ipv4:      true,
	})
	log.SetFlags(0)
	log.SetOutput(&f.logs)
	t.Cleanup(func() { log.SetOutput(io.Discard) })
	return f
}

func sign(body string) string {
	m := hmac.New(sha256.New, []byte(testSecret))
	m.Write([]byte(body))
	return "sha256=" + hex.EncodeToString(m.Sum(nil))
}

func event(typ, store, inv string) string {
	return fmt.Sprintf(`{"deliveryId":"D1","webhookId":"W1","originalDeliveryId":"D1",
"isRedelivery":false,"type":%q,"timestamp":1760000000,"storeId":%q,"invoiceId":%q,
"metadata":{"buyerEmail":"donor@example.com"},"manuallyMarked":false,"overPaid":false}`, typ, store, inv)
}

func (f *fakes) deliver(body, sig string) int {
	req := httptest.NewRequest(http.MethodPost, "/webhook", strings.NewReader(body))
	if sig != "" {
		req.Header.Set("BTCPay-Sig", sig)
	}
	rec := httptest.NewRecorder()
	f.srv.handleWebhook(rec, req)
	return rec.Code
}

func (f *fakes) pushCount() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.pushes)
}

func TestSignature(t *testing.T) {
	body := event("InvoiceSettled", testStore, testInv)
	cases := []struct {
		name, sig string
		code      int
		pushes    int
	}{
		{"missing", "", 401, 0},
		{"no prefix", strings.TrimPrefix(sign(body), "sha256="), 401, 0},
		{"not hex", "sha256=zz", 401, 0},
		{"wrong secret", "sha256=" + strings.Repeat("ab", 32), 401, 0},
		{"other body", sign(body + " "), 401, 0},
		{"good", sign(body), 200, 1},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			f := newFakes(t)
			if code := f.deliver(body, c.sig); code != c.code {
				t.Fatalf("code %d, want %d", code, c.code)
			}
			if n := f.pushCount(); n != c.pushes {
				t.Fatalf("%d pushes, want %d", n, c.pushes)
			}
			if c.code == 401 && f.gfCalls.Load() != 0 {
				t.Fatal("greenfield asked for an unsigned delivery")
			}
		})
	}
}

func TestUnsignedAnswerSaysNothing(t *testing.T) {
	f := newFakes(t)
	req := httptest.NewRequest(http.MethodPost, "/webhook", strings.NewReader("{}"))
	req.Header.Set("BTCPay-Sig", "sha256=00")
	rec := httptest.NewRecorder()
	f.srv.handleWebhook(rec, req)
	if rec.Code != 401 || rec.Body.Len() != 0 {
		t.Fatalf("%d %q", rec.Code, rec.Body.String())
	}
}

func TestOtherEventsAndStoresIgnored(t *testing.T) {
	for _, body := range []string{
		event("InvoiceCreated", testStore, testInv),
		event("InvoiceProcessing", testStore, testInv),
		event("InvoicePaymentSettled", testStore, testInv),
		event("invoicesettled", testStore, testInv),
		event("InvoiceSettled", "OtherStore99", testInv),
		event("InvoiceSettled", "", testInv),
		event("InvoiceSettled", testStore, "__test__0f2c__test__"),
		event("InvoiceSettled", testStore, "../../x"),
	} {
		f := newFakes(t)
		if code := f.deliver(body, sign(body)); code != 200 {
			t.Fatalf("code %d for %s", code, body)
		}
		if f.gfCalls.Load() != 0 || f.pushCount() != 0 {
			t.Fatalf("acted on %s", body)
		}
	}
}

func TestMessageIsAmountOnly(t *testing.T) {
	f := newFakes(t)
	body := event("InvoiceSettled", testStore, testInv)
	if code := f.deliver(body, sign(body)); code != 200 {
		t.Fatalf("code %d", code)
	}
	if f.pushCount() != 1 {
		t.Fatalf("%d pushes", f.pushCount())
	}
	got := f.bodies[0]
	if got != "Kryfo: a donation of 50 USD settled" {
		t.Fatalf("message %q", got)
	}
	r := f.pushes[0]
	if r.URL.Path != "/secret-topic" || r.Method != http.MethodPost {
		t.Fatalf("pushed to %s %s", r.Method, r.URL.Path)
	}
	if r.Header.Get("Title") != "Kryfo donation" || r.Header.Get("Priority") != "low" {
		t.Fatalf("headers %v", r.Header)
	}
	// nothing of the invoice in the body, the headers or the url
	all := got + r.URL.String()
	for k, v := range r.Header {
		all += k + strings.Join(v, ",")
	}
	for _, leak := range []string{testInv, testStore, "donor", "Donor", "order-77", "patron",
		"pay.example", "1760000000", "Click", "Tags", "Attach", "Email"} {
		if strings.Contains(all, leak) {
			t.Fatalf("push carries %q", leak)
		}
	}
	for _, leak := range []string{testInv, "50", "USD", "secret-topic", "donor"} {
		if strings.Contains(f.logs.String(), leak) {
			t.Fatalf("log carries %q: %s", leak, f.logs.String())
		}
	}
}

func TestText(t *testing.T) {
	cases := []struct{ amount, cur, want string }{
		{"50", "USD", "Kryfo: a donation of 50 USD settled"},
		{"50.00", "USD", "Kryfo: a donation of 50 USD settled"},
		{"12.50", "EUR", "Kryfo: a donation of 12.50 EUR settled"},
		{"0.00021", "BTC", "Kryfo: a donation of 0.00021 BTC settled"},
		{"5000", "SATS", "Kryfo: a donation of 5000 SATS settled"},
	}
	for _, c := range cases {
		got, err := text(c.amount, c.cur)
		if err != nil || got != c.want {
			t.Fatalf("%s %s: %q %v", c.amount, c.cur, got, err)
		}
	}
	for _, bad := range [][2]string{
		{"", "USD"}, {"50", ""}, {"-5", "USD"}, {"5e3", "USD"}, {"50 from Ann", "USD"},
		{"50", "usd"}, {"50", "USD\nTitle: x"}, {"1.2.3", "USD"},
	} {
		if got, err := text(bad[0], bad[1]); err == nil {
			t.Fatalf("%q %q made %q", bad[0], bad[1], got)
		}
	}
}

func TestRedeliveryPushesOnce(t *testing.T) {
	f := newFakes(t)
	body := event("InvoiceSettled", testStore, testInv)
	redelivery := strings.Replace(body, `"isRedelivery":false`, `"isRedelivery":true`, 1)
	for i := 0; i < 3; i++ {
		f.deliver(body, sign(body))
		f.deliver(redelivery, sign(redelivery))
	}
	if f.pushCount() != 1 {
		t.Fatalf("%d pushes", f.pushCount())
	}
}

func TestDeliveriesAtOnceForOneInvoicePushOnce(t *testing.T) {
	f := newFakes(t)
	body := event("InvoiceSettled", testStore, testInv)
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			f.deliver(body, sign(body))
		}()
	}
	wg.Wait()
	if f.pushCount() != 1 {
		t.Fatalf("%d pushes", f.pushCount())
	}
}

func TestFailedPushIsTriedAgain(t *testing.T) {
	f := newFakes(t)
	body := event("InvoiceSettled", testStore, testInv)
	f.ntfyStatus.Store(500)
	if code := f.deliver(body, sign(body)); code != 502 {
		t.Fatalf("code %d, want 502 so btcpay sends it again", code)
	}
	f.ntfyStatus.Store(200)
	if code := f.deliver(body, sign(body)); code != 200 {
		t.Fatalf("code %d", code)
	}
	if f.pushCount() != 2 {
		t.Fatalf("%d pushes", f.pushCount())
	}
	f.deliver(body, sign(body))
	if f.pushCount() != 2 {
		t.Fatal("pushed again after a good push")
	}
}

func TestGreenfieldDownIsTriedAgain(t *testing.T) {
	f := newFakes(t)
	body := event("InvoiceSettled", testStore, testInv)
	f.gfStatus.Store(503)
	if code := f.deliver(body, sign(body)); code != 502 {
		t.Fatalf("code %d", code)
	}
	if f.pushCount() != 0 {
		t.Fatal("pushed without an amount")
	}
	f.gfStatus.Store(200)
	f.deliver(body, sign(body))
	if f.pushCount() != 1 {
		t.Fatalf("%d pushes", f.pushCount())
	}
}

func TestUnsettledOrOddInvoiceNotPushed(t *testing.T) {
	for _, inv := range []string{
		strings.Replace(fullInvoice, `"Settled"`, `"Processing"`, 1),
		strings.Replace(fullInvoice, `"50.00"`, `"50.00 thanks Ann"`, 1),
		`not json`,
	} {
		f := newFakes(t)
		f.gfBody.Store(inv)
		body := event("InvoiceSettled", testStore, testInv)
		f.deliver(body, sign(body))
		if f.pushCount() != 0 {
			t.Fatalf("pushed for %s", inv)
		}
	}
}

func TestBodyCap(t *testing.T) {
	f := newFakes(t)
	pad := strings.Repeat("x", maxBody)
	body := strings.Replace(event("InvoiceSettled", testStore, testInv), `"buyerEmail"`, `"pad":"`+pad+`","buyerEmail"`, 1)
	if code := f.deliver(body, sign(body)); code != http.StatusRequestEntityTooLarge {
		t.Fatalf("code %d", code)
	}
	if f.pushCount() != 0 || f.gfCalls.Load() != 0 {
		t.Fatal("acted on an oversized body")
	}
	// just under the cap still works
	small := event("InvoiceSettled", testStore, testInv)
	if code := f.deliver(small, sign(small)); code != 200 || f.pushCount() != 1 {
		t.Fatalf("code %d", code)
	}
}

func TestGetRefused(t *testing.T) {
	f := newFakes(t)
	rec := httptest.NewRecorder()
	f.srv.handleWebhook(rec, httptest.NewRequest(http.MethodGet, "/webhook", nil))
	if rec.Code != 405 {
		t.Fatalf("code %d", rec.Code)
	}
}

func TestIDSetIsBounded(t *testing.T) {
	s := newIDSet(3)
	for _, id := range []string{"a", "b", "c", "d"} {
		if !s.take(id) {
			t.Fatalf("%s seen", id)
		}
	}
	if len(s.ids) != 3 || len(s.ring) != 3 {
		t.Fatalf("%d %d", len(s.ids), len(s.ring))
	}
	if s.take("d") || s.take("c") {
		t.Fatal("recent id taken twice")
	}
	if !s.take("a") {
		t.Fatal("oldest id not dropped")
	}
	s.drop("a")
	if !s.take("a") {
		t.Fatal("dropped id not free")
	}
}
