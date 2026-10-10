// SPDX-License-Identifier: GPL-3.0-or-later
//go:build moatlive

// moat over meek against the real service, through the engine's own path.
//
//	go test -tags moatlive -run TestMoatLive .                 # check it works
//	MOAT_RECORD=1 go test -tags moatlive -run TestMoatLive .   # and rewrite testdata/moat
//	../scripts/builtin-bridges.sh                              # refresh builtin.json
//
// recorded replies are cleaned first: every bridge line that is not one of
// tor's built-ins gets a random address, port, fingerprint, cert and site,
// a country moat guessed from this machine becomes zz, and the captcha
// becomes a tiny made-up picture.
package main

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"image"
	"image/jpeg"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

func liveOpts() moatOpts {
	setDecoy(false)
	return moatOpts{Consent: true, Via: viaMeek}
}

// random values of the same length, nothing taken from the real ones
func fakeHex(n int) string {
	b := make([]byte, (n+1)/2)
	_, _ = rand.Read(b)
	return strings.ToUpper(hex.EncodeToString(b)[:n])
}

func fakeB64(n int) string {
	const abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	b := make([]byte, n)
	_, _ = rand.Read(b)
	for i := range b {
		b[i] = abc[int(b[i])%len(abc)]
	}
	return string(b)
}

func fakePort() int {
	var b [2]byte
	_, _ = rand.Read(b[:])
	return 1024 + (int(b[0])<<8|int(b[1]))%60000
}

// a 4 by 4 grey jpeg in base64, standing in for moat's captcha
func fakeCaptcha() string {
	img := image.NewGray(image.Rect(0, 0, 4, 4))
	var buf bytes.Buffer
	_ = jpeg.Encode(&buf, img, nil)
	return base64.StdEncoding.EncodeToString(buf.Bytes())
}

// one line with nothing real left that would let anyone use the bridge
func cleanLine(ln string, n int) string {
	f := strings.Fields(ln)
	if len(f) < 2 {
		return ln
	}
	t := strings.ToLower(f[0])
	switch t {
	case "obfs4":
		f[1] = fmt.Sprintf("192.0.2.%d:%d", 100+n, fakePort())
	case "webtunnel":
		f[1] = fmt.Sprintf("[2001:db8::%x]:%d", 0x100+n, fakePort())
	}
	// one fingerprint per line: a snowflake line names it twice
	fp := fakeHex(40)
	for i := 2; i < len(f); i++ {
		k, v, ok := strings.Cut(f[i], "=")
		switch {
		case !ok && isFingerprint(f[i]):
			f[i] = fp
		case k == "fingerprint":
			f[i] = k + "=" + fp
		case k == "cert":
			f[i] = k + "=" + fakeB64(len(v))
		case k == "url" && t == "webtunnel":
			f[i] = fmt.Sprintf("url=https://wt%d.example.net/%s", n, strings.ToLower(fakeHex(24)))
		case k == "servername":
			f[i] = fmt.Sprintf("servername=wt%d.example.net", n)
		case k == "sqscreds":
			f[i] = k + "=" + fakeB64(len(v))
		case k == "sqsqueue":
			f[i] = k + "=https://sqs.us-east-2.amazonaws.com/000000000000/snowflake-broker"
		}
	}
	return strings.Join(f, " ")
}

// walks a reply and cleans every bridge line in it that tor does not
// publish as a built-in
func cleanReply(v any, keep map[string]bool, n *int) any {
	switch x := v.(type) {
	case map[string]any:
		for k, e := range x {
			x[k] = cleanReply(e, keep, n)
		}
	case []any:
		for i, e := range x {
			x[i] = cleanReply(e, keep, n)
		}
	case string:
		f := strings.Fields(x)
		if len(f) > 2 && !keep[strings.Join(f, " ")] {
			for _, t := range []string{"obfs4", "webtunnel", "snowflake", "meek_lite"} {
				if strings.EqualFold(f[0], t) {
					*n++
					return cleanLine(x, *n)
				}
			}
		}
	}
	return v
}

type liveCall struct {
	name, method, path string
	body               any
}

