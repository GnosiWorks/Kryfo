// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the built-in bridges: the set tor browser ships, from moat's builtin
// call. builtin.json is refreshed at release by scripts/builtin-bridges.sh
// and its diff read by hand. once tor is up the set is refreshed through
// tor every week, and a refreshed line only replaces a bundled one with the
// same transport, fingerprint and address whose every host is on
// reviewedHosts. anything else waits for the next release.

import "C"

import (
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"log"
	"net"
	"net/url"
	"sort"
	"strings"
	"sync"
	"time"
)

//go:embed builtin.json
var builtinJSON []byte

var builtinBundled = func() map[string][]string {
	var m map[string][]string
	if err := json.Unmarshal(builtinJSON, &m); err != nil {
		panic("builtin.json: " + err.Error())
	}
	return m
}()

// which bundle a refresh was made against. a refresh from an older
// release is dropped.
var builtinBase = func() string {
	h := sha256.Sum256(builtinJSON)
	return hex.EncodeToString(h[:8])
}()

// every host name moat or a snowflake line from moat or the built-ins may
// make kryfo reach outside tor, reviewed at release: moat's reflector and
// fronts, the snowflake broker, its fronts and stun servers. a test holds
// builtin.json and moatTargets to it, and the release script names any
// host moat uses that is not here.
var reviewedHosts = map[string]bool{
	// moat over meek
	"1723079976.rsc.cdn77.org": true,
	"cdn.zk.mk":                true,
	"www.cdn77.com":            true,
	// snowflake broker and fronts, the built-in ones and those moat hands
	// out per country
	"1098762253.rsc.cdn77.org": true,
	"app.datapacket.com":       true,
	"www.datapacket.com":       true,
	"www.phpmyadmin.net":       true,
	"img.icons8.com":           true,
	"cdn.kde.org":              true,
	// snowflake stun
	"stun.antisip.com":    true,
	"stun.epygi.com":      true,
	"stun.uls.co.za":      true,
	"stun.voipgate.com":   true,
	"stun.mixvoip.com":    true,
	"stun.telnyx.com":     true,
	"stun.hot-chilli.net": true,
	"stun.fitauto.ru":     true,
	"stun.m-online.net":   true,
}

func hostAllowed(h string) bool {
	return reviewedHosts[strings.ToLower(strings.TrimSuffix(h, "."))]
}

func urlHost(s string) string {
	u, err := url.Parse(s)
	if err != nil {
		return ""
	}
	return u.Hostname()
}

// the arguments a built-in line may carry, per transport. a refreshed line
// with anything else is not used.
var builtinArgs = map[string]map[string]bool{
	"obfs4":     {"cert": true, "iat-mode": true},
	"webtunnel": {"url": true, "ver": true, "servername": true, "utls": true},
	"snowflake": {"fingerprint": true, "url": true, "fronts": true, "front": true,
		"ice": true, "utls-imitate": true},
}

// the host names in a line's arguments, and false if it has an argument a
// built-in line may not have
func lineHosts(b bridgeLine) ([]string, bool) {
	allowed := builtinArgs[b.transport]
	var hosts []string
	for k, vs := range b.args {
		if !allowed[k] {
			return nil, false
		}
		for _, v := range vs {
			switch k {
			case "url":
				h := urlHost(v)
				if h == "" {
					return nil, false
				}
				hosts = append(hosts, h)
			case "servername":
				hosts = append(hosts, v)
			case "front", "fronts":
				hosts = append(hosts, splitList(v)...)
			case "ice":
				for _, s := range splitList(v) {
					s = strings.TrimPrefix(strings.ToLower(s), "stun:")
					h, _, err := net.SplitHostPort(s)
					if err != nil {
						return nil, false
					}
					hosts = append(hosts, h)
				}
			}
		}
	}
	return hosts, true
}

// a line kryfo may use as a built-in: tor takes it, its arguments are the
// kinds a built-in line has, and every host in it was reviewed
func builtinLineOK(ln string) (bridgeLine, bool) {
	fixed, _ := normaliseBridgeLine(ln)
	b, err := checkBridgeLine(fixed)
	if err != nil || b.fp == "" {
		return b, false
	}
	hosts, ok := lineHosts(b)
	if !ok {
		return b, false
	}
	for _, h := range hosts {
		if !hostAllowed(h) {
			return b, false
		}
	}
	return b, true
}

// the refreshed lines in use, when the refresh was, and when one last
// failed
var (
	builtinMu       sync.Mutex
	builtinFresh    map[string][]string
	builtinFreshAt  time.Time
	builtinFailedAt time.Time
)

// how often the built-ins are refreshed through tor, and how long a failed
// refresh waits before the next try
var (
	builtinRefreshEvery = 7 * 24 * time.Hour
	builtinRetryAfter   = 6 * time.Hour
)

