// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
	"time"
)

func resetBuiltinState(t *testing.T) {
	t.Helper()
	clear := func() {
		builtinMu.Lock()
		builtinFresh, builtinFreshAt = nil, time.Time{}
		builtinMu.Unlock()
		dropMoatSettings()
	}
	clear()
	t.Cleanup(clear)
}

// the bundled set, or with BUILTIN_FILE the file the release script is
// about to bundle
func TestBundledBuiltins(t *testing.T) {
	set := builtinBundled
	if f := os.Getenv("BUILTIN_FILE"); f != "" {
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		set = nil
		if err := json.Unmarshal(b, &set); err != nil {
			t.Fatal(err)
		}
	}
	checkBuiltinSet(t, set)
	if os.Getenv("BUILTIN_FILE") != "" {
		return
	}
	for tr, lines := range builtinBundled {
		if got := builtinLines(tr); len(got) != len(lines) {
			t.Errorf("%s: %d of %d bundled lines in use", tr, len(got), len(lines))
		}
	}
	r := reply(t, builtinBridgesJSON("snowflake"))
	if l, _ := r["lines"].([]any); len(l) != len(builtinBundled["snowflake"]) {
		t.Errorf("HaloBuiltinBridges: %v", r)
	}
	if r := reply(t, builtinBridgesJSON("meek_lite")); r["error"] != "bad_request" {
		t.Errorf("meek built-ins handed out: %v", r)
	}
}

func checkBuiltinSet(t *testing.T, set map[string][]string) {
	t.Helper()
	for _, tr := range []string{"obfs4", "snowflake"} {
		if len(set[tr]) == 0 {
			t.Errorf("no %s lines", tr)
		}
	}
	for tr, lines := range set {
		if builtinArgs[tr] == nil {
			t.Errorf("carries %s, which kryfo does not speak", tr)
		}
		for _, ln := range lines {
			b, ok := builtinLineOK(ln)
			if !ok {
				t.Errorf("a %s line is not usable or names a host not reviewed", tr)
			}
			if b.transport != tr {
				t.Errorf("a %s line under %s", b.transport, tr)
			}
			if n, _ := normaliseBridgeLine(ln); n != ln {
				t.Errorf("a %s line is not in tor's form", tr)
			}
		}
	}
	// the two snowflake lines tor browser ships, on placeholder addresses
	for _, ln := range set["snowflake"] {
		if !strings.HasPrefix(ln, "snowflake 192.0.2.") {
			t.Errorf("snowflake line not on a placeholder address")
		}
	}
}

// a copy of a bundled line with one field swapped
func tweak(t *testing.T, tr string, i int, from, to string) string {
	t.Helper()
	ln := builtinBundled[tr][i]
	if !strings.Contains(ln, from) {
		t.Fatalf("%s line %d has no %q", tr, i, from)
	}
	return strings.Replace(ln, from, to, 1)
}

func TestRefreshOnlyReviewedHosts(t *testing.T) {
	resetBuiltinState(t)
	sf := builtinBundled["snowflake"][0]
	o4 := builtinBundled["obfs4"][0]
	o4b, _ := parseBridgeLine(o4)
	sfb, _ := parseBridgeLine(sf)
	newCert := "cert=" + strings.Repeat("A", 70)
	fresh := map[string][]string{
		"snowflake": {
			// a reviewed front dropped: kept
			strings.Replace(sf, "fronts=app.datapacket.com,www.datapacket.com", "fronts=www.datapacket.com", 1),
			// a front nobody reviewed
			tweak(t, "snowflake", 1, "fronts=app.datapacket.com", "fronts=evil.example"),
			// a broker nobody reviewed
			tweak(t, "snowflake", 1, "url=https://1098762253.rsc.cdn77.org/", "url=https://broker.example/"),
			// a stun server nobody reviewed
			tweak(t, "snowflake", 1, "ice=stun:stun.epygi.com:3478", "ice=stun:stun.example:3478"),
			// amp cache
			tweak(t, "snowflake", 1, "utls-imitate=", "ampcache=https://cdn.ampproject.org/ utls-imitate="),
		},
		"obfs4": {
			// a new cert for the same bridge: kept
			strings.Replace(o4, "cert="+first(o4b.args.Get("cert")), newCert, 1),
			// an unknown fingerprint
			strings.Replace(o4, o4b.fp, strings.Repeat("A", 40), 1),
			// the same fingerprint somewhere else
			strings.Replace(o4, o4b.addr, "203.0.113.9:443", 1),
			// an argument a built-in line never has
			o4 + " extra=1",
		},
		"meek_lite": {"meek_lite 192.0.2.20:80 url=https://1603026938.rsc.cdn77.org front=www.phpmyadmin.net"},
		"webtunnel": {"webtunnel [2001:db8::1]:443 " + strings.Repeat("B", 40) + " url=https://wt.example.net/x ver=0.0.1"},
	}
	kept, ignored := acceptRefreshed(fresh)
	if len(kept["snowflake"]) != 1 || len(kept["obfs4"]) != 1 || len(kept["webtunnel"]) != 0 || kept["meek_lite"] != nil {
		t.Fatalf("kept %v", kept)
	}
	if ignored != 8 {
		t.Errorf("ignored %d, want 8", ignored)
	}
	builtinMu.Lock()
	builtinFresh, builtinFreshAt = kept, time.Now()
	builtinMu.Unlock()
	lines := builtinLines("obfs4")
	if len(lines) != len(builtinBundled["obfs4"]) || !strings.Contains(lines[0], newCert) {
		t.Error("the refreshed obfs4 cert is not in use")
	}
	for _, ln := range builtinLines("snowflake") {
		b, _ := parseBridgeLine(ln)
		if b.fp == sfb.fp && strings.Contains(ln, "app.datapacket.com") {
			t.Error("the refreshed snowflake line is not in use")
		}
		if strings.Contains(ln, "example") {
			t.Error("a host nobody reviewed is in use")
		}
	}
	if builtinRefreshDue() {
		t.Error("due straight after a refresh")
	}
}

