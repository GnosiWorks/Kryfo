// WebRTC rendezvous requires the exchange of SessionDescriptions between
// peers in order to establish a PeerConnection.

package snowflake_client

import (
	"crypto/tls"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"sync"
	"sync/atomic"
	"time"

	"github.com/pion/webrtc/v4"
	utls "github.com/refraction-networking/utls"

	utlsutil "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/ptutil/utls"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/certs"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/covertdtls"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/event"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/messages"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/nat"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/util"
)

const (
	brokerErrorUnexpected string = "Unexpected error, no answer."
	rendezvousErrorMsg    string = "One of SQS, AmpCache, or Domain Fronting rendezvous methods must be used."

	readLimit = 100000 //Maximum number of bytes to be read from an HTTP response
)

// RendezvousMethod represents a way of communicating with the broker: sending
// an encoded client poll request (SDP offer) and receiving an encoded client
// poll response (SDP answer) in return. RendezvousMethod is used by
// BrokerChannel, which is in charge of encoding and decoding, and all other
// tasks that are independent of the rendezvous method.
type RendezvousMethod interface {
	Exchange([]byte) ([]byte, error)
}

// BrokerChannel uses a RendezvousMethod to communicate with the Snowflake broker.
// The BrokerChannel is responsible for encoding and decoding SDP offers and answers;
// RendezvousMethod is responsible for the exchange of encoded information.
type BrokerChannel struct {
	Rendezvous         RendezvousMethod
	keepLocalAddresses bool
	natType            string
	lock               sync.Mutex
	BridgeFingerprint  string
}

// We make a copy of DefaultTransport because we want the default Dial
// and TLSHandshakeTimeout settings. But we want to disable the default
// ProxyFromEnvironment setting.
func createBrokerTransport(proxy *url.URL) http.RoundTripper {
	tlsConfig := &tls.Config{
		RootCAs: certs.GetRootCAs(),
	}
	transport := &http.Transport{TLSClientConfig: tlsConfig}
	transport.Proxy = nil
	if proxy != nil {
		transport.Proxy = http.ProxyURL(proxy)
	}
	transport.ResponseHeaderTimeout = 15 * time.Second
	return transport
}

func newBrokerChannelFromConfig(config ClientConfig) (*BrokerChannel, error) {
	log.Println("Rendezvous using Broker at:", config.BrokerURL)

	if len(config.FrontDomains) != 0 {
		log.Printf("Domain fronting using a randomly selected domain from: %v", config.FrontDomains)
	}

	brokerTransport := createBrokerTransport(config.CommunicationProxy)

	if config.UTLSClientID != "" {
		utlsClientHelloID, err := utlsutil.NameToUTLSID(config.UTLSClientID)
		if err != nil {
			return nil, fmt.Errorf("unable to create broker channel: %w", err)
		}
		utlsConfig := &utls.Config{
			RootCAs: certs.GetRootCAs(),
		}
		brokerTransport = utlsutil.NewUTLSHTTPRoundTripperWithProxy(utlsClientHelloID, utlsConfig, brokerTransport,
			config.UTLSRemoveSNI, config.CommunicationProxy)
	}

	var rendezvous RendezvousMethod
	var err error
	// kryfo: no sqs rendezvous, and errors instead of log.Fatal, which would
	// end the app this runs in
	if config.SQSQueueURL != "" {
		return nil, errors.New("sqs rendezvous is not built in")
	} else if config.AmpCacheURL != "" && config.BrokerURL != "" {
		log.Println("Through AMP cache at:", config.AmpCacheURL)
		rendezvous, err = newAMPCacheRendezvous(
			config.BrokerURL, config.AmpCacheURL, config.FrontDomains,
			brokerTransport)
	} else if config.BrokerURL != "" {
		rendezvous, err = newHTTPRendezvous(
			config.BrokerURL, config.FrontDomains, brokerTransport)
	} else {
		return nil, errors.New("No rendezvous method was specified. " + rendezvousErrorMsg)
	}
	if err != nil {
		return nil, err
	}

	return &BrokerChannel{
		Rendezvous:         rendezvous,
		keepLocalAddresses: config.KeepLocalAddresses,
		natType:            nat.NATUnknown,
		BridgeFingerprint:  config.BridgeFingerprint,
	}, nil
}

