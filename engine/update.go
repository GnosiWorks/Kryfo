// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the app's update check: a plain GET to kryfo.app over tor and nothing
// else, on a circuit of its own, so the site cannot tie the check to a link
// preview or any other lane. no user agent, nothing of the phone in it.

import "C"

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

// the only place the check may ask; tests point it at their own server
var updateBase = "https://kryfo.app/"

type dialFn func(ctx context.Context, network, addr string) (net.Conn, error)

// how the update lane dials: through tor under the socks name given. tests
// stand their own in
var updateDial = func(name string) (dialFn, error) {
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil {
		return nil, fmt.Errorf("not started")
	}
	d, err := torDialerAs(context.Background(), t, name)
	if err != nil {
		return nil, err
	}
	return d.DialContext, nil
}

var (
	updateMu     sync.Mutex
	updateClient *http.Client
)

func updateHTTP() (*http.Client, error) {
	updateMu.Lock()
	defer updateMu.Unlock()
	if updateClient != nil {
		return updateClient, nil
	}
	dial, err := updateDial(laneName(laneUpdate))
	if err != nil {
		return nil, err
	}
	updateClient = &http.Client{
		Transport: &http.Transport{
			DialContext:           dial,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 10 * time.Second,
		},
		Timeout: 30 * time.Second,
		// the files are where they are: a redirect is not followed
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	return updateClient, nil
}

// the client dials the tor it was built on, so a restart drops it
func updateResetClient() {
	updateMu.Lock()
	updateClient = nil
	updateMu.Unlock()
}

// GET a file of kryfo.app over tor, on the update lane. the body of a 200,
// capped at 4kb, or "error: ...": "error: status" and "error: read" when
// the site answered, "error: tor" and "error: get" when it was not reached.
//
//export HaloUpdateGet
func HaloUpdateGet(cUrl *C.char) *C.char {
	return C.CString(updateGet(goStr(cUrl)))
}

const updateGetMax = 4096

func updateGet(url string) string {
	if !strings.HasPrefix(url, updateBase) {
		return "error: req: not " + updateBase
	}
	client, err := updateHTTP()
	if err != nil {
		return fmt.Sprintf("error: tor: %v", err)
	}
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return fmt.Sprintf("error: req: %v", err)
	}
	req.Header.Set("User-Agent", "")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return fmt.Sprintf("error: get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Sprintf("error: status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, updateGetMax+1))
	if err != nil {
		return fmt.Sprintf("error: read: %v", err)
	}
	// cut short it would read as a whole file
	if len(body) > updateGetMax {
		return "error: read: too big"
	}
	return string(body)
}
