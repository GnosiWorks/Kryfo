// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the pluggable transports built into the engine. tor reaches them through
// local socks5 listeners (bridges.go). only obfs4 is handed to tor so far.

import (
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"

	pt "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/goptlib"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/base"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/meeklite"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/obfs4"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/webtunnel"
	sf "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/client/lib"
)

// tor browser's stun servers for its built-in snowflake lines
var snowflakeICE = []string{
	"stun:stun.epygi.com:3478",
	"stun:stun.uls.co.za:3478",
	"stun:stun.voipgate.com:3478",
	"stun:stun.mixvoip.com:3478",
	"stun:stun.telnyx.com:3478",
	"stun:stun.hot-chilli.net:3478",
	"stun:stun.fitauto.ru:3478",
	"stun:stun.m-online.net:3478",
}

func ptClientFactory(name string) (base.ClientFactory, error) {
	switch name {
	case "obfs4":
		return (&obfs4.Transport{}).ClientFactory("")
	case "webtunnel":
		return webtunnel.Transport.ClientFactory("")
	case "meek_lite":
		return (&meeklite.Transport{}).ClientFactory("")
	case "snowflake":
		return snowflakeTransport{}.ClientFactory("")
	}
	return nil, fmt.Errorf("unknown transport %q", name)
}

type snowflakeTransport struct{}

func (snowflakeTransport) Name() string { return "snowflake" }

func (t snowflakeTransport) ClientFactory(string) (base.ClientFactory, error) {
	return snowflakeClient{}, nil
}

func (snowflakeTransport) ServerFactory(string, *pt.Args) (base.ServerFactory, error) {
	return nil, errors.New("snowflake: no server")
}

type snowflakeClient struct{}

func (snowflakeClient) Transport() base.Transport { return snowflakeTransport{} }

// domain fronting through the cdn only: sqs is not built in and amp cache
// is refused here
func (snowflakeClient) ParseArgs(args *pt.Args) (interface{}, error) {
	for _, k := range []string{"sqsqueue", "sqscreds", "ampcache", "proxy"} {
		if _, ok := args.Get(k); ok {
			return nil, fmt.Errorf("snowflake: %s is not supported", k)
		}
	}
	var c sf.ClientConfig
	c.BrokerURL, _ = args.Get("url")
	if c.BrokerURL == "" {
		return nil, errors.New("snowflake: no url")
	}
	fronts, ok := args.Get("fronts")
	if !ok {
		fronts, _ = args.Get("front")
	}
	c.FrontDomains = splitList(fronts)
	c.ICEAddresses = snowflakeICE
	if ice, ok := args.Get("ice"); ok {
		c.ICEAddresses = splitList(ice)
	}
	c.UTLSClientID, _ = args.Get("utls-imitate")
	c.BridgeFingerprint, _ = args.Get("fingerprint")
	c.Max = 1
	if m, ok := args.Get("max"); ok {
		n, err := strconv.Atoi(m)
		if err != nil || n < 1 {
			return nil, errors.New("snowflake: bad max")
		}
		c.Max = n
	}
	return c, nil
}

// the target address is a placeholder, the line's url and fronts say where
// the broker is
func (snowflakeClient) Dial(_, _ string, _ base.DialFunc, args interface{}) (net.Conn, error) {
	c, ok := args.(sf.ClientConfig)
	if !ok {
		return nil, errors.New("snowflake: bad args")
	}
	t, err := sf.NewSnowflakeClient(c)
	if err != nil {
		return nil, err
	}
	return t.Dial()
}

func (snowflakeClient) OnEvent(func(base.TransportEvent)) {}

func splitList(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}
