//Package for communication with the snowflake broker

// import "gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/messages"
package messages

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/nat"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/common/util"
)

const (
	version      = "1.3"
	ProxyUnknown = "unknown"
)

var KnownProxyTypes = map[string]bool{
	"standalone": true,
	"webext":     true,
	"badge":      true,
	"iptproxy":   true,
	"bloco":      true,
}

/* Version 1.3 specification:

== ProxyPollRequest ==
{
  Sid: [generated session id of proxy],
  Version: 1.3,
  Type: ["badge"|"webext"|"standalone"],
  NAT: ["unknown"|"restricted"|"unrestricted"],
  Clients: [number of current clients, rounded down to multiples of 8],
  AcceptedRelayPattern: [a pattern representing accepted set of relay domains]
}

== ProxyPollResponse ==
1) If a client is matched:
HTTP 200 OK
{
  Status: "client match",
  {
    type: offer,
    sdp: [WebRTC SDP]
  },
  NAT: ["unknown"|"restricted"|"unrestricted"],
  RelayURL: [the WebSocket URL proxy should connect to relay Snowflake traffic]
  NextPoll: [number of milliseconds until the proxy's next poll]
}

2) If a client is not matched:
HTTP 200 OK

{
  Status: "no match"
  NextPoll: [number of milliseconds until the proxy's next poll]
}

3) If the request is malformed:
HTTP 400 BadRequest

== ProxyAnswerRequest ==
{
  Sid: [generated session id of proxy],
  Version: 1.3,
  Answer:
  {
    type: answer,
    sdp: [WebRTC SDP]
  }
}

== ProxyAnswerResponse ==
1) If the client retrieved the answer:
HTTP 200 OK

{
  Status: "success"
}

2) If the client left:
HTTP 200 OK

{
  Status: "client gone"
}

3) If the request is malformed:
HTTP 400 BadRequest

*/

type ProxyPollRequest struct {
	Sid     string
	Version string
	Type    string
	NAT     string
	Clients int

	AcceptedRelayPattern *string
}

func EncodeProxyPollRequest(sid string, proxyType string, natType string, clients int) ([]byte, error) {
	return EncodeProxyPollRequestWithRelayPrefix(sid, proxyType, natType, clients, "")
}

func EncodeProxyPollRequestWithRelayPrefix(sid string, proxyType string, natType string, clients int, relayPattern string) ([]byte, error) {
	return json.Marshal(ProxyPollRequest{
		Sid:                  sid,
		Version:              version,
		Type:                 proxyType,
		NAT:                  natType,
		Clients:              clients,
		AcceptedRelayPattern: &relayPattern,
	})
}

func (req *ProxyPollRequest) Encode() ([]byte, error) {
	req.Version = version
	return json.Marshal(req)
}

// Decodes a poll message from a snowflake proxy and returns the
// sid, proxy type, nat type and clients of the proxy on success
// and an error if it failed
func DecodeProxyPollRequestWithRelayPrefix(data []byte) (
	sid string, proxyType string, natType string, clients int, relayPrefix string, relayPrefixAware bool, err error) {
	var message *ProxyPollRequest

	message, err = DecodeProxyPollRequest(data)
	if err != nil {
		return
	}
	var acceptedRelayPattern = ""
	if message.AcceptedRelayPattern != nil {
		acceptedRelayPattern = *message.AcceptedRelayPattern
	}
	return message.Sid, message.Type, message.NAT, message.Clients,
		acceptedRelayPattern, message.AcceptedRelayPattern != nil, nil
}

// Decodes a poll message from a snowflake proxy and returns a
// ProxyPollRequest
func DecodeProxyPollRequest(data []byte) (*ProxyPollRequest, error) {
	var message ProxyPollRequest

	if err := json.Unmarshal(data, &message); err != nil {
		return nil, err
	}

	majorVersion := strings.Split(message.Version, ".")[0]
	if majorVersion != "1" {
		return nil, fmt.Errorf("using unknown version")
	}

	// Version 1.x requires an Sid
	if message.Sid == "" {
		return nil, fmt.Errorf("no supplied session id")
	}

	switch message.NAT {
	case "":
		message.NAT = nat.NATUnknown
	case nat.NATUnknown:
	case nat.NATRestricted:
	case nat.NATUnrestricted:
	default:
		return nil, fmt.Errorf("invalid NAT type")
	}

	// self-reported clients should be greater than or equal to 0
	message.Clients = max(message.Clients, 0)

	// we don't reject polls with an unknown proxy type because we encourage
	// projects that embed proxy code to include their own type
	if !KnownProxyTypes[message.Type] {
		message.Type = ProxyUnknown
	}
	return &message, nil
}

