// SPDX-License-Identifier: GPL-3.0-or-later
//go:build moatlive && torconf

// which country moat names over meek. each sample takes one tor exit and
// asks moat twice from it: through meek, and straight. moat names the
// exit's country for the straight one, so where the two agree, moat saw
// the address the request came from through meek as well.
//
//	go test -tags 'moatlive torconf' -run TestMoatCountryOverMeek -v .
package main

import (
	"context"
	"fmt"
	"net/http"
	"testing"
)

func TestMoatCountryOverMeek(t *testing.T) {
	bootDirect(t)
	setDecoy(false)
	old := meekNetDial
	defer func() { meekNetDial, moatTransport = old, moatTransportFor }()
	body := map[string]any{"transports": []string{"obfs4", "snowflake", "webtunnel"}}
	same, n := 0, 0
	for i := 0; i < 12; i++ {
		d, err := torDialerAs(context.Background(), node(t), fmt.Sprintf("country-%d", i))
		if err != nil {
			t.Fatal(err)
		}
		meekNetDial = d.DialContext
		moatTransport = moatTransportFor
		meek, err := moatSettingsCall(moatOpts{Consent: true, Via: viaMeek, Transports: []string{"obfs4"}})
		if err != nil {
			t.Logf("sample %d: meek: %v", i, err)
			continue
		}
		moatTransport = func(_ string, md *moatDials) (*http.Transport, error) {
			rt, err := moatTransportFor(viaPlain, md)
			if err != nil {
				return nil, err
			}
			rt.DialContext = d.DialContext
			return rt, nil
		}
		raw, code, err := moatDo(moatOpts{Consent: true, Via: viaPlain}, "POST", "/circumvention/settings", body)
		if err != nil {
			t.Logf("sample %d: straight: %v", i, err)
			continue
		}
		straight, _ := readMoatSettings(raw, code)
		n++
		if meek.Country == straight.Country {
			same++
		}
		t.Logf("sample %d: over meek %s, straight %s", i, meek.Country, straight.Country)
	}
	t.Logf("%d of %d samples agree", same, n)
}
