package main

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
)

// a sealed token as the app makes one: base64url, always 480 characters
func sealedEP(i int) string {
	tok := fmt.Sprintf("x%03d", i) + strings.Repeat("A_-", 200)
	return "https://relay.kryfo.app/push/" + tok[:knockSealedMax]
}

func TestKnockGatewayEndpoints(t *testing.T) {
	good := sealedEP(1)
	for _, c := range []struct {
		url string
		ok  bool
	}{
		{good, true},
		// the port written out makes the endpoint longer than the relay takes
		{strings.Replace(good, "kryfo.app/", "kryfo.app:443/", 1), false},
		{strings.Replace(good, "kryfo.app/", "kryfo.app:8443/", 1), false},
		{good + "?up=1", false},
		{good + "?", false},
		{good + "/more", false},
		{good + "%2F", false},
		{good + "=", false},
		{strings.Replace(good, "A", "+", 1), false},
		{"https://relay.kryfo.app/push/" + strings.Repeat("A", knockSealedMin-1), false},
		{"https://relay.kryfo.app/push/" + strings.Repeat("A", 244), false},
		{"https://relay.kryfo.app/push/" + strings.Repeat("A", knockSealedMax+1), false},
		{"https://relay.kryfo.app/push/", false},
		{"https://relay.kryfo.app/up" + strings.Repeat("A", 100), false},
		{"https://relay.kryfo.app/gif/" + strings.Repeat("A", 100), false},
		{"http://relay.kryfo.app/push/" + strings.Repeat("A", 100), false},
		// nothing else of ours is a push server
		{strings.Replace(good, "relay.kryfo.app", "kryfo.app", 1), false},
		{strings.Replace(good, "relay.kryfo.app", "gif.kryfo.app", 1), false},
		{strings.Replace(good, "relay.kryfo.app", "RELAY.kryfo.app", 1), true},
	} {
		if got := knockEndpointOK(c.url, false); got != c.ok {
			t.Errorf("%q: got %v, want %v", c.url, got, c.ok)
		}
	}
}

func TestKnockGatewayCanBeTurnedOff(t *testing.T) {
	t.Setenv("RELAY_KNOCK_GATEWAY", "")
	k := newKnocker(nil, false)
	if k.push["kryfo.app"] {
		t.Fatal("the gateway's domain is a known push server with the gateway off")
	}
	// then its endpoints are any other server's
	if !knockEndpointOK("https://relay.kryfo.app/push/"+strings.Repeat("A", 100)+"?up=1", false) {
		t.Fatal("the gateway's rules hold with the gateway off")
	}
}

func TestKnockGatewayHasItsOwnShare(t *testing.T) {
	tk := newTestKnocks(t)
	// the box's own name is never looked up for the gateway
	tk.lookup = func(_ context.Context, host string) ([]net.IP, error) {
		t.Errorf("looked up %s", host)
		return nil, &net.DNSError{Err: "no such host", Name: host, IsNotFound: true}
	}
	// a phone's sixteen sealed endpoints, one each
	for i := 0; i < 16; i++ {
		register(t, tk, sealedEP(i))
	}
	tk.mu.Lock()
	defer tk.mu.Unlock()
	name, sh := tk.shareOf("kryfo.app")
	if name != "kryfo.app" {
		t.Fatalf("the gateway counts in share %q", name)
	}
	if sh.eps != 16 || sh.epCap != knockGatewayEPs {
		t.Fatalf("share holds %d of %d", sh.eps, sh.epCap)
	}
	if _, common := tk.shares[""]; common && tk.shares[""].eps != 0 {
		t.Fatal("the gateway's endpoints fill the common share")
	}
}

