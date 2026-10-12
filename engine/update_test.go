// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// a server for the update lane, and the socks names the lane dialled under
func updateServer(t *testing.T, h http.HandlerFunc) (*httptest.Server, *[]string) {
	srv := httptest.NewServer(h)
	var names []string
	oldBase, oldDial := updateBase, updateDial
	updateBase = srv.URL + "/"
	updateDial = func(name string) (dialFn, error) {
		names = append(names, name)
		var d net.Dialer
		return d.DialContext, nil
	}
	updateResetClient()
	t.Cleanup(func() {
		srv.Close()
		updateBase, updateDial = oldBase, oldDial
		updateResetClient()
	})
	return srv, &names
}

func TestUpdateHasItsOwnCircuit(t *testing.T) {
	var ua []string
	srv, names := updateServer(t, func(w http.ResponseWriter, r *http.Request) {
		ua = append(ua, r.Header.Get("User-Agent"))
		if r.Method != http.MethodGet || r.URL.RawQuery != "" || r.ContentLength > 0 {
			http.Error(w, "plain get only", http.StatusBadRequest)
			return
		}
		fmt.Fprint(w, `{"app":"kryfo","version":"0.5.1"}`)
	})
	if out := updateGet(srv.URL + "/version.json"); out != `{"app":"kryfo","version":"0.5.1"}` {
		t.Fatalf("got %q", out)
	}
	updateGet(srv.URL + "/version.json.sig")
	if len(*names) != 1 {
		t.Fatalf("dialled %d clients, want one kept", len(*names))
	}
	got := (*names)[0]
	if got != laneName(laneUpdate) {
		t.Fatalf("socks name %q is not the update lane's", got)
	}
	// link previews dial with no name; every other lane has its own
	for _, other := range []string{"", laneName(laneServices), laneName(laneGifs), laneName(laneEveryday)} {
		if got == other {
			t.Fatalf("the update check shares an isolation key: %q", got)
		}
	}
	for _, u := range ua {
		if u != "" {
			t.Fatalf("sent a user agent: %q", u)
		}
	}
}

func TestUpdateGetAnswers(t *testing.T) {
	srv, _ := updateServer(t, func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/gone":
			http.NotFound(w, r)
		case "/moved":
			http.Redirect(w, r, "/version.json", http.StatusFound)
		case "/full":
			fmt.Fprint(w, strings.Repeat("x", updateGetMax))
		default:
			fmt.Fprint(w, strings.Repeat("x", 9000))
		}
	})
	if out := updateGet(srv.URL + "/big"); out != "error: read: too big" {
		t.Fatalf("past the cap: %d bytes", len(out))
	}
	if out := updateGet(srv.URL + "/full"); len(out) != updateGetMax {
		t.Fatalf("at the cap: %q", out)
	}
	if out := updateGet(srv.URL + "/gone"); out != "error: status 404" {
		t.Fatalf("got %q", out)
	}
	if out := updateGet(srv.URL + "/moved"); out != "error: status 302" {
		t.Fatalf("followed a redirect: %q", out)
	}
	if out := updateGet("https://example.com/version.json"); !strings.HasPrefix(out, "error: req") {
		t.Fatalf("asked another site: %q", out)
	}
}

func TestUpdateWithoutTor(t *testing.T) {
	oldDial := updateDial
	updateDial = func(string) (dialFn, error) { return nil, fmt.Errorf("not started") }
	updateResetClient()
	t.Cleanup(func() { updateDial = oldDial; updateResetClient() })
	if out := updateGet(updateBase + "version.json"); !strings.HasPrefix(out, "error: tor") {
		t.Fatalf("got %q", out)
	}
}