// keeps the refreshed lines that may stand in for a bundled one. returns
// the lines kept per transport, and how many were left out.
func acceptRefreshed(fresh map[string][]string) (map[string][]string, int) {
	kept := map[string][]string{}
	ignored := 0
	for t, lines := range fresh {
		if builtinArgs[t] == nil {
			continue
		}
		for _, ln := range lines {
			b, ok := builtinLineOK(ln)
			if !ok || b.transport != t || !bundledMatch(b) {
				ignored++
				continue
			}
			fixed, _ := normaliseBridgeLine(ln)
			kept[t] = append(kept[t], fixed)
		}
	}
	return kept, ignored
}

// a bundled line with the same transport, fingerprint and address
func bundledMatch(b bridgeLine) bool {
	for _, ln := range builtinBundled[b.transport] {
		o, err := parseBridgeLine(ln)
		if err == nil && o.fp == b.fp && bridgeAddrKey(o.addr) == bridgeAddrKey(b.addr) {
			return true
		}
	}
	return false
}

// the built-in lines for a transport: the bundled ones, each replaced by a
// refreshed one with its fingerprint when there is one
func builtinLines(transport string) []string {
	builtinMu.Lock()
	fresh := builtinFresh[transport]
	builtinMu.Unlock()
	var out []string
	for _, ln := range builtinBundled[transport] {
		b, ok := builtinLineOK(ln)
		if !ok {
			continue
		}
		use, _ := normaliseBridgeLine(ln)
		for _, f := range fresh {
			if o, err := parseBridgeLine(f); err == nil && o.fp == b.fp {
				use = f
			}
		}
		out = append(out, use)
	}
	return out
}

func builtinRefreshDue() bool {
	builtinMu.Lock()
	defer builtinMu.Unlock()
	return builtinFreshAt.IsZero() || time.Since(builtinFreshAt) >= builtinRefreshEvery
}

// a refresh that went out and failed holds the next one off a while,
// forced or not
func builtinBackingOff() bool {
	builtinMu.Lock()
	defer builtinMu.Unlock()
	return !builtinFailedAt.IsZero() && time.Since(builtinFailedAt) < builtinRetryAfter
}

// asks moat for the built-ins through tor and keeps what passes
func refreshBuiltin(o moatOpts) (int, int, error) {
	o.Via, o.Automatic, o.Transports = viaTor, true, nil
	fresh, err := moatBuiltinCall(o)
	switch err {
	case nil:
	case errMoatConsent, errMoatDecoy, errMoatNoTor, errMoatArgs:
		// refused before anything went out
		return 0, 0, err
	default:
		builtinMu.Lock()
		builtinFailedAt = time.Now()
		builtinMu.Unlock()
		return 0, 0, err
	}
	kept, ignored := acceptRefreshed(fresh)
	n := 0
	for _, l := range kept {
		n += len(l)
	}
	builtinMu.Lock()
	builtinFresh, builtinFreshAt, builtinFailedAt = kept, time.Now(), time.Time{}
	builtinMu.Unlock()
	log.Printf("bridges: built-ins refreshed, %d kept, %d left out", n, ignored)
	return n, ignored, nil
}

// the built-in lines for one transport. {"ok":true,"lines":[...]}
//
//export HaloBuiltinBridges
func HaloBuiltinBridges(cTransport *C.char) *C.char {
	return C.CString(builtinBridgesJSON(goStr(cTransport)))
}

func builtinBridgesJSON(transport string) string {
	t := strings.ToLower(transport)
	if builtinArgs[t] == nil {
		return moatReply(nil, errMoatArgs)
	}
	return moatReply(map[string]any{"lines": append([]string{}, builtinLines(t)...)}, nil)
}

// refreshes the built-ins through tor, at most once a week unless opts has
// "force", and never within hours of a failed try. opts as moatOpts,
// consent included; via is always tor.
// {"ok":true,"kept":n,"ignored":n} or {"ok":true,"skipped":true}
//
//export HaloBuiltinRefresh
func HaloBuiltinRefresh(cOpts *C.char) *C.char {
	return C.CString(builtinRefreshJSON(goStr(cOpts)))
}

func builtinRefreshJSON(opts string) string {
	var o struct {
		moatOpts
		Force bool `json:"force"`
	}
	if json.Unmarshal([]byte(opts), &o) != nil {
		return moatReply(nil, errMoatArgs)
	}
	if builtinBackingOff() || !o.Force && !builtinRefreshDue() {
		return moatReply(map[string]any{"skipped": true}, nil)
	}
	kept, ignored, err := refreshBuiltin(o.moatOpts)
	if err != nil {
		return moatReply(nil, err)
	}
	return moatReply(map[string]any{"kept": kept, "ignored": ignored}, nil)
}

// ---- what moat gave, kept between runs ----

// how long the settings from moat are used
var moatSettingsFor = 7 * 24 * time.Hour

// the whole settings reply lives in memory only: which transports moat
// listed, and in what order, says which country was asked about
var (
	moatCacheMu    sync.Mutex
	moatSettingsC  []moatSetting
	moatSettingsAt time.Time
)

