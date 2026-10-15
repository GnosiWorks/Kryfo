// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"strings"
	"testing"
)

const tbVanilla = "198.51.100.7:9001 " + testFP

func TestVanillaLinesAccepted(t *testing.T) {
	for _, ln := range []string{
		tbVanilla,
		"198.51.100.7:9001",
		"[2001:db8::7]:443 " + testFP,
	} {
		b, err := checkBridgeLine(ln)
		if err != nil || b.transport != vanillaName {
			t.Errorf("%q: %v %q", ln, err, b.transport)
		}
	}
	for _, ln := range []string{
		tbVanilla + " cert=abc",
		"198.51.100.7:9001 nothex",
		"bridge.example:9001 " + testFP,
		"198.51.100.7 " + testFP,
		"198.51.100.7:0 " + testFP,
	} {
		if validBridgeLine(ln) {
			t.Errorf("%q passed", ln)
		}
	}
}

func TestVanillaLinesSortAndKeepTheirShape(t *testing.T) {
	good, bad, checks := sortBridgeLines(strings.Join([]string{
		tbVanilla, "  198.51.100.7:9001   " + strings.ToLower(testFP), tbObfs4, "198.51.100.8:443 " + testFP + " kryfo=00ff",
	}, "\n"))
	if len(bad) != 1 || len(good) != 3 {
		t.Fatalf("good %q bad %q", good, bad)
	}
	if good[0] != tbVanilla || good[2] != "198.51.100.8:443 "+testFP {
		t.Fatalf("%q", good)
	}
	if checks[3].State != "fixed" {
		t.Fatalf("%+v", checks)
	}
}

// tor refuses arguments on a line without a transport, so the token stays
// off vanilla lines and on every other
func TestVanillaLinesGoToTorWithoutToken(t *testing.T) {
	useBridges(t, true, tbVanilla, tbObfs4)
	got := torBridgeLines()
	if got[0] != tbVanilla {
		t.Fatalf("%q", got[0])
	}
	if !strings.HasSuffix(got[1], ptTokenArg+"="+ptToken) {
		t.Fatalf("%q", got[1])
	}
}

func TestVanillaMethodIsNamed(t *testing.T) {
	useBridges(t, true, tbVanilla)
	if m := linesMethod(); m != vanillaName {
		t.Fatalf("%q", m)
	}
}

func TestVanillaAddressesScrubbed(t *testing.T) {
	noteBridgeSecrets([]string{tbVanilla})
	out := scrubBridges("connect to 198.51.100.7:9001 id " + testFP)
	if strings.Contains(out, "198.51.100.7") || strings.Contains(out, testFP) {
		t.Fatalf("%q", out)
	}
}