func TestMoatLive(t *testing.T) {
	o := liveOpts()
	sent := map[string]any{"transports": []string{"obfs4", "snowflake", "webtunnel"}}
	withCountry := func(c string) map[string]any {
		return map[string]any{"transports": []string{"obfs4", "snowflake", "webtunnel"}, "country": c}
	}
	fetch := func(first string) map[string]any {
		return map[string]any{"data": []moatItem{{Version: "0.1.0", Type: "client-transports",
			Supported: captchaTransports(first)}}}
	}
	calls := []liveCall{
		{"builtin", "POST", "/circumvention/builtin", map[string]any{"transports": []string{}}},
		{"settings-guess", "POST", "/circumvention/settings", sent},
		{"settings-ir", "POST", "/circumvention/settings", withCountry("ir")},
		{"settings-cn", "POST", "/circumvention/settings", withCountry("cn")},
		{"settings-ru", "POST", "/circumvention/settings", withCountry("ru")},
		{"settings-tm", "POST", "/circumvention/settings", withCountry("tm")},
		{"settings-de", "POST", "/circumvention/settings", withCountry("de")},
		{"defaults", "POST", "/circumvention/defaults", sent},
		{"map", "GET", "/circumvention/map", nil},
		{"countries", "GET", "/circumvention/countries", nil},
		{"fetch-obfs4", "POST", "/fetch", fetch("obfs4")},
		{"fetch-webtunnel", "POST", "/fetch", fetch("webtunnel")},
	}
	raws := map[string][]byte{}
	for _, c := range calls {
		raw, code, err := moatDo(o, c.method, c.path, c.body)
		if err != nil || code != 200 {
			t.Fatalf("%s: %d %v", c.name, code, err)
		}
		raws[c.name] = raw
	}
	// the answer goes back with each challenge, as a person would type it
	for _, tr := range []string{"obfs4", "webtunnel"} {
		cap, err := readMoatFetch(raws["fetch-"+tr], 200)
		if err != nil {
			t.Fatalf("fetch %s: %v", tr, err)
		}
		if cap.Transport != tr {
			t.Errorf("fetch %s: moat offers %q first", tr, cap.Transport)
		}
		raw, code, err := moatDo(o, "POST", "/check", map[string]any{"data": []moatItem{{
			ID: "2", Type: "moat-solution", Version: "0.1.0", Transport: tr,
			Challenge: cap.Challenge, Solution: "freedom", QRCode: "false",
		}}})
		if err != nil || code != 200 {
			t.Fatalf("check %s: %d %v", tr, code, err)
		}
		raws["check-"+tr] = raw
		lines, err := readMoatCheck(raw, code, tr)
		if err != nil {
			t.Fatalf("check %s: %v", tr, err)
		}
		for _, ln := range lines {
			if !strings.HasPrefix(ln, tr+" ") {
				t.Errorf("check %s gave a line of another transport", tr)
			}
		}
		t.Logf("check %s: %d usable lines", tr, len(lines))
	}

	// what the engine makes of each
	bi, err := readMoatBuiltin(raws["builtin"], 200)
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("builtin transports: %v", sortedKeys(bi))
	for _, name := range []string{"settings-guess", "settings-ir", "settings-cn", "settings-ru", "settings-tm", "settings-de", "defaults"} {
		s, err := readMoatSettings(raws[name], 200)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		var got []string
		for _, one := range s.Settings {
			got = append(got, fmt.Sprintf("%s/%s/%d", one.Type, one.Source, len(one.Lines)))
		}
		t.Logf("%s: %v", name, got)
	}
	if m, err := readMoatMap(raws["map"], 200); err != nil {
		t.Fatal(err)
	} else {
		t.Logf("map: %d countries", len(m))
	}

	if os.Getenv("MOAT_RECORD") == "" {
		return
	}
	keep := map[string]bool{}
	for _, lines := range bi {
		for _, ln := range lines {
			keep[strings.Join(strings.Fields(ln), " ")] = true
		}
	}
	dir := filepath.Join("testdata", "moat")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	n := 0
	for name, raw := range raws {
		var v any
		if err := json.Unmarshal(raw, &v); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		v = cleanReply(v, keep, &n)
		if strings.HasPrefix(name, "fetch-") {
			if m, ok := v.(map[string]any); ok {
				for _, d := range m["data"].([]any) {
					d.(map[string]any)["image"] = fakeCaptcha()
				}
			}
		}
		if name == "settings-guess" {
			if m, ok := v.(map[string]any); ok && m["country"] != nil {
				m["country"] = "zz"
			}
		}
		out, _ := json.MarshalIndent(v, "", "  ")
		if err := os.WriteFile(filepath.Join(dir, name+".json"), append(out, '\n'), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	t.Logf("recorded %d replies, %d lines made up", len(raws), n)
}

func sortedKeys(m map[string][]string) []string {
	var out []string
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// moat's built-ins as builtin.json wants them, for scripts/builtin-bridges.sh.
// only the transports kryfo speaks, sorted, and a line with a host that was
// not reviewed fails the run until reviewedHosts names it.
func TestBuiltinRelease(t *testing.T) {
	out := os.Getenv("BUILTIN_OUT")
	if out == "" {
		t.Skip("BUILTIN_OUT not set")
	}
	o := liveOpts()
	o.Transports = nil
	raw, code, err := moatDo(o, "POST", "/circumvention/builtin", map[string]any{"transports": []string{}})
	if err != nil {
		t.Fatal(err)
	}
	all, err := readMoatBuiltin(raw, code)
	if err != nil {
		t.Fatal(err)
	}
	set := map[string][]string{}
	for tr, lines := range all {
		if builtinArgs[tr] == nil {
			t.Logf("left out: %s, %d lines", tr, len(lines))
			continue
		}
		for _, ln := range lines {
			ln, _ = normaliseBridgeLine(ln)
			b, ok := builtinLineOK(ln)
			if !ok {
				hosts, _ := lineHosts(b)
				for _, h := range hosts {
					if !hostAllowed(h) {
						t.Errorf("%s: host not reviewed: %s", tr, h)
					}
				}
				t.Errorf("%s: a line kryfo would not use", tr)
				continue
			}
			set[tr] = append(set[tr], ln)
		}
		sort.Strings(set[tr])
	}
	// hosts moat hands out per country that are not reviewed, for the
	// release review. amp cache and sqs lines are refused anyway.
	for _, c := range []string{"ir", "cn", "ru", "tm", "by", "eg", "hk", "mm"} {
		raw, code, err := moatDo(o, "POST", "/circumvention/settings",
			map[string]any{"transports": []string{"snowflake"}, "country": c})
		if err != nil || code != 200 {
			continue
		}
		var w moatSettingsWire
		_ = json.Unmarshal(raw, &w)
		for _, s := range w.Settings {
			for _, ln := range s.Bridges.BridgeStrings {
				b, err := parseBridgeLine(ln)
				if err != nil {
					continue
				}
				hosts, ok := lineHosts(b)
				if !ok {
					continue
				}
				for _, h := range hosts {
					if !hostAllowed(h) {
						t.Logf("%s: moat uses a host that is not reviewed: %s", c, h)
					}
				}
			}
		}
	}
	if t.Failed() {
		return
	}
	b, _ := json.MarshalIndent(set, "", "  ")
	if err := os.WriteFile(out, append(b, '\n'), 0o644); err != nil {
		t.Fatal(err)
	}
}
