// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the handle registry, people search and the badge service go over tor on
// every route. the registry runs on our relay's box: asked directly, it
// could put a handle next to the ip that reads that phone's mailboxes. tor
// runs on every route for the onion door, so it is there to carry them.
// the gif lane is not one of these: it follows the route.

import (
	"context"
	"fmt"
	"net/http"
	"time"
)

// how often a call waiting for tor looks again
var servicesPoll = 250 * time.Millisecond

// people search and the badge calls: the wait for tor and the request
// together. the app waits 80 s (main.dart, torPost)
var servicesWait = 45 * time.Second

// the services lane's client, through tor whatever the route. a tor not
// started yet is waited for until ctx ends
func servicesClient(ctx context.Context) (*http.Client, error) {
	for {
		c, err := servicesTorClient()
		if err == nil {
			return c, nil
		}
		t := time.NewTimer(servicesPoll)
		select {
		case <-ctx.Done():
			t.Stop()
			return nil, err
		case <-t.C:
		}
	}
}

func servicesTorClient() (*http.Client, error) {
	// the onion route's own lane client is tor already
	if modeNeedsTor() {
		return torNostrClientFor(laneServices)
	}
	// kept beside the route's clients, so a mode switch or a new tor drops
	// it with them
	key := "tor:" + laneServices
	cachedNostrClientMu.Lock()
	defer cachedNostrClientMu.Unlock()
	if c := cachedNostrClients[key]; c != nil {
		return c, nil
	}
	mu.Lock()
	t := torNode
	mu.Unlock()
	if t == nil {
		return nil, fmt.Errorf("tor not started")
	}
	d, err := torDialerAs(context.Background(), t, laneName(laneServices))
	if err != nil {
		return nil, fmt.Errorf("tor dialer: %v", err)
	}
	c := &http.Client{
		Transport: &http.Transport{
			DialContext:           d.DialContext,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 10 * time.Second,
		},
		Timeout: 60 * time.Second,
		// the registry answers where it is asked
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	cachedNostrClients[key] = c
	return c, nil
}