// Negotiate uses a RendezvousMethod to send the client's WebRTC SDP offer
// and receive a snowflake proxy WebRTC SDP answer in return.
func (bc *BrokerChannel) Negotiate(
	offer *webrtc.SessionDescription,
	natTypeToSend string,
) (
	*webrtc.SessionDescription, error,
) {
	encReq, err := preparePollRequest(offer, natTypeToSend, bc.BridgeFingerprint)
	if err != nil {
		return nil, err
	}

	// Do the exchange using our RendezvousMethod.
	encResp, err := bc.Rendezvous.Exchange(encReq)
	if err != nil {
		return nil, err
	}
	log.Printf("Received answer: %s", string(encResp))

	// Decode the client poll response.
	resp, err := messages.DecodeClientPollResponse(encResp)
	if err != nil {
		return nil, err
	}
	if resp.Error != "" {
		return nil, errors.New(resp.Error)
	}
	return util.DeserializeSessionDescription(resp.Answer)
}

// Pure function
func preparePollRequest(
	offer *webrtc.SessionDescription,
	natType string,
	bridgeFingerprint string,
) (encReq []byte, err error) {
	offerSDP, err := util.SerializeSessionDescription(offer)
	if err != nil {
		return nil, err
	}
	req := &messages.ClientPollRequest{
		Offer:       offerSDP,
		NAT:         natType,
		Fingerprint: bridgeFingerprint,
	}
	encReq, err = req.EncodeClientPollRequest()
	return
}

// SetNATType sets the NAT type of the client so we can send it to the WebRTC broker.
func (bc *BrokerChannel) SetNATType(NATType string) {
	bc.lock.Lock()
	bc.natType = NATType
	bc.lock.Unlock()
	log.Printf("NAT Type: %s", NATType)
}

func (bc *BrokerChannel) GetNATType() string {
	bc.lock.Lock()
	defer bc.lock.Unlock()
	return bc.natType
}

// All of the methods of the struct are thread-safe.
type NATPolicy struct {
	assumedUnrestrictedNATAndFailedToConnect atomic.Bool
}

// When our NAT type is unknown, we want to try to connect to a
// restricted / unknown proxy initially
// to offload the unrestricted ones.
// So, instead of always sending the actual NAT type,
// we should use this function to determine the NAT type to send.
//
// This is useful when our STUN servers are blocked or don't support
// the NAT discovery feature, or if they're just slow.
func (p *NATPolicy) NATTypeToSend(actualNatType string) string {
	if !p.assumedUnrestrictedNATAndFailedToConnect.Load() &&
		actualNatType == nat.NATUnknown {
		// If our NAT type is unknown, and we haven't failed to connect
		// with a spoofed NAT type yet, then spoof a NATUnrestricted
		// type.
		return nat.NATUnrestricted
	} else {
		// In all other cases, do not spoof, and just return our actual
		// NAT type (even if it is NATUnknown).
		return actualNatType
	}
}

// This function must be called whenever a connection with a proxy succeeds,
// because the connection outcome tells us about NAT compatibility
// between the proxy and us.
func (p *NATPolicy) Success(actualNATType, sentNATType string) {
	// Yes, right now this does nothing but log.
	if actualNATType != sentNATType {
		log.Printf(
			"Connected to a proxy by using a spoofed NAT type \"%v\"! "+
				"Our actual NAT type was \"%v\"",
			sentNATType,
			actualNATType,
		)
	}
}

// This function must be called whenever a connection with a proxy fails,
// because the connection outcome tells us about NAT compatibility
// between the proxy and us.
func (p *NATPolicy) Failure(actualNATType, sentNATType string) {
	if actualNATType == nat.NATUnknown && sentNATType == nat.NATUnrestricted {
		log.Printf(
			"Tried to connect to a restricted proxy while our NAT type "+
				"is \"%v\", and failed. Let's not do that again.",
			actualNATType,
		)
		p.assumedUnrestrictedNATAndFailedToConnect.Store(true)
	}
}

