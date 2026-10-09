package util

import (
	"encoding/json"
	"errors"
	"log"
	"net"
	"net/http"
	"slices"
	"sort"

	"github.com/pion/ice/v4"
	"github.com/pion/sdp/v3"
	"github.com/pion/webrtc/v4"
	"github.com/realclientip/realclientip-go"
)

func SerializeSessionDescription(desc *webrtc.SessionDescription) (string, error) {
	bytes, err := json.Marshal(*desc)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func DeserializeSessionDescription(msg string) (*webrtc.SessionDescription, error) {
	var parsed map[string]interface{}
	err := json.Unmarshal([]byte(msg), &parsed)
	if err != nil {
		return nil, err
	}
	if _, ok := parsed["type"]; !ok {
		return nil, errors.New("cannot deserialize SessionDescription without type field")
	}
	if _, ok := parsed["sdp"]; !ok {
		return nil, errors.New("cannot deserialize SessionDescription without sdp field")
	}

	parsedType, ok := parsed["type"].(string)
	if !ok {
		return nil, errors.New("invalid SDP type")
	}
	parsedSDP, ok := parsed["sdp"].(string)
	if !ok {
		return nil, errors.New("invalid SDP")
	}

	var stype webrtc.SDPType
	switch parsedType {
	default:
		return nil, errors.New("Unknown SDP type")
	case "offer":
		stype = webrtc.SDPTypeOffer
	case "pranswer":
		stype = webrtc.SDPTypePranswer
	case "answer":
		stype = webrtc.SDPTypeAnswer
	case "rollback":
		stype = webrtc.SDPTypeRollback
	}

	return &webrtc.SessionDescription{
		Type: stype,
		SDP:  parsedSDP,
	}, nil
}

func IsLocal(ip net.IP) bool {
	if ip.IsPrivate() {
		return true
	}
	// Dynamic Configuration as per https://tools.ietf.org/htm/rfc3927
	if ip.IsLinkLocalUnicast() {
		return true
	}
	if ip4 := ip.To4(); ip4 != nil {
		// Carrier-Grade NAT as per https://tools.ietf.org/htm/rfc6598
		if ip4[0] == 100 && ip4[1]&0xc0 == 64 {
			return true
		}
	}
	return false
}

// Removes local LAN address ICE candidates
//
// This is unused after https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/merge_requests/442,
// but come in handy later for https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/issues/40322
// Also this is exported, so let's not remove it at least until
// the next major release.
func StripLocalAddresses(str string) string {
	var desc sdp.SessionDescription
	err := desc.Unmarshal([]byte(str))
	if err != nil {
		return str
	}
	for _, m := range desc.MediaDescriptions {
		attrs := make([]sdp.Attribute, 0)
		for _, a := range m.Attributes {
			if a.IsICECandidate() {
				c, err := ice.UnmarshalCandidate(a.Value)
				if err == nil && c.Type() == ice.CandidateTypeHost {
					ip := net.ParseIP(c.Address())
					if ip != nil && (IsLocal(ip) || ip.IsUnspecified() || ip.IsLoopback()) {
						/* no append in this case */
						continue
					}
				}
			}
			attrs = append(attrs, a)
		}
		m.Attributes = attrs
	}
	bts, err := desc.Marshal()
	if err != nil {
		return str
	}
	return string(bts)
}

// Attempts to retrieve the client IP of where the HTTP request originating.
// There is no standard way to do this since the original client IP can be included in a number of different headers,
// depending on the proxies and load balancers between the client and the server. We attempt to check as many of these
// headers as possible to determine a "best guess" of the client IP
// Using this as a reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Forwarded
func GetClientIp(req *http.Request) string {
	// We check the "Fowarded" header first, followed by the "X-Forwarded-For" header, and then use the "RemoteAddr" as
	// a last resort. We use the leftmost address since it is the closest one to the client.
	strat := realclientip.NewChainStrategy(
		realclientip.Must(realclientip.NewLeftmostNonPrivateStrategy("Forwarded")),
		realclientip.Must(realclientip.NewLeftmostNonPrivateStrategy("X-Forwarded-For")),
		realclientip.RemoteAddrStrategy{},
	)
	clientIp := strat.ClientIP(req.Header, req.RemoteAddr)
	return clientIp
}

// Returns a list of IP addresses of ICE candidates, roughly in descending order for accuracy for geolocation
func GetCandidateAddrs(sdpStr string) []net.IP {
	var desc sdp.SessionDescription
	err := desc.Unmarshal([]byte(sdpStr))
	if err != nil {
		log.Printf("GetCandidateAddrs: failed to unmarshal SDP: %v\n", err)
		return []net.IP{}
	}

	iceCandidates := make([]ice.Candidate, 0)

	for _, m := range desc.MediaDescriptions {
		for _, a := range m.Attributes {
			if a.IsICECandidate() {
				c, err := ice.UnmarshalCandidate(a.Value)
				if err == nil {
					iceCandidates = append(iceCandidates, c)
				}
			}
		}
	}

	// ICE candidates are first sorted in asecending order of priority, to match convention of providing a custom Less
	// function to sort
	sort.Slice(iceCandidates, func(i, j int) bool {
		if iceCandidates[i].Type() != iceCandidates[j].Type() {
			// Sort by candidate type first, in the order specified in https://datatracker.ietf.org/doc/html/rfc8445#section-5.1.2.2
			// Higher priority candidate types are more efficient, which likely means they are closer to the client
			// itself, providing a more accurate result for geolocation
			return ice.CandidateType(iceCandidates[i].Type().Preference()) < ice.CandidateType(iceCandidates[j].Type().Preference())
		}
		// Break ties with the ICE candidate's priority property
		return iceCandidates[i].Priority() < iceCandidates[j].Priority()
	})
	slices.Reverse(iceCandidates)

	sortedIpAddr := make([]net.IP, 0)
	for _, c := range iceCandidates {
		ip := net.ParseIP(c.Address())
		if ip != nil {
			sortedIpAddr = append(sortedIpAddr, ip)
		}
	}
	return sortedIpAddr
}
