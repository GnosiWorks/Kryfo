// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"reflect"
	"strings"
	"testing"

	pt "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/goptlib"
	sf "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/client/lib"
)

// tor browser's built-in lines
const (
	tbObfs4     = "obfs4 37.218.245.14:38224 D9A82D2F9C2F65A18407B1D2B764F130847F8B5D cert=bjRaMrr1BRiAW8IE9U5z27fQaYgOhX1UCmOpg2pFpoMvo6ZgQMzLsaTzzQNTlm7hNcb+Sg iat-mode=0"
	tbSnowflake = "snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://1098762253.rsc.cdn77.org/ fronts=app.datapacket.com,www.datapacket.com ice=stun:stun.epygi.com:3478,stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,stun:stun.mixvoip.com:3478,stun:stun.telnyx.com:3478,stun:stun.hot-chilli.net:3478,stun:stun.fitauto.ru:3478,stun:stun.m-online.net:3478 utls-imitate=hellorandomizedalpn"
)

func lineArgs(line string) *pt.Args {
	a := pt.Args{}
	for _, f := range strings.Fields(line)[2:] {
		if k, v, ok := strings.Cut(f, "="); ok {
			a.Add(k, v)
		}
	}
	return &a
}

func TestPTFactories(t *testing.T) {
	for _, n := range []string{"obfs4", "webtunnel", "meek_lite", "snowflake"} {
		f, err := ptClientFactory(n)
		if err != nil || f == nil {
			t.Fatalf("%s: %v", n, err)
		}
		if got := f.Transport().Name(); got != n {
			t.Errorf("%s calls itself %s", n, got)
		}
	}
	if _, err := ptClientFactory("obfs3"); err == nil {
		t.Error("obfs3 has a factory")
	}
}

func TestObfs4ParsesBuiltinLine(t *testing.T) {
	f, _ := ptClientFactory("obfs4")
	if _, err := f.ParseArgs(lineArgs(tbObfs4)); err != nil {
		t.Fatal(err)
	}
}

func TestSnowflakeArgs(t *testing.T) {
	f, _ := ptClientFactory("snowflake")
	got, err := f.ParseArgs(lineArgs(tbSnowflake))
	if err != nil {
		t.Fatal(err)
	}
	c := got.(sf.ClientConfig)
	if c.BrokerURL != "https://1098762253.rsc.cdn77.org/" ||
		!reflect.DeepEqual(c.FrontDomains, []string{"app.datapacket.com", "www.datapacket.com"}) ||
		!reflect.DeepEqual(c.ICEAddresses, snowflakeICE) ||
		c.UTLSClientID != "hellorandomizedalpn" ||
		c.BridgeFingerprint != "2B280B23E1107BB62ABFC40DDCC8824814F80A72" ||
		c.Max != 1 || c.SQSQueueURL != "" || c.AmpCacheURL != "" {
		t.Fatalf("%+v", c)
	}

	// no ice in the line: tor browser's list
	noICE := strings.Replace(tbSnowflake, " ice=", " x=", 1)
	got, err = f.ParseArgs(lineArgs(noICE))
	if err != nil || !reflect.DeepEqual(got.(sf.ClientConfig).ICEAddresses, snowflakeICE) {
		t.Fatalf("%v %v", got, err)
	}

	for _, extra := range []string{"sqsqueue=https://sqs.us-east-1.amazonaws.com/1/q", "ampcache=https://cdn.ampproject.org/", "proxy=socks5://127.0.0.1:1"} {
		if _, err := f.ParseArgs(lineArgs(tbSnowflake + " " + extra)); err == nil {
			t.Errorf("%s accepted", extra)
		}
	}
	if _, err := f.ParseArgs(lineArgs("snowflake 192.0.2.3:80 fingerprint=AB")); err == nil {
		t.Error("a line without url accepted")
	}
}

// the fork has no sqs rendezvous, a config asking for it fails instead of
// ending the process
func TestSnowflakeSQSRefused(t *testing.T) {
	_, err := sf.NewSnowflakeClient(sf.ClientConfig{SQSQueueURL: "https://sqs.us-east-1.amazonaws.com/1/q", SQSCredsStr: "x"})
	if err == nil {
		t.Fatal("sqs accepted")
	}
}