// WebRTCDialer implements the |Tongue| interface to catch snowflakes, using BrokerChannel.
type WebRTCDialer struct {
	*BrokerChannel
	// Can be `nil`, in which case we won't apply special logic,
	// and simply always send the current NAT type instead.
	natPolicy    *NATPolicy
	webrtcConfig *webrtc.Configuration
	max          int

	eventLogger      event.SnowflakeEventReceiver
	proxy            *url.URL
	covertDTLSconfig *covertdtls.CovertDTLSConfig
}

// Deprecated: Use NewWebRTCDialerWithNatPolicyAndEventsAndProxy instead
func NewWebRTCDialer(broker *BrokerChannel, iceServers []webrtc.ICEServer, max int) *WebRTCDialer {
	return NewWebRTCDialerWithNatPolicyAndEventsAndProxy(
		broker, nil, iceServers, max, nil, nil,
	)
}

// Deprecated: Use NewWebRTCDialerWithNatPolicyAndEventsAndProxy instead
func NewWebRTCDialerWithEvents(broker *BrokerChannel, iceServers []webrtc.ICEServer, max int, eventLogger event.SnowflakeEventReceiver) *WebRTCDialer {
	return NewWebRTCDialerWithNatPolicyAndEventsAndProxy(
		broker, nil, iceServers, max, eventLogger, nil,
	)
}

// Deprecated: Use NewWebRTCDialerWithNatPolicyAndEventsAndProxy instead
func NewWebRTCDialerWithEventsAndProxy(broker *BrokerChannel, iceServers []webrtc.ICEServer, max int,
	eventLogger event.SnowflakeEventReceiver, proxy *url.URL,
) *WebRTCDialer {
	return NewWebRTCDialerWithNatPolicyAndEventsAndProxy(
		broker,
		nil,
		iceServers,
		max,
		eventLogger,
		proxy,
	)
}

// NewWebRTCDialerWithNatPolicyAndEventsAndProxy constructs a new WebRTCDialer.
func NewWebRTCDialerWithNatPolicyAndEventsAndProxy(
	broker *BrokerChannel,
	natPolicy *NATPolicy,
	iceServers []webrtc.ICEServer,
	max int,
	eventLogger event.SnowflakeEventReceiver,
	proxy *url.URL,
) *WebRTCDialer {
	return NewCovertWebRTCDialerWithNatPolicyAndEventsAndProxy(broker, natPolicy, iceServers, max, eventLogger, proxy, nil)
}

// NewCovertWebRTCDialerWithNatPolicyAndEventsAndProxy constructs a new WebRTCDialer setting DTLS mimicking and randomization.
func NewCovertWebRTCDialerWithNatPolicyAndEventsAndProxy(
	broker *BrokerChannel,
	natPolicy *NATPolicy,
	iceServers []webrtc.ICEServer,
	max int,
	eventLogger event.SnowflakeEventReceiver,
	proxy *url.URL,
	covertDTLSconfig *covertdtls.CovertDTLSConfig,
) *WebRTCDialer {
	config := webrtc.Configuration{
		ICEServers: iceServers,
	}

	return &WebRTCDialer{
		BrokerChannel: broker,
		natPolicy:     natPolicy,
		webrtcConfig:  &config,
		max:           max,

		eventLogger:      eventLogger,
		proxy:            proxy,
		covertDTLSconfig: covertDTLSconfig,
	}
}

// Catch initializes a WebRTC Connection by signaling through the BrokerChannel.
func (w WebRTCDialer) Catch() (*WebRTCPeer, error) {
	// TODO: [#25591] Fetch ICE server information from Broker.
	// TODO: [#25596] Consider TURN servers here too.
	return NewWebRTCPeerWithNatPolicyAndEventsAndProxy(
		w.webrtcConfig, w.BrokerChannel, w.natPolicy, w.eventLogger, w.proxy,
	)
}

// GetMax returns the maximum number of snowflakes to collect.
func (w WebRTCDialer) GetMax() int {
	return w.max
}