// on its own box the relay posts to the gateway on loopback, the same path,
// with no name looked up; every other endpoint goes the usual way
func TestKnockGatewayPostedOnLoopback(t *testing.T) {
	var mu sync.Mutex
	var paths []string
	local := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		paths = append(paths, r.Method+" "+r.URL.Path+" "+r.Header.Get("Urgency"))
		mu.Unlock()
		w.WriteHeader(http.StatusCreated)
	}))
	defer local.Close()
	addr := strings.TrimPrefix(local.URL, "http://")

	var others []string
	usual := func(_ context.Context, ep string) (int, error) {
		others = append(others, ep)
		return 201, nil
	}
	post := knockPosterVia(usual, "relay.kryfo.app", addr)
	ep := sealedEP(3)
	if code, err := post(context.Background(), ep); err != nil || code != 201 {
		t.Fatalf("gateway post %d %v", code, err)
	}
	if code, _ := post(context.Background(), "https://ntfy.sh/upAbc?up=1"); code != 201 {
		t.Fatal("ntfy post")
	}
	mu.Lock()
	defer mu.Unlock()
	want := "POST " + strings.TrimPrefix(ep, "https://relay.kryfo.app") + " high"
	if len(paths) != 1 || paths[0] != want {
		t.Fatalf("loopback saw %v", paths)
	}
	if len(others) != 1 || others[0] != "https://ntfy.sh/upAbc?up=1" {
		t.Fatalf("the usual way saw %v", others)
	}
}

func TestKnockGatewayLocalMustBeLoopback(t *testing.T) {
	called := 0
	usual := func(context.Context, string) (int, error) { called++; return 201, nil }
	for _, local := range []string{"", "8.8.8.8:3340", "relay.kryfo.app:3340", "127.0.0.1", "localhost:3340"} {
		post := knockPosterVia(usual, "relay.kryfo.app", local)
		post(context.Background(), sealedEP(1))
	}
	if called != 5 {
		t.Fatalf("a post went somewhere other than the usual way: %d of 5", called)
	}
}

func TestKnockGatewaySendSkipsTheLookup(t *testing.T) {
	tk := newTestKnocks(t)
	tk.gatewayLocal = "127.0.0.1:3340"
	tk.q.resolve = func(_ context.Context, host string) ([]net.IP, error) {
		t.Errorf("resolved %s", host)
		return nil, errNotPublic
	}
	var posted []string
	tk.q.post = func(_ context.Context, ep string) (int, error) {
		posted = append(posted, ep)
		return 201, nil
	}
	ep := sealedEP(5)
	register(t, tk, ep)
	tk.mu.Lock()
	e := tk.eps[ep]
	tk.mu.Unlock()
	tk.q.send(context.Background(), e, false)
	if len(posted) != 1 || posted[0] != ep {
		t.Fatalf("posted %v", posted)
	}
	tk.mu.Lock()
	delivered := e.delivered
	tk.mu.Unlock()
	if !delivered {
		t.Fatal("a 201 from the gateway did not count as delivered")
	}
}

// the gateway's share is sized for many play phones, sixteen endpoints each
func TestKnockGatewayShareIsSizedForPhones(t *testing.T) {
	tk := newTestKnocks(t)
	tk.mu.Lock()
	defer tk.mu.Unlock()
	_, gw := tk.shareOf("kryfo.app")
	_, ntfy := tk.shareOf("ntfy.sh")
	if gw.epCap != knockGatewayEPs || gw.epCap < 16*10000 {
		t.Fatalf("the gateway's share holds %d endpoints", gw.epCap)
	}
	if ntfy.epCap != knockPushHostEPs {
		t.Fatalf("ntfy's share changed to %d", ntfy.epCap)
	}
}

// on our box the relay reaches the gateway on loopback by default, and a
// setting that is not loopback leaves lookup and post the usual way alike
func TestKnockGatewayLocalDefaults(t *testing.T) {
	for _, c := range []struct {
		set   bool
		v, gw string
		want  string
	}{
		{false, "", "relay.kryfo.app", "127.0.0.1:3340"},
		{true, "", "relay.kryfo.app", "127.0.0.1:3340"},
		{true, "127.0.0.1:4000", "relay.kryfo.app", "127.0.0.1:4000"},
		{true, "off", "relay.kryfo.app", ""},
		{true, "8.8.8.8:3340", "relay.kryfo.app", ""},
		{false, "", "push.example.org", ""},
		{true, "127.0.0.1:3340", "", ""},
	} {
		if c.set {
			t.Setenv("RELAY_KNOCK_GATEWAY_LOCAL", c.v)
		} else {
			// set first, so the test puts back what was there
			t.Setenv("RELAY_KNOCK_GATEWAY_LOCAL", "")
			os.Unsetenv("RELAY_KNOCK_GATEWAY_LOCAL")
		}
		if got := knockGatewayLocal(c.gw); got != c.want {
			t.Errorf("%+v: %q", c, got)
		}
	}
}
