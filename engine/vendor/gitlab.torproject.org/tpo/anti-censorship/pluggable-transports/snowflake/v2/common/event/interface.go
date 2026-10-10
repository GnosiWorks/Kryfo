package event

import (
	"fmt"
	"time"

	"github.com/pion/webrtc/v4"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/ptutil/safelog"
)

type SnowflakeEvent interface {
	IsSnowflakeEvent()
	String() string
}

type EventOnOfferCreated struct {
	SnowflakeEvent
	WebRTCLocalDescription *webrtc.SessionDescription
	Error                  error
}

func (e EventOnOfferCreated) String() string {
	if e.Error != nil {
		scrubbed := safelog.Scrub([]byte(e.Error.Error()))
		return fmt.Sprintf("offer creation failure %s", scrubbed)
	}
	return "offer created"
}

type EventOnBrokerRendezvous struct {
	SnowflakeEvent
	WebRTCRemoteDescription *webrtc.SessionDescription
	Error                   error
}

func (e EventOnBrokerRendezvous) String() string {
	if e.Error != nil {
		scrubbed := safelog.Scrub([]byte(e.Error.Error()))
		return fmt.Sprintf("broker failure %s", scrubbed)
	}
	return "broker rendezvous peer received"
}

type EventOnSnowflakeConnected struct {
	SnowflakeEvent
}

func (e EventOnSnowflakeConnected) String() string {
	return "connected"
}

type EventOnSnowflakeConnectionFailed struct {
	SnowflakeEvent
	Error error
}

func (e EventOnSnowflakeConnectionFailed) String() string {
	scrubbed := safelog.Scrub([]byte(e.Error.Error()))
	return fmt.Sprintf("trying a new proxy: %s", scrubbed)
}

type EventOnProxyStarting struct {
	SnowflakeEvent
}

func (e EventOnProxyStarting) String() string {
	return "Proxy starting"
}

type EventOnProxyClientConnected struct {
	SnowflakeEvent
}

func (e EventOnProxyClientConnected) String() string {
	return fmt.Sprintf("client connected")
}

// The connection with the client has now been closed,
// after getting successfully established.
type EventOnProxyConnectionOver struct {
	SnowflakeEvent
	Country string
}

func (e EventOnProxyConnectionOver) String() string {
	return fmt.Sprintf("Proxy connection closed")
}

// Rendezvous with a client succeeded,
// but a data channel has not been created.
type EventOnProxyConnectionFailed struct {
	SnowflakeEvent
}

func (e EventOnProxyConnectionFailed) String() string {
	return "Failed to connect to the client"
}

type EventOnProxyStats struct {
	SnowflakeEvent
	// Completed successful connections.
	ConnectionCount int
	// Connections that failed to establish.
	FailedConnectionCount       uint
	InboundBytes, OutboundBytes int64
	InboundUnit, OutboundUnit   string
	SummaryInterval             time.Duration
}

func (e EventOnProxyStats) String() string {
	statString := fmt.Sprintf("In the last %v, there were %v completed successful connections. Traffic Relayed ↓ %v %v (%.2f %v%s), ↑ %v %v (%.2f %v%s).",
		e.SummaryInterval.String(), e.ConnectionCount,
		e.InboundBytes, e.InboundUnit, float64(e.InboundBytes)/e.SummaryInterval.Seconds(), e.InboundUnit, "/s",
		e.OutboundBytes, e.OutboundUnit, float64(e.OutboundBytes)/e.SummaryInterval.Seconds(), e.OutboundUnit, "/s")
	return statString
}

type EventOnCurrentNATTypeDetermined struct {
	SnowflakeEvent
	CurNATType string
}

func (e EventOnCurrentNATTypeDetermined) String() string {
	return fmt.Sprintf("NAT type: %v", e.CurNATType)
}

type SnowflakeEventReceiver interface {
	// OnNewSnowflakeEvent notify receiver about a new event
	// This method MUST not block
	OnNewSnowflakeEvent(event SnowflakeEvent)
}

type SnowflakeEventDispatcher interface {
	SnowflakeEventReceiver
	// AddSnowflakeEventListener allow receiver(s) to receive event notification
	// when OnNewSnowflakeEvent is called on the dispatcher.
	// Every event listener added will be called when an event is received by the dispatcher.
	// The order each listener is called is undefined.
	AddSnowflakeEventListener(receiver SnowflakeEventReceiver)
	RemoveSnowflakeEventListener(receiver SnowflakeEventReceiver)
}
