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

import "C"

// how often a call waiting for tor looks again
var servicesPoll = 250 * time.Millisecond

// people search and the badge calls: the wait for tor and the request
// together. the app waits 80 s (app/engine.dart, torPost)
var servicesWait = 45 * time.Second

// the services lane's client, through tor whatever the route. a tor not
// started yet is waited for until ctx ends
func servicesClient(ctx context.Context) (*http.Client, error) {
	return servicesClientOf(ctx, servicesTorClient)
}

func servicesClientOf(ctx context.Context, of func() (*http.Client, error)) (*http.Client, error) {
	for {
		c, err := of()
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

// built from tor's socks port in every mode, never from the route's client,
// so a mode switch under the call cannot hand it a direct one
func servicesTorClient() (*http.Client, error) {
	return servicesTorClientAs(laneServices, laneName(laneServices))
}

// the client of [lane] whose circuits go under the socks name [name]
func servicesTorClientAs(lane, name string) (*http.Client, error) {
	// kept beside the route's clients, so a mode switch or a new tor drops
	// it with them
	key := "tor:" + lane
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
	d, err := torDialerAs(context.Background(), t, name)
	if err != nil {
		return nil, fmt.Errorf("tor dialer: %v", err)
	}
	// as every lane's over tor: no redirect is followed
	c := torLaneClient(d.DialContext)
	cachedNostrClients[key] = c
	return c, nil
}

// the own handle's lane: through tor whatever the route, as above
func ownHandleClient(ctx context.Context) (*http.Client, error) {
	return servicesClientOf(ctx, func() (*http.Client, error) {
		return servicesTorClientAs(laneOwnHandle, laneName(laneOwnHandle))
	})
}

// a client for one people search: a socks name made for it alone and no
// kept connection, so two searches never share a circuit or a socket
func searchClient(ctx context.Context) (*http.Client, error) {
	name := freshSocksName()
	return servicesClientOf(ctx, func() (*http.Client, error) {
		mu.Lock()
		t := torNode
		mu.Unlock()
		if t == nil {
			return nil, fmt.Errorf("tor not started")
		}
		d, err := torDialerAs(context.Background(), t, name)
		if err != nil {
			return nil, fmt.Errorf("tor dialer: %v", err)
		}
		c := torLaneClient(d.DialContext)
		c.Transport.(*http.Transport).DisableKeepAlives = true
		return c, nil
	})
}

// people search over tor, a new circuit for each search
//
//export HaloSearchPost
func HaloSearchPost(cUrl *C.char, cBody *C.char) *C.char {
	return C.CString(searchPost(goStr(cUrl), goStr(cBody)))
}

func searchPost(url, body string) string { return torPostOn(url, body, searchClient) }

// a lookup of this phone's own handle (the repoint check), on its lane
//
//export HaloOwnHandleGetJSON
func HaloOwnHandleGetJSON(cUrl *C.char) *C.char {
	return C.CString(ownHandleGetJSON(goStr(cUrl)))
}

func ownHandleGetJSON(url string) string { return torGetJSONOn(url, ownHandleClient) }