const (
	ProxyClientMatch   = "client match"
	ProxyClientNoMatch = "no match"
)

type ProxyPollResponse struct {
	Status   string
	Offer    string
	NAT      string
	NextPoll int64

	RelayURL string
}

func EncodePollResponse(offer string, success bool, natType string) ([]byte, error) {
	return EncodePollResponseWithRelayURL(offer, success, natType, "", "no match")
}

func EncodePollResponseWithRelayURL(offer string, success bool, natType, relayURL, failReason string) ([]byte, error) {
	if success {
		return json.Marshal(ProxyPollResponse{
			Status:   "client match",
			Offer:    offer,
			NAT:      natType,
			RelayURL: relayURL,
		})

	}
	return json.Marshal(ProxyPollResponse{
		Status: failReason,
	})
}
func DecodePollResponse(data []byte) (offer string, natType string, err error) {
	offer, natType, relayURL, err := DecodePollResponseWithRelayURL(data)
	if relayURL != "" {
		return "", "", ErrExtraInfo
	}
	return offer, natType, err
}

func (resp *ProxyPollResponse) Encode() ([]byte, error) {
	return json.Marshal(resp)
}

// Decodes a poll response from the broker and returns an offer and the client's NAT type
// If there is a client match, the returned offer string will be non-empty
func DecodePollResponseWithRelayURL(data []byte) (
	offer string,
	natType string,
	relayURL string,
	err_ error,
) {
	message, err := DecodeProxyPollResponse(data)
	if err != nil {
		return "", "", "", err
	}
	return message.Offer, message.NAT, message.RelayURL, err
}

func DecodeProxyPollResponse(data []byte) (*ProxyPollResponse, error) {
	var message ProxyPollResponse

	err := json.Unmarshal(data, &message)
	if err != nil {
		return nil, err
	}
	if message.Status == "" {
		return nil, fmt.Errorf("received invalid data")
	}

	err = nil
	if message.Status == ProxyClientMatch {
		if message.Offer == "" {
			return nil, fmt.Errorf("no supplied offer")
		}
	} else {
		message.Offer = ""
		if message.Status != ProxyClientNoMatch {
			err = errors.New(message.Status)
		}
	}

	if message.NAT == "" {
		message.NAT = "unknown"
	}

	return &message, err
}

type ProxyAnswerRequest struct {
	Version string
	Sid     string
	Answer  string
}

func EncodeAnswerRequest(answer string, sid string) ([]byte, error) {
	return json.Marshal(ProxyAnswerRequest{
		Version: version,
		Sid:     sid,
		Answer:  answer,
	})
}

func (req *ProxyAnswerRequest) Encode() ([]byte, error) {
	req.Version = version
	return json.Marshal(req)
}

// Returns the sdp answer and proxy sid
func DecodeAnswerRequest(data []byte) (answer string, sid string, err error) {
	message, err := DecodeProxyAnswerRequest(data)
	if err != nil {
		return "", "", err
	}
	return message.Answer, message.Sid, nil
}

func DecodeProxyAnswerRequest(data []byte) (*ProxyAnswerRequest, error) {
	var message ProxyAnswerRequest

	err := json.Unmarshal(data, &message)
	if err != nil {
		return nil, err
	}

	majorVersion := strings.Split(message.Version, ".")[0]
	if majorVersion != "1" {
		return nil, fmt.Errorf("using unknown version")
	}

	if message.Sid == "" || message.Answer == "" {
		return nil, fmt.Errorf("no supplied sid or answer")
	}
	if _, err := util.DeserializeSessionDescription(message.Answer); err != nil {
		return nil, fmt.Errorf("malformed session description: %s", err.Error())
	}

	return &message, nil
}

type ProxyAnswerResponse struct {
	Status string
}

func EncodeAnswerResponse(success bool) ([]byte, error) {
	if success {
		return json.Marshal(ProxyAnswerResponse{
			Status: "success",
		})

	}
	return json.Marshal(ProxyAnswerResponse{
		Status: "client gone",
	})
}

func (resp *ProxyAnswerResponse) Encode() ([]byte, error) {
	return json.Marshal(resp)
}

func DecodeAnswerResponse(data []byte) (bool, error) {
	var success bool

	message, err := DecodeProxyAnswerResponse(data)
	if err != nil {
		return false, err
	}
	if message.Status == "" {
		return false, fmt.Errorf("received invalid data")
	}

	if message.Status == "success" {
		success = true
	}

	return success, nil
}

func DecodeProxyAnswerResponse(data []byte) (*ProxyAnswerResponse, error) {
	var message ProxyAnswerResponse
	err := json.Unmarshal(data, &message)
	if err != nil {
		return nil, err
	}
	return &message, nil
}