func first(s string, _ bool) string { return s }

func TestBridgeCacheRoundTrip(t *testing.T) {
	resetBuiltinState(t)
	defer setLines("", false)
	o4 := builtinBundled["obfs4"][0]
	o4b, _ := parseBridgeLine(o4)
	newCert := "cert=" + strings.Repeat("C", 70)
	fresh := strings.Replace(o4, "cert="+first(o4b.args.Get("cert")), newCert, 1)
	kept, _ := acceptRefreshed(map[string][]string{"obfs4": {fresh}})
	builtinMu.Lock()
	builtinFresh, builtinFreshAt = kept, time.Now().Add(-time.Hour)
	builtinMu.Unlock()
	settings, err := readMoatSettings(fixture(t, "settings-ir"), 200)
	if err != nil {
		t.Fatal(err)
	}
	cacheMoatSettings(settings.Settings)
	var inUse []string
	for _, s := range settings.Settings {
		if s.Type == "webtunnel" {
			inUse = s.Lines
		}
	}
	setLines(strings.Join(inUse, "\n"), true)
	blob := bridgeCacheOut()

	resetBuiltinState(t)
	bridgeCacheIn(blob)
	if got := builtinLines("obfs4"); !strings.Contains(got[0], newCert) {
		t.Error("refreshed line lost on the way back")
	}
	if c := moatSettingsCached(); len(c) != 1 || len(c[0].Lines) != len(inUse) {
		t.Errorf("lines in use back: %v", c)
	}

	// stale, from another release, or tampered with: dropped
	var w bridgeCacheWire
	_ = json.Unmarshal([]byte(blob), &w)
	w.Moat.Day -= 8
	w.Builtin.Base = "another"
	stale, _ := json.Marshal(w)
	resetBuiltinState(t)
	bridgeCacheIn(string(stale))
	if moatSettingsCached() != nil || strings.Contains(builtinLines("obfs4")[0], newCert) {
		t.Error("stale or foreign cache taken")
	}

	_ = json.Unmarshal([]byte(blob), &w)
	w.Builtin.Lines["snowflake"] = []string{tweak(t, "snowflake", 0, "fronts=app.datapacket.com", "fronts=evil.example")}
	w.Moat.Lines = append(w.Moat.Lines, "obfs4 nonsense",
		tweak(t, "snowflake", 1, "fronts=app.datapacket.com", "fronts=evil.example"))
	bad, _ := json.Marshal(w)
	resetBuiltinState(t)
	bridgeCacheIn(string(bad))
	for _, ln := range builtinLines("snowflake") {
		if strings.Contains(ln, "evil") {
			t.Error("a tampered cache brought in a host nobody reviewed")
		}
	}
	for _, s := range moatSettingsCached() {
		for _, ln := range s.Lines {
			if !validBridgeLine(ln) || strings.Contains(ln, "evil") {
				t.Error("a tampered cache brought in a bad line")
			}
		}
	}
	bridgeCacheIn("not json")
	bridgeCacheIn(`{"v":1}`)
}

func TestMoatSettingsExpire(t *testing.T) {
	resetBuiltinState(t)
	cacheMoatSettings([]moatSetting{{Type: "obfs4", Source: "builtin", Lines: builtinLines("obfs4")}})
	if moatSettingsCached() == nil {
		t.Fatal("not cached")
	}
	moatCacheMu.Lock()
	moatSettingsAt = time.Now().Add(-moatSettingsFor)
	moatCacheMu.Unlock()
	if moatSettingsCached() != nil {
		t.Error("settings outlived a week")
	}
}