func cacheMoatSettings(s []moatSetting) {
	moatCacheMu.Lock()
	moatSettingsC, moatSettingsAt = s, time.Now()
	moatCacheMu.Unlock()
}

// the cached settings while they are fresh
func moatSettingsCached() []moatSetting {
	moatCacheMu.Lock()
	defer moatCacheMu.Unlock()
	if moatSettingsAt.IsZero() || time.Since(moatSettingsAt) >= moatSettingsFor {
		return nil
	}
	return append([]moatSetting(nil), moatSettingsC...)
}

func dropMoatSettings() {
	moatCacheMu.Lock()
	moatSettingsC, moatSettingsAt = nil, time.Time{}
	moatCacheMu.Unlock()
}

// days since 1970, the only time the store keeps
func dayOf(t time.Time) int64 { return t.Unix() / 86400 }

func dayStart(d int64) time.Time { return time.Unix(d*86400, 0) }

// what the app keeps in its secure store and hands back at start: the
// refreshed built-ins, and of moat's settings only the lines tor has now,
// each with the day it came. no country, no order, no time of day.
type bridgeCacheWire struct {
	V       int `json:"v"`
	Builtin *struct {
		Base  string              `json:"base"`
		Day   int64               `json:"day"`
		Lines map[string][]string `json:"lines"`
	} `json:"builtin,omitempty"`
	Moat *struct {
		Day   int64    `json:"day"`
		Lines []string `json:"lines"`
	} `json:"moat,omitempty"`
}

func bridgeCacheOut() string {
	w := bridgeCacheWire{V: 2}
	builtinMu.Lock()
	if !builtinFreshAt.IsZero() {
		w.Builtin = &struct {
			Base  string              `json:"base"`
			Day   int64               `json:"day"`
			Lines map[string][]string `json:"lines"`
		}{builtinBase, dayOf(builtinFreshAt), builtinFresh}
	}
	builtinMu.Unlock()
	if s := moatSettingsCached(); s != nil {
		inUse := map[string]bool{}
		for _, ln := range bridgeLines() {
			inUse[ln] = true
		}
		var lines []string
		for _, one := range s {
			if one.Source != "bridgedb" {
				continue
			}
			for _, ln := range one.Lines {
				if inUse[ln] {
					lines = append(lines, ln)
				}
			}
		}
		if len(lines) > 0 {
			sort.Strings(lines)
			moatCacheMu.Lock()
			at := moatSettingsAt
			moatCacheMu.Unlock()
			w.Moat = &struct {
				Day   int64    `json:"day"`
				Lines []string `json:"lines"`
			}{dayOf(at), lines}
		}
	}
	b, _ := json.Marshal(w)
	return string(b)
}

// takes back what bridgeCacheOut gave. everything is checked again on the
// way in, and what is stale or from another release is dropped.
func bridgeCacheIn(s string) {
	var w bridgeCacheWire
	if json.Unmarshal([]byte(s), &w) != nil || w.V != 2 {
		return
	}
	today := dayOf(time.Now())
	week := int64(moatSettingsFor / (24 * time.Hour))
	if b := w.Builtin; b != nil && b.Base == builtinBase && b.Day <= today && today-b.Day < 4*week {
		kept, _ := acceptRefreshed(b.Lines)
		builtinMu.Lock()
		builtinFresh, builtinFreshAt = kept, dayStart(b.Day)
		builtinMu.Unlock()
	}
	if m := w.Moat; m != nil && m.Day <= today && today-m.Day < week {
		byType := map[string][]string{}
		var order []string
		for _, ln := range m.Lines {
			f := strings.Fields(ln)
			if len(f) == 0 {
				continue
			}
			t := strings.ToLower(f[0])
			if byType[t] == nil {
				order = append(order, t)
			}
			byType[t] = append(byType[t], ln)
		}
		var good []moatSetting
		for _, t := range order {
			if lines := moatLines(byType[t], t); len(lines) > 0 {
				good = append(good, moatSetting{Type: t, Source: "bridgedb", Lines: lines})
			}
		}
		if len(good) > 0 {
			moatCacheMu.Lock()
			moatSettingsC, moatSettingsAt = good, dayStart(m.Day)
			moatCacheMu.Unlock()
		}
	}
}

// the refreshed built-ins and the moat lines in use, as json for the
// secure store, or {"error":"decoy"}. it holds bridge lines, so it goes
// nowhere else.
//
//export HaloBridgeCache
func HaloBridgeCache() *C.char {
	return C.CString(bridgeCacheJSON())
}

// nothing of it while a decoy is open, or before the app has said
func bridgeCacheJSON() string {
	if !decoyClosed() {
		return moatReply(nil, errMoatDecoy)
	}
	return bridgeCacheOut()
}

// hands back what HaloBridgeCache gave, at start
//
//export HaloSetBridgeCache
func HaloSetBridgeCache(cJSON *C.char) *C.char {
	bridgeCacheIn(goStr(cJSON))
	return C.CString("ok")
}
