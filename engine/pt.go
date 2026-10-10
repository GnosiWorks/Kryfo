// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the pluggable transports built into the engine. tor reaches obfs4,
// webtunnel and snowflake through local socks5 listeners (bridges.go).
// meek_lite has no listener, it is there for moat.

import (
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	pt "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/goptlib"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/base"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/meeklite"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/obfs4"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/webtunnel"
	utlsutil "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/ptutil/utls"
	sf "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/client/lib"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/event"
)

// goptlib writes pt protocol lines to stdout for a parent process that is
// not there, and webtunnel's carry the address it dialled
func init() { pt.Stdout = io.Discard }

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
	if !strings.HasPrefix(strings.ToLower(c.BrokerURL), "https://") {
		return nil, errors.New("snowflake: broker url is not https")
	}
	fronts, ok := args.Get("fronts")
	if !ok {
		fronts, _ = args.Get("front")
	}
	if c.FrontDomains = splitList(fronts); len(c.FrontDomains) == 0 {
		return nil, errors.New("snowflake: no front")
	}
	c.ICEAddresses = snowflakeICE
	if ice, ok := args.Get("ice"); ok {
		c.ICEAddresses = splitList(ice)
	}
	c.UTLSClientID, _ = args.Get("utls-imitate")
	if c.UTLSClientID != "" {
		if _, err := utlsutil.NameToUTLSID(c.UTLSClientID); err != nil {
			return nil, errors.New("snowflake: unknown utls-imitate")
		}
	}
	c.BridgeFingerprint, _ = args.Get("fingerprint")
	c.Max = 1
	if m, ok := args.Get("max"); ok {
		n, err := strconv.Atoi(m)
		if err != nil || n < 1 || n > snowflakeMaxPeers {
			return nil, errors.New("snowflake: bad max")
		}
		c.Max = n
	}
	return c, nil
}

// proxies one connection may gather at once. each is a webrtc peer, and a
// line asking for many would only burn battery.
const snowflakeMaxPeers = 3

// one snowflake client per line, kept until the lines change: its nat check
// and broker channel are set up once, not for every connection tor makes
var (
	sfMu      sync.Mutex
	sfClients = map[string]*sf.Transport{}
	sfMade    atomic.Int64
)

func snowflakeFor(c sf.ClientConfig) (*sf.Transport, error) {
	key := fmt.Sprintf("%q %q %q %q %q %d", c.BrokerURL, c.FrontDomains,
		c.ICEAddresses, c.UTLSClientID, c.BridgeFingerprint, c.Max)
	sfMu.Lock()
	defer sfMu.Unlock()
	if t := sfClients[key]; t != nil {
		return t, nil
	}
	t, err := sf.NewSnowflakeClient(c)
	if err != nil {
		return nil, err
	}
	t.AddSnowflakeEventListener(sfListener{})
	sfMade.Add(1)
	sfClients[key] = t
	return t, nil
}

// what snowflake said last, and when, for the status line. the events come
// from snowflake's own goroutines.
var (
	sfStatMu sync.Mutex
	sfPhase  string
	sfAt     time.Time
	sfCounts = map[string]int{}
)

type sfListener struct{}

func (sfListener) OnNewSnowflakeEvent(e event.SnowflakeEvent) {
	// a panic here would take the app down from a goroutine that is not ours
	defer func() {
		if p := recover(); p != nil {
			log.Printf("snowflake: event panicked")
		}
	}()
	var phase string
	switch e := e.(type) {
	case event.EventOnOfferCreated:
		phase = "offer"
		if e.Error != nil {
			phase = "offer_failed"
		}
	case event.EventOnBrokerRendezvous:
		phase = "broker"
		if e.Error != nil {
			phase = "broker_failed"
		}
	case event.EventOnSnowflakeConnected:
		phase = "connected"
	case event.EventOnSnowflakeConnectionFailed:
		phase = "proxy_failed"
	default:
		return
	}
	sfStatMu.Lock()
	sfPhase, sfAt = phase, time.Now()
	sfCounts[phase]++
	sfStatMu.Unlock()
	// the kind only: an event's own text can carry an address
	log.Printf("snowflake: %s", phase)
}

// the last phase, when it came, and how many times each phase has come
func snowflakeStatus() (string, time.Time, map[string]int) {
	sfStatMu.Lock()
	defer sfStatMu.Unlock()
	counts := map[string]int{}
	for k, v := range sfCounts {
		counts[k] = v
	}
	return sfPhase, sfAt, counts
}

func dropSnowflakeClients() {
	sfMu.Lock()
	sfClients = map[string]*sf.Transport{}
	sfMu.Unlock()
}

// the target address is a placeholder, the line's url and fronts say where
// the broker is
func (snowflakeClient) Dial(_, _ string, _ base.DialFunc, args interface{}) (net.Conn, error) {
	c, ok := args.(sf.ClientConfig)
	if !ok {
		return nil, errors.New("snowflake: bad args")
	}
	t, err := snowflakeFor(c)
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
